-- =====================================================================
--  PORTAL ISAC · P4 · Diagnóstico gratuito (guardar resultados + limite da IA)
--  Como usar: Supabase → SQL Editor → New query → colar tudo → Run.
--  Pré-requisito: schema.sql já executado. Pode correr mais de uma vez.
--
--  O teste em si corre no telemóvel do aluno (js/motor.js) e NÃO precisa desta migração.
--  Esta migração serve para: (1) o aluno poder deixar nome + telefone e o resultado
--  ficar guardado para a secretaria; (2) limitar o uso da IA (evita abusos e custos).
--  Visitantes só conseguem ENVIAR (função registar_diagnostico); só a administração lê.
-- =====================================================================

create table if not exists public.diagnosticos (
  id          uuid primary key default gen_random_uuid(),
  curso       text not null check (curso in ('ingles','mandarim','informatica','eletricidade')),
  nivel       smallint not null check (nivel between 1 and 6),
  nivel_nome  text not null check (char_length(nivel_nome) <= 40),
  confianca   smallint not null check (confianca between 0 and 100),
  pct         jsonb,
  respondidas smallint check (respondidas between 0 and 40),
  certas      smallint check (certas between 0 and 40),
  nome        text not null check (char_length(btrim(nome)) between 2 and 80),
  telefone    text not null check (char_length(btrim(telefone)) between 9 and 20),
  estado      text not null default 'novo' check (estado in ('novo','contactado','matriculado','arquivado')),
  nivel_confirmado text check (char_length(nivel_confirmado) <= 40),  -- nível que o formador confirmou (serve para calibrar o motor)
  ip_hash     text,
  criado_em   timestamptz not null default now()
);
create index if not exists diagnosticos_estado on public.diagnosticos (estado, criado_em desc);
create index if not exists diagnosticos_ip on public.diagnosticos (ip_hash, criado_em desc);

alter table public.diagnosticos enable row level security;
drop policy if exists diag_ver on public.diagnosticos;
create policy diag_ver on public.diagnosticos for select to authenticated using (public.e_admin());
drop policy if exists diag_alterar on public.diagnosticos;
create policy diag_alterar on public.diagnosticos for update to authenticated
  using (public.e_admin()) with check (public.e_admin());
drop policy if exists diag_apagar on public.diagnosticos;
create policy diag_apagar on public.diagnosticos for delete to authenticated using (public.e_admin());

revoke all on public.diagnosticos from anon, authenticated;
grant select, update, delete on public.diagnosticos to authenticated;   -- inserir só pela função abaixo

drop trigger if exists aud_diagnosticos on public.diagnosticos;
create trigger aud_diagnosticos after update or delete on public.diagnosticos
  for each row execute function public.auditar();

-- Envio público: campo-isco, validação e no máximo 5 envios por hora por origem.
create or replace function public.registar_diagnostico(
  p_curso text, p_nivel int, p_nivel_nome text, p_confianca int, p_pct jsonb,
  p_respondidas int, p_certas int, p_nome text, p_telefone text, p_site text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare v_ip text; v_h text;
begin
  if coalesce(p_site, '') <> '' then return; end if;                    -- robô: ignora em silêncio
  if p_curso not in ('ingles','mandarim','informatica','eletricidade') then raise exception 'Curso inválido.'; end if;
  if p_nivel is null or p_nivel < 1 or p_nivel > 6 then raise exception 'Nível inválido.'; end if;
  if p_confianca is null or p_confianca < 0 or p_confianca > 100 then raise exception 'Resultado inválido.'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) < 2 then raise exception 'Escreva o seu nome.'; end if;
  if char_length(regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g')) < 9 then raise exception 'Indique um telefone válido.'; end if;
  if p_pct is not null and (jsonb_typeof(p_pct) <> 'array' or jsonb_array_length(p_pct) > 6) then p_pct := null; end if;
  begin
    v_ip := split_part(coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', ''), ',', 1);
  exception when others then v_ip := ''; end;
  v_h := case when btrim(v_ip) = '' then null else md5(btrim(v_ip)) end;
  if v_h is not null and (select count(*) from public.diagnosticos
        where ip_hash = v_h and criado_em > now() - interval '1 hour') >= 5 then
    raise exception 'Demasiados envios. Tente novamente mais tarde.';
  end if;
  insert into public.diagnosticos (curso, nivel, nivel_nome, confianca, pct, respondidas, certas, nome, telefone, ip_hash)
  values (p_curso, p_nivel::smallint, left(btrim(coalesce(p_nivel_nome, '')), 40), p_confianca::smallint, p_pct,
          p_respondidas::smallint, p_certas::smallint, left(btrim(p_nome), 80), left(btrim(p_telefone), 20), v_h);
end $$;

revoke execute on function public.registar_diagnostico(text, int, text, int, jsonb, int, int, text, text, text) from public, anon;
grant execute on function public.registar_diagnostico(text, int, text, int, jsonb, int, int, text, text, text) to anon, authenticated;

-- Limite de uso da IA (usado só pela Edge Function, com a chave de serviço; ninguém mais lê isto)
create table if not exists public.diag_ia_uso (
  id        bigint generated always as identity primary key,
  ip_hash   text not null,
  criado_em timestamptz not null default now()
);
create index if not exists diag_ia_uso_ip on public.diag_ia_uso (ip_hash, criado_em desc);
alter table public.diag_ia_uso enable row level security;       -- sem policies: só a service_role entra
revoke all on public.diag_ia_uso from anon, authenticated;
