# Gerações da UES — modelo canônico (declarado pelo autor em 2026-09-02)

Este arquivo existe porque eu **interpretei errado** uma vez e corrigi depois. A
correção vira documento para não virar memória de sessão. Fonte: prompt
`PROMPT — UTS / UES E SUAS GERAÇÕES` (autor, 2026-09-02). Nada aqui é status de
implementação; status está em `docs/estado/`.

## 1. Hierarquia (o que eu tinha achatado)

- **UTS** = o ecossistema unificado. Não é engine, não é app, não é IA: é o
  conjunto que contém, coordena e integra UES, Singularity AI, Tese dos D, D-O15,
  NMN, mundo/simulação, física, persistência, ferramentas, automação, rede,
  análise, infraestrutura.
- **UES** = a **engine central** dentro da UTS. Engine **sistêmica** (mundo,
  terreno, gráficos, física, entidades, NPCs, IA, simulação, sociedade, economia,
  persistência, renderização, otimização, ferramentas, dados, criação, execução)
  — não é "uma engine gráfica".
- **RRW** é o que materializa dentro da UES. **Tese dos D** está acima da UTS como
  modelo de representação; **DsOS/KÄIRŌS** é camada de execução do ecossistema.

Regra derivada: integração nativa primeiro; dependência externa só quando a
solução nativa não existir ainda — e aí como adapter, nunca como fundação.

## 2. Gerações = eras de visão arquitetural, não versões numéricas

`V1.0 → V1.1 → V1.2` é a leitura proibida. Cada nome é mudança de **visão**, e
cada geração preserva o que funciona na anterior e supera o que precisa ser
superado.

| era | visão | o que significa em trabalho |
|---|---|---|
| 🌍 **V1-GENESIS** | construir a realidade | fundação: espaço, terreno, mundo, objetos, entidades, física, comportamento, sistemas, relações, dados, regras, ambientes; integrar UES + Tese dos D + D-O15 + mundo + simulação + NMN numa só visão |
| ⚜️ **V1-PRIMORDIAL** | descobrir e construir os **fundamentos** da realidade | não adicionar recursos: aprofundar princípios — leis, estruturas, causalidade, emergência, organização, transformação, abstrações, princípios universais de funcionamento |
| 🌒 **V1-DARKNESS** | o que existe **além** do que já sabemos representar | ápice da V1: confrontar os limites da arquitetura — regiões não exploradas, complexidade extrema, fenômenos difíceis de representar |
| 🌌 **V2-UNIVERSAL EVOLUTION** | a evolução sai de um mundo e passa à escala universal | múltiplos mundos, escalas gigantescas, evolução, sociedades, civilizações, fenômenos em escalas diferentes |
| 🧬 **V2-UNIVERSE SINGULARITY** | unificar e transformar sistemas complexos em estrutura singular | não é mais conteúdo, é **integração**: auto-organização, comunicação entre sistemas, uso dinâmico de recursos, redução de redundância, unificação de níveis de representação |
| 🌠 **V2-BIG BANG** | a tecnologia deixa de evoluir e inicia nova era | ruptura: fim de um ciclo e nascimento de outro, mudança de paradigma |

Síntese do autor: **construir → compreender → ultrapassar limites → expandir →
unificar → transformar.**

## 3. Onde o kernel atual toca cada era

Isto é o que o repo sustenta, medido por teste (107/107 em 2026-09-02), não
narrativa:

- **GENESIS** — sustentado em parte: escadas dos 6 domínios (`d-system`),
  representação por allowlist (`dframe`), decisão por célula (`do15`),
  materialização com Qp medido (`rrw-mat`), persistência de mundo (`world`),
  orçamento medido no aparelho (`cli/measure`), veredito de apresentação
  (`do15/present`). **Falta para a era estar completa:** terreno/asset como
  código, NMN (`behavioral`), social/econômico, execução multi-dispositivo.
- **PRIMORDIAL** — hoje só existe como **matéria-prima**, não como era: a
  formalização de Q⃗ = [Qp, Qf, Qi] como restrições (não soma) e o piso perceptual
  são fundamentos escritos; falta elevar a escada de coeficientes medidos no
  aparelho a **lei** (regressão `cost` ↔ tempo real) e transformar §33/§80-82
  (suficiência, reversibilidade, histerese) em invariantes verificáveis em runtime.
  Fronteira honesta: *leis* de causalidade e emergência não estão escritas em lugar
  nenhum deste repo. Não vou afirmar que V1 fica completa sem PRIMORDIAL.
- **DARKNESS** — não tem código, e é o caso em que "dá para fazer" é a frase
  errada: por definição é o que a arquitetura ainda não sabe representar. O que
  posso fazer é preparar o instrumento (auditoria real-vs-renomeado, `E_INFEASIBLE`
  nomeado, piso que recusa em vez de degradar), porque é ele que vai dizer onde o
  limite está quando formos batido nele.
- **V2** — a única garantia que dou agora é estrutural: escada é array, frame é
  lista de chaves permitidas, materializador é mapa capacidade→termo. Adicionar
  domínio/era não reescreve o otimizador — foi assim que `behavioral`/`social`/
  `economic` ficaram como slot declarado sem quebrar nada.

## 4. Consequência prática para a GÊNESIS (V1-1)

O `REAL UES:825-835` ("não empurre o RRW/arquitetura gráfica/física fundamental/
capacidade de criação para V2; V2 existe para **superar** a Gênesis") é coerente
com este modelo e com ele concordo: as eras **dentro** da V1 têm de fechar a
fundação, e a expansão de escala é o que define V2. Portanto ordem de trabalho da
era atual é: terreno/asset → NMN → social/econômico → execução no aparelho — e não
"melhorar gráficos".
