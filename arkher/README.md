# ARKHER STUDIOS — Geração 1 em desenvolvimento

Implementação focada **somente no ARKHER: UES + Singularity AI sobre a plataforma Roblox**, seguindo o arquivo `ARKHER STUDIOS👑` do main, commit `c849100aec49e344cf915cbbe5b31bcc707963ee`.

**Não é um plugin do Roblox Studio.** É uma experiência com editor próprio, scene graph de dados, comandos, histórico, simulação e uma camada Roblox de materialização. O instalador `.rbxm` serve apenas para transportar essa experiência a um place.

**Esta entrega ainda não é a V1 integral do prompt.** Os mínimos de 10.000 sistemas reais e 100.000 funcionalidades não foram atingidos/certificados. Não foram gerados getters, aliases ou arquivos vazios para inflar essa contagem. Os requisitos restantes continuam na V1; veja [V1_SCOPE.md](V1_SCOPE.md).

## Abrir a experiência

### Caminho recomendado: `.rbxl`

1. Abra **`ARKHER_STUDIOS_G1_DEV.rbxl`** no Roblox Studio.
2. Pressione **Play / F5**.
3. O editor nativo aparece no PlayerGui. O mundo é gerado pelo Core e materializado pelo adapter no cliente.
4. Selecione um objeto pelo viewport ou pela hierarquia. Use **Mover/Girar/Escalar**, os valores do inspector ou as ações rápidas.

O editor aparece **durante Play**, não como janela/plugin do Studio em modo de edição. O place pode ser publicado pelo proprietário para testar a experiência no aplicativo Roblox, inclusive em celular. Isso não instala Roblox Studio no celular.

### Alternativa: `.rbxm`

Use um **place vazio**. Insira `ARKHER_STUDIOS_G1_DEV.rbxm` por **Insert from File** e execute no **Command Bar de edição**, antes de Play:

```lua
require(workspace.ARKHER_G1_PACKAGE.Install).Install(true)
```

O instalador verifica conflitos, copia os componentes e registra Undo no Studio. Não sobrescreve uma instalação existente. Os scripts transportados estão desativados até a instalação. Depois, pressione Play.

**Não instalar às cegas em um jogo em produção:** esta é uma experiência de edição. Por padrão, `DisableAvatar = true` impede o carregamento automático de novos avatares; a câmera do editor é controlada no cliente. Objetos e Characters existentes não são apagados pelo bootstrap. Para um jogo existente, revise e teste a integração separadamente.

## O que possui implementação nesta etapa

- Scene graph próprio e dados serializáveis, sem usar Instances como fonte de verdade.
- Entidades, hierarquia, transformações locais e composição de posição/rotação/escala uniforme.
- Transações com pré-validação integral, revisões, undo/redo, duplicação e exclusão de subárvores.
- Editor em ScreenGui: viewport, hierarquia com linhas virtualizadas, inspector, gizmos, atalhos, import/export JSON e painel de IA.
- Geração determinística de heightfields e de uma cidade por malha de quarteirões.
- Pincéis de elevar, rebaixar, suavizar e nivelar os dados do heightfield.
- Linguagem de grafos executável: operadores numéricos/vetoriais, tempo, dependências, detecção de ciclos e alteração de posição; oscilação demonstrável durante a simulação.
- Simulação própria num fork: gravidade, colisões conservadoras AABB e contato com heightfields verticais. Parar restaura o estado autorado.
- Materialização local por Parts, materiais/luzes suportados, pooling e orçamento adaptativo com EMA e hysteresis.
- Heightfields podem ser materializados em blocos agregados; a altura original permanece no Core e o erro de aproximação é informado como `Δh`.
- Sessão de edição autoritativa no servidor; revisões rejeitam sobrescritas concorrentes desatualizadas.
- Rate limits, aprovação explícita de planos, vínculo ao usuário, expiração e rejeição de planos antigos.
- Adapter DataStore com compare-and-swap e erro honesto quando não configurado.
- Planejador local explícito e adapter HTTPS para provider compatível com Chat Completions. Plano externo também passa pelas mesmas validações e confirmação.

