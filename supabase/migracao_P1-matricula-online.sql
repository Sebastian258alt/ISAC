-- =====================================================================
--  PORTAL ISAC · P1 · Matrícula online (pré-inscrição + BI + activação)
--  Como usar: Supabase → SQL Editor → New query → colar tudo → Run.
--  Pré-requisito: o schema.sql (e as migrações anteriores) já executados.
--  Pode ser executado mais de uma vez sem estragar nada.
--
--  Fluxo:  visitante cria conta (inactiva) → preenche a pré-inscrição e envia o BI
--          → paga e envia o comprovativo por WhatsApp → a administração abre a
--          pré-inscrição, confere o BI e "Activa e matricula" (gera cobranças e
--          regista o pagamento) → o aluno entra, vê notas/pagamentos e baixa recibos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELA
-- ---------------------------------------------------------------------
create table if not exists public.preinscricoes (
  id              uuid primary key default gen_random_uuid(),
  aluno_id        uuid not null unique references public.profiles(id) on delete cascade,
  nome_completo   text not null check (char_length(btrim(nome_completo)) between 3 and 120),
  bi_numero       text not null check (char_length(btrim(bi_numero)) between 5 and 30),
  data_nascimento date not null check (data_nascimento > date '1920-01-01'),
  genero          text check (genero in ('M','F')),
  morada          text not null check (char_length(btrim(morada)) between 3 and 200),
  telefone        text not null check (char_length(btrim(telefone)) between 9 and 20),
  curso_id        uuid not null references public.cursos(id) on delete cascade,
  turma_id        uuid references public.turmas(id) on delete set null,   -- preferência (a administração confirma)
  encarregado     text check (char_length(encarregado) <= 120),
  encarregado_tel text check (char_length(encarregado_tel) <= 20),
  bi_ficheiro     text not null,                                          -- caminho no bucket bi-documentos
  estado          text not null default 'pendente' check (estado in ('pendente','aprovada','rejeitada')),
  observacao      text,                                                   -- motivo, quando rejeitada
  criado_em       timestamptz not null default now(),
  actualizado_em  timestamptz not null default now(),
  -- o ficheiro tem de estar na pasta do próprio aluno (ninguém aponta para o BI de outra pessoa)
  check (bi_ficheiro like aluno_id::text || '/%')
);
create index if not exists preinscricoes_estado on public.preinscricoes (estado, criado_em desc);

alter table public.preinscricoes enable row level security;

drop policy if exists pre_ver on public.preinscricoes;
create policy pre_ver on public.preinscricoes for select to authenticated
  using (aluno_id = auth.uid() or public.e_admin());

-- Só quem ainda é aluno INACTIVO pode criar a sua pré-inscrição (sempre "pendente")
drop policy if exists pre_inserir on public.preinscricoes;
create policy pre_inserir on public.preinscricoes for insert to authenticated
  with check (aluno_id = auth.uid() and estado = 'pendente'
              and exists (select 1 from public.profiles
                           where id = auth.uid() and papel = 'aluno' and not activo));

-- Pode corrigir os dados enquanto está pendente ou rejeitada; nunca se auto-aprova
drop policy if exists pre_actualizar on public.preinscricoes;
create policy pre_actualizar on public.preinscricoes for update to authenticated
  using (aluno_id = auth.uid() and estado in ('pendente','rejeitada'))
  with check (aluno_id = auth.uid() and estado = 'pendente');

-- (sem policy de delete: ninguém apaga pela API)

drop trigger if exists pre_actualizacao on public.preinscricoes;
create trigger pre_actualizacao before update on public.preinscricoes
  for each row execute function public.marcar_actualizacao();

drop trigger if exists aud_preinscricoes on public.preinscricoes;
create trigger aud_preinscricoes after insert or update or delete on public.preinscricoes
  for each row execute function public.auditar();

revoke all on public.preinscricoes from anon, authenticated;
grant select, insert, update on public.preinscricoes to authenticated;

-- ---------------------------------------------------------------------
-- 2. ARMAZENAMENTO PRIVADO DO BI (bucket bi-documentos)
--    Pasta = id do aluno. Só o dono e a administração leem; ninguém é público.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bi-documentos', 'bi-documentos', false, 5242880,
        array['image/jpeg','image/png','application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg','image/png','application/pdf'];

