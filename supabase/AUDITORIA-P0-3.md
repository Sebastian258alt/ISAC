# ISAC · P0-3 · Auditoria de contas, papéis e escalação de privilégios

Método: o `schema.sql` original e o corrigido foram carregados num PostgreSQL 16 com os papéis
`anon`/`authenticated` do Supabase e os privilégios por defeito do Supabase. Cada ataque foi feito
como o PostgREST o faz (`SET ROLE` + JWT `sub`), sem passar pelo portal.
`supabase/testes_P0-3.sql` reproduz tudo (146 testes): **original 136/146 · corrigido 146/146**
(instalação nova e migração do esquema original).

## 1. Como o papel é determinado
O papel efectivo vem **apenas** de `public.profiles.papel` + `activo`, lido pelo PostgreSQL via
`auth.uid()` (JWT assinado). O JavaScript só usa `S.me.papel` para escolher separadores; um
utilizador que o altere no browser continua a receber os dados que o RLS permite.
Não há `role` no `user_metadata` a ser usado (o gatilho `novo_utilizador` só lê `nome`; o
`user_metadata` é editável pelo utilizador e nunca entra em nenhuma policy).
`localStorage`/`sessionStorage`: o código do ISAC não os usa; só o supabase-js guarda lá o token de
sessão (autenticação; um token alterado deixa de ter assinatura válida). URL: só se lê
`location.hash` para `type=recovery` (mostra o formulário de nova palavra-passe; exige sessão de
recuperação válida). Nenhum `?role=`, `?user_id=`, `?turma_id=` é lido.

## 2. Vulnerabilidades e fragilidades
| # | Sev. | Descrição | Correcção |
|---|------|-----------|-----------|
| 1 | MÉDIA | **Bootstrap do admin por email.** O guia mandava correr `update ... where email='x'`. Com "Confirm email" desligado (o próprio guia sugeria), um atacante regista primeiro esse email com a sua palavra-passe; ao correr o UPDATE, o admin é ele. Impacto: controlo total. O comando também podia ser repetido para criar mais admins. | GUIA.md: exige `email_confirmed_at`, só corre se **não existir admin**, e manda ligar a confirmação antes. Só o dono da BD o executa (não há RPC). |
| 2 | MÉDIA | **Protecção de `profiles` dependia de uma única policy.** Hoje só o admin actualiza, mas bastava alguém acrescentar `auth.uid() = id` (para deixar editar o telefone) para um aluno fazer `papel='admin'` ou activar-se. Demonstrado nos testes X1–X3 no esquema original (sucesso). | Gatilho `proteger_profiles()`: só admin activo altera `papel`, `activo`, `email`, `criado_em`; `id` imutável. Testes X1–X7: bloqueia campos críticos, permite telefone. |
| 3 | MÉDIA | **Último administrador podia ser removido pela API** (Z1: o único admin activo desactiva-se → ninguém gere o portal; só SQL Editor recupera). | Mesmo gatilho recusa desactivar/despromover o último admin activo. |
| 4 | MÉDIA | **RPC `nomes_alunos_turma` inexistente no `schema.sql`**, mas chamada pelo portal do formador (a vista do formador falhava numa instalação nova). Se alguém a criasse à pressa, arriscava-se a expor dados. | Criada `SECURITY DEFINER`, devolve só `id,nome`, exige admin activo ou formador activo **dessa** turma (P10, P11, L4, A30). |
| 5 | BAIXA | **`SECURITY DEFINER` com `search_path = public`.** Com CREATE em `public` para outros papéis, permite sequestro de objectos não qualificados. | `search_path = ''` em todas (tudo já estava qualificado; testado). Sem SQL dinâmico (`EXECUTE`/`format()` não existem). |
| 6 | BAIXA | **`recebido_por` forjável** por um admin (aparecia outro utilizador como recebedor; a auditoria guardava o autor real). | Gatilho fixa `recebido_por = auth.uid()` (Z4). |
| 7 | BAIXA | **Privilégios excessivos por defeito do Supabase** (`TRUNCATE`, `REFERENCES`, `TRIGGER` para `authenticated`; novas funções expostas a `anon`). Sem policy para TRUNCATE. | `REVOKE ALL` e re-`GRANT` mínimo; `ALTER DEFAULT PRIVILEGES` para funções futuras; funções de gatilho sem EXECUTE para a API (A38, H6, H7). |
| 8 | BAIXA | **Formador lê o perfil completo** (email, telefone, encarregado) dos alunos das suas turmas (`profiles_ver`). É legítimo ("consultar alunos das suas turmas") e está limitado às suas turmas (F, F5, F8); o portal só usa id+nome. **Não alterado**; se quiserem mínimo privilégio, retirar `professor_ve_aluno(id)` da policy `profiles_ver`. | — |
| 9 | BAIXA | **Registo aberto**: qualquer pessoa cria conta (fica aluno inactivo, sem acesso a dados: Q, Q2). Pode haver spam de contas. | Não alterado. Usar CAPTCHA/limites no Supabase Auth. |
| 10 | INFO | **Desactivar não termina o login.** `activo=false` bloqueia todos os dados/RPCs no PostgreSQL de imediato (K, L, Q), mas a sessão Auth continua válida (só vê o próprio perfil). | Opcional: "Ban user" no painel Auth. |

