# ARKHER — compromisso de escopo da V1

Fonte integral: `ARKHER STUDIOS👑`, blob `9f628f98e103d1fedea1a7c418ecb50ecdf21fcf`, main `c849100aec49e344cf915cbbe5b31bcc707963ee`.

**V1/Gênesis não é definida como um MVP.** Esta etapa de desenvolvimento não fecha a V1. Requisitos ainda não satisfeitos permanecem requisitos da V1, não são transferidos automaticamente à V2.

## Contagem

- Mínimo solicitado: **10.000 sistemas reais**, significativos, excluindo getters/setters, helpers, aliases e wrappers triviais.
- Mínimo solicitado: **100.000 funcionalidades completas e utilizáveis**.
- Situação: **NÃO ATINGIDO / NÃO CERTIFICADO**.
- Arquivos, módulos, testes, entidades de cena, variantes de geradores e nós de grafo **não são usados como substitutos dessa contagem**.
- A lista abaixo é uma matriz de famílias/requisitos, não uma lista de sistemas declarados como concluídos.

## Matriz de famílias

| Família do prompt | Estado nesta etapa | O que falta, entre outros requisitos |
|---|---|---|
| A — Core/UES | Parcial: dados, comandos, revisões, histórico e sessão | Jobs/task graph geral, reflection, recursos completos, plugins, migrations |
| B — Studio/IDE | Parcial: editor nativo, inspector, hierarquia, gizmos e grafos JSON | IDE completa, multi-viewport, docking, debugger, editores especializados |
| C — Scene/World | Parcial: scene graph, hierarquia, fork de simulação, snapshots | World partition, streaming de estado, prefabs/variantes, mundos persistentes completos |
| D — Terrain | Parcial: heightfield, geração e quatro pincéis | Voxel/volumétrico completo, erosão, hidrologia, cavernas, geologia |
| E — Materials | Parcial: dados de superfície e adapter de materiais/luzes | Material graph, texturas, propriedades físicas e envelhecimento completos |
| F — Rendering | Parcial: materialização Roblox, pooling e agregação de heightfield | Render graph completo, GI própria, buffers, efeitos e geometria virtualizada |
| G — Neural/Upscaling | Não implementado | Pesquisa, algoritmos, modelos, execução e validação de reconstrução própria |
| H — Physics | Parcial: gravidade, broad phase, AABB e heightfield vertical | Rigid bodies completos, OBB/CCD, soft bodies, fluidos, cloth/hair, destruição |
| I — Animation | Parcial: grafo numérico/vetorial executável | Rig, IK/FK, skeletal animation, retargeting, motion matching, compressão |
| J — Digital human | Não implementado; NPC usa manequim de primitivas | Corpo/rig humano, face, pele, cabelo, customização e comportamento físico completos |
| K — NPC/NMN | Parcial: necessidades, memórias, percepção, A*, decisões e checkpoints | NMN completo, relações sociais, ocupações, aprendizagem ampla, navegação dinâmica/multinível e validação no Roblox |
| L — World simulation | Parcial: relógio e parâmetros ambientais | Clima, ecologia, populações, sociedades, economia, infraestrutura |
| M — Procedural | Parcial: heightfield e cidade determinísticos | Geradores semânticos completos, interiores, quests, ecossistemas e demais famílias |
| N — VFX | Não implementado | Framework de partículas/VFX e editores |
| O — Audio | Não implementado | Grafo, reprodução, espacialização, propagação, mixagem e editores |
| P — Gameplay | Não implementado como framework | Inventário, crafting, missões, progressão, abilities, estados multiplayer |
| Q — UI/UX | Parcial: widgets do editor, touch/mouse/gamepad em código | Runtime UI amplo, data binding, localização e acessibilidade validadas |
| R — Networking | Parcial: comandos autoritativos, revisões e frames de simulação | Interest management, reconciliação, predição, streaming e profiling completos |
| S — D-O15 | Parcial: frame time, EMA/hysteresis e orçamento visual | Controle multidomínio, Q validada, predição e medições reais por hardware |
| T — Singularity AI | Parcial: planejador local, provider configurável, prévia/aprovação | Orquestração e especialistas completos, conhecimento/memória ampla, pesquisa e verificação avançadas |
| U — Scripting | Parcial: linguagem de grafos, validação e execução | IDE/debugger, code intelligence, linguagem ampla e isolamento de extensões |
| V — Asset pipeline | Parcial: projetos JSON e build RBXL/RBXM | Importadores/exportadores de assets, dependências, versões, formatos e otimização |
| W — Cinematic | Não implementado | Sequencer, timelines, rigs, shots, captura e direção cinematográfica |
| X — Security/reliability | Parcial: permissões, budgets, confirmação, CAS e validação | Isolamento de plugins, threat model completo, fuzzing/pen-test e recuperação ampliada |
| Y — Collaboration/production | Parcial: sessão compartilhada e conflito de revisões | Equipes/projetos isolados, merge, comentários, tarefas, versionamento e publicação completos |
| Z — Original technologies | Em desenvolvimento, sem alegação de invenção certificada | Implementação e avaliação dos mecanismos próprios especificados, sem apenas renomear técnicas |

## Critério de progresso

Um item só poderá sair de pendente/parcial quando houver finalidade, código efetivo, contratos, integração, tratamento de falhas, testes e evidência de uso correspondente ao escopo.

- Compilação Luau não substitui execução no Roblox.
- Leitura de RBXL/RBXM por parsers não substitui teste no aplicativo Studio.
- Um teste de Core com mocks não valida networking, DataStore ou provider reais.
- Um contador de FPS não prova qualidade perceptual/física ou vantagem sobre outras engines.
- APIs/recursos indisponíveis da plataforma exigem alternativas reais e limitações explícitas; não recebem status fictício de concluídos.

A implementação permanece concentrada no **ARKHER**, sem continuar a construção separada da UTS ou do DsOS nesta etapa.

## Relatório de cobertura

A contagem rastreável das entradas explicitamente nomeadas está em [progress/README.md](progress/README.md). Cobertura parcial não é conclusão da V1; os alvos 10K/100K permanecem não certificados.
