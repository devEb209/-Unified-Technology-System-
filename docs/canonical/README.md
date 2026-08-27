# Documentação Canônica — UTS

Esta pasta separa explicitamente o que é **CANON** (definido pelo projeto)
do que é **IMPLEMENTAÇÃO**, **RECONSTRUÇÃO** ou **HIPÓTESE** (não ratificado).
Regra absoluta: **CANON > RECONSTRUÇÃO** — uma suposição do agente nunca vira
decisão oficial sem ratificação.

## Matriz Canônica (conceito × estado × fonte × implementação)

| Conceito | Estado | Fonte | Implementação |
|---|---|---|---|
| UTS (arquitetura maior; realidade computacional, não "só jogos") | **CANÔNICO** | prompts do usuário | funcional |
| UES (aplicação principal; UES ≠ UTS) | **CANÔNICO** | prompts do usuário | funcional |
| Tese dos D (camadas funcionais, fracionárias, efeito verificável) | **CANÔNICO** | prompts do usuário | funcional (D-MAX exceto — ver abaixo) |
| D-MAX | **NÃO RATIFICADO** (reconstrução) | ausente do repositório | provisório: valor dinâmico `max()` |
| RRW — **conceito** (representação aberta, abrangente, multinível, extensível da realidade) | **CANÔNICO** | prompts do usuário | funcional |
| RRW — **acrônimo** "Real World Representation" | **PROPPOSTA** (não ratificado) | proposta do agente | nome apenas; sem efeito na API |
| D-O15 (otimização = mesmo resultado, mais eficiência) | **CANÔNICO** | prompts do usuário | funcional |
| Singularity AI (orquestração, não chatbot) | **CANÔNICO** | prompts do usuário | funcional |
| Singularity Core (objetivo→planejamento→seleção→execução→verificação→correção→memória) | **CANÔNICO** | prompts do usuário | funcional |
| Separação Singularity AI / Core / Provider / Model / Tool / Agent / Memory | **CANÔNICO** | prompts do usuário | funcional |
| Puter = provider opcional (não fundação) | **CANÔNICO** | prompts do usuário | funcional (browser) |
| NMN (Natural Mindset of NPCs) | **CANÔNICO** | prompts do usuário | funcional |
| Causalidade verificável (consequência não aponta para causa inexistente) | **CANÔNICO** | prompts do usuário | funcional (`validateCausality`) |
| Materialização ⇄ abstração com preservação de estado | **CANÔNICO** | prompts do usuário | funcional |
| Mundo vivo fora do foco (abstrair, atualizar, preservar, evoluir, re-materializar) | **CANÔNICO** | prompts do usuário | funcional |
| Realidade não é lista fechada (RRW extensível) | **CANÔNICO** | prompts do usuário | funcional (testado fora do espaço) |
| Persistência (RRW, mundo, memória, relógio, RNG, causalidade) | **IMPLEMENTADO nesta etapa** | arquitetura necessária (Prompt 22) | funcional + teste de determinismo |
| Renderer GPU (Vulkan/DirectX/OpenGL/WebGL) | **FUTURO** | arquitetura (plug point `RendererBackend`) | ausente (limitação) |
| LLM externo no Node | **FUTURO** | arquitetura (provedor plugável, demonstrado) | ausente (limitação) |
| Valores fracionários com efeito comportamental (0.25/0.5/0.75) | **CANÔNICO** (intenção) + implementado | prompts do usuário (5) | funcional (testado) |

## Índice

- [`vision.md`](vision.md) — UTS Vision
- [`architecture.md`](architecture.md) — arquitetura canônica vigente
- [`thesis-of-d.md`](thesis-of-d.md) — Tese dos D (definições canônicas)
- [`rrw.md`](rrw.md) — RRW (conceito canônico; nome proposto)
- [`d-o15.md`](d-o15.md) — D-O15 (definição + implementação)
- [`singularity-ai.md`](singularity-ai.md) — arquitetura da inteligência
- [`ues.md`](ues.md) — arquitetura da engine
- [`decisions.md`](decisions.md) — decisões confirmadas
- [`provisional.md`](provisional.md) — hipóteses/reconstruções não ratificadas
- [`limitations.md`](limitations.md) — limitações reais
