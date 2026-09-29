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
(Antes de usar a sério com o ISAC, o normal é voltar a ligar isto.)

## 5. Criar a primeira conta de Administração

O portal nunca deixa ninguém tornar-se administrador sozinho — isso tem de
ser feito uma vez, directamente na base de dados:

1. Abra o `portal.html` no browser → **Criar conta** → registe-se com o seu
   próprio email e nome.
2. No Supabase, vá a **SQL Editor** → **New query** e corra:
   ```sql
   update profiles set papel = 'admin', activo = true where email = 'o-seu-email@exemplo.com';
   ```
3. Volte ao portal e entre. Já está como Administração.

Dali em diante, criar contas de **formador** ou activar **alunos** faz-se
dentro do próprio portal, no separador **Utilizadores** — já não precisa de
voltar ao SQL Editor para isso.

## 6. Como as pessoas entram no portal

- **Alunos**: criam a própria conta em "Criar conta". Ficam **inactivos** até
  a administração os activar em Utilizadores.
- **Formadores**: a administração cria-lhes a conta pedindo para se
  registarem, depois muda o papel para "Formador" e a turma correspondente em
  **Cursos e turmas**.
- **Administração**: só é criada à mão (passo 5) ou promovida por outro
  administrador em Utilizadores.

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
