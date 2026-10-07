-- =====================================================================
--  ISAC · P0-3 · Testes de escalação de privilégios (acesso DIRECTO à base)
--
--  Como usar:  psql "$DATABASE_URL" -f supabase/testes_P0-3.sql
--  * Correr num projecto de TESTE / cópia local, NUNCA na produção.
--  * Tudo corre dentro de uma transacção e termina em ROLLBACK: não deixa
--    nada gravado (utilizadores, notas, auditoria de teste, etc.).
--  * Cada teste finge ser um utilizador da mesma forma que o PostgREST
--    (API do Supabase) faz: SET ROLE authenticated/anon + JWT com o "sub".
--    Ou seja, é o equivalente a chamar a API com a chave anon + o token
--    desse utilizador — sem passar pelo portal.html.
--
--  Regra de leitura de cada linha:
--    BLOQUEADO = erro do PostgreSQL OU 0 linhas afectadas/visíveis
--    PERMITIDO = sem erro e pelo menos 1 linha
-- =====================================================================
\set ON_ERROR_STOP on
\pset pager off
begin;

create schema t;
grant usage on schema t to public;
create table t.ids (nome text primary key, id uuid not null);
grant select on t.ids to public;
create table t.res (n serial, id text, descr text, esperado text, obtido text, ok boolean);
create function t.u(p_nome text) returns uuid language sql stable as $$ select id from t.ids where nome = p_nome $$;
grant execute on function t.u(text) to public;

-- Executa p_sql como p_role com JWT sub = p_uid. Devolve nº de linhas ou 'ERR:...'
create function t.run(p_uid uuid, p_role text, p_sql text) returns text language plpgsql as $$
declare n bigint; o text; r record;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  execute format('set local role %I', p_role);
  begin
    if p_sql ~* '^\s*(select|with)' then
      n := 0;
      for r in execute p_sql loop n := n + 1; end loop;
    else
      execute p_sql; get diagnostics n = row_count;
    end if;
    o := n::text;
  exception when others then o := 'ERR:' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claim.sub', '', true);
  return o;
end $$;

-- expect: 'BLOQUEADO' | 'PERMITIDO' | 'N=<n>'
create function t.chk(p_id text, p_descr text, p_quem text, p_sql text, p_expect text) returns void language plpgsql as $$
declare o text; ok boolean;
begin
  o := t.run(case when p_quem = 'anon' then null else t.u(p_quem) end,
             case when p_quem = 'anon' then 'anon' else 'authenticated' end, p_sql);
  ok := case p_expect
          when 'BLOQUEADO' then (o like 'ERR:%' or o = '0')
          when 'PERMITIDO' then (o not like 'ERR:%' and o::bigint > 0)
          else (o = substr(p_expect, 3)) end;
  insert into t.res (id, descr, esperado, obtido, ok) values (p_id, p_descr, p_expect, left(o, 70), ok);
end $$;

-- ---------------------------------------------------------------------
-- SEED (como dono da base = equivalente ao SQL Editor)
-- ---------------------------------------------------------------------
insert into t.ids values
  ('admin','a0000000-0000-0000-0000-000000000001'),('prof1','a0000000-0000-0000-0000-000000000002'),
  ('prof2','a0000000-0000-0000-0000-000000000003'),('alu1','a0000000-0000-0000-0000-000000000004'),
  ('alu2','a0000000-0000-0000-0000-000000000005'),('pend','a0000000-0000-0000-0000-000000000006'),
  ('prof3x','a0000000-0000-0000-0000-000000000007'),('adminx','a0000000-0000-0000-0000-000000000008');
insert into auth.users (id, email) select id, nome || '@teste.local' from t.ids;
update public.profiles set papel='admin',     activo=true  where id = t.u('admin');
update public.profiles set papel='professor', activo=true  where id in (t.u('prof1'), t.u('prof2'), t.u('prof3x'));
update public.profiles set papel='aluno',     activo=true  where id in (t.u('alu1'), t.u('alu2'));
update public.profiles set papel='admin',     activo=true  where id = t.u('adminx');
update public.profiles set activo=false where id in (t.u('prof3x'), t.u('adminx'));   -- contas DESACTIVADAS
-- 'pend' fica como nasce: aluno inactivo (auto-registo)

