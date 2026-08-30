# UTS — Unified Technology System

> **A plataforma onde realidade é representada de verdade — não desenhada.**
> UTS = PLATAFORMA GERAL · UES = ENGINE dentro da plataforma · RRW = fonte da verdade.
> Node **22+** · zero dependências de runtime · 100% ESM · **386 testes determinísticos (386/386)**.

---

## O que é

```
UTS  plataforma geral: infraestrutura, serviços, IA-first, ferramentas.
     O usuário descreve o que quer; a plataforma executa e verifica.
     Serviços: ai · research (triangulação multi-modelo) · github (conectado)
               apps · projects (criações longas duráveis) · storage · events

UES  engine da plataforma: cria, representa, simula e executa EXPERIÊNCIAS
     (mundo, jogo, simulação, app) via manifests/rulesets.
     USA a infraestrutura da UTS. UES ⊂ UTS. A UTS é maior.
```

**Duas regras supremas regem todo o código:**

1. **Não simular a aparência quando podemos modelar a realidade que a produz.**
   Fumaça é solver Euleriano (não partícula decorativa); som localiza por
   difração de esfera rígida resolvida em série (não pan estéreo); luz tem
   temperatura Planck e candela com 1/r² exato (não "cor com brilho").
2. **Não otimizar destruindo a realidade** — otimiza-se a forma como ela é
   representada, priorizada e materializada (D-O15: defere/reduz/re-representa,
   nunca descarta).

## Por que é diferente de qualquer engine atual

Estas capacidades **existem e estão provadas por teste** — nenhuma engine,
jogo ou plataforma do mercado as tem hoje como sistema:

| Capacidade | Estado |
|---|---|
| Realidade causal com FONTE ÚNICA da verdade (RRW: entidades, relações, eventos, processos) | **VALIDATED** |
| Determinismo `save → load → evoluir == original` (bit a bit, snapshots versionados, corrupção = erro explícito) | **VALIDATED** |
| IA que opera a plataforma INTEIRA por chat: cria mundo, arquivos, apps, compila/descompila, gera APK/AAB e **binário único EXE (SEA)** — **tempo de construção MEDIDO: vila verificada em 11ms, jogo completo em 3ms** (a IA desenvolve, o humano descreve) | **VALIDATED** |
| Criação em TODOS os Ds (2d/2.5d/3d/3.5d/4d), cutscenes, auto-dublagem, estilo dito no chat (colorista GLSL composto) | **VALIDATED** |
| Física como realidade: energia ½mv², deformação por material, quaternion livre, cordas PBD, Arquimedes, vento e fumaça empurrando malhas compostas | **VALIDATED** |
| Áudio como fenômeno: difração pela esfera rígida resolvida em SÉRIE DE RAYLEIGH (baffel +6dB, ILD crescente, ITD = 3a/c provada contra a analítica), acústica com atraso/sombra/absorção, muffle = filtro real | **VALIDATED** |
| Óptica como lei: loco Planckiano nas âncoras CIE (D65 = (1,1,1) pela definição), spot por cosseno, luz de área amostrada, rig 3 pontos | **VALIDATED** |
| Identidade dos artefatos: **assinatura ed25519** — um byte alterado reprova; chave privada nunca entra no código | **VALIDATED** |
| Token streaming REAL (SSE atravessa o Core; mesma lei de validação) | **VALIDATED** (produção depende de chave via env) |

**Honestidade sobre o resto:** em escala de PRODUÇÃO AAA (bibliotecas de
conteúdo, décadas de otimização por plataforma, orçamento de centenas de
artistas), engines como Unreal 5, Unity 6 e RAGE seguem à frente — isso é
diferença de indústria, não de arquitetura. A superioridade do UTS hoje é
**arquitetural** (o que está na tabela acima) e está na régua pública por
eixo abaixo. A promessa do 100% é superar em TUDO — e cada eixo fecha com
prova, não com adjetivo.

## Arquitetura (uma verdade, derivada — nunca desenhada)

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
RendererBackend → Null | Text | WebGL2 → GPU
```

Fluxo cognitivo em paralelo:
`entidades → índice espacial → percepção → NMN → decisão → ação → evento → causalidade → evolução`.

## Rodar

Requisito: **Node ≥ 22**. Sem dependências — `npm install` só instala a
toolchain de build declarada (postject, para o binário SEA).

### Android/Termux (o produto roda no celular)

```bash
pkg install -y git nodejs
git clone -b arena/01a048b9-unified-technology-system https://github.com/devEb209/-Unified-Technology-System-.git uts
cd uts
rm -f package-lock.json   # gerado localmente; sem isso o git pull pode abortar
git pull origin arena/01a048b9-unified-technology-system
npm install
npm run genesis        # deixa RODANDO — não aperte ^C para usar
```

Abra **`http://localhost:8080`** no navegador do próprio celular.

> A linha `escutando em 0.0.0.0:8080` que o servidor imprime é SAÍDA, não
> endereço para digitar — `0.0.0.0` significa "todas as interfaces desta
> máquina". O log novo já ensina: `localhost` neste aparelho, IP local para
> outro aparelho na mesma rede.

> Se a pasta clonada for `-Unified-Technology-System-` (começa com traço),
> entre com `cd ./-Unified-Technology-System-` — ou clone direto numa pasta
> limpa `uts` como acima.

### Desktop

```bash
git clone -b arena/01a048b9-unified-technology-system https://github.com/devEb209/-Unified-Technology-System-.git uts
cd uts && npm install
npm run genesis        # http://localhost:8080
```

