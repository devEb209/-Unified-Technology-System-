# Arquitetura — UTS (versão vigente das decisões)

> Fonte da verdade: os prompts do usuário (16 decisões) + auditoria do estado
> real. Este documento NÃO inventa estado: descreve o que existe e como as
> camadas se conectam.

## 1. Hierarquia

```
UTS (Unified Technology System) — arquitetura maior
│  visão: representação computacional da realidade, construída e
│          orquestrada, com qualidade ótima sob hardware real
│
├─ RRW — representação aberta (dados + processos + causalidade)
├─ Tese dos D — níveis de representação (D-0 … D-MAX)
├─ D-O15 — otimização inteligente (decisão por pressão + relevância)
├─ Singularity AI — orquestração (planejamento/modelos/agentes/ferramentas)
└─ UES — aplicação principal (engine de mundos/simulações)
     ├─ World (chunks, streaming, camadas semânticas, ambiente, fogo)
     ├─ NMN (mENTES de NPCs — necessidades/utilidade/memória/relações)
     ├─ Sociedade (grupos, economia, famine, mercado)
     └─ Gráficos (Real Life, LOD, iluminação, sombras, backends)
```

**Inversão de dependência:** a IA depende do `WorldAdapter` (contrato em
`src/contracts.ts`); o mundo **não** depende da IA. A UES implementa o
contrato; qualquer outro mundo pode se plugar na IA.

## 2. Camadas da UTS

### 2.1 Core (`src/core`)
- `SimClock` — relógio de simulação (time, tick, dt fixo no engine).
- `Rng` — PRNG determinístico (mulberry32) por seed → mundos reproduzíveis.
- `EventBus` — eventos tipados (síncrono).
- `Logger` — log com escopo e sink global (tests silenciam).
- `PerfMeter` — mede custo REAL de trabalho (`measure(name, fn)`) — é a base
  da confiança do D-O15 ("sem medição, sem claim").
- helpers: `clamp/lerp/damp/dist2d`.

### 2.2 RRW (`src/rrw`)
A representação da realidade. **Aberta por categoria** — categorias,
componentes, camadas, processos e agentes são extensíveis em runtime.

- **Entidades** `{ id, name, categories[], components: Map, data, detail,
  alive, contextId, spawnedBy }` — `detail ∈ [0,1]` (materialização).
- **Componentes** definidos com `compress`/`restore`/`cost` — a abstração
  preserva o DADOS, comprime o DETALHE (ex.: Heightfield 15MB→1,6KB;
  Position/Mind preservados inteiros).
- **Relações** direcionadas, nomeadas, com peso, opcionalmente causais.
- **Eventos** com `cause { by, event }` → `causalChain()` reconstrói a cadeia
  de causas (profundidade limitada; eventos ficam no log da entidade).
- **Processos** `defineProcess(name, { init, tick, abstractTick, contextScope
  })` + `startProcess/stopProcess/stepProcess(name)`:
  - materializada → `tick` (fidelidade alta);
  - abstrata → `abstractTick` (evolução barata — **mundo vivo fora do foco**).
- **Materialização** `MATERIAL_THRESHOLD = 0.5`: `materialize/abstractize`
  (estado preservado) e `materializeForFocus(x, y, outerRadius)` — gradiente:
  dentro do raio interno → 1; dentro do externo → rampa ≥ limiar.
- **Consultas** abertas: `query({ categories, data, contextId, detail, name,
  limit })`, `within(context)`, `neighbors(id, kind, direction)`,
  `componentValue`, `recent(n)`, `eventTypesList()`, `stats()`, `snapshot()`.

### 2.3 Tese dos D (`src/d`)
Camadas funcionais de representação (NÃO dimensões físicas).
`DLayerDef { id, value (fracionário), name, purpose, representation[],
  operational[], fallbackId, critical, cost }`.

- `D-0` identidade (string) · `D-1` semântica (estado compacto) ·
  `D-2` comportamento (processos abstratos) · `D-3` espacial (chunks +
  contexto) · `D-4` detalhe fino (percepção física) · `D-O15` otimização.
