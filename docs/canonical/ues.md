# UES — arquitetura da engine (aplicação principal)

> **UES ≠ UTS.** A UES é a aplicação principal da UTS — o engine que roda
> mundos/simulações. A UTS é maior.

## Componentes

### World
- terreno determinístico por seed (`fbm`/`valueNoise`);
- biomas por regra (altura+umidade) + **zonas** criadas pela IA (prioridade);
- camadas semânticas **abertas** (7 padrões; `addLayer` em runtime);
- **streaming** por foco: load (heightfield+contexto+recursos, 1x) / unload
  (entidades abstraídas, **estado preservado**) / LRU `maxLoadedChunks`;
- **raio de materialização ajustável** (`focusRadius`) — o D-O15 do engine
  encolhe/restaura sob pressão/folga;
- ambiente como entidade RRW com processos `env.day-night` + `env.weather`
  (Markov clear→rain→storm, temperatura, vento, relâmpagos);
- **fogo**: raio → `weather.lightning` → fogo (processo `fire`: consome,
  propaga, apaga) — cadeia causal no RRW;
- `WorldAdapter` (contrato da IA) + `checkInvariants()` (inclui validação
  causal).

### NMN (NPCs)
- necessidades (fome/energia/segurança/social) evoluem no tempo;
- decisão por **avaliação de utilidade** (necessidade + contexto + memória +
  relações + custo/risco) — não árvore de diálogo fixa;
- percepção limitada e **proporcional ao detalhe** (D-2/D-4 fracionário);
- memória (episódios + conhecimento + relações/trust);
- metas: comer/descansar/trabalhar/trocar/socializar/fugir/explorar;
- **trade com causa** (`npc.hunger`), trabalho com causa (`work.assigned`);
- estado no componente `Mind` (compress=identidade) → sobrevive à abstração.

### Sociedade
- grupos como **agregados semânticos** (produção/consumo por ofício, com
  feedback: precisa de comida para trabalhar);
- `society.famine.warning` com causa `society.stock.low`;
- mercado: preços por oferta/demanda;
- **grupos abstratos evoluem** (`abstractTick`) — mundo vivo fora do foco;
- indivíduos materializam quando relevantes.

### Gráficos
- camada **própria** que **interpreta** a realidade (representação > renderização);
- `RealLife`: chuva→wetness, vento+seca→poeira, tempestade→glow, haze —
  **aberta** (`addRule` para novos fenômenos em runtime);
- `Frame`: iluminação derivada do dia/noite, atmosfera, materiais (padrões +
  regras custom), sombras (oclusores + sol), entidades com **LOD 0–3**;
- backends: `NullBackend` (métricas) e `TextBackend` (ASCII).
  **Renderer GPU = FUTURE/plug point** — a abstração `RendererBackend` existe;
  a UES não se acopla a Vulkan/DirectX/OpenGL/WebGL.

### Engine
- relógio `SimClock` (fixed timestep 0.1s);
- D-O15: reanálise a cada 0.5s com pressão medida + relevância;
- scheduler adaptativo (5 sistemas, prioridade, orçamento do hardware);
- bridge IA (`optimizationReport`/`applyOptimization`);
- `autoOptimize()` (hardware adaptativo);
- **persistência** (`serializeUes/restoreUes/saveUes/restoreFromJson`).

## Mundo vivo (canônico, testado)

Quando o foco/observador se afasta de um local: o sistema **abstrai**
(não apaga), **atualiza** (processos abstratos), **preserva** estado,
**evolui** (sociedade/clima/fogo continuam) e **re-materializa** quando o
foco volta — estado íntegro.
