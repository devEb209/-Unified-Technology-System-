# ARKHER V1 — UES Engine for Roblox

> **Status: ROUND 5 delivered — Kernel + ARKHER Studio + World + Image + Motion.**
> 8,504 real systems · 138,472 features · 8,573 modules · 100% of them boot and pass their own self-test.
> That is **85.0% of the 10,000-system floor — and 138.5% of the 100,000-feature requirement**.

ARKHER is **not** a Roblox Studio plugin, not a script pack and not a wrapper around Roblox APIs.
It is a full engine architecture (UES + D-O15 + Singularity AI) that treats Roblox as *one platform
adapter at the bottom of the stack*:

```
ARKHER  ->  UES KERNEL  ->  ARKHER ABSTRACTIONS  ->  PLATFORM ADAPTER  ->  ROBLOX RUNTIME
                                                  \-> HEADLESS ADAPTER -> CI / tests / servers
```

Everything above the adapter line is platform agnostic and runs **outside Roblox** too — which is why
the whole engine is verified in CI by a real Lua VM before it ever reaches Studio.

---

## Download / install (3 ways, all real)

| What | File | How |
|---|---|---|
| **Model** (recommended) | `Releases/ARKHER_V1_ROUND5.rbxmx` | Roblox Studio → right-click `ReplicatedStorage` → **Insert from File** → pick the file. The engine boots itself. |
| **Place** | `Releases/ARKHER_V1_ROUND5.rbxlx` | Double-click / File → Open. A place with ARKHER already installed, streaming on, Future lighting. |
| **Studio plugin** | `Releases/ARKHER_V1_STUDIO_PLUGIN.rbxmx` | Explorer → right-click → **Save as Local Plugin** (or drop it in your Plugins folder). Opens the ARKHER Studio surface. Studio is only the adapter — the IDE is ARKHER's own. |
| **Source (Rojo)** | this folder | `rojo serve` with the included `default.project.json`. |

After insert, press **Play**. The Output window prints the live boot report:

```
====================================================================
ARKHER 1.0.0  (ARKHER V1)  platform=roblox
  modules registered : 8573
  systems online     : 8504  (A=520 S=620 X=410 B=700 U=600 Y=400 C=644 D=640 M=616 E=600 F=700 G=504
                              H=700 I=520 J=330)
  self-test          : 8504 passed / 0 failed
  device             : phone (tier mobile, score 41)
  D-O15 budgets      : frame 16.6ms, draws 500, parts 6000, mem 700MB
  quality preset     : renderScale=0.78 lodBias=1.50 vfx=0.45 npcTick=6
====================================================================
```

A mobile-first HUD is shipped to every player showing live system count, D-O15 quality level and
engine frame cost. Tap it to collapse.

---

## What is actually shipped (Rounds 1–5)

| Category | Family | Systems | Features | State |
|---|---|---:|---:|---|
| **A** | UES / CORE | 520 | 8,080 | complete |
| **S** | D-O15 OPTIMIZATION | 620 | 9,300 | complete |
| **X** | SECURITY / RELIABILITY | 410 | 6,232 | complete |
| **B** | ARKHER STUDIO / IDE | 700 | 11,700 | complete |
| **U** | SCRIPTING / CODE INTELLIGENCE | 600 | 9,640 | complete |
| **Y** | COLLABORATION / PRODUCTION | 400 | 6,560 | complete |
| **C** | SCENE / WORLD | 644 | 10,580 | complete |
| **D** | TERRAIN | 640 | 11,040 | complete |
| **M** | PROCEDURAL GENERATION | 616 | 9,944 | complete |
| **E** | MATERIALS | 600 | 9,640 | complete |
| **F** | RENDERING | 700 | 11,950 | complete |
| **G** | NEURAL / RECONSTRUCTION | 504 | 8,136 | complete |
| **H** | PHYSICS | 700 | 11,600 | complete |
| **I** | ANIMATION | 520 | 8,520 | complete |
| **J** | CHARACTERS / DIGITAL HUMANS | 330 | 5,550 | complete |
| | **Total shipped** | **8,504** | **138,472** | **verified** |

Against the ARKHER spec target of ≥10,000 systems and ≥100,000 functionalities, this is **85.0% of
the system target and 138.5% of the feature target** — the functionality requirement is met and
exceeded, fully finished, no placeholders, no "TODO" systems.
Round-by-round detail: `docs/ROUND1_REPORT.md` … `docs/ROUND5_REPORT.md`. The UI palette and its
accessibility audit are in `docs/DESIGN_SYSTEM.md`.

Underneath the catalog sits the hand-written kernel (every file is real, tested code):

**Motion runtime (Round 5):** `runtime/kits_motion` (12 kits: rigidbody · collider · contact ·
constraint · raycaster · charmotor · vehicle · skeleton · clip · animator · ik · ragdoll),
`physics/world` (fixed-step deterministic world: broadphase, sequential impulse solver, joints,
layers, triggers, explosions, checksum), `physics/character_controller` (capsule sweeps, step-up,
depenetration, moving platforms, jump buffering), `animation/animation_system` (humanoid rigs,
layered playback, foot/look IK, ragdoll blending, LOD ladder + frame budget),
`animation/motion_matching` (trajectory-matched pose search under a budget),
`character/digital_human` (state machine, damage → ragdoll → get-up, 5 appearance tiers, crowds).

