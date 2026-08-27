# Provisório — hipóteses e reconstruções NÃO ratificadas

> Nada neste arquivo é canônico. Cada item: o que se supõe, por quê, e como
> substituir quando a definição correta chegar.

## 1. D-MAX — RECONSTRUÇÃO (não recuperação)

- **Fato auditado**: nenhuma definição de D-MAX existia no repositório
  (histórico git completo: 1 arquivo de logo antes da implementação; busca
  exaustiva por "d-max/dmax" em todos os commits: zero ocorrências).
- **O que se supõe**: D-MAX = **valor máximo dinâmico da tese** (`max()` =
  maior `value` entre as camadas registradas; cresce quando novas camadas
  entram — coerente com "RRW cobre tudo da realidade").
- **Status**: **IMPLEMENTAÇÃO PROVISÓRIA / NÃO RATIFICADA**. Não se declara
  "D-MAX = máximo numérico das camadas" como definição oficial.
- **Por quê (justificativa da suposição)**: mantém a tese aberta, permite
  fracionamento e não fixa número arbitrário.
- **Substituição**: se a definição correta for outra (número fixo, outra
  semântica), a troca é pontual em `TeseDosD` (`src/d/index.ts`) + ajuste de
  `resolve()`; nenhum outro módulo depende do valor concreto.

## 2. Acrônimo RRW — PROPOSTA

- **Fato auditado**: nenhum nome formal de RRW existia no repositório.
- **O que se supõe**: "Real World Representation".
- **Status**: **proposta** — rotulagem apenas; a API não usa o nome em lugar
  nenhum (`class RRW`, `newId` prefixos, etc.). O canônico é o **conceito**
  (ver `rrw.md`).
- **Substituição**: rename de classe/export (mecânico, sem efeito semântico).

## 3. HeuristicProvider — NATUREZA ROTULADA

- **Fato**: é uma camada **local, determinística e funcional** (interpreta
  objetivos, decompõe em planos, verifica) — **não é um LLM**.
- **Status**: implementado e rotulado como tal em todos os lugares. Não é
  "provisório" no sentido de defeito — é a camada local real da arquitetura
  (a arquitetura exige pelo menos um provider sem rede para testabilidade).
- **Substituição/adição**: provider real (LLM) entra via
  `ProviderRegistry.define` — demonstrado por teste com provider externo
  simulado; nenhum LLM externo real está conectado no Node.

## 4. Valores de perfis de hardware — PARÂMETROS AJUSTÁVEIS

- Os orçamentos (4/10/25/60ms) e bandas de pressão (0.5/0.9) são **parâmetros
  calibrados** com base no comportamento desejado + medições — não são
  decisões canônicas numeradas. Podem ser recalibrados sem mudar a arquitetura.
