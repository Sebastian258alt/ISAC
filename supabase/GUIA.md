# Portal ISAC · como pôr a funcionar (Supabase)

Passo a passo para ligar o portal a uma base de dados a sério. Demora cerca de
15 minutos e não precisa de saber programar.

## 1. Criar o projecto

1. Vá a **supabase.com** → **Start your project** → crie uma conta (pode ser
   com o Google).
2. **New project** → dê um nome (ex.: `isac-portal`) → escolha uma
   **palavra-passe da base de dados** forte e guarde-a num sítio seguro →
   região mais próxima (ex.: `South Africa`) → **Create new project**.
   Demora 1–2 minutos a ficar pronto.

## 2. Carregar o esquema da base de dados

1. No menu à esquerda, abra **SQL Editor** → **New query**.
2. Abra o ficheiro `supabase/schema.sql` (está nesta pasta), copie **tudo** e
   cole no editor.
3. Clique **Run**. Deve aparecer "Success. No rows returned".
   Isto cria as tabelas, as regras de segurança e as funções todas de uma vez.
   Só precisa de fazer isto **uma vez**.

## 3. Ligar o site ao projecto

1. No menu à esquerda, **Project Settings** (ícone de engrenagem) → **API**.
2. Copie o **Project URL** e a chave **anon public** (NÃO copie a
   `service_role`, essa é secreta).
3. Abra o ficheiro `js/config.js` e substitua:
   ```js
   window.ISAC_CONFIG = {
     url: 'https://xxxxxxxx.supabase.co',   // o seu Project URL
     key: 'eyJhbГci...'                        // a sua chave anon public
   };
   ```
4. Guarde. O portal já está ligado.

## 4. Desligar a confirmação por email (recomendado para a demonstração)

Por padrão, o Supabase pede para confirmar o email antes de poder entrar.
Para testar mais depressa: **Authentication** → **Providers** → **Email** →
desligue **Confirm email** → **Save**.
(Volte a ligar isto ANTES de criar o administrador (passo 5) e de usar a sério.)

## 5. Criar a primeira conta de Administração

O portal nunca deixa ninguém tornar-se administrador sozinho: isto faz-se **uma
única vez**, no SQL Editor do Supabase (que corre com os direitos do dono da
base de dados; ninguém com a chave anon ou com login de aluno/formador consegue).

1. Abra o `portal.html` → **Criar conta** → registe-se com o seu email e nome.
   **Confirme o email** (ligação recebida). Se a confirmação estiver desligada,
   ligue-a antes deste passo: caso contrário, alguém poderia registar primeiro o
   seu email e ficar com a conta que vai ser promovida.
2. No Supabase, **SQL Editor** → **New query** e corra (troque o email):
   ```sql
   update public.profiles p set papel = 'admin', activo = true
     from auth.users u
    where u.id = p.id
      and u.email = 'o-seu-email@exemplo.com'
      and u.email_confirmed_at is not null
      and not exists (select 1 from public.profiles where papel = 'admin');
   ```
   Deve dizer `UPDATE 1`. Se disser `UPDATE 0`: o email não está confirmado, não
   está registado, ou **já existe um administrador** (este comando só funciona
   enquanto não houver nenhum; por isso não pode ser repetido para criar mais).
3. Volte ao portal e entre. Já está como Administração.

Regras do bootstrap: só o dono da base (SQL Editor / service_role) o pode
executar; não existe nenhuma função/RPC que crie administradores; só cria o
primeiro; depois disso, novos administradores são promovidos por um
administrador activo em **Utilizadores** (fica registado na Auditoria). O
portal não permite que o único administrador activo se desactive ou despromova.

## 6. Como as pessoas entram no portal

- **Alunos**: criam a própria conta em "Criar conta". Ficam **inactivos** até
  a administração os activar em Utilizadores.
- **Formadores**: a administração cria-lhes a conta pedindo para se
  registarem, depois muda o papel para "Formador" e a turma correspondente em
  **Cursos e turmas**.
- **Administração**: a primeira é criada à mão (passo 5); as seguintes são
  promovidas por um administrador activo em Utilizadores.

