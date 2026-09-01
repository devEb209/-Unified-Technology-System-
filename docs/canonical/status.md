# UTS — Status Real (auditoria honesta)

> Convenção: **FUNCTIONAL** (interface + implementação + integração + teste +
> uso real) · **PARTIAL** (existe, incompleto) · **PLANNED** (definido, não
> implementado). Nada aqui declara funcionalidade sem teste que a prove.

## Estado geral

- **200/200 testes** passando (`npm test`), determinísticos, zero dependências
  de runtime (132 pré-Gênesis + 28 novos dos sistemas nativos).
- **GÊNESIS (ADR-018)**: renderer/RHI/culling/materiais/iluminação/shadow
  mapping/instancing/streaming/física/áudio/UTS-DB/Comm — todos nativos, do
  zero, com testes próprios (`test/genesis-*.test.js`).
- **Painel de progresso até o GÊNESIS completo: `progress.md` (89%)**
- **UTS = PLATAFORMA funcional** (AI-first, serviços, apps, research, github,
  projetos duráveis, comm) · **UES = ENGINE funcional** dentro dela (mundos
  vivos, frames, pipeline WebGL2 GÊNESIS, experiências por manifesto).
- Cadeia completa: objetivo → plataforma AI → RRW → mundo vivo → física +
  streaming + D-O15 → Frame → **WebGL2 GÊNESIS real** (browser, sombras e
  instancing) / Null / Text → **áudio sintetizado** (WAV).

## Sistemas

| Sistema | Status | Evidência |
|---|---|---|
| **PLATAFORMA UTS** (ServiceRegistry, status/health) | **FUNCTIONAL** | `test/platform.test.js` |
| **AI-first** (`platform.ask`, AIService) | **FUNCTIONAL** | linguagem natural → realidade verificada |
| **Research triangulado** (N modelos + busca + consenso) | **FUNCTIONAL\*** | *\*validado com providers injetados; busca real plugar provider HTTP* |
| **GitHub conectado** (REST, token mascarado) | **FUNCTIONAL\*** | *\*fetch mock no teste; produção via `GITHUB_TOKEN` env* |
| **Apps da plataforma** (AppHost, kinds abertos, estado durável) | **FUNCTIONAL** | install/act/view + restart mantém estado |
| **CreationProjects** (planos duráveis, orçamento, retomável) | **FUNCTIONAL** | retomada cross-session testada; falhas duráveis |
| **UES como engine geral** (manifests, rulesets=genres) | **FUNCTIONAL** | `test/experience.test.js` |
| RRW (entidades, componentes, relações) | **FUNCTIONAL** | `test/rrw.test.js` |
| Causalidade verificável | **FUNCTIONAL** | cadeia raio→fogo→medo testada ponta a ponta |
| Processos RRW (abstrato/detalhado) | **FUNCTIONAL** | settlement-life evolui abstrato; restauração exige implementação registrada |
| Materialização multinível (D-14) | **FUNCTIONAL** | roundtrip abstrato↔individual preserva população/mente/relações |
| Tese dos D (16 camadas com efeito) | **FUNCTIONAL** | toggle D-9/D-13 muda a realidade; trilha `touch()` auditada |
| D-O15 (pressão→estratégia, defer-not-discard) | **FUNCTIONAL** | hysteresis testada; fila de defer executa quando há orçamento |
| Spatial Grid + percepção indexada | **FUNCTIONAL** | equivalente à força bruta; 158× @10k NPCs (`bench/perception.bench.js`) |
| NMN (necessidades, decisões explicáveis, memória, gossip) | **FUNCTIONAL** | `test/nmn.test.js` |
| Sociedade/economia (agregados, fome, nascimento, comércio) | **FUNCTIONAL** | `test/society_economy.test.js` |
| RealLife (clima causal, fogo, dia/noite) | **FUNCTIONAL** | cadeias de eventos verificadas |
| Frame extraction (LOD, agregados, áudio, física, lights) | **FUNCTIONAL** | <1ms; derivado do estado (testado) |
| Renderer Null/Text | **FUNCTIONAL** | contam/manifestam o Frame exato |
| **RHI — abstração gráfica própria** (recursos rastreados/sized, ProgramCache, contrato de device) | **FUNCTIONAL** | `test/genesis-render.test.js`; destroy libera 100% dos recursos |
| **Culling próprio** (frustum Gribb-Hartman + esferas + distância) | **FUNCTIONAL** | math exato testado; alimenta draw calls (113 no demo Gênesis) |
| **Materiais + Iluminação nativas** (MaterialLibrary, sol+point lights D-O15-aware) | **FUNCTIONAL** | pressão reduz lights 4→2 com evidência no teste |
| **Shadow mapping próprio** (depth pass + PCF 3×3, FBO 1024) | **FUNCTIONAL** | pipeline GL mockado; fallback honesto sem FBO |
| **Instancing próprio** (12 floats/instância, batches por material) | **FUNCTIONAL** | path instanciado + fallback por-entidade testados |
| **Streaming + LOD geométrico COMPLETO** (residência 24/16/8, histerese anti-flicker, skirts anti-fenda, impostores, budgetMs) | **FUNCTIONAL** | skirts provam-se > fenda T-junction medida; histerese: ≤2 mudanças sob jitter na fronteira; impostores 6 vértices/bioma dominante; limiar 150/120/90 u por D-O15 (auditável); determinismo preservado |
| **Física nativa** (corpos=props RRW, impactos causais, **rotação com inércia/torque**, **juntas de distância como relações RRW (PBD)**, pinned, sleep angular, raycast, broadphase) | **FUNCTIONAL** | spin por contato tangencial (determinístico); corrente pendurada: erro máx 0.0097u em 240 passos; **física sobrevive a save/load** (reattach do RRW, A==B após restore+60 passos) |
| **Binaural nativo** (ITD 0.65ms + ILD head-shadow) | **FUNCTIONAL** | orelha próxima ouve ANTES (atraso fracionário próprio); orelha sombreada mais baixa E mais escura (zcr medido); fogo no stream é estéreo posicional |
| **Música procedural adaptativa** (modos por tensão, beat grid absoluto, 4 camadas) | **FUNCTIONAL** | mesma evolução de mundo = mesmas notas (determinismo); tempestade+fogo → modo tenso, mais camadas, bpm ↑; mudanças só em fronteira de compasso; orçamento D-O15 corta camadas |
| **Áudio nativo COMPLETO** (synth/spatial/mixer/AudioDirector + AudioStream contínuo + devices) | **FUNCTIONAL** | stream sem emendas (pior |Δ|=0.011); playback real no browser (botão 🔊 do demo) + WAV; trovão com lockout temporal; fogo espacial em loop; SR/vozes (22050/16000/11025 · 8/5/3) governadas por D-O15 com mudanças medidas |
| **UTS-DB** (journal append-only, replay, tx, índices, compaction, torn-tail) | **FUNCTIONAL** | `test/genesis-db-comm.test.js`; corrupção no meio falha alto |
| **Comm** (rotas, timeouts, pub/sub entre módulos) | **FUNCTIONAL** | rotas ask/research.validate/system.status na plataforma |
| **Renderer WebGL2 GÊNESIS** | **FUNCTIONAL** | shaders GLSL próprios, shadow PCF, instancing, culling, 4 point lights, chuva em GL_POINTS; GL mock (Node) + demo browser |
| Singularity Core (interpretar→planejar→executar→verificar→corrigir) | **FUNCTIONAL** | fluxo completo com HeuristicProvider; fallback de provider testado |
| ModelRegistry (tiers, custo, seleção mínima suficiente) | **FUNCTIONAL** | seleção por capacidade/custo testada |
| ExternalLLMProvider (OpenAI-compatível, generate/stream) | **FUNCTIONAL\*** | *\*validado contra fetch mock; contra API real requer `OPENAI_API_KEY` — nunca commitado* |
| PuterProvider (browser, access-layer) | **FUNCTIONAL\*** | *\*detectado/validado via globalRef injetado; requer browser com Puter* |
| Persistence (save/load, checksum, versão, migração, File/Memory) | **FUNCTIONAL** | corrupção falha alto; A==B após restore+ticks |
| **Cache LRU de terreno persistido** (UTS-DB, flush atômico em tx) | **FUNCTIONAL** | byte-exato vs amostragem fresca (prova de pureza); 2a passada = hits sem resample; sobrevive a restart (journal); LRU sob orçamento de bytes com evictions contados |
| **Autosave/checkpoint journaling** (gzip no UTS-DB, retenção, crash recovery) | **FUNCTIONAL** | 9.9× compressão medida; checkpoint mais novo corrompido → recupera o anterior COM razão; zero válido = erro alto; save nunca bloqueia tick (host-side); A==B após recover+ticks |
| Física avançada (ragdoll, juntas, rotação completa de corpos) | **PARTIAL** | solver de translação/impactos/sleep nativo; juntas/rotação livre PLANNED |
| Busca web real (provider HTTP para research) | **PLANNED** | interface SearchProvider pronta (mock funcional) |
| LLM externo real no loop | **FUNCTIONAL\*** | *\*ExternalLLMProvider validado contra fetch mock; API real via env, nunca commitada* |
| Banco de dados externo/cloud storage | **PARTIAL** | UTS-DB nativo FUNCTIONAL (journal/tx/índices); backend externo PLANNED |

## Limitações reais (honestidade)

1. Checkpoints de autosave são estados completos comprimidos (RRW é a fonte
   da verdade; gzip+retenção tornam o custo incremental). Streams de delta
   por-entidade (cauda de eventos RRW) são PLANNED — não simulados.
2. LOD de terreno combina anéis de amostragem (24/16/8) + skirts +
   impostores; transição impostor→malha é um pop discreto (fade PLANNED).
3. Física nativa resolve translação + impactos + sleep; corpos rígidos com
   rotação livre, juntas e ragdoll são PLANNED.
4. Terreno estático por (chunk,res) — deformação ao vivo ainda não existe.
5. Áudio no Node sai como WAV/pacer (sem device de som nativo sem deps);
   playback ao vivo é no browser (WebAudioDevice). Binaural ITD+ILD próprio;
   pinna/convolução (HRTF completa) PLANNED. Música: camadas pad/bass/arp/
   pulse sintetizadas — instrumentos expressivos PLANNED.
6. `world.set_weather` etc. mudam clima via cadeia causal; a máquina orgânica
   é estocástica por RNG — testes que exigem clima fixo rigam o RNG.
7. Benchmarks dependem do host; sementes e contagens são determinísticas.
8. Streams SSE do provider externo são mínimos (delta de texto).

## Próximas fronteiras (ordem técnica — UMA por vez, terminada antes da seguinte)

1. Streaming assíncrono de chunks (workers) + deltas por-entidade via cauda
   de eventos RRW.
