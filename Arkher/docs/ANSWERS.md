# Engineering answers: file counts, quality ceiling, and licensing

## 1. How many files should ARKHER and UTS have?

Short version: **files are a cost, systems and features are the value.**

What a file actually costs inside Roblox:

| Cost | Effect |
|---|---|
| Instance memory | every ModuleScript is an Instance: roughly 2–6 KB resident before its code runs |
| Load time | Studio insert, replication and `require` graph traversal all scale with file count |
| Replication | ModuleScripts under ReplicatedStorage replicate to every client, on mobile data |
| Require overhead | thousands of `require` calls cost real milliseconds at boot |

Measured on this build: **1,593 modules ≈ 5.7 MB of source**. Linear extrapolation:

| Modules | Source size | Realistic outcome on a mid phone |
|---:|---:|---|
| 1,593 (today) | 5.7 MB | boots fast, no issue |
| 10,000 | ~36 MB | fine with lazy loading per category |
| 15,000 | ~54 MB | upper comfort limit; needs streamed loading |
| 100,000 | ~360 MB | client memory blown, minutes of load, unusable |
| 1,000,000 | ~3.6 GB | physically impossible in a Roblox client |

**Recommendation (adopted in the roadmap):**

* **ARKHER (Roblox): 10,000–15,000 modules**, holding **≥10,000 systems and ≥100,000 features**,
  loaded lazily by category. That is the ceiling where quality still goes *up* with file count.
* **UTS (software / desktop side): 60,000–150,000 modules**, because there you can stream from disk
  and load on demand. 1B files is not "more quality", it is a filesystem that no tool can index —
  it would take *weeks* just to walk the tree, and every device would choke.
* Beyond those numbers, extra files reduce quality: more surface to keep consistent, slower builds,
  slower AI reasoning over the codebase, more dead code.

The 1B ambition is preserved as the **Granularity Doctrine** in
`SingularityAI/Memory/ARKHER_VISION_MEMORY.md` — maximum modularity within the limits where it
*increases* quality instead of destroying it.

## 2. What actually raises the quality ceiling?

Not file count. In order of impact:

1. **Budget discipline** (D-O15): a hard, measured frame budget per device tier.
2. **Perceptual optimization**: cut what the eye cannot see first (already implemented).
3. **Determinism**: identical results everywhere, so tuning transfers between devices.
4. **Self-verification**: every system tests itself, so 10,000 systems stay trustworthy.
5. **Consistency of light, material and motion** (see `HYPERREALISM.md`).

## 3. Open source or closed?

Recommended and applied in this repository: **open core, protected edge.**

| Layer | Licence stance | Why |
|---|---|---|
| Kernel, adapters, D-O15, catalog (this folder) | open source (repo licence) | adoption, auditability, contributions; nobody can build a competing platform from primitives alone |
| ARKHER Studio UI/UX, project format, asset pipeline | source-available | keeps the product identity |
| Singularity AI agent policies, tuned model prompts, trained assets | closed | this is the real moat and the commercial layer |

Fully closed source for an engine kills adoption; fully open with no protected layer kills the
business. Open core is what Unreal, Unity and Godot ecosystems have converged on in practice.