- `resolve({ requestedValue, grantedValue })` — clampa em `min..max`, fraciona,
  reporta `downgradedFrom` (a queda é visível, nunca silenciosa).
- **D-MAX**: valor máximo, **reconstruído como dinâmico** (`max()` cresce com
  camadas registradas) porque nenhuma definição existia no repo — marcado em
  `docs/decisions.md` como reconstrução pendente de ratificação.

### 2.4 D-O15 (`src/d-o15`)
Otimização = **mesmo resultado, mais eficiência** (não "reduzir qualidade").

- `HARDWARE_PRESETS` (low-end 4ms · mid 10ms · high-end 25ms · workstation
  60ms de orçamento por tick) + `detectHardware()` (heurística cpus/mem).
- `Profiler` sobre `PerfMeter`: `sample()`, `top()`, `bottleneck()` (só com
  estouro real de orçamento), `pressure()` (fração do orçamento consumida),
  `memoryMB()`.
- `StrategyEngine.decide(specs, pressure)`:
  - `p < 0.5` → **full** (folga);
  - `0.5 ≤ p < 0.9` → escala `1 − ((min(p,0.9)−0.5)/0.4)·0.55` (0.5→1.0,
    0.9→0.45); relevância < 0.5 agrava sistemas não-críticos;
  - `p ≥ 0.9` → não-críticos → `cached` (Hz 0); críticos → piso de 10% no
    minHz (o mundo nunca "morre");
  - representação por granted: `full ≥ 0.85 · coarse ≥ 0.4 · aggregate > 0 ·
    cached`; Hz = `baseHz·(granted/req)` clampa em `[minHz, baseHz]`.
- `AdaptiveScheduler` — ordem por prioridade; orçamento do perfil de hardware;
  mede o trabalho REAL via `PerfMeter`; **adiaga, não descarta**; relata
  `ran / deferred / notDue / usedMs / overBudget`.

### 2.5 Singularity AI (`src/ai`)
Orquestração — **não é chatbot**.

- `MemorySystem` — conversas, curto prazo (ring 256, TTL), longo prazo
  (importância + decaimento), fatos de usuário/projeto/preferências,
  **decisões** (latest-wins por tópico).
- `ModelRegistry` — modelos por **tier** (S++…C) e **capacidades**
  (`planning/code/verification/critique/…`); `select({ capabilities,
  complexity })` escolhe o mais barato suficiente (relaxa tier apenas quando
  necessário). `main()` = melhor tier disponível.
- `ProviderRegistry` — `HeuristicProvider` (local, determinístico, plano por
  tipo de objetivo) e `PuterProvider` (**opcional**, browser-only; no Node,
  `isAvailable()=false` com erro claro). A arquitetura NÃO depende de
  provider único.
- `ToolRegistry` / `AgentRegistry` — ferramentas (world.describe,
  world.invariants, world.spawn-npcs, d-o15.report, d-o15.apply) e agentes
  (world-builder, npc-designer, optimizer, inspector, verifier, orchestrator)
  que executam chamadas REAIS no `WorldAdapter`.
- `SingularityCore.run(goal)`:
  1. `interpretGoal` (PT/EN) → tipo + parâmetros (bioma, N, estruturas, x/y);
  2. modelo arquiteto (S++) **planeja** (decomposição em etapas);
  3. por etapa: agente + modelo escolhidos por capacidade da tarefa;
  4. `verify` (ferramenta) valida no mundo; falha → até **2 tentativas** com
     o erro reinjetado nos args;
  5. memória: conversa, decisões (`result/{goalId}`) e fatos;
  6. `ExecutionReport { status: success|partial|failed, steps, corrections,
     modelsUsed }`.

### 2.6 UES (`src/ues`) — aplicação principal

**World** — mundo 2.5D por chunks com streaming:
- terreno determinístico (`fbm`/`valueNoise` por seed) → altura/moisture;
- biomas por regras de altura+humidade, com **zonas** criadas pela IA
  (prioridade sobre o ruído);
