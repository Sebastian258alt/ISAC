// Banco de perguntas do Diagnóstico ISAC.
// COMO EDITAR: cada pergunta é { n: nível (1..), k: tema, t: enunciado, o: [4 opções], c: índice da correcta (0 a 3) }.
// As opções são embaralhadas no ecrã, por isso a ordem aqui não importa.
// Os NOMES e o número de níveis de cada curso devem ser confirmados com a direcção do ISAC.
window.ISAC_DIAG = {
  ingles: {
    nome: 'Inglês',
    niveis: [
      { nome: 'Iniciante', ref: 'A1', desc: 'Começar do zero: alfabeto, cumprimentos, números, frases simples.' },
      { nome: 'Básico', ref: 'A2', desc: 'Falar do dia-a-dia: rotina, passado simples, compras e direcções.' },
      { nome: 'Intermédio', ref: 'B1', desc: 'Conversar com fluência razoável: experiências, planos, opiniões.' },
      { nome: 'Avançado', ref: 'B2', desc: 'Usar o inglês no trabalho e nos estudos: textos complexos e argumentação.' }
    ],
    q: [
      { n:1, k:'Vocabulário', t:'Qual é a tradução de "thank you"?', o:['Obrigado','Desculpe','Bom dia','Adeus'], c:0 },
      { n:1, k:'Gramática', t:'Complete: "I ___ a student."', o:['am','is','are','be'], c:0 },
      { n:1, k:'Vocabulário', t:'Qual número é "seven"?', o:['7','9','6','17'], c:0 },
      { n:1, k:'Gramática', t:'Complete: "She ___ my sister."', o:['is','am','are','do'], c:0 },
      { n:1, k:'Vocabulário', t:'"Good morning" diz-se…', o:['de manhã','à noite','à tarde','ao almoço'], c:0 },
      { n:1, k:'Gramática', t:'Complete: "We ___ from Mozambique."', o:['are','is','am','be'], c:0 },
      { n:2, k:'Gramática', t:'Complete: "Yesterday I ___ to the market."', o:['went','go','goes','going'], c:0 },
      { n:2, k:'Gramática', t:'Complete: "He ___ football every Sunday."', o:['plays','play','playing','is play'], c:0 },
      { n:2, k:'Vocabulário', t:'Qual palavra significa "cheap"?', o:['barato','caro','grande','novo'], c:0 },
      { n:2, k:'Gramática', t:'Complete: "There ___ two books on the table."', o:['are','is','be','am'], c:0 },
      { n:2, k:'Leitura', t:'"Turn left at the bank." O que deve fazer?', o:['Virar à esquerda no banco','Virar à direita no banco','Ir em frente até ao banco','Entrar no banco'], c:0 },
      { n:2, k:'Gramática', t:'Complete: "I ___ TV when you called."', o:['was watching','watched','am watching','watch'], c:0 },
      { n:3, k:'Gramática', t:'Complete: "If it rains tomorrow, we ___ at home."', o:['will stay','stay','stayed','would stayed'], c:0 },
      { n:3, k:'Gramática', t:'Complete: "I have lived here ___ 2019."', o:['since','for','from','during'], c:0 },
      { n:3, k:'Vocabulário', t:'"I\'m looking forward to meeting you" significa…', o:['Estou ansioso por conhecê-lo','Estou à procura de si','Estou a olhar para si','Vou evitar encontrá-lo'], c:0 },
      { n:3, k:'Gramática', t:'Complete: "She asked me where I ___."', o:['lived','live','do live','am living'], c:0 },
      { n:3, k:'Gramática', t:'Qual frase está correcta?', o:['She doesn\'t like coffee.','She don\'t like coffee.','She not likes coffee.','She doesn\'t likes coffee.'], c:0 },
      { n:3, k:'Leitura', t:'"I used to walk to school." Isto quer dizer que…', o:['antes eu ia a pé, agora já não','vou a pé agora','nunca fui a pé','estou habituado a ir a pé hoje'], c:0 },
      { n:4, k:'Gramática', t:'Complete: "If I had known, I ___ you."', o:['would have told','will tell','would tell','had told'], c:0 },
      { n:4, k:'Gramática', t:'Complete: "The report ___ by the time the manager arrived."', o:['had been finished','has finished','was finishing','finished'], c:0 },
      { n:4, k:'Vocabulário', t:'"Despite the delay, the project succeeded." "Despite" é próximo de…', o:['in spite of','because of','instead of','thanks to'], c:0 },
      { n:4, k:'Gramática', t:'Qual frase está correcta?', o:['Hardly had he arrived when it started to rain.','Hardly he had arrived when it started to rain.','Hardly had he arrived that it started to rain.','Hardly he arrived when it had started to rain.'], c:0 },
      { n:4, k:'Vocabulário', t:'"To call off a meeting" significa…', o:['cancelar uma reunião','adiar para ligar','marcar uma reunião','presidir a uma reunião'], c:0 },
      { n:4, k:'Leitura', t:'"The proposal was met with mixed reactions." Isto significa que…', o:['alguns gostaram e outros não','todos gostaram','ninguém reagiu','todos rejeitaram'], c:0 }
    ]
  },
  mandarim: {
    nome: 'Mandarim',
    niveis: [
      { nome: 'Iniciante', ref: 'HSK 1', desc: 'Começar do zero: sons (pinyin), tons, cumprimentos e números.' },
      { nome: 'Elementar', ref: 'HSK 2', desc: 'Frases do dia-a-dia: apresentar-se, família, compras e horas.' },
      { nome: 'Intermédio', ref: 'HSK 3', desc: 'Conversar sobre rotina, experiências e planos; ler textos curtos.' }
    ],
    q: [
      { n:1, k:'Vocabulário', t:'Como se diz "Olá" em mandarim?', o:['你好 (nǐ hǎo)','谢谢 (xièxie)','再见 (zàijiàn)','对不起 (duìbuqǐ)'], c:0 },
      { n:1, k:'Vocabulário', t:'O que significa 谢谢 (xièxie)?', o:['Obrigado','Desculpe','Adeus','Por favor'], c:0 },
      { n:1, k:'Vocabulário', t:'Qual número é 三 (sān)?', o:['3','2','4','5'], c:0 },
      { n:1, k:'Pronúncia', t:'Quantos tons tem o mandarim padrão (sem contar o tom neutro)?', o:['4','2','3','5'], c:0 },
      { n:1, k:'Vocabulário', t:'O que significa 再见 (zàijiàn)?', o:['Até à vista / Adeus','Bom dia','Obrigado','Bem-vindo'], c:0 },
      { n:1, k:'Vocabulário', t:'O que significa 我 (wǒ)?', o:['Eu','Tu','Ele','Nós'], c:0 },
      { n:2, k:'Gramática', t:'Como se diz "Eu sou estudante"?', o:['我是学生 (wǒ shì xuésheng)','我有学生 (wǒ yǒu xuésheng)','我学生是 (wǒ xuésheng shì)','我不学生 (wǒ bù xuésheng)'], c:0 },
      { n:2, k:'Vocabulário', t:'O que significa 苹果 (píngguǒ)?', o:['Maçã','Água','Arroz','Pão'], c:0 },
      { n:2, k:'Gramática', t:'Como se forma a negação em "Eu não bebo café"?', o:['我不喝咖啡','我没喝咖啡了不','我喝不咖啡','不我喝咖啡'], c:0 },
      { n:2, k:'Vocabulário', t:'Como se pergunta "Quanto custa?"', o:['多少钱？(duōshao qián?)','你叫什么？(nǐ jiào shénme?)','你几岁？(nǐ jǐ suì?)','你在哪儿？(nǐ zài nǎr?)'], c:0 },
      { n:2, k:'Vocabulário', t:'Qual é a hora "三点" (sān diǎn)?', o:['Três horas','Três minutos','Terça-feira','Três dias'], c:0 },
      { n:2, k:'Gramática', t:'Qual é a partícula que forma pergunta de sim/não no fim da frase?', o:['吗 (ma)','了 (le)','的 (de)','呢 (ne) como "e tu?"'], c:0 },
      { n:3, k:'Gramática', t:'Qual frase significa "Eu já estive em Pequim"?', o:['我去过北京。(wǒ qùguo Běijīng)','我去北京了过。','我过去北京。','我北京去过了不。'], c:0 },
      { n:3, k:'Gramática', t:'Qual frase usa correctamente 比 (bǐ) para comparar?', o:['他比我高。(tā bǐ wǒ gāo)','他很比我高。(tā hěn bǐ wǒ gāo)','他比我很高。(tā bǐ wǒ hěn gāo)','他高比我。(tā gāo bǐ wǒ)'], c:0 },
      { n:3, k:'Gramática', t:'Qual frase indica acção em curso ("Estou a comer")?', o:['我正在吃饭。(wǒ zhèngzài chīfàn)','我吃过饭。(wǒ chīguo fàn)','我会吃饭。(wǒ huì chīfàn)','我吃饭了吗？'], c:0 },
      { n:3, k:'Vocabulário', t:'O que significa 因为……所以……?', o:['porque… por isso…','embora… mas…','se… então…','primeiro… depois…'], c:0 },
      { n:3, k:'Leitura', t:'"明天我要去超市买东西。" Quando vai o falante ao supermercado?', o:['Amanhã','Hoje','Ontem','Na próxima semana'], c:0 },
      { n:3, k:'Gramática', t:'Qual é a ordem correcta para "Amanhã eu vou à escola"?', o:['我明天去学校。(wǒ míngtiān qù xuéxiào)','我去学校明天。','去我明天学校。','学校我去明天。'], c:0 }
    ]
  },
  informatica: {
    nome: 'Informática',
    niveis: [
      { nome: 'Iniciante', ref: 'Nível 1', desc: 'Começar do zero: ligar o computador, rato, teclado e ficheiros.' },
      { nome: 'Básico', ref: 'Nível 2', desc: 'Windows, Word, internet e email com segurança.' },
      { nome: 'Intermédio', ref: 'Nível 3', desc: 'Excel com fórmulas, PowerPoint e organização de trabalho digital.' },
      { nome: 'Avançado', ref: 'Nível 4', desc: 'Excel avançado, redes, segurança e introdução à programação.' }
    ],
    q: [
      { n:1, k:'Fundamentos', t:'Qual destes dispositivos serve para escrever texto?', o:['Teclado','Monitor','Altifalante','Impressora'], c:0 },
      { n:1, k:'Fundamentos', t:'O que é o "rato" (mouse)?', o:['Um dispositivo para apontar e clicar no ecrã','Um tipo de vírus','Uma impressora pequena','Um programa de escrever'], c:0 },
      { n:1, k:'Fundamentos', t:'Qual destes é um programa para escrever cartas e documentos?', o:['Word','Chrome','Calculadora de bolso','Windows Update'], c:0 },
      { n:1, k:'Fundamentos', t:'Para desligar o computador correctamente, deve…', o:['usar a opção Encerrar / Desligar','arrancar o cabo da ficha','fechar o ecrã apenas','carregar no teclado'], c:0 },
      { n:1, k:'Fundamentos', t:'Uma pen drive (USB) serve para…', o:['guardar e transportar ficheiros','ligar à internet','imprimir documentos','aumentar o volume'], c:0 },
      { n:1, k:'Fundamentos', t:'O que significa "clicar duas vezes" num ícone?', o:['Abrir o programa ou ficheiro','Apagar o ícone','Copiar o ícone','Desligar o computador'], c:0 },
      { n:2, k:'Windows', t:'Qual é o atalho de teclado para COPIAR?', o:['Ctrl + C','Ctrl + V','Ctrl + X','Ctrl + Z'], c:0 },
      { n:2, k:'Word', t:'No Word, como se coloca texto a negrito?', o:['Seleccionar o texto e carregar em Ctrl + B (ou N)','Carregar em Ctrl + P','Mudar a cor da página','Fechar o documento'], c:0 },
      { n:2, k:'Internet', t:'Qual é um sinal de que um email pode ser fraude (phishing)?', o:['Pede a sua palavra-passe ou dados do banco com urgência','Vem de um colega conhecido sem links','Tem o seu nome correcto','Não tem anexos'], c:0 },
      { n:2, k:'Windows', t:'Onde ficam guardados os ficheiros que apaga, antes de serem eliminados de vez?', o:['Reciclagem (Recycle Bin)','Ambiente de trabalho','Painel de controlo','Barra de tarefas'], c:0 },
      { n:2, k:'Internet', t:'O que é um navegador (browser)?', o:['Um programa para aceder a páginas da internet (ex.: Chrome)','Um tipo de antivírus','Uma rede Wi-Fi','Um cabo de rede'], c:0 },
      { n:2, k:'Word', t:'Para guardar um documento Word com outro nome, usa-se…', o:['Guardar como','Imprimir','Rever ortografia','Inserir tabela'], c:0 },
      { n:3, k:'Excel', t:'Qual fórmula soma as células de A1 a A10 no Excel?', o:['=SOMA(A1:A10)','=A1+A10','=SOMAR(A1;A10;)','=TOTAL(A1-A10)'], c:0 },
      { n:3, k:'Excel', t:'O que faz a referência $A$1 numa fórmula?', o:['Fixa a célula A1 (referência absoluta)','Soma A1 duas vezes','Apaga a célula A1','Converte A1 em moeda'], c:0 },
      { n:3, k:'Excel', t:'Qual função devolve o maior valor de um intervalo?', o:['MÁXIMO (MAX)','MÉDIA','CONTAR','SE'], c:0 },
      { n:3, k:'PowerPoint', t:'Para apresentar slides em ecrã inteiro, usa-se…', o:['Apresentação de slides (tecla F5)','Inserir imagem','Guardar como PDF','Rever ortografia'], c:0 },
      { n:3, k:'Excel', t:'Qual fórmula devolve "Passou" se B2 for ≥ 10 e "Chumbou" caso contrário?', o:['=SE(B2>=10;"Passou";"Chumbou")','=B2>=10 "Passou"','=SOMA(B2;"Passou")','=PROCURAR(B2;10)'], c:0 },
      { n:3, k:'Segurança', t:'Qual é a melhor prática para palavras-passe?', o:['Usar palavras-passe longas e diferentes em cada conta','Usar a mesma palavra-passe em todas as contas','Usar a data de nascimento','Partilhar com amigos de confiança'], c:0 },
      { n:4, k:'Excel', t:'Qual função procura um valor na primeira coluna de uma tabela e devolve outro da mesma linha?', o:['PROCV (VLOOKUP)','SOMA','CONTAR.SE','CONCATENAR'], c:0 },
      { n:4, k:'Excel', t:'Para resumir grandes tabelas por categorias, usa-se…', o:['Tabela Dinâmica (Pivot Table)','Corrector ortográfico','Ordenar por cor','Proteger folha'], c:0 },
      { n:4, k:'Redes', t:'O que faz um endereço IP?', o:['Identifica um dispositivo numa rede','Guarda ficheiros na nuvem','Protege contra vírus','Aumenta a velocidade do CPU'], c:0 },
      { n:4, k:'Segurança', t:'Para que serve a autenticação em dois passos (2FA)?', o:['Exigir um segundo código além da palavra-passe','Duplicar os ficheiros','Acelerar o login','Eliminar vírus'], c:0 },
      { n:4, k:'Programação', t:'Em programação, o que é um ciclo (loop)?', o:['Repetir instruções várias vezes','Guardar um ficheiro','Ligar à internet','Desenhar uma imagem'], c:0 },
      { n:4, k:'Redes', t:'Qual é a diferença entre RAM e disco (armazenamento)?', o:['A RAM é memória temporária de trabalho; o disco guarda dados de forma permanente','A RAM guarda ficheiros para sempre','São a mesma coisa','O disco só existe em telemóveis'], c:0 }
    ]
  },
  eletricidade: {
    nome: 'Electricidade',
    niveis: [
      { nome: 'Iniciante', ref: 'Nível 1', desc: 'Começar do zero: o que é corrente, tensão, materiais e segurança.' },
      { nome: 'Básico', ref: 'Nível 2', desc: 'Lei de Ohm, circuitos em série/paralelo, instalação doméstica simples.' },
      { nome: 'Intermédio', ref: 'Nível 3', desc: 'Quadros, protecções, esquemas, trifásico e diagnóstico de avarias.' }
    ],
    q: [
      { n:1, k:'Fundamentos', t:'Qual é a unidade de medida da tensão eléctrica?', o:['Volt (V)','Ampere (A)','Ohm (Ω)','Watt (W)'], c:0 },
      { n:1, k:'Segurança', t:'Antes de mexer numa tomada ou interruptor, deve…', o:['desligar a corrente no quadro / disjuntor','molhar as mãos','usar sapatos descalços','tocar nos fios para testar'], c:0 },
      { n:1, k:'Fundamentos', t:'Qual destes materiais é bom condutor de electricidade?', o:['Cobre','Borracha','Madeira seca','Plástico'], c:0 },
      { n:1, k:'Fundamentos', t:'A unidade da corrente eléctrica é…', o:['Ampere (A)','Volt (V)','Watt (W)','Hertz (Hz)'], c:0 },
      { n:1, k:'Segurança', t:'A que serve o isolamento (plástico) à volta dos fios?', o:['Evitar choques e curto-circuitos','Fazer o fio brilhar','Aumentar a tensão','Gerar mais corrente'], c:0 },
      { n:1, k:'Fundamentos', t:'Uma lâmpada acende quando o circuito está…', o:['fechado (completo)','aberto','desligado da fonte','sem fios'], c:0 },
      { n:2, k:'Lei de Ohm', t:'Segundo a Lei de Ohm, a corrente I é igual a…', o:['V ÷ R','V × R','R ÷ V','V + R'], c:0 },
      { n:2, k:'Lei de Ohm', t:'Qual é a corrente num circuito de 12 V com uma resistência de 4 Ω?', o:['3 A','48 A','8 A','0,33 A'], c:0 },
      { n:2, k:'Circuitos', t:'Em duas lâmpadas ligadas em PARALELO, se uma fundir…', o:['a outra continua a funcionar','a outra também apaga','ambas ficam mais fracas','a outra explode'], c:0 },
      { n:2, k:'Potência', t:'Qual é a fórmula da potência eléctrica?', o:['P = V × I','P = V ÷ I','P = R × I','P = V + I'], c:0 },
      { n:2, k:'Circuitos', t:'Em série, duas resistências de 10 Ω e 20 Ω dão uma resistência total de…', o:['30 Ω','6,7 Ω','200 Ω','10 Ω'], c:0 },
      { n:2, k:'Instalação', t:'Qual é a cor tradicional do condutor de terra (protecção)?', o:['Verde/amarelo','Azul','Vermelho','Preto'], c:0 },
      { n:3, k:'Protecções', t:'Qual é a função do disjuntor diferencial?', o:['Cortar a corrente quando há fuga para a terra (protege pessoas)','Aumentar a tensão','Medir o consumo','Baixar a frequência'], c:0 },
      { n:3, k:'Trifásico', t:'Num sistema trifásico a 400 V entre fases, a tensão entre fase e neutro é aproximadamente…', o:['230 V','400 V','110 V','690 V'], c:0 },
      { n:3, k:'Instalação', t:'Para escolher a secção do cabo, é essencial considerar…', o:['a corrente que vai passar e o comprimento do cabo','só a cor do cabo','só o preço','o tamanho do quadro'], c:0 },
      { n:3, k:'Medição', t:'Para medir a corrente num circuito com um multímetro, ele liga-se…', o:['em série com o circuito','em paralelo com a carga','aos fios de terra apenas','sem ligar a nada'], c:0 },
      { n:3, k:'Esquemas', t:'Um interruptor de escada (comutador) é usado para…', o:['comandar uma lâmpada de dois pontos diferentes','proteger contra fugas','medir a tensão','ligar o motor trifásico'], c:0 },
      { n:3, k:'Protecções', t:'O que acontece quando um disjuntor "dispara" por sobrecarga?', o:['Interrompe o circuito para evitar sobreaquecimento','Aumenta a corrente','Liga a terra','Muda a cor dos fios'], c:0 }
    ]
  }
};
