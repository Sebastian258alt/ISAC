-- =====================================================================
--  ISAC · P0-3B · Testes de "apagar contas / limpar dados" (só administração)
--
--  Como usar:  psql "$DATABASE_URL" -f supabase/testes_P0-3B_apagar.sql
--  * Correr num projecto de TESTE / cópia local, NUNCA na produção: os testes
--    APAGAM dados a sério (dentro de uma transacção) e terminam em ROLLBACK.
--  * Cada teste finge ser um utilizador como o PostgREST faz (SET ROLE + JWT sub).
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

-- devolve a 1.ª coluna da 1.ª linha (como texto) executando como p_quem
create function t.val(p_quem text, p_sql text) returns text language plpgsql as $$
declare o text;
begin
  perform set_config('request.jwt.claim.sub', t.u(p_quem)::text, true);
  set local role authenticated;
  execute p_sql into o;
  reset role;
  perform set_config('request.jwt.claim.sub', '', true);
  return o;
end $$;
create function t.asrt(p_id text, p_descr text, p_cond boolean) returns void language sql as $$
  insert into t.res (id, descr, esperado, obtido, ok) values (p_id, p_descr, 'verdadeiro', coalesce(p_cond::text,'nulo'), coalesce(p_cond,false)) $$;

insert into t.ids values
  ('admin','a0000000-0000-0000-0000-000000000001'),('admin2','a0000000-0000-0000-0000-000000000002'),
  ('adminx','a0000000-0000-0000-0000-000000000003'),('prof1','a0000000-0000-0000-0000-000000000004'),
  ('alu1','a0000000-0000-0000-0000-000000000005'),('alu2','a0000000-0000-0000-0000-000000000006'),
  ('pend','a0000000-0000-0000-0000-000000000007');

-- (Re)cria um cenário completo como dono da base
create function t.seed() returns void language plpgsql as $$
begin
  delete from public.pagamentos where id is not null;
  delete from public.matriculas where id is not null;
  delete from public.turmas where id is not null;
  delete from public.cursos where id is not null;
  delete from auth.users where id is not null;
  insert into auth.users (id, email) select id, nome || '@teste.local' from t.ids;
  update public.profiles set papel='admin', activo=true where id in (t.u('admin'), t.u('admin2'));
  update public.profiles set papel='admin', activo=false where id = t.u('adminx');
  update public.profiles set papel='professor', activo=true where id = t.u('prof1');
  update public.profiles set papel='aluno', activo=true where id in (t.u('alu1'), t.u('alu2'));
  insert into public.cursos (id, nome, taxa_matricula, propina_mensal) values ('c0000000-0000-0000-0000-000000000001','Curso Teste',100,50);
  insert into public.turmas (id, curso_id, nome, professor_id) values ('70000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','T1', t.u('prof1'));
  insert into public.matriculas (id, aluno_id, turma_id) values
    ('b0000000-0000-0000-0000-000000000001', t.u('alu1'), '70000000-0000-0000-0000-000000000001'),
    ('b0000000-0000-0000-0000-000000000002', t.u('alu2'), '70000000-0000-0000-0000-000000000001');
  insert into public.avaliacoes (matricula_id, t1, t2, ex) values
    ('b0000000-0000-0000-0000-000000000001',10,10,10),('b0000000-0000-0000-0000-000000000002',12,12,12);
  insert into public.faltas (matricula_id, data) values
    ('b0000000-0000-0000-0000-000000000001','2026-01-10'),('b0000000-0000-0000-0000-000000000002','2026-01-10');
  insert into public.cobrancas (id, matricula_id, tipo, valor, vencimento) values
    ('d0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','matricula',100,'2026-01-01'),
    ('d0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','matricula',100,'2026-01-01');
  insert into public.pagamentos (cobranca_id, valor, recebido_por) values
    ('d0000000-0000-0000-0000-000000000001',60,t.u('admin')),('d0000000-0000-0000-0000-000000000002',30,t.u('admin2'));
end $$;
select t.seed();

