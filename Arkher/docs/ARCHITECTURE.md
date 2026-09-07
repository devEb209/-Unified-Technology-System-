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

---

## 12. The image stack (Round 4)

```
   render/renderer.lua        8 declared passes inside one millisecond budget
        |                     depth -> shadows -> GI -> opaque -> transparent
        |                     -> temporal resolve -> post -> UI
        +-- neural/reconstruction.lua   trained scale policy + temporal accumulation
        +-- render/lighting.lua         day cycle, Kelvin sun, clustered lights, SH probe GI,
        |                               height fog, auto exposure, ACES tonemap
        +-- render/virtualization.lua   clusters -> HLOD proxies -> impostors, budget resolve
        +-- materials/material_framework.lua  presets, layers, procedural wear, device tiers
        |
   runtime/kits_render.lua    material sampler shadegraph framegraph camera visibility
                              impostor lightrig probe temporal upscaler inference
```

Three rules make this stack different from a pile of effects:

1. **Everything is declared, then culled.** The frame graph knows which pass writes what, so a
   pass nobody reads never runs, optional passes are shed by priority when the budget is tight,
   and transient render targets with disjoint lifetimes share one allocation.
2. **Quality is one dial, not twenty.** `Renderer:applyQuality(q)` moves triangle budget, draw
   budget, impostor error threshold, active lights, shadow casters, cascade count, probe spacing,
   material tier and render scale together — so degradation stays *coherent* instead of ugly.
3. **The reconstruction policy is trained, not tuned.** A small dense network learns the
   frame-time → render-scale relationship from a deterministic synthetic dataset, is quantized to
   8 bits, and ships as weights; the device runs a forward pass, never a trainer.

The design system (`src/ui/theme.lua`) sits beside this stack for the same reason: one source of
truth for colour and metrics, audited against WCAG AA, scaled by D-O15 device tier.

---

## 13. The motion stack (Round 5)

```
   character/digital_human.lua   motor + rig + state machine + IK + ragdoll + appearance + LOD
        |                        9 locomotion states, 5 appearance tiers, crowd path
        +-- physics/character_controller.lua   capsule sweeps, ground probe, step-up,
        |        |                             depenetration, moving platforms, jump buffer
        |        +-- physics/world.lua         fixed step -> broadphase -> narrow phase ->
        |                                      sequential impulses -> position correction ->
        |                                      joints -> signals -> checksum
        +-- animation/animation_system.lua     humanoid builder, layered playback, foot/look IK,
        |        |                             ragdoll blend, 4-band LOD, frame budget
        |        +-- animation/motion_matching.lua   trajectory feature search under a budget
        |
   runtime/kits_motion.lua   rigidbody collider contact constraint raycaster charmotor vehicle
                             skeleton clip animator ik ragdoll
```

Four rules hold this stack together:

1. **One clock, one order.** The world runs on a fixed timestep with a bounded number of substeps;
   integration, broadphase, narrow phase, solving, correction and joints always happen in the same
   order. That is what makes `PhysicsWorld:checksum()` reproducible, and reproducibility is what
   makes replays, rollback netcode and CI regression testing possible at all.

2. **Kinematic characters do not fight the solver.** A `charmotor` is swept, not simulated: it
   slides along contact normals, steps up ledges, is pushed out of overlaps, and only *then*
   writes its position back into the rigid body the rest of the world sees. Fighting between an
   animated capsule and an impulse solver is the classic source of jitter; ARKHER removes the
   fight instead of tuning it.

3. **Animation is budgeted like rendering.** Rigs are sorted by distance and evaluated nearest
   first, at full/half/quarter rate or not at all, until the per-frame budget is spent. The same
   `applyQuality(q)` call that moves triangle budgets moves animation budgets, IK iterations,
   motion-matching search size and character tier distances — so the whole engine degrades as one
   coherent picture.

4. **Physical response is a blend, never a switch.** A ragdoll starts from the animated pose,
   integrates as physical bones with distance joints, detects when it has settled, and blends back
   toward animation on recovery. A character can be hit, fall, settle and stand up without ever
   teleporting or popping.

## 14. The life stack (Round 6)

```
   sim/world_simulation.lua   regions at 3 fidelities, clock/seasons, events, reification
        |                     full (agents) <-> cohort (groups) <-> statistical (rates)
        +-- sim/civilization.lua   settlements, factions, trade routes, laws, war, migration
        |
        +-- npc/agent.lua      4 LOD tiers, BT + utility + GOAP + schedule arbitration,
        |        |             navigation with an LRU path cache, crowd steering, frame budget
        |        +-- npc/mind.lua   perception -> memory -> needs -> emotion -> mindnet policy
        |                           urgency override, wellbeing-delta reward, learning
        |
   runtime/kits_life.lua   mindnet memory need emotion perception behaviortree utility planner
                           navgraph crowd society economy schedule ecology
```

Four rules hold this stack together:

1. **The loop is closed.** Perception writes memories, memories and drives form the observation
   vector, the policy net picks an action, the action changes the world, the change moves the
   NPC's wellbeing, and that delta is the reward that updates the net. Nothing in that chain is a
   lookup table; remove any link and the behaviour degrades in a way you can see.

2. **Biology beats the policy.** A drive above 0.75 urgency overrides the network entirely
   (eat, rest, flee, socialise, work). A learned policy that lets an NPC starve while it optimises
   something else is not intelligence, it is a bug — so the architecture forbids it structurally
   rather than hoping the reward shaping catches it.

3. **Fidelity is chosen by the observer and is reversible.** `classify()` maps observer distance to
   full / cohort / statistical; `aggregate()` folds individuals into cohorts on demotion and
   `reify()` re-materialises them — deterministically, with a plausible history and memories — on
   promotion. The world therefore keeps living at a cost proportional to how much of it anyone can
   actually perceive, which is what makes a living world affordable on a phone.

4. **Consequence propagates, and it is audited.** Ecology feeds economy, economy feeds prosperity,
   prosperity feeds migration and unrest, unrest feeds revolt and law. Every step is numeric, every
   step is written to a chronicle, and `checksum()` over the whole world proves that the same seed
   produces the same history — which is what makes a persistent world testable.
