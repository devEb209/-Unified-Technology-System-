# Decisões — versão vigente (e o que está pendente de ratificação)

> **Este arquivo é histórico-operacional. A separação CANON vs
> RECONSTRUÇÃO vs LIMITAÇÃO canônica vive em
> [`canonical/README.md`](canonical/README.md) (matriz canônica) —
> use aquela como fonte primária.**

Regra do usuário: **usar sempre a versão mais recente**; versões antigas são
obsoletas; nunca misturar duas versões sem justificar; não ressuscitar
conceitos antigos. Este arquivo registra a versão vigente de cada decisão e
marca explicitamente o que foi **reconstruído** (não recuperado).

## Vigentes (fonte: prompts do usuário)

| # | Decisão | Vigente (última versão) | Efeito no código |
|---|---|---|---|
| 1 | Representação por materialização | Abstração ⇄ materialização; **estado NUNCA se perde**; materialização por foco + limiar (0.5) + rampa na zona ativa | RRW `detail`, `materialize/abstractize`, `materializeForFocus`, `MATERIAL_THRESHOLD` |
| 2 | RRW | **Cobrir TUDO DA REALIDADE** — aberto/extensível, nunca lista fechada (sistemas, objetos, entidades, agentes, fenômenos) | categorias/componentes/camadas/processos/agentes abertos em runtime |
| 3 | D (Tese dos D) | **Camadas funcionais/conceituais, NÃO dimensões físicas**; valores fracionários; cada D com efeito operacional verificável | `src/d` (fracionário, min..max, `downgradedFrom`) + testes por D |
| 4 | D-MAX | **RECONSTRUÍDO** — ver abaixo | `max()` dinâmico em `TeseDosD` |
| 5 | D-O15 | Otimização inteligente — **mesmo resultado, mais eficiência** (não "reduzir qualidade"); sem claim de otimização sem medição | `StrategyEngine`/`Profiler`/`AdaptiveScheduler` + testes medidos |
| 6 | Otimização adaptativa | Por pressão real + relevância + criticidade; piso para críticos (mundo nunca morre) | bandas 0.5/0.9; piso 10% no minHz |
| 7 | Hardware adaptativo | Perfis + detecção; degrada/promove pelo orçamento/tick | `HARDWARE_PRESETS`, `detectHardware`, `autoOptimize` |
| 8 | Singularity AI | **Não é chatbot** — orquestra planejamento/modelos/ferramentas/agentes/memória; IA constrói a cena, não "conversa" | `SingularityCore` (plano→execução→verificação→correção) |
| 9 | Modelos | Seleção por **tier + capacidades + custo**; o mais barato suficiente | `ModelRegistry.select` |
| 10 | Puter | **Provider opcional** (acesso), nunca o coração; arquitetura desacoplada de provider único; browser-only | `PuterProvider` com `isAvailable()`; `HeuristicProvider` local |
| 11 | Ferramentas | Operam no mundo real (WorldAdapter); a IA lê/aplica otimização | `createDefaultTools`, bridge no World |
| 12 | Agentes | Especializados (world-builder, npc-designer, optimizer, inspector, verifier, orchestrator) | `createDefaultAgents` |
| 13 | Memória | Curto (ring+TTL) + longo (importância+decaimento) + decisões (latest-wins) | `MemorySystem` |
| 14 | Real Life | Fenômenos coerentes (chuva molha; vento+seca→poeira; tempestade→glow) com estado temporal | `RealLife` |
| 15 | UES | **UES ≠ UTS** — UES é aplicação principal; UTS é maior; camadas: UTS⊃(RRW+D+O15+AI)⊃UES | estrutura do repo + `src/index.ts` |
| 16 | NMN (NPCs) | Princípios de realidade (identidade/objetivos/necessidades/memória/relações/knowledge/contexto/percepção/experiências/consequências) — **sem árvore de diálogo fixa** | `src/ues/npc.ts` (utilidade) |
| 17 | Representação adaptativa | Grupo=agregado (mundo vivo fora do foco); indivíduo=detalhe (só materializado) | `Society.abstractTick`, NMN `isMaterial` gate |
| 18 | Testes por escala | Pequeno/médio/grande/extremo; extremo usa abstração (custo D-1); D-O15 mantém resultado sob orçamento | `test/scale.test.ts` |
| 19 | Gráficos | Camada PRÓPRIA (não isolada); backends abaixo da abstração; frame deriva do estado | `src/ues/graphics.ts` |
| 20 | Causalidade | Todo evento relevante traz causa (by+event); cadeia verificável | `RRW.causalChain` + testes |
| 21 | Relógio | `SimClock` + relógio de frame; ticks determinísticos (fixed timestep) | `Engine.tick` (dt=0,1 s) |
| 22 | Mundo aberto | Chunks/streaming/contexto; recursos por chunk; biomas por regra + zonas da IA | `src/ues/world.ts` |
| 23 | Fogo | Fenômeno emergente (raio→fogo→propagação), com causa no RRW | processo `fire` |
| 24 | Ambiente | Dia/noite + clima (Markov) + temperatura/vento — como entidade com processos | `env.day-night`, `env.weather` |
| 25 | Estruturas | Casa/mercado/fortaleza/templo — mercado com estoque/preços | `spawnStructure` + `market.prices` |
| 26 | Sociedade | Grupos com população/estoque/produção/consumo; famine com causa; preço por oferta/demanda | `src/ues/society.ts` |
| 27 | Escala | Múltiplas escalas de NPCs; D-O15 adapta; invariants em todas | `test/scale.test.ts` |
| 28 | Escopo | **Parar no maior estado funcional/integrado/testado possível dentro dos limites reais do ambiente**; o relatório final não substitui implementação | tudo acima + `docs/status.md` |
| 29 | Entrega | Construir → validar → relatar (sempre, nesta ordem) | suíte de 76 testes + demo + docs |
| 30 | Qualidade | Nada de "fake demo", interfaces vazias ou comentário como implementação; mock rotulado como mock | auditável por teste |

