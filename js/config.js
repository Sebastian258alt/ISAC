// Ligação ao Supabase do projecto ISAC.
// A chave anon é pública por desenho; quem protege os dados são as regras da base de dados (supabase/schema.sql).
// NUNCA coloque aqui a chave "service_role".
window.ISAC_CONFIG = {
  url: 'https://falduwgvkvrlwnvlhmyx.supabase.co',
  key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhbGR1d2d2a3ZybHdudmxobXl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2Nzc2MDUsImV4cCI6MjEwNjI1MzYwNX0.HXvZXCyBWVC8PNgyTGYFrVdYFs8b8kz9PiTKv6LyF-M',
  // WhatsApp da secretaria (formato internacional, sem + nem espaços): recebe os comprovativos
  whatsapp: '258865166752',
  // Dados para pagamento mostrados ao aluno. PREENCHA com os números/contas reais do ISAC, ex.:
  //   { metodo: 'M-Pesa', detalhe: '84 000 0000 (ISAC)' }, { metodo: 'Transferência', detalhe: 'NIB 0000 0000 0000' }
  // Se ficar vazio, o portal diz que a secretaria envia os dados por WhatsApp.
  pagamento: []
};
