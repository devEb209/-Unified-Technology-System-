Q-SYSTEM + DFRAME — CONTRATO OPERACIONAL DA TESE DOS D

Documento canônico. Ele NÃO substitui a Tese dos D. Ele implementa o que a Tese
exigiu e não definiu: a medida (Q) e o transporte (DFrame).

Hierarquia mantida:

  TESE DOS D → UTS → UES → SISTEMAS → EXECUÇÃO   (Tese, §94)

Este documento situa-se em dois lugares ao mesmo tempo:
é a operacionalização do §33/§98 da Tese, e é o contrato §37 (conversão) entre
UES e RRW definido pelo `REAL UES`.

CONFLITO ENCERRADO POR ESTE DOCUMENTO

A Tese dos D governa a materialização. Onde qualquer outro texto da UTS definir
renderer, material, pipeline gráfico ou "qualidade" de forma incompatível com a
cadeia

  REALIDADE → CONHECIMENTO → TESE DOS D → REPRESENTAÇÃO → D-O15 → RRW → MATERIALIZAÇÃO → EXPERIÊNCIA

(`REAL UES:855`), a Tese e o `REAL UES` prevalecem e o texto anterior é
CONFLITANTE, não doutrina. Consequentemente:

- `REPRESENTAÇÃO ≠ RENDERIZAÇÃO`, `RendererBackend`, `Render Pipeline` e
  `WebGL2 RendererBackend` (todos apenas em `UTS.txt`) são OBSOLETOS como
  arquitetura. Podem retornar como nomes de adapter de exportação.
- `SingularityAIPROMPT.txt` é camada de produto/interoperabilidade: seu pipeline
  `MESH → MATERIAL → PBR` é válido somente na fronteira de exportação (§7 deste
  documento) e jamais como modelo interno da UES.
- `UtsDesignSystem.txt` descreve a UI GENESIS. "Renderer" ali é painel, não
  arquitetura.

Regra geral preservada de `UTS.txt:11-19`: versão mais recente vence; não
misturar versões sem justificativa; não inventar que algo está implementado.

---

PARTE 0 — DEFINIÇÃO DE Q

Q não é "qualidade". Q é:

«O grau no qual uma representação D continua adequada ao que precisa ser
preservado para o objetivo atual.»

Q não é escalar. Q é vetor de três componentes, cada um com classe própria de
medida:

  Qp — qualidade perceptual    (o que o observador humano pode notar)
  Qf — qualidade funcional    (o que precisa continuar funcionando)
  Qi — integridade informacional (o que precisa continuar reconstruível)

Q NÃO É UMA SOMA. Uma componente excelente não pode compensar uma componente
violada: representação visualmente perfeita que destrói informação necessária à
simulação não é "boa", é defeito. Por isso Q é tratado como vetor de requisitos,
com pisos por componente:

  Qp ≥ Qp_min
  Qf ≥ Qf_min
  Qi ≥ Qi_min

Q é relativo ao objetivo, nunca absoluto:

  Q = f(D, objetivo, contexto, observador, estado)

Exemplo normativo: montanha distante tem Qp relevante, Qf quase nulo, Qi pequeno.
NPC em combate tem os três relevantes, com Qf dominante. A mesma entidade pode
ter pesos diferentes por domínio no mesmo instante (Tese §76/§77).

---

PARTE 1 — CRITÉRIO DE SELEÇÃO (substitui o §98 da Tese)

O §98 atual (`D* = argmax(Q − C)`) é mantido como intuição e substituído como
critério operacional por um problema com restrições:

  D⃗* = argmin_D⃗  C(D⃗)
    sujeito a
      Qp(D⃗) ≥ Qp_min
      Qf(D⃗) ≥ Qf_min
      Qi(D⃗) ≥ Qi_min
      ΔInfo(D⃗) ≤ ΔInfo_max
      Function(D⃗) = intacta
      Stability(D⃗) = true          [definido em §1.3, não é predicado livre]

Motivo formal da substituição: `argmax(Q−C)` é compensatório e sempre devolve
resposta, inclusive quando nenhuma representação serve. `argmin C sob
restrições` é não-compensatório e **falha com nome** quando o objetivo é
insatisfaível. Essa falha nomeada é instrumento de diagnóstico, não defeito.

