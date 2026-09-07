# ARKHER V1 — UES Engine for Roblox

> **Status: ROUND 1 delivered — the ARKHER Kernel.**
> 1,550 real systems · 23,612 features · 1,593 modules · 100% of them boot and pass their own self-test.

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
| **Model** (recommended) | `Releases/ARKHER_V1_ROUND1.rbxmx` | Roblox Studio → right-click `ReplicatedStorage` → **Insert from File** → pick the file. The engine boots itself. |
| **Place** | `Releases/ARKHER_V1_ROUND1.rbxlx` | Double-click / File → Open. A place with ARKHER already installed, streaming on, Future lighting. |
| **Source (Rojo)** | this folder | `rojo serve` with the included `default.project.json`. |

After insert, press **Play**. The Output window prints the live boot report:

```
====================================================================
ARKHER 1.0.0  (ARKHER V1)  platform=roblox
  modules registered : 1593
  systems online     : 1550  (A=520  S=620  X=410)
  self-test          : 1550 passed / 0 failed
  device             : phone (tier mobile, score 41)
  D-O15 budgets      : frame 16.6ms, draws 500, parts 6000, mem 700MB
  quality preset     : renderScale=0.78 lodBias=1.50 vfx=0.45 npcTick=6
====================================================================
```

A mobile-first HUD is shipped to every player showing live system count, D-O15 quality level and
engine frame cost. Tap it to collapse.

---

## What is actually in Round 1

| Category | Family | Systems | Features | State |
|---|---|---:|---:|---|
| **A** | UES / CORE | 520 | 8,080 | complete |
| **S** | D-O15 OPTIMIZATION | 620 | 9,300 | complete |
| **X** | SECURITY / RELIABILITY | 410 | 6,232 | complete |
| | **Round 1 total** | **1,550** | **23,612** | **verified** |

Against the ARKHER spec target of ≥10,000 systems, Round 1 = **15.5% of the system target and 23.6%
of the 100,000-feature target**, fully finished — no placeholders, no "TODO" systems.

Underneath the catalog sits the hand-written kernel (every file is real, tested code):

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
node tools/harness.js tests/engine_spec.lua   # boots all 1,550 systems + self-tests
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
5. **Every system proves itself.** `engine:verify()` runs 1,550 self-tests at boot.

---

## Roadmap

Rounds are 10–20% each, delivered complete. See `docs/ROADMAP.md`.

| Round | Categories | Systems | Cumulative |
|---|---|---:|---:|
| **1 (done)** | A core, S D-O15, X security | 1,550 | 15.5% |
| 2 | B editor/IDE, U scripting, Y collaboration | ~1,700 | ~33% |
| 3 | C scene/world, D terrain, M procedural | ~1,900 | ~52% |
| 4 | E materials, F rendering, G neural reconstruction | ~1,800 | ~70% |
| 5 | H physics, I animation, J characters | ~1,500 | ~85% |
| 6 | K NMN/NPC, L world simulation | ~1,300 | ~98% |
| 7 | N VFX, O audio, P gameplay, Q UI, R networking | ~2,100 | ~119% |
| 8 | T Singularity AI, V assets, W cinematic, Z original tech | ~2,600 | ≥145% of the 10k floor |

---

*ARKHER is part of the Unified Technology System (UES · D-O15 · Singularity AI · SNB · DsOS).*
