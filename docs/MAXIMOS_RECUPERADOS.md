# Três pacotes recuperados — UTS, Arkhe e Auto Organizer

**Versão desta reconstrução: `2026.09.06-recovered.1`.**

## Escopo real, antes do download

“Máximo recuperado” significa **todo o conteúdo disponível e identificado nesta cópia**, não a certificação de um motor completo ou de qualidade máxima absoluta.

- Base recuperada: commit `d9087f9ba26bf171fe175d274d925b4cd5f911f2`.
- O commit local antigo `961ee39` não está nesta cópia; a consulta de commit no GitHub também não o encontrou. Não é possível reproduzir fielmente alterações que só existiam naquela sessão.
- O ZIP legado disponível tem **100.000 entradas de arquivo**. Seus bytes são preservados, além dos arquivos não-ZIP da base. Os três ZIPs redundantes de UTS/DsOS não são duplicados: suas fontes já estão na base.
- Os **138.080 arquivos**, o modelo antigo de **620 pastas/5.580 módulos**, o Auto Organizer anterior e os números de **27,6M físicos / 278,9B funcionalidades** não foram recuperados nem certificados.
- Muitos arquivos antigos são descrições, tabelas ou esqueletos. `Physical = 200`, um laço que cria 200 registros e uma função que retorna `Power = "INFINITO"` **não implementam 200 fenômenos físicos nem criação ilimitada**. O legado é conservado, não executado nem reclassificado como funcional.
- Estes RBXM são **modelos/bibliotecas para Roblox Studio**, não mapas `.rbxl`, jogos prontos, APKs, sistemas operacionais ou executáveis nativos de UTS.

O `VALIDACAO.json` registra as contagens, ferramentas e verificações efetivamente executadas. O `MANIFEST.json` externo registra tamanho e SHA-256 dos quatro downloads.

## Os quatro arquivos de entrega

| Arquivo | Conteúdo |
|---|---|
| `UTS_MAXIMO_RECUPERADO.rbxm` | Biblioteca integral da base disponível e do ZIP legado, mais leitor paginado e agendador cooperativo novos. |
| `ARKHE_MAXIMO_RECUPERADO.rbxm` | As 1.000 fontes Roblox disponíveis, documentos relacionados, leitor/agendador autocontidos, auditoria de cena e perfil visual inicial opcionais. |
| `AUTO_ORGANIZER_MAXIMO.rbxm` | **Implementação nova**, com prévia, confirmação, conflitos, rollback e desfazer. Não é o organizador antigo ausente. |
| `3_MAXIMOS_RECUPERADOS.zip` | Os três RBXM inteiros, fontes preservadas em páginas JSON, código novo, ferramentas, testes, licenças, guia de realismo e verificação. **Sem partes.** |

### Por que não criar 100.000 instâncias de scripts no Studio?

O legado fica em páginas `StringValue` de no máximo **180.000 bytes**. Cada arquivo mantém caminho, tamanho, SHA-256, codificação e todos os seus fragmentos. A compactação do RBXM é LZ4, usando a biblioteca `rbx_binary`, não um ZIP/XML apenas renomeado.

Isso conserva os bytes com muito menos instâncias. **Não torna o conteúdo uma simulação ativa e não elimina seu custo de memória**: o Studio ainda precisa importar o modelo inteiro. O leitor decodifica páginas sob demanda, com cache limitado (duas páginas por padrão). Arquivos grandes só são remontados quando solicitados. Não há `require`, `loadstring`, HTTP ou execução automática dos arquivos arquivados.

## Instalação no Roblox Studio

1. Baixe o ZIP completo e extraia-o. Opcionalmente, confira `SHA256SUMS.txt`/`CHECKSUMS_MODELOS.sha256` com `Get-FileHash` no PowerShell ou `sha256sum` no Linux.
2. Abra um **place de teste**, preferencialmente uma cópia vazia. Use **Insert from File / Inserir de arquivo** para importar os três `.rbxm` no `Workspace`.
3. Confira no **Explorer** os modelos `UTS_MAXIMO_RECUPERADO`, `ARKHE_MAXIMO_RECUPERADO` e `AUTO_ORGANIZER_MAXIMO`. **Não existe uma cena hiper-realista visível neste pacote**; ver uma biblioteca no Explorer, sem objetos 3D, é esperado.
4. Fique no modo de edição. **Não use Play/Run ainda**: a biblioteca precisa ser movida para `ServerStorage` para não ser replicada aos jogadores.
5. Selecione no Explorer **apenas o UTS e/ou o Arkhe**. Na Command Bar, execute a prévia:

