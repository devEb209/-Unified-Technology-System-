# RRW — definição e arquitetura

## O conceito (CANÔNICO)

RRW é a fundação de **representação da realidade** da UTS. Sua regra central
(versão mais recente das decisões):

> **RRW deve abranger TUDO DA REALIDADE.**

Isso é implementado como **ABERTURA**, não como lista:

- categorias abertas — qualquer aspecto da realidade pode ser registrado
  em runtime (`defineCategory`);
- componentes abertos — estrutura + comportamento + custo de materialização
  (`defineComponent` com `compress/restore/cost`);
- relações abertas — qualquer tipo de vínculo direcionado, opcionalmente causal;
- eventos abertos — com **causalidade explícita** (causa → efeito, verificável);
- processos abertos — estado + tick de fidelidade alta + tick abstrato;
- contexto/scope — o mundo é organizado, não um lago de entidades;
- materialização contínua 0..1 com **preservação de estado** na abstração.

RRW **não é** uma biblioteca de assets nem um motor de mapa: a representação
visual é apenas uma manifestação possível (a UES/graphics interpreta o
estado RRW). Teste dedicado: um domínio **não espacial** (propagação de
informação em população abstrata, sem posição) roda no núcleo — prova de que
o RRW não é limitado a mapas/NPCs/física/biomas/gráficos. Esses são
**exemplos**, não o universo.

## O acrônimo — ⚠️ NÃO CANÔNICO

"RRW" como **"Real World Representation"** é uma **proposta do agente**
(nenhum nome formal existia no repositório). O nome é apenas rotulagem:
pode ser renomeado sem afetar a API. O que é canônico é o **conceito**
acima — abrangente, funcional, extensível e multinível.

## Níveis de representação de uma mesma entidade (testado)

Uma entidade pode ser:

- **altamente abstrata** (detail 0): apenas `data` semântica + processos
  abstratos; sem percepção fina;
- **parcialmente representada** (0 < detail < 1, transient): rampa de
  materialização; comportamento coarse;
- **materializada** (detail ≥ 0.5): componentes completos, `tick` de
  fidelidade alta;
- **altamente detalhada** (detail 1): percepção total, interação fina.

Mudanças entre estados **preservam o necessário** (teste de round-trip:
identidade, posição, memória/Mind, relações, causalidade e estado de
processos sobrevivem a abstração→materialização). **Abstração ≠ deletar.**

## Causalidade verificável (testado)

- Todo evento pode carregar `cause { by, event, description }`.
- `causalChain(id, type)` reconstrói a cadeia até a raiz (profundidade limitada).
- `validateCausality()` **verifica** que toda causa aponte para um evento que
  REALMENTE existe no log da entidade causadora — uma consequência nunca
  aponta para causa inexistente/fabricada. O `World.checkInvariants()` inclui
  essa validação.
- Exemplos reais capturados: `fire.starts ← weather.lightning`,
  `npc.trade ← npc.hunger`, `society.famine.warning ← society.stock.low`,
  `work.produced ← work.assigned`.

## Persistência

`serialize()`/`restore()` capturam/reconstruem o estado completo (entidades,
componentes, snapshots comprimidos, relações, eventos → causalidade,
processos → alvos e estados, contadores) de forma JSON-safe e determinística.
