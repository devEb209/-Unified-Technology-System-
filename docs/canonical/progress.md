# UTS/UES — PROGRESSO ATÉ O GÊNESIS COMPLETO

> **RÉGUA ADR-019 (fidelidade de representação)**: a régua antiga media
> "sistema implementado + testes". A régua nova mede **o quão fielmente o
> sistema REPRESENTA O FENÔMENO REAL** (12 pontos em vision.md). O marco
> honesto do re-baseline era **70%** — o 89% anterior media a coisa errada.
> Auditoria completa: `audit-vision.md`.
> Meta: GÊNESIS = a visão COMPLETA (vision.md), usável por todos, UTS+UES
> funcionais. Recalculado **a cada rodada**, sem inflar nada.

## % ATUAL: **79%** (após R4 "RE-REPRESENTAÇÃO" + R5 "GRAMÁTICA+ANEXOS")

| # | Categoria | Peso | Completo | Contribuição | Evidência / o que falta |
|---|---|---|---|---|---|
| 1 | **Núcleo da realidade** — RRW, Tese dos D, D-O15, SpatialGrid, NMN, sociedade/economia, **RealLife→fenômenos reais** | 18 | 88% | 15.84 | R1+R2: ar/água/fogo/vida/som/energia causais e verificados; falta: clima regional (escalas R3), agentes comendo a paisagem direto |
| 2 | **Render como MATERIALIZAÇÃO** — RHI, pipeline WebGL2 (8 programas), sombras PCF, instancing, culling, LOD 3-tier, **céu = espalhamento do AR**, **vegetação = população viva**, **mar segue a câmera**, **lâmina d'água RENDERIZADA**, **CINZAS/QUEIMADO VISÍVEL (desvanece com idade real)**, **chuva re-representada sob pressão (menos+maior+mais rápida)**, horizonte vivo | 14 | 70% | 9.80 | falta: partículas de fogo, malha própria p/ árvores, pós-processo |
| 3 | **Singularity AI** — Core (interpretar→planejar→executar→verificar→corrigir), **GRAMÁTICA DE CRIAÇÃO (multi-comando, relações perto/ao-norte-de, fontes citadas, determinística)**, **ANEXOS VALIDADOS (csv→posições, nomes→vilas, imagem honestamente não vista)**, providers, agentes, memória | 14 | 82% | 11.48 | falta: busca web real, LLM vivo no loop, agentes geradores de código |
| 4 | **Plataforma UTS** — serviços, apps, CreationProjects, research triangulado, GitHub, Comm | 12 | 85% | 10.20 | funcional; falta: storage externo, apps de usuário reais |
| 5 | **Usabilidade para todos** — demo browser (render + IA cria mundo + áudio + save/load + **HUD de fenômenos**), CLI, docs, Termux | 10 | 83% | 8.30 | falta: onboarding guiado, tutorial interativo, empacotamento 1-comando |
| 6 | **Física como realidade** — translação, impactos causais, **energia ½mv² + deformação persistente por MATERIAL (rocha/madeira/gelo)**, rotação+torque, juntas PBD, raycast, persistência (a amassado sobrevive save/load) | 8 | 72% | 5.76 | falta: quaternions livres, ragdoll, fluidos |
| 7 | **Áudio como fenômeno** — synth, binaural ITD+ILD, música adaptativa, stream, devices, WAV, **ACÚSTICA REAL (atraso d/343, sombra de terreno, absorção do ar)**, **MUFFLE = FILTRO REAL (o crepitar abafado atrás da serra)**, trovão longe = rumble grave | 8 | 84% | 6.72 | falta: HRTF completa (pinna), reverb por ambiente |
| 8 | **Streaming + Persistência** — residência LOD, histerese, UTS-DB, autosave, **fenômenos persistem (ar/água/fogo/vida no snapshot)** | 8 | 82% | 6.56 | save→load byte-idêntico COM fenômenos; falta: streaming assíncrono (workers), deltas por-entidade |
| 9 | **Ferramentas/pipelines avançados** — tools validadas, projetos duráveis, agentes especializados | 8 | 60% | 4.80 | falta: agentes coder/graphics gerando código real |
| | **TOTAL** | **100** | | **79.42 ≈ 79%** | |

## O que separa 73% → 100% (fila R1–R6 de audit-vision.md)

1. **R3 — ESCALA generalizada**: LOD materializa escala (cidade distante =
   estado causal; água da hidrologia renderizada onde importa).
3. **R4 — D-O15 re-representação**: trovão longe = rumble, fogo longe =
   brilho no horizonte (re-representar, nunca descartar).
4. **R5 — Gramática de criação + anexos**: IA cria com contexto rico.
5. **R6 — Workers + LLM real + onboarding**: o resto da plataforma.

## Histórico de rodadas (régua nova salvo indicação)

| Rodada | % | Sistemas terminados na rodada |
|---|---|---|
| (régua antiga) Gênesis→Autosave→4 sistemas→LOD→fade/água/IA | 62→89% | ver git; media "implementado+testes", não fidelidade |
| **Re-baseline ADR-019 (4e0ae5f)** | **70%** | visão como lei, auditoria honesta A–G |
| **R1 FENÔMENOS I** | **73%** | **atmosfera (céu=espalhamento do ar), hidrologia (água=substância), combustão (fogo=combustível+vento+umidade), ecologia (vegetação=população viva); reallife re-ligado à realidade; fenômenos persistem; 210 testes** |
| **R2 FENÔMENOS II** | **75%** | **acústica (som=onda de pressão: atraso d/343, sombra de terreno, absorção do ar; trovão longe=rumble grave), física de energia (½mv², materiais rocha/madeira/gelo, deformação persistente), comida=clima (solo rega bushes; seca mata com evento); 219 testes** |
| **R3 ESCALA** | **77%** | **mar segue a câmera, lâmina d'água renderizada, horizonte vivo (brilho/marcador causal, sem dupla representação); 226 testes** |
| **R4+R5 RE-REPRESENTAÇÃO+CRIAÇÃO (esta)** | **79%** | **R4: muffle=filtro real no áudio (2 vias), cinzas visíveis que desvanecem com idade, chuva re-representada sob pressão D-O15 (menos+maior+mais rápida). R5: gramática de criação (multi-comando, relações, fontes citadas), anexos validados (csv/nomes/imagem-honesta), world.plant_forest (ecologia real); 237 testes** |
