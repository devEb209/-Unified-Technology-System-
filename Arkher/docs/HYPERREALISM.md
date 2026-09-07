# ARKHER Hyperrealism Program (Roblox)

How ARKHER reaches "impossible on Roblox" visuals — on a phone. Ordered by *realism gained per
millisecond*, which is the only ranking that matters when the budget is 16.6 ms.

## Tier 0 — the cheap wins that fool the eye (Round 4)
1. **Imperfection everywhere.** Nothing in reality is clean, straight or uniform. ARKHER Material
   Framework injects wear, dust, edge damage, colour drift and micro-variation per instance from a
   deterministic noise field. Cost: ~0. Realism: enormous.
2. **Atmospheric depth.** Correct fog density curves, aerial perspective and sun scattering give
   depth cues the brain reads as "real space".
3. **Colour discipline.** One filmic tonemap, one exposure model, one white balance. Most "Roblox
   look" is actually inconsistent exposure and over-saturation.
4. **Contact grounding.** Contact shadows / darkening where objects meet surfaces. Objects stop
   floating; the scene locks together.

## Tier 1 — light (Round 4)
5. **Probe-based GI (ARKHER Global Illumination Framework).** Irradiance probe volumes baked at
   build time, blended at runtime, projected into part colours and atmosphere parameters.
6. **Light hierarchy.** A tiny number of hero lights with shadows, everything else as unshadowed
   fill within the D-O15 light budget.
7. **Reflection strategy.** Probe cubemaps for the environment, planar approximations for water and
   floors, screen-space only on tiers that can pay for it.

## Tier 2 — geometry (Round 3–4)
8. **ARKHER Geometry Virtualization.** Chunked instancing, HLOD cascades and impostor synthesis:
   distant geometry becomes a handful of oriented billboards generated from the real mesh.
9. **Silhouette budgeting.** Detail spent on silhouettes and near-field surfaces, never on hidden
   interior volume.
10. **Micro-detail.** Detail textures, decals and normal-ish surface breakup near the camera only.

## Tier 3 — motion and life (Round 5–6)
11. **Motion quality beats model quality.** Foot IK, terrain adaptation, secondary motion, weight
    shift and gaze. A simple character that moves correctly reads as more real than a detailed one
    that slides.
12. **NMN behaviour.** NPCs with needs, routines, memory and social state — the world keeps living
    off-screen through statistical simulation (LOD band 5).
13. **Environmental reaction.** Vegetation, cloth, water and dust respond to wind, weather and
    contact.

## Tier 4 — reconstruction (Round 4, G)
14. **ARKHER Reconstruction Framework.** Render at a lower internal scale, redistribute detail
    temporally, and let the perceptual quality controller pick the scale per device. This is the
    single biggest FPS lever on mobile.
15. **Foveated / attention rendering.** Fidelity concentrated where the player is actually looking
    (screen centre, interaction targets, VR gaze).

## The rule
> Hyperrealism on Roblox is **not** a polygon problem. It is a *consistency* problem:
> consistent light, consistent materials, consistent motion, consistent imperfection.
> ARKHER enforces that consistency in code, and D-O15 pays for it by cutting only what the eye
> does not notice.
