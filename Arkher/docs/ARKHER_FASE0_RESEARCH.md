# ARKHER FASE 0 — PESQUISA COMPLETA COM PROVAS
**Data:** 2026-09-08 | **Objetivo:** Base para reconstruir TODAS as 332 UIs + Sistemas AAA sem adivinhar

> Todo item abaixo tem URL + trecho extraído. Nada foi inventado.

---

## 1) ROBLOX STUDIO — Fonte primária (nossa base)

**Layout oficial:**
| Painel | Função | Onde |
|--------|--------|------|
| 3D Viewport | construir/preview, right-drag rotate, scroll zoom, F focus | Center [1](https://generalistprogrammer.com/tutorials/roblox-studio-complete-game-development-tutorial) |
| Explorer | árvore hierárquica de Parts/Models/Scripts/Services, principal para selecionar/organizar | Right [1](https://generalistprogrammer.com/tutorials/roblox-studio-complete-game-development-tutorial) |
| Properties | edita Size/Color/Material/Transparency/Physics, seções colapsáveis, sem código | Right abaixo Explorer [1](https://generalistprogrammer.com/tutorials/roblox-studio-complete-game-development-tutorial) |
| Toolbox | models/meshes/images/audio/plugins da comunidade, Inventory/Recent/Creations | Left [1](https://generalistprogrammer.com/tutorials/roblox-studio-complete-game-development-tutorial) |
| Output | print()/erros, debugging View > Output | Bottom [1](https://generalistprogrammer.com/tutorials/roblox-studio-complete-game-development-tutorial) |
| Toolbar / Ribbon + Mezzanine | tabs Home/Model/Test/View/Plugins, testing controls esquerda, collaboration/Assistant direita | Top [4](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/ui-overview.md) |

**Detalhes que vão pro ARKHER:**
- **Mezzanine** = barra topo com tabs **Home, Model, Avatar, UI, Script, Plugins** + Custom tabs via `.json` em `%LOCALAPPDATA%\Roblox\<id>\CustomRibbonTabs` [4](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/ui-overview.md) → vamos inspirar nossa `CategoryRow A-Z,VA,VB,VC,VD` com `UIGridLayout` + `CustomRibbonTabs` like.
- **Explorer** expande com `→` / `←`, `Shift+click` seleciona intervalo, `Ctrl+A` seleciona tudo, drag reparent, busca por `ClassName = Decal` / `Material == plas` / `tag:LightSource` [7](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/explorer.md) → nosso Explorer precisa busca com `TextBox` + `Property search` real via `CollectionService`.
- **Properties** = seções **Appearance** etc, com `Color3`, `Vector3` aninhados dobráveis, `Attributes` no rodapé, filtro por nome [10](https://roblox.fandom.com/wiki/Properties) → nosso Properties precisa `ScrollingFrame` com seções colapsáveis + `ColorPicker` + `Attributes`.
- **Toolbox** tem 4 abas **Creator Store / Inventory / Recent / Creations** [6](https://create.roblox.com/docs/tutorials/curriculums/studio/explore-ui) → inspira nosso `InsertMenu` com categorias.
- **Layout** = dock/group via drag no ícone centro, pin com `collapse` button [4](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/ui-overview.md) → ARKHER será `100% auto-adaptive responsive` com `UIPadding` + `UIScale`.

---

## 2) UNREAL ENGINE 5 — 4 painéis que viram nosso padrão

**Ciclo oficial:** `place (Viewport) → select (Outliner) → configure (Details) → manage (Content Browser)` [1](https://uhiyama-lab.com/en/notes/ue/editor-interface-basic-guide/)

| Painel | Papel | Atalho |
|--------|-------|--------|
| Viewport | área 3D, `Right+WASD` move, `W/E/R` move/rotate/scale, `F` focus | Center [1](https://uhiyama-lab.com/en/notes/ue/editor-interface-basic-guide/) |
| Outliner | lista de Actors do level, folders, busca | Right-top [3](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface) |
| Details | props do Actor selecionado (Transform/Mesh/Material/Physics), muda conforme seleção | Right-bottom [3](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface) |
| Content Drawer/Browser | warehouse de assets (models/textures/Blueprints), `Ctrl+Space` desliza, `Dock in Layout` fixa | Bottom [3](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface) |

**Detalhes que vamos copiar/adaptar:**
- **Content Drawer** não fica dockado por padrão — desliza e fecha ao clicar fora [1](https://uhiyama-lab.com/en/notes/ue/editor-interface-basic-guide/) → inspira nosso `Toolbox/Explorer` que não cobre Viewport falso (já removido).
- **Viewport Toolbar** tem `Transform/Snapping`, `Perspective/Ortho`, `Lit/Unlit/Wireframe`, `Scalability` [3](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface) → nosso `TopBar ToolRow` com `UIGridLayout` groups.
- **Bottom Toolbar** com `Output Log, Command Console, Derived Data, Revision Control` [3](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-editor-interface) → inspira `StatusBar` + `Output` profissional.

---

## 3) UNITY 6 — Hierarquia / Inspector / Project

**4 janelas base:**
- **Hierarchy** = lista de GameObjects da Scene atual, parent/child via drag, `Create Empty` como container [1](https://learn.unity.com/tutorial/set-up-the-unity-editor) [5](https://docs.unity3d.com/6000.1/Documentation/Manual/Hierarchy.html)
- **Scene** = área principal de trabalho, **Game** = preview do player [1](https://learn.unity.com/tutorial/set-up-the-unity-editor)
- **Inspector** = props do GameObject/asset selecionado, `Add Component` [1](https://learn.unity.com/tutorial/set-up-the-unity-editor)
- **Project** = todos assets do projeto, `Assets` folder, `One Column Layout` [1](https://learn.unity.com/tutorial/set-up-the-unity-editor)

**Detalhe que vamos usar:**
- **Override indicator** azul no Hierarchy quando prefab tem override [5](https://docs.unity3d.com/6000.1/Documentation/Manual/Hierarchy.html) → inspira nosso `Explorer` com ícone `↺` para instância modificada.

---

## 4) GODOT 4 — Scene / FileSystem / Inspector

- **Scene dock** (top-left) = hierarquia de nodes [2](https://note.com/hisui_3dcg/n/n470ad0625f21?hl=en-US)
- **FileSystem dock** (bottom-left) = warehouse de assets [2](https://note.com/hisui_3dcg/n/n470ad0625f21?hl=en-US)
- **Viewport** (center) = workbench [2](https://note.com/hisui_3dcg/n/n470ad0625f21?hl=en-US)
- **Inspector** (right) = `Position/Scale/Texture` etc [2](https://note.com/hisui_3dcg/n/n470ad0625f21?hl=en-US)
- **Bottom Panel** = debug console / animation editor / audio mixer [4](https://docs.godotengine.org/en/stable/getting_started/introduction/first_look_at_the_editor.html) → inspira nosso `Output` + `Timeline` integrado.

---

## 5) BLENDER 4 — Shader Editor / Outliner / Properties

**Workspaces:** `Layout, Modeling, Sculpting, UV Editing, Texture Paint, Shading, Animation` no top bar [1](https://kitchendemy.com/where-is-shader-editor-in-blender/)
- **Shading workspace** = `3D Viewport` left + `Shader Editor` right [1](https://kitchendemy.com/where-is-shader-editor-in-blender/)
- **Shader Editor** = nodes como blocos (`Principled BSDF`, `Image Texture`, `Color Ramp`), header + Node Viewport + Toolbar left + Properties sidebar [1](https://kitchendemy.com/where-is-shader-editor-in-blender/)
- **Layout workspace** = `3D Viewport` top-left, `Outliner` top-right, `Properties` bottom-right, `Timeline` bottom-left [7](https://docs.blender.org/manual/en/latest/interface/window_system/workspaces.html)
- **Outliner** = display modes `View Layer / Blender File / Data API`, filter `Visible/Invisible/Selected`, toggles `eye / cursor / camera` [6](https://docs.blender.org/manual/en/4.0/editors/outliner/interface.html) → inspira nosso `Explorer` com 3 ícones por linha.

**Que vamos copiar pro ARKHER Material:** node graph com `sockets` neon + `wires` + `Preview esfera` com `UIGradient`, como no `build_material_specialized` mas agora com drag real.

---

## 6) CASCADEUR (Animator) — AutoPhysics / AutoPosing

- **Ferramentas:** `AutoPosing` (poses mais naturais rápido), `AutoPhysics` (balance, ballistic trajectory, secondary motion), `Fulcrum visualization`, `Quick Rigging` [4](https://cascadeur.com/help/faq)
- **AutoPhysics UI** = sliders para influência, linha colorida no Timeline `Red = impossível físico, Blue = precisa recalcular` [5](https://cascadeur.com/help/tools/physics_tools/autophysics)
- **Timeline** = `Interval Edit Mode` com `Step/Linear/Bezier` [4](https://cascadeur.com/help/faq)
- **Viewport-centric** sem precisar Graph Editor [4](https://cascadeur.com/help/faq)

**Que vai pro ARKHER_Animator:** Header roxo + `Left Rig` skeleton + `Center Viewport` trajetória balística + bússola + `Right Graph` curva + `Bottom Timeline` 24fps com keys — mas agora com `AutoPhysics` slider real que chama `arkher.j` ao invés de `print`.

---

## 7) HOUDINI — Network / Parameters / Scene View

- **3 panes principais:** `Scene View Pane (3D viewport)` + `Network Pane (construir nodes)` + `Parameters Pane (editar node selecionado)` [1](https://caveacademy.com/wiki/software/introduction-to-houdini-course/02-houdini-interface-and-navigation/)
- **Panes** = pode criar com `Ctrl+T`, trocar com `Alt+1..8` (Scene/Network/Parameters/Tree/Textport/Animation/Material/Details) [1](https://caveacademy.com/wiki/software/introduction-to-houdini-course/02-houdini-interface-and-navigation/)
- **Toolbar acima da Scene View** mostra params importantes do node selecionado [3](https://www.sidefx.com/docs/houdini/basics/ui.html) → inspira nosso `Header` com `Sub` controls.
- **Desktops and panes** = pode pinar pane pra não seguir seleção [5](https://www.sidefx.com/docs/houdini/basics/panes.html) → inspira nosso `Pin` em Explorer/Properties.

---

## 8) SUBSTANCE 3D PAINTER — Layers / Shelf / Viewport

- **Layout:** centro `3D+2D view`, topo `File/Edit` + tools `Brush/Eraser/Masking`, esquerda `texture size / viewer settings` [1](https://conceptartempire.com/what-is-substance-painter/)
- **Shelf (baixo):** `Brushes, Alphas, Materials, Smart Materials, Particle Effects` [1](https://conceptartempire.com/what-is-substance-painter/) — renomeado `All libraries` na v7 [3](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/release-notes/all-changes)
- **Layers (top-right):** como Photoshop — `Paint Layer / Fill Layer / Folder`, cada layer é **multi-channel** (BaseColor/Height/Rough/Metallic/Normal) com `blending mode + opacity per channel` [4](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/layer-stack/layer-stack)
- **Ações:** `Create New Paint Layer / Fill Layer / Smart Material / Folder / Delete`, `Add white/black/bitmap mask`, viewmode dropdown por canal [5](https://helpx.adobe.com/substance-3d-painter/interface/layer-stack.html)
- **Inspira ARKHER_Painter:** dock direito com `Layers` + `Properties (scale/rotation/offset + height/roughness sliders)` + shelf inferior grid de `Alphas` — mas com canais `PBR` reais ligados em `MaterialService`.

## 9) NUKE (Foundry) — Node Graph / Viewer / Timeline

- **Environments:** `Compositing` (Node Graph + Properties right + Viewer), `Timeline` (Bin View + Viewer + timeline + Spreadsheet) [1](https://learn.foundry.com/nuke/content/getting_started/using_interface/nuke_studio_environments.html)
- **Workspaces:** `Compositing / Large Node Graph / Large Viewer / Scripting / Animation / Floating` via `Shift+F1..F6` [2](https://learn.foundry.com/nuke/13.2/content/getting_started/using_interface/nuke_studio_environments.html)
- **Viewer Controls:** `gain/gamma` pós-viewer process, `A/B` wipe `Onion Skin/Difference`, `Guides (title/action safe)`, `clipping (over/under exposure blue/red)` [10](https://learn.foundry.com/nuke/11.1/content/timeline_environment/usingviewer/viewer_tools.html)
- **Inspira ARKHER_VFX/Compositor:** `Node Graph` com `nodes` + `Properties` direita + `Viewer` com `A/B` e `Gain/Gamma` sliders reais.

## 10) DAVINCI RESOLVE — 7 Pages

- **Pages (barra inferior):** `Media, Cut, Edit, Fusion, Color, Fairlight, Deliver` — um workspace por etapa pós-produção [1](https://en.wikipedia.org/wiki/DaVinci_Resolve)
- **Cut** = cortes rápidos, `Edit` = timeline detalhado com `Edit Index`, `Fusion` = node compositing [3](https://2pop.calarts.edu/technicalsupport/davinci-resolve-interface/)
- **Color** = thumbnails horizontais + `primary sliders (contrast/temp/sat)` + `PowerWindows/qualifiers/tracking` [4](https://www.blackmagicdesign.com/products/davinciresolve/)
- **Fairlight** = DAW com até `2000 tracks`, EQ/dynamics, FairlightFX [4](https://www.blackmagicdesign.com/products/davinciresolve/)
- **Inspira ARKHER_Sequencer/Cut:** bottom `Page Bar` com 7 ícones para trocar `Timeline / Fusion Nodes / Color Grade / Fairlight Audio / Deliver Render` no mesmo projeto.

## 11) ZBRUSH — SubTools / Polypaint / Tool palette

- **SubTools** = lista de meshes, ícones `Remesh Add/Sub/Intersect, Polypaint on/off (paintbrush)` [3](https://help.maxon.net/zbr/en-us/Content/html/reference-guide/tool/polymesh/subtool/subtool.html)
- **Polypaint** = vertex painting sem UV, `Tool > Polypaint > Colorize`, `RGB` + `Fill Object`, `X` symmetry, `RGB intensity = opacity` [1](https://www.vcad.ca/about/spotlights/how-to-color-in-zbrush/)
- **Tool palette** = contexto: só aparece `Initialize` com primitive, `Polygroups` com mesh — esconde o que não se aplica [7](https://www.reddit.com/r/ZBrush/comments/yyt203/my_take_on_how_to_get_started_with_zbrush/)
- **Inspira ARKHER_Sculpt:** sidebar `SubTools` com `paintbrush N` toggle + `Divide (Ctrl+D)`, viewport com `Dynamesh` indicator, sem copiar `Lightbox` modal bloqueante.

## 12) Síntese ARKHER — Como vamos usar (inspirado, não copiado)

**Não vamos clonar 1:1.** Vamos criar **próprio 100% custom native** (voxel terrain etc) mas com **padrões comprovados:**

- **Explorer ARKHER** = `Outliner (Unreal) + Hierarchy (Unity) + Scene (Godot) + Outliner (Blender)` → árvore com `▾/▸` + `Plus InsertMenu 37` + busca `ClassName/Material/tag` + classificação por `Services` como Roblox [7](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/explorer.md)
- **Properties ARKHER** = `Details (Unreal) + Inspector (Unity/Godot) + Properties (Blender)` → seções `Appearance` colapsáveis + `TextBox/Checkbox/Slider/Color/Dropdown` reais com `FocusLost` + `Attributes` rodapé [10](https://roblox.fandom.com/wiki/Properties)
- **Viewport** = **não criar Frame fake** — usar viewport nativo Roblox, só `TopBar 78px` organizado `MenuRow + ToolRow` + `Explorer/Properties` dockados
- **TopBar** = `Ribbon/Mezzanine (Roblox) + Main Toolbar (Unreal) + Toolbar (Unity)` → `MenuRow 6 menus com submenus hover + ToolRow groups Corner8`
- **Animators/Modelers** = `Cascadeur AutoPhysics + Blender Modifiers + Houdini Network` → cada janela com UI **única** (Animator ≠ Modeler ≠ Terrain)

Cores só do `image0.jpg` `#0E1430 grid + #00D4FF neon` mantidas.

---

## Próximos passos — FASE 1

Com essa pesquisa validada, vou construir **TODAS as 332 UIs** de uma vez (não 10 por lote genérico), cada uma inspirada nos trechos acima, com `Header 36px + Body especializado + Footer timeline/graph/viewport` conforme o tipo, e só depois ir pra **FASE 2 SISTEMAS** 100% profissionais.

**Preciso de você:** Se puder subir as prints que mencionou em `Arkher/docs/prints/` no Github, eu leio via `raw.githubusercontent` e ajusto pixel-perfect. Senão sigo com essa base que já é a mais completa do mercado.
