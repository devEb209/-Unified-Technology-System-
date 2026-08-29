# UTS/UES — PROGRESSO ATÉ O GÊNESIS COMPLETO

> **RÉGUA ADR-019 (fidelidade de representação)**: a régua antiga media
> "sistema implementado + testes". A régua nova mede **o quão fielmente o
> sistema REPRESENTA O FENÔMENO REAL** (12 pontos em vision.md). O marco
> honesto do re-baseline era **70%** — o 89% anterior media a coisa errada.
> Auditoria completa: `audit-vision.md`.
> Meta: GÊNESIS = a visão COMPLETA (vision.md), usável por todos, UTS+UES
> funcionais. Recalculado **a cada rodada**, sem inflar nada.

## % ATUAL: **82%** (após R7 — OFENSIVA GRÁFICA ADR-020: céu = física integrada; 82.46 exato, era 81.66)

| # | Categoria | Peso | Completo | Contribuição | Evidência / o que falta |
|---|---|---|---|---|---|
| 1 | **Núcleo da realidade** — RRW, Tese dos D, D-O15, SpatialGrid, NMN, sociedade/economia, **RealLife→fenômenos reais** | 18 | 88% | 15.84 | R1+R2: ar/água/fogo/vida/som/energia causais e verificados; falta: clima regional (escalas R3), agentes comendo a paisagem direto |
| 2 | **Render como MATERIALIZAÇÃO** — RHI, pipeline WebGL2 (8 programas), sombras PCF, instancing, culling, LOD 3-tier, **CÉU = INTEGRAL DO ESPALHAMENTO RAYLEIGH+MIE POR PIXEL (espelho JS testado + GLSL GERADO das mesmas constantes)**, **PERSPECTIVA AÉREA física no lugar de fog pintado (terreno/entidades/água; água reflete o CÉU REAL)**, **atmosfera dona da óptica (frame.air), sol verdadeiro não-clampado**, vegetação = população viva, mar segue a câmera, lâmina d'água RENDERIZADA, cinzas/queimado visíveis, chuva re-representada, horizonte vivo | 14 | 76% | 10.64 | falta: partículas de fogo, malha própria p/ árvores, nuvens volumétricas, pós-processo |
| 3 | **Singularity AI** — Core, **GRAMÁTICA DE CRIAÇÃO**, **ANEXOS VALIDADOS**, **LLM REAL NO LOOP (env: UTS_LLM_API_KEY/URL/MODEL; objetivos com raciocínio vão direto ao modelo; chave nunca entra em logs/snapshots — testado)**, providers, agentes, memória | 14 | 86% | 12.04 | falta: agentes geradores de código real, streaming SSE no UI |
| 4 | **Plataforma UTS** — serviços, apps, CreationProjects, research triangulado **com HttpSearchProvider real (env: UTS_SEARCH_URL/KEY)**, GitHub, Comm | 12 | 88% | 10.56 | funcional; falta: storage externo, apps de usuário reais |
| 5 | **Usabilidade para todos** — demo browser completo **COM TOUR GUIADO (5 passos, destaca painéis, uma vez por visitante)**, render + IA cria mundo + anexos + áudio + save/load + HUD de fenômenos, CLI, docs, Termux | 10 | 89% | 8.90 | falta: galeria de mundos-exemplo, empacotamento 1-comando |
| 6 | **Física como realidade** — translação, impactos causais, **energia ½mv² + deformação persistente por MATERIAL (rocha/madeira/gelo)**, rotação+torque, juntas PBD, raycast, persistência (a amassado sobrevive save/load) | 8 | 72% | 5.76 | falta: quaternions livres, ragdoll, fluidos |
| 7 | **Áudio como fenômeno** — synth, binaural ITD+ILD, música adaptativa, stream, devices, WAV, **ACÚSTICA REAL (atraso d/343, sombra de terreno, absorção do ar)**, **MUFFLE = FILTRO REAL (o crepitar abafado atrás da serra)**, trovão longe = rumble grave | 8 | 84% | 6.72 | falta: HRTF completa (pinna), reverb por ambiente |
| 8 | **Streaming + Persistência** — residência LOD, histerese, UTS-DB, autosave, fenômenos persistem, **STREAMING ASSÍNCRONO (worker_threads: amostragem off-thread byte-idêntica à síncrona, demo/Node opt-in, browser cai honestamente p/ sync)** | 8 | 90% | 7.20 | falta: deltas por-entidade (event tail RRW) |
| 9 | **Ferramentas/pipelines avançados** — tools validadas, projetos duráveis, agentes especializados | 8 | 60% | 4.80 | falta: agentes coder/graphics gerando código real |
| | **TOTAL** | **100** | | **81.66 ≈ 82%** | |

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
| **R7 OFENSIVA GRÁFICA (ADR-020)** | **82%** (82.46) | céu = integral Rayleigh+Mie por pixel (espelho JS validado: meio-dia azul, sol poente vermelho, disco, noite, poeira dessatura); perspectiva aérea física substitui fog pintado em terreno/entidades/água; água reflete o céu real; atmosphere.optics dona da óptica; 251 testes |
| **R1 FENÔMENOS I** | **73%** | **atmosfera (céu=espalhamento do ar), hidrologia (água=substância), combustão (fogo=combustível+vento+umidade), ecologia (vegetação=população viva); reallife re-ligado à realidade; fenômenos persistem; 210 testes** |
| **R2 FENÔMENOS II** | **75%** | **acústica (som=onda de pressão: atraso d/343, sombra de terreno, absorção do ar; trovão longe=rumble grave), física de energia (½mv², materiais rocha/madeira/gelo, deformação persistente), comida=clima (solo rega bushes; seca mata com evento); 219 testes** |
| **R3 ESCALA** | **77%** | **mar segue a câmera, lâmina d'água renderizada, horizonte vivo (brilho/marcador causal, sem dupla representação); 226 testes** |
| **R4+R5 RE-REPRESENTAÇÃO+CRIAÇÃO** | **79%** | **muffle=filtro real, cinzas que desvanecem, chuva re-representada; gramática multi-comando, anexos validados, plant_forest; 237 testes** |
| **R6 PLATAFORMA REAL (esta)** | **82%** | **streaming assíncrono (workers byte-idênticos), LLM real no loop via env (chave jamais persistida — testado), HttpSearchProvider real via env, tour guiado no demo; 242 testes** |
