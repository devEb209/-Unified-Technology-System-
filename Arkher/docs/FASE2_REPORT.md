# FASE 2 — STUDIO V2 100% FUNCIONAL

Commit `4ac7ab23` — 362 files, 16999 insertions. Branch `arena/01a08125`.

## O que foi entregue (não print-only)

### Core cockpit cyber-blue
- `src/core/theme.lua` — tokens ONLY #0E1430 / #00D4FF (image0.jpg) + roles + metrics + WCAG helpers
- `src/core/config.lua` — layout (topBar 76 = 36+36), worldCover 11 hex, OpenLandMap 32
- `src/ui/windows/base_window.lua` — draggable + resizable + header + glow + handle

### Studio real (sem viewport fake)
- `TopBar` 2 rows organizada, botões separados (gap 10/8), stroke, corner 8 — Explorer/Properties toggles, Insert submenu Block●⬢◤◣, Gizmo Select✥↻⤢, Fly F, Maps, **1 botão Singularity** + **All 332**
- `Explorer` REAL — lê `game` hierarchy, busca, expand/collapse, ícones, seleção via `Selection:Set`, highlight sync, `DescendantAdded/Removing` live
- `Properties` REAL — mostra classe, Name live, Transform Position/Size/CFrame, Appearance Color/Material/Transparency/Reflectance, flags Anchored/CanCollide/CastShadow + Script Disabled + ARKHER Tag/LOD — tudo via `ChangeHistoryService:SetWaypoint` (undoável)
- `StatusBar` + `Output` funcional
- `FlyCamera` preservado (RMB drag + WASD Q/E Shift ×3.5, sens 0.22)
- `Gizmo` — `SelectionBox` / `Handles Movement` / `ArcHandles` / `Handles Resize` reais no mundo
- `InsertService` — primitive parts 5 formas, Model, parent workspace, `Anchored true`, `CFrame` da câmera, History

### Integrações mundo real
- `WorldMap` — Mapbox GL vs OSM vs Google, ESA WorldCover 11 classes COG 3×3°, OpenLandMap 32 biomas, GPS latlon, SRTM import, overlay opacity, HttpService bridge
- `AssetBrowser` — Quixel Bridge UDIM LOD + PolyHaven CC0 + SpeedTree Atlas, grid 140×110, Search

### 9 editores AAA únicos (não cor trocada)
1. **Modeler** — Modifier Stack (eye/pin, Collapse) + Tool shelf + Bevel params sliders → `ARKHER_Bevel*`
2. **Animator** — Rig Tree 16 joints + Dopesheet 24f + Graph Editor + Onion Skin, Mixamo/Rokoko import
3. **Material** — Layer Stack UDIM + node graph (Texture→Multiply→PBR) + Preview sphere + Brush bar
4. **Terrain** — Palette Gaea 180+ / WM 100+ + node flow (Mountain→Erosion→Stratify→River) + 3D Preview + Tiled Builds
5. **VFX** — Nuke/Houdini graph (Emit→Velocity→Turbulence→Render) + 18 particles preview
6. **Sculpt** — ZBrush palette 10 brushes + SubTools (Body/Head/Hands/Clothes/Armor) + EditableMesh hint
7. **Audio** — Fairlight 6 strips, meters, faders
8. **Sequencer** — DaVinci 7 pages (Media/Cut/Edit/Fusion/Color/Fairlight/Deliver) + 4 tracks
9. `AssetBrowser` acima

### Singularity Core
- `SingularityChat` — **1 botão TopBar** abre chat canto inferior-direito (380×460), arrastável, não atrapalha viewport, Auto Build (dias/semanas), vê `workspace:GetDescendants()` + estrutura, roteia todos modelos Puter.js `puter.ai.chat(img2txt/txt2vid)` via StarterPlayer bridge, streaming

### Loading
- `LoadingScreen` — logo ARKHER™ 52pt, bar, % , 3 dots pulsáveis, `SetProgress(p,text)` interativa

### 332 UIs únicas
- `src/generated/ARKHER_V1_0001..0332.lua` — cada uma **layout distinto** (15 templates: stack, timeline, layer_graph, node_flow, particle, sculpt, mixer, cinematic, asset_grid, map, code, blueprint, profiler, form, toggles), ícone único, accent `categoryColor`, tamanho/pos random porém legível, **controles funcionais** (Slider/Checkbox/Dropdown/TextField/ColorField) que escrevem `SetAttribute`/`BasePart.Color`/`Material`/`Transparency` com History — nunca `print`
- `GeneratedPalette` — buscável, `▣ All 332` no TopBar, lazy `require` + cache, `Toggle`

### Bootstrap
- `roblox/boot.server.lua` — ground se vazio
- `roblox/hud.client.lua` — monta ScreenGui IgnoreGuiInset, loading 0.15→1.0, services, 9 editores + palette + 332 lazy, `SelectionChanged` → gizmo + status, shortcuts F/Delete, logs Output

## Verificação
- `default.project.json` → `ReplicatedStorage.ARKHER=$path src`, `ServerScriptService.ARKHER_Boot`, `StarterPlayer.ARKHER_HUD`
- Cada módulo usa `BaseWindow` + `Components.init` (Button/Icon/Field/Vector3/Checkbox/Slider/Dropdown/Color) 100% callback, sem prints mortos
- Cores só #0E1430/#00D4FF, corner 8/14, gap 8, gutter 12

## Próximo
FASE3 refinar/testar (validação lazy open 332), FASE5-10 sistemas completos, ImageLabels IDs, RBXL/RBXM, APK — seguindo automático.
