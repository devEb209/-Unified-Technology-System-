# UTS — Decisões Canônicas (ADR)

Estas decisões são a **versão mais recente** e prevalecem sobre qualquer
versão anterior encontrada em histórico, código ou documentação.

## ADR-001 — RRW é representação aberta, não uma lista de assets
RRW representa entidades, propriedades, relações, eventos, causalidade,
processos, fenômenos, agregados — e categorias ainda não definidas. Novos
domínios entram sem reescrever o núcleo. **Nunca** reduza RRW a
"personagens + objetos + terreno".

## ADR-002 — D são camadas funcionais, não dimensões
Os D (D-0..D-14, D-O15) descrevem níveis de representação/integração/operação.
Cada D precisa de função verificável e efeito observável (`tese.touch`);
nomenclatura vazia é removida. Valores fracionários (D.x.25) são conceituais.

## ADR-003 — D-O15: defer, nunca descartar
Otimização = melhor representação para o resultado necessário. Sob pressão:
raio de materialização encolhe, percepção reduz resolução (fenômenos
importantes jamais são cortados), trabalho é ADIADO para a próxima janela de
orçamento. Decisões são logadas com razão. Nenhuma entidade é destruída por
otimização.

## ADR-004 — Puter é camada de acesso, não a inteligência
Providers (Heuristic, Puter, ExternalLLM) são access layers no ProviderRegistry.
A inteligência é o Singularity Core: planeja, seleciona modelo/ferramenta/agente,
executa, verifica, corrige, memoriza. Fallback chain garante controle do Core.

## ADR-005 — UES ⊂ UTS
UES é a aplicação-engine da arquitetura (mundos/experiências). UTS é maior:
a representação e seus princípios servem a qualquer sistema que precise
modelar realidade.

## ADR-006 — O renderer manifesta; nunca inventa
Frame é derivado do estado representado (RRW→UES→D-O15→Frame). O terreno
visual nasce do heightfield; clima nasce do RealLife; LOD nasce do D-O15.

## ADR-007 — Causalidade verificável por construção
`emitEvent({cause})` rejeita causas inexistentes. Decisões de NPC guardam
`because` + referências de evento. Cadeias atravessam abstração, streaming,
persistência e evolução.

## ADR-008 — RRW é a fonte da verdade
Grid espacial, cache de terreno e buffers de GPU são derivados. No restore,
o grid é reconstruído do RRW (settlements ficam fora do índice por serem
estacionários — alcançadas por id).

## ADR-009 — Determinismo com adaptação de hardware
RNG e relógio são estado serializado. Métricas de timing são evidência de
runtime: pressão/decisões do D-O15 não entram no snapshot; estratégia e
orçamento entram. `do15.pinned` garante replay determinístico (CI/testes).
Índices derivados ordenam resultados por id — a ordem nunca depende do
histórico de inserção.

## ADR-010 — Segredos fora do estado
API keys vêm de configuração (env/param), nunca de código, testes, logs,
snapshots ou documentação. Providers mascaram-se (`toString`/`toJSON`); o
Core persiste apenas o NOME do provider.

## ADR-011 — Texto livre de LLM não muta estado
Inteligência externa só altera a realidade por ferramentas validadas por
schema (ToolRegistry). Interpretação inválida → loop de correção → fallback
heurístico → relatório honesto (`ok:false`), nunca invenção.

## ADR-012 — Falhas de persistência são altas
Snapshot corrompido/incompatível → `SnapshotError` explícito. Nunca iniciar
uma realidade vazia em silêncio.
