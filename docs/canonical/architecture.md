# UTS — Canonical Architecture

> **UTS — Unified Technology System** é uma arquitetura para construir uma
> **representação computacional da realidade**. Jogos são uma aplicação
> (a UES), não o objetivo máximo. Este documento descreve a arquitetura
> **como ela está implementada neste repositório** — sem declarar como
> funcional aquilo que não é.

## 0. DEFINIÇÃO OFICIAL: UTS ≠ UES

```
UTS  = PLATAFORMA GERAL (a antiga SNB)
       ambiente maior: infraestrutura, sistemas, serviços, IA, ferramentas,
       recursos e tecnologias para criação e execução. Filosofia AI-first:
       o usuário descreve o que quer e usa arquivos/serviços/fontes como
       entrada. Plataforma geral — nunca especializada num tipo de app.

UES  = ENGINE DA UTS (Unified Engine System)
       um dos principais sistemas da plataforma: cria, representa, simula
       e executa experiências e mundos. Engine GERAL (qualquer gênero de
       experiência). USA a infraestrutura fornecida pela UTS.

Relação:  UTS → fornece a plataforma e sua infraestrutura
          UES → utiliza essa infraestrutura para funcionar como engine
          UES ⊂ UTS — a UES faz parte, mas a UTS é MAIOR.

Estado:   UTS parcial + infraestrutura necessária FUNCIONAL → UES plena.
          Nem tudo da UTS precisa existir para a UES funcionar; o que a UES
          precisa da UTS deve estar funcional (hoje: está — 128 testes).
```

Implementação: `src/platform/` é a PLATAFORMA (ServiceRegistry, AI-first,
Research triangulado, GitHub conectado, AppHost, CreationProjects, storage).
`src/ues/` é a ENGINE (mundo, NMN, frames, scheduler, experiências) —
registrada na plataforma como serviço-consumidor `ues`, nunca o contrário.

## 1. A cadeia canônica

```
UTS  (arquitetura: representação da realidade)
 │
 ├── RRW ................ representação aberta, multinível, causal (fonte da verdade)
 ├── TESE DOS D ......... camadas funcionais D-0..D-14 (+D-O15) com efeito observável
 ├── D-O15 .............. otimização: pressão medida → estratégia; defer, nunca descartar
 ├── SINGULARITY AI ..... Core + Providers + Models + Agents + Tools + Memory
 └── UES ................ execução: mundo, NMN, sociedade, economia, RealLife
      │
      └── FRAME ......... descrição visual DERIVADA do estado representado
           │
           └── RendererBackend (Null | Text | WebGL2) → GPU → imagem
```

Princípios invariantes:

1. **REPRESENTAÇÃO ≠ RENDERIZAÇÃO.** RRW representa; UES executa/orquestra;
   D-O15 decide a resolução necessária; o renderer **manifesta**. O renderer
   nunca inventa estado.
2. **RRW é a fonte da verdade.** Índices (SpatialGrid, buffers GPU, cache de
   terreno) são derivados e reconstruíveis a partir do RRW sozinho.
3. **Causalidade verificável por construção.** Um evento só pode citar como
   causa um evento que EXISTE (`emitEvent` lança `CausalityError` caso
   contrário). Cadeias sobrevivem a abstração, materialização e persistência.
4. **Abstração nunca destrói estado** (D-14): `abstract → materialize`
   preserva identidade, memória, relações, posição e recursos.
5. **D não são dimensões físicas.** São camadas funcionais; cada uma precisa
   demonstrar efeito observável (`tese.touch()`), ou é removida.
6. **D-O15 não é "reduzir qualidade".** É obter o resultado necessário pela
   representação mais eficiente: medir → decidir → DEFER (nunca descartar).

## 2. Mapa de módulos

