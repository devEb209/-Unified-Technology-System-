# THEATRE ZERO — GDD DE SISTEMAS
### "Realismo que transborda": as regras técnicas que produzem a sensação de guerra real

O documento abaixo separa o que **já está implementado no protótipo jogável** (`/game`)
do que é **especificação para a produção completa**. Cada sistema tem um critério de
aceitação verificável — nada de "deve ser realista", e sim "a queda a 400 m deve ser 1,3 m".

Legenda: ✅ implementado no protótipo · 🔶 parcial · ⬜ especificado para produção

---

## 1. A CÂMERA CORPORAL (o pilar)

A câmera **não é um efeito de pós-produção estilizado**. É a simulação de um sensor CMOS
barato, com rolling shutter, preso a um arnês que balança com o corpo.

| Sistema | Estado | Critério de aceitação |
|---|---|---|
| Rolling shutter (skew por velocidade angular) | ✅ | Girar rápido deve entortar as verticais da cena |
| Ganho ISO dinâmico + ruído cromático por luminância | ✅ | Sombra granulada, luz limpa; o grão vive na sombra |
| Auto-exposição com atraso assimétrico | ✅ | Sair do escuro para o holofote satura 1,2 s antes de corrigir |
| Aberração cromática lateral (cresce com o raio) | ✅ | Centro limpo, cantos com franja vermelho/azul |
| Distorção de barril de grande-angular (96° FOV) | ✅ | Linhas retas curvam nas bordas; some ao mirar |
| Macroblocos de compressão H.264 em movimento | ✅ | Correr faz o vídeo "quebrar" em blocos |
| Gotas de chuva e sujeira na lente com refração | ✅ | Gotas deslocam a imagem, não são adesivos |
| Sangue na lente conforme dano | ✅ | Ferimento grave = campo de visão comprometido de verdade |
| Visão noturna Gen-3 (P43, cintilação, blooming, vinheta do tubo) | ✅ | Holofote aceso "queima" o tubo e cega o jogador |
| Motion blur temporal por acumulação de frames | ✅ | Sensor lento borra o giro, não a cena parada |
| Molas do arnês (câmera com massa própria) | ✅ | A câmera chega **depois** do movimento do corpo |
| Interferência de guerra eletrônica (glitch, roll) | ✅ | Perto de emissores a imagem rola e perde linhas |
| Bateria acabando / desligamento (Ato IV) | ⬜ | 6 min de jogo só com áudio |
| Suporte a lente rachada por estilhaço | ⬜ | Trinca permanente no HUD óptico até fim da missão |

**Nenhum elemento de interface existe em campanha ou multiplayer.**
O único elemento de DOM sobre o vídeo é o botão `SAIR DA OPERAÇÃO`, exigido pelo briefing.
Legendas de rádio aparecem como transcrição queimada no vídeo (padrão de bodycam militar) e
podem ser desligadas.

### Como o jogador sabe as coisas sem HUD
| Informação | Como se obtém |
|---|---|
| Munição | `V` — o operador saca o carregador e olha; peso do fuzil muda a animação |
| Vida | Respiração, tremor, sangue na lente, passos mais curtos, visão desfocada |
| Direção / objetivo | Rádio (voz), placas no cenário, terreno, estrelas |
| Inimigo | Som da bota, voz, lanterna, silhueta — nunca um marcador |
| Recarga | Som do ferrolho e do carregador batendo no chão |

---

## 2. BALÍSTICA E ARMAMENTO

Modelo de ponto material com arrasto quadrático calibrado contra tabelas reais.

| Munição | Vel. boca | Queda @400 m | Vel. restante @400 m | Estado |
|---|---|---|---|---|
| 7.62×51 M118LR (M110 SASS) | 838 m/s | **1,33 m** | **658 m/s** | ✅ (tabela real: ~1,3 m / ~660 m/s) |
| 5.56×45 M855 (MK18) | 780 m/s | 0,90 m @300 m | 579 m/s @300 m | ✅ |
| 9×19 124 gr (Glock 19) | 365 m/s | 0,10 m @50 m | 333 m/s @50 m | ✅ |

Implementado ✅:
- arrasto quadrático com coeficiente balístico G1 por munição;
- deriva de vento (vetor de vento do mundo entra na equação, não é decoração);
- **velocidade do som**: o estalo supersônico chega antes do estampido da boca — a IA e o
  jogador localizam a origem errado, exatamente como na vida real;
- penetração por material com perda de energia e desvio angular (concreto, metal, saco de
  areia, madeira, chapa de veículo);
- ricochete dependente do ângulo de incidência (< 16° tende a quicar);
- dispersão gaussiana em MOA por arma, agravada por fadiga, supressão e postura;
- dano por energia cinética e região atingida (cabeça / tórax / membros), sem "barra de vida":
  um 7.62 no tórax **encerra** o combate.

Especificado ⬜: fragmentação de projétil (yaw), sobrepenetração com dano reduzido no segundo
alvo, aquecimento de cano alterando ponto de impacto, munição subsônica dedicada.

### Manuseio
✅ recuo com mola (retorno não é instantâneo nem perfeito — o ponto de mira **drifta**),
✅ recarga tática vs. recarga com câmara vazia (esta exige ferrolho e é ~0,8 s mais lenta),
✅ tempo de troca de arma, ✅ tempo de mira dependente do peso, ✅ prender a respiração com
custo de fôlego, ✅ mira instintiva (sem retículo) muito imprecisa fora do ADS,
✅ luneta 10× com máscara óptica, mil-dot e **sombra de olho** quando a cabeça sai do eixo.

