# ARKHER Architecture (V1)

## 1. Layers

```
+------------------------------------------------------------------+
|  Singularity AI  (agents operate the engine through the registry) |
+------------------------------------------------------------------+
|  ARKHER CATALOG   1,550 systems (A core / S D-O15 / X security)   |
+------------------------------------------------------------------+
|  ARKHER RUNTIME   engine.lua  ·  runtime/kits.lua                 |
+------------------------------------------------------------------+
|  UES KERNEL       ecs · scheduler · jobs · bus · resources · ...   |
+------------------------------------------------------------------+
|  PLATFORM ADAPTER  roblox.lua | headless.lua  (validated contract) |
+------------------------------------------------------------------+
|  HOST              Roblox runtime / Studio / Node+Lua VM          |
+------------------------------------------------------------------+
```

## 2. The module contract

Every ARKHER source file is a **factory**:

```lua
--@arkher-module
return function(A)
    local EventBus = A:import("arkher/kernel/eventbus")
    ...
    return Module
end
```

* In Roblox: `require(ModuleScript)(loader)`.
* Headless: the Node harness registers the same factories in a real Lua VM.
* The loader (`src/kernel/loader.lua`) caches instances, detects dependency cycles and records
  per-module load time. There is **no** `script.Parent.Parent.Parent` fragility anywhere.

## 3. Kits — why the catalog is real

A *kit* (`src/runtime/kits.lua`) is a complete working machine: registry, pipeline, cache,
controller, analyzer, budgeter, guard, index, codec, graph, field, predictor, ledger, recovery,
orchestrator, solver, streamer, composer, policy, synthesizer.

A *catalog system* = kit + area-specific configuration + specialized methods + integration hook +
its own executable `selfTest()`. That is why `engine:verify()` can prove all 1,550 systems work
rather than counting files.

## 4. Frame loop

```
Engine:step(dt)
  profiler:beginFrame()      -- hierarchical scoped timing
  budget:beginFrame()        -- per-frame budget reset
  sandbox:resetFrameQuotas() -- security quotas per frame
  bus:flush(n)               -- deferred events, bounded
  jobs:pump(2ms)             -- cooperative coroutine workers
  scheduler:frame(dt)        -- 11 phases, priority + interval + budget aware
  resources:pump(n)          -- streaming under a memory budget
  profiler:endFrame() -> D-O15 controller -> new quality preset every 6 frames
```

## 5. D-O15 (the 15 optimization dimensions)

`resolution · geometry · shadows · lighting · reflections · postfx · particles · textures ·
animation · physics · ai · audio · streaming · network · simulation`

The controller holds a single scalar quality level with a PID loop plus asymmetric response
(drop fast, recover slowly) and projects it onto the 15 dimensions weighted by *perceptual cost*,
so the least visible things degrade first. Device tiers (`potato → mobile → mobileHigh → desktop →
console → desktopHigh → vr`) define hard budgets in real units.

## 6. Security

Nothing privileged happens without a capability grant: `sandbox:invoke(principal, capability, fn)`.
Roles (`viewer`, `builder`, `scripter`, `aiAgent`, `optimizer`, `admin`) plus per-frame and total
call quotas, an audit log and trust scoring. AI agents are principals like everyone else.

## 7. Determinism

`bits.lua` (bit32 on Luau, arithmetic elsewhere) + `random.lua` (xoshiro128\*\*) + `noise.lua`
guarantee that the same seed generates the same world on a phone, on a PC and in CI.

---

## 8. ARKHER Studio (Round 2)

ARKHER Studio is ARKHER's **own** IDE. It is assembled from six kits plus the viewport, and it never
depends on a Roblox editing API:

```
                      studio/editor.lua
   document ──┐   (12 panels · 13 palette commands · 7 tools)
   commands ──┤
   selection ─┼──► editor core ──► studio/viewport.lua  (Universal Transform Framework)
   layout ────┤                     screenToRay · BVH pick · region pick · snapping
   widget ────┤                     axis-constrained gizmo drags · frame/orbit/dolly/pan
   inspector ─┘
```

*Every* editing action is a `command` (undoable, groupable, coalescing) applied to a `document`
(transactional, revisioned, checksummed). That is why undo works across tools, why autosave is a
checksum comparison, and why a Studio session, a headless CI session and a future native ARKHER
shell all behave identically.

**Roblox Studio is an adapter.** `roblox/plugin.server.lua` (shipped as
`Releases/ARKHER_V1_STUDIO_PLUGIN.rbxmx`) hosts that runtime inside Studio: it indexes the payload,
boots the engine, and exposes ARKHER commands (verify · D-O15 optimize · import selection · grid
snap through the Universal Transform Framework · whole-place code analysis · build pipeline ·
project commit · runtime install). Delete the adapter and ARKHER Studio still runs.

## 9. Code intelligence and visual scripting (Round 2)

`source` kit = a real Luau-subset tokenizer → symbol extractor → rule engine. `code/intelligence`
lifts that to project scope: index, lint, complete, go-to-definition, find-references, rename,
dependency graph, unused symbols, docs and metrics. `code/visualscript` and the `nodegraph` kit are
type-checked graphs that **execute** and **compile to Luau source that actually loads** — visual
scripting with no interpreter tax at runtime.

## 10. Collaboration, versioning and build (Round 2)

`session` (presence · per-path locks · ordered op log · OT rebase) + `merge` (three-way with
conflict records) + `collab/workspace` (commits · branches · checkout · history · common ancestor ·
revert) give a project-level version control that is engine-native, not file-based. `taskgraph` +
`collab/build` turn validation, analysis, tests, optimization, packaging and publishing into one
content-hashed incremental graph with release gates: unchanged work is never redone.

---

## 11. The world stack (Round 3)

Scene, terrain and procedural generation are three layers of one stack; each is usable alone and
each is driven by D-O15 budgets rather than by hard-coded constants:

```
   procedural/worldgen.lua      biomes -> terrain -> rivers -> sites -> cities
        |                       -> highways -> vegetation -> population
        +-- procedural/city.lua        grid -> blocks -> zoning -> lots -> buildings
        |
   terrain/terrain.lua          tiled heightfields - materials - erosion - rivers - LOD meshes
        |
   world/scene.lua              scenegraph + prefab + spatial hash + BVH raycast + LOD bands
        |
   world/streaming.lua          chunker + viewers + hysteresis + memory budget + pinning
        |
   runtime/kits_world.lua       scenegraph prefab heightfield voxel spline mesh
                                chunker wfc lsystem scatter network simulation
```

**Determinism is a hard architectural rule here.** Every generator takes a seed, every random draw
goes through `kernel/random` (xoshiro128\*\*) and every noise sample through `kernel/noise`, so
`worldgen:checksum()` is stable across devices and across runs. That is what makes a generated world
*reviewable*: two people on two machines get byte-identical worlds from one number.

**Life without observers.** `Kits.simulation` classifies every entity as full, reduced or
statistical relative to the observer. Distant settlements keep accumulating state through a cheap
aggregate function and reconcile exactly when the observer arrives — the "Modo Vida Real" rule from
the specification, implemented under a per-tick entity budget instead of an unbounded update loop.
