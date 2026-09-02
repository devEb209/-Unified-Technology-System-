# GEN-1 — estado real do kernel (2026-09-02)

> Nomeclatura deste arquivo: "GEN-1" é a **era V1-GENESIS** (a primeira de seis,
> ver `docs/canonical/Geracoes-da-UES.md`) implementada neste repo. Não é "a versão
> 1 da engine inteira", e não é V1.1 de nada: as eras são mudanças de visão, não
> incrementos. Eu achatei isso numa resposta anterior; o documento existe para que a
> correção não dependa da minha memória.

Nada aqui é promessa. É o que roda, o que é medido e o que está aberto.

## Rodando hoje

```
npm test              # 88 testes, 0 falhas (d-system 17, dframe 18, do15 20, rrw-mat 12, world 10, cli 11)
npm run validate      # escadas válidas (validateAll() === [])
node packages/cli/run.js measure --iterations 400 --out device.json
node packages/cli/run.js plan --scene cena.json --device device.json --out plan.json
```

Zero dependências, zero build. TypeScript no type-stripping nativo do Node 22
(`--disable-warning=ExperimentalWarning`). Isto é deliberado: o GÊNESIS proíbe a
pipeline tradicional, inclusive a de ferramentas.

## O que cada pacote é

| pacote | função | o que garante por construção |
|---|---|---|
| `d-system` | escadas D0..D5 como dados | custo é RELAÇÃO (px/entidade/luz/volume), nunca constante; monotonicidade vem de `caps` cumulativos + qualidade derivada de capacidades |
| `dframe` | Representação Mínima Suficiente como formato | varre o objeto e recusa geometria em qualquer nível; allowlist de códigos; ledger de omissão obrigatório; todo erro nomeado |
| `do15` | `D* = argmin C` s.a. pisos | requisito nunca é satisfeito apagando capacidade; `E_INFEASIBLE` com restrição vinculante e dono da decisão |
| `rrw-mat` | MATERIALIZAÇÃO + medição de Qp | termo aditivo por capacidade ⇒ erro contra a cena completa é monótono por construção |
| `world` | estado persistente por célula | `tick` custa O(células acordadas); snapshot sem `schemaVersion` é erro, não mundo vazio |
| `cli` | `measure` + `plan` | devolve `plan.json` com calibração declarada e aviso quando o orçamento não decide nada |

## Três decisões que o código forçou contra o documento

Registradas porque foram o código dizendo que a formulação original estava errada:

1. **Desempate é menor folga, não maior.** `maximize Q_margin` fazia D0 e D5
   empatar em folga zero e escolhia o topo da escada — o superdimensionamento que
   §33 proíbe, reintroduzido pelo próprio critério.
2. **Histerese é gatilho de Schmitt com cláusula de reversibilidade**, medida no
   estado que se DEIXA, e estabilidade de mesmo custo é aceita sem banda. "Proibir
   descer sem folga" puro deixava regiões presas em D caro por inércia (25× o
   custo), refutado por teste.
3. **Fixpoint por elevação precisa do lado oposto.** Pré-requisito elevava o piso
   do vizinho e nada desfazia a elevação: a física ficava paga em D3 por uma
   exigência do visual que já tinha caído. Sem a descida em ordem topológica
   inversa, `argmin C` era nome, não propriedade.

## O que está ABERTO — e é aqui que mora a verdade do projeto

- **A escala de custo não bate com tempo.** No piloto de 78 células a utilização
  do quadro saiu 0,00003%. O orçamento não vinculou nada; a decisão veio toda
  dos pisos. Enquanto `cost` na escada não for calibrado contra tempo medido no
  aparelho, `argmin C` é um otimizador de qualidade-only — útil, mas não é
  "cabe no meu frame". O `plan.json` agora grita isso em vez de fingir.
- **`measure` mede CPU, não GPU.** Calibra o trabalho de materialização. Fill
  rate, banda e compilação de shader continuam desconhecidos aqui — este sandbox
  não tem GPU. Só o A70 responde.
- **Termos por luz/volume da escada ainda não têm contraparte no materializador**
  (declarado em `device.json.limitation`).
- **Nada foi desenhado.** A cena do piloto é sintética. O primeiro `scene.json`
  real é o do `nul-impacto`, com os `.glb` do usuário.
- **Render de verdade não existe ainda.** `rrw-mat` produz o campo por célula em
  CPU; não há backend GL, e a compilação de shader nunca foi verificada aqui.

## Número medido agora, no sandbox (x86-64, Node 22), para nada virar mito

Materializar uma célula 48×48 com 44 entidades: ~0,25 ms. Grade completa de 78
células: ~20 ms. Isto não é o A70 e não é raster — é apenas a evidência de que a
granularidade de célula (região, não entidade) está do tamanho certo para o laço
de decisão, que é a correção do erro dos 216 ms/tick do `UTS.txt` l.326-331.

## Piso perceptual medido no piloto (Qp ≥ 0,9 exigido pelo frame)

