# Decisões confirmadas (canônicas)

Regra do usuário: **sempre a versão mais recente**; versões antigas são
obsoletas; nunca misturar duas sem justificar; não ressuscitar conceitos
antigos.

| # | Decisão (versão vigente) | Efeito no código |
|---|---|---|
| 1 | Representação por materialização: abstração⇄materialização; estado **nunca** se perde; foco + limiar 0.5 + rampa na zona ativa | `RRW.materialize/abstractize/materializeForFocus`, `MATERIAL_THRESHOLD` |
| 2 | RRW cobre **TUDO DA REALIDADE** — aberto/extensível, nunca lista fechada | categorias/componentes/camadas/processos/agentes abertos em runtime |
| 3 | D = **camadas funcionais/conceituais**, NÃO dimensões físicas; fracionário; cada D com efeito operacional verificável | `src/d` + testes por D |
| 4 | Valores fracionários (.25/.5/.75) têm **efeito comportamental real** | `behaviorScale` (percepção 0/0.5/1; ações coarse/fine; fogo escala) + testes |
| 5 | D-O15 = otimização inteligente: **mesmo resultado, mais eficiência**; sem claim sem medição | Profiler (PerfMeter), StrategyEngine, AdaptiveScheduler, raio adaptativo |
| 6 | Adaptação por pressão real + relevância + criticidade; **piso para críticos** | bandas 0.5/0.9; piso 10% no minHz; defer (não drop) |
| 7 | Hardware adaptativo: perfis + detecção; degrada/promove pelo orçamento/tick | `HARDWARE_PRESETS`, `detectHardware`, `autoOptimize` |
| 8 | Singularity AI ≠ chatbot — orquestra planejamento/modelos/ferramentas/agentes/memória | `SingularityCore` |
| 9 | Separação AI / Core / Provider / Model / Tool / Agent / Memory | registries separados |
| 10 | Modelos: seleção por **tier + capacidades + custo** (mais barato suficiente) | `ModelRegistry.select` |
| 11 | Puter = provider **opcional**, nunca a fundação; desacoplado de provider único; browser-only | `PuterProvider` (`isAvailable()`), `HeuristicProvider` local |
| 12 | Arquitetura pronta para provider real **sem reescrever o Core** | `ProviderRegistry.define` + teste com provider externo |
| 13 | Ferramentas operam no mundo real (WorldAdapter) | `createDefaultTools`, bridge |
| 14 | Agentes especializados | `createDefaultAgents` |
| 15 | Memória: curto (ring+TTL) + longo (importância+decaimento) + decisões (latest-wins) + load/serialize | `MemorySystem` |
| 16 | Real Life: fenômenos coerentes com estado temporal; **sistema aberto** (novos fenômenos em runtime) | `RealLife.addRule` |
| 17 | UES é aplicação principal; **UES ≠ UTS** | estrutura do repo |
| 18 | NMN: princípios de realidade, decisão por utilidade, **sem árvore de diálogo fixa** | `src/ues/npc.ts` |
| 19 | Representação adaptativa: grupo=agregado (mundo vivo); indivíduo=detalhe (só materializado) | `Society.abstractTick`, gate de materialização do NMN |
| 20 | Testes por escala (pequeno/médio/grande/extremo); extremo usa abstração (D-1) | `scale.test.ts` + `scale-probe.test.ts` |
| 21 | Gráficos = camada PRÓPRIA (representação > renderização); backends abaixo da abstração | `src/ues/graphics.ts` |
| 22 | Causalidade: consequência **não** aponta para causa inexistente; cadeia verificável | `validateCausality`, `checkInvariants`, causas reais (`work.assigned`) |
| 23 | Relógio: `SimClock` + ticks determinísticos (fixed timestep) | `Engine.tick` |
| 24 | Mundo aberto: chunks/streaming/contexto; recursos por chunk; biomas por regra + zonas da IA | `src/ues/world.ts` |
| 25 | Fogo emergente (raio→fogo→propagação) com causa no RRW | processo `fire` |
| 26 | Ambiente: dia/noite + clima Markov como entidade com processos | `env.day-night`, `env.weather` |
| 27 | Sociedade: grupos, produção/consumo, famine com causa, mercado oferta/demanda | `src/ues/society.ts` |
| 28 | Persistência preserva determinismo (RNG com estado exato) | `Rng.state/fromState`, `persistence.ts` + testes |
| 29 | Escopo: parar no maior estado funcional/integrado/testado possível; relatório não substitui implementação | este repo |
| 30 | Qualidade: nada de fake demo, interfaces vazias ou comentário como implementação; mock rotulado como mock | auditável por teste |
| 31 | Regra de honestidade: claim sem evidência é proibido; hipótese é marcada como hipótese | este documento + `provisional.md` |
| 32 | **CANON > RECONSTRUÇÃO** — suposição do agente nunca vira decisão oficial | este documento |

Ver histórico completo em [`../decisions.md`](../decisions.md) (tabela de
vigentes + regras operacionais).