```lua
local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); s.Preview()
```

6. Confira o Output. Para ambos os pacotes, são quatro movimentos de contêineres. Nenhuma alteração foi feita até aqui. Se não houver conflitos e você concordar, execute:

```lua
local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); print(s.Apply("INSTALAR"))
```

Resultado esperado:

```text
ServerStorage
  UTS_SourceArchive
  Arkhe_SourceArchive
ReplicatedStorage
  UTS
    Runtime
      BudgetScheduler
      SourceArchive
  Arkhe
    Runtime
      BudgetScheduler
      SourceArchive
      SceneAudit
      VisualProfile
```

- O organizador não renomeia, não sobrescreve, não mescla, não apaga e não varre o jogo todo. Só considera os pacotes selecionados, com formato reconhecido.
- Um nome já existente bloqueia a instalação inteira. Faça uma cópia do place e decida manualmente como lidar com a versão anterior; não apague conteúdo para “forçar” a instalação.
- Scripts/LocalScripts ativos no payload são recusados. Os pacotes gerados contêm apenas Model, Folder, StringValue e ModuleScript, sem Script/LocalScript de execução automática.
- Mantenha as embalagens importadas para permitir o retorno aos pais originais. O wrapper registra a instalação no `ChangeHistoryService`.
- Para desfazer pela API na mesma sessão, **antes de fazer alterações externas**, use:

```lua
local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); print(s.Undo("DESFAZER"))
```

Se usar o Undo nativo do Studio, a referência de recibo do módulo pode ficar desatualizada; não aplique também o Undo da API à mesma operação. A API recusa estados incompatíveis. Falhas de rollback são reportadas, nunca apresentadas como sucesso.

### Consultar fontes sem executá-las

Após instalar o UTS, na Command Bar ou em código de servidor:

```lua
local Reader = require(game.ReplicatedStorage.UTS.Runtime.SourceArchive)
local archive = Reader.new(game.ServerStorage.UTS_SourceArchive)
print(archive:Stats().files)
for _, item in ipairs(archive:List("repository/UTS/", 5)) do
    print(item.path, item.bytes)
end
local text, info = archive:Get("repository/UTS/AI/Core/Threading_0001_Core_GroundTruth.lua")
print(info.encoding, info.sha256, text)
archive:ClearCache()
```

`Get` devolve texto e metadados; imagens/binários vêm como base64 identificado, não executáveis. `List(prefix, limit, after)` lista de 1 a 1.000 resultados; passe o último caminho como `after` para continuar. Os SHA-256 são verificados offline pelo empacotador/extrator; o leitor Luau valida a estrutura, **não calcula SHA-256**.

### Código novo: capacidades e limites

- **BudgetScheduler**: fila limitada, tarefas identificadas, cancelamento, rotação, orçamento temporal cooperativo, limite de callbacks por passo e isolamento de erros. Uma tarefa retorna `true` ao terminar. Callbacks devem ser curtos e **não podem ceder execução/yield**. O agendador não interrompe uma tarefa lenta, não cria threads nativas e não é motor físico.
- **SceneAudit.Inspect(sceneRoot)**: inventário sob demanda de partes, partes não ancoradas, MeshParts, SurfaceAppearance, luzes e emissores. Não mede GPU, FPS, qualidade visual ou “sistemas físicos”. Use em uma cena selecionada, não repetidamente a cada frame.
- **VisualProfile.Describe()**: recomendações e propriedades editáveis. `Apply(lighting, true)` é opcional e guarda um snapshot em memória; `Restore(lighting, true)` recusa sobrescrever mudanças externas. Não altera LightingStyle/Technology, não cria texturas PBR nem baixa assets. Não substitui um trabalho de arte/iluminação.
- **Organizer**: planejamento e movimentação explícita com dependências injetáveis; a integração com serviços reais precisa do smoke test abaixo.

