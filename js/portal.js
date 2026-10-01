(function(){
'use strict';
// Regras de exemplo (a direcção do ISAC deve confirmar)
var NOTA_MIN=10, LIMITE_FALTAS=10;

var $=function(s){return document.querySelector(s)};
var esc=function(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})};
var num=function(v){return (+v||0).toLocaleString('pt-PT',{minimumFractionDigits:2,maximumFractionDigits:2})+' MT'};
var num0=function(v){return Math.round(+v||0).toLocaleString('pt-PT')+' MT'};
var dt=function(d){return d?new Date(d+'T00:00:00').toLocaleDateString('pt-PT'):'—'};
var mes=function(d){var s=new Date(d+'T00:00:00').toLocaleDateString('pt-PT',{month:'long',year:'numeric'});return s.charAt(0).toUpperCase()+s.slice(1)};
var hoje=function(){var d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
var by=function(a){return Object.fromEntries(a.map(function(x){return[x.id,x]}))};
var pill=function(t,c){return '<span class="pill '+(c||'')+'">'+esc(t)+'</span>'};
var vazio=function(t){return '<div class="card"><p>'+esc(t)+'</p></div>'};
var opts=function(arr,lbl,sel,ph){return (ph?'<option value="">'+esc(ph)+'</option>':'')+arr.map(function(x){return '<option value="'+esc(x.id)+'"'+(x.id===sel?' selected':'')+'>'+esc(lbl(x))+'</option>'}).join('')};

var PAP={aluno:'Aluno',professor:'Formador',admin:'Administração'};
var EST={pago:['Pago','ok'],pendente:['Pendente',''],parcial:['Parcial',''],em_atraso:['Em atraso','wr']};
var MET={numerario:'Numerário',mpesa:'M-Pesa',emola:'e-Mola',mkesh:'mKesh',transferencia:'Transferência',outro:'Outro'};

var toastT;
function toast(m,ok){var t=$('#toast');t.textContent=m;t.className=ok?'ok':'';t.style.display='block';clearTimeout(toastT);toastT=setTimeout(function(){t.style.display='none'},3500)}
function erro(e){var m=(e&&e.message)||String(e);
  if(/row-level security|permission denied/i.test(m))return 'Sem permissão para esta acção.';
  if(/duplicate key/i.test(m))return 'Este registo já existe.';
  if(/Invalid login/i.test(m))return 'Email ou palavra-passe incorrectos.';
  if(/Email not confirmed/i.test(m))return 'Confirme primeiro o email (veja a caixa de correio).';
  if(/rate limit/i.test(m))return 'Demasiadas tentativas. Aguarde alguns minutos.';
  if(/Failed to fetch|NetworkError/i.test(m))return 'Sem ligação à internet.';
  return m}
function fail(e){console.error(e);toast(erro(e))}
async function q(p){var r=await p;if(r.error)throw r.error;return r.data}
async function upd(p){var d=await q(p.select());if(!d.length)throw new Error('Sem permissão para esta acção.');return d}

var sb,S={me:null,tab:null,turma:null,dia:hoje(),fe:'',fq:'',fin:[]},rt=0;
var TABS={
  aluno:[['res','Notas e faltas'],['pag','Pagamentos']],
  professor:[['tur','As minhas turmas']],
  admin:[['pan','Painel'],['mat','Matrículas'],['pag','Pagamentos'],['uti','Utilizadores'],['cur','Cursos e turmas'],['aud','Auditoria']]
};

// ---------- dados partilhados ----------
async function loadFin(){
  var r=await Promise.all([
    q(sb.from('v_cobrancas').select('*').order('vencimento')),
    q(sb.from('matriculas').select('id,aluno_id,turma_id')),
    q(sb.from('profiles').select('id,nome')),
    q(sb.from('turmas').select('id,nome,curso_id')),
    q(sb.from('cursos').select('id,nome'))]);
  var M=by(r[1]),P=by(r[2]),T=by(r[3]),C=by(r[4]);
  return r[0].map(function(c){var m=M[c.matricula_id]||{},t=T[m.turma_id]||{};
    return Object.assign({},c,{aluno:(P[m.aluno_id]||{}).nome||'—',curso:(C[t.curso_id]||{}).nome||'—',turma:t.nome||'',
      desc:c.tipo==='matricula'?'Taxa de matrícula':'Propina de '+mes(c.referencia_mes)})})}

function tabFin(rows,admin){
  return '<div class="tw"><table><thead><tr>'+(admin?'<th>Aluno</th>':'')+'<th>Descrição</th><th>Curso</th><th>Vencimento</th><th>Valor</th><th>Pago</th><th>Em falta</th><th>Estado</th>'+(admin?'<th></th>':'')+'</tr></thead><tbody>'+
  (rows.map(function(r){var e=EST[r.estado]||['',''];
    return '<tr>'+(admin?'<td>'+esc(r.aluno)+'</td>':'')+'<td>'+esc(r.desc)+'</td><td>'+esc(r.curso)+' '+esc(r.turma)+'</td><td>'+dt(r.vencimento)+'</td><td>'+num(r.valor)+'</td><td>'+num(r.pago)+'</td><td>'+num(r.em_falta)+'</td><td>'+pill(e[0],e[1])+'</td>'+
    (admin?'<td>'+(+r.em_falta>0?'<button class="btn o2 sm" data-a="pagar" data-id="'+esc(r.id)+'">Registar pagamento</button>':'')+'</td>':'')+'</tr>'}).join('')||'<tr><td colspan="9" class="mu">Sem registos.</td></tr>')+
  '</tbody></table></div>'}

// ---------- vistas ----------
var V={};

V.aluno_res=async function(){
  var ms=await q(sb.from('matriculas').select('id,turma_id,estado,data').order('data'));
  if(!ms.length)return vazio('Ainda não está matriculado em nenhuma turma. Dirija-se à secretaria do ISAC.');
  var ids=ms.map(function(m){return m.id});
  var r=await Promise.all([q(sb.from('turmas').select('id,nome,horario,curso_id')),q(sb.from('cursos').select('id,nome')),
    q(sb.from('avaliacoes').select('*').in('matricula_id',ids)),q(sb.from('faltas').select('*').in('matricula_id',ids).order('data'))]);
  var T=by(r[0]),C=by(r[1]),A=Object.fromEntries(r[2].map(function(a){return[a.matricula_id,a]}));
  return ms.map(function(m){
    var t=T[m.turma_id]||{},c=C[t.curso_id]||{},a=A[m.id]||{},f=r[3].filter(function(x){return x.matricula_id===m.id}),
        inj=f.filter(function(x){return !x.justificada}).length,
        e=a.media==null?['Sem média',''] : (a.media>=NOTA_MIN&&inj<LIMITE_FALTAS?['Em dia','ok']:['Em risco','wr']);
    var n=function(v){return v==null?'—':v};
    return '<section class="card"><h3>'+esc(c.nome)+' · Turma '+esc(t.nome)+'</h3><p class="mu">'+esc(t.horario||'')+' '+pill(e[0],e[1])+'</p>'+
    '<div class="tw"><table><thead><tr><th>Teste escrito (30%)</th><th>Oral (30%)</th><th>Teste final (40%)</th><th>Média</th></tr></thead><tbody><tr><td>'+n(a.t1)+'</td><td>'+n(a.t2)+'</td><td>'+n(a.ex)+'</td><td><b>'+n(a.media)+'</b></td></tr></tbody></table></div>'+
    '<p>Faltas: <b>'+f.length+'</b> ('+inj+' injustificadas). Fica em risco com média abaixo de '+NOTA_MIN+' ou '+LIMITE_FALTAS+' faltas injustificadas.</p>'+
    (f.length?'<details><summary>Ver datas das faltas</summary><p>'+f.map(function(x){return dt(x.data)+(x.justificada?' (justificada)':'')}).join(' · ')+'</p></details>':'')+'</section>'}).join('')};

V.aluno_pag=async function(){
  var rows=await loadFin();S.fin=rows;
  var falta=rows.reduce(function(s,r){return s+ +r.em_falta},0),atr=rows.filter(function(r){return r.estado==='em_atraso'}).length;
  return '<div class="kpis"><div class="k"><b>'+num(falta)+'</b><span>Em falta</span></div><div class="k"><b>'+atr+'</b><span>Prestações em atraso</span></div></div>'+tabFin(rows,false)+
    '<p class="note">Os pagamentos são registados pela secretaria. Depois de pagar, mostre o comprovativo para actualizar o estado.</p>'};

V.professor_tur=async function(){
  var ts=await q(sb.from('turmas').select('id,nome,horario,curso_id').eq('professor_id',S.me.id).order('nome'));
  if(!ts.length)return vazio('Ainda não tem turmas atribuídas. Peça à administração.');
  if(!ts.some(function(t){return t.id===S.turma}))S.turma=ts[0].id;
  var cs=by(await q(sb.from('cursos').select('id,nome')));
  var ms=await q(sb.from('matriculas').select('id,aluno_id').eq('turma_id',S.turma).eq('estado','activa'));
  var ids=ms.map(function(m){return m.id}),r=[[],[],[]];
  if(ids.length)r=await Promise.all([q(sb.rpc('nomes_alunos_turma',{p_turma:S.turma})),
    q(sb.from('avaliacoes').select('*').in('matricula_id',ids)),q(sb.from('faltas').select('*').in('matricula_id',ids))]);
  var P=by(r[0]),A=Object.fromEntries(r[1].map(function(a){return[a.matricula_id,a]}));
  ms.sort(function(a,b){return ((P[a.aluno_id]||{}).nome||'').localeCompare((P[b.aluno_id]||{}).nome||'')});
  var f=function(a,k){return '<td><input type="number" min="0" max="20" step="0.5" data-i="nota" data-k="'+k+'" value="'+(a[k]==null?'':a[k])+'" aria-label="'+esc(k)+'"></td>'};
  return '<div class="bar"><label>Turma <select data-c="turma">'+ts.map(function(t){return '<option value="'+esc(t.id)+'"'+(t.id===S.turma?' selected':'')+'>'+esc((cs[t.curso_id]||{}).nome+' · '+t.nome+(t.horario?' · '+t.horario:''))+'</option>'}).join('')+'</select></label>'+
    '<label>Data da aula <input type="date" data-c="dia" value="'+esc(S.dia)+'"></label></div>'+
    '<div class="tw"><table><thead><tr><th>Aluno</th><th>Teste escrito</th><th>Oral</th><th>Teste final</th><th>Média</th><th>Faltas</th><th></th></tr></thead><tbody>'+
    (ms.map(function(m){var a=A[m.id]||{},fm=r[2].filter(function(x){return x.matricula_id===m.id}),on=fm.some(function(x){return x.data===S.dia});
      return '<tr data-m="'+esc(m.id)+'"><td>'+esc((P[m.aluno_id]||{}).nome)+'</td>'+f(a,'t1')+f(a,'t2')+f(a,'ex')+'<td class="med"><b>'+(a.media==null?'—':a.media)+'</b></td><td class="fc">'+fm.length+'</td>'+
      '<td><button class="btn p2 sm" data-a="guardar">Guardar notas</button> <button class="btn o2 sm" data-a="falta" data-on="'+(on?1:0)+'">'+(on?'Retirar falta':'Marcar falta')+'</button></td></tr>'}).join('')||'<tr><td colspan="7" class="mu">Esta turma ainda não tem alunos matriculados.</td></tr>')+
    '</tbody></table></div><p class="note">Notas de 0 a 20. A média (30% teste escrito, 30% oral, 40% teste final) aparece quando as três notas estão lançadas. "Marcar falta" usa a data da aula escolhida acima.</p>'};

V.admin_pan=async function(){
  var r=await Promise.all([loadFin(),q(sb.from('profiles').select('id,papel,activo')),q(sb.from('matriculas').select('id').eq('estado','activa'))]);
  var f=r[0],sum=function(a,k){return a.reduce(function(s,x){return s+ +x[k]},0)},atr=f.filter(function(x){return x.estado==='em_atraso'}),
      pend=r[1].filter(function(p){return !p.activo}).length;
  return (pend?'<button class="card go" data-a="tab" data-k="uti"><b>'+pend+' conta(s) à espera de activação.</b> Abrir Utilizadores</button>':'')+
  '<div class="kpis" style="margin-top:12px"><div class="k"><b>'+r[1].filter(function(p){return p.papel==='aluno'&&p.activo}).length+'</b><span>Alunos activos</span></div>'+
  '<div class="k"><b>'+r[2].length+'</b><span>Matrículas activas</span></div>'+
  '<div class="k"><b>'+num0(sum(f,'pago'))+'</b><span>Recebido</span></div>'+
  '<div class="k"><b>'+num0(sum(f,'em_falta'))+'</b><span>Por receber</span></div>'+
  '<div class="k"><b>'+num0(sum(atr,'em_falta'))+'</b><span>Em atraso ('+atr.length+' prestações)</span></div></div>'+
  '<h3 class="h3">Prestações em atraso</h3>'+tabFin(atr.slice(0,10),true)+(atr.length>10?'<p class="note">A mostrar 10 de '+atr.length+'. Veja todas em Pagamentos.</p>':'')};

V.admin_pag=async function(){
  var rows=await loadFin();S.fin=rows;
  var fq=S.fq.trim().toLowerCase(),sel=rows.filter(function(x){return (!S.fe||x.estado===S.fe)&&(!fq||x.aluno.toLowerCase().indexOf(fq)>-1)});
  return '<div class="bar"><label>Estado <select data-c="fe">'+[['','Todos']].concat(Object.keys(EST).map(function(k){return[k,EST[k][0]]})).map(function(o){return '<option value="'+o[0]+'"'+(o[0]===S.fe?' selected':'')+'>'+o[1]+'</option>'}).join('')+'</select></label>'+
    '<label>Aluno <input type="search" data-c="fq" value="'+esc(S.fq)+'" placeholder="Nome do aluno"></label></div>'+tabFin(sel.slice(0,200),true)+(sel.length>200?'<p class="note">A mostrar 200 de '+sel.length+'. Use os filtros.</p>':'')};

V.admin_mat=async function(){
  var r=await Promise.all([q(sb.from('profiles').select('id,nome,papel,activo').eq('papel','aluno').eq('activo',true).order('nome')),
    q(sb.from('turmas').select('id,nome,curso_id').eq('activa',true)),q(sb.from('cursos').select('id,nome')),
    q(sb.from('matriculas').select('id,aluno_id,turma_id,data,estado').order('data',{ascending:false}))]);
  var C=by(r[2]),T=by(r[1]),P=by(r[0]);
  var todos=by(await q(sb.from('profiles').select('id,nome')));
  var form=(!r[0].length||!r[1].length)?vazio(!r[0].length?'Ainda não há alunos activos. Active contas em Utilizadores.':'Ainda não há turmas. Crie cursos e turmas primeiro.'):
    '<form class="card fm" data-f="matricular"><h3>Nova matrícula</h3><div class="fr"><label>Aluno<select name="aluno" required>'+opts(r[0],function(x){return x.nome},'','Escolher…')+'</select></label>'+
    '<label>Turma<select name="turma" required>'+opts(r[1],function(t){return (C[t.curso_id]||{}).nome+' · '+t.nome},'','Escolher…')+'</select></label>'+
    '<label>Início<input type="date" name="inicio" value="'+hoje()+'" required></label>'+
    '<label>Propinas a gerar (meses)<input type="number" name="meses" min="0" max="24" value="10" required></label></div>'+
    '<div><button class="btn p2" type="submit">Matricular</button></div><p class="note">Gera a taxa de matrícula e as propinas mensais (vencem no dia 10) com os valores do curso.</p></form>';
  var tf=by(await q(sb.from('turmas').select('id,nome,curso_id')));
  return form+'<h3 class="h3">Matrículas</h3><div class="tw"><table><thead><tr><th>Aluno</th><th>Curso · Turma</th><th>Data</th><th>Estado</th><th></th></tr></thead><tbody>'+
    (r[3].map(function(m){var t=tf[m.turma_id]||{};
      return '<tr><td>'+esc((todos[m.aluno_id]||{}).nome)+'</td><td>'+esc((C[t.curso_id]||{}).nome)+' · '+esc(t.nome)+'</td><td>'+dt(m.data)+'</td><td><select data-c="mest" data-id="'+esc(m.id)+'">'+
      [['activa','Activa'],['concluida','Concluída'],['desistiu','Desistiu']].map(function(o){return '<option value="'+o[0]+'"'+(o[0]===m.estado?' selected':'')+'>'+o[1]+'</option>'}).join('')+'</select></td>'+
      '<td><button class="btn o2 sm" data-a="propinas" data-id="'+esc(m.id)+'">Gerar mais 3 meses</button></td></tr>'}).join('')||'<tr><td colspan="5" class="mu">Sem matrículas.</td></tr>')+'</tbody></table></div>'};

V.admin_uti=async function(){
  var ps=await q(sb.from('profiles').select('*'));
  ps.sort(function(a,b){return (a.activo-b.activo)||a.nome.localeCompare(b.nome)});
  return '<p class="sub">Quem cria conta no portal fica aqui como <b>aluno inactivo</b> até a administração o activar. Só formadores e administradores precisam de mudar de papel.</p>'+
  '<div class="tw"><table><thead><tr><th>Nome</th><th>Email</th><th>Papel</th><th>Activo</th><th></th></tr></thead><tbody>'+ps.map(function(p){var eu=p.id===S.me.id;
    return '<tr'+(p.activo?'':' style="background:var(--soft)"')+'><td>'+esc(p.nome)+(eu?' (você)':'')+'</td><td>'+esc(p.email)+'</td><td><select data-c="papel" data-id="'+esc(p.id)+'"'+(eu?' disabled':'')+' aria-label="Papel de '+esc(p.nome)+'">'+
    Object.keys(PAP).map(function(k){return '<option value="'+k+'"'+(k===p.papel?' selected':'')+'>'+PAP[k]+'</option>'}).join('')+'</select></td>'+
    '<td><input type="checkbox" data-c="activo" data-id="'+esc(p.id)+'"'+(p.activo?' checked':'')+(eu?' disabled':'')+' aria-label="Conta activa de '+esc(p.nome)+'"></td><td>'+(eu?'':'<button class="btn dg sm" data-a="apagaruti" data-id="'+esc(p.id)+'">Apagar</button>')+'</td></tr>'}).join('')+'</tbody></table></div>'+
  '<section class="card zona"><h3>Zona de perigo</h3><p>Apagar de uma vez notas, finanças, matrículas ou contas (por exemplo, dados de teste antes de abrir a sério). Só a administração pode fazer isto e nunca se apagam as contas de administração nem a Auditoria.</p><button class="btn dg" data-a="limpar">Limpar dados…</button></section>'};

V.admin_cur=async function(){
  var r=await Promise.all([q(sb.from('cursos').select('*').order('nome')),q(sb.from('turmas').select('*').order('nome')),
    q(sb.from('profiles').select('id,nome').eq('papel','professor').eq('activo',true).order('nome'))]);
  var C=by(r[0]);
  return '<h3 class="h3" style="margin-top:0">Cursos</h3><div class="tw"><table><thead><tr><th>Nome</th><th>Taxa de matrícula (MT)</th><th>Propina mensal (MT)</th><th>Activo</th><th></th></tr></thead><tbody>'+
  r[0].map(function(c){return '<tr data-id="'+esc(c.id)+'"><td><input type="text" name="nome" value="'+esc(c.nome)+'"></td><td><input type="number" name="taxa" min="0" step="0.01" value="'+c.taxa_matricula+'"></td><td><input type="number" name="prop" min="0" step="0.01" value="'+c.propina_mensal+'"></td><td><input type="checkbox" name="activo"'+(c.activo?' checked':'')+'></td><td><button class="btn p2 sm" data-a="salvarcurso">Guardar</button></td></tr>'}).join('')+'</tbody></table></div>'+
  '<form class="card fm" data-f="addcurso"><div class="fr"><label>Novo curso<input name="nome" required></label><label>Taxa de matrícula (MT)<input type="number" name="taxa" min="0" step="0.01" value="0" required></label><label>Propina mensal (MT)<input type="number" name="prop" min="0" step="0.01" value="0" required></label></div><div><button class="btn p2" type="submit">Adicionar curso</button></div>'+
  '<p class="note">Alterar preços não muda cobranças já geradas, só as matrículas futuras.</p></form>'+
  '<h3 class="h3">Turmas</h3><div class="tw"><table><thead><tr><th>Curso</th><th>Turma</th><th>Horário</th><th>Formador</th><th>Activa</th></tr></thead><tbody>'+
  r[1].map(function(t){return '<tr><td>'+esc((C[t.curso_id]||{}).nome)+'</td><td>'+esc(t.nome)+'</td><td>'+esc(t.horario||'—')+'</td><td><select data-c="prof" data-id="'+esc(t.id)+'">'+opts(r[2],function(p){return p.nome},t.professor_id,'Sem formador')+'</select></td><td><input type="checkbox" data-c="tact" data-id="'+esc(t.id)+'"'+(t.activa?' checked':'')+' aria-label="Turma activa"></td></tr>'}).join('')+'</tbody></table></div>'+
  (r[0].length?'<form class="card fm" data-f="addturma"><div class="fr"><label>Curso<select name="curso" required>'+opts(r[0],function(c){return c.nome},'','Escolher…')+'</select></label><label>Nome da turma<input name="nome" required placeholder="A"></label><label>Horário<input name="horario" placeholder="Seg/Qua 08h–10h"></label><label>Formador<select name="prof">'+opts(r[2],function(p){return p.nome},'','Sem formador')+'</select></label></div><div><button class="btn p2" type="submit">Adicionar turma</button></div></form>':'')};

V.admin_aud=async function(){
  var rows=await q(sb.from('auditoria').select('*').order('quando',{ascending:false}).limit(100));
  var TB={sistema:'Sistema',profiles:'Utilizador',cursos:'Curso',turmas:'Turma',matriculas:'Matrícula',avaliacoes:'Nota',faltas:'Falta',cobrancas:'Cobrança',pagamentos:'Pagamento'},AC={INSERT:'Criou',UPDATE:'Alterou',DELETE:'Apagou',LIMPEZA:'Limpou'};
  var dif=function(d){if(!d||!d.antes||!d.depois)return '';return Object.keys(d.depois).filter(function(k){return JSON.stringify(d.depois[k])!==JSON.stringify(d.antes[k])}).join(', ')};
  return '<p class="sub">As últimas 100 acções registadas automaticamente. Ninguém as pode editar ou apagar.</p><div class="tw"><table><thead><tr><th>Quando</th><th>Quem</th><th>Acção</th><th>O quê</th><th>Campos alterados</th></tr></thead><tbody>'+
  rows.map(function(a){return '<tr><td>'+new Date(a.quando).toLocaleString('pt-PT')+'</td><td>'+esc(a.utilizador_nome)+'</td><td>'+(AC[a.accao]||a.accao)+'</td><td>'+(TB[a.tabela]||a.tabela)+'</td><td>'+esc(dif(a.detalhe))+'</td></tr>'}).join('')+'</tbody></table></div>'};

// ---------- composição ----------
async function render(full){
  var my=++rt,tabs=TABS[S.me.papel];
  if(!S.tab||!tabs.some(function(t){return t[0]===S.tab}))S.tab=tabs[0][0];
  if(full!==false)$('#v').innerHTML='<nav class="ptabs" aria-label="Secções">'+tabs.map(function(t){return '<button data-a="tab" data-k="'+t[0]+'" class="'+(t[0]===S.tab?'on':'')+'"'+(t[0]===S.tab?' aria-current="page"':'')+'>'+t[1]+'</button>'}).join('')+'</nav><div id="c"><p class="mu">A carregar…</p></div>';
  try{var h=await V[S.me.papel+'_'+S.tab]();if(my===rt)$('#c').innerHTML=h}
  catch(e){console.error(e);if(my===rt)$('#c').innerHTML='<p class="bad">Não foi possível carregar os dados. '+esc(erro(e))+'</p>'}}

function who(){$('#who').innerHTML=S.me?esc(S.me.nome)+' · '+PAP[S.me.papel]+' <button class="btn o2 sm" data-a="sair">Sair</button>':''}

function authView(m){
  S.me=null;who();
  var t={in:'Entrar no portal',up:'Criar conta de aluno',rec:'Recuperar palavra-passe','new':'Nova palavra-passe'}[m];
  var f={
    'in':'<label>Email<input type="email" name="email" autocomplete="email" required></label><label>Palavra-passe<input type="password" name="password" autocomplete="current-password" required></label><button class="btn p2" type="submit">Entrar</button><p class="mu"><button type="button" class="lnk" data-a="authmode" data-m="up">Criar conta</button> · <button type="button" class="lnk" data-a="authmode" data-m="rec">Esqueci a palavra-passe</button></p>',
    up:'<label>Nome completo<input name="nome" autocomplete="name" required minlength="3"></label><label>Email<input type="email" name="email" autocomplete="email" required></label><label>Palavra-passe (mínimo 8 caracteres)<input type="password" name="password" autocomplete="new-password" minlength="8" required></label><button class="btn p2" type="submit">Criar conta</button><p class="mu">A conta só fica activa depois de a administração a aprovar.</p><p class="mu"><button type="button" class="lnk" data-a="authmode" data-m="in">Já tenho conta</button></p>',
    rec:'<label>Email<input type="email" name="email" autocomplete="email" required></label><button class="btn p2" type="submit">Enviar ligação de recuperação</button><p class="mu"><button type="button" class="lnk" data-a="authmode" data-m="in">Voltar</button></p>',
    'new':'<label>Nova palavra-passe (mínimo 8 caracteres)<input type="password" name="password" autocomplete="new-password" minlength="8" required></label><button class="btn p2" type="submit">Guardar palavra-passe</button>'}[m];
  $('#v').innerHTML='<div class="login"><h2>'+t+'</h2><form class="fm" data-f="'+({in:'login',up:'signup',rec:'recuperar','new':'novasenha'}[m])+'">'+f+'</form></div>'}

function setupView(){$('#v').innerHTML='<div class="login"><h2>Falta ligar o portal</h2><p>Preencha o ficheiro <b>js/config.js</b> com o URL e a chave anon do seu projecto Supabase. O passo a passo está em <b>supabase/GUIA.md</b>.</p></div>'}

async function start(){
  var uid=(await sb.auth.getSession()).data.session.user.id;
  try{S.me=await q(sb.from('profiles').select('*').eq('id',uid).single())}
  catch(e){console.error(e);$('#v').innerHTML='<div class="login"><h2>Não foi possível abrir a conta</h2><p>'+esc(erro(e))+'</p><button class="btn p2" data-a="sair">Sair</button></div>';return}
  who();
  if(!S.me.activo){$('#v').innerHTML='<div class="login"><h2>Conta a aguardar activação</h2><p>A sua conta foi criada, mas a administração do ISAC ainda não a activou. Volte a tentar mais tarde.</p><p><button class="btn p2" data-a="reload">Verificar novamente</button> <button class="btn o2" data-a="sair">Sair</button></p></div>';return}
  S.tab=null;render()}

// ---------- eventos ----------
var A={},F={},CH={},I={};
A.tab=function(b){S.tab=b.dataset.k;render()};
A.authmode=function(b){authView(b.dataset.m)};
A.reload=function(){return start()};
A.sair=async function(){await sb.auth.signOut();authView('in')};
A.fechar=function(){$('#dlg').close()};

A.guardar=async function(b){
  var tr=b.closest('tr'),v={};
  ['t1','t2','ex'].forEach(function(k){var x=tr.querySelector('[data-k='+k+']').value;v[k]=x===''?null:+x});
  for(var k in v){if(v[k]!==null&&(isNaN(v[k])||v[k]<0||v[k]>20))return toast('As notas devem estar entre 0 e 20.')}
  var d=await q(sb.from('avaliacoes').upsert(Object.assign({matricula_id:tr.dataset.m},v),{onConflict:'matricula_id'}).select('media'));
  tr.querySelector('.med').innerHTML='<b>'+(d[0].media==null?'—':d[0].media)+'</b>';toast('Notas guardadas.',true)};
A.falta=async function(b){
  var tr=b.closest('tr'),m=tr.dataset.m,on=b.dataset.on==='1';
  if(on){var d=await q(sb.from('faltas').delete().eq('matricula_id',m).eq('data',S.dia).select());if(!d.length)throw new Error('Sem permissão para esta acção.')}
  else await q(sb.from('faltas').insert({matricula_id:m,data:S.dia}));
  b.dataset.on=on?'0':'1';b.textContent=on?'Marcar falta':'Retirar falta';
  var fc=tr.querySelector('.fc');fc.textContent=+fc.textContent+(on?-1:1);toast(on?'Falta retirada.':'Falta marcada em '+dt(S.dia)+'.',true)};
I.nota=function(el){
  var tr=el.closest('tr'),g=function(k){return tr.querySelector('[data-k='+k+']').value},a=g('t1'),b=g('t2'),c=g('ex');
  tr.querySelector('.med').innerHTML='<b>'+((a===''||b===''||c==='')?'—':Math.round(3*a+3*b+4*c)/10)+'</b>'};

A.pagar=function(b){
  var c=S.fin.filter(function(x){return x.id===b.dataset.id})[0];if(!c)return;
  $('#dlg').innerHTML='<h3 id="dlgt">Registar pagamento</h3><p>'+esc(c.aluno)+' · '+esc(c.desc)+'<br><span class="mu">Em falta: '+num(c.em_falta)+'</span></p>'+
  '<form class="fm" data-f="pagar" data-id="'+esc(c.id)+'"><label>Valor (MT)<input type="number" name="valor" min="0.01" max="'+c.em_falta+'" step="0.01" value="'+c.em_falta+'" required></label>'+
  '<label>Data<input type="date" name="data" value="'+hoje()+'" required></label>'+
  '<label>Método<select name="metodo">'+Object.keys(MET).map(function(k){return '<option value="'+k+'">'+MET[k]+'</option>'}).join('')+'</select></label>'+
  '<label>Referência da transacção (opcional)<input name="ref" maxlength="60"></label>'+
  '<div><button class="btn p2" type="submit">Registar</button> <button type="button" class="btn o2" data-a="fechar">Cancelar</button></div></form>';
  $('#dlg').showModal()};
F.pagar=async function(f){
  var c=S.fin.filter(function(x){return x.id===f.dataset.id})[0],v=+f.valor.value;
  if(!(v>0)||v>+c.em_falta)return toast('O valor deve ser maior que zero e não pode exceder '+num(c.em_falta)+'.');
  var p=await q(sb.from('pagamentos').insert({cobranca_id:c.id,valor:v,data:f.data.value,metodo:f.metodo.value,referencia:f.ref.value.trim()||null}).select('id,valor,data,metodo,referencia').single());
  S.rec={p:p,c:c,resta:+c.em_falta-v};
  $('#dlg').innerHTML='<h3 id="dlgt">Pagamento registado</h3><p>'+num(v)+' recebidos de '+esc(c.aluno)+'.</p><div><button class="btn p2" data-a="recibo">Imprimir recibo</button> <button class="btn o2" data-a="fechar">Fechar</button></div>';
  render(false)};
A.recibo=function(){
  var r=S.rec,w=window.open('','_blank');if(!w)return toast('Permita janelas pop-up para imprimir o recibo.');
  w.document.write('<!DOCTYPE html><html lang="pt"><meta charset="utf-8"><title>Recibo</title><style>body{font:15px/1.6 system-ui,sans-serif;max-width:560px;margin:30px auto;padding:0 16px}h1{margin:0}table{width:100%;border-collapse:collapse;margin:16px 0}td{padding:7px 0;border-bottom:1px solid #ccc}td:first-child{color:#555;width:42%}</style>'+
  '<h1>ISAC</h1><p>Recibo n.º <b>'+esc(r.p.id.slice(0,8).toUpperCase())+'</b></p><table>'+
  [['Data',dt(r.p.data)],['Recebido de',r.c.aluno],['Referente a',r.c.desc+' ('+r.c.curso+' · '+r.c.turma+')'],['Valor recebido',num(r.p.valor)],['Método',MET[r.p.metodo]||r.p.metodo],['Referência',r.p.referencia||'—'],['Ainda em falta nesta cobrança',num(r.resta)],['Recebido por',S.me.nome]].map(function(x){return '<tr><td>'+esc(x[0])+'</td><td>'+esc(x[1])+'</td></tr>'}).join('')+'</table>');
  w.document.close();w.focus();w.print()};

F.matricular=async function(f){
  await q(sb.rpc('matricular',{p_aluno:f.aluno.value,p_turma:f.turma.value,p_meses:+f.meses.value,p_inicio:f.inicio.value}));
  toast('Aluno matriculado. Taxa e propinas geradas.',true);render(false)};
A.propinas=async function(b){var n=await q(sb.rpc('gerar_propinas',{p_matricula:b.dataset.id,p_meses:3}));toast(n+' propinas geradas.',true)};
CH.mest=async function(el){await upd(sb.from('matriculas').update({estado:el.value}).eq('id',el.dataset.id));toast('Estado guardado.',true)};
CH.papel=async function(el){await upd(sb.from('profiles').update({papel:el.value}).eq('id',el.dataset.id));toast('Papel guardado.',true)};
CH.activo=async function(el){await upd(sb.from('profiles').update({activo:el.checked}).eq('id',el.dataset.id));toast(el.checked?'Conta activada.':'Conta desactivada.',true)};
CH.prof=async function(el){await upd(sb.from('turmas').update({professor_id:el.value||null}).eq('id',el.dataset.id));toast('Formador guardado.',true)};
CH.tact=async function(el){await upd(sb.from('turmas').update({activa:el.checked}).eq('id',el.dataset.id));toast('Turma guardada.',true)};
CH.turma=function(el){S.turma=el.value;render(false)};
CH.dia=function(el){if(el.value){S.dia=el.value;render(false)}};
CH.fe=function(el){S.fe=el.value;render(false)};
CH.fq=function(el){S.fq=el.value;render(false)};
A.salvarcurso=async function(b){var tr=b.closest('tr'),g=function(n){return tr.querySelector('[name='+n+']')};
  await upd(sb.from('cursos').update({nome:g('nome').value.trim(),taxa_matricula:+g('taxa').value,propina_mensal:+g('prop').value,activo:g('activo').checked}).eq('id',tr.dataset.id));toast('Curso guardado.',true)};
F.addcurso=async function(f){await q(sb.from('cursos').insert({nome:f.nome.value.trim(),taxa_matricula:+f.taxa.value,propina_mensal:+f.prop.value}));toast('Curso adicionado.',true);render(false)};
F.addturma=async function(f){await q(sb.from('turmas').insert({curso_id:f.curso.value,nome:f.nome.value.trim(),horario:f.horario.value.trim()||null,professor_id:f.prof.value||null}));toast('Turma adicionada.',true);render(false)};

// ---------- apagar contas / limpar dados (só administração; a confirmação é validada também no servidor) ----------
var RL={contas:'conta(s) de acesso',matriculas:'matrícula(s)',notas:'nota(s)',faltas:'falta(s)',cobrancas:'cobrança(s)',pagamentos:'pagamento(s) registado(s)',turmas:'turma(s)',cursos:'curso(s)',turmas_sem_formador:'turma(s) ficam sem formador'};
var AMB=[['notas_faltas','Notas e faltas'],['financas','Cobranças e pagamentos'],['matriculas','Matrículas (e o que depende delas: notas, faltas, cobranças, pagamentos)'],['alunos','Todas as contas de aluno (e os seus dados)'],['formadores','Todas as contas de formador'],['tudo','Tudo, excepto contas de administração (inclui cursos e turmas)']];
function resLista(r){var k=Object.keys(RL).filter(function(x){return +r[x]>0});
  return k.length?'<ul>'+k.map(function(x){return '<li><b>'+(+r[x])+'</b> '+RL[x]+'</li>'}).join('')+'</ul>':'<p class="mu">Não há nada para apagar.</p>'}
function confBox(){return '<label>Para confirmar, escreva <b>APAGAR</b><input name="conf" data-i="conf" autocomplete="off" autocapitalize="characters" required></label>'}
function dlgBtns(t){return '<div><button class="btn dg" type="submit" disabled>'+t+'</button> <button type="button" class="btn o2" data-a="fechar">Cancelar</button></div>'}
I.conf=function(el){el.closest('form').querySelector('[type=submit]').disabled=el.value!=='APAGAR'};

A.apagaruti=async function(b){
  var id=b.dataset.id,r=await q(sb.rpc('resumo_utilizador',{p_id:id}));
  $('#dlg').innerHTML='<h3 id="dlgt">Apagar conta</h3><p><b>'+esc(r.nome)+'</b> · '+esc(PAP[r.papel]||r.papel)+'</p>'+
  '<p>Vai ser apagado <b>de forma definitiva</b>: o acesso desta pessoa e ainda</p>'+resLista(r)+
  '<p class="note">Se só quer impedir o acesso, desactive a conta em vez de a apagar. A Auditoria guarda um registo do que foi apagado.</p>'+
  '<form class="fm" data-f="apagaruti" data-id="'+esc(id)+'">'+confBox()+dlgBtns('Apagar definitivamente')+'</form>';
  $('#dlg').showModal()};
F.apagaruti=async function(f){
  if(f.querySelector('[name=conf]').value!=='APAGAR')return toast('Escreva APAGAR para confirmar.');
  await q(sb.rpc('apagar_utilizador',{p_id:f.dataset.id,p_confirmacao:f.querySelector('[name=conf]').value}));
  $('#dlg').close();toast('Conta apagada.',true);render(false)};

async function previewLimpeza(amb){
  var box=$('#lres');box.innerHTML='<p class="mu">A calcular…</p>';
  try{var r=await q(sb.rpc('resumo_limpeza',{p_ambito:amb}));if($('#dlg select[name=ambito]').value===amb)box.innerHTML='<p>Vai ser apagado <b>de forma definitiva</b>:</p>'+resLista(r)}
  catch(e){console.error(e);box.innerHTML='<p class="bad">'+esc(erro(e))+'</p>'}}
A.limpar=async function(){
  $('#dlg').innerHTML='<h3 id="dlgt">Limpar dados</h3><form class="fm" data-f="limpar"><label>O que limpar<select name="ambito" data-c="ambito">'+
  AMB.map(function(o){return '<option value="'+o[0]+'">'+esc(o[1])+'</option>'}).join('')+'</select></label><div id="lres" aria-live="polite"></div>'+
  '<p class="note">Não se apagam contas de administração nem a Auditoria (que regista esta limpeza e guarda cópia do que foi apagado).</p>'+confBox()+dlgBtns('Limpar definitivamente')+'</form>';
  $('#dlg').showModal();previewLimpeza('notas_faltas')};
CH.ambito=function(el){previewLimpeza(el.value)};
F.limpar=async function(f){
  if(f.querySelector('[name=conf]').value!=='APAGAR')return toast('Escreva APAGAR para confirmar.');
  await q(sb.rpc('limpar_dados',{p_ambito:f.querySelector('[name=ambito]').value,p_confirmacao:f.querySelector('[name=conf]').value}));
  $('#dlg').close();toast('Limpeza concluída.',true);render(false)};

F.login=async function(f){var r=await sb.auth.signInWithPassword({email:f.email.value.trim(),password:f.password.value});if(r.error)throw r.error;await start()};
F.signup=async function(f){
  var r=await sb.auth.signUp({email:f.email.value.trim(),password:f.password.value,options:{data:{nome:f.nome.value.trim()}}});if(r.error)throw r.error;
  if(r.data.session)return start();
  $('#v').innerHTML='<div class="login"><h2>Verifique o seu email</h2><p>Enviámos uma ligação de confirmação. Depois de confirmar, a administração do ISAC tem de activar a sua conta.</p><button class="btn p2" data-a="authmode" data-m="in">Ir para o início de sessão</button></div>'};
F.recuperar=async function(f){var r=await sb.auth.resetPasswordForEmail(f.email.value.trim(),{redirectTo:location.origin+location.pathname});if(r.error)throw r.error;toast('Se o email existir, enviámos a ligação de recuperação.',true);authView('in')};
F.novasenha=async function(f){var r=await sb.auth.updateUser({password:f.password.value});if(r.error)throw r.error;history.replaceState(null,'',location.pathname);toast('Palavra-passe alterada.',true);await start()};

document.addEventListener('click',function(e){var b=e.target.closest('[data-a]');if(!b||!A[b.dataset.a])return;Promise.resolve(A[b.dataset.a](b)).catch(fail)});
document.addEventListener('submit',function(e){var f=e.target.closest('[data-f]');if(!f||!F[f.dataset.f])return;e.preventDefault();
  var s=f.querySelector('[type=submit]');if(s)s.disabled=true;
  Promise.resolve(F[f.dataset.f](f)).catch(fail).then(function(){if(s)s.disabled=false})});
document.addEventListener('change',function(e){var c=e.target.closest('[data-c]');if(c&&CH[c.dataset.c])Promise.resolve(CH[c.dataset.c](c)).catch(function(err){fail(err);render(false)})});
document.addEventListener('input',function(e){var c=e.target.closest('[data-i]');if(c&&I[c.dataset.i])I[c.dataset.i](c)});

// ---------- arranque ----------
(async function(){
  var cfg=window.ISAC_CONFIG||{};
  if(!window.supabase||!cfg.url||/COLE_AQUI/.test(cfg.url+cfg.key))return setupView();
  sb=window.supabase.createClient(cfg.url,cfg.key);
  sb.auth.onAuthStateChange(function(ev){
    if(ev==='SIGNED_OUT')setTimeout(function(){authView('in')},0);
    if(ev==='PASSWORD_RECOVERY')setTimeout(function(){authView('new')},0)});
  if(/type=recovery/.test(location.hash))return authView('new');
  var s=(await sb.auth.getSession()).data.session;
  if(s)start();else authView('in')})().catch(fail);
})();
