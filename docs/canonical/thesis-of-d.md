# Tese dos D — definições canônicas

> D = **CAMADAS/CONCEITOS FUNCIONAIS** voltados aos objetivos da UTS.
> Não são dimensões físicas. Não são coordenadas matemáticas. Não são níveis
> arbitrários para organizar código. **Cada D possui função arquitetural real**
> (com efeito operacional verificável — testado).

## Os D

| D | Função arquitetural | Representação | Efeito operacional (testado) |
|---|---|---|---|
| **D-0** | Identidade mínima — "o que é" | string/label + categorias | entidades distinguíveis sem detalhe |
| **D-1** | Semântica — estado compacto que sobrevive | `data` + snapshot comprimido | mundo vivo em abstração (20k entidades ≈ 2ms/tick) |
| **D-2** | Comportamento — processos que evoluem estado | processos RRW (`tick`/`abstractTick`) | NPC decide; grupo produz/consume mesmo abstrato |
| **D-3** | Espaço — onde as coisas estão, organizado | chunks + contexto + streaming | load/unload por foco; estado preservado no unload |
| **D-4** | Detalhe fino — percepção física e interação | materialização ≥ limiar (0.5) | percepção de NPC exige materialização; LOD |
| **D-O15** | Otimização inteligente | StrategyEngine + Profiler + Scheduler | pressão medida → detalhe/Hz/raio por sistema |
| **D-MAX** | *(ver abaixo — NÃO RATIFICADO)* | `max()` dinâmico (provisório) | teto cresce com camadas registradas |

## Valores fracionários — com efeito real (não decorativos)

A resolução fracionária produz **comportamentos intermediários úteis**:

- `behaviorScale(detail)`:
  - `detail < 0.5` → **0** (abstrato: sem comportamento fino, sem percepção);
  - `0.5 ≤ detail < 0.75` → **0.5** (coarse: percepção a metade do raio;
    sem trade/trabalho/socialização — só ações básicas: comer/descansar/
    fugir/explorar);
  - `detail ≥ 0.75` → **1** (completo).
- Materialização por foco gera **rampa** de detalhe na zona externa
  (0.5..1) — NPCs nessa faixa ficam coarse automaticamente.
- A propagação de fogo escala com o detalhe do fogo.
- Testes: percepção coarse < full; coarse não compra no mercado; rampa gera
  valores intermediários.

## Resolução (resolve)

`resolve({ requestedValue, grantedValue })` → clampa em `min..max`,
fraciona e reporta `downgradedFrom` — **a queda de nível é visível,
nunca silenciosa** (ex.: pedido D-4, concedido D-3.5 → `downgradedFrom: 4`).

## D-MAX — ⚠️ NÃO RATIFICADO

- **Auditoria**: nenhuma definição de D-MAX existe no repositório (histórico
  completo = 1 arquivo de logo antes desta implementação).
- **Estado**: a implementação atual usa D-MAX **dinâmico** (`max()` = maior
  `value` entre camadas registradas) como **IMPLEMENTAÇÃO PROVISÓRIA**.
- **Não se declara** "D-MAX = máximo numérico das camadas" como definição
  oficial. Está marcado em `provisional.md` e aguarda ratificação.
