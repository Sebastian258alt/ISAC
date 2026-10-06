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
})();
