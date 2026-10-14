// Edge Function "diagnostico-ia": escreve a análise personalizada do diagnóstico.
// As PERCENTAGENS e o NÍVEL vêm do motor (js/motor.js); a IA só explica e aconselha.
// Recebe apenas números e palavras de uma lista fixa (nada de texto livre do aluno),
// por isso não há risco de "injecção de instruções". Segredos: ANTHROPIC_API_KEY (obrigatório).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const CURSOS: Record<string, { nome: string; niveis: string[]; temas: string[] }> = {
  ingles: { nome: "Inglês", niveis: ["Iniciante", "Básico", "Intermédio", "Avançado"], temas: ["Vocabulário", "Gramática", "Leitura"] },
  mandarim: { nome: "Mandarim", niveis: ["Iniciante", "Elementar", "Intermédio"], temas: ["Vocabulário", "Pronúncia", "Gramática", "Leitura"] },
  informatica: { nome: "Informática", niveis: ["Iniciante", "Básico", "Intermédio", "Avançado"], temas: ["Fundamentos", "Windows", "Word", "Internet", "Excel", "PowerPoint", "Segurança", "Redes", "Programação"] },
  eletricidade: { nome: "Electricidade", niveis: ["Iniciante", "Básico", "Intermédio"], temas: ["Fundamentos", "Segurança", "Lei de Ohm", "Circuitos", "Potência", "Instalação", "Protecções", "Trifásico", "Medição", "Esquemas"] },
};
const POR_IP_DIA = 10, GLOBAL_DIA = 800;
const MODELO = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-5-5";

const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const int = (v: unknown, a: number, b: number) => (Number.isInteger(v) && (v as number) >= a && (v as number) <= b ? (v as number) : null);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ erro: "método" }, 405);

  let b: any;
  try { b = await req.json(); } catch { return json({ erro: "json" }, 400); }
  const c = CURSOS[b?.curso];
  const nivel = int(b?.nivel, 1, c?.niveis.length ?? 0), conf = int(b?.confianca, 0, 100);
  const resp = int(b?.respondidas, 1, 40), certas = int(b?.certas, 0, 40), ns = int(b?.naoSei, 0, 40);
  if (!c || !nivel || conf === null || !resp || certas === null || ns === null || !Array.isArray(b.pct) || b.pct.length !== c.niveis.length
      || !b.pct.every((x: unknown) => int(x, 0, 100) !== null) || !Array.isArray(b.temas) || b.temas.length > 12) return json({ erro: "dados" }, 400);
  const temas = [];
  for (const t of b.temas) {
    if (!c.temas.includes(t?.k) || int(t?.c, 0, 40) === null || int(t?.t, 1, 40) === null) return json({ erro: "dados" }, 400);
    temas.push(`${t.k}: ${t.c}/${t.t}`);
  }

  // limites (por origem e globais)
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "?";
  const h = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ip + "isac")))).slice(0, 8).map((x) => x.toString(16).padStart(2, "0")).join("");
  const dia = new Date(Date.now() - 86400000).toISOString();
  const [a, g] = await Promise.all([
    sb.from("diag_ia_uso").select("id", { count: "exact", head: true }).eq("ip_hash", h).gt("criado_em", dia),
    sb.from("diag_ia_uso").select("id", { count: "exact", head: true }).gt("criado_em", dia),
  ]);
  if ((a.count ?? 0) >= POR_IP_DIA || (g.count ?? 0) >= GLOBAL_DIA) return json({ erro: "limite" }, 429);
  await sb.from("diag_ia_uso").insert({ ip_hash: h });

  const dist = c.niveis.map((n, i) => `${n} ${b.pct[i]}%`).join(", ");
  const prompt = `Diagnóstico de nível no ISAC (instituto de cursos em Maputo/Matola, Moçambique).
Curso: ${c.nome}. Nível recomendado: ${c.niveis[nivel - 1]} (confiança ${conf}%).
Probabilidade de cada nível ser o ideal: ${dist}.
Respondeu a ${resp} perguntas: ${certas} certas, ${ns} "não sei".
Acertos por tema: ${temas.join("; ") || "n/d"}.${b.dominaTudo ? "\nO aluno domina todos os níveis do curso." : ""}

Escreve em português de Moçambique, tom simpático e motivador, para um aluno comum (linguagem simples).
Responde APENAS com JSON, sem texto à volta, neste formato:
{"resumo":"2 a 3 frases a explicar o resultado e o que vai aprender neste nível","fortes":["até 2 pontos"],"melhorar":["até 2 pontos"],"plano":["3 conselhos práticos e curtos para se preparar"]}
Usa SÓ os números acima; não inventes percentagens, preços, horários nem promessas de emprego.`;

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: MODELO, max_tokens: 600, messages: [{ role: "user", content: prompt }] }),
    });
    if (!r.ok) return json({ erro: "ia" }, 502);
    const d = await r.json();
    const txt = (d.content ?? []).map((x: any) => x.text ?? "").join("").replace(/```json|```/g, "").trim();
    const o = JSON.parse(txt.slice(txt.indexOf("{"), txt.lastIndexOf("}") + 1));
    const lim = (v: unknown, n: number) => (Array.isArray(v) ? v.filter((x) => typeof x === "string").slice(0, n).map((x) => x.slice(0, 240)) : []);
    if (typeof o.resumo !== "string") return json({ erro: "ia" }, 502);
    return json({ resumo: o.resumo.slice(0, 600), fortes: lim(o.fortes, 2), melhorar: lim(o.melhorar, 2), plano: lim(o.plano, 3) });
  } catch { return json({ erro: "ia" }, 502); }
});