| Módulo | Responsabilidade |
|---|---|
| `src/core/` | RNG determinístico (xoshiro128**), Clock, PerfMeter, Logger, EventBus, math |
| `src/rrw/` | Registro de entidades, componentes, relações, eventos causais, processos, materialização, snapshots |
| `src/d/` | `tese.js` (camadas D + trilha de efeitos), `do15.js` (pressão → estratégia, defer queue) |
| `src/spatial/` | SpatialGrid (grid uniforme derivado; permute quadtree/kd depois) |
| `src/nmn/` | Mentes NPC: necessidades, percepção, decisão com explicações, memória, gossip |
| `src/world/` | Terreno (heightfield/biomas), RealLife (clima causal), sociedade/economia, World |
| `src/ues/` | Scheduler com orçamento, extração de Frame, orquestrador UES, **experiências (manifests/rulesets)** |
| `src/singularity/` | ProviderRegistry, Heuristic/Puter/ExternalLLM providers, ModelRegistry (tiers), AgentRegistry, ToolRegistry, MemorySystem, SingularityCore, platform-tools |
| `src/render/` | **GÊNESIS**: `rhi.js` (RHI: recursos GPU rastreados/sized, ProgramCache, contrato de device), `culling.js` (frustum Gribb-Hartman + esferas), `materials.js` (MaterialLibrary), `lighting.js` (sol + point lights), `shaders.js` (GLSL próprio), `webgl2.js` (pipeline GÊNESIS), Null e Text |
| `src/physics/` | **GÊNESIS** `physics.js`: PhysicsWorld própria (corpos=props RRW, impactos causais, sleep, raycast corpo+terreno, broadphase em células) |
| `src/audio/` | **GÊNESIS COMPLETO**: `synth.js` (osciladores/ruído/env/lowpass), `spatial.js` (atenuação+pan), `mixer.js`, `stream.js` (AudioStream: timeline contínua, vozes agendadas, ambience sem emendas, snapshot/restore), `backends.js` (contrato AudioDevice: Memory/NodePacer/WebAudio + resampler próprio), `uts-audio.js` (AudioDirector + encodeWav RIFF 16-bit) |
| `src/persistence/` | StorageBackend (Memory/File), snapshots versionados com checksum+migração; **`utsdb.js`**: UTS-DB (journal append-only, replay tolerante a torn-tail, tx, índices, compaction, asStorage) |
| `src/core/comm.js` | **GÊNESIS** Comm: rotas nomeadas, requests com timeout, pub/sub entre módulos (sem API keys) |
| `src/world/streaming.js` | **GÊNESIS** StreamingSystem: residência de patches por anel de LOD (24/16/8), eviction, orçamento de tempo (budgetMs) |
| `src/platform/` | **A PLATAFORMA**: ServiceRegistry, AIService (AI-first), ResearchService (triangulação multi-modelo), GitHubService (serviço conectado), AppHost (apps), CreationProjectManager (projetos duráveis), UTSPlatform |

## 2b. Serviços da PLATAFORMA (o que a UES e os apps consomem)

| Serviço | Papel |
|---|---|
| `ai` | Acesso AI-first: linguagem natural → interpretação → plano → ferramentas validadas → verificação. Agrega todos os providers (incl. modelos via Puter) |
| `research` | Validação de conhecimento por **triangulação**: N modelos (meta ≥3) sobre resultados de busca; consenso, acordo, conflitos; honesto quando não triangula |
| `github` | Serviço conectado (REST): ler/escrever arquivos, inspecionar repositórios — token só via env, mascarado sempre |
| `apps` | **Aplicações são cidadãs de primeira classe** (nem tudo é mundo): kinds abertos (setup/reduce/view), estado durável em storage, sobrevive a restarts |
| `projects` | **CreationProjects**: objetivos grandes (horas/dias/semanas) viram planos duráveis, executáveis por orçamento e retomáveis em qualquer sessão |
| `storage` | KV durável (Memory/File hoje; Database/Cloud depois) |
| `events` | Pub/sub da plataforma |
| `ues` | A ENGINE registrada como consumidora — UES ⊂ UTS |

## 3. Fluxo de dados por tick