Esses itens são **capacidades implementadas no código desta etapa**, não uma contagem formal dos sistemas exigidos pelo catálogo. Componentes que dependem do Roblox ainda precisam de teste integrado no Studio.

## Controles

| Ação | Controle |
|---|---|
| Orbitar | Botão direito + arrastar; um dedo em touch |
| Mover câmera | Botão do meio; WASD com cursor no viewport; analógico esquerdo |
| Zoom | Roda; pinça com dois dedos; R2/L2 |
| Selecionar | Clique/toque; A no gamepad no centro do viewport |
| Enquadrar | F ou botão do inspector |
| Transformar | Gizmos ou números no inspector |
| Desfazer/refazer | Ctrl+Z / Ctrl+Y ou toolbar |
| Remover | Delete ou botão do inspector, com Undo |
| Terreno | Selecione o terreno, escolha um pincel e clique/toque no terreno |
| Animação de grafo | Selecione uma entidade → Animar/criar grafo → Simular |

Touch e gamepad têm caminhos de código, **mas não foram testados em dispositivos físicos aqui**. Em VR, a câmera orbital é desativada por precaução; VR não está validado nesta entrega.

## IA: sem falsa conexão

O modo padrão é **Local · regras**, não um LLM. Exemplos executáveis:

```text
crie uma cidade 3x3 seed 42
crie um terreno 16x16 seed 17
crie um cubo x=8 y=12 z=4
crie uma esfera
adicione uma luz
configure noite
otimize o mapa para celulares
```

O pedido de otimização ajusta um orçamento de materialização. **Não é prova de ganho de FPS ou preservação perfeita de qualidade**: essas métricas precisam ser medidas no dispositivo.

A IA retorna uma prévia, não modifica imediatamente o mundo. **Validar e aplicar** usa o plano armazenado no servidor, não operações substituídas pelo cliente. Alterações no projeto ou expiração invalidam a prévia.

### Provider externo opcional

Em `ServerScriptService.ARKHER_SERVER.Config`, configure `Provider.Endpoint`, `Provider.Model` e, se necessário, o **nome** do segredo em `Provider.SecretName`.

