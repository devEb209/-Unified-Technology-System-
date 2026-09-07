# UTS com 1B físico e Arkhe hiper-realista: meta técnica, não contagem decorativa

## Minha avaliação

A ambição de escala é interessante. **Eu não usaria “1 bilhão físico” como definição de qualidade.** Primeiro, é preciso definir o que se conta: entidades armazenadas, partículas, graus de liberdade, fenômenos implementados ou atualizações por segundo. São métricas diferentes.

Criar um bilhão de IDs, arquivos, tabelas ou nomes não cria um bilhão de comportamentos físicos. Simular mais elementos também não corrige um modelo errado. É melhor implementar e validar dezenas de subsistemas coerentes do que multiplicar descrições vazias.

“Ultrapassar a realidade” pode significar uma direção artística: mais contraste, detalhe selecionado, situações impossíveis ou uma visão ampliada do mundo. Não é uma certificação física. Uma simulação é um modelo com hipóteses, resolução e erro; *ground truth* exige referência observável, dados e método de comparação.

### Quanto custaria 1B, em um exemplo mínimo?

Hipótese: **1.000.000.000 entidades**, cada uma usando somente 64 bytes de estado.

- Estado básico: `1.000.000.000 × 64 = 64.000.000.000 bytes`, ou **64 GB decimais / aproximadamente 59,6 GiB**.
- Isso não inclui índices, colisões, geometria, texturas, buffers temporários, cópias CPU/GPU ou rede.
- Atualizar todas 60 vezes por segundo significa **60 bilhões de atualizações de entidade por segundo**, não apenas 60 bilhões de instruções. Cada atualização pode exigir muitas operações.

Esse é um cálculo hipotético, não uma medição da UTS. Armazenar um catálogo dessa escala e simular tudo simultaneamente são problemas muito diferentes. O pacote recuperado não demonstra essa capacidade.

## UTS: onde concentrar a engenharia

Minha proposta de evolução, **não uma lista de funcionalidades já entregues**:

1. **Definir unidades e referências.** Comprimento, massa, tempo, energia, exposição; escolher casos de teste e tolerâncias de erro antes de aumentar escala.
2. **Separar realidade persistida e conjunto ativo.** Entidades distantes podem ter estado resumido, representação procedural ou atualização menos frequente. Só materializar o necessário para observação e interação.
3. **Usar múltiplas escalas e modelos.** Não simular atomisticamente uma cidade inteira. Empregar modelos de corpo rígido, campos, materiais contínuos, aproximações estatísticas ou detalhes offline conforme o fenômeno.
4. **Construir dados e execução eficientes.** Estruturas compactas, particionamento espacial, tarefas pequenas, paralelismo real onde disponível, limites de memória, streaming, cache e telemetria.
5. **Controlar o erro nas transições.** Trocar representação sem saltos visuais grosseiros e sem alterar arbitrariamente massas, quantidades conservadas ou efeitos de gameplay. Reduzir trabalho significa negociar precisão, frequência, distância ou detalhe — não obter o mesmo custo/qualidade gratuitamente.
6. **Validar física de verdade.** Testes de conservação dentro das hipóteses, estabilidade temporal, convergência, colisões, repetibilidade e comparação com dados/referências. Separar os efeitos apenas visuais da simulação autoritativa.
7. **Só então testar grande escala.** Crescer a carga gradualmente, documentando hardware, memória, tempo por passo e erro. “1B armazenado” não deve ser divulgado como “1B ativo a 60 FPS”.

O nome **D-O15** pode designar essa política adaptativa de representação. Não torna memória ou processamento infinitos. O `BudgetScheduler` desta entrega é apenas um agendador cooperativo pequeno e testável: **não implementa todo esse plano**, nem um solver físico ou um renderizador próprio.

Para UTS fora do Roblox, uma arquitetura nativa poderia explorar recursos próprios de CPU/GPU e ferramentas de produção de assets. Este repositório recuperado, porém, não entrega um executável nativo completo capaz disso. Esse trabalho ainda precisa ser implementado, compilado e medido.

## Arkhe no Roblox: como buscar hiper-realismo

O Arkhe pode organizar o projeto, suas bibliotecas, trabalho incremental e diagnósticos. **Não substitui o renderizador nem o motor físico do Roblox.** Uma pasta chamada Nanite, Lumen, RRW ou RayTracing não disponibiliza a tecnologia correspondente.

### 1. Iluminação atual, configurada corretamente