Isto é a formalização do §33 (Representação Mínima Suficiente) e do §97.

§1.1 — ΔInfo

ΔInfo não recebe métrica nova. É a soma de duas classes da taxonomia do §10:

  ΔInfo = informação_perdida + informação_aproximada

e obedece ao §80: se a informação não pode ser recuperada E é importante, ela é
PRESERVADA, não medida. `Qi` é o portador desse requisito (PARTE 4).

§1.2 — monotonicidade (axioma exigido, antes ausente)

`argmin C` só é correto se Q for monótono não-decrescente ao longo da escada de
D do domínio. Como o §68 e o §4 proíbem tratar D como escala de qualidade,
adota-se:

  §98.1 (novo). Nenhum D pode ser candidato do D-O15 sem que exista, para o seu
  domínio, uma escada explícita D₁ < … < Dₙ com Q monotônico e com medidor
  declarado por componente (Qp/Qf/Qi). D sem escada declarada está FORA do
  espaço de otimização e só pode ser usado por decisão humana explícita.

Isso vincula o §40 (10 requisitos para admitir um D novo) ao §98 e encerra a
criação de D por estética de resultado.

§1.3 — Stability

Stability não é booliano solto. É o conjunto de instrumentos do §82 aplicado por
região e por domínio, com uma única constante:

  downgrade permitido somente se  Q > Q_min + h
  upgrade   permitido somente se  Q < Q_min
  e         |Q(t) − Q(t−1)| < h_Q  por (região, domínio)

h e h_Q existem para que popping e oscilação `D3→D2→D3→D2` sejam
impossíveis por construção, não "evitados com cuidado". Isso separa
explicitamente "piora dentro do piso" (aceitável) de "transição visível"
(Stability) — popping pode ocorrer com todos os frames acima de Qp_min.

Consequência implementada (GEN-1): em `visual`, Qf e Qi são derivados das
capacidades declaradas do degrau (0.45/0.35 no D0 até 1/1 no D5) em vez de
1.0 em todos os degraus. Com a coluna plana, nenhum piso numérico de visual
poderia vincular nada e `Qf ≥ 0.9` era texto decorativo; a aresta
`physical D5 → temporal ≥ 5` (CCD sem tick por frame tunela) é o segundo caso
em que a coerção é restritiva de verdade, não preferência de renderização.

§1.4 — desempate (corrigido pela implementação, GEN-1)

Empate de custo **não** escolhe maior folga. A regra que `packages/do15`
implementa é, em ordem:

  1. min C                     (o objetivo de §98 é minimizar custo)
  2. empate dentro de ε_C:      manter o D atual se ele está na banda mínima
                                (estabilidade custa zero; trocar por nada gasta a
                                troca — §82)
  3. persistindo o empate:      menor |Q − Q_min| (folga mínima acima do piso),
                                não a maior
  4. ainda empatado:            menor D

Motivo da correção: `maximize Q_margin` faz D0 e D5 empatarem em folga zero
quando não há requisito, e o desempate escolhe então o topo da escada — a
formulação original reintroduzia o superdimensionamento que §33 proíbe, com
`Q_margin` crescente sem custo. O teto previsto por ΔCtx(t+H) (Tese §83/§84)
deixa de ser regra de seleção e passa a ser **nota na decisão**
(`marginCeiling`): registra que a folga escolhida cabe na deriva prevista, sem
comprar qualidade extra por ela. Se a engine passar a ter custo de troca
(medido, §11), a regra 2 vira `ΔC ≥ switchCost` e o `h` numérico perde o papel.

---

PARTE 2 — MEDIDA DE Qp

2.1 Qp é medido por comparação entre representação de referência e candidata:

  D_ref → REF (alta fidelidade)      D_cand → CAND
  (REF ↔ CAND) → avaliação → Qp

2.2 Qp tem três termos. A decomposição espacial isolada NÃO basta:

  Qp_spatial   diferença de luminância/estrutura por região
  Qp_chromatic diferença de cor/cromaticidade (e, em D alto, de distribuição
               espectral — ver §2.5)
  Qp_temporal  diferença perceptual INTEGRADA no tempo:
                   ∫|∂IMG/∂t|dt  vs  ∫|∂REF/∂t|dt

