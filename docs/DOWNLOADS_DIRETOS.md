# Downloads diretos — reconstrução 2026.09.06-recovered.1

Links RAW imutáveis, retornados pela API do próprio repositório. Não são páginas GitHub, nem previews Arena, nem servidores `8000-*`. **A hospedagem continua sendo o GitHub**: esta entrega segue o pedido final de links RAW GitHub, não promete hospedagem externa sem GitHub.

| Download | Tamanho em bytes |
|---|---:|
| [3_MAXIMOS_RECUPERADOS.zip](https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/2399b3f3d278af4e3caba58c38345a18880edfc5/downloads/2026-09-06/3_MAXIMOS_RECUPERADOS.zip) | 27,521,158 |
| [ARKHE_MAXIMO_RECUPERADO.rbxm](https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/2399b3f3d278af4e3caba58c38345a18880edfc5/downloads/2026-09-06/ARKHE_MAXIMO_RECUPERADO.rbxm) | 1,739,038 |
| [AUTO_ORGANIZER_MAXIMO.rbxm](https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/2399b3f3d278af4e3caba58c38345a18880edfc5/downloads/2026-09-06/AUTO_ORGANIZER_MAXIMO.rbxm) | 5,836 |
| [UTS_MAXIMO_RECUPERADO.rbxm](https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/2399b3f3d278af4e3caba58c38345a18880edfc5/downloads/2026-09-06/UTS_MAXIMO_RECUPERADO.rbxm) | 19,315,189 |

Commit que contém os quatro arquivos: `2399b3f3d278af4e3caba58c38345a18880edfc5`.

## O que foi efetivamente verificado

- Commit e push concluídos na branch `arena/01a077de-unified-technology-system`.
- Os quatro arquivos completos foram baixados do GitHub pelo endpoint de conteúdo RAW da API; tamanho, SHA-256 e hash de blob Git coincidem com os arquivos locais.
- A API forneceu cada `download_url` acima. O acesso direto a `raw.githubusercontent.com` a partir deste ambiente falhou no handshake TLS (EOF). Portanto, **não foi marcado como download HTTP testado por esse host**, nem como teste no navegador do usuário.
- A reconstrução completa produziu novamente os mesmos bytes dos três RBXM e do ZIP.
- 14 testes Python + 35 testes de lógica Luau passaram. Os binários passaram por dois leitores independentes, com comparação integral de hierarquia/propriedades.
- Importação no aplicativo Roblox Studio e runtime nos serviços reais continuam **não testados**.

Evidência estruturada: [`PUBLICACAO_VERIFICADA.json`](../downloads/2026-09-06/PUBLICACAO_VERIFICADA.json).
Integridade dos downloads: [`SHA256SUMS.txt`](../downloads/2026-09-06/SHA256SUMS.txt).
Instalação, escopo recuperado e limitações: [guia](MAXIMOS_RECUPERADOS.md).

O commit antigo `961ee39` e as alegações de 138.080 arquivos/27,6M sistemas físicos/278,9B funcionalidades não foram recuperados nem certificados. Os pacotes são bibliotecas e utilitários recuperados, não motores completos ou garantia de hiper-realismo.
