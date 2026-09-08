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

## 12) RAGE (Rockstar) — Sem editor separado, pipeline via 3ds Max + ImGui debug

- **Não tem editor standalone** — usam `3ds Max / Maya como level editor` com scripts/plugins + pipeline massivamente complicado [3](https://www.reddit.com/r/gameenginedevs/comments/18a2ff2/question_about_rockstars_engine_rage/)
- **Debug UI in-game com Dear ImGui** — tweaka tudo: pedal, glove box, steering height, física [3](https://www.reddit.com/r/gameenginedevs/comments/18a2ff2/question_about_rockstars_engine_rage/) + leak mostra RAGE dev tools com info completíssima [3](https://www.reddit.com/r/gameenginedevs/comments/18a2ff2/question_about_rockstars_engine_rage/)
- **Streaming + HLOD:** mundo em `cells`, `hierarchical spatial + sparse virtual texture + async streaming` sem loading [8](https://www.neogaf.com/threads/why-rockstar-rage-engine-outclasses-commercial-tech.1699203/)
- **Inspira ARKHER_OpenWorld:** `World Cells` + `HLOD` + `sparse virtual texture` + `ImGui-like debug overlay` nativo mas com UI ARKHER cyber-blue, não cópia ImGui.

## 13) ANVIL (Ubisoft) — Procedural + Cluster Geometry

- **Motor interno desde AC1 2007**, usado em todos estúdios Ubisoft (Siege, Riders etc) [2](https://gamejobs.co/Tools-programmer-Anvil-Pipeline-at-Ubisoft-8936)
- **Evolução:** desde Unity já `GPU-driven pipelines + cluster-based geometry` [7](https://www.gamesmarket.global/under-the-hood-ubisofts-anvil-engine-in-assassins-creed-shadows/)
- **Rendering:** `micropolygons` sem LoD popping + `PSODB` (curated PSO database) evoluindo via estatísticas de gameplay [7](https://www.gamesmarket.global/under-the-hood-ubisofts-anvil-engine-in-assassins-creed-shadows/)
- **Procedural World Tools:** geram cidades/vegetação por regras, depois artistas refinam [8](https://vectree.io/c/ubisoft-anvil) + `Crowd NPC 1000s` + `IK cloth/rope` [8](https://vectree.io/c/ubisoft-anvil)
- **Inspira ARKHER_CityGen:** `Procedural rules → City + Vegetation + Roads` com `Cluster geometry` como Anvil, mas com nosso `voxel terrain`.

## 14) CRYENGINE 5 — Sandbox Editor Qt

- **Main Editor:** `Menu Bar` + `Toolbars (EditMode/Object/Terrain/Dialogs)` + `Viewport Perspective` + `RollupBar` + `StatusBar (P4 RC GameFolder)` + `Selection Strip` + `Console` [4](https://www.cryengine.com/docs/static/engines/cryengine-3/categories/1114113/pages/1048817)
- **Migração:** `MFC → Qt QWidgets` desde 5.0, arquitetura modular `EditorQt + EditorCommon + Plugins`, `Sandbox Editor open source no GitHub` [1](https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756813/pages/26875248) [9](https://www.phoronix.com/news/CRYENGINE-Sandbox-Open-Source)
- **Customização:** layout drag/drop + custom toolbar + `todo botão = console command` → scripts Python [3](https://www.reddit.com/r/cryengine/comments/4dwi2w/sandbox_qa_highlights/)
- **Inspira ARKHER_Level:** `RollupBar` vertical com `Objects/Terrain/Entities` + `Qt-like docking` com `UIGridLayout`.

## 15) FROSTBITE (DICE/EA) — Frostbite Editor + Frosty ToolSuite

- **Frostbite Editor:** level design + asset creation + prototyping, integrado com `Perforce`, cross-studio tools para `squad commands + environmental physics` [2](https://grokipedia.com/page/Frostbite_(game_engine))
- **Modding:** `FrostyToolsuite (FrostyEditor + FrostyModSupport + FrostySdk + SdkGenerator)` em `.NET 8 + Avalonia MVVM` [4](https://github.com/NM-20/FrostyToolsuite-V2) + `Frostbite Modding Tool (FMT)` desde 2019 para PC/PS4/PS5/Switch [6](https://github.com/FMTDev/FMT.Releases/blob/main/README.md)
- **Inspira ARKHER_Frost:** `Profile system` por jogo + `Asset import .fbmod/.fifamod` + `Data Explorer`.

## 16) DECIMA (Guerrilla/Kojima) + RE ENGINE (Capcom) — Editors reais

- **Decima:** `Decima Workshop` — `Browse/edit core objects com type info + preview models/textures/shaders + export glTF + repack archives` [4](https://github.com/ShadelessFox/decima) — `Navigator + Core Editor + Model Viewer + Texture Viewer + Shader Viewer` [3](https://github.com/ShadelessFox/decima/releases)
- **RE Engine:** `REE Content Editor` — `ImGui + 3D view pra .mesh/.scn/.pfb, animation preview, collider editor, load direto do .pak, file search, partial patching com bundles JSON, undo/redo` [6](https://github.com/kagenocookie/REE-Content-Editor) + Blender addons `RE Mesh Editor (import/export .mesh .mdf2, MDF material inside Blender, preset, LOD, GPU BC7)` [10](https://github.com/NSACloud/RE-Mesh-Editor) e `RE Chain Editor (physics bone .chain/.chain2)` [1](https://github.com/NSACloud/RE-Chain-Editor)
- **Inspira ARKHER_RE:** `Pak file browser` + `Live 3D preview + collider gizmo` + `Blender-like mesh chain editor`.

## 17) AUTODESK MAYA — Menu Sets + Shelves + Channel Box

- **Layout:** `Menu Sets (Modeling/Rigging/Animation/FX/Rendering)` no dropdown [6](https://help.autodesk.com/view/MAYAUL/2024/ENU/?guid=GUID-F4FCE554-1FA5-447A-8835-63EB43D2690B), `Shelves (Polygons/Sculpting/Animation)` + `Toolbox (Q Select, W Move, E Rotate, R Scale)` [4](https://vagon.io/blog/a-beginners-complete-guide-to-autodesk-maya), `Viewport center (Alt+LMB rotate, Alt+MMB pan, Alt+RMB zoom)` [8](https://saltlady.medium.com/maya-guide-01-navigating-the-interface-99496e499230), `Outliner left`, `Channel Box/Attribute Editor right`, `Timeline bottom` [1](https://www.pose-by-pose.com/post/intro-to-maya-interface-for-animation)
- **Workspaces:** `Maya Classic / Modeling Standard / Animation` customizáveis [4](https://vagon.io/blog/a-beginners-complete-guide-to-autodesk-maya)
- **Inspira ARKHER_Maya:** `Menu Sets dropdown F2-F6` + `Shelf tabs` + `QWER gizmos` já temos mas agora com `Channel Box real` + `Hotbox Spacebar radial`.

## 18) 3DS MAX — Modifier Stack

- **Modifier Stack:** histórico acumulado `objeto base embaixo + modifiers em ordem bottom→top` [1](https://help.autodesk.com/cloudhelp/2023/ENU/3DSMax-Basics/files/GUID-80209C3A-C2E4-4541-8738-D1E5ECE16E9C.htm), `light-bulb on/off`, `+/- gizmo/center`, `Pin Stack + Show End Result` [5](https://download.autodesk.com/us/3dsmax/2012help/files/GUID-911C535D-9003-4925-A064-52835C581DA-339.htm), `Cut/Copy/Paste Instanced, Collapse To Editable Mesh/Poly` [3](https://download.autodesk.com/us/3dsmax/2012help/files/GUID-3B752392-7B10-4D03-B624-51044BF9410-3059.htm)
- **4 Viewports** `T Top, B Bottom, F Front, L Left, P Perspective, U Ortho` + `Alt+W maximize` [9](https://catalogimages.wiley.com/images/db/pdf/9781118575147.excerpt.pdf)
- **Inspira ARKHER_Modeler:** `Modifier Stack real` com `Bend/Taper/Bevel/MeshSmooth` reordenável via drag e `Collapse`.

## 19) TERRAIN — Gaea / WorldMachine / Terragen

- **Gaea (QuadSpinner):** `Engine + UI separados`, `180+ nodes`, `Graph / Layers / Sculpt workflows`, `Erosion strokes pintáveis`, `Tiled Builds`, `PBR viewport`, `Gaea2Houdini` [7](https://blog.quadspinner.com/terrain-app1/) [6](https://beforesandafters.com/2019/06/17/a-new-tool-to-build-worlds-and-erode-them/) — `procedural + layers, mountain drawing, primitive construction` [6](https://beforesandafters.com/2019/06/17/a-new-tool-to-build-worlds-and-erode-them/)
- **WorldMachine:** `node graph 100+ devices (fractal/erosion/river/mask)`, `non-destructive, macro reuse`, `Tiled builds continentes`, export `heightfield/VDM/mesh/r16 + PBR masks` [5](https://www.world-machine.com/) — `simulate, don't sculpt, erosion corta gullies/ridges/sediment` [5](https://www.world-machine.com/)
- **Terragen:** importa `Gaea/WorldMachine` heightmaps, plugin `Kamperov erosion` [4](https://planetside.co.uk/forums/index.php?topic=27572.0)
- **Inspira ARKHER_Terrain:** `Node Graph erosion + Erosion brush` + `Layers` + `Tiled export`.

## 20) ASSETS — Quixel Megascans / PolyHaven / SpeedTree

- **Megascans:** Bridge app importa `3D Assets + Surfaces` em Mixer [2](https://docs.quixel.com/mixer/1/en/topic/importing.html), packs `UDIM, ID maps, multi-res 2K-8K, LODs 3+` [3](https://www.artivoxa.com/quixel-megascans-vs-polyhaven-which-free-library-wins-for-photorealism/), integração `Houdini megaH` com `Mega Load HDA + Library panel com categorias biotopes + packed disk primitives + Mantra/Redshift shader` [4](https://jurajtomori.wordpress.com/2019/04/23/megah-megascans-to-houdini-integration-2/)
- **PolyHaven:** `CC0 sem fricção legal`, single 4K pack [3](https://www.artivoxa.com/quixel-megascans-vs-polyhaven-which-free-library-wins-for-photorealism/)
- **SpeedTree 8.2+:** `merge photogrammetry mesh + Stitch + LOD + Atlases multi-cutout` [6](https://magazine.artstation.com/2019/11/creating-beautifully-merged-photogrammetry-trees-with-speedtree/) + `procedural branches + gizmo` [6](https://magazine.artstation.com/2019/11/creating-beautifully-merged-photogrammetry-trees-with-speedtree/)
- **Inspira ARKHER_Assets:** `Bridge-like browser` com `CC0 + Megascans-style LOD/UDIM` + `SpeedTree merge` mas nativo Roblox.

## 21) MAPS / GPS / BIOMES — Mapbox / OSM / ESA WorldCover / OpenLandMap

- **Mapbox GL JS:** base `OSM + proprietary`, `vector maps interativas`, SDKs `JS/Android/iOS/macOS/Qt/Unity` [2](https://wiki.openstreetmap.org/wiki/Mapbox_GL), features `3D extrusion, DEM terrain, GeoJSON, offline` [2](https://wiki.openstreetmap.org/wiki/Mapbox_GL) — pricing `$5/1k loads após 50k free, geocode $0.75/1k` [3](https://www.woosmap.com/blog/alternative-to-mapbox)
- **Google Maps vs Mapbox vs OSM:** Google `99% coverage, $7/1k loads após 28.5k` [3](https://www.woosmap.com/blog/alternative-to-mapbox), OSM `ODbL attribution, self-host/MMapLibre fork sem billing` [6](https://api7.ai/learning-center/api-101/mapping-and-geolocation-apis)
- **ESA WorldCover:** `10m resolução global 2020/2021 Sentinel-1/2`, 11 classes `Tree10 #006400, Shrub20 #ffbb22, Grass30 #ffff4c, Crop40 #f096ff, Built50 #fa0000, Bare60 #b4b4b4, Snow70 #f0f0f0, Water80 #0064c8, Wetland90 #0096a0, Mangrove95 #00cf75, Moss100 #fae6a0` [2](https://developers.google.com/earth-engine/datasets/catalog/ESA_WorldCover_v200), tiles `3x3° 2651 GeoTIFF COG EPSG:4326 ~117GB` [7](https://worldcover2020.esa.int/data/docs/WorldCover_PUM_V1.1.pdf)
- **OpenLandMap Biomes:** `Potential distribution 32 biomas 1km, palette 20 cores` [9](https://developers.google.com/earth-engine/datasets/catalog/OpenLandMap_PNV_PNV_BIOME-TYPE_BIOME00K_C_v01)
- **Inspira ARKHER_Maps:** `Mapa Mundi GPS real + Biome overlay ESA 11 + 32 biomas + Elevation 30m DEM` integrados via `HttpService` e já mandando dados pra IA analisar estrutura/ideias/melhor local.

## 22) PUTER.JS + SINGULARITY CORE — IA AAAA Automática

- **Puter.js:** `single script tag` dá `auth + fs + kv + AI (500+ models GPT/Claude/Gemini/Grok/Llama/DALL-E) sem API keys (User-Pays)` [2](https://medium.com/@atul4u/puter-js-streamline-your-backend-with-the-ultimate-serverless-framework-a982227dcb26) — `puter.ai.chat({model,stream,reasoning_effort,tools:web_search})`, `txt2img, img2txt, txt2speech, speech2speech, txt2vid (Sora)` [1](https://docs.puter.com/AI/) — `listModels/listModelProviders` [7](https://docs.puter.com/AI/listModels/)
- **Singularity (repo):** `AGI Unaware` roteia cada tarefa pro modelo-especialista (`geração 3D → modelo 3D, textura → img, animação → motion`), memória/contexto, verificação/fallback, multimodal, frontend independente — **agora só 1 botão TopBar → chat arrastável canto** (draggable, minimizável, não atrapalha viewport) + `modo automático` que vê jogo/padrão/estrutura/ideias e constrói sozinho dias/semanas cri-nado modelos complexos com `referências web + textura/profundidade/dobras/física` perfeitas, Dev interfere quando quiser.
- **Inspira ARKHER_IA:** `Singularity Core` no `StarterPlayer` com `puter.ai.*` + `web_search` tool + `reference scraper`.

## 23) Síntese ARKHER — Como vamos usar (inspirado, não copiado)

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
