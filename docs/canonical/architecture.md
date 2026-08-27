# Arquitetura Canônica (vigente)

Hierarquia com inversão de dependência entre IA e mundo:

```
UTS (arquitetura maior — realidade computacional)
├─ RRW ──────────── representação aberta (dados + processos + causalidade)
├─ Tese dos D ───── camadas funcionais de representação (D-0…D-4, D-O15, D-MAX*)
├─ D-O15 ─────────── otimização inteligente (mede→analisa→decide→adapta)
├─ Singularity AI ── orquestração (Core + registries + memória)
└─ UES ───────────── aplicação principal (engine de mundos)
     ├─ World (chunks, streaming, camadas, ambiente, fogo)
     ├─ NMN (mentes de NPCs)
     ├─ Sociedade (grupos, economia, famine)
     ├─ Gráficos (Real Life, frame, LOD, RendererBackend)
     └─ Engine (relógio + scheduler + bridge IA + persistência)

* D-MAX: provisório (não ratificado) — ver provisional.md
```

## Inversão de dependência (contrato)

`src/contracts.ts` define `WorldAdapter`: `createWorld/worldExists/
createBiome/buildStructures/spawnNpcs/entityCount/npcCount/describe/
checkInvariants/optimizationReport/applyOptimization`.

- A **IA depende do contrato** (`WorldAdapter`).
- O **mundo não depende da IA**.
- A UES implementa o contrato. Outro mundo pode se plugar na IA sem
  alterar o core (testado: provider externo + cenário completo).

## Fluxo do Engine (laço de integração)

```
SimClock.tick(dt=0.1s)
  → rrw.time = clock.time
  → a cada 0.5 s de sim:
       pressão = Profiler.pressure(orçamento do hardware)   [medição real]
       relevância = fração de NPCs materializados no foco
       StrategyEngine.decide(specs, pressão)                [decisão]
       applyAdaptiveRadius()                                [materialização/abstração]
       profiler.clear()                                     [nova janela]
  → AdaptiveScheduler.step(time, ctx)                       [agenda dentro do orçamento]
       environment(10Hz,crit) → streaming(5Hz,crit) →
       npc-mind(5Hz,crit) → society(1Hz,crit) → graphics(10Hz,não-crit)
  → frame interpretado (último do tick, se graphics rodou)
```

Sistemas rodam trabalho REAL medido por `PerfMeter` (nada de custo estimado).
Adaptação = **adiar** (nunca descartar) + reduzir detalhe/raio; piso para
críticos (o mundo nunca "morre").

## Persistência (implementada nesta etapa)

`src/ues/persistence.ts`:

- `serializeUes(engine, memory?)` → objeto JSON-safe do estado completo:
  - RRW (entidades + componentes + snapshots comprimidos, relações, eventos
    globais e por entidade → **causalidade**, processos → alvos e estados,
    contadores);
  - mundo (chunks com heightfield, foco, raio de materialização, zonas);
  - relógio, **RNG (estado exato)**, hardware;
  - sociedade (cooldowns), agendamento D-O15 (nextDue/hz), ciclo de decisão;
  - memória da IA (opcional).
- `restoreUes(cfg, snap, memory?)` reconstrói um Engine e evolui
  **idêntico** ao original (teste de determinismo).
- `saveUes/restoreFromJson` — conveniência de string.
- `normalizeUes/canonicalJson` — comparação entre runs independentes
  (IDs únicos por runtime → mapeados por ordem de inserção).

Determinismo: mesma seed + mesma sequência → mesma realidade (teste com
IDs normalizados); seed diferente → realidade diferente (teste).