insert into public.cursos (id, nome, taxa_matricula, propina_mensal) values ('c0000000-0000-0000-0000-000000000001','Curso Teste',100,50);
insert into public.turmas (id, curso_id, nome, professor_id) values
  ('70000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','T1', t.u('prof1')),
  ('70000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','T2', t.u('prof2')),
  ('70000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','T3', t.u('prof3x'));
insert into public.matriculas (id, aluno_id, turma_id) values
  ('b0000000-0000-0000-0000-000000000001', t.u('alu1'), '70000000-0000-0000-0000-000000000001'),   -- M1: alu1 em T1 (prof1)
  ('b0000000-0000-0000-0000-000000000002', t.u('alu2'), '70000000-0000-0000-0000-000000000002'),   -- M2: alu2 em T2 (prof2)
  ('b0000000-0000-0000-0000-000000000003', t.u('alu2'), '70000000-0000-0000-0000-000000000003');   -- M3: alu2 em T3 (prof3x desactivado)
insert into public.avaliacoes (matricula_id, t1, t2, ex) values
  ('b0000000-0000-0000-0000-000000000001',10,10,10),('b0000000-0000-0000-0000-000000000002',12,12,12),('b0000000-0000-0000-0000-000000000003',14,14,14);
insert into public.faltas (id, matricula_id, data) values
  ('f0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','2026-01-10'),
  ('f0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','2026-01-10');
insert into public.cobrancas (id, matricula_id, tipo, valor, vencimento) values
  ('d0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','matricula',100,'2026-01-01'),
  ('d0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','matricula',100,'2026-01-01');
insert into public.pagamentos (id, cobranca_id, valor) values
  ('e0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001',30),
  ('e0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002',30);

\o /dev/null
-- =====================================================================
-- ANON (chave pública, sem login)
-- =====================================================================
select t.chk('N1','anon lê profiles','anon',$s$select * from public.profiles$s$,'BLOQUEADO');
select t.chk('N2','anon lê cursos','anon',$s$select * from public.cursos$s$,'BLOQUEADO');
select t.chk('N3','anon chama RPC matricular','anon',$s$select public.matricular(t.u('alu1'),'70000000-0000-0000-0000-000000000001')$s$,'BLOQUEADO');
select t.chk('N4','anon chama e_admin()','anon',$s$select public.e_admin()$s$,'BLOQUEADO');

