# UTS — Status Real (auditoria honesta)

> Convenção: **FUNCTIONAL** (interface + implementação + integração + teste +
> uso real) · **PARTIAL** (existe, incompleto) · **PLANNED** (definido, não
> implementado). Nada aqui declara funcionalidade sem teste que a prove.

## Estado geral

- **160/160 testes** passando (`npm test`), determinísticos, zero dependências
  de runtime (132 pré-Gênesis + 28 novos dos sistemas nativos).
- **GÊNESIS (ADR-018)**: renderer/RHI/culling/materiais/iluminação/shadow
  mapping/instancing/streaming/física/áudio/UTS-DB/Comm — todos nativos, do
  zero, com testes próprios (`test/genesis-*.test.js`).
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
| **Streaming de terreno** (residência por anel 24/16/8, eviction, budgetMs) | **FUNCTIONAL** | 36 patches/38.980 bytes no demo; determinismo preservado |
| **Física nativa** (corpos=props RRW, impactos causais, sleep, raycast, broadphase) | **FUNCTIONAL** | cadeia de impacto verificável; D-O15 coarse reduz taxa de passos (medido) |
| **Áudio nativo** (synth/spatial/mixer/AudioDirector, encodeWav 16-bit) | **FUNCTIONAL** | WAV real de 215KB gerado no demo; SR adaptada por D-O15 |
| **UTS-DB** (journal append-only, replay, tx, índices, compaction, torn-tail) | **FUNCTIONAL** | `test/genesis-db-comm.test.js`; corrupção no meio falha alto |
| **Comm** (rotas, timeouts, pub/sub entre módulos) | **FUNCTIONAL** | rotas ask/research.validate/system.status na plataforma |
| **Renderer WebGL2 GÊNESIS** | **FUNCTIONAL** | shaders GLSL próprios, shadow PCF, instancing, culling, 4 point lights, chuva em GL_POINTS; GL mock (Node) + demo browser |
| Singularity Core (interpretar→planejar→executar→verificar→corrigir) | **FUNCTIONAL** | fluxo completo com HeuristicProvider; fallback de provider testado |
| ModelRegistry (tiers, custo, seleção mínima suficiente) | **FUNCTIONAL** | seleção por capacidade/custo testada |
| ExternalLLMProvider (OpenAI-compatível, generate/stream) | **FUNCTIONAL\*** | *\*validado contra fetch mock; contra API real requer `OPENAI_API_KEY` — nunca commitado* |
| PuterProvider (browser, access-layer) | **FUNCTIONAL\*** | *\*detectado/validado via globalRef injetado; requer browser com Puter* |
| Persistence (save/load, checksum, versão, migração, File/Memory) | **FUNCTIONAL** | corrupção falha alto; A==B após restore+ticks |
| Áudio playback no browser (WebAudio graph em tempo real) | **PLANNED** | síntese+mix+encodeWav FUNCTIONAL; falta destino de playback |
| Física avançada (ragdoll, juntas, rotação completa de corpos) | **PARTIAL** | solver de translação/impactos/sleep nativo; juntas/rotação livre PLANNED |
| LOD geométrico real (malhas por nível, não só resolução de amostragem) | **PARTIAL** | anéis de residência 24/16/8 FUNCTIONAL; malhas alternativas PLANNED |
| Busca web real (provider HTTP para research) | **PLANNED** | interface SearchProvider pronta (mock funcional) |
| LLM externo real no loop | **FUNCTIONAL\*** | *\*ExternalLLMProvider validado contra fetch mock; API real via env, nunca commitada* |
| Banco de dados externo/cloud storage | **PARTIAL** | UTS-DB nativo FUNCTIONAL (journal/tx/índices); backend externo PLANNED |

## Limitações reais (honestidade)

1. LOD de terreno é por **resolução de amostragem** (24/16/8), não malhas
   geométricas alternativas por nível.
2. Física nativa resolve translação + impactos + sleep; corpos rígidos com
   rotação livre, juntas e ragdoll são PLANNED.
3. Terreno estático por (chunk,res) — deformação ao vivo ainda não existe.
4. Áudio sai como WAV sintetizado (arquivo/amostras); playback contínuo no
   browser (WebAudio) é PLANNED.
5. `world.set_weather` etc. mudam clima via cadeia causal; a máquina orgânica
   é estocástica por RNG — testes que exigem clima fixo rigam o RNG.
6. Benchmarks dependem do host; sementes e contagens são determinísticas.
7. Streams SSE do provider externo são mínimos (delta de texto).

## Próximas fronteiras (ordem técnica)

1. WebAudio em tempo real consumindo o AudioDirector (playback D-11).
2. LOD geométrico real: malhas por anel + impostores distantes.
3. Streaming assíncrono (workers) + cache LRU persistido no UTS-DB.
4. Autosave incremental de deltas (event sourcing via RRW → UTS-DB).
5. Rotação completa de corpos + juntas na PhysicsWorld.
6. LLM real no loop (chave via env) com structured output validado pelo Core.