2. Rotação 3D livre (quaternions) + juntas de dobradiça na PhysicsWorld.
3. LLM real no loop (chave via env) com structured output validado pelo Core.
4. HRTF completa (pinna/convolução própria) sobre o AudioStream binaural.
5. Fade impostor↔malha (cross-fade no shader próprio).


## R1 — FENÔMENOS I (esta rodada)

**Refeitos sob ADR-019 (realidade primeiro), terminados e testados (210/210):**

- `src/world/phenomena/atmosphere.js` — FUNCTIONAL: ar com estado
  (umidade/poeira/poluição) + inércia; `sky()` = Rayleigh (dia vs pôr-do-sol
  por caminho óptico) + Mie (umidade/poeira) + noite não-preta. O céu do
  renderer DERIVA disso (gradiente autoral deletado do reallife).
- `src/world/phenomena/hydrology.js` — FUNCTIONAL: lâmina d'água por célula
  (chuva acumula, escoa por gradiente, evapora, infiltra), solo com memória
  (`soil.wetness` = a umidade do mundo), poças persistem, orçamento D-O15.
- `src/world/phenomena/combustion.js` — FUNCTIONAL: fogo consome biomassa
  real, espalha por vento+combustível, chuva apaga, chão queimado persiste,
  solo encharcado recusa ignição (evento `combustion.refused` auditável).
- `src/world/phenomena/ecology.js` — FUNCTIONAL: população de árvores
  (espécie/idade/biomassa/saúde), crescimento sol×água, sementes,
  competição, morte (fogo/seca/idade), madeira morta vira combustível.
- `reallife.js` re-ligado: fogo-entidade é agora âncora de PERCEPÇÃO que
  espelha o campo de combustão (nunca inventa); wetness vem da hidrologia;
  céu vem da atmosfera. Cadeia raio→fogo→medo de NPC continua 100%
  verificável (teste de integração).
