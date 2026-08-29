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

## R18 — O MAR VIVO (a vida que brilha + o fio que não mente; 92.26 → 93.02)

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