- O endpoint deve ser HTTPS e compatível com Chat Completions/texto JSON.
- Habilite HTTP nas configurações da experiência. HTTP não está habilitado por padrão. [1](https://create.roblox.com/docs/cloud-services/http-service)
- Configure o valor da chave no **secrets store do Roblox**. O código usa `GetSecret(...):AddPrefix("Bearer ")`; nunca converte o segredo em texto nem o replica ao cliente. [2](https://create.roblox.com/docs/cloud-services/secrets)
- Não coloque chaves no repositório, no chat, no PlayerGui ou em ReplicatedStorage.
- No editor, escolha explicitamente **Provider externo**. O pedido e um resumo da cena serão enviados ao serviço configurado.

Nenhum provider real foi chamado nos testes desta entrega. Disponibilidade, custos, resposta do modelo e quotas dependem da configuração e do serviço.

## Permissões e projetos salvos

No Studio, os jogadores de teste são permitidos. Em uma experiência pessoal publicada, o criador é permitido. Outros editores precisam constar explicitamente em `Config.EditorUserIds`:

```lua
EditorUserIds = {
    [123456789] = true,
}
```

Em experiências de grupo, configure os UserIds autorizados. Não é concedida permissão automaticamente ao primeiro jogador que entrar.

`PersistenceEnabled` começa como `false`. Para DataStore, publique/configure a experiência e habilite o acesso apropriado aos serviços. A sessão compartilha um projeto de equipe identificado por `DataStoreName` + `DataStoreKey`.

- **Salvar** só informa sucesso quando `UpdateAsync` retorna a nova versão.
- Se já houver uma versão persistida desconhecida desta sessão, carregue-a antes de salvar: o adapter não a sobrescreve cegamente.
- Um carregamento inválido ou que fique desatualizado durante I/O não substitui o projeto.
- Exportar JSON é independente de DataStore e preserva o **estado autorado**, não o fork de simulação. Copiar/importar pelo editor tem orçamento de 200 KB por operação para evitar travar a interface.
- Não existe ainda exportação/publicação automática de novos jogos Roblox a partir de um cliente mobile. Isso permanece requisito de produção da V1.

## Limites técnicos explícitos

- AABB é uma aproximação: esferas/cilindros não possuem colisão geométrica exata aqui; não há solver completo de corpos rígidos, OBB, cloth, hair, fluidos, destruição ou CCD geral.
- Dinâmicos devem estar na raiz; heightfields de colisão precisam permanecer verticais. Esses casos são rejeitados, não simulados como se estivessem corretos.
- O renderizador atual usa o adapter de Parts/luzes. Não há DLSS/FSR, renderização neural, acesso próprio aos buffers GPU ou pipeline completo de GI/path tracing.
- Geometrias fora do alcance/tamanho do adapter são informadas como sem representação; seus dados permanecem no projeto. Não são silenciosamente redimensionadas.
- `LightingStyle`/`PrioritizeLightingQuality` não são alterados por scripts. Configure o estilo desejado manualmente no Studio. [3](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Os gizmos `Handles`/`ArcHandles` são primitivas da **camada de plataforma**; comandos, transformações e histórico pertencem ao ARKHER. [4](https://create.roblox.com/docs/en-us/reference/engine/classes/Handles.md)
- A programação disponível é o grafo de dados descrito acima. Não existe execução livre de Lua, nem IDE completa com breakpoints, autocomplete, refactoring e sandbox de plugins nesta etapa.
- Ainda não foram implementados o NMN completo, digital humans, áudio completo, sistemas de gameplay, marketplace, cinemática completa e várias outras famílias do prompt.

## Validação e reprodução

Requer Node 22+ e Python 3.11+ apenas para as ferramentas de construção; o produto executa Luau no Roblox.

Na raiz da cópia das fontes:

```sh
npm ci --ignore-scripts --prefix tools/roblox-package
node arkher/tools/test.mjs
node arkher/tools/build.mjs
python3 arkher/tools/package.py
```

- `test.mjs`: lógica Core/Session e adapter DataStore com mock, via Luau WASM; compila também os scripts de plataforma.
- `build.mjs`: arquivos binários nativos LZ4; releitura nativa e independente; hierarquia, strings e booleanos exatos. O leitor independente usa tolerância relativa `2e-6` para Float32; a comparação nativa permanece exata.
- `package.py`: ZIP único, CRC e hashes dos binários.

**Roblox Studio, cliente/servidor reais, DataStore real, provider externo, mobile, console e VR: não testados neste ambiente.**

### Smoke test necessário no Studio

1. Abrir o `.rbxl` e Play; conferir Output e o editor.
2. Criar, selecionar, transformar, duplicar e excluir; desfazer/refazer.
3. Gerar terreno/cidade; aplicar pincéis.
4. Simular e parar; verificar restauração do estado autorado.
5. Criar o grafo de oscilação; editar o JSON; rejeitar um ciclo.
6. Planejar localmente e confirmar; verificar que a prévia sozinha não altera o projeto.
7. Testar dois clientes autorizados e conflito de revisão.
8. Testar um usuário sem permissão.
9. Configurar e testar DataStore/provider separadamente, sem publicar segredos.
10. Testar touch, teclado/mouse e gamepad em hardware real; verificar consumo e frame time.

Licenças existentes do repositório não foram alteradas; nenhuma alegação jurídica/patentária foi certificada por esta implementação.
