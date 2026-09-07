# Singularity AI — Vision Memory: ARKHER / UES

**Purpose of this file.** Everything in the ARKHER/UES program that is a *goal, claim, metaphor or
target* rather than an implemented, executable system is preserved here as **AI memory** instead of
being deleted or shipped as if it were code. Nothing is lost; it is reclassified.

Two shelves, never mixed:

* `IMPLEMENTED` — code that boots and passes its own tests (tracked in `Arkher/ARKHER_MANIFEST.json`).
* `VISION` — direction, ambition and numeric north stars (this file).

---

## VISION-001 — "1 billion physical files"
**Statement:** the UTS software should reach 1B+ physical files, ARKHER 1M+, "to surpass reality".
**Memory note:** interpreted as *maximum modular granularity*, not a literal file count.
Engineering reality: file count is a cost, not a quality metric. Roblox loads every ModuleScript
into memory; 1M ModuleScripts is a dead client on mobile. The vision is preserved as the
**Granularity Doctrine**: one responsibility per module, modules small enough to be individually
optimized, counted in *systems and features*, not files.
**Adopted target:** 10k–15k modules on the Roblox side, 60k–150k modules on the software/desktop
side (streamed, lazily loaded), 100k+ features. See `ANSWERS.md` for the full reasoning.

## VISION-002 — "Quality that surpasses reality"
**Statement:** ARKHER should exceed real life in fidelity.
**Memory note:** kept as the **Perceptual Superiority Doctrine** — not "more photons than reality",
but *more perceived fidelity per watt and per millisecond than any competing engine on the same
device*. Operationalized by D-O15: perceptual weighting, adaptive reconstruction, statistical
simulation of everything off-screen.

## VISION-003 — "Infinite content / infinite quality"
**Memory note:** stored as the **Unbounded Architecture Rule**: no artificial ceiling in any
registry, catalog, LOD chain or generation pipeline. Physically infinite output is not claimed.

## VISION-004 — Historical program claims (previous sessions)
Preserved verbatim as history, marked as *unverified legacy claims*, not engine features:
`138,080 files`, `27.6M physical`, `278.9B functional`, `100K/100M evolution ladders`,
`620 folders / 5,580 files RBXM`, `5K DIVINE OS`, `10K single-file packs`.
**Memory note:** these describe *ambition and past packaging experiments*. The ARKHER V1 counter is
independent and audited: every number in `ARKHER_MANIFEST.json` is reproduced by
`node tools/harness.js tests/engine_spec.lua`.

## VISION-005 — Roblox hyperrealism
**Statement:** reach hyperrealistic visuals inside Roblox.
**Memory note:** kept as an engineering program with concrete, reachable steps (see
`Arkher/docs/HYPERREALISM.md`): PBR discipline, probe-based GI, temporal reconstruction, geometry
virtualization + impostors, micro-detail materials, human motion quality, spatial audio, and
"reality cues" (wear, dirt, imperfection, atmospheric depth) which buy more realism per millisecond
than raw polygon count.

## VISION-006 — "Better games than any engine, in days, with AI + UES"
**Memory note:** stored as the **Time-to-World Objective**: measured as *hours from prompt to a
playable, optimized, verified world*. Round 8 (Singularity AI) turns this into an actual metric with
the agent pipeline; until then it is a target, not a feature.

## VISION-007 — Console & VR parity
**Memory note:** device tiers for console and VR already exist in `src/do15/device.lua` with real
budgets. Full input/runtime parity is scheduled with Round 7 (P/Q/R).

---

**Rule for future sessions:** if a requested capability cannot be implemented as running code in the
current round, it is written here as a VISION record with an interpretation and an adopted,
measurable target — and then scheduled into `Arkher/docs/ROADMAP.md`. Nothing is faked, nothing is
thrown away.

---

# ROUND 2 RECORDS (ARKHER Studio · Scripting · Collaboration)

## VISION-008 — A native ARKHER text-editor surface
**Memory note:** Roblox exposes no editable code surface to a plugin. ARKHER therefore ships the
entire *model* side as running code — a real Luau-subset tokenizer, symbol extraction, diagnostics
rules, completion, rename and metrics (`runtime/kits_studio` source kit + `code/intelligence`) — and
records the pixel-level editing surface as V2 adapter work. Status: **partially implemented**.

## VISION-009 — Peer-to-peer live collaboration
**Memory note:** the collaboration *logic* is real (presence, per-path locks, ordered op log,
operational-transform rebase, three-way merge, branches and commits). Roblox networking is
authoritative-server only, so a genuine P2P transport is recorded as a V2 networking adapter rather
than claimed today. Status: **partially implemented**.

## VISION-010 — Binary asset diff and merge
**Memory note:** structured-tree three-way merge ships in Round 2. Diffing meshes and textures needs
the content-addressed asset pipeline from category V (Round 8). Status: **scheduled**.

