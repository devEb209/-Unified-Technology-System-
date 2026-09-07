# ARKHER V1 roadmap — 10–20% complete per round, nothing partial

The formal target from the ARKHER specification: **≥10,000 systems, ≥100,000 features**, growing.
Each round finishes whole categories: generated, booted, self-tested, packaged and verified.

| Round | Categories delivered | Systems | Features (approx) | % of the 10k floor | Cumulative |
|---|---|---:|---:|---:|---:|
| **1 — Kernel** ✅ | A UES/Core (520), S D-O15 (620), X Security (410) | **1,550** | **23,612** | 15.5% | **15.5%** |
| **2 — Studio & Code** ✅ | B Editor/IDE (700), U Scripting (600), Y Collaboration (400) | **1,700** | **27,900** | 17% | **32.5%** |
| **3 — World** ✅ | C Scene/World (644), D Terrain (640), M Procedural (616) | **1,900** | **31,564** | 19% | **51.5%** |
| **4 — Image** ✅ | E Materials (600), F Rendering (700), G Neural (504) | **1,804** | **29,726** | 18% | **69.5%** |
| **5 — Motion** ✅ | H Physics (700), I Animation (520), J Characters (330) | **1,550** | **25,670** | 15.5% | **85.0%** |
| **6 — Life** ✅ | K NMN/NPC (700), L World simulation (600) | **1,300** | **22,850** | 13% | **98.0%** |
| 7 — Experience | N VFX, O Audio, P Gameplay, Q UI, R Networking | ~2,100 | ~32,000 | 21% | ~119% |
| 8 — Intelligence | T Singularity AI, V Assets, W Cinematic, Z ARKHER original tech | ~2,600 | ~40,000 | 26% | **≥145%** |

Every round ships:

1. generated + hand-written systems for the whole category,
2. self-tests for every system (`engine:verify()` must be 100%),
3. an updated `.rbxmx` model and `.rbxlx` place, byte-validated,
4. updated manifest (`ARKHER_MANIFEST.json`) and docs,
5. a delta report of exactly what changed.

Generations after V1 (`ARKHER V2 Continuum`, `V3 Ascension`) are declared in
`src/kernel/version.lua` with a working migration chain, so projects built on V1 migrate forward.
