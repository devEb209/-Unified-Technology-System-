# UTS — Unified Technology System

> **Arquitetura para uma representação computacional da realidade.**
> RRW representa · a Tese dos D organiza · o D-O15 decide a resolução
> necessária · a Singularity AI opera sobre tudo · a UES executa mundos ·
> o renderer apenas manifesta.

Node **22+** · zero dependências de runtime · 100% ESM.

## Chain

```
USER → SINGULARITY AI (Core/Providers/Models/Agents/Tools/Memory)
        ↓ objetivo → interpretação → plano → ferramentas validadas
RRW (fonte da verdade: entidades, relações, eventos causais, processos)
        ↓
TESE DOS D (D-0…D-14, cada camada com efeito observável)
        ↓
D-O15 (pressão medida → estratégia; DEFER, nunca descartar)
        ↓
UES (mundo vivo: RealLife, ecologia, economia, NMN, sociedade)
        ↓
FRAME (descrição visual DERIVADA do estado)
        ↓
RendererBackend → Null | Text | **WebGL2 → GPU**
```

Em paralelo, o fluxo cognitivo:
`entidades → índice espacial → percepção → NMN → decisão → ação → evento → causalidade → evolução`.

## Quick start

```bash
npm test            # 115/115 testes determinísticos
npm run demo:cli    # prova ponta-a-ponta no terminal (Core→mundo→frames→causas)
npm run demo        # demo WebGL2 no browser (http://localhost:8080)
npm run bench       # percepção (500→10000 NPCs) + frame extraction
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
src/world/          terreno, RealLife, sociedade/economia, World
src/ues/            scheduler, frame, orquestrador
src/singularity/    Core, providers, modelos, agentes, tools, memória
src/render/         backends Null/Text/WebGL2 (+shaders/mesh/mat)
src/persistence/    storage (Memory/File) + snapshots versionados
test/               115 testes (node:test, zero deps)
bench/              percepção (brute vs grid) + frame
demos/              CLI + browser (WebGL2)
docs/canonical/     arquitetura, decisões (ADR), status honesto
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
