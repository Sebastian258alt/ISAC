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
})();
