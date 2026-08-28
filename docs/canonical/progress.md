# UTS/UES — PROGRESSO ATÉ O GÊNESIS COMPLETO

> **RÉGUA ADR-019 (fidelidade de representação)**: a régua antiga media
> "sistema implementado + testes". A régua nova mede **o quão fielmente o
> sistema REPRESENTA O FENÔMENO REAL** (12 pontos em vision.md). O marco
> honesto do re-baseline era **70%** — o 89% anterior media a coisa errada.
> Auditoria completa: `audit-vision.md`.
> Meta: GÊNESIS = a visão COMPLETA (vision.md), usável por todos, UTS+UES
> funcionais. Recalculado **a cada rodada**, sem inflar nada.

## % ATUAL: **75%** (após R2 "FENÔMENOS II" — som, energia e comida reais)

| # | Categoria | Peso | Completo | Contribuição | Evidência / o que falta |
|---|---|---|---|---|---|
| 1 | **Núcleo da realidade** — RRW, Tese dos D, D-O15, SpatialGrid, NMN, sociedade/economia, **RealLife→fenômenos reais** | 18 | 88% | 15.84 | R1+R2: ar/água/fogo/vida/som/energia causais e verificados; falta: clima regional (escalas R3), agentes comendo a paisagem direto |
| 2 | **Render como MATERIALIZAÇÃO** — RHI, pipeline WebGL2 (7 programas), sombras PCF, instancing, culling, LOD 3-tier, **céu = espalhamento Rayleigh/Mie do AR**, **vegetação = população viva materializada**, precipitação | 14 | 52% | 7.28 | céu e vegetação agora DERIVADOS de estado real; falta: renderizar a lâmina d'água da hidrologia (quad fixo = limitação conhecida), cinzas/queimado visível, partículas de fogo |
| 3 | **Singularity AI** — Core (interpretar→planejar→executar→verificar→corrigir), providers, ModelRegistry, agentes, memória | 14 | 75% | 10.50 | ExternalLLM validado vs mock; falta: busca web real, LLM vivo no loop, agentes geradores de código |
| 4 | **Plataforma UTS** — serviços, apps, CreationProjects, research triangulado, GitHub, Comm | 12 | 85% | 10.20 | funcional; falta: storage externo, apps de usuário reais |
| 5 | **Usabilidade para todos** — demo browser (render + IA cria mundo + áudio + save/load + **HUD de fenômenos**), CLI, docs, Termux | 10 | 83% | 8.30 | falta: onboarding guiado, tutorial interativo, empacotamento 1-comando |
| 6 | **Física como realidade** — translação, impactos causais, **energia ½mv² + deformação persistente por MATERIAL (rocha/madeira/gelo)**, rotação+torque, juntas PBD, raycast, persistência (a amassado sobrevive save/load) | 8 | 72% | 5.76 | falta: quaternions livres, ragdoll, fluidos |
| 7 | **Áudio como fenômeno** — synth, binaural ITD+ILD, música adaptativa, stream, devices, WAV, **ACÚSTICA REAL (atraso d/343, sombra de terreno, absorção do ar úmido; trovão longe = rumble grave = re-representação D-O15)** | 8 | 78% | 6.24 | falta: HRTF completa (pinna), reverb por ambiente, re-representar fogo longe (brilho+crepitar abafado) |
| 8 | **Streaming + Persistência** — residência LOD, histerese, UTS-DB, autosave, **fenômenos persistem (ar/água/fogo/vida no snapshot)** | 8 | 82% | 6.56 | save→load byte-idêntico COM fenômenos; falta: streaming assíncrono (workers), deltas por-entidade |
| 9 | **Ferramentas/pipelines avançados** — tools validadas, projetos duráveis, agentes especializados | 8 | 60% | 4.80 | falta: agentes coder/graphics gerando código real |
| | **TOTAL** | **100** | | **75.48 ≈ 75%** | |

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
| **R2 FENÔMENOS II (esta)** | **75%** | **acústica (som=onda de pressão: atraso d/343, sombra de terreno, absorção do ar; trovão longe=rumble grave), física de energia (½mv², materiais rocha/madeira/gelo, deformação persistente), comida=clima (solo rega bushes; seca mata com evento); 219 testes** |
