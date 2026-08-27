# Singularity AI — arquitetura

A Singularity AI **não é chatbot + ferramentas**. É a camada de
**inteligência/orquestração** da UTS.

## Separações obrigatórias (canônico)

| Termo | Papel |
|---|---|
| **Singularity AI** | a inteligência/sistema (o todo) |
| **Singularity Core** | a orquestração (o fluxo objetivo→resultado) |
| **Provider** | fonte de capacidade de modelo (Heur, Puter, LLM externo…) |
| **Model** | modelo concreto usado (tier + capacidades + custo) |
| **Tool** | ferramenta nomeada com schema |
| **Agent** | especialista que executa ações |
| **Memory** | estado/contexto persistente |

**Puter é apenas uma possibilidade de provider/acesso.** A arquitetura é
desacoplada de qualquer fornecedor — Puter nunca é a fundação inseparável da
UTS.

## Fluxo do Core (testado, funcional)

```
objetivo (texto)
  → interpretGoal (PT/EN → tipo + parâmetros)
  → Main Model (melhor tier, ex. S++) PLANEJA (decomposição em etapas)
  → por etapa:
       agente selecionado (por ação)
       modelo selecionado POR CAPACIDADE da tarefa (não "o melhor sempre")
         (verificador → verification; otimizador → verification+critique;
          construção → code+specification)
       execução (ferramenta real no WorldAdapter)
       verificação (valida no mundo real)
       falha → correção (até 2 tentativas, erro reinjetado nos args)
  → memória: conversa, decisões (result/{goalId}), fatos
  → ExecutionReport { status: success|partial|failed, steps, corrections, modelsUsed }
```

## LLM — estado honesto

- `HeuristicProvider` = **local, determinístico, funcional** (não é um LLM —
  rotulado como tal). Permite o fluxo completo sem rede.
- `PuterProvider` = **opcional, browser-only** (em Node `isAvailable()===false`
  com erro claro).
- **Nenhum LLM externo real está conectado no Node.** Não se finge que existe.
- **A arquitetura está pronta para receber um provider real sem reescrever o
  Core**: o teste `canonical` pluge um provider externo simulado (que devolve
  o plano como um LLM devolveria JSON) e a orquestração completa (cena
  construída no mundo) roda inalterada.

## Modelos (seleção por tarefa)

`ModelRegistry.select({ capabilities, complexity, maxCost })`:
- complexidade 0..1 → força (tier) mínima necessária;
- capacidades exigidas = filtro duro;
- orçamento (custo máx) = filtro duro quando presente;
- escolhe o **mais fraco suficiente** (mais barato), relaxa tier só quando
  necessário; `main()` = melhor tier (planejamento).
