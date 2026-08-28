# UTS — Unified Technology System

> **UTS = PLATAFORMA GERAL · UES = ENGINE dentro da plataforma.**
> Arquitetura para uma representação computacional da realidade.
> RRW representa · a Tese dos D organiza · o D-O15 decide a resolução
> necessária · a Singularity AI (AI-first) opera sobre tudo · a UES cria
> e executa experiências (mundos, jogos, apps) · o renderer apenas manifesta.

Node **22+** · zero dependências de runtime · 100% ESM.

## UTS (plataforma) vs UES (engine) — definição oficial

```
UTS  plataforma geral: infraestrutura, serviços, IA-first, ferramentas.
     O usuário descreve o que quer; a plataforma executa e verifica.
     Serviços: ai · research (triangulação multi-modelo) · github (conectado)
               apps · projects (criações longas duráveis) · storage · events

UES  engine da plataforma: cria, representa, simula e executa EXPERIÊNCIAS
     de qualquer tipo (mundo, jogo, simulação, app) via manifests/rulesets.
     USA a infraestrutura da UTS. UES ⊂ UTS. A UTS é maior.
```

## Chain

```
USER → UTS PLATFORM (AI-first: ask() → Core/Providers/Models/Agents/Tools)
        ↓ objetivo → interpretação → plano → ferramentas validadas → verificação
RRW (fonte da verdade: entidades, relações, eventos causais, processos)
        ↓
TESE DOS D (D-0…D-14, cada camada com efeito observável)
        ↓
D-O15 (pressão medida → estratégia; DEFER, nunca descartar)
        ↓
UES ENGINE (experiência: RealLife, ecologia, economia, NMN, sociedade)
        ↓
FRAME (descrição visual DERIVADA do estado)
        ↓
RendererBackend → Null | Text | **WebGL2 → GPU**
```

Em paralelo, o fluxo cognitivo:
`entidades → índice espacial → percepção → NMN → decisão → ação → evento → causalidade → evolução`.

## Quick start

```bash
npm test              # 185/185 testes determinísticos
npm run demo:cli      # prova ponta-a-ponta no terminal (Core→mundo→frames→causas)
node demos/platform.js # demo da PLATAFORMA (ask, apps, research, projects)
node demos/genesis.js # demo GÊNESIS (física, streaming, sombras, áudio WAV, UTS-DB)
npm run demo          # demo WebGL2 no browser (http://localhost:8080)
npm run bench         # percepção (500→10000 NPCs) + frame extraction
```

## Plataforma em 60 segundos

```js
import { createUTS, createPlatform } from './src/index.js';

const platform = createPlatform();               // UTS: a plataforma
const uts = createUTS({ seed: 'mundo', platform }); // UES roda DENTRO dela

await platform.ask('criar uma pequena vila próxima a um rio chamada Aurora'); // AI-first

const app = await platform.apps.install({ kind: 'tasks', name: 'Roadmap' });  // apps
await platform.apps.act(app.id, 'add', { text: 'dominar a realidade' });

const project = await platform.projects.create('criar uma vila chamada Metrópole'); // criação longa
await platform.projects.run(project.id, { maxSteps: 2 });  // orçamento → retomável depois
```

## Demo browser (WebGL2 real)

`npm run demo` abre um mundo **gerado pela UES** e desenhado na GPU:
terreno do heightfield representado, NPCs com mentes (NMN), clima causal
(chuva→molhado, tempestade→raio→fogo), dia/noite, agregados populacionais,
LOD e pressão D-O15 no HUD. Painel Singularity aceita objetivos em linguagem
natural (`criar uma pequena vila próxima a um rio chamada Vila Aurora`) e
executa o fluxo Core→ferramentas→verificação ao vivo. Botões de save/load
usam a persistência real (checksum+versão).

## Layout

```
src/core/           RNG determinístico, clock, perf, log
src/rrw/            Reality Representation Weave (fonte da verdade)
src/d/              Tese dos D + D-O15
src/spatial/        SpatialGrid (índice derivado)
src/nmn/            Natural Mindset of NPCs
src/world/          terreno, RealLife, sociedade/economia, streaming, World
src/physics/        PhysicsWorld nativa (corpos=props RRW, impactos causais)
src/audio/          synth/spatial/mixer + AudioStream contínuo + devices (playback próprio)
src/ues/            scheduler, frame, orquestrador
src/singularity/    Core, providers, modelos, agentes, tools, memória
src/render/         RHI, culling, materiais, iluminação, shaders, WebGL2 GÊNESIS, Null/Text
src/persistence/    storage + snapshots + UTS-DB (journal/tx) + autosave (gzip/recovery)
src/core/comm.js    Comm (rotas/timeouts/pub-sub entre módulos)
test/               160 testes (node:test, zero deps)
bench/              percepção (brute vs grid) + frame
demos/              CLI + browser (WebGL2) + GÊNESIS
docs/canonical/     arquitetura, decisões (ADR-013..018), status honesto
```

## Exemplo mínimo

```js
import { createUTS, NullRenderer } from './src/index.js';

const uts = createUTS({ seed: 'meu-mundo' });
const report = await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Aurora');
console.log(report.ok, report.verifications);       // verificado, não inventado

uts.ues.run(600);                                   // o mundo vive: clima, fome, comércio…
const frame = uts.ues.renderFrame();                // REPRESENTAÇÃO → descrição visual
new NullRenderer().render(frame);                   // …ou WebGL2 no browser

const chain = uts.rrw.causalityChain(algumEventoId); // causalidade audível
```

## Status honesto

Veja [`docs/canonical/status.md`](docs/canonical/status.md) — nada é
declarado funcional sem teste que prove. Funcional hoje: RRW causal,
Tese dos D operacional, D-O15 adaptativo, percepção indexada (158× @10k
NPCs), NMN, sociedade/economia, RealLife, Frames, WebGL2 v1, persistência
determinística, Singularity Core com fallback. Planejado: sombras reais,
instancing, áudio sintetizado, DatabaseStorage.

## Especificação

A visão canônica completa do projeto está em `UTS.txt` (raiz, branch main).