Qp_temporal é o termo que torna "fluidez percebida" mensurável sem usar FPS.

2.3 PROIBIÇÃO NORMATIVA (Tese §70): nenhuma componente de Q é FPS, RAM,
resolução, contagem de polígonos ou clock. Qualquer métrica que termine usando
um deles como proxy de qualidade é erro de implementação, não otimização. Frame
budget (orçamento de tempo por região) é um RECURSO do `C`, nunca um termo de `Q`.

2.4 Dois modos de operação, obrigatórios. `REF` não pode existir no caminho
quente — calcular a representação de alta fidelidade é exatamente o que o
D-O15 existe para evitar.

  modo=ESTIMATE  caminho quente  Q̂ estimado por proxy barato
  modo=MEASURE   amostrado      REF↔CAND real, calibra o estimador

O estimador é aceito região por região pela sua discrepância medida contra o
MEASURE. Isto é o que satisfaz Tese §39 e `UTS.txt` PROMPT 4/4 §5
("Não aceite 'otimizado' sem medição") usando a mesma máquina. Consequência de
contrato: todo requisito de Q declara seu modo; requisito sem modo é rejeitado.

2.5 Base científica assumida, declarada como conhecimento e não como invenção.
A UTS não finge que o problema é novo; ela o aplica onde a indústria não aplica
(§7 da Parte de Âncoras). Componentes reutilizáveis:

- modelo de limiar perceptual para métrica de erro físico em síntese de imagem
  (Ramasubramanian, Pattanaik, Greenberg, SIGGRAPH 1999) — demonstrou
  economizar amostragem de iluminação global mantendo resultado
  visualmente indistinguível, usando ~6% das amostras da solução de
  referência; os próprios autores declaram que o modelo NÃO incluía cor nem
  processamento temporal. Nossos Qp_chromatic e Qp_temporal são exatamente a
  lacuna declarada por eles.
- métricas de vídeo perceptual com resultado em "just-noticeable difference"
  (FovVideoVDP), já usadas como critério de aceitação em rendering fovelado.
- tone mapping com modelo psicofísico em tempo real na GPU (Pattanaik et al.,
  2000) — precedente de que modelo perceptual pode rodar em taxa interativa.

Nada disso é padrão de indústria de engine; é literatura de pesquisa que os
pipelines comerciais de tempo real nunca adotaram como critério arquitetural.

---

PARTE 3 — D⃗ OPERACIONAL

Por entidade e por domínio:

  D⃗ = [Dv, Dp, Db, Ds, De, Dt]     (Tese §78)
  D⃗(t) = f(contexto, prioridade, recursos, estado)   (§79)

Cada componente tem `D_min`, `D_max`, `D_current`, `D_target` por domínio
(Tese §43/§44), com escada declarada conforme §1.2.

Domínios reconhecidos no GEN-1: `visual`, `physical`, `temporal`. Os demais
(`behavioral`, `social`, `economic`) existem como slots do contrato e ficam
FORA DE ESCOPO da primeira geração — fora de escopo declarado, não "fica para
V2": a Gênesis não empurra capacidade que ela definiu para si (`REAL UES:206`).

---

PARTE 4 — O DFRAME (contrato de transporte)

O DFrame é o estado operacional do D⃗. É a camada de conversão do §37.
Frame ≠ objeto gráfico: é uma DECRIÇÃO de representação, não uma cena.

DFrame {
  schemaVersion, engineVersion,        // imutável: §5.4
  regionId,                            // unidade primária de decisão
  entities[],                          // deltas por entidade dentro da região
  domain,                              // visual | physical | behavioral | social | economic | temporal

  DMin, DMax, DCurrent, DTarget,       // do domínio declarado, não do objeto inteiro
  Priority,                            // Tese §75, dinâmico
  CostBudget,

  QualityRequired {
    Qp, Qf, Qi,                        // pisos por componente; soma é proibida
    class: PERCEPTUAL|FUNCTIONAL|INFORMATIONAL,
    mode: ESTIMATE|MEASURE
  },

  Representation,                      // allowlist de tipos — §4.2
  OmittedFacts, RecoverySet,           // tornam Qi verificável — §4.3
  Hysteresis { h, h_Q, lastChangeT },  // Tese §82
  Predicted { D_expected, horizon },   // Tese §83/§84
  Measured { Q_real, C_real, source }, // fecha o ciclo mede→valida→feedback
  Provenance { decisionId, inputsHash, dO15Version }
}