## VISION-011 — Distributed build farm
**Memory note:** the incremental, content-hashed task graph is shipping (`collab/build`), which is
the difficult half. Fanning those tasks out across machines is a platform capability for V2.
Status: **partially implemented**.

## VISION-012 — "ARKHER Studio is not a Roblox Studio plugin"
**Memory note:** restated as a standing architectural rule. ARKHER Studio is ARKHER's own IDE
(document · commands · selection · layout · widget · inspector · viewport). The shipped
`ARKHER_V1_STUDIO_PLUGIN.rbxmx` is only a *display adapter* that lets that IDE drive a Roblox Studio
session — every command it exposes is executed by ARKHER code. Status: **architectural rule**.

---

# ROUND 3 RECORDS (Scene/World · Terrain · Procedural)

## VISION-013 — GPU voxel meshing / compute-shader surface extraction
**Memory note:** Roblox exposes no compute API, so marching-cubes-class meshing cannot run on the
GPU. ARKHER ships the complete CPU surface extractor (`voxel` kit: 6-neighbour face extraction,
flood fill, material histograms) under a D-O15 mesh budget; the GPU path is recorded as a V2
platform capability. Status: **partially implemented**.

## VISION-014 — Planetary-scale unbounded terrain
**Memory note:** ARKHER terrain is tiled and unbounded *by construction* — tiles are created on
demand and streamed by the Streaming Director. A shipped Roblox place is still bounded by device
memory, so the planetary paging ledger is documented as intent while what ships is unbounded tiling
under a measured memory budget. Status: **partially implemented**.

## VISION-015 — Round-tripping into Roblox native smooth-terrain voxels
**Memory note:** the Terrain Framework owns heightfields, materials, erosion, rivers and LOD meshes
as engine data. Writing that data into Roblox's own `Terrain` voxel store (and reading it back) is
adapter work, kept strictly below the abstraction line, scheduled with the Round 4 adapter pass.
Status: **scheduled**.

## VISION-016 — Persistent cross-server world state ("Modo Vida Real" at platform scale)
**Memory note:** the `simulation` kit already keeps the world alive when unobserved through
full / reduced / statistical tiers, and its state is serialisable and reconcilable (`catchUp`).
Persisting that state across many Roblox servers needs the networking family (Round 7) and the
Reality Layer original technology (Round 8). Status: **partially implemented**.

## VISION-017 — Learned procedural style transfer
**Memory note:** Round-3 procedural generation is deterministic and grammar-based (WFC, L-systems,
rule synthesiser, Poisson-disc scatter, A\* networks) precisely so results are reproducible,
debuggable and identical on every device. A learned component that imitates a reference style is a
Singularity AI capability (Round 8, category T), not a procedural one. Status: **scheduled**.

---

# ROUND 4 RECORDS (Materials · Rendering · Neural Reconstruction)

## VISION-018 — Author-written GPU shaders
**Memory note:** the platform exposes no shader authoring. ARKHER ships everything above that
line as running code: a shading node graph with cycle rejection, constant folding and compilation
to Luau, plus a layered material resolver. The adapter maps resolved parameters onto the surface
types that do exist. Status: **partially implemented**.

## VISION-019 — Hardware ray tracing / path-traced GI
**Memory note:** no ray tracing API exists on the target platform. ARKHER substitutes irradiance
probe volumes encoded in 9-coefficient spherical harmonics, trilinearly interpolated, with
budgeted incremental relight — measurable, and cheap enough for a phone. Status: **substituted**.

## VISION-020 — Convolutional / transformer models on device
**Memory note:** the `inference` kit is dense-layer only, with real backpropagation and fixed-point
quantization, because that is what a mobile frame budget honestly allows. Larger architectures are
authoring-time tools that export quantized weights ARKHER loads at boot. Status: **partially
implemented**.

## VISION-021 — Framebuffer-level post processing
**Memory note:** ARKHER owns exposure, ACES tonemapping, height fog and contrast-adaptive
sharpening as parameter mathematics. A true fullscreen post chain needs a render target the
platform does not expose to user code. Status: **substituted**.

## VISION-022 — Variable rate shading and vendor upscaling hooks (DLSS/FSR/XeSS class)
**Memory note:** standing rule from the specification — never bolt on a vendor technology. ARKHER's
own Reconstruction Framework (resolution ladder with hysteresis, edge-aware reconstruction,
temporal accumulation with variance clipping, and a *trained* scale policy) is the substitute, and
it is fully implemented. Status: **substituted**.

---

# ROUND 5 RECORDS (Physics · Animation · Digital Humans)

