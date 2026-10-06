-- =====================================================================
--  ISAC · MIGRAÇÃO P0-3B · Apagar contas e limpar dados (só administração)
--  Para um projecto Supabase JÁ EXISTENTE (quem instala de novo usa só schema.sql).
--  Supabase → SQL Editor → New query → colar tudo → Run.
--  Idempotente. Não apaga nada: só cria as funções que o botão do portal chama.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6B. [P0-3B] APAGAR CONTAS E LIMPAR DADOS (só administração activa)
--     Tudo corre no servidor: o botão do portal só chama estas funções.
--     Protecções: e_admin() · confirmação escrita "APAGAR" (validada aqui, não só no
--     navegador) · ninguém apaga a própria conta (logo nunca sobra 0 administradores) ·
--     a limpeza nunca toca em contas de administração nem na Auditoria.
--     A Auditoria regista cada linha apagada (quem, quando, antes) + uma linha de resumo.
--     Nota: como a Auditoria é imutável, guarda uma cópia dos dados apagados
--     (nome, email...). Para a esvaziar (ex.: antes de abrir a sério) só pelo SQL Editor.
-- ---------------------------------------------------------------------

-- Interna: apaga contas + tudo o que depende delas. Sem EXECUTE para a API.
create or replace function public.apagar_contas_interno(p_ids uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.pagamentos where cobranca_id in
    (select c.id from public.cobrancas c join public.matriculas m on m.id = c.matricula_id
      where m.aluno_id = any(p_ids));
  delete from public.matriculas where aluno_id = any(p_ids);   -- notas, faltas e cobranças saem em cascata
  delete from auth.users where id = any(p_ids);                -- o perfil sai em cascata
end $$;

-- Quanto se apaga se esta conta for removida (para o ecrã de confirmação)
create or replace function public.resumo_utilizador(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode apagar contas.'; end if;
  select jsonb_build_object(
      'nome', p.nome, 'papel', p.papel,
      'matriculas', (select count(*) from public.matriculas where aluno_id = p.id),
      'notas', (select count(*) from public.avaliacoes a join public.matriculas m on m.id = a.matricula_id where m.aluno_id = p.id),
      'faltas', (select count(*) from public.faltas f join public.matriculas m on m.id = f.matricula_id where m.aluno_id = p.id),
      'cobrancas', (select count(*) from public.cobrancas c join public.matriculas m on m.id = c.matricula_id where m.aluno_id = p.id),
      'pagamentos', (select count(*) from public.pagamentos g join public.cobrancas c on c.id = g.cobranca_id
                      join public.matriculas m on m.id = c.matricula_id where m.aluno_id = p.id),
      'turmas_sem_formador', (select count(*) from public.turmas where professor_id = p.id))
    into r from public.profiles p where p.id = p_id;
  if r is null then raise exception 'Utilizador não encontrado.'; end if;
  return r;
end $$;

create or replace function public.apagar_utilizador(p_id uuid, p_confirmacao text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode apagar contas.'; end if;
  if p_confirmacao is distinct from 'APAGAR' then raise exception 'Confirmação em falta: escreva APAGAR.'; end if;
  if p_id = auth.uid() then raise exception 'Não pode apagar a sua própria conta.'; end if;
  if not exists (select 1 from public.profiles where id = p_id) then raise exception 'Utilizador não encontrado.'; end if;
  perform public.apagar_contas_interno(array[p_id]);
end $$;

-- Âmbitos: notas_faltas · financas · matriculas · alunos · formadores · tudo
create or replace function public.resumo_limpeza(p_ambito text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_ids uuid[]; v_m uuid[];
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode limpar dados.'; end if;
  if p_ambito is null or p_ambito not in ('notas_faltas','financas','matriculas','alunos','formadores','tudo') then
    raise exception 'Âmbito de limpeza inválido.';
  end if;
  v_ids := case p_ambito
    when 'alunos'     then array(select id from public.profiles where papel = 'aluno')
    when 'formadores' then array(select id from public.profiles where papel = 'professor')
    when 'tudo'       then array(select id from public.profiles where papel <> 'admin') end;
  v_m := case when v_ids is null or p_ambito = 'tudo' then array(select id from public.matriculas)
              else array(select id from public.matriculas where aluno_id = any(v_ids)) end;
  return jsonb_strip_nulls(jsonb_build_object(
    'contas',     cardinality(v_ids),
    'matriculas', case when p_ambito in ('matriculas','alunos','formadores','tudo') then cardinality(v_m) end,
    'notas',      case when p_ambito <> 'financas' then (select count(*) from public.avaliacoes where matricula_id = any(v_m)) end,
    'faltas',     case when p_ambito <> 'financas' then (select count(*) from public.faltas where matricula_id = any(v_m)) end,
    'cobrancas',  case when p_ambito <> 'notas_faltas' then (select count(*) from public.cobrancas where matricula_id = any(v_m)) end,
    'pagamentos', case when p_ambito <> 'notas_faltas' then (select count(*) from public.pagamentos where cobranca_id in
                     (select id from public.cobrancas where matricula_id = any(v_m))) end,
    'turmas',     case when p_ambito = 'tudo' then (select count(*) from public.turmas) end,
    'cursos',     case when p_ambito = 'tudo' then (select count(*) from public.cursos) end,
    'turmas_sem_formador', case when p_ambito = 'formadores' then (select count(*) from public.turmas where professor_id = any(v_ids)) end));
end $$;

create or replace function public.limpar_dados(p_ambito text, p_confirmacao text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_res jsonb;
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode limpar dados.'; end if;
  if p_confirmacao is distinct from 'APAGAR' then raise exception 'Confirmação em falta: escreva APAGAR.'; end if;
  v_res := public.resumo_limpeza(p_ambito);      -- valida o âmbito e conta o que vai sair
  case p_ambito
    when 'notas_faltas' then
      delete from public.faltas where id is not null;
      delete from public.avaliacoes where matricula_id is not null;
    when 'financas' then
      delete from public.pagamentos where id is not null;
      delete from public.cobrancas where id is not null;
    when 'matriculas' then
      delete from public.pagamentos where id is not null;
      delete from public.matriculas where id is not null;
    when 'alunos' then
      perform public.apagar_contas_interno(array(select id from public.profiles where papel = 'aluno'));
    when 'formadores' then
      perform public.apagar_contas_interno(array(select id from public.profiles where papel = 'professor'));
    when 'tudo' then
      delete from public.pagamentos where id is not null;
      delete from public.matriculas where id is not null;
      delete from public.turmas where id is not null;
      delete from public.cursos where id is not null;
      perform public.apagar_contas_interno(array(select id from public.profiles where papel <> 'admin'));
  end case;
  insert into public.auditoria (utilizador_id, utilizador_nome, tabela, accao, registo_id, detalhe)
  values (auth.uid(), coalesce((select nome from public.profiles where id = auth.uid()), 'sistema'),
          'sistema', 'LIMPEZA', p_ambito, jsonb_build_object('ambito', p_ambito, 'apagado', v_res));
  return v_res;
end $$;

-- Permissões: só contas com login; a interna nunca é exposta à API
revoke all on function public.resumo_utilizador(uuid), public.apagar_utilizador(uuid, text),
  public.resumo_limpeza(text), public.limpar_dados(text, text), public.apagar_contas_interno(uuid[])
  from public, anon;
grant execute on function public.resumo_utilizador(uuid), public.apagar_utilizador(uuid, text),
  public.resumo_limpeza(text), public.limpar_dados(text, text) to authenticated;
revoke execute on function public.apagar_contas_interno(uuid[]) from authenticated;