No Studio, selecione `Lighting` e configure **`LightingStyle = Realistic`**. Esse é o estilo documentado para a iluminação/sombras mais realistas que o Roblox oferece. `PrioritizeLightingQuality = true` é uma escolha possível quando a iluminação próxima importa mais que a distância de visão em níveis gráficos reduzidos; não garante que todos os dispositivos renderizem igual. Configure essas propriedades pela interface do Studio, sem tentar contornar sua segurança por script. [2](https://create.roblox.com/docs/environment/lighting) [3](https://create.roblox.com/docs/reference/engine/classes/Lighting#LightingStyle)

Depois trabalhe horário, direção de luz, exposição, ambiente, contraste e quantidade de luzes locais. O perfil opcional incluído apenas fornece um ponto de partida reversível para propriedades permitidas. Bloom, desfoque e correção de cor devem apoiar a cena, não esconder materiais e geometria ruins.

### 2. Materiais PBR e assets autorais/licenciados

Para `MeshPart`, use `SurfaceAppearance` e mapas coerentes. A documentação atual lista **color, normal, roughness, metalness e emissive**. Mapas alteram a aparência, não a geometria real do objeto. Teste o material em diferentes iluminações; não ajuste tudo para funcionar apenas em uma captura de tela. A preparação/upload de assets e o pré-processamento exigido pelo Roblox continuam necessários. [4](https://create.roblox.com/docs/art/modeling/surface-appearance)

O trabalho artístico proposto inclui escala plausível, silhuetas corretas, bordas, encaixes, distribuição de detalhes, variação não repetitiva, desgaste contextual e densidade de textura consistente. Fotogrametria pode ajudar se houver licença, limpeza, retopologia e otimização. **Nenhum conjunto de fotogrametria, mapas PBR próprios ou cena hiper-realista pronta está incluído nos três RBXM.**

### 3. Streaming, níveis de detalhe e física seletiva

Ative e teste `Workspace.StreamingEnabled` no Studio. O streaming carrega/descarrega conteúdo conforme a necessidade e exige que a lógica lide com objetos ausentes. Montagens físicas móveis grandes podem produzir picos; não divida uma cena em um número desnecessário de partes físicas ativas. [4](https://create.roblox.com/docs/workspace/streaming)

Use níveis de detalhe apropriados; a documentação de desempenho inclui `Model.LevelOfDetail = SLIM` com streaming para modelos distantes. Reavalie luzes, sombras, transparências, partículas e outros custos medindo a cena. Não presuma que um único preset resolve todos os gargalos. [5](https://create.roblox.com/docs/performance-optimization/improve)

Minha recomendação de arquitetura para Arkhe:

- Detalhe visual não precisa virar peça física independente. Prefira colisores adequados à interação e imobilize objetos que não precisam se mover.
- Priorize interações próximas; use aproximações para comportamentos distantes quando o design permitir.
- Não esconda consequências de gameplay só porque um objeto saiu da câmera; simulação autoritativa e representação visual têm responsabilidades diferentes.
- Não replique o acervo inteiro de fontes ao cliente. Nesta reconstrução ele fica no `ServerStorage`; só os módulos pequenos compartilhados vão ao `ReplicatedStorage`.

### 4. Animação, câmera e áudio

Mesmo uma imagem estática bonita perde credibilidade com contatos errados, câmera instável ou som sem relação com materiais/distâncias. Minha proposta é testar locomoção, interação, ritmo, resposta sonora, enquadramento e transições de detalhe junto com a iluminação — não como acabamento tardio.

### 5. Definir uma cena-alvo e medir

Antes de prometer “máximo em todo aparelho”, eu faria uma **fatia vertical pequena**: um cômodo e uma rua curta, com luz natural e artificial, materiais diferentes, uma interação física e um personagem animado.

Metas iniciais sugeridas, não resultados medidos:

| Alvo | Orçamento total por frame | O que conferir |
|---|---:|---|
| PC-alvo a 60 FPS | ~16,7 ms | CPU/GPU, p95/p99, memória, qualidade visual e entradas |
| Celular-alvo a 30 FPS | ~33,3 ms | Temperatura, estabilidade sustentada, memória e experiência visual |

Registre dispositivo, resolução, configurações gráficas, duração, conteúdo e versão do teste. Meça tempo de frame mediano/p95/p99, picos, memória e rede. Use a documentação de otimização e os instrumentos do Studio, em vez de inferir desempenho a partir do tamanho do ZIP. [5](https://create.roblox.com/docs/performance-optimization/improve)

## Decisão recomendada

- **UTS:** perseguir fidelidade física e escala comprovadas, com catálogos grandes e um conjunto ativo sob controle. “1B” pode ser uma meta futura bem definida; não deve ser uma contagem promocional de tabelas.
- **Arkhe:** perseguir hiper-realismo perceptivo **dentro do Roblox**, com arte excelente, iluminação Realistic, materiais PBR, animação, áudio, streaming e orçamento por dispositivo.
- **Critério de máximo:** melhor resultado verificável para uma cena, hardware e orçamento definidos. Arquivo maior, mais pastas ou mais nomes não equivalem a qualidade maior.

**Estado desta entrega:** preservação de dados + módulos utilitários pequenos + testes de lógica/formato. As etapas de arte, física de grande escala, cena-alvo, benchmark e validação no Roblox Studio permanecem por fazer.
