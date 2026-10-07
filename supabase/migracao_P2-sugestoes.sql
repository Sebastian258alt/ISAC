-- =====================================================================
--  PORTAL ISAC · P2 · Comentários e sugestões (site público + moderação)
--  Como usar: Supabase → SQL Editor → New query → colar tudo → Run.
--  Pré-requisito: schema.sql já executado. Pode correr mais de uma vez.
--
--  Quem visita o site (sem login) só consegue ENVIAR (função enviar_sugestao) e
--  LER os comentários já publicados (função comentarios_publicos). A tabela em si
--  só é visível à administração. Um comentário só aparece no site se o autor
--  autorizou a publicação E a administração o publicou.
-- =====================================================================

create table if not exists public.sugestoes (
  id         uuid primary key default gen_random_uuid(),
  tipo       text not null default 'sugestao' check (tipo in ('comentario','sugestao','elogio','reclamacao')),
  nome       text check (char_length(nome) <= 60),
  contacto   text check (char_length(contacto) <= 80),   -- só para a administração responder; nunca é público
  mensagem   text not null check (char_length(btrim(mensagem)) between 10 and 1000),
  avaliacao  smallint check (avaliacao between 1 and 5),
  publicar   boolean not null default false,             -- o autor autorizou a publicação
  estado     text not null default 'nova' check (estado in ('nova','lida','publicada','arquivada')),
  ip_hash    text,                                        -- só para limitar abusos; não é o IP
  criado_em  timestamptz not null default now(),
  check (estado <> 'publicada' or publicar)               -- nunca se publica sem autorização
);
create index if not exists sugestoes_estado on public.sugestoes (estado, criado_em desc);
create index if not exists sugestoes_ip on public.sugestoes (ip_hash, criado_em desc);

alter table public.sugestoes enable row level security;
drop policy if exists sug_ver on public.sugestoes;
create policy sug_ver on public.sugestoes for select to authenticated using (public.e_admin());
drop policy if exists sug_alterar on public.sugestoes;
create policy sug_alterar on public.sugestoes for update to authenticated
  using (public.e_admin()) with check (public.e_admin());
drop policy if exists sug_apagar on public.sugestoes;
create policy sug_apagar on public.sugestoes for delete to authenticated using (public.e_admin());

revoke all on public.sugestoes from anon, authenticated;
grant select, update, delete on public.sugestoes to authenticated;   -- inserir só pela função abaixo

drop trigger if exists aud_sugestoes on public.sugestoes;
create trigger aud_sugestoes after update or delete on public.sugestoes
  for each row execute function public.auditar();

-- Envio público. Defesas: campo-isco (p_site), limites de tamanho e no máximo
-- 3 envios por hora por origem (guarda-se só um resumo do IP).
create or replace function public.enviar_sugestao(
  p_tipo text, p_nome text, p_contacto text, p_mensagem text,
  p_avaliacao int default null, p_publicar boolean default false, p_site text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare v_ip text; v_h text;
begin
  if coalesce(p_site, '') <> '' then return; end if;            -- robô: ignora em silêncio
  if p_tipo not in ('comentario','sugestao','elogio','reclamacao') then raise exception 'Tipo inválido.'; end if;
  if char_length(btrim(coalesce(p_mensagem, ''))) < 10 then raise exception 'Escreva pelo menos 10 caracteres.'; end if;
  if char_length(p_mensagem) > 1000 then raise exception 'A mensagem é demasiado longa (máx. 1000 caracteres).'; end if;
  if p_avaliacao is not null and (p_avaliacao < 1 or p_avaliacao > 5) then raise exception 'Avaliação inválida.'; end if;
  begin
    v_ip := split_part(coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', ''), ',', 1);
  exception when others then v_ip := ''; end;
  v_h := case when btrim(v_ip) = '' then null else md5(btrim(v_ip)) end;
  if v_h is not null and (select count(*) from public.sugestoes
        where ip_hash = v_h and criado_em > now() - interval '1 hour') >= 3 then
    raise exception 'Demasiados envios. Tente novamente mais tarde.';
  end if;
  insert into public.sugestoes (tipo, nome, contacto, mensagem, avaliacao, publicar, ip_hash)
  values (p_tipo, nullif(left(btrim(coalesce(p_nome, '')), 60), ''), nullif(left(btrim(coalesce(p_contacto, '')), 80), ''),
          btrim(p_mensagem), p_avaliacao::smallint, coalesce(p_publicar, false), v_h);
end $$;

-- Comentários publicados (sem contacto, sem estado interno)
create or replace function public.comentarios_publicos()
returns table (nome text, tipo text, mensagem text, avaliacao smallint, criado_em timestamptz)
language sql stable security definer set search_path = '' as $$
  select coalesce(s.nome, 'Anónimo'), s.tipo, s.mensagem, s.avaliacao, s.criado_em
    from public.sugestoes s where s.estado = 'publicada' and s.publicar
   order by s.criado_em desc limit 12
$$;

revoke execute on function public.enviar_sugestao(text, text, text, text, int, boolean, text),
  public.comentarios_publicos() from public, anon;
grant execute on function public.enviar_sugestao(text, text, text, text, int, boolean, text),
  public.comentarios_publicos() to anon, authenticated;