4.1 Um frame por (região, domínio). Uma entidade não gera um frame; ela gera um
delta dentro do frame da sua região. Isso é exigência de escalabilidade, não
conveniência (§5.1).

4.2 ALLOWLIST DE TIPOS (regra estrutural, não estética). `Representation` aceita
somente: números, enums, IDs e chaves semânticas (`biome_code`, `material_class`,
`heightfield_ref`, `implicit_sphere`, `spectral_band_code`). Primitivas
geométricas recursivas, arrays de vértice/texel e bytecode de shader são
REJEITADOS na serialização.

Justificativa: é a única forma de a proibição do `REAL UES:11-17`
(`asset → mesh → material → shader → raster/RT → GPU → tela`) sobreviver ao
trabalho de implementação. Declaração não impede deriva; tipo impede.

4.3 RecoverySet. Tese §81 exige que, quando a transformação não for reversível,
os dados necessários para reconstrução sejam preservados explicitamente. Sem
este campo, Qi é promessa do executor, não restrição verificável. `Qi` é
avaliado como: *o conjunto de fatos omitidos ⊇ o mínimo exigido por DTarget*,
com reconstrução testada por amostragem.

4.4 Conteúdo do Representation (o que o RRW materializa a partir de códigos).
O frame transporta referências semânticas; o RRW possui a base de conhecimento
de materialização e as expande. Este é o ponto que resolve "o que o renderer
recebe se não é mesh": recebe um código de matéria e um nível, e expande por
conhecimento próprio, exatamente como o `REAL UES:130-137` pede para terreno e
como §120 manda abandonar `albedo + normal + roughness + metallic` como
representação fundamental.

4.5 Imutabilidade de transporte. O DFrame não é mutável pelo executor. O
executor responde com um `ResultFrame { regionId, domain, DApplied, Q_measured,
C_measured, deviations[] }`. Nada de "renderer ajusta o LOD por conta própria":
isso é a inversão de dependência de `UTS.txt` PROMPT 6/6 §34, agora mecânica.

---

PARTE 5 — D-O15 COMO EXECUTOR

5.1 GRANULARIDADE. O D-O15 decide por (região, domínio), com exceções por
entidade apenas quando a REGRA DA IMPORTÂNCIA (Tese §49) marcar crítico. Um
argmin por entidade é uma segunda O(n) e faria o otimizador violar o próprio §33.
Precedente obrigatório a respeitar: o gargalo medido de `UTS.txt` PROMPT 6/6
§16 (500 NPCs ≈ 27 ms/tick; 2000 NPCs ≈ 216 ms/tick, causa: percepção O(n) por
NPC) foi resolvido por Spatial Grid (§17, "FASE A"). A mesma grade passa a ser
a unidade de orçamento. Consequência feliz: a "percepção indexada" deixa de ser
otimização pontual e se torna a geometria do D-O15, e o "orçamento por região"
da GEN-1 ganha uma unidade concreta que já existia por outro motivo.

5.2 Acoplamento preservado: o frame vai para a região; a região devolve a lista
de entidades que contém. O RRW não conhece as entidades fora da região; a física
não conhece a grade; o NMN não conhece a estrutura espacial (Tese/`UTS.txt`).

5.3 Ciclo completo (normativo):

  CONTEXTO → OBJETIVO → REQUISITOS Q → TESE DOS D → D-O15
    → candidatos D⃗ (somente escadas válidas, §1.2)
    → estimar Q̂ (modo=ESTIMATE) e C
    → aplicar restrições + histerese (Schmitt) + desempate de §1.4
    → ponto fixo por ELEVAÇÃO de pisos entre domínios (prereq)
    → descida acoplada em ordem topológica inversa (I11)
    → verificação do orçamento do frame inteiro (não por domínio)
    → D⃗*
    → DFrame (região × domínio)
    → conversão (§37)
    → sistema executor / RRW → MATERIALIZAÇÃO
    → ResultFrame com Q real medido
    → validação: Q̂ vs Q_real
    → recalibração do estimador
    → próximo ciclo