## Fontes fora do Roblox

As páginas JSON estão em `FONTES/UTS` e `FONTES/ARKHE` dentro do ZIP. Não é preciso materializar centenas de milhares de arquivos para usar os modelos. Para verificar ou extrair todos os arquivos preservados:

```sh
python EXTRAIR_FONTES.py 3_MAXIMOS_RECUPERADOS.zip --verify-only
python EXTRAIR_FONTES.py 3_MAXIMOS_RECUPERADOS.zip --package ARKHE --verify-only
python EXTRAIR_FONTES.py 3_MAXIMOS_RECUPERADOS.zip --output fontes_uts --package UTS
```

O extrator confere hashes antes de escrever, exige destino vazio e recusa travessia de caminhos, symlinks e sobrescrita. Ele **não compila nem executa** o legado. A extração pode criar mais de 100.000 arquivos; faça isso apenas se precisar das fontes individuais.

## Verificação: o que se pode afirmar

O build falha se qualquer teste obrigatório falhar:

- Testes Python de fragmentação, UTF-8, binários, limites, travessia, integridade, extração e ZIP determinístico.
- Testes Luau de lógica com instâncias simuladas: fila, cache, planejamento, conflitos, corrida de destino, rollback, desfazer, perfil e inventário.
- Compilação Luau de **todos os módulos novos executáveis**, não dos dados legados.
- Assinatura binária RBXM, leitura/escrita com `rbx_binary` e leitura independente com `rbxm-parser`.
- Comparação de **toda a hierarquia e todas as propriedades fornecidas**, incluindo fontes e páginas de dados.
- Reconstrução do RBXM duas vezes a partir da mesma especificação, com bytes idênticos.
- Recuperação byte a byte das fontes, SHA-256, CRC do ZIP e igualdade entre cada RBXM solto e o RBXM dentro do ZIP.

**Não realizado neste ambiente:** importação no aplicativo Roblox Studio, execução de serviços Roblox reais, testes em dispositivos, benchmark de hiper-realismo ou validação de um motor físico completo. Logo, não há garantia honesta de “abre 100% em qualquer Studio” ou de “100% completo da sessão perdida”.

### Smoke test obrigatório no Studio

- [ ] Cada RBXM é importado via Inserir de arquivo e aparece no Explorer sem erro.
- [ ] Prévia com UTS/Arkhe selecionados mostra só os destinos esperados e não modifica o place.
- [ ] Instalação confirmada termina sem erro; bibliotecas ficam no ServerStorage.
- [ ] Consulta `SourceArchive:Get` recupera um arquivo esperado sem executar o conteúdo.
- [ ] Instalar outra cópia bloqueia conflitos, sem sobrescrever a primeira.
- [ ] Desfazer restaura os contêineres aos modelos importados.
- [ ] Salvar, fechar e reabrir o place mantém os dados e a hierarquia.
- [ ] Teste Play/clientes não replica a biblioteca e não apresenta erros novos.
- [ ] Perfil visual e arte são avaliados numa cena própria, no hardware-alvo.

## Reproduzir a entrega no repositório

```sh
npm ci --ignore-scripts --prefix tools/roblox-package
python3 tools/build_maximos.py
python3 tools/extract_sources.py downloads/2026-09-06/3_MAXIMOS_RECUPERADOS.zip --verify-only
```

Ferramentas fixadas no lockfile: `rbx-dom 0.3.0`, `rbxm-parser 1.1.4`, `luau-web 1.4.0`. O parser independente depende de `lz4` nativo e pode exigir Python, make, compilador C++ e os headers do Node. Neste ambiente os headers estão em `/usr/local`: após `npm ci --ignore-scripts`, foi usado `npm rebuild lz4 --prefix tools/roblox-package --nodedir=/usr/local`. Em outras máquinas, use a instalação normal com os headers correspondentes.

Os intermediários ficam em `build/`, dependências em `node_modules/` e somente os artefatos finais solicitados são versionados em `downloads/2026-09-06/`. O build usa a base Git fixa, não se apresenta como uma nova plataforma nativa pronta. As licenças existentes são preservadas; esta entrega não verifica as alegações jurídicas de patentes do legado.