- Frame/renderer: `frame.vegetation` (população materializada sob D-O15),
  `frame.water` (lâmina d'água), 7º programa (vegetation points).
- Persistência: fenômenos salvos/carregados; save→load byte-idêntico.

**Limitações honestas restantes:** lâmina d'água ainda não renderizada
(quad d'água fixo = limitação conhecida), chão queimado não muda a cor do
terreno, acústica sem oclusão (R2), fogo sem partículas próprias (usa
luzes), árvores como point-sprites (malha própria em rodada futura).


## R2 — FENÔMENOS II (esta rodada)

- `src/world/phenomena/acoustics.js` — FUNCTIONAL: som é onda de pressão.
  Atraso = d/343 s (velocidade FINITA — trovão chega depois do flash),
  espalhamento geométrico, absorção do ar (umidade aumenta), SOMBRA
  ACÚSTICA por terreno (marcha na linha fonte-ouvinte: atrás da serra o
  som chega fraco e abafado). Frame anexa a verdade de chegada a cada
  fonte; as duas vias de áudio (stream contínuo e renderFrameAudio)
  materializam. D-O15 RE-REPRESENTA: trovão longe/oculto = rumble grave
  longo, nunca só volume cortado.
- `src/physics/physics.js` EVOLUIDO — energia cinética real (½mv²) no
  evento de impacto; MATERIAIS (rocha 2.6g/cm³ dura, madeira leve, gelo
  frágil) com massa = densidade×volume; deformação PERSISTENTE acima da
  tenacidade (restituição cai, amassado sobrevive save/load via RRW);
  impactos recentes viram fontes acústicas (thud com energia real).
- Comida é CLIMA — `updateEcology`: bushes regrow do AGUA DO SOLO
  (hidrologia); seca mata comida com evento `ecology.food.withered`
  causal. Fome agora tem céu.
- Testes: 219/219 (9 novos: velocidade do som, sombra acústica, umidade,
  energia/materiais, amassado persistente, chegada tardia, comida-clima).


## R3 — ESCALA (esta rodada)

- **Mar segue a câmera**: `WATER_VS` recebe `uCenter` (XZ da câmera) — o
  oceano existe em TODA parte (escala), mas as ondas continuam FIXAS NO
  MUNDO (padrão não "nada" com a câmera). Limitação "quad fixado na
  origem" DELETADA.
- **Lâmina d'água materializada**: `hydrology.filmNear(cam, 220, 120)` —
  as células com profundidade > 4mm são renderizadas (mais fundo primeiro),
  tamanho/alpha ∝ profundidade. A água da chuva aparece no chão.
- **Horizonte vivo** (`frame.horizon`, `buildHorizon`): fogo além de 170m =
  BRILHO no horizonte (cintilação, intensidade do campo de combustão —
  re-representação D-O15, nunca descarte); assentamento além da bolha =
  marcador causal (população, identidade RRW preservada). Sem DUPLA
  representação (perto = luz/agregado, nunca os dois); orçamento 24.
- Renderer: 8º programa (`horizon`), pass único film+horizonte com blend.
- Testes: 226/226 (7 novos: mar-segue, filme, brilho, marcador-causal,
  sem-dupla, orçamento, determinismo com escala).


## R4 + R5 — RE-REPRESENTAÇÃO + GRAMÁTICA (esta rodada)

**R4 (D-O15 fecha como re-representação):**
- MUFFLE é FILTRO REAL: as duas vias de áudio (stream + renderFrameAudio)
  aplicam lowpass guiado pelo `muffle` da acústica — o fogo atrás da serra
  crepita ABFAFADO (testado por taxa de cruzamentos de zero), não só baixo.
- Cinzas VISÍVEIS: `combustion.burntNear` materializa a cicatriz de queimado
  (campo real, fresco primeiro) e o alpha DESVANECE com a idade (3.000 ticks
  — um tempo real, não um decal permanente).
- Chuva sob pressão D-O15 = RE-REPRESENTAÇÃO: menos gotas, cada uma maior e
  mais rápida (compensação 1/√densidade) — a intensidade PERCEBIDA sobrevive;
  o contador de partículas nunca foi a realidade.
- Pass único de escala: filme d'água + cinzas + horizonte (1 draw).

**R5 (Singularity AI cria com gramática e contexto):**
- `singularity/grammar.js` — gramática de criação determinística:
  multi-comando ("crie X e depois Y e 15 npcs e clima Z"), relações
  estruturadas (perto do rio / perto de "X" / ao norte de "Y"), contagens,
  nomes que terminam em stop-words, CADA comando cita o fragmento que o
  gerou (`source`) e o que não foi entendido volta honesto (`unknown`).
- Anexos VALIDADOS: csv com cabeçalho x,z,name,pop → assentamentos nas
  posições EXATAS (dados, auditáveis); texto "nomes" → uma vila por nome;
  imagem → registrada como NÃO VISTA (providers offline são vision:false —
  nenhuma percepção fingida). Validação estrita (tipos + 64KB).
- `world.plant_forest`: ferramenta nova que planta ÁRVORES REAIS (população
  da ecologia R1) — verificação = crescimento da população.
- `ues.create_settlement` evolui: `pos` (dados), `nearName`/`dir`/`of`
  (relações de âncora: Porto Sul fica ao sul de Ancora de verdade).
- Demo: painel de IA aceita anexo (csv/nomes) e mostra "N comandos (gramática)".
- Testes: 237/237.


## R6 — PLATAFORMA REAL (esta rodada)

- **Streaming assíncrono**: `world/async-sampler.js` + `world/chunk-worker.js`
  (worker_threads). Amostragem de chunks OFF-THREAD; resultado BYTE-IDÊNTO
  ao síncrono (testado com compare de buffers) — o worker muda QUANDO, nunca
  O QUÊ. Demo/Node opt-in (`createUTS({ asyncStreaming: true })`); browser
  cai honestamente para o caminho síncrono. `execArgv: []` no worker (nunca
  herdar flags do pai). Save→load continua byte-idêntico com workers ligados.
- **LLM real no loop**: `buildSingularity` registra `ExternalLLMProvider`
  quando `UTS_LLM_API_KEY`/`OPENAI_API_KEY` existe (+ `UTS_LLM_BASE_URL`,
  `UTS_LLM_MODEL`). Objetivos com raciocínio vão direto ao modelo real;
  heurística "não sei" → upgrade honesto audível (`upgradedFrom`).
  TESTADO contra servidor HTTP local; a chave NUNCA entra em snapshots
  nem memória (testado por substring). Sem chave: registra nada (honesto).
- **Busca web real**: `HttpSearchProvider` (env: `UTS_SEARCH_URL`/`KEY`),
  normaliza {results|lista} → contrato interno; ResearchService triangula
  sobre ele (testado contra servidor local). Sem env: offline honesto.
- **Onboarding**: tour guiado de 5 passos no demo (orbitar → IA cria →
  clima → fogo → save/load), destaca o painel de cada passo, uma vez por
  visitante (localStorage), botão pular.
- Testes: 242/242.

## R7 — OFENSIVA GRÁFICA (ADR-020): aparência é consequência

**Doutrina:** vencer em gráficos modelando a realidade, não pintando
aparências. **Feito e testado (9 testes novos, suite 251/251):**

- `src/render/scattering.js`: física do céu — Rayleigh (β λ⁻⁴ [1.16, 2.70,
  6.62]) + Mie (g=0.76, pico direto), march 8 amostras com caminho
  dependente da inclinação (o pôr-do-sol é vermelho porque o feixe cruza
  ~8× mais ar), disco solar, piso noturno. Espelho JS `skyColor()/aerial()`
  + `SCATTER_GLSL` GERADO das mesmas constantes (consistência testada).
- `shaders.js`: SKY_FS substituída — sem gradiente pintado; integra
  `skyColor()` por pixel com base de câmera real (fwd/right/up derivados do
  MESMO lookAt). TERRAIN/ENTITY/WATER: fog cinza `mix(col,uSkyBottom,…)`
  removido → `aerial()` (perspectiva aérea física). Água reflete o céu REAL.
- `atmosphere.js`: `optics()` — mie de poeira/poluição/umidade, intensidade
  atenuada por chuva. `frame.js`: `frame.air` + `frame.sunDirTrue` (sol não
  clampado — o céu vê o pôr-do-sol de verdade).
- `webgl2.js`: uniformes de ar em sky/terrain/entity/water; luz relâmpago
  continua ADICIONANDO luz ao ar (físico).

**Régua:** 81.66 → **82.46** (render 70 → 76). Falta em render: partículas
de fogo, malha de árvores, nuvens volumétricas, pós-processo.

## R8 — NUVENS VOLUMÉTRICAS + FOGO FÍSICO + ÁRVORES REAIS (ADR-020)

- `src/render/clouds.js`: a lâmina de nuvens é o MESMO ar condensado —
  densidade = ruído determinístico × perfil vertical × cobertura CAUSAL
  (`atmosphere.cloudCoverage`: tempestade 0.95, chuva, umidade; poeira
  suprime). O céu integra Beer + Henyey–Greenstein ao longo do raio
  (espelho JS + `CLOUD_GLSL` gerado). Borda prateada EMERGE do pico direto
  (testado: em direção ao sol ≫ anti-solar).
- `src/render/fire.js`: partículas de gás quente com temperatura
  900–1800K ∝ intensidade real da combustão; cor = LOCI DE PLANCK
  (`blackbody()` — 1000K vermelho, 5800K branco); sobe por flutuabilidade,
  esfria 75% e vira fumaça; contagem ∝ combustível; determinística.
  Blend aditivo (o fogo É luz).
- `mesh.js treeMesh()`: pinheiro = tronco cônico + 3 copas, stride
  pos3+norm3+copa; saúde mistura seco→verde; vento dobra quadraticamente
  (cantilever). Fallback sem instancing: 1 malha por árvore.
- Integração: 10 programas (+tree, +fire); `frame.clouds` (coverage+drift);
  frame hazards carregam {intensity,fuel}; arbustos continuam pontos (D-O15).
- Correção latente: introspecção de atributos agora cobre aHH/aSC/aAlpha/
  aCanopy/aT0/aT1 (atributos não listados ficavam soltos no navegador).
- **259/259 testes.** Falta em render: broadleaf, sombra de nuvem no solo,
  pós-processo.

## R9 — REALIDADE COMPLETA (a ofensiva ADR-020 vira sistema nervoso)

**Tese:** o que supera Unreal/Unity/RAGE/Anvil não é um gráfico bonito — é a
REALIDADE INTEIRA CONECTADA. R9 fechou as conexões que faltavam:

- **Sombra de nuvem no solo:** TERRAIN_FS importa o MESMO CLOUD_GLSL
  gerado e amostra a transmitância da lâmina DO SOLO PARA O SOL — a nuvem
  que o jogador vê é a que escurece o chão (móvel: deriva com o vento).
  Testado: monótona na cobertura; tempestade corta >70% do sol direto.
- **UM vento causal:** `atmosphere.state.cloudDrift` integra env.wind —
  o mesmo campo que dobra árvores e espalha fogo ADVECTA as nuvens.
  Testado: forte ≫ fraco; determinístico; frame compartilha a fonte.
- **Exposição física:** `world.observer` adapta o ganho do olho à luz real
  (constrige τ=0.35s no flash, dilata τ=11s no escuro; alvo Weber-like
  0.9/L^0.75). Multiplicada nos 5 shaders que produzem imagem. Relâmpago
  ofusca e o mundo escurece de verdade por um instante; a noite dilata.
- **Floresta mista:** espécies por NOME + lista por bioma — FOREST semeia
  pine E broadleaf (rng determinístico). `treeMesh('broadleaf')` = copa
  blob com 3 lóbulos + tronco. Fixes: `speciesFor` preserva name; linha
  `fragColor` duplicada latente em ENTITY_FS removida.
- **267/267 testes.** Falta em render: ondas direcionais, fumaça
  volumétrica iluminada, neblina por altura.

## R10 — O MAR E O AR RESPONDEM (realidade completa, água e luz)

- `src/render/ocean.js`: ondas = 3 componentes com dispersão de águas
  profundas ω=√(g·k) (o swell viaja ~1.8× mais rápido que o chop — FÍSICA
  VISÍVEL), direção = o MESMO vento (spread 0°/28°/63°), amplitude ∝ v²
  do vento, cristas que quebram viram ESPUMA cujo limiar cai com o vento
  (mar de tempestade 12× mais branco) e que espalha a COR DO CÉU.
  `OCEAN_GLSL` gerado das mesmas constantes (WATER_VS desloca; WATER_FS
  recomputa o campo p/ normal analítica consistente).
- `fire.js`: a fumaça ESPALHA a luz do céu (`skyLight()` do scattering —
  escura à noite, leitosa ao meio-dia) e ainda brilha perto da chama com
  o próprio corpo negro do fogo.
- `atmosphere.js`: NEBLINA DE RADIAÇÃO — umidade>0.72 & sol<0.12 constrói;
  sol alto e vento queimam; extinção do ar ganha a névoa. `frame.js`
  materializa BANCOS nos baixios (grade determinística, cor = céu real,
  dentro do orçamento D-O15 de 24).
- `world.js`: `env.windDir` fonte ÚNICA da direção (mar, árvores, fogo,
  nuvens). TREE_VS dobra NA direção do vento.
- **274/274 testes** (7 novos). Falta: fumaça volumétrica 3D, neblina
  por altura no aerial, reflexo de terreno na água.

## R11 — CINCO SISTEMAS DE UMA VEZ (mais fundo na realidade completa)

- **Física:** rotação LIVRE 3D por quaternion (q̇=½ω⊗q, renormalizada;
  atrito do solo freia o spin; yaw do renderer DERIVADO da orientação —
  uma verdade, sem estado duplo). RAGDOLL: 7 segmentos de carne
  (MATERIALS.flesh: deforma fácil, quase não quica) ligados por 6 juntas
  PBD; o pescoço segura após a queda; SOBREVIVE save/load via reattach().
- **Áudio:** PINNA — a concha reflete som para o canal ~30µs depois:
  notch espectral dependente da elevação (5.5–10.5kHz) + sombra do torso
  (atrás é mais escuro) = frente vs fundo SEM visão. REVERB POR AMBIENTE:
  Schroeder (4 combs+2 allpass) com RT60/pre-delay por espaço
  (sala 0.35s / vale 1.3s / cânion 2.9s); cânion soa 4×+ maior.
- **Streaming:** DELTAS POR-ENTIDADE — componentes carimbados com __v;
  deltaSince(T)/applyDelta: um clone restaurado em T acompanha o original
  recebendo SÓ o que mudou (testado com NPCs; sem delta diverge; delta
  nunca inventa entidade).
- **Render:** NÉVOA POR ALTURA no aerial() (JS+GLSL): boost de extinção
  ∝ fogH·e^(−h/20) — o baixio se afoga na neblina de radiação, a
  montanha escapa; uAirFog nos 4 FS; frame.air.fogH do estado causal.
- **Usabilidade:** GALERIA DE MUNDOS (4 presets REAIS via ?world=:
  alvorada úmida com névoa, arquipélago ventoso, vale em chamas com fogo
  aceso de verdade, cidade viva com settlement).
- **Fixes físicos:** dupla-contagem do OD no march (horizonte morria no
  piso noturno) → trapezoidal; beamTransmittance() expõe o feixe direto
  (invariante honesto do pôr-do-sol: B/R 0.48→1.4e-5); aerial insc com
  N dinâmico (8 amostras perto do horizonte).
- **281/281 testes.**

## R35 — A DOENÇA DO MEIO (TDZ do shell; a guarda que executa a casca)

**"Ainda detectando GPU" + "pouca coisa funciona": a raiz era UMA só.**
A restauração de sessão (`sessao()`) rodava NO MEIO do script do shell
— com sessão ativa (ou seja, em TODO reload após o redirect do mundo),
`ligarApp → iniciarMirror → atualizaMirror` lia `chats`, que só era
declarado 280 linhas adiante → **ReferenceError por TDZ** → a execução
do script inteiro morria ali: `window.__addCriacao` nunca era
registrado, galeria/PROJECTS/RECENT/histórico nunca renderizavam, o
badge GPU ficava eternamente em "detectando" (o `checaGpu` vinha
depois), botões ficavam sem handler. No primeiro login funcionava
(clique acontece após o parse) — por isso o bug se escondia.

**O conserto na raiz:** `sessaoIniciar()` virou declaração chamada NO
FIM do shell (depois de tudo declarado — ordem provada por script);
cada init do `ligarApp` ganhou try/catch próprio (um erro jamais mata
os outros — o banner denuncia em vez de meia-morte); badge GPU ganhou
fallback honesto (12s sem sinal do boot → "BOOT INCOMPLETO — cole o
banner").

**A guarda (r35 — O SHELL VIVO):** o teste EXECUTA o script do shell
com DOM simulado no exato caminho do usuário (sessão restaurada +
?world=vale + log pré-escrito) e exige: usuário no topo, __addCriacao
registrado, thread/PROJECTS/RECENT/galeria renderizados, badge GPU =
GPU REAL · WEBGL2 GENESIS lido do passado, chip IA com os modelos,
providers reais em SERVICES. A classe "metade do shell morta" morreu
sob teste. Auditado: **393/393, zero skips**.



**O bug do "detectando GPU":** os observers do shell (badge GPU, chip
IA · N modelos, espelho de logs) só liam MUTAÇÕES futuras — mas o boot
do módulo escreve ANTES do login. Agora todos fazem leitura imediata do
PASSADO do log e depois observam: o badge mostra GPU REAL · WEBGL2
GENESIS (ou MODO TEXTO HONESTO) no instante do login, o chip mostra a
contagem real de modelos e SERVICES mostra os PROVIDERS reais do boot.

**Identidade GÊNESIS (matrix deixa de existir):** o tema padrão é
GENESIS — e o efeito muda de conceito: nada CAI (isso era a identidade
antiga); na gênese a realidade ASCENDE do solo (fluxos de criação
subindo, verde com raios azuis, barato como antes). Migração automática
da preferência antiga; hero com a assinatura "o sistema que cria
sistemas · no princípio, um objetivo".

**Varredura "TUDO FUNCIONAL":** PROJECTS virou registro real — toda
execução BUILD vira projeto com objetivo/estado/resultado, marcado
CRIADO pelo ganho do engine, com REABRIR (leva ao compositor),
REEXECUTAR (recria, com confirmação) e EXPORTAR (.json). RECENT lista
conversas e criações reais (clicáveis); MEMORIES mostra conversas,
mensagens, criações e eventos do RRW; TASKS lista as execuções com
origem e hora; subcards AGENTS/MODELS/TOOLS/RESEARCH ganharam botões
reais; CREATE tem "escrever objetivo agora"; ASSETS e RESEARCH pedem à
IA com contexto. 70 botões com handler verificado, 72 IDs intactos.
Obs. honesta: o teste de autosave flakeou 1× sob a carga da suíte
(timing) e passou isolado e na re-execução — nada foi afrouxado.

## R33 — A REALIDADE NASCE NO LOGIN (mundo no primeiro olhar; IA responde na hora)

**O usuário confirmou o redesign ("MUITO melhor") e apontou as duas
feridas restantes: nenhum mundo real pra ver, e a IA da aba inicial
não respondia como devia. Raízes achadas no módulo: sem `?world=` o
engine cria um mundo com `setup: () => {}` — VAZIO; e o palco morava
só no UES (a home não mostrava realidade nenhuma).**

**Três consertos de raiz:** (1) A REALIDADE NASCE NO LOGIN — o primeiro
login entra direto no Vale do Alvorecer (`?world=vale`: alvorada +
chuva + neblina de radiação real, sem clique nenhum); sessão guarda o
flag, presets do usuário continuam valendo. (2) O PALCO ACOMPANHA — o
mundo vive na HOME do UTS AI (embaixo do hero) e se move para o UES ao
navegar (reparenting do canvas, context intacto, resize re-medido) —
a primeira tela mostra a conversa com a IA E a realidade viva ao lado.
(3) A IA RESPONDE NA HORA — no modo CHAT, a primeira bolha é a
TELEMETRIA REAL do engine (fps · tick · npcs · clima · eventos, lida
dos s-*) com o encaminhamento ao agente; a resposta do modelo (Puter)
chega na bolha seguinte pelo espelho do terminal — a home nunca mais
fica muda, nem offline. Diagnóstico honesto no palco: badge GPU lê o
boot (WEBGL2 GENESIS real × MODO TEXTO HONESTO). Auditado: 391/391.

## R32 — A GENESIS COMPLETA (login → UTS AI → 32 áreas; a performance como lei)

**O PROMPT SUPREMO, implementado:** o usuário entregou a especificação
completa (68 seções) e mandou refazer TUDO de novo com performance boa.
O frontend virou a GENESIS de verdade: **LOGIN** (autenticação LOCAL
real — SHA-256 no aparelho, sessão 12h com expiração, guest, reset de
conta, estados loading/erro/offline/sessão expirada; Google/GitHub
representados com honestidade PLANNED), e após o login a **HOME é a
UTS AI** (nunca a UES): hero GENESIS + compositor com toggle CHAT/BUILD
+ AUTO + anexos (file/imagem/url reais; vídeo/áudio honestamente
desabilitados) + thread de conversa que ESPELHA os terminais reais do
módulo (MutationObserver) + histórico só no UTS AI com
fixar/renomear/arquivar/apagar em localStorage. **SIDEBAR com 32 áreas**
em 4 grupos (inteligência · plataforma · UES · sistema), routing por
hash, command palette Ctrl+K, notificações com badge, IA contextual
global (drawer flutuante que recebe a área atual), bottom nav no mobile,
5 temas, escala de fonte, níveis de efeito AUTO/LOW/MED/HIGH/ULTRA.

**Performance como lei (a lição do R31b virou arquitetura):** ZERO
backdrop-filter; matrix sem sombra por glifo (tick 90ms, pausa escondida,
desligada em LOW/mobile); fundo 3D do login é grid projetado em canvas 2D
(barato) e PARA de animar após o login; sparkline de FPS só com o painel
visível; espelhos de telemetria a 0.7Hz checando document.hidden;
`prefers-reduced-motion` respeitado em tudo.

**A realidade inteira exposta, nada inventado:** as 27 estatísticas
s-* do engine têm ids REAIS no painel PERFORMANCE e são espelhadas para
UES/SCENES/ENVIRONMENT/NATURE/NPC/DATA; áreas sem UI pronta mostram
PLANNED/PARTIAL com o motivo (zero placeholder, zero dado falso —
ADR-018: a UI é camada de apresentação da realidade existente). O palco
3D mora no UES (a engine acessada pela inteligência), os controles de
clima no card #controls, o form de criação no #ai-panel do CREATE — o
tour do engine destaca os três de novo. **Contrato do módulo: os 72 IDs
presentes, zero chamadas-seletor, 391/391.** Auditado.

## R31 — O REDESIGN TOTAL (a casca nova; o módulo vivo intacto)

**O que mudou:** o usuário validou a pilha de shaders no aparelho
(logs + criação OK) e mandou refazer 100% do frontend — "todas as abas,
botões, submenus, menus, tudoooo". A casca (`demos/web/index.html`) foi
reescrita por inteiro: 5 abas (MUNDO/CRIAR/ESTILO/JOGOS/SISTEMA),
paleta preto + verde neon + azul elétrico, 30 ícones SVG próprios
(`icons.js`, zero emoji — a régua varre codepoints ≥ U+2190), chuva
matrix em canvas (glifos verdes, 12% raios azuis), scanlines + vigneta,
tipografia Space Grotesk + JetBrains Mono, telemetria completa, terminal
com cursor, sugestões clicáveis, tour e espelho ws-live — tudo
responsivo com `prefers-reduced-motion`.

**A lei do redesign (a que importa):** nada que a IA cria pode ser
invisível. Mundos por objetivo, jogos .zip e apps instalados agora
ENTRAM numa galeria de cards viva (`#criacoes`, `localStorage
uts.criacoes.v1`, máx 40) via o gancho `window.__addCriacao` — 3 pontos
de injeção no módulo vivo (mundo criado, jogo zipado, app instalado),
zero linha da lógica real tocada. O contrato dos 72 IDs do módulo foi
verificado por diff automático: TODOS presentes na casca nova.

**A auditoria r13 pegou um bug real do redesign:** `goal-attach` era um
TEXTAREA de anexo e a casca nova o tinha virado botão — o `.value` do
módulo leria vazio. Restaurado como textarea estilizado. Auditado:
391/391 (1 skip intencional — banco HRTF medido aguardando o dono).

**R31b — o aparelho falou (banner→causa→guarda, 4ª rodada):** o usuário
reportou FPS no chão, mundo invisível e "ERRO DE BOOT: Cannot set
properties of null (setting 'textContent')". TRÊS raízes: (1) bug
HERDADO do shell velho — `$('w-audio span')` usa `$` = getElementById e
id não tem espaço: NUNCA existiu; ligar o áudio explodia logo depois
(aúdio até tocava — o crash vinha após). Corrigido na fonte: o span
ganhou id próprio (`w-audio-rot`); (2) o canvas do mundo era fundo
`fixed` COBERTO pelos cards opacos no celular — o shell velho o tornava
janela de 46vh no fluxo; agora ele é PALCO: janela em moldura neon com
cantos e rótulo, no fluxo, VISÍVEL EM TODA ABA, e as abas re-medem o
canvas via `resize`; (3) FPS: `backdrop-filter: blur(14px)` em todos os
cards + `shadowBlur` por glifo do matrix = morte em GPU de celular —
zero backdrop-filter (painéis sólidos 0.88), matrix sem shadow, tick
66→90ms, barra de pressão estática. Diff exhaustivo: os 72 IDs do
módulo presentes, ZERO chamadas-seletor restantes. Auditado: 391/391.

## R30 — O AÉREO CEGO (aerial() sem declaração; 99.92 → 99.96)

**O terceiro erro do banner, a classe mais grave:** o driver denunciou
`aerial: no matching overloaded function found` no TERRAIN — e a raiz
era estrutural: `aerial()` (a perspectiva aérea gerada da física de
espalhamento) só era DECLARADA dentro do bloco do CÉU (SCATTER_GLSL);
TERRAIN_FS, ENTITY_FS e WATER_FS CHAMAVAM a função sem nunca a incluir.
TREE_FS tinha porque carrega o bloco inteiro. Conserto na FONTE: o
scattering agora exporta SCATTER_PROLOGUE (constantes geradas +
skyColor + aerial, SEM a linha #version) e os três shaders cegos o
recebem — #version único garantido e verificado.

**A guarda (r29 estendido, CLASSE 2):** o linter agora PARSEIA cada um
dos 24 strings (comentários fora, macros contadas) e reprova qualquer
função CHAMADA que não seja declarada no MESMO shader, nem builtin, nem
palavra-chave, nem fornecida por composição — mais a lei do #version
único e primeiro. A classe inteira do "compila no meu desktop, reprova
no seu aparelho" está sob teste. Auditado: 391/391.



**O segundo erro saiu do banner na primeira GPU REAL que a página
enfrentou:** o compilador GLSL ES 3.0 do driver do aparelho é ESTRITO —
`const float C_LO = 190;` (inteiro em float) reprova; os desktops
toleram e a sandbox não tem GPU, por isso nunca tinha aparecido. Os 4
erros denunciados (linhas 73/74/129/130 do SKY_FS) eram todos de BLOCOS
GERADOS: nuvens (C_LO/C_HI) e fumaça (SM_R0/SM_TOP).

**Conserto na FONTE:** os TRÊS geradores tinham a mesma lei quebrada
`f = String(Number(x))` — clouds.js, smoke.js e ocean.js agora emitem
float SEMPRE com ponto (`Number.isInteger(n) ? n + '.0' : String(n)`),
e o quarto foco estático (OS0 = 0 nos shaders de água) virou 0.0.

**A GUARDA PERMANENTE (r29):** linter estático sobre os 24 STRINGS de
shader (funções incluídas, com e sem bloco de superficie) que reprova a
classe inteira do erro — float declarado com literal inteiro e inteiro
puro como argumento de builtin float — além de exigir que os consts
gerados cheguem com ponto. O driver do celular nunca mais é o
descobridor de bugs. Auditado: 391/391 testes.



**O banner de boot cumpriu o papel dele na primeira batalha:** o usuário
colou o erro NA TELA — `Cannot access '$' before initialization @ :462`
— e a aritmética fechou: linha 462 do HTML = linha 240 do módulo, onde
`const styleOut = $('style-out')` roda no TOPO, mas `$` só era declarado
na linha 398. TDZ: o script INTEIRO morria aí — em qualquer navegador,
desde aquela edição. **Conserto estrutural:** `$` e `logLine` viraram
declarações de função HOISTED no topo do módulo (declaração de função é
inicializada antes de qualquer código de topo — TDZ impossível em
qualquer ordem de linha, para sempre).

**ROBUSTEZ REAL descoberta no mesmo passe:** sem WebGL2 (aparelho antigo
ou GPU bloqueada), `new WebGL2Renderer(null)` matava a página DEPOIS do
try do getContext. Agora: sem GPU = render de TEXTO honesto — UI, IA,
física e clima inteiros vivos; só o material do quadro muda.

**A GUARDA PERMANENTE (r28 — A PÁGINA VIVA):** o teste EXTRAI o módulo
real do index.html e o EXECUTA de ponta a ponta com DOM simulado,
afirmando que ele chega ao ÚLTIMO linha (o loop agendado no request-
AnimationFrame). Qualquer TDZ, referência morta ou boot quebrado volta a
ser FALHA DE TESTE — a página nunca mais morre em silêncio. Auditado:
390/390 testes.



**A CAUSA RAIZ DE "NADA FUNCIONA" (a página morta):** o grafo de módulos
do NAVEGADOR continha `node:fs`, `node:child_process`, `node:zlib` e
leituras de `process` — o script inteiro do mundo morria na importação
(em QUALQUER navegador, desde várias rodadas; os testes não pegavam
porque rodam em Node). Conserto estrutural: ENV com guarda, zlib
preguiçoso, ferramentas de máquina em módulo separado carregado por
import dinâmico SÓ onde há Node; auditoria mecânica prova ZERO
`node:` estático alcançável. Simulação de navegador: mundo constrói,
objetivo verificado, status honesto.

**A IA DO NAVEGADOR (Puter — User Pays, SEM CHAVE):** a página agora
carrega js.puter.com/v2; o PuterProvider ganhou STREAM (iterável de
partes → tokens um a um no fio do Core, MESMA lei de validação) e
LISTA DE MODELOS (a que a camada devolver — nunca número inventado;
a lista do dono tem 876). O registro só aceita a camada QUANDO ELA
EXISTE — sem ela, interpretador nativo, nada fingido.

**A PÁGINA NUNCA MAIS FICA MUDA:** banner vermelho de BOOT captura
exceção/rejeição/falha de módulo e mostra o erro NA TELA; o boot se
AUTORELATA no log (núcleo vivo em Xms + providers ativos + contagem
de modelos Puter). **389/389 testes.**



**O FIO REAL (IA 97 → 98):** o token streaming já era real (R24); agora o
PROTOCOLO DA NUVEM está provado ponta a ponta NESTA MÁQUINA: um servidor
HTTP de verdade (socket TCP) responde SSE OpenAI-compatível com os bytes
FRAGMENTADOS no meio de linhas e payloads (a rede não entrega blocos
arrumados) — o ExternalLLMProvider com o fetch GLOBAL (rede de verdade,
não mock) reconstrói, e os 100+ TOKENS chegam um a um ao
interpretObjectiveStream, que devolve o plano VÁLIDO cuja remontagem é o
texto inteiro. A nuvem é a MESMA rota com TLS + chave: o dono liga via
env e o código não muda uma linha.

**O TEMPO DE CONSTRUÇÃO (o pilar contra o tempo da indústria):** medido
com limite FORÇADO por teste — a IA cria uma vila com verificação em
11ms e um JOGO COMPLETO com arquivos reais em 3ms. Engines tradicionais
precisam de equipes e meses para cada mundo; aqui o humano DESCREVE e a
IA DESENVOLVE. Este é o número do argumento.

**Fix do Termux:** package-lock.json gerado localmente bloqueava o git
pull (untracked vs merge) — o guia novo inclui `rm -f package-lock.json`
antes do pull. **388/388 testes.**

 (a orelha exata, a luz forjada; 99.18 → 99.50)

**A BASE EXATA DA ORELHA (audio/sphere-hrtf):** a solução em SÉRIE DE
RAYLEIGH para a difração de onda plana pela esfera rígida (o problema
canônico do qual KEMAR/CIPIC são a medida) — H(Γ,f) fechada por soma
harmônica esférica com Bessel por recorrência determinística e a
identidade de Wronskian B_n = −i/(x²·h_n′). A tabela sai NO MESMO
schema do banco medido (13 az × 6 el, 48 taps) e passa pela MESMA
loadMeasuredTable e pela MESMA interpoladora binlinear. Provado contra
a física: transparência em baixa frequência (0.05dB), ganho de baffel
+6dB (1.98×), ILD crescente (1.8→7.0dB) e a ITD = 3a/c de RAYLEIGH
(774µs medidos vs 765µs analíticos — o resultado clássico, não a
aproximação geométrica de Woodworth). Convenções erradas matam a
sombra: e^{−iωt} sai com h^{(2)} — a que deu a física certa.

**A FORJA DE LUZ (agent/light-smith, tool agent.light):** o mesmo molde
da forja de geometria. Temperatura REAL (loco Planckiano, Hernandez-
Andres 1999, âncoras CIE: corpo negro 6504K = (0.3135, 0.3236); o
branco D65 da DEFINIÇÃO sRGB sai (1,1,1)); fotometria REAL (candela→
lux, 1/r² EXATO a 1e-12; corte no piso de visibilidade); spot pela lei
do cosseno; luz de ÁREA com amostras semeadas (suavidade real de
perto); RIG 3 pontos consistente com o ponto a 1e-9; gamut honesto
(dessatura, nunca clamp). 13 provas. Detalhe honesto: D65 é loco
DAYLIGHT — o corpo negro vizinho é (0.3135, 0.3236); os dois testes
convivem com as duas âncoras certas.

**A FUMAÇA EMPURRA MALHAS COMPOSTAS (physics + fluid3d):** o solver 3D
ganhou sampleAll (trilinear, a lei do advec) e a física ganhou PARTES:
massa composta = soma das partes (ρV/4 cada), raio de colisão alcança
a parte mais distante, silhueta soma as áreas. Força POR PARTE no
plume: arrasto ½ρ·Cd·A·|v_rel|·v_rel com Cd de ESFERA (0.47) e ρ
engordando com a fumaça, empuxo de Archimedes do fluido presente
(fumaça ~0.12% da água — honesto), TORQUE Σ r×F no ar. PORTÃO DE
CONTATO: corpo apoiado não tomba pela fumaça (a normal segura) — fogo
tomba o dirigível de madeira (0.74 rad), pedra apoiada nem sente
(0.0001 rad). Reconstrução bit a bit idêntica.

**O LANÇAMENTO (o pacto):** artefatos GENESIS v1 construídos e
ASSINADOS (ed25519): web (zip), android (kit) e EXE único SEA de
119MB — selos hash+assinatura VERIFICADOS; ata pública em
docs/launch/GENESIS-v1.json com a chave pública e fingerprints; a
chave privada nunca entra no repositório. A nuvem por env já estava
pronta (UTS_LLM_API_KEY/BASE_URL/MODEL no servidor; SSE ao vivo).
**386/386 testes. FÍSICA 8/8 e FERRAMENTAS 8/8 FECHADOS.**

 (o fio fala token; o artefato tem nome; 98.52 → 99.18)

**TOKEN STREAMING REAL (core + external):** o interpretObjectiveStream
usa o stream do provider quando ele existe: os TOKENS da nuvem
atravessam o onChunk UM A UM, o texto acumulado passa pela MESMA
validação de interpretação (muda o transporte, nunca a lei), com retry
e fallback honestos. Provado contra SSE real (ReadableStream com deltas
OpenAI-compatíveis; o fio parte no meio dos bytes e o [DONE] fecha).
Sem chave roda o caminho fatiado de sempre; com UTS_LLM_API_KEY /
OPENAI_API_KEY é produção — o mesmo código.

**ASSINATURA ED25519 (build-system):** build({ signingKey }) assina o
artefato (a chave pública embarca no selo); verifySelo valida hash E
assinatura: UM byte alterado reprova, chave trocada reprova; sem chave
o honesto diz. newSigningKey gera o par por instalação — a chave nunca
entra no código (mesma lei da API key).

**A FORJA DE GEOMETRIA (agent/geometry-smith, tool agent.geometry):**
malhas NOVAS por regras determinísticas: ÁRVORE por L-system (galhos =
1+g+…, contagem PROVADA pela fórmula), CRISTAL de N faces (simetria a
1e-9, 4f faces), ROCHA icosaesférica (20·4ⁿ triângulos, ruído
determinístico). Autoteste: finito, contagens, determinismo (mesma
semente = mesma malha). Tipo/parâmetro fora da lei = erro explícito.

**O VENTO EMPURRA CORPOS (physics):** acoplamento fluido-estrutura:
arrasto ½ρ·Cd·A·v² com a densidade do material decidindo — na
tempestade (vento 0.9) a lâmina de madeira anda 1.4m A FAVOR do vento,
a rocha 0.25m, na calmaria zero. O clima é DONO do vento (o teste lê a
direção dele — a física não mente para agradar o teste).

**Fixes colaterais:** params achatados no agent.geometry (a registry
valida por campo). **382/382 testes. PLATAFORMA 12/12, USABILIDADE
10/10.**



**FLUIDO 3D COM PROFUNDIDADE REAL (fluid3d):** solver Euleriano (Stam,
"Real-Time Fluid Dynamics") numa grade local 20×14×20 @ 12m: advecção
SEMI-LAGRANGIANA com o VENTO AMBIENTE na backtrace (o meio inteiro se
move), EMPUXO TÉRMICO (α·T − β·ρ — a fumaça quente sobe e o peso próprio
puxa para baixo), PROJEÇÃO DE PRESSÃO por Gauss-Seidel (14 iterações,
∇·v → 5e-6 medido). Determinístico: zero aleatório, passos fixos, e os
LIMIARES são IDENTIDADE do estado (dens < 1e-4, |T| < 0.01, |v| < 1e-3 ⇒
0 todo passo) — o snapshot esparso (só células vivas viajam; ar parado é
zero) restaura bit a bit e o determinismo save→load→evoluer se mantém.
JSON de double roundtrip exato.

**A FUMAÇA É SOLUÇÃO:** cada célula queimando INJETA densidade+calor no
solver (updateFires), a grade SEGUE O FOCO (recêntrise honesto: fumaça é
efêmera e a injeção contínua reconstrói), e o CÉU materializa as colunas
da solução (uSmoke lê peakColumns antes dos fogos analíticos de
horizonte — D-O15: nada é descartado). A vida do fogo é real: consome o
combustível e apaga sozinho; a fumaça continua subindo.

**O SMITH DE CENA (agent.surface):** shaders de SUPERFÍCIE novos por
composição de leis de material: NEVE (altitude+declive: acumula no alto
e no plano, penhasco solta), MUSGO (umidade × plano), CINZA (a cicatriz
do fogo), FLORAÇÃO (hash determinístico 127.1/311.7 — a primavera tem
endereço). Espelho JS = GLSL com as mesmas constantes; erro de estágio
ou parâmetro é explícito. O terrainFS injeta definição+chamada no shader
do TERRENO e o programa é RECOMPILADO ao vivo (cache por hash) — o chat
pediu "inverno", o mundo compila neve.

**Fixes colaterais:** render() autossuficiente (init lazy restaurado);
limiar esparso com identidade de estado matou a divergência do
save→load; r18 fio compacto volta a encolher (ar vazio não viaja).
**378/378 testes. RENDER 14/14.**



**A TEIA ALIMENTA A GENTE (society.teiaPass):** a vila PESCA o cardume
da sua célula (64m) e CAÇA o veado da célula ou da vizinha mais cheia.
A rede e a flecha COBRAM do campo: o peixe e o veado tirados deixam de
existir no banco — pesca predatória COLAPSA o cardume e a comida SOME
(não há peixe mágico). A carne e o peixe entram no armazém nos DOIS
tiers: abstrato (pop estatística, evolveSettlementAbstract) e
materializado (trabalhadores). Evento society.teia registra o que foi
tirado; acumuladores honestos no componente. O rebanho volta quando a
natureza se recupera (imigração da teia) — a fome da vila agora tem a
MESMA causa que a seca.

**CORRENTEZA COM VELOCIDADE REAL (ecology):** a advecção deixou de
saltar 1 célula por passo (teleporte) e ganhou ACUMULADOR físico: o
campo inteiro anda quando o deslocamento acumulado completa 1 célula —
0.35 células/s por unidade de vento, determinístico, persistido no
snapshot. Brisa de 30s não espalha o banco; vento forte de 120s leva o
bloom (e o cardume junto) para leste.

**O SELO (build-system):** TODO artefato sai com sha256 dos próprios
bytes (web zip, binário SEA, exe-kit, android-kit). verifySelo confere:
UM byte alterado quebra o selo; artefato sem selo não passa. Honestidade
mantida: integridade é PROVADA aqui; identidade (certificado de código)
continua sendo passo de distribuição.

**Fixes colaterais:** r19/r20 atualizados à física nova da correnteza
(a cadência mudou, a conclusão não). **375/375 testes. NÚCLEO 18/18.**



**FAUNA TERRESTRE (ecology):** a teia desceu do mar para o chão. CAPIM
por célula (64m) bebe a água do solo (logístico; SECA MATA o mato —
planta seca, não "para de crescer"). VEADO come o capim da célula
(Holling funcional) e MIGRA 10% do rebanho para a vizinha mais verde —
o pasto PERSEGUE a onda de comida e come atrás dela. LOBO COME o veado
(resposta Holling-II saturada pelo rebanho global — o lobo não come
infinito). Imigração: rebanho vindo de fora recoloniza quando o campo
é bom. Cadeia medida: seca → capim morre → veado colapsa → lobo cai
ATRASADO; chuva de volta → tudo recoloniza. Teto de materialização
(D-O15): o capim é campo real em até ~400 células; além disso é
re-representado, nunca descartado. Persiste no snapshot.

**CÁPSULA REAL (physics):** NPC de pé é cápsula para a física: corpo
rápido (v>2) que cruza a cápsula derruba (mesma lei do impacto, evento
npc.downed com by: corpo) e PERDE MOMENTO (14 → 0.93 na prova — o corpo
SENTIU a pessoa, conservação honesta). A base da cápsula é a ALTURA DO
TERRENO (o y guardado pode estar stale — bug encontrado e corrigido).

**BINÁRIO ÚNICO REAL (build):** com postject na máquina, o alvo exe
agora EXECUTA o SEA de verdade: node --experimental-sea-config → blob →
postject injeta no fuse → EXECUTÁVEL NATIVO com o app embutido (servidor
dentro; `--version` responde DO BINÁRIO). ELF provado no teste. Sem
postject: cai para o kit honesto da R19. A assinatura de código segue
honesto (passo de distribuição).

**O COLORISTA (shader-smith):** shaders de COR NOVOS por composição
ARBITRÁRIA de estágios-verdade: rotação de matiz (base ortonormal por
Gram-Schmidt sobre a luminância — 0° é IDENTIDADE EXATA a 1e-9; a
rotação é ortogonal: não inventa luz), temperatura (corpo negro do
material), lift/gamma/gain, curva S, sépia. GLSL montado na hora +
espelho JS com as MESMAS constantes + vetores de teste finitos; estágio
desconhecido ou parâmetro fora da lei = erro explícito. A lente viva
recebe o RESUMO ESCALAR (tint = pipeline do cinza médio — D-O15
honesto); o GLSL completo viaja no artefato do build. Tool
agent.colorist com presets (quente, frio, teia-noite, prata-velha,
psicodelico).

**Fixes colaterais:** capim semeia UMA vizinha por tentativa (a onda
não explode); lente viva criada na hora para o colorista; r19/r13
aceitam os DOIS contratos do exe (SEA quando há postject, kit quando
não). **371/371 testes.**



**EMPUXO DE ARQUIMEDES (physics):** a água desloca volume e o corpo perde
peso. Na convenção de massa do motor (m = ρV/4) a água tem ρ = 0.25, logo
a fração submersa de equilíbrio É a densidade do material: GELO flutua
92% afundado como na realidade (medido 0.90), madeira (0.7) leve, rocha
(2.6) e carne (1.05) afundam. Arrasto viscoso ∝ fração submersa; entrar
na água com velocidade é SPLASH — evento causal com energia abafada na
fila da acústica. Corpo flutuando não dorme (empuxo é força viva). Ordem
correta de Euler semi-implícito: força ANTES da integração (o empuxo que
vem depois da integração é zerado pelo contato — bug encontrado e morto).

**CORDAS PBD (buildRope):** corrente de nós (props) com juntas de
distância rest = segmento; pendurada com ~7% de esticão; TODOS os nós e
relações vivem no RRW ⇒ save/load recria a MESMA corda (juntas renascem
no reattach; esticão idêntica após restaurar). Honestidade: corda
empilhada no chão luta contra o contato e injeta energia no PBD
implícito — limite documentado, não escondido.

**IMPACTO DERRUBA NPC:** energia cinética de impacto a menos de 2.5m põe
o NPC no chão (downedUntil, evento npc.downed); caído NÃO anda (o
movimento obedece ao corpo); levanta quando o tempo do corpo cumpre.
A janela T..T+1 (mentes rodam antes da física no tick) não perde nem
dobra impacto.

**A TEIA (ecology):** PEIXES por célula comem o plâncton (crescimento
logístico; larvas chegam do mar aberto onde a comida concentra) e
SEGUEM o banco advectado (a escola viaja COM a comida, não para onde a
comida estava); célula sem comida esvazia (a teia não guarda mortos).
AVES seguem os peixes com atraso. Persistem no snapshot/restore; sem
plâncton não nasce peixe.

**O ARCO-ÍRIS (shaders, espelho JS = GLSL):** a gota refrata duas vezes
e reflete uma — anel a 42° do ponto ANTISSOLAR (vermelho por fora, azul
por dentro), secundário a 51° com cores INVERTIDAS e ~43% da luz, e a
BANDA DE ALEXANDER escurecendo o céu ~28% entre os arcos. Só existe com
chuva suspensa + sol (frame.rainbow = chuva × elevação solar):
consequência, não efeito.

**O SMITH POR DESCRIÇÃO (forgeLook):** o LÉXICO DO OLHAR — sonho, noir,
retrato, vintage, pesadelo, cristalino — o chat diz o olhar e a lente
carrega (média dos parâmetros quando cruza looks). Palavra fora do
léxico é HONESTA: entra no nome como "(criado)" e usa a média verificada;
autoteste numérico sempre. A lente viva é criada na hora se não existir
(nunca no-op silencioso).

**O DIRETOR VIVO (media/cutscene + ues):** dentro de um plano a câmera
VOA de cam→cam2 com easing easeInOutQuad e MIRA o alvo (yaw/pitch
derivados da geometria, mesma convenção do renderer); letterbox no
frame; no fim o jogo recebe o enquadramento DE VOLTA. Rola pelo chat:
media.cutscene { play: true }.

**A NUVEM HONESTA (cloud-storage):** interface estruturada put/get/list;
bytes sobem em base64 fiel; a chave vai SÓ no header Authorization,
configurada por ambiente (UTS_CLOUD_URL/UTS_CLOUD_KEY — nunca no código);
transporte injetável para teste determinístico; sem env é LOCAL e DIZ
que é local (CloudError CLOUD_OFFLINE codificado).

**O KIT ANDROID REAL (build):** android vira android-kit: projeto gradle
COMPLETO embalado (manifest + MainActivity + www/) com INSTALL.txt
ensinando o assembleDebug — o projeto é buildável; sem toolchain não
fingimos compilar (o contrato honesto do apk continua, agora com
artefato real).

**O OLHO DO DIRETOR (core.critique + genesis.critique):** a IA lê o
próprio mundo — quem vive nele, o que o clima está fazendo, quem caiu —
e devolve crítica honesta com sugestões DERIVADAS DO ESTADO
(determinísticas; nada de texto pronto).

**Fixes colaterais:** ordem do empuxo no integrador (força antes da
integração); agent.shader cria a lente se não existe; schema do
world.style já aceitava ca/sharp (R19). **367/367 testes.**



**LÂMINA D'ÁGUA (fluids, atrito de leito):** o escoamento rasante perde
energia no LEITO: drop × min(1, 0.3 + (h/0.4)·0.7). A película de 2cm
escorrega DEVAGAR; a lâmina de 40cm deságua rápido — provado no mesmo
declive (0.5 escoa mais que 0.03). Conservação segue de pé.

**CORRENTEZA (ecology.planktonField):** o plâncton deixa de ser número e
vira CAMPO (células de 64m): o bloom nasce na costa (onde o silt chega) e
O VENTO ADVECTA o campo (shift = vento·dt·0.35, decaimento por célula).
Sem ilha causal: a vida se move com o ar. Persiste no snapshot/restore.

**O FIO COM LZ (src/util/lz.js, USZ):** LZW próprio (zero deps), header
de 12B + códigos u32 LE. Honestidade ANTES do pacote: encodeSnapshotPacked
empacota SÓ se shrinks() — estado diverso viaja TEXTO (e os dois abrem
IGUAIS no cliente, provado); applySnapshot aceita ambos.

**A ORELHA DE LITERATURA (hrtf):** grade 13 az × 6 el (15°/20°) derivada
de resumos publicados (CIPIC/KEMAR/Woodworth): ITD=(0.0875/343)(θ+sinθ),
sombra contralateral ≈ -18dB MEDIDA no pico da resposta, notch da concha
varrendo com a elevação, ombro no reflexo do torso. Binlinear mantida
(7.5° = média EXATA de 0°/15°). O slot da tabela MEDIDA continua aberto
(loadMeasuredTable intacto).

**KIT DE IMPLANTAÇÃO (build exe):** o exe agora é um kit REAL: zip
executável com o app + run.sh + INSTALL.txt — roda em qualquer
linux/mac com node 22. Honestidade mantida: o binário ÚNICO exige
postject/SEA (dito no resultado, não escondido).

**SMITH COMPLETO (aberração + nitidez):** a forja óptica agora carrega 6
efeitos verificados (espelho JS = GLSL, autoteste numérico): vinheta,
grão, bloom, tonemap, ABERRAÇÃO CROMÁTICA (dispersão radial ∝ excentricidade
× uCAExtra) e NITIDEZ (unsharp mascarado). A lente viva recebe todos.

**STREAMING PROVADO PONTA-A-PONTA:** o plano da IA atravessa o fio SSE
partido no meio dos bytes e é reconstruído BYTE A BYTE (parser + [DONE] +
multiline) — a mesma substância, sem chave nenhuma.

**Fixes colaterais:** guard do atraso HRTF (taps dentro do FIR 8);
world.style aceita ca/sharp; schema do smith com ca/sharp; R19 = 357/357.



**O PLÂNCTON (ecology.plankton):** a vida no MAR. Floresce com nutrientes
que chegam à costa (o SILT da erosão escorrido para o mar — a mesma
cadeia da R17 agora termina em LUZ) e com luz (fotossíntese); decai sem
nutriente. Persiste no phenomenaSnapshot.

**BIOLUMINESCÊNCIA (WATER_FS uBio):** no escuro, a água PERTURBADA
brilha (luz mecânica dos dinoflagelados — cor real ciano-verde
[0.18, 0.85, 0.62]): uBio = plankton × presença de mar; brilho = uBio ×
noite × (onda + espuma). A cadeia INTEIRA viva e testada: chuva →
erosão → silt → rio → mar → plâncton → luz. Sem mar, sem brilho (honesto).

**A ORELHA GIRA SUAVE (pickBilinear):** a HRTF interpolada entre as 4
células (az × el) — 15° é a MÉDIA EXATA de 0°/30° (provado a 1e-12), as
âncoras ficam exatas, vizinhos contínuos (atrasos discretos de FIR
documentados). O ouvido não dá degraus ao virar a cabeça.

**O FIO COMPACTO (compactState):** snapshot com números arredondados e
nulls fora — MENOR com a MESMA verdade (≤1e-4, provado por caminhada no
estado restaurado). O seq segue autoritativo (gap continua erro).

**O SMITH COMPLETO:** mais dois blocos verificados — BLOOM fisiológico
(corona ciliar: limiar 0.75 + halo largo) e TONEMAP de display (Reinhard
col/(1+col)) — espelho JS = GLSL, autoteste; estilo aceita bloom/tone
(schema achatado); o post tem uBloomE/uTone.

**O FIO DO LLM CONTADO (net/sse.js):** parser SSE que junta chunks
PARTIDOS no meio da linha, vê [DONE], junta data multiline — integrado
ao proxy (passthrough byte-exato + contagem honesta de eventos no log).

**NOITE NUM BOTÃO:** lua AUTORAL (ícone SVG), handler que manda o tempo
do mundo para a madrugada — o olho escurece (Purkinje) e o mar brilha
se houver plâncton. Zero emoji segue garantido por teste.

**Testes:** r18-the-living-sea.test.js — 7 testes (350 no total).

## R17 — A TERRA NO ESPELHO + A PLATAFORMA QUE RECEBE E MEDe (91.38 → 92.26)

**A TERRA NO ESPELHO (render/water-reflection.js):** a água refletia só
o céu — agora MARCHA o heightfield REAL ao longo do raio refletido (4
passos × 26m): se o raio acerta morro/montanha, o que a água mostra é a
TERRA (areia/mata/rocha/neve por altura), com fade de perspectiva aérea.
Sem render target: o terreno é DADO analítico. O espelho JS usa
terrain.height (com deltas de erosão); o GLSL é gerado com as MESMAS
frequências macro e a SEMENTE real do mundo (uTerrSeed via frame) — a
silhueta na água é a silhueta DESTE mundo. A chuva ainda PRATEIA a
superfície (gotas espalham a luz do céu) e QUEBRA o especular (quebra
de tensão superficial).

**OCEANO→ATMOSFERA:** o mar EVAPORA — 8 amostras no horizonte do
observador viram fração de mar (env.seaHumidity) que soma na umidade do
ar (litoral medido mais úmido que interior, mesma chuva). E a névoa de
radiação ganhou a física que faltava: ela é fenômeno de AR CALMO —
acima de vento moderado a formação CESA (turbulência mistura) e o vento
disperse a que existe (tendência líquida build − disperse).

**SNAPSHOT DE RECONEXÃO (net/sync.js):** fio completo e honesto — delta
exato aplica; replay ignora (idempotente); GAP é erro; e agora o SNAPSHOT
COMPLETO (encodeSnapshot/applySnapshot) substitui o estado do cliente
sob seq nova e os deltas continuam dali. Reconectar nunca adivinha.

**APPS DE USUÁRIO (platform/user-apps.js):** o ciclo REAL da plataforma:
o GENESIS cria o jogo → o usuário INSTALA (workspace/apps/<nome>/, do
zip VERIFICADO, com manifest app.json) → joga servido PELA plataforma
(/apps/<nome>/index.html) → o app tem STORAGE PRÓPRIO (apps/<nome>/data/,
sandbox duplo; fuga e app alheio = erro). rescan() traz os apps de volta
ao reiniciar. /api/install, /api/apps, tool platform.install/apps/storage.
Botão "instalar na plataforma" no demo.

**A ORELHA DIRECIONAL (audio/hrtf.js):** HRTF como TABELA direcional
(7 azimutes × 5 elevações, FIR de 8 taps por orelha: ITD de Woodworth
como atraso puro, sombra de cabeça lowpass, notch da concha por
elevação, ombro). Rótulo honesto: "paramétrica publicada" — e o slot
loadMeasuredTable(table) valida o banco MEDIDO do dono pelo MESMO schema
(recusa incompleta com erro que ensina); o consumidor nunca muda.

**A PLATAFORMA SE MEDINDO:** perf EMA por fenômeno (reallife, climate,
atmosphere, fluid, erosion) no world.perf, exposto no genesis.status —
custo honesto por subsistema, sem estimativa.

**Simetria restaurada:** o load de save agora liga world.ues = ues (o
mundo restaurado foca os fenômenos onde o observador está — igual ao
original; os testes de determinismo byte-a-byte voltaram a fechar).

**Testes:** r17-land-in-the-mirror.test.js — 8 testes (343 no total).

## R16 — ÍCONES AUTORAIS + A AUTORIDADE DO ESTADO (zero emoji; 90.74 → 91.38)

**ÍCONES SVG PRÓPRIOS (render/icons.js):** 25 ícones autorais (olho,
escalas, pasta, terminal, caixa, gamepad, paleta, link, check, cruz,
proibido, alerta, som, mudo, terra, alvorada, ilha, fogo, templo, play,
varinha, radar, gota, pincel, engrenagem) — 24×24, stroke currentColor,
UMA fonte de verdade: o demo injeta o sprite e referencia com <use>;
TESTE garante: nenhum codepoint gráfico (emoji) sobrevive no HTML e
todo <use href="#i-x"> existe na biblioteca. Ícone inventado = erro
honesto.

**ACOMODAÇÃO MATERIALIZADA (DOF real):** o FBO da cena ganhou textura
de DEPTH; o post lineariza near/far, lê a distância por pixel, foca no
CENTRO (onde o olho acomoda) e borra pelo círculo de confusão
∝ pupila/7 — a óptica do olho agora AGE na imagem com a geometria real.
Device sem FBO: sem post, resto desenha normal (honesto).

**A LENTE DO ESTILO ganhou óptica física:** vinheta NATURAL (cos⁴ do
ângulo de campo — queda real de irradiância) e grão de SENSOR (ruído de
fóton, σ ∝ 1/√sinal — menos luz, mais grão). Noir os carrega por
padrão; qualquer estilo criado aceita. Via POST + uniforms.

**O AGENTE GRÁFICO (agent/shader-smith.js):** forja óptica da biblioteca
VERIFICADA — cada efeito tem modelo físico + GLSL + espelho JS gerados
das MESMAS constantes; o espelho é amostrado numericamente (autoteste)
antes de entregar; desconhecido/fora de faixa = erro honesto. Aplica na
lente viva. Tool `agent.shader`.

**SYNC AUTORITATIVO (net/sync.js):** o mundo do servidor é a ÚNICA
verdade; deltas cruzam o fio com seq. Regras honestas: seq exata →
aplica; replay/antigo → IGNORADO (idempotente); GAP → ERRO (o cliente
pede snapshot completo, nunca adivinha). Teste: cliente converge byte a
byte; replay não volta estado. Tool `net.sync` emite o delta.

**BIOLOGIA→ATMOSFERA:** `ecology.canopyNear` (densidade × maturidade no
raio) → evapotranspiração soma na umidade alvo do ar (fator 0.45) → a
névoa da madrugada nasce ANTES na mata. Gêmeos: mesma chuva, só o
dossel difere — umidade e névoa maiores na floresta (medido).

**Testes:** r16-svg-and-authority.test.js — 7 testes (335 no total).

## R15 — O GÊNESIS CRIA LITERALMENTE TUDO + A UTS CONSEGUE TUDO (89.86 → 90.74)

**O CRIADOR (agent/creator.js):** uma frase vira um JOGO COMPLETO E
JOGÁVEL. `createGame({genre, name, brief})` — 5 gêneros REAIS:
- **corrida**: pista procedural de 40 segmentos com curvas semeadas,
  voltas, aderência;
- **plataforma**: 24 plataformas com física real (gravidade 1500, salto
  560) e moedas;
- **rpg**: mapa com bioma semeado + 6 missões com recompensas;
- **torre**: caminho senoidal + 10 ondas escalando hp/velocidade + 2
  torres com custo/dps;
- **sobrevivência**: mundo com árvores/pedras, ciclo dia/noite, fome,
  inimigos noturnos, receitas de crafte.
Determinístico (mesma frase = MESMO jogo — testado), shell auto-contido
(canvas 2D, zero deps — roda num A01), assets gerados (textura + clipe
de andar), zip verificado LENDO de volta. Gênero desconhecido = erro
que ensina ("sei criar: … — me diga as REGRAS que eu crio o seu").
Tool `genesis.create` + `/api/create` (baixa o .zip) + botão 🎮 no demo.

**TRANSPORTE REAL (net/transport.js):** WebSocket RFC 6455 zero-dep —
accept key idêntico ao exemplo do PRÓPRIO RFC (`s3pPLMBiTxaQ9kYGzzhZRbK+xOo=`),
frames do cliente MASCARADOS (máscara bit a bit), lengths 7/16/64 bits,
ping→pong, close honesto. `WSHub.attach(server)` mantém os sockets
vivos e transmite o MESMO mundo para todos. Pulse a cada 2s no demo
(clientes, estilo, uptime) — o indicador 🔗 no painel é O transport
funcionando, não um enfeite.

**A ÓPTICA DO OLHO MATERIALIZADA (POST pass):** a cena vai para uma
textura e o post mostra o que o OLHO faz com ela: px→ÂNGULO real
(excentricidade = comprimento·fov), acuidade foveal 1/(1+(ang/2.2°)²)
periferia = borrão; aberração cromática lateral desloca R/B ∝ ângulo;
halo do glare em volta dos brilhos (PSF, energia do frame). Device sem
FBO? Sem post — honesto (o resto desenha normal).

**A GEOLOGIA ALIMENTA A VIDA (acoplado):** o sedimento que a erosão
deposita fica mapeado por célula (`silt`), `siltAt(x,z)` soma 3×3 e o
`ecology.step` recebe o adubo: crescimento ×(1+boost até 0.8). A MESMA
chuva que esculpe o chão alimenta a mata — cadeia causal única.

**A CABEÇA REAL (áudio):** ITD de Woodworth com a cabeça média (r=8.75cm,
c=343): ITD(θ)=(r/c)(θ+sinθ) — frontal 0ms, lateral 0.656ms, curva
contínua (o máximo antigo era o ponto final da curva — agora a curva
INTEIRA). Notch da concha por elevação. Honesto: modelo paramétrico,
não medidas — a base de dados medida segue na fila.

**A PLATAFORMA SE VÊ:** tool `genesis.status` — estado HONESTO de todos
os subsistemas (mundo, olho com pupila, estilo, escalas, erosão+silt,
agentes fs/exec, targets de build, mídia/dublagem).

**Testes:** r15-genesis-creates-all.test.js — 8 testes (328 no total),
incluindo handshake RFC com socket CRU e criação dos 5 gêneros.

## R14 — O OLHO COMPLETO + ESTILOS SEM LIMITE (o órgão com estado + a lente que obedece ao usuário; 89.08 → 89.86)

**O OLHO COMPLETO (render/vision.js):** "capturar TUDO que o olho humano
consegue" — o olho agora é um ÓRGÃO com estado que evolui entre frames
(`VisionDynamics`, determinístico, mora no mundo):
- **Pupila** 2–7mm com dinâmica assimétrica REAL (constrição tau 0.25s —
  protege a retina; dilatação tau 1.5s — adaptação ao escuro é lenta).
- **Acomodação**: círculo de confusão pela abertura — pupila aberta =
  foco raso (a óptica do olho, não um blur pintado).
- **Acuidade foveal**: 1/(1+(e/2.2°)²) — o centro é denso, a periferia
  é borrão sensível a movimento (é assim que o olho amostra).
- **Supressão sacádica**: gaze > 60°/s mascara a visão (até 85% do
  ganho) — virar o olho rápido APAGA a visão por um instante.
- **Pós-imagem negativa**: o flash queima o complemento da tinta de
  Purkinje e decai (tau 1.2s) — uAfter nos shaders.
- **Véu óptico**: luz espalhada na óptica LEVANTA o preto (∝ cena);
  escuro = preto é preto. uVeil.
- **CFF**: fusão crítica 56Hz fóvea dia → 36Hz noite; periferia funde
  MAIS ALTO (é detector de movimento).
- **Aberração cromática lateral**: 0.035%/° — cresce com a excentricidade.
- Purkinje/glare/CSF (R13) continuam; o frame carrega o órgão inteiro
  (`frame.vision`) e o `exposure` do frame é mascarado pela sacada.

**MOTOR DE ESTILO (render/style.js) — "realista, anime ou QUALQUER um
que o user falar (sem limites)":** a física é resolvida UMA vez e é a
MESMA para todo estilo (comprovado: mundos gêmeos dão pupila e luz
idênticas); o estilo é a LENTE D-O15 sobre a luz já resolvida: bandas
cel, rim light (entidade+vegetação), saturação, contraste, tinta — nos
5 shaders. 7 presets (realista=identidade honesta, anime, noir, pastel,
cyberpunk, carvão, aquarela). Nome desconhecido SEM parâmetros = erro
honesto; COM parâmetros = a IA **CRIA o estilo do usuário na hora**
("sonho azul" com sat/tint vira estilo real, validado e congelado).
`StyleEngine` guarda histórico e emite `world.style.changed` no RRW.
Tool `world.style` usa o engine; tool nova `eye.readout` devolve o que
a retina captura (a IA VÊ pelo olho). `/api/style` no servidor (400
honesto p/ inventado sem params). Demo: painel de estilo com os 6
presets + criar estilo novo (nome + params JSON) ao vivo.

**EROSÃO MULTI-ESCALA (world/erosion.js):** a chuva que CAI escava o
chão (kE·energia·declive, nunca abaixo de 0), o sedimento vai MORRO
ABAIXO (4 vizinhos), deposita onde o declive morre, 10% fica suspenso
e assenta — massa CONSERVADA (erodido == depositado + em trânsito, o
teste exige 1e-9). Os deltas são estado REAL: `terrain.height()` lê
`terrain.deltas` — o mundo é esculpido de verdade. Quando o total
movido cruza o limiar, SOBE A ESCADA: `scales.propagateUp([m³],
'region')` → o registro geológico no nível PLANETA (events[] persiste
no phenomenaSnapshot/Restore). Determinística (twin seeds batem).

**REVERB → BUS DO MIXER (dívida da R11 paga):** `mixer.setSpace('sala|
vale|cânion')` — o mix estéreo SECO passa pelo Schroeder do espaço
antes do limitador (uma verdade só). Medido: tailEnergy(cânion) ≫
tailEnergy(sala) > seco. Espaço inventado = erro honesto.

**Testes:** r14-eye-and-styles.test.js — 14 testes (320 no total).

## R13 — QUINZE SISTEMAS DE UMA VEZ (a escada inteira + o olho + a IA operando a máquina; 87.18 → 89.08)

**A escada da realidade (world/scales.js):** 15 níveis do quantum (1e-12 m)
ao universo (8.8e26 m), cada um com escala de tempo própria. `scaleFor`
etiqueta qualquer corpo (um NPC é 'human', um próton é 'quantum');
`aggregate` sobe a estatística SÓ entre vizinhos (a rede é causal — célula
vira tecido, tecido vira órgão; quantum NÃO pula para human);
`ScaleLadder.propagateUp` faz o evento de baixo virar estado de cima.
O mundo etiqueta os corpos no spawn (`world.scales`).

**O OLHO HUMANO (render/vision.js):** mais que fotorrealismo — o que o OLHO
pega. Bastonetes assumem no escuro (mix por log10 da luminância);
Purkinje: a noite tinta de azul e o vermelho MORRE (tint=[1−.22r, 1−.06r,
1+.16r]); glare PSF (.06·log10 L/3) no relâmpago; CSF: contraste cai no
escuro (.55+.45·(1−rod)). `frame.vision` alimenta `uEyeTint` nos 5 shaders
(webgl2 envia o tint do frame — o olho chega à tela).

**IA com sistema de arquivos (agent/fs-agent.js):** AgentFS com sandbox
duro (absoluto e '..' rejeitados ANTES do resolve), journal de 500
operações, read/write/mkdir/list/remove/move. **Executor de comandos
(agent/proc-agent.js):** sh -c com timeout 20s, guarda regex contra
destruição (rm -rf /, mkfs, fork bomb, dd, shutdown), opt-in honesto
(UTS_ALLOW_EXEC=1; desligado é o padrão e o teste exige isso).

**Compilar e descompilar (agent/build-system.js + util/zip.js):** zip
store determinístico próprio (CRC32, EOCD, erro honesto se corrompido).
web: builda AGORA — projeto npm real empacotado, verificado lendo o zip
de volta (o teste baixa o .zip do servidor e lê). android/exe: scaffold
REAL (gradle/manifest/MainActivity; SEA) e erro honesto se a toolchain
não existe (`toolchain ausente: …`) — nunca apk falso.

**Mídia em todos os Ds (media/):** models (2d estrela/polígono, 2.5d
extrusão, 3d torus/prisma, 3.5d voxel com value noise, 4d frames
animados); textures (madeira com anéis, tijolo com fiada offset e
rejunte, mármore com veios — determinísticas); animation (Track/Clip,
smoothstep, blendPoses — o andar 'cansado' amortece de verdade);
cutscene (diretor com planos/letterbox/fim honesto); dub (pt/en/es/ja
com cps por idioma — japonês dura mais; tradução só do que está no BOOK,
nunca fake).

**Perfis D-O15 (ues/devices.js):** a01 (33ms, 40 vegetais, sem sombra) →
desktop (11ms, 500, 300 npcs). O MESMO mundo com orçamento menor —
deferir/reduzir/re-representar, nunca descartar.

**Estilo pelo chat (world.style):** 'anime', 'realista' etc. viram ESTADO
do mundo (evento world.style.changed no RRW) — não string solta.

**Frontend 100%:** painel novo 'IA no seu aparelho' (criar arquivo no
workspace, executar comando, gerar app .zip que baixa) + teste que
AUDITA o HTML: todo `<button id>` tem handler — se um botão nascer
morto, a suíte falha.

**Endpoints HTTP reais:** /api/fs (sandbox; fuga = 400), /api/exec
(403 honesto sem opt-in), /api/build (application/zip com o app dentro).
Bug real encontrado e corrigido no caminho: writeHead antes do await
mata o processo com ERR_HTTP_HEADERS_SENT — agora trabalho primeiro,
header depois.

**Descompilar (agent.inspect):** a porta de volta — `inspect(data)` lê
qualquer zip/apk/aab: nomeia TODO arquivo com tamanho, extrai package.json
e AndroidManifest.xml como texto, e relata binário como bytes (nunca finge
texto). Registrada como tool `agent.inspect` (a IA descompila pelo chat).

**Testes:** r13-full-reality.test.js — 16 testes (306 no total): escada
(conservação + vizinhos), olho (Purkinje/glare/CSF no frame), 5 Ds,
texturas, animação, cutscene, dublagem, sandbox de arquivos, guarda de
comandos, compilador (web real + honestidade apk/exe), perfis, tools
registradas, DESCOMPILAÇÃO (arquivos nomeados + manifestos + binário
honesto), /api/fs por HTTP (incluindo fuga → 400), auditoria de
botões, zip roundtrip + corrupção → erro.

## R12 — NOVE SISTEMAS DE UMA VEZ (o maior round; 84.98 → 87.18)

1. **Fluidos** (`fluids.js`): água rasa por pipe-model atômico — chuva
   despejada no morro ESCORRE (poça mais funda é morro abaixo), conserva
   massa com evaporação+infiltração MEDIDAS (mass+lost ≈ despejado).
2. **Clima regional** (`climate.js`): grade 6×6 de fatores que RESPIRAM e
   são ADVECTADOS pelo vento (frentes andam); `rainAt(x,z)` alimenta a
   combustão POR CÉLULA — o fogo vê a chuva da SUA região (piso 0.6×:
   tempestade segue tempestade em toda região).
3. **Fumaça volumétrica de horizonte** (`smoke.js`): march com BANDA
   ADAPTATIVA por fogo (projeta o raio na pluma, ±140) — JS+GLSL gerado,
   no SKY pass (uSmoke[4]); escura à noite, leitosa de dia, CURVA com o
   vento, atenua o céu atrás. Escopo honesto: fogos >170 (perto continua
   partículas); reflexo de terreno na água espera render target.
4. **Agente CODER**: gera código REAL na gramática de criação a partir de
   um brief estruturado, o PARSER valida (auto-reparo simplificando, ≤3),
   executa, e o MUNDO verifica (vila no RRW, árvores vivas, clima). Falha
   honesta em brief vazio. Fix da gramática: nome entre aspas DIRETO.
5. **Streaming**: `processObjectiveStream`/`interpretObjectiveStream` —
   o stream É o resultado (chunk join == JSON exato); UI recebe em partes.
6. **SSE** (`/api/llm/stream`): proxy token-a-token do LLM env; 503
   honesto sem chave.
7. **Absorção por material** (acoustics): a oclusão ganha o material do
   bloqueador por bioma (rocha 1.8 ≫ mata 1.1) — o morro de rocha abafa
   mais que a mata.
8. **Deltas comprimidos**: quantização em deltaSince — JSON menor, o clone
   sincroniza igual (testado com NPCs).
9. **GENESIS 1-comando**: npm run genesis === npm start.

**Fixes colaterais:** mock-gl ganhou uniform4fv; fluid atômico (delta map);
plant_forest do coder ancora na TERRA da vila. **290/290 testes.**
