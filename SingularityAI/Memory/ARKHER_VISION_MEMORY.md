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
