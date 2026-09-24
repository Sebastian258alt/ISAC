
const $=s=>document.querySelector(s);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const D=['Inglês','Informática'];
const K={t1:'Teste escrito',t2:'Oral',ex:'Teste final'};
const A=[{id:1,n:'Ana Macuácua'},{id:2,n:'Bruno Sitoe'},{id:3,n:'Carla Mondlane'},{id:4,n:'Délcio Tembe'},{id:5,n:'Eliana Cossa'},{id:6,n:'Fábio Chissano'}];
const R={aluno:'Aluno',professor:'Formador',admin:'Administração'};
const PROF='Formador (demo)';
const cl=v=>Math.max(0,Math.min(20,v));
const base=[14,8,17,11,6,13],fb=[1,6,0,3,8,2];
const G={},F={};
A.forEach((a,i)=>{
  G[a.id]=D.map((_,d)=>{const b=cl(base[i]-d);return{t1:b,t2:cl(b+1),ex:cl(b+(i%2?1:-1))}});
  F[a.id]=D.map((_,d)=>Math.max(0,fb[i]-d));
});
let role='aluno',me=1,cur=0,log=[],tt;
const nm=id=>A.find(a=>a.id==id).n;
const mf=g=>+(g.t1*.3+g.t2*.3+g.ex*.4).toFixed(1);
const avg=a=>+(G[a].reduce((s,g)=>s+mf(g),0)/D.length).toFixed(1);
const tf=a=>F[a].reduce((s,x)=>s+x,0);
const est=a=>avg(a)>=10&&tf(a)<10?['Em dia','ok']:['Em risco','wr'];
const L=(w,t)=>log.unshift({h:new Date().toLocaleTimeString('pt-PT',{hour:'2-digit',minute:'2-digit',second:'2-digit'}),w,t});
function toast(m){const t=$('#toast');t.textContent=m;t.style.display='block';clearTimeout(tt);tt=setTimeout(()=>t.style.display='none',3000)}

const vA=()=>{const [e,c]=est(me);return `<div class="w"><div class="demo">Dados fictícios. Escolha um aluno para ver o que ele vê.</div>
<div class="bar"><label>Entrar como <select id="who">${A.map(a=>`<option value="${a.id}"${a.id==me?' selected':''}>${esc(a.n)}</option>`).join('')}</select></label><span class="pill ${c}">${e}</span></div>
<div class="kpis"><div class="k"><b>${avg(me)}</b><span>Média geral (0–20)</span></div><div class="k"><b>${tf(me)}</b><span>Faltas no total</span></div></div>
<div class="grid">${D.map((d,i)=>{const g=G[me][i],m=mf(g);return `<div class="card"><h3>${d}</h3><p class="mu">${K.t1}: <b>${g.t1}</b> · ${K.t2}: <b>${g.t2}</b> · ${K.ex}: <b>${g.ex}</b></p><p>Média <b class="${m<10?'bad':''}">${m}</b> · Faltas <b>${F[me][i]}</b></p></div>`}).join('')}</div>
<p class="note">O aluno vê apenas os seus próprios dados e não pode alterar nada.</p></div>`};

const vP=()=>`<div class="w"><div class="demo">Dados fictícios. Altere uma nota ou falta e veja o registo no perfil Administração.</div>
<div class="bar"><b>${PROF}</b><label>Curso <select id="cur">${D.map((d,i)=>`<option value="${i}"${i==cur?' selected':''}>${d}</option>`).join('')}</select></label></div>
<div class="tw"><table><tr><th>Aluno<th>${K.t1}<th>${K.t2}<th>${K.ex}<th>Média<th>Faltas</tr>${A.map(a=>{const g=G[a.id][cur],m=mf(g);return `<tr><td>${esc(a.n)}`+['t1','t2','ex'].map(k=>`<td><input type="number" min="0" max="20" step="0.5" value="${g[k]}" data-a="${a.id}" data-k="${k}" aria-label="${K[k]} de ${esc(a.n)}">`).join('')+`<td><b class="${m<10?'bad':''}">${m}</b><td><span class="st"><button data-f="${a.id}" data-d="-1" aria-label="Menos uma falta">−</button>${F[a.id][cur]}<button data-f="${a.id}" data-d="1" aria-label="Mais uma falta">+</button></span>`}).join('')}</table></div>
<p class="note">O formador só lança dados do seu curso. Média = 30% ${K.t1} + 30% ${K.t2} + 40% ${K.ex} (regra de exemplo). Cada alteração fica registada.</p></div>`;

const vM=()=>{const av=+(A.reduce((s,a)=>s+avg(a.id),0)/A.length).toFixed(1),r=A.filter(a=>est(a.id)[1]=='wr').length;return `<div class="w"><div class="demo">Dados fictícios. Visão geral da turma.</div>
<div class="kpis"><div class="k"><b>${av}</b><span>Média da turma</span></div><div class="k"><b>${A.reduce((s,a)=>s+tf(a.id),0)}</b><span>Faltas no total</span></div><div class="k"><b class="${r?'bad':''}">${r}</b><span>Alunos em risco</span></div></div>
<div class="tw"><table><tr><th>Aluno<th>Média geral<th>Faltas<th>Estado</tr>${A.map(a=>{const [e,c]=est(a.id);return `<tr><td>${esc(a.n)}<td>${avg(a.id)}<td>${tf(a.id)}<td><span class="pill ${c}">${e}</span>`}).join('')}</table></div>
<h3 style="margin-top:22px">Registo de auditoria</h3>
<div class="tw"><table><tr><th>Hora<th>Quem<th>Alteração</tr>${log.length?log.slice(0,12).map(l=>`<tr><td>${l.h}<td>${esc(l.w)}<td>${esc(l.t)}`).join(''):'<tr><td colspan="3" class="mu">Ainda sem alterações. Mude uma nota no perfil Formador e volte aqui.'}</table></div>
<p class="note">Em risco: média geral abaixo de 10 ou 10 faltas ou mais (regra de exemplo).</p></div>`};

function render(){
  $('#tabs').innerHTML=Object.keys(R).map(k=>`<button data-r="${k}" class="${k==role?'on':''}" aria-pressed="${k==role}">${R[k]}</button>`).join('');
  $('#v').innerHTML=({aluno:vA,professor:vP,admin:vM})[role]();
}
document.addEventListener('click',e=>{
  const b=e.target.closest('button');if(!b)return;
  if(b.dataset.r){role=b.dataset.r;render();scrollTo(0,0);return}
  if(b.dataset.go){$('#'+b.dataset.go).scrollIntoView();return}
  if(b.dataset.f){const id=+b.dataset.f,o=F[id][cur],n=Math.max(0,o+ +b.dataset.d);
    if(n!==o){F[id][cur]=n;L(PROF,`Faltas de ${nm(id)} a ${D[cur]}: ${o} → ${n}`);render()}}
});
document.addEventListener('change',e=>{
  const t=e.target;
  if(t.id==='who'){me=+t.value;render();return}
  if(t.id==='cur'){cur=+t.value;render();return}
  if(t.dataset.k){const id=+t.dataset.a,v=parseFloat(t.value),g=G[id][cur],k=t.dataset.k;
    if(isNaN(v)||v<0||v>20){toast('Nota inválida. Use um valor entre 0 e 20.');render();return}
    if(g[k]!==v){L(PROF,`${K[k]} de ${nm(id)} a ${D[cur]}: ${g[k]} → ${v}`);g[k]=v}
    render();}
});
render();