## Reconstruções e propostas (marcadas — pendentes de ratificação)

### 4. D-MAX — **RECONSTRUÇÃO (não recuperação)**
- **Fato auditado**: nenhuma definição de D-MAX existia no repositório
  (o único arquivo pré-existente era o logo). Os prompts dizem "D máximo"
  como conceito sem definição concreta recuperável.
- **Reconstrução adotada**: D-MAX é o **valor máximo dinâmico da tese** —
  `max()` = maior `value` entre as camadas registradas (cresce quando novas
  camadas entram, coerente com "RRW cobre tudo da realidade").
- **Justificativa**: mantém a tese aberta (nova camada → teto sobe), permite
  fracionamento e não fixa um número arbitrário.
- **Status**: implementado e testado, **pendente de ratificação** do
  usuário. Se a definição correta for outra (número fixo, por exemplo), a
  troca é pontual em `TeseDosD`.

### Acronimo RRW — **proposta**
- Nenhum nome formal de RRW existia no repo. Proposta: **"Real World
  Representation"** (representação aberta do mundo real). Proposta — pode
  ser renomeada sem afetar a API.

### HeuristicProvider — **rotulado**
- É uma camada **local, determinística e funcional** (não é um LLM). Rotulada
  como tal em `docs/status.md` e `README.md`. Modelos reais (LLM) entram via
  `ProviderRegistry` sem mudar o core.

## Regra de materialização ativa (detalhe operacional)
- `MATERIAL_THRESHOLD = 0.5`; `materializeForFocus(fx, fy, outer)`:
  - distância ≤ raio interno → detail 1;
  - raio interno < distância ≤ raio externo → rampa `0.5..1` (piso 0.5);
  - fora → abstrata (0) se estiver carregada;
- chunk descarregado → entidades abstraídas, **estado preservado**
  (Heightfield comprimido; Mind/Position/relações preservados).
