// PWA: regista o service worker e mostra o botão "Instalar app" (só quando o navegador o permite).
(function () {
  'use strict';
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function (e) { console.error('Service worker:', e); });
    });
  }
  var slot = document.getElementById('pwa-slot'), adiado = null;
  var instalada = (window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  if (!slot || instalada) return;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault(); adiado = e;
    slot.hidden = false;
  });
  slot.addEventListener('click', function () {
    if (!adiado) return;
    adiado.prompt();
    adiado.userChoice.then(function () { adiado = null; slot.hidden = true; });
  });
  window.addEventListener('appinstalled', function () { adiado = null; slot.hidden = true; });
})();
