# Roblox limitations → ARKHER substitutes

Rule: identify the limitation, build an ARKHER abstraction, keep the dependency inside the adapter.
The registry below is live in code (`src/platform/adapter.lua`, `Adapter.LIMITATIONS`).

| Limitation (Roblox) | ARKHER substitute | Where |
|---|---|---|
| No user-authored GPU shaders | **ARKHER Material Framework** — layered PBR parameter synthesis, SurfaceAppearance composition, screen-space post stack assembled from viewport composition, decals and adaptive atlases | Round 4 (E/F) |
| No compute shaders | **ARKHER Compute Fabric** — parallel Luau actor pools with deterministic job-graph partitioning and cached result fields | Kernel job system (Round 1) + Round 4 |
| No engine-level realtime GI control | **ARKHER Global Illumination Framework** — precomputed irradiance probe volumes plus runtime light-transport approximation projected into part/atmosphere parameters | Round 4 |
| Harsh instance / draw-call budget (mobile) | **ARKHER Geometry Virtualization** — chunked instancing, impostor synthesis, HLOD cascades, D-O15 budget-driven streaming | Round 1 (LOD/streaming primitives) + Round 4 |
| No DLSS/FSR-style reconstruction hooks | **ARKHER Reconstruction Framework** — temporal detail redistribution, adaptive render scaling through viewport composition, perceptual quality controller | Round 1 (controller) + Round 4 (G) |
| Single-threaded script semantics | **ARKHER Job System** — cooperative coroutine pool with time slicing, dependencies and deterministic completion, mapped onto Actors where available | Round 1 |
| Limited profiling surface | **ARKHER Profiler + Bottleneck Analyzer** — hierarchical scopes, percentile analysis, 9 detection signatures and an executable optimization plan | Round 1 |

| No editable code surface for plugins | **ARKHER Source Model** — tokenizer, symbol extractor, rule-based diagnostics, completion, rename and metrics shipped as engine code; the drawing surface stays in the adapter | Round 2 (U) |
| No peer-to-peer networking | **ARKHER Session Layer** — presence, per-path locks, ordered op log and operational-transform rebase, transport-agnostic by design | Round 2 (Y) |
| No engine-level version control | **ARKHER Project VCS** — commits, branches, checkout, history, common-ancestor and three-way merge over the project tree | Round 2 (Y) |
| No incremental build system | **ARKHER Task Graph** — dependency topology with content input hashing, artifact cache and invalidation cascade | Round 2 (B/U/Y) |

| No compute-shader meshing | **ARKHER Voxel Surface Extractor** — CPU sparse-volume face extraction, flood fill and mesh welding under a D-O15 mesh budget | Round 3 (D) |
| Instance-count ceiling on large worlds | **ARKHER Streaming Director** — chunked load sets with hysteresis, memory-budget capacity, per-frame work budget and pinning | Round 3 (C) |
| Roblox Terrain is a fixed voxel store | **ARKHER Terrain Framework** — engine-owned tiled heightfields, materials, thermal+hydraulic erosion, river tracing and LOD mesh building; the Roblox store is one output target | Round 3 (D) |
| No world simulation when unobserved | **ARKHER Living Simulation ("Modo Vida Real")** — full / reduced / statistical tiers with catch-up reconciliation, driven by D-O15 | Round 3 (C/M) |
| No engine-side procedural generation | **ARKHER Procedural Intelligence** — WFC constraint solving, L-system grammars, Poisson-disc scatter, A\* road networks and a deterministic 8-step world pipeline with checksums | Round 3 (M) |

| No shader authoring | **ARKHER Shade Graph** — 15-op node graph with cycle rejection, constant folding and compilation to Luau, feeding a layered material resolver | Round 4 (E) — *shipped* |
| No realtime GI | **ARKHER Probe GI** — SH9 irradiance volumes, trilinear interpolation, budgeted incremental relight | Round 4 (F) — *shipped* |
| No ray tracing | **ARKHER Light Transport Approximation** — probe GI + clustered lights + contact-scale fog and occlusion | Round 4 (F) — *shipped* |
| No DLSS/FSR/XeSS hooks | **ARKHER Reconstruction Framework** — resolution ladder with hysteresis, edge-aware reconstruction, temporal variance clipping, trained scale policy | Round 4 (G) — *shipped* |
| No fullscreen post chain | **ARKHER Image Maths** — exposure, ACES tonemap, height fog, contrast-adaptive sharpening as parameters | Round 4 (F) — *shipped* |
| Hard draw/instance ceiling | **ARKHER Geometry Virtualization** — spatial clusters, HLOD proxies, octahedral impostors, triangle+draw budget resolve | Round 4 (F) — *shipped* |

Each substitute is a *design of our own*, not an emulation of the original vendor technology.

---

## Round 5 additions — motion

| External capability | Why it cannot be used as-is | The ARKHER system that replaces it |
|---|---|---|
| PhysX / Havok / Jolt rigid-body engines | Native engines, not available inside the Roblox VM; Roblox's own solver is not addressable, steerable or deterministic from a script. | **ARKHER Physics Abstraction** (`src/physics/world.lua` + kits 56–60): its own fixed-step loop, spatial-hash broadphase, manifold generation, sequential-impulse solver with warm starting, joints and a determinism checksum. Roblox physics remains one possible *output* adapter, never the brain. |
| Unreal `CharacterMovementComponent` / Unity `CharacterController` | Engine-bound C++ components. | **ARKHER Character Motion** (`charmotor` kit + `src/physics/character_controller.lua`): capsule move-and-slide, slope limits, step-up, depenetration, coyote-time jump, platform riding, input buffering. |
| Unreal Chaos Vehicles / NVIDIA vehicle SDK | Native modules. | **ARKHER Vehicle Framework** (`vehicle` kit): raycast suspension, torque curve, gearbox with auto-shift, Ackermann steering, friction-circle tire model. |
| Unreal Animation Blueprint / Unity Mecanim | Editor-bound proprietary graph runtimes. | **ARKHER Animation Framework** (`skeleton`/`clip`/`animator`/`ik`/`ragdoll` kits + `src/animation/animation_system.lua`): layers, masks, crossfades, blend trees, events, IK and physical blending, all scriptable and headless-testable. |
| Ubisoft/EA-style motion matching (Motorica, Learned Motion Matching) | Proprietary datasets and runtimes; a learned model of that size cannot ship inside a Roblox place. | **ARKHER Motion Matching** (`src/animation/motion_matching.lua`): explicit feature vectors, weighted cost with continuity bonus, stride-sampled k-best search inside a hard budget, blend-in and hysteresis — the same idea, sized for a phone. |
| MetaHuman / Character Creator pipelines | Closed asset pipelines and licences. | **ARKHER Digital Human** (`src/character/digital_human.lua` + category J): rig definition, motion set, blend controller, look-and-reach, physical response, appearance composition, variants, per-crowd budget, streaming and recovery — 330 systems, all authored inside ARKHER. |
| NVIDIA Blast / destruction middleware | Native. | Preserved as **Singularity AI memory**: the intent (structured destruction with breakable constraints) is recorded, and the shipped substitute is the breakable-joint path in the `constraint` kit plus the ragdoll solver. Full destruction is scheduled, not claimed. |