## 7. Antes de usar a sério

- Confirme os **cursos, taxas de matrícula e propinas** em "Cursos e turmas"
  — vêm todos a zero por definição.
  as fórmulas de média e o limite de faltas ficam no topo do `js/portal.js`
  (`NOTA_MIN`, `LIMITE_FALTAS`) e a fórmula da média no `supabase/schema.sql`
  (tabela `avaliacoes`) — confirme os pesos com a direcção pedagógica.
- Volte a ligar a confirmação por email (passo 4).
- Faça um pequeno teste com 2–3 contas reais antes de abrir a toda a gente.

## Se algo correr mal

- **"Sem permissão para esta acção"** → normalmente é papel errado ou conta
  ainda inactiva.
- Mensagens de erro inesperadas → **Table Editor**, no Supabase, mostra os
  dados tal como estão guardados; ajuda a perceber o que falta.
- Este ficheiro e o `schema.sql` cobrem o essencial; para dúvidas específicas
  do Supabase, a documentação oficial está em **supabase.com/docs**.

## Projecto já instalado antes da correcção P0-3?

Não volte a correr o `schema.sql`. Corra apenas `supabase/migracao_P0-3.sql`
(SQL Editor → New query → colar → Run). É seguro repetir e não apaga dados.

## Projecto já instalado antes de "Apagar contas / Limpar dados" (P0-3B)?

Corra apenas `supabase/migracao_P0-3B_apagar_dados.sql` (SQL Editor → New query → colar → Run).
É seguro repetir e **não apaga nada**: só cria as funções que os botões chamam.

## 8. Apagar contas e limpar dados (só Administração)

Em **Utilizadores**:
- **Apagar** (em cada linha): remove o acesso da pessoa e tudo o que depende dela (matrículas,
  notas, faltas, cobranças e pagamentos, se for aluno). Mostra primeiro o que vai ser apagado.
  Não pode apagar a sua própria conta. Se só quer travar o acesso, **desactive** em vez de apagar.
- **Zona de perigo → Limpar dados…**: notas e faltas · cobranças e pagamentos · matrículas ·
  todas as contas de aluno · todas as contas de formador · tudo (excepto administradores).
  Cursos e turmas só se apagam na opção "tudo".

Em todos os casos é preciso escrever **APAGAR** (o servidor também o exige) e **não há como
desfazer**. Contas de administração nunca são apagadas por "Limpar dados".

A **Auditoria** não se apaga pelo portal (é imutável de propósito): regista quem apagou, quando e o
que existia (incluindo nome/email de contas apagadas) e uma linha "Limpou" por cada limpeza.
Se estiver a limpar dados de TESTE antes de abrir a sério, pode também esvaziar a Auditoria
**uma vez**, no SQL Editor (só o dono da base consegue): `truncate public.auditoria;`
Faça isto só se tiver a certeza de que não precisa desse histórico.

## 9. Matrícula online (pré-inscrição, BI e activação)
1. SQL Editor → colar e correr `supabase/migracao_P1-matricula-online.sql` (depois do schema.sql).
2. Em **Authentication → Providers → Email**, desligue **Confirm email** (assim o candidato continua logo para o passo 2 e envia o BI na mesma sessão). Se mantiver ligado, funciona na mesma: o candidato confirma o email e preenche a pré-inscrição ao entrar.
3. Em `js/config.js`, preencha `pagamento` com os números M-Pesa/e-Mola/NIB reais e confirme o `whatsapp`.
4. Crie os **cursos** (com taxa e propina) e as **turmas**: aparecem para o candidato escolher.
Fluxo: candidato cria conta → preenche dados + envia BI (conta fica **pendente**) → paga e envia o comprovativo por WhatsApp → administração: **Pré-inscrições → Rever e activar** (vê o BI, escolhe a turma, regista o pagamento) → o aluno entra e **baixa o recibo** em Pagamentos.
Nota: o BI fica num bucket privado (`bi-documentos`); apagar uma conta não apaga o ficheiro do BI (apague-o em Storage, se necessário).
