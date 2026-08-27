# Status — auditoria objetiva (sem exagero)

Metodologia: cada item foi verificado contra o código real e os testes
correspondentes. Estado: **IMPLEMENTADO** (código funcional + testado),
**PARCIAL**, **AUSENTE**.

> Separação canon × reconstrução × limitação: ver
> [`canonical/README.md`](canonical/README.md) (matriz canônica).

## Resumo

| # | Sistema | Estado | Teste |
|---|---|---|---|
| 1 | Núcleo (clock, RNG **com estado serializável**, bus, logger, perf) | IMPLEMENTADO | `test/core.test.ts` (8) |
| 2 | RRW representação aberta | IMPLEMENTADO | `test/rrw.test.ts` (8) |
| 3 | RRW: causalidade **verificável** | IMPLEMENTADO | `test/canonical.test.ts` |
| 4 | RRW: persistência (serialize/restore) | IMPLEMENTADO | `test/persistence.test.ts` |
| 5 | Tese dos D (fracionário **com efeito**) | IMPLEMENTADO (D-MAX provisório) | `test/d.test.ts` (7) + `canonical` |
| 6 | D-O15 (c/ **raio de materialização adaptativo**) | IMPLEMENTADO | `test/d-o15.test.ts` (7) + `canonical` |
| 7 | Singularity AI (**provider externo plugável**) | IMPLEMENTADO | `test/ai.test.ts` (10) + `canonical` |
| 8 | UES World + streaming | IMPLEMENTADO | `test/world.test.ts` (8) |
| 9 | UES NMN (percepção **fracionária**) | IMPLEMENTADO | `test/nmn.test.ts` (7) + `canonical` |
| 10 | UES Sociedade | IMPLEMENTADO | `test/society.test.ts` (5) |
| 11 | UES Gráficos/Real Life (**aberto a novos fenômenos**) | IMPLEMENTADO | `test/graphics.test.ts` (6) + `canonical` |
| 12 | UES Engine (integração) | IMPLEMENTADO | `test/integration.test.ts` (4) |
| 13 | Persistência + **determinismo** (save/restore/reprodução) | IMPLEMENTADO | `test/persistence.test.ts` (4) |
| 14 | Provas canônicas (11 testes dedicados) | IMPLEMENTADO | `test/canonical.test.ts` |
| 15 | Escala + **prova de gargalo medido** | TESTADO | `test/scale.test.ts` (5) + `scale-probe.test.ts` (4) |
| 16 | Renderer GPU real | AUSENTE (plug point pronto) | — |
| 17 | LLM externo no Node | AUSENTE (plug point demonstrado) | `canonical` |
| 18 | D-MAX | **NÃO RATIFICADO** (reconstrução dinâmica) | `test/d.test.ts` |
| 19 | Acrônimo RRW | **PROPPOSTA** ("Real World Representation") | — |

**Total: 95 testes passando, 0 falhas, 0 dependências, Node 22 nativo.**

## Corrigido neste ciclo (bugs reais encontrados na auditoria canônica)

1. **Causa inexistente** — `work.produced` citava a causa `work.assigned`,
   que NUNCA era emitida (44 violações por run). Agora `work.assigned` é
   emitido na atribuição do ofício; `validateCausality()` (novo) verifica
   TODO evento e `checkInvariants()` a inclui.
2. **NPCs de `buildVillage` nunca eram simulados** — criavam-se fora do
   registro do engine. O engine agora **descobre NPCs pelo RRW**
   (`npcFor`/adoção) — qualquer origem (factory, buildVillage, restore)
   entra na simulação.
3. **`snapshot()` do RRW era incompleto** — faltavam componentes, estado
   comprimido, eventos (causalidade!) e processos. Implementado
   `serialize()/restore()` completo (JSON-safe, determinístico); `snapshot()`
   permanece como resumo semântico.
4. **Valores fracionários eram decorativos** — detail 0.5..1 não mudava
   nada. Agora `behaviorScale` produz comportamento intermediário real
   (percepção 0/0.5/1; coarse sem trade/trabalho/social; fogo escala).
5. **D-O15 não controlava materialização** — só Hz/detalhe de sistemas.
   Agora a decisão do sistema `streaming` ajusta o **raio de materialização**
   do mundo (pressão → encolhe; folga → restaura).
6. **RealLife fechada** — efeitos fixos. Agora `addRule()` (fenômenos novos
   em runtime, estado extensível).
7. **Engine sem descoberta aberta** — ver item 2.
8. **Rng não serializável** — adicionado `state()`/`fromState()` (base da
   persistência determinística).
9. **Scheduler sem estado serializável** — `scheduleState()/restoreScheduleState()`
   (nextDue/hz) para o restore continuar o agendamento sem descontinuidade.
10. **Memory sem `load()`** — adicionado (round-trip de memória da IA).

## O que é real (verificável agora)

- **Causalidade verificável**: toda causa aponta para evento real;
  violação é detectável (`validateCausality`) — fluxo real tem zero
  violações.
- **Persistência determinística**: save → restore → ambos evoluem
  **idênticos** (10 s adicionais, bit a bit em posições/estoques/clima/RNG).
  Dois runs independentes com mesma seed produzem a mesma realidade
  (IDs normalizados); seed diferente → diferente.
- **D-O15 controla a abstração**: sob pressão extrema a zona materializada
  encolhe (testado) e restaura em folga (testado).
- **Fracionário com efeito**: NPC coarse vê menos e não comercia (testado);
  abstrato não percebe (testado).
- **RRW fora do espaço**: propagação de informação em população abstrata
  roda no núcleo (testado) — RRW ≠ motor de mapa.
- **Provider externo plugável**: um provider simulado (contrato real de
  Provider) planeja e o core orquestra a cena completa sem alteração (testado).
- **Mundo vivo preservado**: round-trip de materialização preserva
  identidade, posição, memória, relações, causalidade e estado de processo
  (fogo continua queimando do ponto em que parou — testado).

## Escala — números medidos (esta máquina; não são garantia absoluta)

| Carga | Custo medido | Veredito |
|---|---|---|
| 500 NPCs materializados (workstation 60ms) | ~27ms/tick | dentro do orçamento |
| 2000 NPCs materializados | ~216ms/tick (máx 950ms no 1º stream) | **gargalo CPU** — sistema adapta (deferrals, pressão >15) |
| 20.000 entidades abstratas (D-1) | ~2ms/tick (300 ticks em 625ms) | barato — representação > força bruta |
| 800 NPCs: raio cheio vs raio 1-2 | custo cai com a abstração | testado |
| Memória | ~4.7KB/NPC materializado | ok |

Ponto de gargalo depende da máquina; os testes asseveram a **adaptação**
(ticks sobre orçamento + deferrals), não números absolutos.

## Como revalidar

```bash
npm test              # 95 testes
npm run demo          # ciclo completo
npm run demo:lowend   # adaptatividade sob hardware baixo
```