-- ---------------- 1. QUEM NÃO PODE ----------------
select t.chk('S1','anon: apagar_utilizador','anon',$s$select public.apagar_utilizador(t.u('alu2'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('S2','anon: limpar_dados(tudo)','anon',$s$select public.limpar_dados('tudo','APAGAR')$s$,'BLOQUEADO');
select t.chk('S3','aluno: apagar outro aluno','alu1',$s$select public.apagar_utilizador(t.u('alu2'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('S4','aluno: apagar a própria conta','alu1',$s$select public.apagar_utilizador(t.u('alu1'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('S5','aluno: limpar_dados(tudo)','alu1',$s$select public.limpar_dados('tudo','APAGAR')$s$,'BLOQUEADO');
select t.chk('S6','formador: apagar aluno','prof1',$s$select public.apagar_utilizador(t.u('alu1'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('S7','formador: limpar_dados(notas_faltas)','prof1',$s$select public.limpar_dados('notas_faltas','APAGAR')$s$,'BLOQUEADO');
select t.chk('S8','aluno: resumo_utilizador (não espreita dados de terceiros)','alu1',$s$select public.resumo_utilizador(t.u('alu2'))$s$,'BLOQUEADO');
select t.chk('S9','formador: resumo_limpeza','prof1',$s$select public.resumo_limpeza('tudo')$s$,'BLOQUEADO');
select t.chk('S10','admin DESACTIVADO: apagar_utilizador','adminx',$s$select public.apagar_utilizador(t.u('alu1'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('S11','admin DESACTIVADO: limpar_dados','adminx',$s$select public.limpar_dados('tudo','APAGAR')$s$,'BLOQUEADO');
select t.chk('S12','aluno: executar a função interna directamente','alu1',$s$select public.apagar_contas_interno(array[t.u('alu2')])$s$,'BLOQUEADO');
select t.chk('S13','admin: executar a função interna directamente (sem confirmação)','admin',$s$select public.apagar_contas_interno(array[t.u('alu2')])$s$,'BLOQUEADO');
select t.chk('S14','admin: DELETE directo em profiles (continua vedado)','admin',$s$delete from public.profiles where id = t.u('alu2')$s$,'BLOQUEADO');
select t.chk('S15','admin: DELETE directo em auth.users','admin',$s$delete from auth.users where id = t.u('alu2')$s$,'BLOQUEADO');

-- ---------------- 2. SALVAGUARDAS PARA O ADMIN ----------------
select t.chk('G1','admin: confirmação errada ("sim")','admin',$s$select public.apagar_utilizador(t.u('alu2'),'sim')$s$,'BLOQUEADO');
select t.chk('G2','admin: confirmação nula','admin',$s$select public.apagar_utilizador(t.u('alu2'),null)$s$,'BLOQUEADO');
select t.chk('G3','admin: confirmação em minúsculas ("apagar") recusada no servidor','admin',$s$select public.apagar_utilizador(t.u('alu2'),'apagar')$s$,'BLOQUEADO');
select t.chk('G4','admin: apagar a própria conta','admin',$s$select public.apagar_utilizador(t.u('admin'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('G5','admin: utilizador inexistente','admin',$s$select public.apagar_utilizador('99999999-9999-9999-9999-999999999999','APAGAR')$s$,'BLOQUEADO');
select t.chk('G6','admin: limpar_dados sem confirmação','admin',$s$select public.limpar_dados('tudo','')$s$,'BLOQUEADO');
select t.chk('G7','admin: âmbito inválido','admin',$s$select public.limpar_dados('auditoria','APAGAR')$s$,'BLOQUEADO');
select t.chk('G8','admin: âmbito nulo','admin',$s$select public.limpar_dados(null,'APAGAR')$s$,'BLOQUEADO');
select t.asrt('G9','nada foi apagado pelas tentativas recusadas (3 alunos, 2 matrículas, 2 pagamentos)',
  (select count(*) from public.profiles where papel='aluno')=3 and (select count(*) from public.matriculas)=2 and (select count(*) from public.pagamentos)=2);

-- ---------------- 3. PRÉ-VISUALIZAÇÃO ----------------
select t.asrt('R1','resumo_utilizador(alu1): 1 matrícula, 1 nota, 1 falta, 1 cobrança, 1 pagamento',
  t.val('admin',$s$select public.resumo_utilizador(t.u('alu1'))::text$s$)::jsonb @> '{"matriculas":1,"notas":1,"faltas":1,"cobrancas":1,"pagamentos":1}');
select t.asrt('R2','resumo_utilizador(prof1): 1 turma ficará sem formador',
  (t.val('admin',$s$select public.resumo_utilizador(t.u('prof1'))::text$s$)::jsonb->>'turmas_sem_formador')='1');
select t.asrt('R3','resumo_limpeza(alunos): conta todas as contas de aluno (activas e inactivas)',
  (t.val('admin',$s$select public.resumo_limpeza('alunos')::text$s$)::jsonb->>'contas')=(select count(*)::text from public.profiles where papel='aluno'));
select t.asrt('R4','resumo_limpeza(notas_faltas): só notas e faltas',
  t.val('admin',$s$select public.resumo_limpeza('notas_faltas')::text$s$)::jsonb = '{"notas":2,"faltas":2}');
select t.asrt('R5','resumo_limpeza(formadores): não conta alunos nem admins',
  (t.val('admin',$s$select public.resumo_limpeza('formadores')::text$s$)::jsonb->>'contas')='1');
select t.asrt('R6','pré-visualizar não apaga nada',(select count(*) from public.profiles)=(select count(*) from t.ids));

-- ---------------- 4. APAGAR UMA CONTA (aluno com dinheiro e notas) ----------------
select t.chk('A1','admin apaga o aluno alu1 (com pagamentos)','admin',$s$select public.apagar_utilizador(t.u('alu1'),'APAGAR')$s$,'PERMITIDO');
select t.asrt('A2','perfil de alu1 apagado', not exists (select 1 from public.profiles where id=t.u('alu1')));
select t.asrt('A3','login (auth.users) de alu1 apagado', not exists (select 1 from auth.users where id=t.u('alu1')));
select t.asrt('A4','matrícula, nota, falta, cobrança e pagamento de alu1 apagados',
  not exists (select 1 from public.matriculas where id='b0000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.faltas where matricula_id='b0000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.cobrancas where id='d0000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.pagamentos where cobranca_id='d0000000-0000-0000-0000-000000000001'));
select t.asrt('A5','dados de alu2 (outro aluno) intactos',
  exists (select 1 from public.profiles where id=t.u('alu2')) and exists (select 1 from public.matriculas where id='b0000000-0000-0000-0000-000000000002')
  and exists (select 1 from public.pagamentos where cobranca_id='d0000000-0000-0000-0000-000000000002') and exists (select 1 from public.avaliacoes where matricula_id='b0000000-0000-0000-0000-000000000002'));
select t.asrt('A6','curso, turma e formador intactos',
  exists (select 1 from public.cursos) and exists (select 1 from public.turmas where professor_id=t.u('prof1')));
select t.asrt('A7','Auditoria registou o DELETE do perfil, feito pelo admin',
  exists (select 1 from public.auditoria where tabela='profiles' and accao='DELETE' and registo_id=t.u('alu1')::text and utilizador_id=t.u('admin')));
select t.asrt('A8','Auditoria registou o DELETE do pagamento',
  exists (select 1 from public.auditoria where tabela='pagamentos' and accao='DELETE' and utilizador_id=t.u('admin')));
select t.chk('A9','apagar o mesmo aluno outra vez (já não existe)','admin',$s$select public.apagar_utilizador(t.u('alu1'),'APAGAR')$s$,'BLOQUEADO');
select t.chk('A10','admin apaga o formador prof1','admin',$s$select public.apagar_utilizador(t.u('prof1'),'APAGAR')$s$,'PERMITIDO');
select t.asrt('A11','turma de prof1 ficou sem formador (não foi apagada)', exists (select 1 from public.turmas where professor_id is null));
select t.chk('A12','admin apaga outro admin (admin2, que recebeu pagamentos)','admin',$s$select public.apagar_utilizador(t.u('admin2'),'APAGAR')$s$,'PERMITIDO');
select t.asrt('A13','pagamento recebido por admin2 mantém-se, com recebido_por nulo', exists (select 1 from public.pagamentos where cobranca_id='d0000000-0000-0000-0000-000000000002' and recebido_por is null));
select t.chk('A14','agora o único admin activo já não se consegue apagar','admin',$s$select public.apagar_utilizador(t.u('admin'),'APAGAR')$s$,'BLOQUEADO');
select t.asrt('A15','continua a existir 1 admin activo', (select count(*) from public.profiles where papel='admin' and activo)=1);

-- ---------------- 5. LIMPEZAS POR ÂMBITO ----------------
select t.seed();
select t.chk('L1','admin limpa notas e faltas','admin',$s$select public.limpar_dados('notas_faltas','APAGAR')$s$,'PERMITIDO');
select t.asrt('L1a','notas e faltas = 0; matrículas, finanças e contas intactas',
  (select count(*) from public.avaliacoes)=0 and (select count(*) from public.faltas)=0 and (select count(*) from public.matriculas)=2
  and (select count(*) from public.pagamentos)=2 and (select count(*) from public.profiles)=(select count(*) from t.ids));

select t.seed();
select t.chk('L2','admin limpa finanças','admin',$s$select public.limpar_dados('financas','APAGAR')$s$,'PERMITIDO');
select t.asrt('L2a','cobranças e pagamentos = 0; notas, faltas, matrículas intactas',
  (select count(*) from public.cobrancas)=0 and (select count(*) from public.pagamentos)=0 and (select count(*) from public.matriculas)=2
  and (select count(*) from public.avaliacoes)=2 and (select count(*) from public.faltas)=2);

select t.seed();
select t.chk('L3','admin limpa matrículas','admin',$s$select public.limpar_dados('matriculas','APAGAR')$s$,'PERMITIDO');
select t.asrt('L3a','matrículas, notas, faltas, cobranças, pagamentos = 0; contas, cursos e turmas intactos',
  (select count(*) from public.matriculas)=0 and (select count(*) from public.avaliacoes)=0 and (select count(*) from public.faltas)=0
  and (select count(*) from public.cobrancas)=0 and (select count(*) from public.pagamentos)=0
  and (select count(*) from public.profiles)=(select count(*) from t.ids) and (select count(*) from public.turmas)=1 and (select count(*) from public.cursos)=1);

select t.seed();
select t.chk('L4','admin limpa alunos','admin',$s$select public.limpar_dados('alunos','APAGAR')$s$,'PERMITIDO');
select t.asrt('L4a','sem contas de aluno (perfil e login), sem matrículas/finanças',
  not exists (select 1 from public.profiles where papel='aluno') and not exists (select 1 from auth.users where id in (t.u('alu1'),t.u('alu2'),t.u('pend')))
  and (select count(*) from public.matriculas)=0 and (select count(*) from public.pagamentos)=0 and (select count(*) from public.avaliacoes)=0);
select t.asrt('L4b','admins (incl. desactivado), formador, turmas e cursos intactos',
  (select count(*) from public.profiles where papel='admin')=3 and exists (select 1 from public.profiles where id=t.u('prof1'))
  and (select count(*) from public.turmas)=1 and (select count(*) from public.cursos)=1);

select t.seed();
select t.chk('L5','admin limpa formadores','admin',$s$select public.limpar_dados('formadores','APAGAR')$s$,'PERMITIDO');
select t.asrt('L5a','sem formadores; turma sem formador; alunos e matrículas intactos',
  not exists (select 1 from public.profiles where papel='professor') and exists (select 1 from public.turmas where professor_id is null)
  and (select count(*) from public.profiles where papel='aluno')=3 and (select count(*) from public.matriculas)=2);

select t.seed();
select t.chk('L6','admin limpa TUDO','admin',$s$select public.limpar_dados('tudo','APAGAR')$s$,'PERMITIDO');
select t.asrt('L6a','só restam as 3 contas de administração',
  (select count(*) from public.profiles)=3 and not exists (select 1 from public.profiles where papel<>'admin') and (select count(*) from auth.users)=3);
select t.asrt('L6b','cursos, turmas, matrículas, notas, faltas, cobranças, pagamentos = 0',
  (select count(*)+(select count(*) from public.turmas)+(select count(*) from public.matriculas)+(select count(*) from public.avaliacoes)
   +(select count(*) from public.faltas)+(select count(*) from public.cobrancas)+(select count(*) from public.pagamentos) from public.cursos)=0);
select t.asrt('L6c','Auditoria NÃO foi apagada e tem a linha de resumo LIMPEZA feita pelo admin',
  exists (select 1 from public.auditoria where tabela='sistema' and accao='LIMPEZA' and registo_id='tudo' and utilizador_id=t.u('admin') and detalhe->>'ambito'='tudo')
  and (select count(*) from public.auditoria)>10);
select t.chk('L7','depois de limpar tudo, o admin continua a funcionar (resumo)','admin',$s$select public.resumo_limpeza('tudo')$s$,'PERMITIDO');

\echo
\echo '=== RESULTADOS ==='
select id, descr, esperado, obtido, case when ok then 'PASS' else '>>> FAIL <<<' end as resultado from t.res order by n;
select count(*) filter (where ok) as pass, count(*) filter (where not ok) as fail, count(*) as total from t.res;

rollback;
