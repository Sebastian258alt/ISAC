-- =====================================================================
--  PORTAL ISAC · Esquema da base de dados (Supabase / PostgreSQL)
--  Como usar: Supabase → SQL Editor → New query → colar tudo → Run.
--  Executar UMA só vez, num projecto novo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELAS
-- ---------------------------------------------------------------------

-- Um perfil por conta de login. Todos começam como aluno INACTIVO:
-- só a administração pode activar contas e mudar o papel.
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  nome            text not null default '',
  email           text,
  papel           text not null default 'aluno' check (papel in ('aluno','professor','admin')),
  activo          boolean not null default false,
  telefone        text,
  encarregado     text,          -- nome do encarregado de educação (alunos menores)
  encarregado_tel text,
  criado_em       timestamptz not null default now()
);

create table public.cursos (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null unique,
  descricao      text,
  taxa_matricula numeric(12,2) not null default 0 check (taxa_matricula >= 0),
  propina_mensal numeric(12,2) not null default 0 check (propina_mensal >= 0),
  activo         boolean not null default true
);

create table public.turmas (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid not null references public.cursos(id) on delete restrict,
  nome         text not null,
  horario      text,
  professor_id uuid references public.profiles(id) on delete set null,
  activa       boolean not null default true,
  unique (curso_id, nome)
);

create table public.matriculas (
  id       uuid primary key default gen_random_uuid(),
  aluno_id uuid not null references public.profiles(id) on delete restrict,
  turma_id uuid not null references public.turmas(id) on delete restrict,
  data     date not null default current_date,
  estado   text not null default 'activa' check (estado in ('activa','concluida','desistiu')),
  unique (aluno_id, turma_id)
);

-- Uma linha por matrícula. Média = 30% teste escrito + 30% oral + 40% teste final
-- (regra de exemplo do protótipo; alterar aqui se a direcção definir outra).
create table public.avaliacoes (
  matricula_id  uuid primary key references public.matriculas(id) on delete cascade,
  t1            numeric(4,1) check (t1 between 0 and 20),
  t2            numeric(4,1) check (t2 between 0 and 20),
  ex            numeric(4,1) check (ex between 0 and 20),
  media         numeric(4,1) generated always as (round((t1*0.3 + t2*0.3 + ex*0.4)::numeric, 1)) stored,
  actualizado_em timestamptz not null default now()
);

create table public.faltas (
  id           uuid primary key default gen_random_uuid(),
  matricula_id uuid not null references public.matriculas(id) on delete cascade,
  data         date not null,
  justificada  boolean not null default false,
  unique (matricula_id, data)
);

-- Valores a pagar (taxa de matrícula e propinas mensais)
create table public.cobrancas (
  id             uuid primary key default gen_random_uuid(),
  matricula_id   uuid not null references public.matriculas(id) on delete cascade,
  tipo           text not null check (tipo in ('matricula','propina')),
  referencia_mes date,             -- 1.º dia do mês (só nas propinas)
  valor          numeric(12,2) not null check (valor >= 0),
  vencimento     date not null,
  check ((tipo = 'propina') = (referencia_mes is not null))
);
create unique index cobrancas_unica on public.cobrancas
  (matricula_id, tipo, coalesce(referencia_mes, date '1900-01-01'));

-- Dinheiro recebido (pode haver pagamentos parciais)
create table public.pagamentos (
  id          uuid primary key default gen_random_uuid(),
  cobranca_id uuid not null references public.cobrancas(id) on delete restrict,
  valor       numeric(12,2) not null check (valor > 0),
  data        date not null default current_date,
  metodo      text not null default 'numerario'
              check (metodo in ('numerario','mpesa','emola','mkesh','transferencia','outro')),
  referencia  text,
  recebido_por uuid references public.profiles(id) on delete set null default auth.uid(),
  criado_em   timestamptz not null default now()
);

create table public.auditoria (
  id              bigint generated always as identity primary key,
  quando          timestamptz not null default now(),
  utilizador_id   uuid,
  utilizador_nome text,
  tabela          text not null,
  accao           text not null,
  registo_id      text,
  detalhe         jsonb
);

create index on public.matriculas (aluno_id);
create index on public.matriculas (turma_id);
create index on public.faltas (matricula_id);
create index on public.cobrancas (matricula_id);
create index on public.pagamentos (cobranca_id);
create index on public.auditoria (quando desc);

-- ---------------------------------------------------------------------
-- 2. FUNÇÕES DE APOIO (usadas pelas regras de segurança)
--    security definer: correm com os direitos do dono, para não entrarem
--    em ciclo com as próprias regras.
-- ---------------------------------------------------------------------

