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

## Round 6 additions — life

| External capability | Why it cannot be used as-is | The ARKHER system that replaces it |
|---|---|---|
| LLM-driven NPC dialogue (Inworld, Convai, NVIDIA ACE) | Requires a hosted model of billions of parameters and per-request network calls; impossible inside a Roblox place, and impossible offline. | **ARKHER Neural Mind Network** (`mindnet` kit + `src/npc/mind.lua`): a small recurrent policy net that is *actually trained at runtime* by the NPC's own wellbeing. It decides and learns; it does not converse in free text. The LLM-class ambition is preserved as **Singularity AI memory** (`VISION-029`), not claimed as shipped. |
| Unreal Mass Entity / Crowd AI, Unity DOTS crowds | Engine-bound native ECS runtimes. | **ARKHER Agent Runtime** (`src/npc/agent.lua` + `crowd`/`navgraph` kits): four LOD tiers with a per-frame thinking budget, spatial-hash neighbourhood steering, A\* with smoothing and flow fields — all in portable Lua, all headless-testable. |
| Recast/Detour navmesh generation | A native C++ library; navmesh voxelisation of a streamed world does not fit a Roblox script budget. | **ARKHER Navigation** (`navgraph` kit): cost grid with A\* + octile heuristic, Bresenham line-of-sight smoothing to reduce a 40-cell path to 3 waypoints, and Dijkstra flow fields when many agents share one destination. Grid, not mesh — chosen deliberately for mobile memory. |
| Utility-AI / GOAP middleware (Apex Utility AI, ReGoap) | Licensed engine plugins. | **ARKHER Reasoning kits** (`utility`, `planner`, `behaviortree`): response curves with momentum, cost-driven backward GOAP with a `simulate()` proof, and a full behaviour-tree runtime with cooldown/parallel decorators. |
| Dwarf-Fortress-class full-fidelity world history | Simulating every individual for a whole world costs orders of magnitude more than a phone frame allows. | **ARKHER Living World** (`src/sim/world_simulation.lua`): the same *outcome* through observer-driven fidelity — individuals only where someone can see them, cohorts nearby, pure rates everywhere else, with deterministic reification. The full-fidelity variant is preserved as **Singularity AI memory** (`VISION-031`). |
| Persistent cross-server world state (dedicated simulation servers) | Roblox gives no always-on authoritative world process; DataStore is not a simulation host. | **ARKHER World Persistence** (`checksum()` + codec/recovery aspects of category L): the world state is serialisable, diffable and checksummed so it *can* be persisted and resumed by whatever host exists. True cross-server continuous simulation is recorded as **Singularity AI memory** (`VISION-030`). |
| Full agent-based macro-economics (per-item ledgers for a whole nation) | The per-tick cost scales with population, not with what a player perceives. | **ARKHER Economy** (`economy` kit + `sim/civilization.lua`): market-level stock/production/demand with elastic price discovery and real money transfer on every trade — a real economy at cohort granularity. Per-individual ledgers are preserved as **Singularity AI memory** (`VISION-032`). |

## Round 7 additions — experience

| External capability | Why it cannot be used as-is | The ARKHER system that replaces it |
|---|---|---|
| Niagara / VFX Graph GPU particle systems | Compute shaders and GPU buffers are not reachable from a Roblox script; a million-particle simulation has nowhere to run. | **ARKHER VFX Framework** (`emitter`/`particles`/`forcefield`/`ribbon` kits + `src/vfx/effect_system.lua`): shaped emission with variance, pooled CPU integration with drag, restitution and life curves, analytic wind/radial/vortex/drag/curl-turbulence fields, camera-facing trails — all inside **one global particle budget** allocated by priority and four distance LOD bands. GPU compute particles are preserved as **Singularity AI memory** (`VISION-034`). |
| Wwise / FMOD authoring runtimes | Licensed native middleware; no plugin surface inside a Roblox place. | **ARKHER Audio Framework** (`dsp`/`mixer`/`spatialaudio`/`sequencer` kits + `src/audio/audio_engine.lua`): biquad filters and delay lines computed for real, a hierarchical bus tree with dB gain, mute/solo, attack-release ducking and priority voice stealing, distance/occlusion/doppler spatialisation, and adaptive music with stems, cues and bar-quantized transitions. |
| Convolution reverb and HRTF binaural rendering | Requires a per-sample audio callback and impulse-response convolution the platform does not expose. | Parametric substitute: filter-and-delay reverb per zone, low-pass occlusion and an equal-power panning law — the perceptual result at a fraction of the cost. Recorded as **Singularity AI memory** (`VISION-033`). |
| Unreal Gameplay Ability System / GAS-style attribute frameworks | Engine-bound C++ subsystem. | **ARKHER Gameplay Framework** (`stats`/`inventory`/`quest`/`combat` kits + `src/gameplay/gameplay_framework.lua`): ordered stat modifiers with timed expiry and derived caches, weight- and slot-bounded inventories with crafting, event-driven objectives with prerequisite chains, and a combat resolver with mitigation, resistances, criticals and statuses — wired so equipment changes damage and kills change quests. |
| Native UI toolkits (UMG, UIToolkit, SwiftUI/Compose) with system text shaping and UI shaders | Not exposed; the platform draws its own widgets and shapes its own text. | **ARKHER Interface Framework** (`flex`/`inputmap`/`tween` kits + `src/ui/ui_framework.lua`): a real layout solver with safe areas, weights and breakpoints, a retained widget tree with property bindings, one action bound simultaneously to touch, gamepad and keyboard, and accessibility audits (44 pt targets, WCAG AA contrast) that are API, not advice. Native shaping and UI shaders are preserved as **Singularity AI memory** (`VISION-036`). |
| Photon / Mirror / dedicated authoritative servers with rollback netcode | There is no dedicated deterministic host process; the platform owns the transport and the tick. | **ARKHER Networking Framework** (`replicator`/`netclock`/`prediction` kits + `src/net/replication.lua`): server-owned entity state, per-client interest sets, delta snapshots split under the MTU, clock synchronisation with median outlier rejection and an adaptive jitter buffer, client prediction with deterministic replay of unacknowledged inputs, token-bucket rate guarding and **lag compensation** that rewinds a recorded position history to validate a hit. World rollback netcode is preserved as **Singularity AI memory** (`VISION-035`). |