-- =====================================================================
-- ALUNO (alu1: matrícula M1 em T1)  ·  pend = aluno inactivo (auto-registo)
-- =====================================================================
-- Teste A / B / C
select t.chk('A','[TESTE A] aluno: role -> admin (sobre si)','alu1',$s$update public.profiles set papel='admin' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('A2','aluno: role -> professor (sobre si)','alu1',$s$update public.profiles set papel='professor' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('B','[TESTE B] conta pendente: activo -> true (sobre si)','pend',$s$update public.profiles set activo=true where id=t.u('pend')$s$,'BLOQUEADO');
select t.chk('B2','aluno activo: tenta reactivar/alterar activo','alu1',$s$update public.profiles set activo=true where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('C','[TESTE C] aluno: role de OUTRO utilizador -> admin','alu1',$s$update public.profiles set papel='admin' where id=t.u('alu2')$s$,'BLOQUEADO');
select t.chk('C2','aluno: altera nome/telefone de outro','alu1',$s$update public.profiles set nome='x' where id=t.u('alu2')$s$,'BLOQUEADO');
select t.chk('A3','aluno: altera o próprio id (chave)','alu1',$s$update public.profiles set id=gen_random_uuid() where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('A4','aluno: INSERT em profiles com papel=admin','alu1',$s$insert into public.profiles (id,nome,papel,activo) values (gen_random_uuid(),'x','admin',true)$s$,'BLOQUEADO');
select t.chk('A5','aluno: INSERT profile com o próprio id e papel=admin','pend',$s$insert into public.profiles (id,nome,papel,activo) values (t.u('pend'),'x','admin',true)$s$,'BLOQUEADO');
select t.chk('A6','aluno: DELETE do próprio perfil','alu1',$s$delete from public.profiles where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('A7','aluno: DELETE do perfil de outro','alu1',$s$delete from public.profiles where id=t.u('alu2')$s$,'BLOQUEADO');
select t.chk('A8','aluno vê APENAS o próprio perfil','alu1',$s$select * from public.profiles$s$,'N=1');
select t.chk('A9','aluno vê as próprias matrículas','alu1',$s$select * from public.matriculas$s$,'N=1');
select t.chk('A10','aluno vê as próprias notas','alu1',$s$select * from public.avaliacoes$s$,'N=1');
select t.chk('A11','aluno vê as próprias faltas','alu1',$s$select * from public.faltas$s$,'N=1');
select t.chk('A12','aluno vê as próprias cobranças (v_cobrancas)','alu1',$s$select * from public.v_cobrancas$s$,'N=1');
select t.chk('A13','aluno vê os próprios pagamentos','alu1',$s$select * from public.pagamentos$s$,'N=1');
select t.chk('A14','aluno lê matrícula de outro aluno (por id)','alu1',$s$select * from public.matriculas where id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A15','aluno lê notas de outro','alu1',$s$select * from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A16','aluno lê faltas de outro','alu1',$s$select * from public.faltas where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A17','aluno lê cobranças de outro','alu1',$s$select * from public.cobrancas where id='d0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A18','aluno lê pagamentos de outro','alu1',$s$select * from public.pagamentos where id='e0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A19','aluno altera as próprias notas','alu1',$s$update public.avaliacoes set t1=20,t2=20,ex=20 where matricula_id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('A20','aluno cria notas','alu1',$s$insert into public.avaliacoes (matricula_id,t1) values ('b0000000-0000-0000-0000-000000000003',20)$s$,'BLOQUEADO');
select t.chk('A21','aluno apaga as próprias faltas','alu1',$s$delete from public.faltas where matricula_id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('A22','aluno cria falta','alu1',$s$insert into public.faltas (matricula_id,data) values ('b0000000-0000-0000-0000-000000000001','2026-02-02')$s$,'BLOQUEADO');
select t.chk('A23','aluno cria pagamento (própria cobrança)','alu1',$s$insert into public.pagamentos (cobranca_id,valor) values ('d0000000-0000-0000-0000-000000000001',10)$s$,'BLOQUEADO');
select t.chk('A24','aluno altera pagamento','alu1',$s$update public.pagamentos set valor=1 where id='e0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('A25','aluno elimina pagamento','alu1',$s$delete from public.pagamentos where id='e0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('A26','aluno altera cobrança (valor=0)','alu1',$s$update public.cobrancas set valor=0 where id='d0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('A27','aluno cria matrícula para si','alu1',$s$insert into public.matriculas (aluno_id,turma_id) values (t.u('alu1'),'70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('A28','aluno altera matrícula de outro','alu1',$s$update public.matriculas set estado='desistiu' where id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('A29','aluno altera a própria matrícula','alu1',$s$update public.matriculas set estado='concluida' where id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('I','[TESTE I] aluno: RPC administrativa matricular()','alu1',$s$select public.matricular(t.u('alu1'),'70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('I2','aluno: RPC administrativa gerar_propinas()','alu1',$s$select public.gerar_propinas('b0000000-0000-0000-0000-000000000001',3)$s$,'BLOQUEADO');
select t.chk('A30','aluno: RPC nomes_alunos_turma(turma alheia)','alu1',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('A31','aluno: RPC nomes_alunos_turma(a sua turma)','alu1',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000001')$s$,'BLOQUEADO');
select t.chk('A32','aluno escreve em cursos','alu1',$s$update public.cursos set propina_mensal=0$s$,'BLOQUEADO');
select t.chk('A33','aluno escreve em turmas','alu1',$s$update public.turmas set professor_id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('A34','aluno lê auditoria','alu1',$s$select * from public.auditoria$s$,'BLOQUEADO');
select t.chk('A35','aluno escreve em auditoria','alu1',$s$insert into public.auditoria (tabela,accao) values ('x','y')$s$,'BLOQUEADO');
select t.chk('A36','aluno apaga auditoria','alu1',$s$delete from public.auditoria$s$,'BLOQUEADO');
select t.chk('A37','aluno altera auditoria','alu1',$s$update public.auditoria set utilizador_nome='x'$s$,'BLOQUEADO');
select t.chk('A38','aluno TRUNCATE auditoria (privilégio de tabela)','alu1',$s$truncate public.auditoria$s$,'BLOQUEADO');
select t.chk('J','[TESTE J] aluno envia UUID alheio: pagamento p/ cobrança de outro','alu1',$s$insert into public.pagamentos (cobranca_id,valor,recebido_por) values ('d0000000-0000-0000-0000-000000000002',5,t.u('admin'))$s$,'BLOQUEADO');
-- Funções SECURITY DEFINER auxiliares chamadas directamente com parâmetros manipulados
select t.chk('H1','aluno chama pode_lancar(matrícula alheia)','alu1',$s$select 1 where public.pode_lancar('b0000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('H2','aluno chama e_admin()','alu1',$s$select 1 where public.e_admin()$s$,'BLOQUEADO');
select t.chk('H3','aluno chama professor_ve_aluno(outro aluno)','alu1',$s$select 1 where public.professor_ve_aluno(t.u('alu2'))$s$,'BLOQUEADO');
select t.chk('H4','aluno chama professor_da_turma(turma alheia)','alu1',$s$select 1 where public.professor_da_turma('70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('H5','aluno chama aluno_da_matricula(matrícula de outro)','alu1',$s$select 1 where public.aluno_da_matricula('b0000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('H6','aluno chama função de gatilho auditar() directamente','alu1',$s$select public.auditar()$s$,'BLOQUEADO');
select t.chk('H7','aluno chama novo_utilizador() directamente','alu1',$s$select public.novo_utilizador()$s$,'BLOQUEADO');

-- =====================================================================
-- PROFESSOR (prof1: T1 com alu1/M1)  ·  prof2: T2 com alu2/M2
-- =====================================================================
select t.chk('D','[TESTE D] professor: role -> admin (sobre si)','prof1',$s$update public.profiles set papel='admin' where id=t.u('prof1')$s$,'BLOQUEADO');
select t.chk('D2','professor: role de outro utilizador','prof1',$s$update public.profiles set papel='admin' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('D3','professor: activo de conta alheia','prof1',$s$update public.profiles set activo=true where id=t.u('pend')$s$,'BLOQUEADO');
select t.chk('D4','professor: INSERT profile admin','prof1',$s$insert into public.profiles (id,nome,papel,activo) values (gen_random_uuid(),'x','admin',true)$s$,'BLOQUEADO');
select t.chk('E','[TESTE E] professor atribui-se à turma T2','prof1',$s$update public.turmas set professor_id=t.u('prof1') where id='70000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('E2','professor atribui outro professor à sua turma','prof1',$s$update public.turmas set professor_id=t.u('prof2') where id='70000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('E3','professor cria turma para si','prof1',$s$insert into public.turmas (curso_id,nome,professor_id) values ('c0000000-0000-0000-0000-000000000001','ZZ',t.u('prof1'))$s$,'BLOQUEADO');
select t.chk('E4','professor altera cursos','prof1',$s$update public.cursos set propina_mensal=0$s$,'BLOQUEADO');
select t.chk('F','[TESTE F] professor vê aluno de OUTRA turma (profile)','prof1',$s$select * from public.profiles where id=t.u('alu2')$s$,'BLOQUEADO');
select t.chk('F2','professor vê matrículas de outra turma','prof1',$s$select * from public.matriculas where turma_id='70000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('F3','professor vê notas de outra turma','prof1',$s$select * from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('F4','professor vê faltas de outra turma','prof1',$s$select * from public.faltas where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('F5','[legítimo] professor vê aluno da SUA turma','prof1',$s$select * from public.profiles where id=t.u('alu1')$s$,'PERMITIDO');
select t.chk('F6','[legítimo] professor vê matrículas da SUA turma','prof1',$s$select * from public.matriculas where turma_id='70000000-0000-0000-0000-000000000001'$s$,'PERMITIDO');
select t.chk('F7','[legítimo] professor vê as suas turmas','prof1',$s$select * from public.turmas where professor_id=t.u('prof1')$s$,'PERMITIDO');
select t.chk('F8','professor vê só 1 profile de aluno + o próprio (2)','prof1',$s$select * from public.profiles$s$,'N=2');
select t.chk('G','[TESTE G] professor consulta pagamentos','prof1',$s$select * from public.pagamentos$s$,'BLOQUEADO');
select t.chk('G2','professor consulta cobranças','prof1',$s$select * from public.cobrancas$s$,'BLOQUEADO');
select t.chk('G3','professor consulta v_cobrancas','prof1',$s$select * from public.v_cobrancas$s$,'BLOQUEADO');
select t.chk('G4','professor cria pagamento (cobrança do seu aluno)','prof1',$s$insert into public.pagamentos (cobranca_id,valor) values ('d0000000-0000-0000-0000-000000000001',10)$s$,'BLOQUEADO');
select t.chk('G5','professor cria cobrança','prof1',$s$insert into public.cobrancas (matricula_id,tipo,valor,vencimento) values ('b0000000-0000-0000-0000-000000000001','matricula',1,'2026-01-01')$s$,'BLOQUEADO');
select t.chk('G6','professor apaga pagamento','prof1',$s$delete from public.pagamentos$s$,'BLOQUEADO');
select t.chk('G7','professor cria/altera matrícula','prof1',$s$update public.matriculas set estado='desistiu' where id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('P1','[legítimo] professor lança notas na SUA turma','prof1',$s$update public.avaliacoes set t1=15 where matricula_id='b0000000-0000-0000-0000-000000000001'$s$,'PERMITIDO');
select t.chk('P2','professor lança notas em turma ALHEIA (UPDATE)','prof1',$s$update public.avaliacoes set t1=20 where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('P3','professor lança notas com matricula_id alheio (INSERT/upsert)','prof1',$s$insert into public.avaliacoes (matricula_id,t1) values ('b0000000-0000-0000-0000-000000000003',20) on conflict (matricula_id) do update set t1=20$s$,'BLOQUEADO');
select t.chk('P4','professor move a própria nota para matrícula alheia','prof1',$s$update public.avaliacoes set matricula_id='b0000000-0000-0000-0000-000000000002' where matricula_id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('P5','[legítimo] professor marca falta na SUA turma','prof1',$s$insert into public.faltas (matricula_id,data) values ('b0000000-0000-0000-0000-000000000001','2026-02-02')$s$,'PERMITIDO');
select t.chk('P6','professor marca falta em turma ALHEIA','prof1',$s$insert into public.faltas (matricula_id,data) values ('b0000000-0000-0000-0000-000000000002','2026-02-02')$s$,'BLOQUEADO');
select t.chk('P7','professor apaga falta de turma ALHEIA','prof1',$s$delete from public.faltas where id='f0000000-0000-0000-0000-000000000002'$s$,'BLOQUEADO');
select t.chk('P8','[legítimo] professor retira falta da SUA turma','prof1',$s$delete from public.faltas where id='f0000000-0000-0000-0000-000000000001'$s$,'PERMITIDO');
select t.chk('P9','professor apaga notas (só admin)','prof1',$s$delete from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000001'$s$,'BLOQUEADO');
select t.chk('P10','[legítimo] RPC nomes_alunos_turma(SUA turma)','prof1',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000001')$s$,'N=1');
select t.chk('P11','RPC nomes_alunos_turma(turma ALHEIA)','prof1',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('P12','professor: RPC matricular()','prof1',$s$select public.matricular(t.u('alu1'),'70000000-0000-0000-0000-000000000001')$s$,'BLOQUEADO');
select t.chk('P13','professor: RPC gerar_propinas()','prof1',$s$select public.gerar_propinas('b0000000-0000-0000-0000-000000000001',3)$s$,'BLOQUEADO');
select t.chk('P14','professor lê auditoria','prof1',$s$select * from public.auditoria$s$,'BLOQUEADO');
select t.chk('P15','professor chama pode_lancar(matrícula alheia)','prof1',$s$select 1 where public.pode_lancar('b0000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');

-- =====================================================================
-- CONTAS DESACTIVADAS / PENDENTES  (Teste H do enunciado)
-- =====================================================================
select t.chk('K','[TESTE H] admin DESACTIVADO chama RPC matricular()','adminx',$s$select public.matricular(t.u('alu1'),'70000000-0000-0000-0000-000000000002')$s$,'BLOQUEADO');
select t.chk('K2','admin DESACTIVADO chama RPC gerar_propinas()','adminx',$s$select public.gerar_propinas('b0000000-0000-0000-0000-000000000001',3)$s$,'BLOQUEADO');
select t.chk('K3','admin DESACTIVADO altera papéis','adminx',$s$update public.profiles set papel='admin' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('K4','admin DESACTIVADO activa contas','adminx',$s$update public.profiles set activo=true where id=t.u('pend')$s$,'BLOQUEADO');
select t.chk('K5','admin DESACTIVADO lê auditoria','adminx',$s$select * from public.auditoria$s$,'BLOQUEADO');
select t.chk('K6','admin DESACTIVADO lê pagamentos','adminx',$s$select * from public.pagamentos$s$,'BLOQUEADO');
select t.chk('K7','admin DESACTIVADO cria curso','adminx',$s$insert into public.cursos (nome) values ('x')$s$,'BLOQUEADO');
select t.chk('K8','admin DESACTIVADO chama e_admin()','adminx',$s$select 1 where public.e_admin()$s$,'BLOQUEADO');
select t.chk('K9','admin DESACTIVADO ainda vê o próprio perfil (necessário p/ ecrã "a aguardar")','adminx',$s$select * from public.profiles$s$,'N=1');
select t.chk('L','professor DESACTIVADO lança notas na turma que tinha','prof3x',$s$update public.avaliacoes set t1=20 where matricula_id='b0000000-0000-0000-0000-000000000003'$s$,'BLOQUEADO');
select t.chk('L2','professor DESACTIVADO marca falta','prof3x',$s$insert into public.faltas (matricula_id,data) values ('b0000000-0000-0000-0000-000000000003','2026-03-03')$s$,'BLOQUEADO');
select t.chk('L3','professor DESACTIVADO lê matrículas da turma','prof3x',$s$select * from public.matriculas$s$,'BLOQUEADO');
select t.chk('L4','professor DESACTIVADO chama nomes_alunos_turma()','prof3x',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000003')$s$,'BLOQUEADO');
select t.chk('L5','professor DESACTIVADO lê cursos/turmas','prof3x',$s$select * from public.turmas$s$,'BLOQUEADO');
select t.chk('L6','professor DESACTIVADO reactiva-se','prof3x',$s$update public.profiles set activo=true where id=t.u('prof3x')$s$,'BLOQUEADO');
select t.chk('Q','conta PENDENTE lê cursos','pend',$s$select * from public.cursos$s$,'BLOQUEADO');
select t.chk('Q2','conta PENDENTE lê matrículas/notas/pagamentos','pend',$s$select * from public.pagamentos$s$,'BLOQUEADO');
select t.chk('Q3','conta PENDENTE ainda vê o próprio perfil','pend',$s$select * from public.profiles$s$,'N=1');
select t.chk('Q4','conta PENDENTE chama RPC matricular()','pend',$s$select public.matricular(t.u('pend'),'70000000-0000-0000-0000-000000000001')$s$,'BLOQUEADO');

-- =====================================================================
-- DEFESA EM PROFUNDIDADE (Secção 3 do enunciado)
-- Simula o pior caso: alguém, no futuro, acrescenta uma policy "auth.uid() = id"
-- para deixar o utilizador editar o próprio perfil. Sem gatilho, isso abre a
-- escalação (papel/activo). Com o gatilho proteger_profiles() tem de continuar
-- BLOQUEADO nos campos críticos, mas PERMITIDO em nome/telefone.
-- =====================================================================
create policy _tmp_auto_edicao on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
select t.chk('X1','[policy auth.uid()=id] aluno: role -> admin','alu1',$s$update public.profiles set papel='admin' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('X2','[policy auth.uid()=id] conta pendente: activo -> true','pend',$s$update public.profiles set activo=true where id=t.u('pend')$s$,'BLOQUEADO');
select t.chk('X3','[policy auth.uid()=id] professor: role -> admin','prof1',$s$update public.profiles set papel='admin' where id=t.u('prof1')$s$,'BLOQUEADO');
select t.chk('X4','[policy auth.uid()=id] aluno: altera o próprio id','alu1',$s$update public.profiles set id=gen_random_uuid() where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('X5','[policy auth.uid()=id] aluno: altera o próprio email','alu1',$s$update public.profiles set email='admin@isac.local' where id=t.u('alu1')$s$,'BLOQUEADO');
select t.chk('X6','[policy auth.uid()=id] aluno: altera telefone (dado pessoal)','alu1',$s$update public.profiles set telefone='84 000 0000' where id=t.u('alu1')$s$,'PERMITIDO');
select t.chk('X7','[policy auth.uid()=id] aluno: altera papel de OUTRO','alu1',$s$update public.profiles set papel='admin' where id=t.u('alu2')$s$,'BLOQUEADO');
drop policy _tmp_auto_edicao on public.profiles;

-- =====================================================================
-- ADMIN  (o que tem de continuar a funcionar)
-- =====================================================================
select t.chk('M1','[admin] lê todos os perfis','admin',$s$select * from public.profiles$s$,'N=8');
select t.chk('M2','[admin] muda papel de aluno -> professor','admin',$s$update public.profiles set papel='professor' where id=t.u('alu2')$s$,'PERMITIDO');
select t.chk('M3','[admin] activa conta pendente','admin',$s$update public.profiles set activo=true where id=t.u('pend')$s$,'PERMITIDO');
select t.chk('M4','[admin] desactiva conta','admin',$s$update public.profiles set activo=false where id=t.u('pend')$s$,'PERMITIDO');
select t.chk('M5','[admin] muda papel de volta (aluno)','admin',$s$update public.profiles set papel='aluno' where id=t.u('alu2')$s$,'PERMITIDO');
select t.chk('M6','[admin] cria curso','admin',$s$insert into public.cursos (nome,taxa_matricula,propina_mensal) values ('Novo',10,5)$s$,'PERMITIDO');
select t.chk('M7','[admin] altera curso','admin',$s$update public.cursos set propina_mensal=60 where nome='Novo'$s$,'PERMITIDO');
select t.chk('M8','[admin] cria turma','admin',$s$insert into public.turmas (curso_id,nome,professor_id) values ('c0000000-0000-0000-0000-000000000001','T9',t.u('prof1'))$s$,'PERMITIDO');
select t.chk('M9','[admin] atribui professor a turma','admin',$s$update public.turmas set professor_id=t.u('prof2') where nome='T9'$s$,'PERMITIDO');
select t.chk('M10','[admin] RPC matricular()','admin',$s$select public.matricular(t.u('alu1'),'70000000-0000-0000-0000-000000000002',3,'2026-02-01')$s$,'PERMITIDO');
select t.chk('M11','[admin] RPC gerar_propinas()','admin',$s$select public.gerar_propinas('b0000000-0000-0000-0000-000000000001',3,'2026-02-01')$s$,'PERMITIDO');
select t.chk('M12','[admin] altera estado de matrícula','admin',$s$update public.matriculas set estado='concluida' where id='b0000000-0000-0000-0000-000000000001'$s$,'PERMITIDO');
select t.chk('M13','[admin] lança/altera notas','admin',$s$update public.avaliacoes set t1=11 where matricula_id='b0000000-0000-0000-0000-000000000002'$s$,'PERMITIDO');
select t.chk('M14','[admin] gere faltas (insere)','admin',$s$insert into public.faltas (matricula_id,data) values ('b0000000-0000-0000-0000-000000000002','2026-04-04')$s$,'PERMITIDO');
select t.chk('M15','[admin] regista pagamento','admin',$s$insert into public.pagamentos (cobranca_id,valor) values ('d0000000-0000-0000-0000-000000000002',20)$s$,'PERMITIDO');
select t.chk('M16','[admin] altera pagamento','admin',$s$update public.pagamentos set metodo='mpesa' where id='e0000000-0000-0000-0000-000000000002'$s$,'PERMITIDO');
select t.chk('M17','[admin] lê cobranças e pagamentos','admin',$s$select * from public.v_cobrancas$s$,'PERMITIDO');
select t.chk('M18','[admin] consulta auditoria','admin',$s$select * from public.auditoria$s$,'PERMITIDO');
select t.chk('M19','[admin] RPC nomes_alunos_turma(qualquer turma)','admin',$s$select * from public.nomes_alunos_turma('70000000-0000-0000-0000-000000000001')$s$,'PERMITIDO');
select t.chk('M20','[admin] NÃO consegue alterar auditoria (imutável)','admin',$s$update public.auditoria set utilizador_nome='x'$s$,'BLOQUEADO');
select t.chk('M21','[admin] NÃO consegue apagar auditoria','admin',$s$delete from public.auditoria$s$,'BLOQUEADO');
select t.chk('M22','[admin] NÃO consegue inserir auditoria falsa','admin',$s$insert into public.auditoria (tabela,accao) values ('x','y')$s$,'BLOQUEADO');

-- =====================================================================
-- Novas protecções P0-3 (não existiam no esquema original)
-- =====================================================================
-- último admin activo (o "admin" é o único activo: adminx está desactivado)
select t.chk('Z1','único admin activo tenta desactivar-se via API','admin',$s$update public.profiles set activo=false where id=t.u('admin')$s$,'BLOQUEADO');
select t.chk('Z2','único admin activo tenta despromover-se via API','admin',$s$update public.profiles set papel='professor' where id=t.u('admin')$s$,'BLOQUEADO');
select t.chk('Z3','admin altera o id de um perfil','admin',$s$update public.profiles set id=gen_random_uuid() where id=t.u('pend')$s$,'BLOQUEADO');
-- recebido_por não pode ser forjado
select t.chk('Z4','admin regista pagamento a fingir ser outro utilizador (recebido_por)','admin',$s$insert into public.pagamentos (cobranca_id,valor,recebido_por) values ('d0000000-0000-0000-0000-000000000001',5,t.u('prof1'))$s$,'PERMITIDO');
\o

-- Verificação de Z4: quem ficou como "recebido_por"?
select 'Z4-verif' as id, 'recebido_por gravado = admin (não o valor forjado)' as descr, 'admin' as esperado,
       case when recebido_por = t.u('admin') then 'admin' else 'FORJADO' end as obtido,
       (recebido_por = t.u('admin')) as ok
  from public.pagamentos where cobranca_id = 'd0000000-0000-0000-0000-000000000001' and valor = 5;

-- Estado final: nada mudou onde não devia (verificações de efeito)
select 'EF1' as id, 'papel de alu1 continua aluno' as descr, 'aluno' as esperado, papel as obtido, papel = 'aluno' as ok from public.profiles where id = t.u('alu1')
union all select 'EF2','prof1 continua professor','professor', papel, papel='professor' from public.profiles where id = t.u('prof1')
union all select 'EF3','pend continua inactivo (após M3/M4 repostos)','false', activo::text, not activo from public.profiles where id = t.u('pend')
union all select 'EF4','prof3x continua inactivo','false', activo::text, not activo from public.profiles where id = t.u('prof3x')
union all select 'EF5','apenas 1 admin activo','1', count(*)::text, count(*)=1 from public.profiles where papel='admin' and activo
union all select 'EF6','notas de M2 não foram alteradas pelo professor alheio (t1=11 só pelo admin)','11.0', t1::text, t1=11 from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000002'
union all select 'EF7','pagamento p1 intacto (30)','30.00', valor::text, valor=30 from public.pagamentos where id='e0000000-0000-0000-0000-000000000001';

\echo
\echo '=== RESULTADOS ==='
select id, descr, esperado, obtido, case when ok then 'PASS' else '>>> FAIL <<<' end as resultado from t.res order by n;
select count(*) filter (where ok) as pass, count(*) filter (where not ok) as fail, count(*) as total from t.res;

rollback;
