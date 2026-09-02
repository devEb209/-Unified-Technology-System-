# Soluções por sistema — a regra que faltava no meu processo

Escrito em 2026-09-03 depois de uma correção do autor, que é o motivo deste arquivo
existir: eu **descartei** foveação/densidade variável por hardware ("precisa de
eye-tracker") sem gerar alternativas, e chamei isso de realidade. Não era realidade,
era catálogo de indústria. O `UTS`/`REAL UES` já proíbem essa conduta (não otimizar a
tecnologia antiga; abandonar a solução e criar outra), e o autor explicitou o método:

> Fugir do padrão **não** é burlar o impossível (ex.: os pixels físicos da tela).
> É: antes de descartar qualquer sistema, **buscar, criar e experimentar todas as
> soluções possíveis**, e escolher a melhor para cada sistema. Teoria, ficção
> funcional e conceito são entradas legítimas — inclusive para as eras PRIMORDIAL
> e DARKNESS, que existem justamente para fundamentos e para o ainda-não-representável.

## 1. O protocolo (obrigatório para todo "não")

Nenhum sistema entra em "não" sem uma linha neste documento com os cinco campos.
Um "não" sem lista de alternativas é **processo quebrado**, não conclusão.

1. **Objetivo** — o que o sistema tem de entregar (em grandeza, não em adjetivo).
2. **Restrição física/contratual imutável** — o que de fato não se negoceia (nº de
   pixels do painel, bytes/frame de banda, tempo do quadro, piso Qp, allowlist do
   DFrame). Só isto é "impossível".
3. **Conjunto de soluções** — ≥4 candidatos, incluindo pelo menos um não-industrial
   (novo paradigma) e um de fronteira (teoria/ficção funcional).
4. **Custo e risco de cada um** — latência, memória, banda, energia, superfícies de
   falha, o que fica invisível para o jogador.
5. **Escolha + medição** — qual entrou no kernel, e qual número no aparelho decide
   se a escolha continua de pé (sem número, o item é `pendente`, não `decidido`).

## 2. Registro

### 2.1 Densidade de representação por célula ("desrenderizar o desnecessário")

1. **Objetivo:** gastar menos trabalho de render nos lugares onde a cena não cobra
   informação, sem tocar no degrau D da região e sem cruzar o piso perceptual.
2. **Restrição imutável:** o painel tem 720×1612 = 1.161.824 px; cada pixel exibido
   precisa de uma cor; o Qp é medido contra a referência na mesma cena.
3. **Soluções:**
   - **(a) Foveação com eye-tracker** — a forma da indústria (desktop/VR). Descartada
     pela restrição do aparelho: o A70 não tem sensor de retina. Não é "não dá": é "dá
     sem esse sensor"?
   - **(b) Foveação por hipódromo de atenção** — a atenção do jogador já é declarada
     pelo próprio jogo: **mira** (retículo), **salience** (onde há entidade/movimento),
     **head-pose** (IMU, ~graus de erro), **câmera frontal** (estipulação),
     **predição** (estado futuro), **prior estático** (centro). Cada uma tem custo e
     risco próprios e nenhuma exige hardware novo. **[escolhida como família]**
   - **(c) Densidade por célula do Spatial Grid** — a decisão do motor **já é** por
     célula; foveação é só a densidade de amostragem *dentro* da célula. Zero
     mecanismo novo: um campo de pesos multiplicativos sobre o campo materializado.
     **[implementada — `packages/rrw-mat/src/fovea.ts`]**
   - **(d) Reconstrução a partir do estado (não da imagem)** — onde a densidade é
     cortada, a célula é reapresentada pelo *último estado válido*, não por blur; o
     motor tem o snapshot, então "esconder" é escolher, não perder. **[parcial: vale
     para movimento; geometria ainda não tem asset]**
   - **(e) Temporal: render de periferia a taxa menor que a cena central** — a cena
     central vai a 30 Hz, a periferia a 15 Hz. **[pendente — depende do veredito de
     apresentação por célula, `do15/present.ts`]**
   - **(f) Teoria/ficção (PRIMORDIAL):** densidade como **função de informação
     esperada** — a célula gasta amostras proporcionalmente ao ganho informacional que
     ela produz (entropia local / valor de decisão), e a "atenção" deixa de ser do
     olho e passa a ser do **objetivo do agente**. Não implementado; entra como
     candidato legítimo da era seguinte. **[fronteira]**
4. **Custo/risco:** (b) custa latência da hipótese (estipulação por câmera: +1 quadros;
   predição: erro em movimento brusco) e risco de **cuspir informação no olho errado**
   se a hipótese falhar; (c) custo de CPU ~0 (um campo `Float64Array` por região), risco
   de granularidade — em grade 24×24 o corte é grosseiro. Energia: (b) com câmera
   frontal é a única alternativa com custo de bateria real (declarar no plano).
5. **Escolha + medição:** família (b)/(c)/(d) no kernel. **Medida neste sandbox,
   g32, minDensity 0.5, Qp ≥ 0.9:** cena coerente aceita **36% de corte**; alta
   frequência (6 oitavas) aceita **0%**; no materializador atual (sem asset) o piso
   aceita **18–30%**. Conclusão: **o limite é da cena, não do hardware** — e é por
   isso que o "não" anterior estava errado duas vezes: negava a técnica por hardware e,
   ao mesmo tempo, prometia ganho que só aparece quando o campo de elevação/asset existir.
   **Pendente no aparelho:** quanto disso sobe quando a cena for terreno real (medir com
   `uts measure` + auditoria REF↔CAND no A70).

### 2.2 Frame generation (suavizar 15 Hz simulado para parecer 30/60)

(Registro já feito em `docs/estado/GEN-1-andamento.md`; aqui só a forma de protocolo:
alternativas consideradas = FG por imagem DLSS/FSR-style [recusada: precisa de optical
flow hardware/qualidade que o Mali-G57/PowerVR não dá], FG por estado do snapshot
[escolhido], view-model livre de simulação [sempre aplicado], taxa de sim por célula
[escolhido como dial principal]. Medido: veredito `vale` só em célula dominada por
simulação; na célula em foco o custo líquido é negativo em −0.3 ms a −4 ms.)

### 2.3 Vazios no meu processo que este protocolo pega

- Eu tinha tratado "sem hardware" como "impossível" (2.1a/b): o protocolo exige
  perguntar "e sem o sensor, qual é a família de soluções?".
- Eu tinha aceitado um único medidor (grade 24/32 ruidosa) como se fosse a cena: o
  campo 5 ("sem número, é `pendente`") proibe transformar limitação do instrumento em
  limite do sistema.
- Item (f): eu vinha recusando entrada teórica por não estar confirmada, o que
  contradiz a Tese dos D e a própria definição de PRIMORDIAL/DARKNESS. Teoria entra
  como **candidato com custo declarado**, nunca como conclusão.

### 2.4 Terreno: como a altura chega à cena

1. **Objetivo:** relevo que obedece leis (rio desce, encosta respeita o ângulo de
   repouso, neve na linha de neve) e que registra o que aconteceu nele.
2. **Restrição imutável:** decisão é por CÉLULA do Spatial Grid, nunca por entidade;
   o frame não transporta mesh nem altura explícita (allowlist do `dframe`).
3. **Soluções:**
   - **(a) altura importada (`.png`/`.raw`/`.glb`)** — o padrão da indústria. Barato,
     mas o motor passa a obedecer um asset estático: sem lei, sem deformação
     persistente, e o custo vira O(pixels) de textura. **[adiada: só como
     `heightfield_ref` resolvido fora do frame]**
   - **(b) campo procedural POR LEI, escalonado em D** — cada degrau liga uma lei:
     orogenia → hidrologia → ângulo de repouso → clima → deformação. **[escolhida:
     `packages/terrain` não existe — é `packages/rrw-mat/src/terrain.ts` + escada
     `terrain` em `d-system`]**
   - **(c) terreno como agregados do `world`** (alturas resumidas por região, sem
     campo): cobre colisão grosseira a custo zero, mas não dá hidologia nem marca do
     tsunami. **[rejeitada: viola o requisito "realidade", não o orçamento]**
   - **(d) heightfield implícito em shader** (o truque do "raymarching de terreno"):
     rende sem asset, mas é exatamente o "shader tradicional" proibido em
     `REAL UES:11-17`. **[rejeitada por contrato, não por custo]**
   - **(e) simulação de formação em tempo de criação (erosão de milhões de ticks
     offline, campo congelado como código)** — é o que "construir a realidade"
     significa de verdade; pesado, e hoje a D5 cobre só a deformação contínua.
     **[fronteira — PRIMORDIAL: aqui entra física, não engine]**
4. **Custo/risco:** custo é `perVolume` (células de campo) — testado como exato (T3);
   risco é o clima derivar de altitude que a cena não declarou (aconteceu: o materializador
   tinha uma tabela de bioma e corrigia a cena → virou erro de projeto, e o conserto é
   a chave `base_altitude_m` no frame, não uma tabela melhor).
5. **Escolha + medição:** (b) implementada com T1–T10 (10 testes). Medido: linha de
   neve **emerge** como faixa parcial (não cobertor), rio forma lago em bacia fechada,
   encosta acima do ângulo de repoudo do material é marcada como instável. Pendente no
   aparelho: custo de materializar g×g por célula a 716.098 un/s — e o próximo passo é
   o `plan` decidir `terrain` por região com o `device.json`.

## 3. Próximas linhas a preencher (na ordem)

NMN (`behavioral`) → social/econômico → execução multi-device → taxa por célula
(2.1e) → erosão offline (2.4e). Cada uma abre aqui **antes** de virar código, com ≥4
alternativas e um número de aparelho como critério de fechamento.