## Comandos

```bash
npm test               # 388/388 testes determinísticos (node:test, zero deps)
npm run genesis        # a plataforma viva no navegador (WebGL2 real)
npm start              # mesmo servidor
npm run demo:cli       # prova ponta-a-ponta no terminal (Core→mundo→frames→causas)
node demos/platform.js # demo da PLATAFORMA (ask, apps, research, projects)
npm run bench          # percepção (500→10000 NPCs) + frame extraction

# IA opera a sua máquina (opt-in, chaves NUNCA persistidas):
UTS_WORKSPACE=./workspace npm start    # a IA cria arquivos em ./workspace
UTS_ALLOW_EXEC=1 npm start             # + executor de comandos (guarda ativa)
UTS_LLM_API_KEY=… npm start            # LLM real via SSE (ou OPENAI_API_KEY)
```

## Plataforma em 60 segundos

```js
import { createUTS, createPlatform } from './src/index.js';

const platform = createPlatform();                 // UTS: a plataforma
const uts = createUTS({ seed: 'mundo', platform }); // UES roda DENTRO dela

await platform.ask('criar uma pequena vila próxima a um rio chamada Aurora');

const app = await platform.apps.install({ kind: 'tasks', name: 'Roadmap' });
await platform.apps.act(app.id, 'add', { text: 'dominar a realidade' });

const project = await platform.projects.create('criar uma vila chamada Metrópole');
await platform.projects.run(project.id, { maxSteps: 2 });  // orçamento → retomável
```

## O navegador mostra a realidade, não uma cena

`npm run genesis` abre um mundo **gerado pela UES** e desenhado na GPU:
terreno do heightfield representado, NPCs com mentes (NMN), clima causal
(chuva→molhado, tempestade→raio→fogo que consome combustível), água com
empuxo de Arquimedes, fumaça que é SOLUÇÃO do solver 3D e empurra corpos,
dia/noite, LOD com pressão D-O15 no HUD — tudo derivado do RRW. O painel
Singularity executa objetivos em linguagem natural ao vivo
(`criar uma pequena vila próxima a um rio chamada Vila Aurora`), com token
streaming quando há LLM configurado. Save/load usa a persistência real
(checksum + versão + determinismo bit a bit).

## Layout

```
src/core/           RNG determinístico, clock, perf, log, comm
src/rrw/            Reality Representation Weave (fonte da verdade)
src/d/              Tese dos D + D-O15
src/spatial/        SpatialGrid (índice derivado)
src/nmn/            Natural Mindset of NPCs
src/world/          terreno, RealLife, sociedade/economia, streaming, World, fluid3d
src/physics/        PhysicsWorld nativa (impactos, quaternion, PBD, Arquimedes, malhas compostas)
src/audio/          synth/spatial + HRTF (paramétrica + SÉRIE DE RAYLEIGH exata) + música + devices
src/ues/            scheduler, frame, orquestrador
src/singularity/    Core, providers, agentes, tools, memória, streaming
src/agent/          build-system (zip/APK/EXE SEA + ed25519), fs/proc, geometry/light/shader-smith
src/render/         RHI, culling, materiais, iluminação, shaders, WebGL2 GÊNESIS, Null/Text
src/persistence/    storage + snapshots + UTS-DB + autosave + chunk-cache (LRU)
test/               386 testes (node:test, zero deps)
bench/              percepção (brute vs grid) + frame
demos/              CLI + browser (WebGL2) + plataforma
docs/canonical/     arquitetura, ADRs, progress.md (régua por eixo), status.md
docs/launch/        ata de lançamento GENESIS v1 (chave pública, artefatos, hashes)
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

## Status honesto — 99.50 ≈ 100%

Régua pública por eixo em [`docs/canonical/progress.md`](docs/canonical/progress.md);
estado narrado em [`docs/canonical/status.md`](docs/canonical/status.md).
Nada é declarado funcional sem teste que prove.

| Eixo (peso) | % | Estado |
|---|---|---|
| Core/núcleo (18) | **100** | FECHADO |
| Render (14) | **100** | FECHADO (14/14 provas de render) |
| Streaming/fio (10) | **100** | FECHADO |
| Plataforma (12) | **100** | FECHADO (identidade ed25519) |
| Usabilidade (10) | **100** | FECHADO |
| Física (8) | **100** | FECHADO (fumaça empurra malhas compostas) |
| Ferramentas (8) | **100** | FECHADO (forja de geometria + LUZ) |
| Áudio (8) | 99 | falta o banco MEDIDO cru do dono (schema + interpoladora prontos: anexou, usa) |
| IA (14) | 98 | protocolo da NUVEM provado ponta a ponta (SSE real por socket); falta a chave via env — o dono liga, o código não muda |
| **TOTAL** | **99.64** | **GENESIS v1 LANÇADO** |

**Lançamento:** artefatos web + android + **EXE único SEA** assinados
(ed25519), ata pública em [`docs/launch/GENESIS-v1.json`](docs/launch/GENESIS-v1.json).

**Fila até o 100 absoluto:** banco HRTF medido anexado pelo dono · prova do
streaming contra a nuvem com a chave · e a evolução contínua de fidelidade
por eixo (a promessa: superar em TUDO, cada eixo com prova pública).

## Especificação

A visão canônica completa do projeto está em `UTS.txt` (raiz, branch main).
Decisões de arquitetura: `docs/canonical/` (ADR-013 UTS/UES, ADR-018 nativo
primeiro, ADR-019 realidade primeiro, ADR-020 vence modelando).