---

## 3. O CORPO DO OPERADOR

Não existe "vida". Existe fisiologia:
- **fôlego** (consumido por corrida, prender respiração e dor) → amplitude da oscilação da mira;
- **frequência cardíaca** (62–190 bpm) → tremor visível na câmera e no cano;
- **supressão** — passar bala perto sobe o batimento, estreita a respiração e degrada a mira
  por vários segundos; ✅
- **dor e sangramento** — dano contínuo, campo de visão sujo, marcha mais lenta; ✅
- **surdez temporária** por tiro sem supressor perto de parede (áudio real: compressor + filtro
  passa-baixa + zumbido de 6,3 kHz); ✅
- **postura**: em pé / agachado / deitado alteram velocidade, silhueta, ruído, estabilidade e
  a altura da câmera. ✅

---

## 4. INTELIGÊNCIA ARTIFICIAL

Percepção honesta ✅:
- cone de visão real com raycast de oclusão **e** teste analítico contra o relevo;
- visibilidade ponderada por: distância, **iluminação real do ponto** (holofote aceso importa),
  postura do alvo, movimento do alvo;
- audição por eventos com raio: passo, corrida, tiro suprimido (~42 m) vs. não suprimido (~240 m),
  sabotagem, corpo caindo;
- **tempo de reação humano** de 0,22–0,67 s antes do primeiro tiro;
- suspeita acumulativa em três níveis: calmo → investiga → combate (sem "!" na tela);
- comunicação de esquadrão por rádio: um viu, todos sabem em ~4 s — e você **ouve** o rádio dele;
- corpos são descobertos e disparam alarme com atraso;
- em combate: rajadas curtas, recarga, flanqueamento, busca do último ponto conhecido, agachar
  sob fogo.

Especificado ⬜: cobertura dinâmica com pontuação tática, granada de fumaça para avanço,
arrastar feridos, rendição, ordens de oficial (se o oficial morre, o esquadrão degrada).

---

## 5. MUNDO E CENÁRIO DINÂMICO

✅ no protótipo: relevo procedural com colisão analítica, instalação militar completa
(muro, prédios com interior, torres de vigia, contêineres empilhados, veículos, sacos de areia,
gerador, terminal SIGINT, antena de radar), chuva volumétrica que segue o jogador, vento que
afeta chuva/fumaça/bala, ciclo dia-noite com céu de Rayleigh/Mie, holofotes que **podem ser
apagados** e mudam toda a partida, fumaça de dutos, decalques de impacto persistentes.

⬜ produção: destruição estrutural por camadas (revestimento → alvenaria → estrutura),
incêndio propagante, inundação de compartimento em missões navais, neve acumulativa,
detritos que viram cobertura, prédios que desabam e mudam a rota da IA no meio do tiroteio.

---

## 6. ÁUDIO — 100% PROCEDURAL NO PROTÓTIPO

✅ síntese em tempo real de: disparo (impulso de boca + corpo grave + mecanismo), diferença
audível entre suprimido e não suprimido, estalo supersônico, impactos por material, ricochete
com queda de tom Doppler, passos por superfície, respiração acoplada ao batimento, rádio com
squelch e distorção, artilharia distante, chuva e vento com LFO.

Distância implementada com **atraso real** (343 m/s), absorção do ar (passa-baixa por distância),
oclusão e cauda de reverberação convolutiva gerada por código.

⬜ produção: HRTF binaural, reverb por volume de sala com traçado de raios, banco de gravações
reais de armas em campo aberto a 5/50/200/800 m, voz de operador com estados de estresse.

---

## 7. CAMPANHA E DECISÕES SIMULTÂNEAS

✅ grafo de missão com fases, objetivos por rádio, **duas ordens contraditórias no mesmo
instante com cronômetro**, consequência imediata no mundo (corte de energia real vs. ataque de
drone real), estado global de reputação com três entidades, registro de escolhas no epílogo,
detecção que reescreve a missão (reforços convergem por dois eixos).

⬜ produção: 27 missões, 11 países, 5 finais, persistência entre atos, mortes permanentes de
personagens, e o **Ledger** — arquivo consultável in-game com o custo de cada decisão sua.

---

## 8. MULTIPLAYER (sem UI)

🔶 protótipo: servidor de relay em Node/WebSocket a 20 Hz, replicação de posição/orientação,
interpolação local, peers visíveis no mundo. Ativar com `?mp=1`.

⬜ produção:
- **modo ARQUIVO** (16 jogadores): objetivo assimétrico, sem respawn, sem placar visível —
  você só sabe que perdeu quando para de ouvir o rádio dos seus.
- Sem nametags, sem minimapa, sem indicador de dano: identificação por uniforme, voz e
  disciplina de fogo. Fogo amigo sempre ligado.
- Voz por proximidade + rádio de esquadrão com alcance e ruído reais.
- Netcode: simulação autoritativa no servidor com rollback de 120 ms para a balística.

---

## 9. DESEMPENHO (metas do protótipo web)

- 60 fps em GPU integrada moderna a 1080p com escala dinâmica de resolução.
- Percepção da IA a 10 Hz escalonada por soldado (não a cada frame).
- Zero raycast contra o terreno de 80 k triângulos — substituído por marcha analítica no
  heightfield (ganho medido de **160×** no teste de simulação headless).
- Pool fixo de partículas e decalques com reciclagem.

Teste de regressão: `node tools/smoke.js` roda 30 s de mundo, IA, balística e campanha sem GPU
e valida que a simulação não lança exceções e que os objetivos avançam.
