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
materiais, iluminação, shadow mapping, instancing, culling, LOD, streaming,
física, áudio, sistemas de mundo, sistemas de simulação, storage, ferramentas,
pipelines, integração AI, comunicação entre módulos, sistemas de runtime.

**PRINCÍPIO ARQUITETURAL** — todo sistema é pensado primeiro como:
"como isso deveria funcionar **nativamente** dentro da UTS/UES?" e somente
depois: "existe dependência externa **inevitável** para uma camada
específica?". Se existir (driver de GPU, OS, protocolo/serviço deliberadamente
consumido — GitHub, Puter, LLM API), é **isolada atrás de interface própria**.
A questão nunca foi "nunca usar código externo": é que a UTS/UES deve possuir
sua própria implementação e arquitetura em tudo que está dentro do escopo que
podemos controlar. Nunca uma coleção de wrappers.

**Camadas nativas (forma canônica):**
```
UTS Audio    → nossa API → nosso mixer → nosso spatializer →
               nossos eventos (D-11) → backend de dispositivo (inevitável)
UTS Renderer → nossa arquitetura (Frame) → nossos materiais/lighting/
               culling/streaming/instancing/sombras → RHI próprio →
               backend gráfico (WebGL2 do browser — inevitável) → GPU
UTS Storage  → nossa API StorageBackend → UTS-DB próprio (journal/tx/
               índices/compaction) → FileSystem do OS (inevitável)
UTS AI       → nosso Core (objetivo→plano→executar→verificar→corrigir) →
               nosso ModelRegistry/AgentRegistry/ToolRegistry → provider
               externo isolado (Puter/LLM API — inevitável)
```

**"Podemos criar → devemos criar" (cumprido nativamente):** física
(`src/physics/physics.js`), áudio espacial/síntese (`src/audio/*`),
shadow mapping (`shaders.js`+`webgl2.js` PCF 3×3), instancing (12
floats/instância), RHI (`render/rhi.js`), DatabaseStorage (`persistence/utsdb.js`
— camada e implementação controladas pela UTS), orchestration de LLM
(`singularity/core.js`+`model.js`+`agents.js` — registry, fallback, structured
output validado). **Inevitável, não recriamos:** driver de GPU, sistema
operacional, serviço externo deliberadamente consumido.

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

## ADR-019 — REALIDADE PRIMEIRO: a correção fundamental da visão
A UES não é uma engine gráfica com sistemas bons: é uma **representação
computacional da realidade**. A referência primária é a realidade
("como isso funciona na realidade?" ANTES de "como aproximar
computacionalmente?"). Técnicas (LOD, impostors, ray tracing, shaders,
partículas) são **mecanismos de implementação/otimização**, nunca a
ontologia — não definem céu, água, fogo, som ou luz da UES.

Cadeia única e obrigatória: REALIDADE → MODELO CAUSAL (RRW) → SIMULAÇÃO →
PERCEPÇÃO → FRAME/ÁUDIO → HARDWARE. O Renderer, o áudio, a física e a IA
não são fontes de realidade; materializam a MESMA realidade. RealLife é
transversal (princípio, não módulo). Escalas são realidade (a cidade
distante é estado causal com menor granularidade, nunca textura).

**Regras supremas:**
1. NÃO SIMULAR A APARÊNCIA DA REALIDADE QUANDO PUDERMOS MODELAR A
   REALIDADE QUE PRODUZ ESSA APARÊNCIA.
2. NÃO OTIMIZAR DESTRUINDO A REALIDADE; OTIMIZAR A FORMA COMO A REALIDADE
   É REPRESENTADA, PRIORIZADA E MATERIALIZADA.

**Critério de completo (12 pontos)** — implementação própria, contrato
próprio, integração à realidade da UES, causalidade, persistência,
integração D-O15, testes unitários, testes de integração, medição,
demonstração real, independência de engine externa, e REPRESENTAR
CORRETAMENTE O FENÔMENO que afirma representar. Auditado em
`audit-vision.md` (re-baseline honesto: 89% → 70% sob a régua correta).
Visão completa em `vision.md`.

## ADR-020 — OFENSIVA GRÁFICA: APARÊNCIA É CONSEQUÊNCIA DA REALIDADE

**Status:** adotado (R7).

O UTS vai competir — e vencer — no eixo gráfico pelo único caminho que não
expira: **modelar a realidade que produz a aparência**, em vez de pintar a
aparência. A história confirma: luz assada → ray tracing; shaders ad-hoc →
PBR; sprites → volumétrico. Quem modela a física não reescreve o truque a
cada geração de hardware.

**Implementação (R7):** o céu do UTS é a INTEGRAL do espalhamento da luz
solar pelo ar ao longo do raio de visão (Rayleigh λ⁻⁴ + Mie com pico direto,
coisa de dezenas de linhas de física real — `src/render/scattering.js`).
A mesma constante física alimenta o espelho JS (testado: meio-dia azul,
sol poente vermelho, disco solar, noite, poeira dessatura) e o GLSL GERADO
(`SCATTER_GLSL`) que roda por pixel na GPU. A névoa cinza pintada foi
substituída por PERSPECTIVA AÉREA: `aerial()` integra o mesmo ar entre a
câmera e cada vértice/pixel — no infinito, objetos CONVERGEM para a cor do
céu porque É a mesma física. A atmosfera (`atmosphere.optics()`) é dona da
óptica (carga de aerossóis; nuvem/chuva atenuam); o renderer só integra —
nunca inventa cor. `frame.air` e `frame.sunDirTrue` carregam a verdade
física (sol não clampado — o céu vê o pôr-do-sol).

**Regra permanente:** toda técnica gráfica nova no UTS DEVE SER o fenômeno
(integração de física, solução de equações, propagação de onda/energia),
nunca pintura/ad-hoc. Proibido: gradientes de céu pintados, fog de cor
fixa, sprites de fumaça, HDR fake por LUT.
