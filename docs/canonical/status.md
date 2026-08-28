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
