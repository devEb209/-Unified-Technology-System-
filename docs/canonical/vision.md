# UTS Vision

> A UTS NÃO EXISTE APENAS PARA CRIAR JOGOS.

A UES pode criar jogos. A arquitetura maior busca:

> **CONSTRUIR UMA REALIDADE COMPUTACIONAL.**

Isso significa desenvolver uma base capaz de representar:

- mundos;
- entidades;
- processos;
- fenômenos;
- comportamento;
- sistemas;
- relações;
- informação;
- inteligência;
- ambientes;
- e **qualquer outro aspecto necessário da realidade**.

## Separações obrigatórias (para não perder a visão)

1. **Representação ≠ Renderização.** A representação da realidade é maior
   que a renderização. Renderizar é uma manifestação visual possível — a
   representação existe com ou sem visual (testada sem GPU).
2. **Visão ≠ Estado atual do código.** O que está implementado hoje é a
   **primeira grande implementação funcional** — a fundação. A arquitetura
   deve poder crescer muito além dela.
3. **Mas também: estado atual ≠ visão.** Não se declara que "a UTS já
   representa toda a realidade". A implementação atual cobre um subconjunto
   (ver `limitations.md`). Visão e estado são coisas explicitamente separadas.
4. **Abertura, não enumeração.** "Cobrir tudo da realidade" é implementado
   como **capacidade de extensão** (categorias, componentes, camadas,
   processos, agentes, fenômenos entram em runtime) — nunca como lista
   fechada de sistemas.

## Provas de abertura já implementadas

- Novas **camadas semânticas** entram em runtime (`World.addLayer`).
- Novas **categorias/componentes** entram em runtime (`RRW.defineCategory/Component`).
- Novos **processos** entram em runtime (`RRW.defineProcess`).
- Novos **fenômenos Real Life** entram em runtime (`RealLife.addRule`).
- **Novos providers de modelo** entram em runtime (`ProviderRegistry.define`) —
  demonstrado com um provider externo simulado (teste `canonical`).
- **Domínio não espacial** roda no núcleo (teste: propagação de informação em
  população abstrata, sem mapa, sem física) — prova de que o RRW não é
  "motor de mapa".