```
D5: Qp=1.000 aceita=true
D4: Qp=0.955 aceita=true
D3: Qp=0.686 aceita=false  → 724 células violando, pior erro 0.090 vs limiar local
D2: Qp=0.563 aceita=false
D1: Qp=0.069 aceita=false
D0: Qp=0.031 aceita=false
```

Isto é o que "não existe dial de reduzir gráficos" significa em código: abaixo de
D3 o corte é percebido, então o motor recusa e devolve o erro para o humano — não
um preset mais baixo.

## Frame generation (15 Hz de sim com cara de 30): a conta, não a promessa

`packages/do15/src/present.ts` (+ `packages/cli/src/present.ts`, subcomando
`uts present`) resolve a pergunta como aritmética por célula:

```
custo_tudo_a_dispHz   = pixels(D_visual) + sim(D_físico..econômico) × dispHz
custo_com_apresentação = pixels(D_visual) + sim × simHz/dispHz + reprojeção(0.0001/px × dispHz)
VALE  ⟺  estoura o deadline  E  o custo líquido cai ≥ 5%
```

O que sai da conta na escala do A70 (720×1612, tela cheia, 870k un/s — ordem de
grandeza medida no sandbox, **não** no aparelho):

| célula | sim | pixels | reprojeção | líquido | veredito |
|---|---|---|---|---|---|
| em foco, visual D4, 40 corpos | 0.06 ms | 8 ms | 4 ms | −3.98 ms | **não vale** |
| 2.400 corpos, física D4 | 4.6 ms | 8 ms | 4 ms | −0.34 ms | **não vale** |
| 12.000 corpos, física+temporal D5, visual no piso | 41 ms | 0.35 ms | 4 ms | +40.8 ms | **vale** |

Conclusão dura, e ela é o resultado — não um obstáculo: num telemóvel 720p o
custo de apresentar a tela inteira (~4 ms a 30 Hz, ~8 ms a 60 Hz) é da mesma
ordem do frame inteiro, então suavizar por reprojeção **só paga onde a simulação
domina** (multidões, agregados, física de destruição em massa). Na célula onde o
jogador está, o que falta é raster, e frame generation não cria banda — cria
latência (+1/simHz ≈ 66.7 ms nos corpos dos outros) e desoclusão.

Duas correções de modelo que saíram dos testes e não podem regredir:

1. o mapa de movimento é **lido do snapshot**, portanto é precificado **por
   pixel**; cobrar "uma amostra por entidade" fazia FG nunca caber em lugar
   nenhum — resultado que parece teórico demais costuma ser erro de modelo;
2. interpolação **não inventa**: entidade recém-nascida não é eased do nada
   (`delta = 0`, política `repeat`), e `t > 1` é devolvido marcado
   `predicted: true` — previsão tem de aparecer na conta, não sumir.

O caminho que **não** cobra latência é o livre de simulação (câmera, arma, UI a
dispHz): 0,48 ms na tela cheia, porque só a camada toda é que é barata de subir
de taxa. Isso é orçado dentro do mesmo veredito, não vendido como feature.

Isto é o que há de genuinamente novo aqui: DLSS-FG/FSR3-FG estimam fluxo a partir
**da imagem**; aqui o motor tem o estado (snapshot com `pos`/`vel` por entidade
viva, no mesmo frame que o otimizador decidiu), então o movimento interpelado é
físico e auditável — e o custo de latência é idêntico, não é driblável.

`examples/scene-a70.json` + `examples/scene-a70.device.json` rodam o fluxo
`plan → present` sem aparelho; o device ali é placeholder declarado e o
`present` recusa rodar sem `device.json` medido.

## O elo EXPERIÊNCIA agora tem superfície: `uts demo`

`packages/rrw-mat/src/render.ts` materializa o campo (luminância + croma por célula)
em PNG escrito à mão (IHDR/IDAT/IEND + CRC conferidos em teste R1 — um arquivo que
"o navegador abriu" não é evidência de estar conforme a spec) e
`packages/cli/src/demo.ts` serve: os seis degraus da MESMA cena lado a lado, com Qp
medido contra D5 e a coluna "aceita no piso?" ao lado, mais o veredito de frame
generation da conta acima, atualizando a cada tick.

O que a imagem deixa evidente e não deve ser maquiado: a 24×24 o campo parece
ruído. Isto é correto — não existe campo de elevação importado ainda, então a
altura vem de `heightAt(x,y,biome,ref)` (hash do código). O materializador não tem
de onde tirar terreno; ele tem de onde tirar **decisão**. Asset ingestão
(`.glb`/altura) é o elo faltante, e ele entra como dado do mundo, nunca como mesh
no frame (a allowlist recusa `mesh`/`vertices`/`position` em nível de teste — R2).

Dois invariantes que os testes R4/R5 prenderam e que são a defesa contra deriva:
estado de matéria é MODULAÇÃO de croma, nunca termo a mais na soma de luminância
(é assim que Qp fica monotônico por construção em vez de por decreto), e um D sem a
capacidade correspondente **não pode reagir** ao tick — se reagir, alguém ligou o
pixel a um canal que a decisão não autorizou.
