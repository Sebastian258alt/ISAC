-- =====================================================================
--  ISAC · MIGRAÇÃO P0-3 · Segurança de contas, papéis e escalação de privilégios
--  Para um projecto Supabase JÁ EXISTENTE (quem instala de novo usa só schema.sql).
--  Supabase → SQL Editor → New query → colar tudo → Run.
--  Idempotente: pode ser executada mais do que uma vez. Não apaga dados.
-- =====================================================================

-- 1. search_path seguro em todas as funções SECURITY DEFINER
--    (vazio = só pg_catalog; todas as referências no código já são qualificadas com public./auth.)
alter function public.papel_actual() set search_path = '';
alter function public.e_admin() set search_path = '';
alter function public.professor_da_turma(uuid) set search_path = '';
alter function public.professor_ve_aluno(uuid) set search_path = '';
alter function public.pode_lancar(uuid) set search_path = '';
alter function public.aluno_da_matricula(uuid) set search_path = '';
alter function public.pode_ver_matricula(uuid) set search_path = '';
alter function public.aluno_da_cobranca(uuid) set search_path = '';
alter function public.novo_utilizador() set search_path = '';
alter function public.auditar() set search_path = '';
alter function public.verificar_pagamento() set search_path = '';
alter function public.gerar_propinas(uuid,int,date) set search_path = '';
alter function public.matricular(uuid,uuid,int,date) set search_path = '';

-- 2. Gatilhos novos

-- 4.5 [P0-3] Defesa em profundidade em profiles. Mesmo que um dia alguém acrescente
--     uma policy do tipo "auth.uid() = id", ninguém que não seja admin activo consegue
--     mudar papel, activo, email, criado_em; ninguém muda o id; e a API não consegue
--     remover o último admin activo. SQL Editor / service_role (auth.uid() nulo e
--     fora dos papéis da API) não são afectados: é assim que se cria o 1.º admin.
--     (Função SEM security definer de propósito: current_user é o papel da API.)
create or replace function public.proteger_profiles() returns trigger
language plpgsql set search_path = '' as $$
begin
  if auth.uid() is null and current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if new.id is distinct from old.id then
    raise exception 'O identificador de uma conta não pode ser alterado.';
  end if;
  if not public.e_admin() then
    if new.papel is distinct from old.papel or new.activo is distinct from old.activo
       or new.email is distinct from old.email or new.criado_em is distinct from old.criado_em then
      raise exception 'Apenas a administração pode alterar papel, estado ou dados de identidade de uma conta.';
    end if;
  elsif old.papel = 'admin' and old.activo and (new.papel <> 'admin' or not new.activo)
        and not exists (select 1 from public.profiles where papel = 'admin' and activo and id <> old.id) then
    raise exception 'Não é possível remover ou desactivar o último administrador activo.';
  end if;
  return new;
end $$;
drop trigger if exists proteger_profiles on public.profiles;
create trigger proteger_profiles before update on public.profiles
  for each row execute function public.proteger_profiles();

-- 4.6 [P0-3] Quem recebeu o pagamento é sempre quem está autenticado (não vem do navegador)
create or replace function public.definir_recebido_por() returns trigger
language plpgsql set search_path = '' as $$
begin
  if auth.uid() is not null then new.recebido_por := auth.uid(); end if;
  return new;
end $$;
drop trigger if exists pag_recebido_por on public.pagamentos;
create trigger pag_recebido_por before insert on public.pagamentos
  for each row execute function public.definir_recebido_por();

-- 3. RPC em falta (o portal do formador chama-a; se já existir uma versão antiga, é substituída pela segura)
drop function if exists public.nomes_alunos_turma(uuid);
-- [P0-3] Nomes dos alunos de uma turma (usada pelo portal do formador).
-- Devolve só id e nome (sem email/telefone/encarregado). Só admin activo ou o
-- formador activo dessa turma; a turma vem do parâmetro mas a autorização é
-- sempre confirmada contra auth.uid() dentro da função.
create function public.nomes_alunos_turma(p_turma uuid)
returns table (id uuid, nome text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.nome
    from public.matriculas m join public.profiles p on p.id = m.aluno_id
   where m.turma_id = p_turma
     and (public.e_admin() or public.professor_da_turma(p_turma))
$$;

-- 4. Permissões
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon;
revoke all on all sequences in schema public from anon, authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;
revoke insert, delete on public.profiles from authenticated;           -- perfis: só o gatilho cria; ninguém apaga pela API
revoke insert, update, delete on public.auditoria from authenticated;  -- auditoria: só os gatilhos escrevem

-- As funções auxiliares têm de ser executáveis por "authenticated" porque as policies
-- RLS são avaliadas com os direitos de quem consulta. Todas validam auth.uid() e "activo".
grant execute on all functions in schema public to authenticated;
-- Funções de gatilho nunca são chamadas pela API (o EXECUTE não é exigido ao disparar o gatilho)
revoke execute on function public.novo_utilizador(), public.auditar(), public.marcar_actualizacao(),
  public.verificar_pagamento(), public.proteger_profiles(), public.definir_recebido_por() from authenticated;
-- Funções futuras: nunca expostas à chave pública por omissão
alter default privileges in schema public revoke execute on functions from public, anon;

-- 5. Verificação (só leitura): todas as funções de public, quem as executa e o search_path
select p.proname as funcao, p.prosecdef as security_definer,
       coalesce(array_to_string(p.proconfig, ','), 'SEM search_path') as config,
       has_function_privilege('anon', p.oid, 'execute')          as anon_executa,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_executa
  from pg_proc p where p.pronamespace = 'public'::regnamespace order by 1;
