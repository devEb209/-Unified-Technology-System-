# UTS — Status Real (auditoria honesta)

> Convenção: **FUNCTIONAL** (interface + implementação + integração + teste +
> uso real) · **PARTIAL** (existe, incompleto) · **PLANNED** (definido, não
> implementado). Nada aqui declara funcionalidade sem teste que a prove.

## Estado geral

- **115/115 testes** passando (`npm test`), determinísticos, zero dependências.
- Cadeia completa funcional: objetivo → Singularity Core → RRW → mundo vivo →
  D-O15 → Frame → **WebGL2 real** (browser) / Null / Text.

## Sistemas

| Sistema | Status | Evidência |
|---|---|---|
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
| Frame extraction (LOD, agregados, áudio) | **FUNCTIONAL** | <1ms; derivado do estado (testado) |
| Renderer Null/Text | **FUNCTIONAL** | contam/manifestam o Frame exato |
| **Renderer WebGL2** | **FUNCTIONAL (v1)** | shaders reais, terreno do heightfield da UES, entidades, céu, chuva/poeira, LOD de terreno, uploads só-ao-mudar; validado contra GL mock (Node) + demo browser. Sem shadow mapping (blob/emissive apenas) |
| Singularity Core (interpretar→planejar→executar→verificar→corrigir) | **FUNCTIONAL** | fluxo completo com HeuristicProvider; fallback de provider testado |
| ModelRegistry (tiers, custo, seleção mínima suficiente) | **FUNCTIONAL** | seleção por capacidade/custo testada |
| ExternalLLMProvider (OpenAI-compatível, generate/stream) | **FUNCTIONAL\*** | *\*validado contra fetch mock; contra API real requer `OPENAI_API_KEY` — nunca commitado* |
| PuterProvider (browser, access-layer) | **FUNCTIONAL\*** | *\*detectado/validado via globalRef injetado; requer browser com Puter* |
| Persistence (save/load, checksum, versão, migração, File/Memory) | **FUNCTIONAL** | corrupção falha alto; A==B após restore+ticks |
| Audio (D-11) | **PARTIAL** | estado de canais no Frame; **sem** síntese/playback |
| Física | **PARTIAL** | movimento/intents/colisão-implícita-terreno; sem solver de forças/ragdoll |
| Sombras/atenção visual avançada | **PLANNED** | shadow mapping, água animada, vegetação, partículas GPU, pós-processo |
| Banco de dados/Cloud storage | **PLANNED** | interface StorageBackend pronta |
| Agentes 'coder'/'graphics' avançados | **PARTIAL** | registry + tuning de orçamento; sem geração de código real |

## Limitações reais (honestidade)

1. WebGL2 v1 desenha entidades por uniforms (sem instancing); D-O15 compensa
   limitando materialização (`maxMaterialized`).
2. Terreno estático por (chunk,res) — deformação ao vivo ainda não existe.
3. `world.set_weather` etc. mudam clima via cadeia causal; a máquina orgânica
   é estocástica por RNG — testes que exigem clima fixo rigam o RNG.
4. Benchmarks dependem do host; sementes e contagens são determinísticas.
5. Streams SSE do provider externo são mínimos (delta de texto).

## Próximas fronteiras (ordem técnica)

1. Instancing + frustum culling no WebGL2 backend (alimentar do D-O15).
2. Shadow mapping barato (1 pass) mantendo Frame como única verdade.
3. Streaming de chunks assíncrono (workers) + cache LRU persistente.
4. DatabaseStorage + autosave incremental de deltas (event sourcing via RRW).
5. Áudio sintetizado (D-11) consumindo `frame.audio`.
6. LLM real no loop (chave via env) com structured output validado pelo Core.
