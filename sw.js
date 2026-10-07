/* Service worker do ISAC.
   REGRAS DE SEGURANÇA (não alterar sem pensar):
   - Só guarda em cache ficheiros ESTÁTICOS do próprio site (páginas, CSS, JS, imagens).
   - NUNCA interfere com pedidos a outros domínios (Supabase, fontes): esses vão sempre directos à rede,
     por isso notas, pagamentos e dados de contas nunca ficam guardados no telemóvel por este ficheiro.
   - Única excepção: o script público do supabase-js (versão fixa na CDN), para a página abrir sem rede.
   Ao mudar qualquer ficheiro do site, aumente o número em VERSION para os telemóveis receberem a versão nova. */
var VERSION = 'v3';
var CORE_CACHE = 'isac-core-' + VERSION;
var RUNTIME_CACHE = 'isac-runtime-' + VERSION;
var CORE = ['./', 'index.html', 'portal.html', 'offline.html', 'manifest.webmanifest',
  'css/style.css', 'js/main.js', 'js/config.js', 'js/portal.js', 'js/pwa.js',
  'img/logo.jpg', 'img/favicon.png', 'img/apple-touch-icon.png', 'img/icon-192.png', 'img/icon-512.png'];
var SUPABASE_JS = /^https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@[\d.]+\//;

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CORE_CACHE).then(function (c) {
    return Promise.all(CORE.map(function (u) { return c.add(new Request(u, { cache: 'reload' })).catch(function () {}); }));
  }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k !== CORE_CACHE && k !== RUNTIME_CACHE && /^isac-/.test(k); })
      .map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

function guardar(cache, req, res) {
  if (res && (res.status === 200 || res.type === 'opaque')) cache.put(req, res.clone()).catch(function () {});
  return res;
}
function cacheFirst(req) {
  return caches.match(req).then(function (hit) {
    if (hit) return hit;
    return fetch(req).then(function (res) { return caches.open(RUNTIME_CACHE).then(function (c) { return guardar(c, req, res); }); });
  });
}
function staleWhileRevalidate(req) {
  return caches.match(req).then(function (hit) {
    var rede = fetch(req).then(function (res) { return caches.open(RUNTIME_CACHE).then(function (c) { return guardar(c, req, res); }); }).catch(function () { return hit; });
    return hit || rede;
  });
}
function paginaRedeDepois(req) {
  var tempo = new Promise(function (_, rej) { setTimeout(rej, 4000); });
  var rede = fetch(req).then(function (res) { return caches.open(CORE_CACHE).then(function (c) { return guardar(c, req, res); }); });
  return Promise.race([rede, tempo]).catch(function () {
    return caches.match(req, { ignoreSearch: true }).then(function (hit) {
      return hit || rede.catch(function () { return caches.match('offline.html'); });
    });
  });
}

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  if (SUPABASE_JS.test(req.url)) { e.respondWith(cacheFirst(req)); return; }
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;           // Supabase, fontes, etc.: direto à rede, sem cache
  if (req.mode === 'navigate') { e.respondWith(paginaRedeDepois(req)); return; }
  if (req.destination === 'style' || req.destination === 'script' || url.pathname.slice(-16) === '.webmanifest') {
    e.respondWith(staleWhileRevalidate(req)); return;
  }
  if (req.destination === 'image' || req.destination === 'font') { e.respondWith(cacheFirst(req)); }
});
