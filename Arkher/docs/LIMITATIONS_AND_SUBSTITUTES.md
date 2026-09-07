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

Each substitute is a *design of our own*, not an emulation of the original vendor technology.
