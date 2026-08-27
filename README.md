# UTS — Unified Technology System

> **Construir uma representação computacional da realidade.**
> A UTS é a arquitetura maior: um sistema para representar, construir e otimizar
> mundos/realidades computacionais. A **UES (Unified Engine System)** é sua
> aplicação principal (o engine que roda um mundo) — UES ≠ UTS; a UES é uma
> camada de aplicação sobre a UTS.

```
        ┌────────────────────────────────────────────────────────────┐
        │                        UTS (arquitetura maior)             │
        │                                                            │
        │  ┌──────────┐  ┌──────────────┐  ┌─────────────────────┐  │
        │  │ Singularity AI │  Tese dos D │  D-O15 (otimização    │  │
        │  │ Core + modelos  │  D-0…D-MAX* │  inteligente + HW)    │  │
        │  └──────┬─────┘  └──────┬──────┘  └──────────┬──────────┘  │
        │         └───────────────┼─────────────────────┘            │
        │                         ▼                                  │
        │  ┌─────────────────────────────────────────────────────┐   │
        │  │  RRW — representação aberta da realidade             │   │
        │  │  (entidades, componentes, relações, processos,       │   │
        │  │   eventos + CAUSALIDADE verificável,                 │   │
        │  │   materialização ⇄ abstração, persistência)          │   │
        │  └───────────────────────────┬─────────────────────────┘   │
        └──────────────────────────────┼─────────────────────────────┘
                                       ▼
        ┌────────────────────────────────────────────────────────────┐
        │              UES — aplicação principal (engine)            │
        │  World (chunks/streaming/camadas semânticas) · NMN (NPCs)  │
        │  Sociedade/economia · Gráficos (Real Life, LOD, backends)  │
        │  Engine: relógio + scheduler adaptativo + bridge de IA     │
        │  Persistência: save/restore determinístico do estado todo  │
        └────────────────────────────────────────────────────────────┘
```

\* D-MAX = **provisório (não ratificado)** — ver [`docs/canonical/provisional.md`](docs/canonical/provisional.md).

## Estado (auditoria real — sem exagero)

| Camada | Estado | Evidência |
|---|---|---|
| Núcleo (tempo, RNG com estado serializável, eventos, perf) | **IMPLEMENTADO** | `src/core` + 8 testes |
| RRW (representação aberta) | **IMPLEMENTADO** | `src/rrw` + 8 testes |
| RRW: causalidade **verificável** | **IMPLEMENTADO** | `validateCausality` + testes (detecta causa fabricada) |
| RRW: persistência (serialize/restore) | **IMPLEMENTADO** | `src/ues/persistence.ts` + 4 testes (determinismo) |
| Tese dos D (fracionário **com efeito comportamental**) | **IMPLEMENTADO** (D-MAX provisório) | `src/d` + 7 testes + `behaviorScale` |
| D-O15 (mede→analisa→decide→adapta, c/ raio de materialização) | **IMPLEMENTADO** | `src/d-o15` + 7 testes |
| Singularity AI (provider externo plugável — demonstrado) | **IMPLEMENTADO** | `src/ai` + 10 testes |
| UES: World + streaming + camadas | **IMPLEMENTADO** | `src/ues/world.ts` + 8 testes |
| UES: NMN (NPCs, percepção fracionária) | **IMPLEMENTADO** | `src/ues/npc.ts` + 7 testes |
| UES: Sociedade/economia | **IMPLEMENTADO** | `src/ues/society.ts` + 5 testes |
| UES: Gráficos/Real Life (aberto a novos fenômenos) | **IMPLEMENTADO** | `src/ues/graphics.ts` + 6 testes |
| UES: Engine (integração) | **IMPLEMENTADO** | `src/ues/engine.ts` + 4 testes |
| Provas canônicas (fracionário, raio adaptativo, RRW fora do espaço, provider externo, round-trip) | **IMPLEMENTADO** | `test/canonical.test.ts` (11 testes) |
| Persistência + determinismo | **IMPLEMENTADO** | `test/persistence.test.ts` (4 testes) |
| Escala + **prova de gargalo** (medido: 500 ok / 2000 = gargalo CPU) | **TESTADO** | `test/scale.test.ts` + `test/scale-probe.test.ts` |
| Renderização real (GPU) | **AUSENTE** (arquitetura pronta, backend é o plug point) | `src/ues/graphics.ts` |
| LLM externo no Node | **AUSENTE** (provider plugável demonstrado) | `test/canonical.test.ts` |

**95 testes passando** (Node 22 nativo, zero dependências).

## Começar

```bash
node --version        # requer >= 22.18 (executa .ts nativamente)
npm test              # suíte completa (95 testes)
npm run demo          # demo completa (IA → mundo → D-O15 → frame ASCII)
npm run demo:lowend   # mesma demo, hardware low-end (adaptatividade visível)
node tools/demo.ts --hardware mid --seconds 120 --seed 7
```

## O ciclo (o que a demo faz)

1. **Objetivo em texto** → `SingularityCore` interpreta, o modelo arquiteto
   (S++) planeja, agentes executam com modelos escolhidos por tarefa,
   verificador valida cada etapa (correção automática em até 2 tentativas).
2. A cena é construída **no RRW** (bioma, estruturas, NPCs) — entidades com
   componentes, relações, eventos e **causalidade verificável**.
3. O **Engine** roda: relógio → D-O15 reanalisando pressão a cada 0,5 s →
   scheduler dentro do orçamento do hardware → mundo evolui (clima, NPCs
   decidindo por utilidade, sociedade produzindo/consumindo, preços, fome
   com causa) → frame interpretado (iluminação, Real Life, LOD, sombras).
4. **Adaptação**: sem perder estado — entidades fora do foco ficam
   abstratas (detalhe 0, tick barato); o estado é preservado e re-materializa
   quando o foco volta. Sob pressão, a **própria zona materializada encolhe**
   (D-O15 controla abstração/materialização). Hardware pode degradar/promover.
5. **Persistência**: `saveUes(engine)` → string JSON do estado completo
   (mundo, NPCs, sociedade, causalidade, relógio, RNG, memória);
   `restoreFromJson(...)` → engine que evolui **idêntico** ao original.

## Documentação canônica

A separação **CANON vs RECONSTRUÇÃO vs LIMITAÇÃO** vive em
[`docs/canonical/`](docs/canonical/README.md) — matriz canônica, visão,
arquitetura vigente, Tese dos D, RRW (conceito canônico; acrônimo proposto),
D-O15, Singularity AI, UES, decisões confirmadas, **provisório** (D-MAX,
acrônimo RRW, natureza do HeuristicProvider) e **limitações reais**.

Regra: **CANON > RECONSTRUÇÃO** — suposições do agente nunca viram decisão
oficial sem ratificação (ver `docs/canonical/provisional.md`).

## Estrutura

```
src/
  core/       # tempo, RNG (estado serializável), eventos, logger, métricas
  rrw/        # representação da realidade (entidades/processos/causalidade/serialize)
  d/          # Tese dos D (D-0…D-MAX)
  d-o15/      # perfil de hardware, profilers, estratégia, scheduler
  ai/         # memória (serialize/load), registries, core
  ues/        # world, npc (NMN), society, graphics, engine, persistence
  contracts.ts# WorldAdapter (IA ↔ mundo — inversão de dependência)
test/         # 14 arquivos, 95 testes (core→rrw→d→d-o15→ai→ues→canon→persistência→escala)
tools/demo.ts # demo do ciclo completo
docs/
  canonical/  # ★ documentação canônica (matriz + visão + decisões + provisório + limitações)
  architecture.md · status.md · decisions.md
```
