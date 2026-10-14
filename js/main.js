(function(){
  var nav=document.getElementById('nav'),mb=document.querySelector('.mb');
  if(mb){mb.addEventListener('click',function(){var o=nav.classList.toggle('open');mb.setAttribute('aria-expanded',o)});
    nav.addEventListener('click',function(e){if(e.target.tagName==='A'){nav.classList.remove('open');mb.setAttribute('aria-expanded',false)}})}
  document.querySelectorAll('a[data-c]').forEach(function(a){a.href+='?text='+encodeURIComponent('Olá, quero informações sobre o curso de '+a.dataset.c+'.')});
  document.querySelectorAll('a[data-t]').forEach(function(a){a.href+='?text='+encodeURIComponent(a.dataset.t)});
  var y=document.getElementById('yr');if(y)y.textContent=new Date().getFullYear();
  var lb=document.getElementById('lb');
  if(lb){var im=lb.querySelector('img');
    document.querySelectorAll('.gg button').forEach(function(b){b.addEventListener('click',function(){var s=b.querySelector('img');im.src=s.src;im.alt=s.alt;lb.showModal()})});
    lb.addEventListener('click',function(e){if(e.target===lb||e.target.className==='x')lb.close()})}
  var fi=document.getElementById('faqq');
  if(fi){var nm=function(t){return t.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()};
    fi.addEventListener('input',function(){var q=nm(fi.value.trim()),n=0;
      document.querySelectorAll('#faql details').forEach(function(d){var ok=!q||nm(d.textContent).indexOf(q)>-1;d.hidden=!ok;d.open=!!q&&ok;if(ok)n++});
      document.querySelectorAll('#faql .fqh').forEach(function(h){var x=h.nextElementSibling,v=false;while(x&&x.tagName==='DETAILS'){if(!x.hidden)v=true;x=x.nextElementSibling}h.hidden=!v});
      document.getElementById('faqn').hidden=n>0})}
  // comentários e sugestões (função pública no Supabase; sem login)
  var cf=window.ISAC_CONFIG||{},sf=document.getElementById('sugf'),cl=document.getElementById('comlist');
  function rpc(n,b){return fetch(cf.url+'/rest/v1/rpc/'+n,{method:'POST',headers:{'Content-Type':'application/json',apikey:cf.key,Authorization:'Bearer '+cf.key},body:JSON.stringify(b||{})})}
  function listar(){if(!cl)return;
    rpc('comentarios_publicos').then(function(r){if(!r.ok)throw 0;return r.json()}).then(function(a){
      cl.textContent='';
      if(!a.length){var p=document.createElement('p');p.className='mu';p.textContent='Ainda não há comentários publicados. Seja o primeiro!';cl.appendChild(p);return}
      a.forEach(function(x){var d=document.createElement('div');d.className='cm';
        if(x.avaliacao){var s=document.createElement('div');s.className='st';s.setAttribute('aria-label',x.avaliacao+' de 5 estrelas');s.textContent='★'.repeat(x.avaliacao)+'☆'.repeat(5-x.avaliacao);d.appendChild(s)}
        var p=document.createElement('p');p.textContent=x.mensagem;d.appendChild(p);
        var n=document.createElement('small');n.textContent='— '+x.nome+' · '+new Date(x.criado_em).toLocaleDateString('pt-PT');d.appendChild(n);cl.appendChild(d)})
    }).catch(function(){cl.innerHTML='<p class="mu">Não foi possível carregar os comentários agora.</p>'})}
  if(cl&&cf.url)listar();
  if(sf){var sm=document.getElementById('sugm');
    sf.addEventListener('submit',function(e){e.preventDefault();
      var f=sf.elements,msg=f.msg.value.trim(),b=sf.querySelector('[type=submit]');
      var say=function(t,k){sm.textContent=t;sm.className='note '+(k||'')};
      if(msg.length<10)return say('Escreva pelo menos 10 caracteres.','bad');
      if(!cf.url)return say('O envio não está disponível neste momento.','bad');
      b.disabled=true;say('A enviar…');
      rpc('enviar_sugestao',{p_tipo:f.tipo.value,p_nome:f.nome.value.trim(),p_contacto:f.contacto.value.trim(),p_mensagem:msg,
        p_avaliacao:f.aval.value?+f.aval.value:null,p_publicar:f.pub.checked,p_site:f.site.value})
      .then(function(r){if(r.ok)return null;return r.json().catch(function(){return{}}).then(function(j){throw new Error(j&&j.message||'')})})
      .then(function(){say(f.pub.checked?'Obrigado! A sua mensagem foi enviada e será publicada depois de revista.':'Obrigado! A sua mensagem foi enviada.','ok');sf.reset()})
      .catch(function(err){var m=err&&err.message&&/[a-zà-ú]/i.test(err.message)&&!/fetch|network/i.test(err.message)?err.message:'Não foi possível enviar agora. Verifique a internet ou envie pelo WhatsApp.';say(m,'bad')})
      .then(function(){b.disabled=false})})}
  // avisos públicos da instituição
  var av=document.getElementById('avisos'),al=document.getElementById('avlist');
  if(av&&al&&cf.url)rpc('avisos_publicos').then(function(r){if(!r.ok)throw 0;return r.json()}).then(function(a){
    if(!a.length)return;var nv={info:'Informação',importante:'Importante',urgente:'Urgente'};
    a.forEach(function(x){var d=document.createElement('article');d.className='av '+x.nivel;
      var t=document.createElement('h3');t.textContent=(x.nivel==='urgente'?'⚠ ':'')+x.titulo;var p=document.createElement('p');p.style.whiteSpace='pre-wrap';p.textContent=x.mensagem;
      var s=document.createElement('small');s.className='mu';s.textContent=(nv[x.nivel]||'')+' · '+new Date(x.publicado_em).toLocaleDateString('pt-PT');
      d.appendChild(t);d.appendChild(p);d.appendChild(s);al.appendChild(d)});
    av.hidden=false;var n=document.getElementById('navav');if(n)n.hidden=false}).catch(function(){});
})();
