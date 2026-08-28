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

## ADR-013 — UTS é a PLATAFORMA; UES é a ENGINE (definição oficial)
UTS (antiga SNB) = plataforma geral: infraestrutura, serviços, IA, ferramentas
e recursos para criação e execução, com filosofia AI-first. UES = engine que
roda DENTRO da plataforma, usando sua infraestrutura, capaz de qualquer tipo
de experiência. UTS ≠ UES; UES ⊂ UTS; a UTS é estritamente maior. A UES é
registrada como serviço-consumidor (`ues`) no ServiceRegistry. Não reduzir a
UTS à UES; não reduzir a UES a um módulo. A UTS pode estar parcial desde que
TUDO que a UES necessita esteja funcional.

## ADR-014 — AI-first é a interface da plataforma
O usuário interage naturalmente por IA (`platform.ask()`), usando arquivos,
serviços e fontes como entrada. A IA agrega múltiplos providers/modelos
(incluindo todos os modelos acessíveis via Puter), mas a orquestração é do
Singularity Core: nenhum vendor é a inteligência. Conhecimento é validado por
TRIANGULAÇÃO (≥3 modelos sobre busca; consenso + conflitos reportados — e
`triangulated:false` honesto quando não há base suficiente).

## ADR-015 — Serviços conectados são ferramentas validadas
GitHub (e qualquer serviço futuro) entra como serviço da plataforma e é
exposto à IA apenas por tools validadas por schema. Tokens vêm de env/param,
são mascarados (`toString`/`toJSON`), nunca persistidos em snapshots, logs,
testes ou docs.

## ADR-016 — Criações grandes são PROJETOS duráveis
Pedidos que levam minutos a meses viram CreationProjects: planos decompostos,
executados por orçamento, persistidos em storage da plataforma e retomáveis
em qualquer sessão exatamente onde pararam. Passo que falha é logado e
persistido como falha — nunca marcado como feito.

## ADR-017 — Apps e mundos são EXPERIÊNCIAS da engine
A UES é engine geral: experiências são manifests (`world-sim`, `app`) com
rulesets que ligam/desligam sistemas do engine — gêneros são configurações,
não engines novas. Apps rodam na infraestrutura da plataforma (AppHost) e
podem ser orquestrados pela UES como qualquer experiência.

## ADR-018 — FILOSOFIA NATIVA (regra permanente)
A UTS/UES é construída **do zero** sempre que tecnicamente possível e
justificável: renderer, RHI/abstração gráfica, gerenciamento de recursos GPU,
materiais, iluminação, shadow mapping, instancing, culling, streaming, física,
áudio, storage, comunicação, ferramentas, pipelines, runtime. Dependência
externa apenas para o inevitável (driver de GPU, OS, protocolo/serviço
deliberadamente consumido — GitHub, Puter, LLM API) e sempre **isolada atrás
de interface própria**. Nada de coleção de wrappers.

Cada implementação nativa deve: (1) ter arquitetura própria; (2) API/contrato
próprio; (3) integrar-se aos sistemas existentes; (4) ser testável isoladamente;
(5) ter testes de integração; (6) ser mensurável; (7) respeitar D-O15
(adaptação medida, nunca degradação aleatória); (8) respeitar RRW (o estado/causalidade
vive no RRW, única fonte da verdade); (9) respeitar o scheduler da UES;
(10) ser independente de UI. Limitações são eliminadas implementando, não
plugando soluções prontas. Rótulos honestos (PLANNED/PARTIAL/FUNCTIONAL)
continuam obrigatórios.

GÊNESIS é a primeira onda dessa filosofia: RHI (`src/render/rhi.js`),
culling/matérias/iluminação próprios, streaming de terreno com residência por
anel de LOD, física de corpos com causalidade no RRW, áudio sintetizado
espacializado (encodeWav próprio), UTS-DB (journal append-only com replay,
transações, índices, compaction), Comm (rotas/timeouts/eventos entre módulos)
e o pipeline WebGL2 GÊNESIS (shadow mapping PCF 3×3, instancing 12
floats/instância, 4 point lights, precipitação).