create function public.papel_actual() returns text
language sql stable security definer set search_path = '' as $$
  select papel from public.profiles where id = auth.uid() and activo
$$;

create function public.e_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select papel = 'admin' from public.profiles where id = auth.uid() and activo), false)
$$;

create function public.professor_da_turma(t uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.papel_actual() = 'professor', false)
     and exists (select 1 from public.turmas where id = t and professor_id = auth.uid())
$$;

create function public.professor_ve_aluno(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.papel_actual() = 'professor', false)
     and exists (select 1 from public.matriculas m join public.turmas t on t.id = m.turma_id
                 where m.aluno_id = a and t.professor_id = auth.uid())
$$;

-- Pode lançar notas/faltas nesta matrícula? (admin ou formador da turma)
create function public.pode_lancar(m uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.e_admin()
      or (coalesce(public.papel_actual() = 'professor', false)
          and exists (select 1 from public.matriculas mt join public.turmas t on t.id = mt.turma_id
                      where mt.id = m and t.professor_id = auth.uid()))
$$;

create function public.aluno_da_matricula(m uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.papel_actual() = 'aluno', false)
     and exists (select 1 from public.matriculas where id = m and aluno_id = auth.uid())
$$;

create function public.pode_ver_matricula(m uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.pode_lancar(m) or public.aluno_da_matricula(m)
$$;

create function public.aluno_da_cobranca(c uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.cobrancas x where x.id = c and public.aluno_da_matricula(x.matricula_id))
$$;

-- ---------------------------------------------------------------------
-- 3. SEGURANÇA POR LINHA (RLS)
--    Isto é o que impede um aluno de ver notas de outro, mesmo que alguém
--    altere o código do site no navegador.
-- ---------------------------------------------------------------------

alter table public.profiles   enable row level security;
alter table public.cursos     enable row level security;
alter table public.turmas     enable row level security;
alter table public.matriculas enable row level security;
alter table public.avaliacoes enable row level security;
alter table public.faltas     enable row level security;
alter table public.cobrancas  enable row level security;
alter table public.pagamentos enable row level security;
alter table public.auditoria  enable row level security;

-- profiles: cada um vê o seu; admin vê todos; formador vê os seus alunos.
-- Só a administração altera (papel, activo...). Ninguém apaga/insere pela API.
create policy profiles_ver on public.profiles for select to authenticated
  using (id = auth.uid() or public.e_admin() or public.professor_ve_aluno(id));
create policy profiles_alterar on public.profiles for update to authenticated
  using (public.e_admin()) with check (public.e_admin());

-- cursos e turmas: qualquer conta activa lê; só admin escreve
create policy cursos_ver on public.cursos for select to authenticated
  using (public.papel_actual() is not null);
create policy cursos_escrever on public.cursos for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

create policy turmas_ver on public.turmas for select to authenticated
  using (public.papel_actual() is not null);
create policy turmas_escrever on public.turmas for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

-- matrículas: admin tudo; aluno as suas; formador as da sua turma. Só admin escreve.
create policy matriculas_ver on public.matriculas for select to authenticated
  using (public.e_admin()
         or (aluno_id = auth.uid() and public.papel_actual() = 'aluno')
         or public.professor_da_turma(turma_id));
create policy matriculas_escrever on public.matriculas for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

-- avaliações e faltas: ver = admin/formador da turma/o próprio aluno; lançar = admin/formador da turma
create policy avaliacoes_ver on public.avaliacoes for select to authenticated
  using (public.pode_ver_matricula(matricula_id));
create policy avaliacoes_inserir on public.avaliacoes for insert to authenticated
  with check (public.pode_lancar(matricula_id));
create policy avaliacoes_alterar on public.avaliacoes for update to authenticated
  using (public.pode_lancar(matricula_id)) with check (public.pode_lancar(matricula_id));
create policy avaliacoes_apagar on public.avaliacoes for delete to authenticated
  using (public.e_admin());

create policy faltas_ver on public.faltas for select to authenticated
  using (public.pode_ver_matricula(matricula_id));
create policy faltas_inserir on public.faltas for insert to authenticated
  with check (public.pode_lancar(matricula_id));
create policy faltas_alterar on public.faltas for update to authenticated
  using (public.pode_lancar(matricula_id)) with check (public.pode_lancar(matricula_id));
create policy faltas_apagar on public.faltas for delete to authenticated
  using (public.pode_lancar(matricula_id));

-- finanças: admin vê e escreve; aluno só vê as suas; formador NÃO vê nada
create policy cobrancas_ver on public.cobrancas for select to authenticated
  using (public.e_admin() or public.aluno_da_matricula(matricula_id));
create policy cobrancas_escrever on public.cobrancas for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

create policy pagamentos_ver on public.pagamentos for select to authenticated
  using (public.e_admin() or public.aluno_da_cobranca(cobranca_id));
create policy pagamentos_escrever on public.pagamentos for all to authenticated
  using (public.e_admin()) with check (public.e_admin());

-- auditoria: só admin lê; ninguém escreve pela API (só os gatilhos abaixo)
create policy auditoria_ver on public.auditoria for select to authenticated
  using (public.e_admin());

-- ---------------------------------------------------------------------
-- 4. GATILHOS
-- ---------------------------------------------------------------------

-- 4.1 Nova conta -> perfil de aluno INACTIVO (o papel nunca vem do navegador)
create function public.novo_utilizador() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, nome, email)
  values (new.id,
          coalesce(nullif(trim(new.raw_user_meta_data->>'nome'), ''), split_part(new.email, '@', 1)),
          new.email);
  return new;
end $$;

create trigger ao_criar_utilizador after insert on auth.users
  for each row execute function public.novo_utilizador();

-- 4.2 Auditoria automática: quem, quando, o quê (antes/depois)
create function public.auditar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_nome text;
  v_reg  jsonb := to_jsonb(coalesce(new, old));
  v_det  jsonb;
begin
  select nome into v_nome from public.profiles where id = auth.uid();
  v_det := case tg_op
    when 'INSERT' then jsonb_build_object('depois', to_jsonb(new))
    when 'UPDATE' then jsonb_build_object('antes', to_jsonb(old), 'depois', to_jsonb(new))
    else jsonb_build_object('antes', to_jsonb(old)) end;
  insert into public.auditoria (utilizador_id, utilizador_nome, tabela, accao, registo_id, detalhe)
  values (auth.uid(), coalesce(v_nome, 'sistema'), tg_table_name, tg_op,
          coalesce(v_reg->>'id', v_reg->>'matricula_id'), v_det);
  return coalesce(new, old);
end $$;

create trigger aud_profiles   after insert or update or delete on public.profiles   for each row execute function public.auditar();
create trigger aud_cursos     after insert or update or delete on public.cursos     for each row execute function public.auditar();
create trigger aud_turmas     after insert or update or delete on public.turmas     for each row execute function public.auditar();
create trigger aud_matriculas after insert or update or delete on public.matriculas for each row execute function public.auditar();
create trigger aud_avaliacoes after insert or update or delete on public.avaliacoes for each row execute function public.auditar();
create trigger aud_faltas     after insert or update or delete on public.faltas     for each row execute function public.auditar();
create trigger aud_cobrancas  after insert or update or delete on public.cobrancas  for each row execute function public.auditar();
create trigger aud_pagamentos after insert or update or delete on public.pagamentos for each row execute function public.auditar();

-- 4.3 Data de actualização das avaliações
create function public.marcar_actualizacao() returns trigger language plpgsql as $$
begin new.actualizado_em := now(); return new; end $$;
create trigger av_actualizacao before update on public.avaliacoes
  for each row execute function public.marcar_actualizacao();

-- 4.4 Um pagamento nunca pode exceder o que falta pagar
create function public.verificar_pagamento() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_valor numeric; v_pago numeric;
begin
  select valor into v_valor from public.cobrancas where id = new.cobranca_id;
  select coalesce(sum(valor), 0) into v_pago from public.pagamentos
   where cobranca_id = new.cobranca_id and id is distinct from new.id;
  if v_pago + new.valor > v_valor then
    raise exception 'O pagamento excede o valor em falta (% MT).', to_char(v_valor - v_pago, 'FM999G999G990D00');
  end if;
  return new;
end $$;
create trigger pag_verificar before insert or update on public.pagamentos
  for each row execute function public.verificar_pagamento();

-- 4.5 [P0-3] Defesa em profundidade em profiles. Mesmo que um dia alguém acrescente
--     uma policy do tipo "auth.uid() = id", ninguém que não seja admin activo consegue
--     mudar papel, activo, email, criado_em; ninguém muda o id; e a API não consegue
--     remover o último admin activo. SQL Editor / service_role (auth.uid() nulo e
--     fora dos papéis da API) não são afectados: é assim que se cria o 1.º admin.
--     (Função SEM security definer de propósito: current_user é o papel da API.)
create function public.proteger_profiles() returns trigger
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
create trigger proteger_profiles before update on public.profiles
  for each row execute function public.proteger_profiles();

-- 4.6 [P0-3] Quem recebeu o pagamento é sempre quem está autenticado (não vem do navegador)
create function public.definir_recebido_por() returns trigger
language plpgsql set search_path = '' as $$
begin
  if auth.uid() is not null then new.recebido_por := auth.uid(); end if;
  return new;
end $$;
create trigger pag_recebido_por before insert on public.pagamentos
  for each row execute function public.definir_recebido_por();

-- ---------------------------------------------------------------------
-- 5. VISTA DE COBRANÇAS (com estado calculado). Respeita a segurança por linha.
-- ---------------------------------------------------------------------
create view public.v_cobrancas with (security_invoker = true) as
select c.id, c.matricula_id, c.tipo, c.referencia_mes, c.valor, c.vencimento,
       coalesce(sum(p.valor), 0)::numeric(12,2)                 as pago,
       (c.valor - coalesce(sum(p.valor), 0))::numeric(12,2)     as em_falta,
       case when coalesce(sum(p.valor), 0) >= c.valor then 'pago'
            when c.vencimento < current_date               then 'em_atraso'
            when coalesce(sum(p.valor), 0) > 0             then 'parcial'
            else 'pendente' end                                  as estado
from public.cobrancas c
left join public.pagamentos p on p.cobranca_id = c.id
group by c.id;

-- ---------------------------------------------------------------------
-- 6. FUNÇÕES CHAMADAS PELO PORTAL (só administração)
-- ---------------------------------------------------------------------

-- Gera propinas mensais (vencem no dia 10). Continua a partir do último mês já gerado.
create function public.gerar_propinas(p_matricula uuid, p_meses int, p_inicio date default null)
returns int language plpgsql security definer set search_path = '' as $$
declare v_valor numeric; v_mes date; v_n int := 0; i int;
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode gerar propinas.'; end if;
  if p_meses < 1 or p_meses > 24 then raise exception 'Número de meses inválido (1 a 24).'; end if;
  select c.propina_mensal into v_valor
    from public.matriculas m join public.turmas t on t.id = m.turma_id join public.cursos c on c.id = t.curso_id
   where m.id = p_matricula;
  if not found then raise exception 'Matrícula não encontrada.'; end if;
  if v_valor <= 0 then return 0; end if;
  v_mes := coalesce(
    (select max(referencia_mes) + interval '1 month' from public.cobrancas
      where matricula_id = p_matricula and tipo = 'propina'),
    date_trunc('month', coalesce(p_inicio, current_date)))::date;
  for i in 1..p_meses loop
    insert into public.cobrancas (matricula_id, tipo, referencia_mes, valor, vencimento)
    values (p_matricula, 'propina', v_mes, v_valor, v_mes + 9)
    on conflict do nothing;
    v_mes := (v_mes + interval '1 month')::date;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- Matricula um aluno: cria a matrícula, a taxa de matrícula e as propinas
create function public.matricular(p_aluno uuid, p_turma uuid, p_meses int default 10, p_inicio date default current_date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_mat uuid; v_taxa numeric;
begin
  if not public.e_admin() then raise exception 'Apenas a administração pode matricular alunos.'; end if;
  if not exists (select 1 from public.profiles where id = p_aluno and papel = 'aluno' and activo) then
    raise exception 'O utilizador escolhido não é um aluno activo.';
  end if;
  select c.taxa_matricula into v_taxa
    from public.turmas t join public.cursos c on c.id = t.curso_id where t.id = p_turma;
  if not found then raise exception 'Turma não encontrada.'; end if;
  if exists (select 1 from public.matriculas where aluno_id = p_aluno and turma_id = p_turma) then
    raise exception 'Este aluno já está matriculado nesta turma.';
  end if;
  insert into public.matriculas (aluno_id, turma_id, data) values (p_aluno, p_turma, p_inicio)
    returning id into v_mat;
  if v_taxa > 0 then
    insert into public.cobrancas (matricula_id, tipo, valor, vencimento) values (v_mat, 'matricula', v_taxa, p_inicio);
  end if;
  if p_meses > 0 then perform public.gerar_propinas(v_mat, p_meses, p_inicio); end if;
  return v_mat;
end $$;

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

-- ---------------------------------------------------------------------
-- 7. PERMISSÕES
--    A chave pública (anon) não pode tocar em nada. Só contas com login.
-- ---------------------------------------------------------------------
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