drop policy if exists bi_inserir on storage.objects;
create policy bi_inserir on storage.objects for insert to authenticated
  with check (bucket_id = 'bi-documentos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists bi_ver on storage.objects;
create policy bi_ver on storage.objects for select to authenticated
  using (bucket_id = 'bi-documentos'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.e_admin()));

-- ---------------------------------------------------------------------
-- 3. FUNÇÕES
-- ---------------------------------------------------------------------

-- Cursos e turmas visíveis a quem ainda não tem conta activa (informação pública do site)
create or replace function public.cursos_publicos()
returns table (id uuid, nome text, descricao text, taxa_matricula numeric, propina_mensal numeric)
language sql stable security definer set search_path = '' as $$
  select c.id, c.nome, c.descricao, c.taxa_matricula, c.propina_mensal
    from public.cursos c where c.activo order by c.nome
$$;

create or replace function public.turmas_publicas()
returns table (id uuid, curso_id uuid, nome text, horario text)
language sql stable security definer set search_path = '' as $$
  select t.id, t.curso_id, t.nome, t.horario
    from public.turmas t join public.cursos c on c.id = t.curso_id
   where t.activa and c.activo order by t.nome
$$;

-- Aprovar: activa a conta, copia os dados para o perfil, matricula (gera cobranças)
-- e, se p_valor > 0, regista o pagamento da taxa de matrícula. Tudo ou nada.
create or replace function public.aprovar_preinscricao(
  p_aluno uuid, p_turma uuid, p_meses int default 10, p_inicio date default current_date,
  p_valor numeric default 0, p_metodo text default 'mpesa', p_ref text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_pre public.preinscricoes; v_mat uuid; v_cob uuid;
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode aprovar pré-inscrições.'; end if;
  select * into v_pre from public.preinscricoes where aluno_id = p_aluno for update;
  if not found then raise exception 'Pré-inscrição não encontrada.'; end if;
  if v_pre.estado = 'aprovada' then raise exception 'Esta pré-inscrição já foi aprovada.'; end if;
  if coalesce(p_valor, 0) < 0 then raise exception 'Valor inválido.'; end if;

  update public.profiles
     set activo = true, papel = 'aluno', nome = v_pre.nome_completo, telefone = v_pre.telefone,
         encarregado = v_pre.encarregado, encarregado_tel = v_pre.encarregado_tel
   where id = p_aluno;

  v_mat := public.matricular(p_aluno, p_turma, p_meses, p_inicio);

  if coalesce(p_valor, 0) > 0 then
    select id into v_cob from public.cobrancas where matricula_id = v_mat and tipo = 'matricula';
    if v_cob is null then
      raise exception 'Este curso não tem taxa de matrícula: deixe o valor pago a 0.';
    end if;
    insert into public.pagamentos (cobranca_id, valor, data, metodo, referencia)
    values (v_cob, p_valor, current_date, p_metodo, nullif(btrim(p_ref), ''));
  end if;

  update public.preinscricoes set estado = 'aprovada', observacao = null where aluno_id = p_aluno;
  return v_mat;
end $$;

create or replace function public.rejeitar_preinscricao(p_aluno uuid, p_motivo text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode rejeitar pré-inscrições.'; end if;
  if char_length(btrim(coalesce(p_motivo, ''))) < 3 then raise exception 'Indique o motivo.'; end if;
  update public.preinscricoes set estado = 'rejeitada', observacao = btrim(p_motivo)
   where aluno_id = p_aluno and estado = 'pendente';
  if not found then raise exception 'Não há pré-inscrição pendente para este aluno.'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 4. PERMISSÕES DAS FUNÇÕES
-- ---------------------------------------------------------------------
revoke execute on function public.cursos_publicos(), public.turmas_publicas(),
  public.aprovar_preinscricao(uuid, uuid, int, date, numeric, text, text),
  public.rejeitar_preinscricao(uuid, text) from public, anon;
grant execute on function public.cursos_publicos(), public.turmas_publicas() to anon, authenticated;
grant execute on function public.aprovar_preinscricao(uuid, uuid, int, date, numeric, text, text),
  public.rejeitar_preinscricao(uuid, text) to authenticated;
