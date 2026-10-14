// Motor adaptativo do Diagnóstico ISAC (sem servidor, sem custos).
// Em vez de contar só acertos, estima a PROBABILIDADE de cada nível ser o ideal para o aluno
// (inferência bayesiana) e escolhe a pergunta seguinte que mais reduz a incerteza.
// Resultado: percentagens que somam 100%, em poucas perguntas (8 a 14).
(function (root) {
  'use strict';
  var MIN = 8, MAX = 14, CONF = 0.70, MARGEM = 0.10;
  var TAU = 0.6; // "temperatura": cada resposta pesa 60%, para não ficar demasiado confiante (ver simulação em LEIA-ME)
  var SAIDAS = ['c', 'e', 'n']; // c = certa, e = errada, n = "não sei"

  // Estados: j = 1..N  → o aluno deve COMEÇAR no nível j (domina os anteriores, ainda não domina o j);
  //          j = N+1   → já domina todos os níveis do curso.
  // P(saída | estado j, pergunta de nível q). Valores calibráveis com dados reais do ISAC.
  function veros(j, q) {
    if (q < j)  return { c: 0.88, e: 0.09, n: 0.03 };   // abaixo do nível: devia saber
    if (q === j) return { c: 0.45, e: 0.28, n: 0.27 };  // no nível: ainda não domina (sabe alguma coisa)
    if (q === j + 1) return { c: 0.20, e: 0.37, n: 0.43 }; // um nível acima: sobretudo "não sei"/palpites
    return { c: 0.12, e: 0.41, n: 0.47 };               // muito acima
  }

  function entropia(p) { var h = 0; for (var i = 0; i < p.length; i++) if (p[i] > 0) h -= p[i] * Math.log(p[i]); return h; }
  function normalizar(p) { var s = 0, i; for (i = 0; i < p.length; i++) s += p[i]; return p.map(function (x) { return x / s; }); }
  function actualizar(post, q, o) { return normalizar(post.map(function (p, i) { return p * Math.pow(veros(i + 1, q)[o], TAU); })); }

  function novo(curso, rng) {
    var n = curso.niveis.length, post = [];
    for (var i = 0; i < n + 1; i++) post.push(1 / (n + 1));
    return { curso: curso, n: n, post: post, resp: [], usadas: {}, rng: rng || Math.random };
  }

  function livres(s, nivel) {
    return s.curso.q.map(function (q, i) { return { q: q, i: i }; })
      .filter(function (x) { return x.q.n === nivel && !s.usadas[x.i]; });
  }

  // Nível cuja resposta, em média, mais reduz a incerteza.
  function melhorNivel(s) {
    var melhor = null, hm = Infinity;
    for (var l = 1; l <= s.n; l++) {
      if (!livres(s, l).length) continue;
      var h = 0;
      SAIDAS.forEach(function (o) {
        var po = 0; s.post.forEach(function (p, i) { po += p * veros(i + 1, l)[o]; });
        h += po * entropia(actualizar(s.post, l, o));
      });
      if (h < hm - 1e-9) { hm = h; melhor = l; }
    }
    return melhor;
  }

  // Devolve { i, q } (índice no banco + pergunta) ou null.
  function proxima(s) {
    var nivel = s.resp.length === 0 ? 1 : melhorNivel(s); // 1.ª pergunta fácil: aquece e dá confiança
    if (nivel == null) return null;
    var L = livres(s, nivel);
    if (!L.length) return null;
    var cont = {}; s.resp.forEach(function (r) { var k = s.curso.q[r.i].k; cont[k] = (cont[k] || 0) + 1; });
    var min = Math.min.apply(null, L.map(function (x) { return cont[x.q.k] || 0; }));
    var C = L.filter(function (x) { return (cont[x.q.k] || 0) === min; }); // varia os temas
    return C[Math.floor(s.rng() * C.length)];
  }

  function responder(s, i, saida) {
    s.usadas[i] = true;
    s.resp.push({ i: i, o: saida });
    s.post = actualizar(s.post, s.curso.q[i].n, saida);
  }

  function maximo(p) { return Math.max.apply(null, p); }
  function terminou(s) {
    var n = s.resp.length;
    if (n >= MAX) return true;
    if (n >= MIN && maximo(s.post) >= CONF) return true;
    return melhorNivel(s) == null;
  }

  // Arredonda para inteiros que somam exactamente 100.
  function arredondar(p) {
    var b = p.map(function (x) { return x * 100; }), f = b.map(Math.floor), r = 100 - f.reduce(function (a, c) { return a + c; }, 0);
    b.map(function (x, i) { return { i: i, d: x - Math.floor(x) }; }).sort(function (a, c) { return c.d - a.d; })
      .slice(0, r).forEach(function (x) { f[x.i]++; });
    return f;
  }

  function resultado(s) {
    var n = s.n, p = s.post.slice(0, n);
    p[n - 1] += s.post[n];                               // "domina tudo" conta para o último nível
    var ordem = p.map(function (x, i) { return { i: i, p: x }; }).sort(function (a, c) { return c.p - a.p; });
    var rec = ordem[0].i, incerto = null;
    var seg = ordem[1];
    if (seg && ordem[0].p - seg.p < MARGEM && Math.abs(seg.i - rec) === 1) {
      incerto = Math.max(rec, seg.i);
      rec = Math.min(rec, seg.i);                        // na dúvida, o nível mais baixo é mais seguro
    }
    var pct = arredondar(p);
    var dominaTudo = s.post[n] > s.post[n - 1] && rec === n - 1;
    // acertos por tema
    var temas = {};
    s.resp.forEach(function (r) {
      var k = s.curso.q[r.i].k; temas[k] = temas[k] || { c: 0, t: 0 };
      temas[k].t++; if (r.o === 'c') temas[k].c++;
    });
    var cert = s.resp.filter(function (r) { return r.o === 'c'; }).length;
    return {
      nivel: rec + 1, nivelNome: s.curso.niveis[rec].nome, nivelRef: s.curso.niveis[rec].ref,
      confianca: Math.round((p[rec]) * 100), pct: pct, probs: p,
      alternativa: incerto ? incerto + 1 : null, dominaTudo: dominaTudo,
      respondidas: s.resp.length, certas: cert,
      naoSei: s.resp.filter(function (r) { return r.o === 'n'; }).length,
      temas: temas
    };
  }

  var api = { novo: novo, proxima: proxima, responder: responder, terminou: terminou, resultado: resultado,
    _veros: veros, MIN: MIN, MAX: MAX };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.ISAC_MOTOR = api;
})(typeof window !== 'undefined' ? window : this);
