-- =====================================================================
--  PORTAL ISAC · P3 · Avisos e notificações da instituição
--  Como usar: Supabase → SQL Editor → New query → colar tudo → Run.
--  Pré-requisito: schema.sql já executado. Pode correr mais de uma vez.
--
--  A administração publica avisos (informação / importante / urgente) para:
--    publico    = site público + todos os utilizadores do portal
--    alunos     = só alunos (portal)
--    formadores = só formadores (portal)
--  No portal cada utilizador vê quantos avisos ainda não leu.
-- =====================================================================

create table if not exists public.avisos (
  id           uuid primary key default gen_random_uuid(),
  titulo       text not null check (char_length(btrim(titulo)) between 3 and 120),
  mensagem     text not null check (char_length(btrim(mensagem)) between 3 and 2000),
  nivel        text not null default 'info' check (nivel in ('info','importante','urgente')),
  publico      text not null default 'publico' check (publico in ('publico','alunos','formadores')),
  fixado       boolean not null default false,
  activo       boolean not null default true,
  publicado_em timestamptz not null default now(),
  expira_em    timestamptz,
  criado_por   uuid references public.profiles(id) on delete set null default auth.uid(),
  check (expira_em is null or expira_em > publicado_em)
);
create index if not exists avisos_lista on public.avisos (activo, publico, fixado desc, publicado_em desc);

create table if not exists public.avisos_lidos (
  aviso_id uuid not null references public.avisos(id) on delete cascade,
  user_id  uuid not null references public.profiles(id) on delete cascade,
  lido_em  timestamptz not null default now(),
  primary key (aviso_id, user_id)
);

alter table public.avisos        enable row level security;
alter table public.avisos_lidos  enable row level security;

-- administração: tudo
drop policy if exists avisos_admin on public.avisos;
create policy avisos_admin on public.avisos for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

-- restantes: só avisos activos, em vigor e dirigidos ao seu papel
drop policy if exists avisos_ver on public.avisos;
create policy avisos_ver on public.avisos for select to authenticated
  using (activo and publicado_em <= now() and (expira_em is null or expira_em > now())
         and (publico = 'publico'
              or (publico = 'alunos'     and public.papel_actual() = 'aluno')
              or (publico = 'formadores' and public.papel_actual() = 'professor')));

-- cada pessoa só vê/marca as suas leituras
drop policy if exists lidos_ver on public.avisos_lidos;
create policy lidos_ver on public.avisos_lidos for select to authenticated using (user_id = auth.uid());
drop policy if exists lidos_inserir on public.avisos_lidos;
create policy lidos_inserir on public.avisos_lidos for insert to authenticated
  with check (user_id = auth.uid() and public.papel_actual() is not null);

revoke all on public.avisos, public.avisos_lidos from anon, authenticated;
grant select, insert, update, delete on public.avisos to authenticated;
grant select, insert on public.avisos_lidos to authenticated;

drop trigger if exists aud_avisos on public.avisos;
create trigger aud_avisos after insert or update or delete on public.avisos
  for each row execute function public.auditar();

-- Avisos para o site público (sem login): só os de público = 'publico', activos e em vigor
create or replace function public.avisos_publicos()
returns table (id uuid, titulo text, mensagem text, nivel text, fixado boolean, publicado_em timestamptz)
language sql stable security definer set search_path = '' as $$
  select a.id, a.titulo, a.mensagem, a.nivel, a.fixado, a.publicado_em
    from public.avisos a
   where a.activo and a.publico = 'publico' and a.publicado_em <= now()
     and (a.expira_em is null or a.expira_em > now())
   order by a.fixado desc, a.publicado_em desc limit 10
$$;
revoke execute on function public.avisos_publicos() from public, anon;
grant execute on function public.avisos_publicos() to anon, authenticated;