```
Clock.advance(dt)
 → weather      (RealLife: máquina de estados causal; chuva→molhado,
                 vento+seco→poeira, tempestade→raio→fogo→perigo)
 → ecology      (D-9: regrowth de recursos)
 → economy      (processos RRW das settlements + trabalho individual detalhado)
 → trade        (a cada 50 ticks: excedente → déficit, com evento)
 → nmn          (mentes por tier: full=1 tick, partial=4, abstract=agregado)
 → physics      (GÊNESIS: passos do solver; D-O15 coarse pula ticks ímpares)
 → movement     (integração de intents + sincronização do grid)
 → materializer (D-O15: raio+importância → full/partial/abstract;
                 settlements ↔ indivíduos com preservação de estado)
 → streaming    (GÊNESIS: residência de patches por anel de LOD, budgetMs)
 → deferred     (D-O15 executa trabalho adiado quando há orçamento)
```

## 4. Percepção indexada (Fronteira 2)

```
NPC → SpatialGrid.queryCircle(célula + vizinhas)   [candidatos O(k), k≪n]
    → filtro distância/FOV                         [geometria]
    → prioridade por importância                   [fenômenos (fogo) NUNCA cortados]
    → cap por resolução (full 12 / reduced 6 / coarse 3)
    → decisão (utilidade com razões) → ação → evento causal
```

O NMN não conhece a estrutura espacial: pede `world.perceive(pos, model)`.
Medição real (host do CI, semente fixa):

| n NPCs | brute force ms/tick | grid ms/tick | speedup | cand/consulta |
|---:|---:|---:|---:|---:|
| 500 | 12.99 | 3.33 | 3.9× | 8.3 |
| 2000 | 321.86 | 12.37 | 26× | 8.7 |
| 5000 | 2115.96 | 29.91 | 70.8× | 8.8 |
| 10000 | 9741.71 | 61.65 | 158× | 8.8 |

## 5. Cadeia causal canônica (exemplo real testado)

```
reallife.weather.changed → reallife.lightning.strike → reallife.fire.started
   → npc.hazard.sighted → decisão flee (com `because`) → npc.fled
```

`rrw.verifyCausalChain(id)` valida toda a cadeia; `causalityChain(id)`
retorna a sequência completa para auditoria/explicação.

## 6. Persistência determinística

```
save:   validate → checksum (fnv1a) → StorageBackend
load:   parse → checksum → migrate (schemaVersion) → restore → validate (RRW)
```

* RNG faz parte do estado: save→load→N ticks == N ticks contínuos (testado).
* Snapshot novo demais → erro explícito (nunca inicia realidade vazia em silêncio).
* Pressão/métricas do D-O15 são evidência de runtime e NÃO entram no snapshot;
  estratégia e orçamento entram. Modo `pinned` garante replay bit-a-bit.
* Segredos de providers nunca entram em snapshots (providers se mascaram;
  o Core persiste apenas NOMES).

## 7. Regras de dependência (inversão preservada)

**Nativo primeiro (ADR-018):** todo sistema nasce da pergunta "como isso
funciona nativamente na UTS/UES?"; dependência externa só quando inevitável
e sempre atrás de interface própria (RHI → WebGL2 do browser; providers →
Puter/LLM API; StorageBackend → FileStorage do OS). Wrapper que controla
tudo não passa na revisão.

```
RRW      não conhece Renderer, NMN nem SpatialGrid
NMN      não conhece SpatialGrid (usa world.perceive)
UES      orquestra (scheduler, materializer, frames)
D-O15    decide/adapta com base em medição
Renderer consome Frame (nunca o contrário)
Core     nunca depende de um vendor/modelo (registry + fallback)
```

## 8. Extensibilidade aberta

* **RRW**: novos domínios/kinds sem reescrever o núcleo (`createEntity` é
  genérico; componentes são dados).
* **Tese dos D**: `tese.define({id:'D-16',...})` registra novas camadas.
* **Processos**: `rrw.registerProcessType(kind, {evolveAbstract, evolveDetailed})`.
* **Providers**: qualquer backend OpenAI-compatível; Puter é apenas um deles.
* **Renderers**: qualquer backend que implemente `init/render/destroy`.
* **RealLife**: regras de fenômenos são um conjunto aberto (chuva/vento/poeira/
  tempestade são exemplos, não limite).
