(function(){
'use strict';
var D=window.ISAC_DIAG,M=window.ISAC_MOTOR,CF=window.ISAC_CONFIG||{},root=document.getElementById('dg');
var ICON={ingles:'Inglês',mandarim:'Mandarim',informatica:'Informática',eletricidade:'Electricidade'};
var S=null,chave=null,tIni=0;

function el(t,c,x){var e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e}
function limpa(){root.textContent='';window.scrollTo(0,0)}
function emb(a,rng){a=a.slice();for(var i=a.length-1;i>0;i--){var j=Math.floor(rng()*(i+1)),t=a[i];a[i]=a[j];a[j]=t}return a}
function wa(m){return 'https://wa.me/'+(CF.whatsapp||'258865166752')+'?text='+encodeURIComponent(m)}
function rpc(n,b){return fetch(CF.url+'/rest/v1/rpc/'+n,{method:'POST',headers:{'Content-Type':'application/json',apikey:CF.key,Authorization:'Bearer '+CF.key},body:JSON.stringify(b)})}

// ---------- 1. escolha do curso ----------
function inicio(){
  limpa();
  root.appendChild(el('h1','','Diagnóstico gratuito de nível'));
  root.appendChild(el('p','lead','Descubra em cerca de 5 minutos qual é o melhor nível para começar. É grátis, não precisa de conta e não o obriga a matricular-se.'));
  var b=el('div','dgb');b.innerHTML='<b>Como funciona:</b> o teste adapta-se às suas respostas. Se não souber uma pergunta, escolha <b>“Não sei”</b>: não perde pontos e ajuda-nos a indicar o nível certo. Não use dicionário nem ajuda, para o resultado ser fiel.';
  root.appendChild(b);
  root.appendChild(el('h3','','Escolha o curso'));
  var g=el('div','dgc');
  Object.keys(D).forEach(function(k){
    var bt=el('button');bt.type='button';bt.appendChild(el('b','',D[k].nome));bt.appendChild(el('small','',D[k].niveis.length+' níveis'));
    bt.addEventListener('click',function(){comecar(k)});g.appendChild(bt)});
  root.appendChild(g);
  var pre=location.hash.replace('#','');if(D[pre]&&history.replaceState)history.replaceState(null,'',location.pathname);
}

// ---------- 2. perguntas ----------
function comecar(k){chave=k;S=M.novo(D[k]);tIni=Date.now();perguntar()}

function perguntar(){
  if(M.terminou(S))return resultado();
  var x=M.proxima(S);if(!x)return resultado();
  limpa();
  var n=S.resp.length,total=M.MAX;
  root.appendChild(el('p','mu',D[chave].nome+' · Pergunta '+(n+1)+' (no máximo '+total+')'));
  var p=el('div','dgp');p.setAttribute('role','progressbar');p.setAttribute('aria-valuemin','0');p.setAttribute('aria-valuemax',total);p.setAttribute('aria-valuenow',n);
  var i=el('i');i.style.width=Math.round(100*n/total)+'%';p.appendChild(i);root.appendChild(p);
  var c=el('div','dgq'),h=el('h2','',x.q.t);c.appendChild(h);
  var ops=x.q.o.map(function(t,idx){return{t:t,ok:idx===x.q.c}});ops=emb(ops,Math.random);
  var l=el('div','dgo');
  function resp(o){S&&M.responder(S,x.i,o);perguntar()}
  ops.forEach(function(op){var b=el('button','',op.t);b.type='button';b.addEventListener('click',function(){resp(op.ok?'c':'e')});l.appendChild(b)});
  var ns=el('button','ns','Não sei');ns.type='button';ns.addEventListener('click',function(){resp('n')});l.appendChild(ns);
  c.appendChild(l);root.appendChild(c);
  var q=el('p','note');q.appendChild(el('button','lnk','Mudar de curso'));q.firstChild.type='button';
  q.firstChild.addEventListener('click',function(){if(confirm('Sair deste teste e escolher outro curso?'))inicio()});root.appendChild(q);
  h.tabIndex=-1;h.focus({preventScroll:true});
}

// ---------- 3. resultado ----------
var NIV_TXT=function(r,c){return c.niveis[r.nivel-1].nome+(c.niveis[r.nivel-1].ref?' ('+c.niveis[r.nivel-1].ref+')':'')};

function textoLocal(r,c){
  var fortes=[],fracos=[];
  Object.keys(r.temas).forEach(function(k){var t=r.temas[k];if(t.t<2)return;var p=t.c/t.t;if(p>=0.7)fortes.push(k);else if(p<=0.4)fracos.push(k)});
  var niv=c.niveis[r.nivel-1];
  return {
    resumo:'Com base nas suas respostas, o nível mais indicado para começar em '+c.nome+' é o '+niv.nome+'. '+niv.desc,
    fortes:fortes.length?['Foi bem em: '+fortes.join(', ')+'.']:[],
    melhorar:fracos.length?['Precisa de reforçar: '+fracos.join(', ')+'.']:[],
    plano:['Estude 20 a 30 minutos por dia, de forma regular.','Venha à primeira aula: o formador confirma o seu nível e pode ajustá-lo.'],
    local:true};
}

function pedirIA(r,c){
  if(!CF.url||!CF.key||CF.ia===false)return Promise.reject();
  var corpo={curso:chave,nivel:r.nivel,confianca:r.confianca,pct:r.pct,respondidas:r.respondidas,certas:r.certas,naoSei:r.naoSei,
    temas:Object.keys(r.temas).map(function(k){return{k:k,c:r.temas[k].c,t:r.temas[k].t}}),dominaTudo:r.dominaTudo};
  var ctl=window.AbortController?new AbortController():null,to=setTimeout(function(){ctl&&ctl.abort()},15000);
  return fetch(CF.url+'/functions/v1/diagnostico-ia',{method:'POST',signal:ctl&&ctl.signal,
    headers:{'Content-Type':'application/json',apikey:CF.key,Authorization:'Bearer '+CF.key},body:JSON.stringify(corpo)})
  .then(function(x){clearTimeout(to);if(!x.ok)throw 0;return x.json()})
  .then(function(j){if(!j||typeof j.resumo!=='string')throw 0;return j});
}

function lista(arr,tit,pai){if(!arr||!arr.length)return;pai.appendChild(el('p','',tit)).style.fontWeight='700';
  var u=el('ul');arr.slice(0,4).forEach(function(t){u.appendChild(el('li','',String(t).slice(0,240)))});pai.appendChild(u)}

function pintaAnalise(box,a){
  box.textContent='';var h=el('h3','','Análise personalizada');
  h.appendChild(el('span','tag',a.local?'Resumo automático':'Feita por IA'));box.appendChild(h);
  box.appendChild(el('p','',String(a.resumo).slice(0,600)));
  lista(a.fortes,'Pontos fortes',box);lista(a.melhorar,'A melhorar',box);lista(a.plano,'Como se preparar',box);
}

function resultado(){
  var r=M.resultado(S),c=D[chave],segs=Math.round((Date.now()-tIni)/1000);
  try{localStorage.setItem('isac_diag',JSON.stringify({curso:chave,cursoNome:c.nome,nivel:r.nivel,nivelNome:c.niveis[r.nivel-1].nome,confianca:r.confianca,em:Date.now()}))}catch(e){}
  limpa();
  var box=el('div','dgr');box.appendChild(el('small','','O seu nível recomendado em '+c.nome));
  box.appendChild(el('div','nv',NIV_TXT(r,c)));
  box.appendChild(el('span','pc','Confiança: '+r.confianca+'%'));
  box.appendChild(el('p','',c.niveis[r.nivel-1].desc)).style.margin='12px 0 0';
  root.appendChild(box);
  if(r.alternativa)root.appendChild(el('p','dgb','Está entre dois níveis: '+c.niveis[r.nivel-1].nome+' ('+r.pct[r.nivel-1]+'%) e '+c.niveis[r.alternativa-1].nome+' ('+r.pct[r.alternativa-1]+'%). Recomendamos o mais baixo para começar com segurança; o formador pode subir-lhe o nível rapidamente se for fácil demais.'));
  else if(r.confianca<60)root.appendChild(el('p','dgb','Resultado indicativo: as suas respostas deixaram alguma dúvida. O formador confirma o nível na primeira aula.'));
  if(r.dominaTudo)root.appendChild(el('p','dgb','Domina bem os conteúdos até ao último nível. Fale com a secretaria sobre turmas avançadas ou certificação.'));

  var d=el('div','dgd');d.appendChild(el('h3','','Probabilidade de cada nível ser o ideal para si'));
  c.niveis.forEach(function(n,i){var li=el('div','dgn'+(i===r.nivel-1?' rec':''));
    li.appendChild(el('b','',n.nome));var b=el('div','bar2'),f=el('i');f.style.width=r.pct[i]+'%';b.appendChild(f);li.appendChild(b);li.appendChild(el('span','',r.pct[i]+'%'));d.appendChild(li)});
  root.appendChild(d);

  var tk=Object.keys(r.temas).filter(function(k){return r.temas[k].t>=1});
  if(tk.length){var t=el('div','dgd dgt');t.appendChild(el('h3','','Acertos por tema'));
    tk.forEach(function(k){var x=r.temas[k],p=Math.round(100*x.c/x.t),li=el('div','dgn');li.appendChild(el('b','',k));
      var b=el('div','bar2'),f=el('i');f.style.width=p+'%';b.appendChild(f);li.appendChild(b);li.appendChild(el('span','',x.c+'/'+x.t));t.appendChild(li)});
    t.appendChild(el('p','note','Respondeu a '+r.respondidas+' perguntas ('+r.certas+' certas, '+r.naoSei+' “Não sei”) em '+Math.max(1,Math.round(segs/60))+' min.'));root.appendChild(t)}

  var ia=el('div','dgia');ia.appendChild(el('h3','','Análise personalizada'));ia.appendChild(el('p','mu','A preparar a sua análise…'));root.appendChild(ia);
  pedirIA(r,c).then(function(a){pintaAnalise(ia,a)}).catch(function(){pintaAnalise(ia,textoLocal(r,c))});

  // guardar o resultado (opcional)
  var gl=el('div','dgl');gl.appendChild(el('h3','','Quer que a secretaria guarde o seu resultado?'));
  gl.appendChild(el('p','mu','Opcional. Assim, ao matricular-se ou ao visitar uma unidade, já sabemos o seu nível e pode ser contactado sobre turmas e horários.'));
  var f=el('form','fm');f.noValidate=true;
  f.innerHTML='<label>O seu nome<input name="nome" maxlength="80" autocomplete="name"></label><label>Telefone / WhatsApp<input name="tel" type="tel" maxlength="20" autocomplete="tel" placeholder="84 000 0000"></label>'+
    '<label class="sr" aria-hidden="true">Não preencha<input name="site" tabindex="-1" autocomplete="off"></label>'+
    '<label class="chk"><input type="checkbox" name="ok"> Autorizo o ISAC a guardar o meu resultado e a contactar-me sobre o curso.</label><div><button class="btn p2" type="submit">Guardar resultado</button></div><p class="note" role="status" id="dgm"></p>';
  var salvo=false;
  f.addEventListener('submit',function(e){e.preventDefault();var m=f.querySelector('#dgm'),say=function(t,k){m.textContent=t;m.className='note '+(k||'')};
    if(salvo)return;var E=f.elements,nome=E.nome.value.trim(),tel=E.tel.value.trim();
    if(nome.length<2)return say('Escreva o seu nome.','bad');if(tel.replace(/\D/g,'').length<9)return say('Indique um telefone válido (9 dígitos).','bad');
    if(!E.ok.checked)return say('Marque a autorização para guardarmos o resultado.','bad');if(!CF.url)return say('O envio não está disponível neste momento.','bad');
    var b=f.querySelector('[type=submit]');b.disabled=true;say('A guardar…');
    rpc('registar_diagnostico',{p_curso:chave,p_nivel:r.nivel,p_nivel_nome:c.niveis[r.nivel-1].nome,p_confianca:r.confianca,p_pct:r.pct,p_respondidas:r.respondidas,p_certas:r.certas,p_nome:nome,p_telefone:tel,p_site:E.site.value})
    .then(function(x){if(!x.ok)return x.json().catch(function(){return{}}).then(function(j){throw new Error(j&&j.message||'')})})
    .then(function(){salvo=true;say('Resultado guardado. Obrigado, '+nome.split(' ')[0]+'!','ok')})
    .catch(function(er){b.disabled=false;say(er&&/[a-zà-ú]{4}/i.test(er.message)&&!/fetch|network/i.test(er.message)?er.message:'Não foi possível guardar agora. Tente de novo ou fale connosco pelo WhatsApp.','bad')})});
  gl.appendChild(f);root.appendChild(gl);

  var cta=el('div','cta');
  var a1=el('a','btn p2','Matricular-me neste nível');a1.href='portal.html#matricula';cta.appendChild(a1);
  var a2=el('a','btn o2','Falar com o ISAC no WhatsApp');a2.target='_blank';a2.rel='noopener';
  a2.href=wa('Olá, fiz o diagnóstico gratuito de '+c.nome+' e o resultado foi: '+c.niveis[r.nivel-1].nome+' ('+r.confianca+'% de confiança). Quero informações sobre turmas e horários.');cta.appendChild(a2);
  var a3=el('button','btn o2','Fazer outro diagnóstico');a3.type='button';a3.addEventListener('click',inicio);cta.appendChild(a3);
  root.appendChild(cta);
  root.appendChild(el('p','note','O diagnóstico é uma orientação, não um exame oficial. O formador confirma o seu nível na primeira aula.'));
  S=null;
}

if(!D||!M){root.textContent='Não foi possível carregar o teste.';return}
inicio();
})();