Sem vulnerabilidade **crítica/alta** no esquema original. Os ataques A–J do enunciado já eram
rejeitados pelas policies e grants actuais; o que faltava era defesa em profundidade e bootstrap seguro.

## 3. Tabela de RPCs / funções
| FUNÇÃO | SECURITY DEFINER | EXECUTE | AUTORIZAÇÃO | RISCO | CORRECÇÃO |
|---|---|---|---|---|---|
| `matricular(aluno,turma,meses,inicio)` | sim | authenticated (anon revogado) | `e_admin()` (admin+activo); valida aluno activo; chamada pelo portal (admin) | baixo | search_path vazio |
| `gerar_propinas(matricula,meses,inicio)` | sim | authenticated | `e_admin()`; meses 1–24; chamada pelo portal (admin) | baixo | search_path vazio |
| `nomes_alunos_turma(turma)` | sim | authenticated | `e_admin()` ou `professor_da_turma()` (activo, dono da turma) | baixo | **criada**; só id+nome |
| `e_admin()`, `papel_actual()` | sim | authenticated | usam só `auth.uid()` + `activo`; sem parâmetros; devolvem info do próprio chamador | baixo | search_path vazio |
| `professor_da_turma(t)`, `professor_ve_aluno(a)`, `pode_lancar(m)`, `aluno_da_matricula(m)`, `pode_ver_matricula(m)`, `aluno_da_cobranca(c)` | sim | authenticated (necessário: as policies avaliam-nas com os direitos do utilizador) | parâmetro é um UUID, mas a resposta é sobre `auth.uid()`: nunca dá informação de terceiros (H1–H5) | baixo | search_path vazio |
| `novo_utilizador()` (gatilho em auth.users) | sim | **nenhum** (revogado) | papel fixo `aluno`, `activo=false`; ignora metadata excepto `nome` | baixo | EXECUTE revogado |
| `auditar()` (gatilhos) | sim | nenhum | grava `auth.uid()` do JWT, não do cliente | baixo | EXECUTE revogado |
| `verificar_pagamento()` | sim | nenhum | limite de valor | baixo | EXECUTE revogado |
| `proteger_profiles()`, `definir_recebido_por()` (novas) | não | nenhum | gatilhos BEFORE | — | novas |
| `marcar_actualizacao()` | não | nenhum | só carimbo de data | — | EXECUTE revogado |

Nota sobre `REVOKE EXECUTE FROM authenticated` nas funções auxiliares de RLS: **não foi feito de
propósito**; partiria todas as policies. A segurança está na validação interna.

## 4. Mapa dos testes do enunciado
A→A, B→B, C→C, D→D, E→E, F→F, G→G, H (conta desactivada + RPC)→K/K2/L4/Q4, I→I/I2, J→J.
Ataques a–j da secção 2: a→A, b→D/A2, c→B/B2, d→A3/X4/Z3, e→A3, f→C/C2/D2, g→I/P12/P13, h→H1–H7,
i→A4/A5/D4, j→C/D2/A7.

## 5. Checklist final (todas verificadas por teste)
ALUNO
- [x] não altera role (A, A2, C, X1) · [x] não altera activo (B, B2, X2) · [x] não acede a outros alunos (A8, A14–A18)
- [x] não acede a pagamentos de terceiros (A13, A18, J) · [x] não executa RPC administrativa (I, I2, A30)

PROFESSOR
- [x] não altera role (D, D2, X3) · [x] não acede a finanças (G–G7) · [x] não acede a outras turmas (F–F4, P2–P7, P11)
- [x] não se atribui a turmas (E, E2, E3) · [x] não altera contas (D3, D4)

ADMIN
- [x] mantém todas as permissões necessárias (M1–M19); [x] auditoria imutável (M20–M22)

CONTAS
- [x] conta desactivada não contorna (K*, L*, Q*) · [x] escalação impossível pelo frontend (papel só vem da BD)
- [x] escalação impossível pela API (A–J, X1–X7) · [x] RPCs protegidas · [x] SECURITY DEFINER protegidas
- [x] localStorage/sessionStorage não são fonte de autorização

## 6. Testes via API REST (equivalente aos testes SQL)
Com `URL`, `ANON` (config.js) e `TOKEN` = `access_token` do utilizador de teste:
```bash
H=(-H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Prefer: return=representation")
# A: aluno -> admin        (esperado: [] ou erro "Apenas a administração...")
curl -X PATCH "$URL/rest/v1/profiles?id=eq.$MEU_ID" "${H[@]}" -d '{"papel":"admin"}'
# I: RPC admin             (esperado: erro "Apenas a administração pode matricular alunos.")
curl -X POST "$URL/rest/v1/rpc/matricular" "${H[@]}" -d '{"p_aluno":"'$MEU_ID'","p_turma":"'$TURMA'"}'
# G: professor -> pagamentos (esperado: [])
curl "$URL/rest/v1/pagamentos?select=*" "${H[@]}"
# F: professor -> matrículas de outra turma (esperado: [])
curl "$URL/rest/v1/matriculas?turma_id=eq.$OUTRA_TURMA" "${H[@]}"
# sem login (anon): esperado 401/permission denied
curl "$URL/rest/v1/profiles" -H "apikey: $ANON"
```
Um `[]` num PATCH/DELETE significa "0 linhas afectadas" (o RLS filtrou): nada foi alterado.