## VISION-023 — Native rigid-body middleware (PhysX / Havok / Jolt class)
**Memory note:** the platform runs no native physics module a script can steer, and its own solver
is not addressable, deterministic or budgetable from user code. ARKHER therefore owns the whole
loop: fixed timestep, spatial-hash broadphase, analytic manifolds, sequential impulses with warm
starting, Baumgarte correction, joints and a position checksum that CI asserts twice per build.
The platform solver stays available as an *output* adapter for bodies ARKHER chooses to delegate.
Status: **substituted (fully implemented in ARKHER's own terms)**.

## VISION-024 — Continuous collision detection for bullet-speed objects
**Memory note:** ARKHER ships conservative sphere sweeps (Minkowski-expanded ray tests) which
solve the character and projectile cases at mobile cost. True per-shape conservative advancement
against rotating convex meshes is expensive and is scheduled with the mesh-collider work, not
claimed today. Status: **partially implemented**.

## VISION-025 — GPU cloth, soft bodies and destruction (Blast class)
**Memory note:** the cloth, soft-body and destruction *areas* exist in category H with real
budgeting, policy, analysis and recovery systems, and the `constraint` kit ships breakable joints
plus a distance-joint rope/ragdoll solver. Vertex-level cloth simulation and fracture meshing need
geometry the adapter cannot generate at runtime; they are recorded here and scheduled behind the
VFX and asset-pipeline families. Status: **partially implemented**.

## VISION-026 — Learned motion matching (neural pose search)
**Memory note:** ARKHER implements classical motion matching with explicit feature vectors, a
weighted cost function, stride-sampled k-best search inside a hard budget, switch hysteresis and
blend-in. Compressing that database into a learned network (Learned Motion Matching) is a
Singularity AI capability for Round 8 (category T), because the trainer belongs at authoring time.
The runtime hook — a pose provider behind one interface — already exists. Status: **scheduled**.

## VISION-027 — Skeletal skinning, morph targets and facial rigs at vertex level
**Memory note:** ARKHER owns the *rig*: bones, poses, blending, masks, IK, ragdoll and the
character tiering that decides how many bones a body deserves at a given distance. Deforming a
mesh per vertex, and blending morph targets, requires runtime mesh generation the platform does
not expose; the adapter maps ARKHER poses onto the rig types that do exist. Facial animation,
lip-sync, gaze and expression are shipped as *systems* (category J) that drive whatever the
adapter can move. Status: **partially implemented**.

## VISION-028 — Thousands of fully simulated characters at once
**Memory note:** the honest number on a phone is dozens of animated rigs, not thousands, so ARKHER
does not pretend otherwise: five appearance tiers, a nearest-first evaluation budget, quarter-rate
and frozen-pose bands, and a crowd tier that moves only the capsule and skips the rig entirely.
Larger populations are a *simulation* problem (category L, Round 6: statistical crowds promoted to
full agents only when observed), not an animation problem. Status: **substituted**.

## VISION-029 — LLM-class NPC dialogue and open-ended conversation
**Memory note:** ARKHER ships a Neural Mind Network that genuinely decides and genuinely learns —
a small recurrent policy whose reward is the NPC's own wellbeing delta. Free-form language is a
different machine: billions of parameters and a network round trip per line, which no Roblox place
can host. So dialogue ships as *behaviour and social consequence* (category K: dialogue behaviour,
gossip, reputation, disposition), and the language layer stays a Singularity AI service boundary
scheduled for Round 8 (category T). Status: **substituted**.

## VISION-030 — Persistent world state continuing across servers and sessions
**Memory note:** the world is serialisable, diffable and checksummed; the same seed replays the
same history, and a region advances by elapsed time when it is loaded (catch-up integration). What
the platform does not give ARKHER is an always-on authoritative process — DataStore is storage, not
a simulation host. Resumable state is shipped; continuous cross-server simulation is recorded here
and depends on a host that exists outside the place. Status: **partially implemented**.

## VISION-031 — Full-fidelity simulation of every individual in the whole world
**Memory note:** every person, everywhere, every tick is orders of magnitude beyond a mobile frame.
ARKHER's substitute is observer-driven fidelity: individuals where someone can perceive them,
cohorts nearby, aggregate rates beyond — with deterministic reification, so a re-materialised
villager arrives with a plausible history and memories instead of being born on the spot. What a
player can observe is identical; the cost scales with perception, not with world size.
Status: **substituted**.

## VISION-032 — Per-individual economic ledgers for an entire civilisation
**Memory note:** the shipped economy is real — goods, stock, production, demand, elastic price
discovery, and trades that move both goods and money — at market and settlement granularity, wired
into trade routes, taxation, laws, prosperity and migration. Tracking every coin of every person
scales with population rather than with observation, so it is preserved here and enabled only
inside the region the player currently occupies. Status: **substituted**.