- `SemanticLayer` aberto (7 padrões: terrain/heightfield/biome/slope/
  environment/resources/entities) — novas camadas entram em runtime;
- **streaming**: load (heightfield + contexto + recursos, 1x) / unload
  (entidades abstratizadas, estado preservado) / LRU `maxLoadedChunks` /
  `materializeForFocus`;
- ambiente como entidade RRW com **processos** `env.day-night` e
  `env.weather` (Markov clear→rain→storm→clear, temperatura, vento,
  relâmpagos);
- **fogo**: raio → `weather.lightning` → fogo (processo `fire`: consome,
  propaga, apaga) — cadeia causal completa no RRW;
- `WorldAdapter`: createBiome/buildStructures/spawnNpcs/entityCount/
  checkInvariants/optimizationReport/applyOptimization.

**NMN (NPCs)** — mente natural (sem árvore de diálogo):
- necessidades (fome/energia/segurança/social) evoluem no tempo;
- decisão por **avaliação de utilidade** (urgência da necessidade + contexto +
  memória + relações + custo/risco) — reproduzível por seed;
- percepção limitada (raio) e **dependente de materialização** (D-4);
- memória: episódios (ring) + conhecimento (confiança) + relações
  (trust/debt);
- metas: comer/descansar/trabalhar/trocar/socializar/fugir/explorar;
- **trade com causa**: compra comida cita o evento `npc.hunger` (causalidade
  real, verificável);
- estado vive no componente `Mind` (compress=identidade) → sobrevive à
  abstração.

**Sociedade** — grupos como **agregados semânticos**:
- produção/consumo por ofício (depende de ter comida — feedback);
- `society.famine.warning` com causa `society.stock.low` (cadeia no RRW);
- mercado: preços por oferta/demanda;
- **grupos abstratos evoluem** (`abstractTick`) — mundo vivo fora do foco.

**Gráficos** — camada PRÓPRIA que **interpreta** a realidade:
- `RealLife`: chuva→wetness (especular), vento+seca→poeira, tempestade→glow,
  haze combinado (estado temporal, testado);
- `Frame`: iluminação derivada do dia/noite (não hardcoded), atmosfera,
  materiais, sombras (oclusores + sol), entidades com **LOD 0–3** (agregado/
  distante/médio/próximo);
- backends: `NullBackend` (métricas) e `TextBackend` (ASCII para CLI).
  Vulkan/DirectX/OpenGL/WebGL plugam como `RendererBackend` (arquitetura não
  depende de backend concreto).

**Engine** — o laço:
`SimClock → rrw.time → (a cada 0,5 s: decide D-O15 com pressão medida +
relevância de NPCs materializados) → scheduler (orçamento do HW) → frame`.
Sistemas registrados: `environment` (10Hz, crit), `streaming` (5Hz, crit),
`npc-mind` (5Hz, crit), `society` (1Hz, crit), `graphics` (10Hz, não-crit).
`autoOptimize()` degrada/promove o perfil de hardware pela pressão medida.

## 3. Fluxo de uma decisão (exemplo real)

```
foco move para (2,2)
  → World.stream(): chunks longe → unload → entidades abstractize(detail 0)
      (Heightfield comprimido, Mind/Position preservados)
  → materializeForFocus: só re-materializa no raio (gradiente ≥ limiar)
  → engine.tick():
      profiler: sys:npc-mind cai (só NPCs materializados rodam)
      strategy.decide(pressura menor) → gráficos pode voltar a full
      scheduler executa no orçamento do HW
  → gráficos: frame com LOD 0 para o que está abstrato
  → foco volta → re-materializa → estado íntegro (mesmo dinheiro/memória)
```

## 4. Limitações reais (ver `docs/status.md`)
- Backend GPU real ausente (plug point pronto).
- `HeuristicProvider` é local/determinístico (não é um LLM) — modelos
  externos entram via `ProviderRegistry`.
- D-MAX reconstruído (dinâmico) — pendente de ratificação.
- Sem persistência (save/load) ainda.