5.4 Versionamento do contrato. O D⃗ é contrato entre decisão e materialização e
muda quando novos D entram (Tese §40/§41). `schemaVersion`/`engineVersion` são
obrigatórios, com migração explícita e erro explícito — mesmo padrão já
estabelecido para persistência em `UTS.txt` PROMPT 6/6 §51/§52 ("não inicialize
silenciosamente uma realidade vazia"). Frame de versão desconhecida falha: não
materializa o nível errado em silêncio.

---

PARTE 6 — FALHA

Infeasível é resultado nomeado, não degradação:

  E_INFEASIBLE { regionId, domain, bindingConstraint, requiredQ, bestAchievedQ,
                  availableResources, suggestion }

Sugestão é uma de: reduzir Q_min (exige decisão humana se o requisito vier de
objetivo absoluto, níveis 1 e 2 de `PromptTeseDosD.TXT`), aumentar
recursos, ou aceitar `Function` parcialmente. O sistema NUNCA resolve
inviabilidade rebaixando Q silenciosamente: isso é exatamente a "degradação
aleatória" proibida por `UTS.txt` PROMPT 6/6 §62.

---

PARTE 7 — INVARIANTES TESTÁVEIS

Cada regra acima vira teste determinístico. Sem teste, é prosa.

  I1  Nenhum DFrame serializado contém vértice, texel ou bytecode de shader.
  I2  Todo D candidato possui escada com Q monotônico; candidato sem escada é
      rejeitado antes de entrar no argmin.
  I3  Nenhuma métrica de Q retorna FPS, RAM, resolução ou contagem de
      polígonos como valor de Q (proteção do §70).
  I4  Round-trip: abstrair → materializar → reconstruir reproduz os fatos do
      RecoverySet (prova de Qi, §80/§81).
  I5  Uma descida só é recusada quando as três condições valem ao mesmo tempo:
      o degrau de destino NÃO está na banda de custo mínimo, o D atual declara
      perdas (`drops ≠ ∅`, logo a volta não é grátis) e sua folga sobre o piso é
      < h. A banda é cumprida no estado que se DEIXA (gatilho de Schmitt: banda
      de saída h, de entrada 0). É esta a forma operacional de §82; "proibir
      descer sem folga" sem a cláusula de reversibilidade gerava regiões presas
      em D caro por inércia, e foi refutado por teste (O9/O10/O11 em
      packages/do15/test).
  I11 Nenhum domínio termina com D acima do que a soma dos pré-requisitos dos
      seus dependentes + o seu próprio piso exige (descida acoplada). Sem I11 o
      ponto fixo por elevação converge para um máximo disfarçado de mínimo.
  I6  erro(Q̂_ESTIMATE, Q_MEASURE) ≤ ε por região; se violado, a região é
      forçada a modo=MEASURE até reconvergir.
  I7  DFrame com schemaVersion incompatível produz erro explícito, nunca
      materialização silenciosa.
  I8  Todo QualityRequired declara `class` ∈ {PERCEPTUAL, FUNCTIONAL,
      INFORMATIONAL}; requisito sem classe é rejeitado (garante que a
      tri-partição do §16 seja aplicada por dados, não por hábito).
  I9  Nenhuma decisão do D-O15 excede orçamento por frame: custo medido do
      próprio otimizador entra em C (o otimizador obedece ao §33).
  I10 Nenhuma alteração de C reduz Q abaixo de Q_min em nenhum domínio
      (a "otimização sem destruir o resultado", `UTS.txt` PROMPT 2/4 §11).

---

PARTE 8 — GÊNESIS (GEN-1) DENTRO DESTE SISTEMA

GEN-1 é a primeira geração em que o D-O15 decide por diferença perceptual, e
não por distância/LOD herdado da indústria. Escopo: terreno, céu, luz,
atmosfera, água e UM material real por princípio — com orçamento por região
(Parte 5) e histerese calibrada. Não inclui economia, sociedade, áudio e
animação: estes são slots do contrato, fora de escopo declarado.

Critério de sucesso da GEN-1 (número, não adjetivo): em hardware fraco, a
GEN-1 deve preservar Q ≥ Q_min por região a custo C menor que o de um pipeline
convencional na mesma cena; em hardware forte, deve exceder a qualidade do
pipeline convencional ao mesmo custo. Falha da GEN-1: delta perceptual acima
do limiar, orçamento estourado, corte percebido pelo usuário, ou E_INFEASIBLE
emitido em cena que um preset convencional desenha.

Os precedentes de §2.5 (≈6% de amostras com resultado visualmente
indistinguível; 40% de economia de energia com QoE preservado em rendering
fovelado) são a evidência de que a meta é fisicamente atingível. Não são a meta
garantida: exigem medição própria.

---

PARTE 9 — ÂNCORAS (o que é novo e o que não é)

Declarado para que ninguém, incluindo uma IA, venda isto como invenção do zero.

JÁ EXISTE COMO CIÊNCIA (não é diferencial, é fundação reutilizada):
- erro perceptual para limitar precisão de iluminação global (1999);
- métricas de qualidade perceptual por JND para vídeo/rendering (FovVideoVDP);
- modelos psicofísicos de tone mapping em tempo real na GPU (2000);
- orçamento perceptual como técnica real em produção (rendering fovelado, com
  economia de energia da ordem de 40%).

NÃO EXISTE NA INDÚSTRIA (aqui mora o diferencial, e é estrutural):
- nenhum pipeline comercial de engine usa diferença perceptual como UNIDADE DE
  TRABALHO da arquitetura; usam-na, quando usam, como pós-processo ou
  economia de amostras dentro de um rasterizador triângulo-por-triângulo;
- nenhuma engine estende o orçamento perceptual a física, comportamento,
  sociedade e economia sob um único vetor D⃗ — isto é a tese do LOD conceitual
  (Tese §21) aplicada de verdade;
- nenhuma engine tem um IR de materialização proibido por tipo de carregar
  mesh: a cena é o contrato em toda engine existente;
- nenhuma engine trata infeasibilidade como resultado nomeado em vez de preset
  rebaixado.

Conclusão honesta: a UTS não precisa de física nova para ser fora do padrão.
Ela precisa aplicar em arquitetura uma ciência que tem décadas e que a
indústria nunca adotou como critério organizador, e estendê-la além dos
gráficos — que é onde a Tese dos D é a única peça do sistema com escopo maior
que o de qualquer engine existente.

---

PARTE 10 — O QUE ESTE DOCUMENTO NÃO RESOLVE

1. Valor numérico de Qp_min, Qf_min, Qi_min e h por domínio. Isso é
   calibração psicofísica mediada por observador humano. Pode ser semeada por
   JND/literatura e corrigida por medição; não pode ser inventada.
2. Custo real de C em hardware alvo: nenhum número deste documento vale sem
   profiling no dispositivo físico.
3. A definição dos demais D da Tese (o §43 só lista campos). O que está definido
   é o mecanismo de admissão (§40, §41) e agora a exigência de escada (§98.1).
4. `D máximo` continua AUSENTE: `UTS.txt` PROMPT 2/4 §9 manda recuperar a
   definição "mais recente existente no projeto" e ela não existe nos arquivos
   do repositório.
5. O nome da UES ainda aparece de duas formas no corpus. Este documento segue a
   Tese (`UES — Unified Engine System`, igual a `UTS.txt:489`);
   `Universal Engine of the Singularity` (`PromptCompleteVersionV1Snb.txt:2464`,
   `PromptFinalV1Singularity.txt:565`) é tratado como OBSOLETO. Corrija os dois
   arquivos ou declare a precedência, para não deixar a próxima IA arbitrar.
6. Estado real do repositório: 11 documentos de prosa, 1 imagem, zero código, 1
   commit em `main`. O commit `a7a6722` e os "95/95 testes" citados em
   `UTS.txt:1661` não existem neste repositório. Nada aqui foi implementado.
