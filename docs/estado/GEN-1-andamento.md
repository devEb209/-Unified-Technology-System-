# GEN-1 — estado real do kernel (2026-09-02)

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
