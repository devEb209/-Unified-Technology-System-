package net.kairos.manager.systems

import net.kairos.manager.core.SystemModule

/** Catálogo dos 78 sistemas do Käirōs Net Manager. */
object Systems {

    val all: List<SystemModule> = listOf(
        // ---- Descoberta e inventário (1-12) ----
        s(1, "Varredura Automática", "Descoberta", "Escaneia toda a faixa /24 da sua rede e atualiza a lista a cada 7 minutos."),
        s(2, "Ciclo de 7 Minutos", "Descoberta", "Agendador fixo de atualização automática em background."),
        s(3, "Tabela ARP", "Descoberta", "Lê /proc/net/arp para mapear IP → MAC de cada dispositivo."),
        s(4, "Identificação de Fabricante", "Descoberta", "Resolve o OUI do MAC e mostra a marca do aparelho."),
        s(5, "Detector de MAC Aleatório", "Descoberta", "Sinaliza aparelhos usando MAC privado/aleatorizado."),
        s(6, "Scanner de Portas", "Descoberta", "Fingerprint das portas abertas de cada dispositivo."),
        s(7, "Detecção de Tipo", "Descoberta", "Classifica em celular, PC, TV, IoT, console ou roteador."),
        s(8, "Ponte Bluetooth", "Descoberta", "Lista aparelhos BLE/Bluetooth próximos que também estão na rede."),
        s(9, "Dispositivo Novo", "Descoberta", "Alerta imediato quando um aparelho desconhecido entra."),
        s(10, "Inventário Permanente", "Descoberta", "Guarda todo aparelho já visto, com primeira e última aparição."),
        s(11, "Apelidos", "Descoberta", "Renomeie cada aparelho com um nome que você reconheça."),
        s(12, "Favoritos", "Descoberta", "Fixe os aparelhos importantes no topo da lista."),

        // ---- Controle de acesso (13-26) ----
        s(13, "Bloqueio Instantâneo", "Controle", "Um toque corta a internet do aparelho; outro toque libera."),
        s(14, "Pausa Blindada 3h07", "Controle", "Pausa travada por 3 horas e 7 minutos, sem possibilidade de desfazer."),
        s(15, "Bloqueio Agendado", "Controle", "Define janelas de horário em que o aparelho fica sem internet."),
        s(16, "Modo Dormir", "Controle", "Corta a rede de todos os aparelhos não confiáveis durante a madrugada."),
        s(17, "Hora do Dever", "Controle", "Bloqueia entretenimento em horários definidos por você."),
        s(18, "Lista Branca", "Controle", "Só aparelhos aprovados navegam; o resto entra bloqueado."),
        s(19, "Lista Negra", "Controle", "MACs banidos permanentemente da sua rede."),
        s(20, "Botão de Pânico", "Controle", "Derruba todos os aparelhos exceto o seu, em um toque."),
        s(21, "Modo Só Eu", "Controle", "Deixa apenas o seu aparelho com acesso à internet."),
        s(22, "Bloqueio em Lote", "Controle", "Aplica bloqueio a vários aparelhos selecionados de uma vez."),
        s(23, "Cotas de Tempo", "Controle", "Cada aparelho recebe um limite diário de minutos online."),
        s(24, "Expulsão de Intruso", "Controle", "Desconecta e bane um aparelho suspeito imediatamente."),
        s(25, "Quarentena", "Controle", "Isola aparelhos novos até você aprovar manualmente."),
        s(26, "Desbloqueio Programado", "Controle", "Libera automaticamente no horário que você marcar."),

        // ---- Potência, QoS e banda (27-38) ----
        s(27, "Prioridade Alta", "Potência", "Aumenta a prioridade/potência de uso do Wi-Fi do aparelho."),
        s(28, "Prioridade Baixa", "Potência", "Reduz a fatia de banda e a prioridade do aparelho."),
        s(29, "Escala 1-5", "Potência", "Cinco níveis de prioridade ajustáveis por aparelho."),
        s(30, "Limite de Download", "Potência", "Teto de velocidade de descida em Kbps por aparelho."),
        s(31, "Limite de Upload", "Potência", "Teto de velocidade de subida em Kbps por aparelho."),
        s(32, "Turbo Gaming", "Potência", "Perfil de latência mínima para o aparelho escolhido."),
        s(33, "Perfil Streaming", "Potência", "Banda reservada e estável para vídeo em alta definição."),
        s(34, "Modo Economia", "Potência", "Reduz o consumo geral limitando aparelhos ociosos."),
        s(35, "Banda Justa", "Potência", "Divide a banda igualmente entre todos os conectados."),
        s(36, "Reserva Dedicada", "Potência", "Garante uma faixa fixa de banda só para você."),
        s(37, "Anti-Sanguessuga", "Potência", "Detecta e freia quem monopoliza a banda."),
        s(38, "Perfis Rápidos", "Potência", "Aplica conjuntos de regras prontos com um toque."),

        // ---- Monitoramento e histórico (39-52) ----
        s(39, "Histórico por Aparelho", "Monitor", "Linha do tempo completa de cada dispositivo da rede."),
        s(40, "Registro de Conexões", "Monitor", "Anota toda entrada e saída de aparelhos na rede."),
        s(41, "Uso de Dados", "Monitor", "Contabiliza download e upload acumulado por aparelho."),
        s(42, "Gráfico de Presença", "Monitor", "Mostra visualmente os horários em que cada um esteve online."),
        s(43, "Medidor de Latência", "Monitor", "Ping contínuo com histórico de resposta."),
        s(44, "Força de Sinal", "Monitor", "Acompanha o RSSI e a qualidade do link Wi-Fi."),
        s(45, "Teste de Velocidade", "Monitor", "Mede a velocidade real da sua conexão."),
        s(46, "Saúde da Rede", "Monitor", "Nota geral calculada de 0 a 100 para sua rede."),
        s(47, "Mapa de Canais", "Monitor", "Mostra a ocupação dos canais Wi-Fi ao redor."),
        s(48, "Detector de Interferência", "Monitor", "Aponta redes vizinhas atrapalhando seu sinal."),
        s(49, "Tempo Online", "Monitor", "Uptime do roteador e da sua conexão."),
        s(50, "Top Consumidores", "Monitor", "Ranking de quem mais usa a internet."),
        s(51, "Relatório Diário", "Monitor", "Resumo automático do dia da sua rede."),
        s(52, "Exportar Dados", "Monitor", "Gera arquivo com todo o histórico para você guardar."),

        // ---- Segurança (53-66) ----
        s(53, "Trava por Senha", "Segurança", "O app só abre com a sua senha secreta exclusiva."),
        s(54, "Bloqueio por Tentativas", "Segurança", "Trava o app por 5 minutos após 5 erros de senha."),
        s(55, "Sessão Expirável", "Segurança", "Fecha o acesso sozinho após 15 minutos parado."),
        s(56, "Alerta de Intruso", "Segurança", "Notifica na hora se um aparelho desconhecido conecta."),
        s(57, "Detector de MAC Clonado", "Segurança", "Percebe dois aparelhos com o mesmo endereço físico."),
        s(58, "Anti-ARP Spoofing", "Segurança", "Vigia mudanças suspeitas na tabela ARP."),
        s(59, "Rastreador de Rede Falsa", "Segurança", "Detecta pontos de acesso clonando o seu SSID."),
        s(60, "Aparelhos Confiáveis", "Segurança", "Marque quem é de casa e destaque o resto."),
        s(61, "Auditoria de Portas", "Segurança", "Avisa quando um aparelho abre porta perigosa."),
        s(62, "Guardião do Roteador", "Segurança", "Monitora se o painel do roteador foi alterado."),
        s(63, "Trava da Minha Rede", "Segurança", "O app só funciona quando você está na SUA rede."),
        s(64, "Registro de Segurança", "Segurança", "Log dedicado de todos os eventos de risco."),
        s(65, "Modo Discreto", "Segurança", "Esconde dados sensíveis da tela rapidamente."),
        s(66, "Backup Cifrado", "Segurança", "Salva sua configuração protegida por senha."),

        // ---- Ferramentas e automação (67-78) ----
        s(67, "Ping Manual", "Ferramentas", "Dispara ping para qualquer IP quando quiser."),
        s(68, "Traceroute", "Ferramentas", "Mostra o caminho dos pacotes até o destino."),
        s(69, "Consulta DNS", "Ferramentas", "Resolve nomes e checa a saúde do DNS."),
        s(70, "Wake-on-LAN", "Ferramentas", "Liga computadores da rede remotamente."),
        s(71, "Painel do Roteador", "Ferramentas", "Atalho direto para a administração do roteador."),
        s(72, "Reiniciar Roteador", "Ferramentas", "Envia comando de reinício ao roteador."),
        s(73, "Gerador de Senha Wi-Fi", "Ferramentas", "Cria senhas fortes para a sua rede."),
        s(74, "QR da Rede", "Ferramentas", "Gera código para visitantes conectarem sem digitar senha."),
        s(75, "Central de Notificações", "Ferramentas", "Todos os avisos do sistema em um só lugar."),
        s(76, "Automação por Regras", "Ferramentas", "Se acontecer X, o app faz Y automaticamente."),
        s(77, "Widget Rápido", "Ferramentas", "Acesso imediato aos controles essenciais."),
        s(78, "Serviço em Segundo Plano", "Ferramentas", "Mantém o monitoramento ativo mesmo com o app fechado.")
    )

    val categories: List<String> = all.map { it.category }.distinct()

    private fun s(id: Int, name: String, cat: String, desc: String) =
        SystemModule(id, name, cat, desc)
}