**Image runtime (Round 4):** `runtime/kits_render` (12 kits: material · sampler · shadegraph ·
framegraph · camera · visibility · impostor · lightrig · probe · temporal · upscaler · inference),
`materials/material_framework` (18 presets + procedural wear + device tiers),
`render/lighting` (day cycle, Kelvin colour, clustered lights, SH probe GI, fog, ACES tonemap),
`render/virtualization` (HLOD clusters + impostors under triangle/draw budgets),
`neural/reconstruction` (trained render-scale policy + temporal resolve + quantized weight export),
`render/renderer` (the 8-pass budgeted frame graph), `ui/theme` (design system, WCAG-audited).

**World / terrain / procedural runtime (Round 3):** `runtime/kits_world` (12 kits: scenegraph ·
prefab · heightfield · voxel · spline · mesh · chunker · wfc · lsystem · scatter · network ·
simulation), `world/scene` (Scene Framework: BVH raycast, spatial queries, LOD bands),
`world/streaming` (Streaming Director: hysteresis, memory budget, pinning), `terrain/terrain`
(Terrain Framework: tiled heightfields, erosion, rivers, materials, LOD meshes),
`procedural/city` (zoning → lots → buildings), `procedural/worldgen` (8-step deterministic
world pipeline with "Modo Vida Real" simulation).

**Studio / code / collaboration runtime (Round 2):** `runtime/kits_studio` (11 kits: document ·
commands · selection · layout · widget · inspector · nodegraph · source · session · merge ·
taskgraph), `studio/viewport` (Universal Transform Framework), `studio/editor`,
`code/intelligence`, `code/visualscript` (compiles to real Luau), `collab/workspace` (locks +
branches + three-way merge), `collab/build` (incremental pipeline + release gates).

**Kernel (Round 1):**

`bits · class · errors · clock · signal · eventbus · scheduler · jobsystem · promise · depgraph ·
mathx · vec · random · noise · containers · spatial · hash · serialize · ecs · service · state ·
config · validate · reflection · resource · profiler · version · log · loader · testkit ·
security/sandbox · security/integrity · platform/adapter · platform/roblox · platform/headless ·
do15/device · do15/budget · do15/controller · do15/bottleneck · do15/lod · runtime/kits · engine`

---

## Verify it yourself (no Roblox needed)

```bash
cd Arkher
npm install fengari          # a real Lua VM in Node
node tools/harness.js tests/kernel_spec.lua   # 80 tests / 272 assertions
node tools/harness.js tests/studio_spec.lua   # 30 tests / 121 assertions (Studio, code, collab)
node tools/harness.js tests/world_spec.lua    # 28 tests / 275 assertions (world, terrain, procedural)
node tools/harness.js tests/render_spec.lua   # 21 tests / 182 assertions (materials, rendering, neural)
node tools/harness.js tests/motion_spec.lua   # 25 tests / 218 assertions (physics, animation, characters)
node tools/harness.js tests/engine_spec.lua   # boots all 8,504 systems + self-tests
python3 tools/validate_release.py             # byte-checks the .rbxmx / .rbxlx
```

Inside Roblox the same tests run through `arkher/kernel/testkit`.

---

## Design rules that are enforced, not just written down

1. **Nothing is copied.** Every external capability (DLSS/FSR-class reconstruction, Nanite-class
   geometry virtualization, GI, motion matching…) is re-designed as an ARKHER framework with its own
   architecture. See `docs/LIMITATIONS_AND_SUBSTITUTES.md`.
2. **Roblox never leaks upward.** `src/platform/roblox.lua` is the only file allowed to touch a
   Roblox API. It is lazy-loaded so the whole engine still runs headless.
3. **Mobile is the design target, not the fallback.** D-O15 device tiers start at low-end phones and
   every budget is a measured number (`src/do15/device.lua`).
4. **Portable by construction.** Luau has no bitwise operators, Lua 5.3 has no `bit32` — ARKHER ships
   `src/kernel/bits.lua` so hashing, RNG and noise give *identical results on every host*.
5. **Every system proves itself.** `engine:verify()` runs 8,504 self-tests at boot.

---

## Roadmap

Rounds are 10–20% each, delivered complete. See `docs/ROADMAP.md`.

| Round | Categories | Systems | Cumulative |
|---|---|---:|---:|
| **1 (done)** | A core, S D-O15, X security | 1,550 | 15.5% |
| **2 (done)** | B editor/IDE, U scripting, Y collaboration | 1,700 | 32.5% |
| **3 (done)** | C scene/world, D terrain, M procedural | 1,900 | 51.5% |
| **4 (done)** | E materials, F rendering, G neural reconstruction | 1,804 | 69.5% |
| **5 (done)** | H physics, I animation, J characters/digital humans | 1,550 | **85.0%** |
| 6 | K NMN/NPC, L world simulation | ~1,300 | ~98% |
| 7 | N VFX, O audio, P gameplay, Q UI, R networking | ~2,100 | ~119% |
| 8 | T Singularity AI, V assets, W cinematic, Z original tech | ~2,600 | ≥145% of the 10k floor |

---

*ARKHER is part of the Unified Technology System (UES · D-O15 · Singularity AI · SNB · DsOS).*
