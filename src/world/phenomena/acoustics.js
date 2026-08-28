// UTS :: world/phenomena/acoustics — SOUND AS A PRESSURE WAVE, modeled.
//
//   reality question first: WHAT HAPPENS TO A SOUND BETWEEN HERE AND THERE?
//
// A sound is mechanical energy propagating through AIR. In reality it:
//   1. spreads geometrically (intensity falls with distance),
//   2. is ABSORBED by air — high frequencies first, more over distance,
//   3. is BLOCKED by terrain — a hill between you and the source casts an
//      acoustic shadow (what leaks around it is quiet and muffled),
//   4. travels at FINITE speed (~343 m/s) — thunder arrives AFTER the flash
//      by exactly d/343 seconds. No engine shortcut deletes this.
//
// This module computes that propagation from REPRESENTED state (terrain
// heightfield + atmosphere humidity). The audio layer consumes it as
// materialization parameters — D-O15 re-represents (far thunder = deep
// rumble), it never simply discards.

import { clamp01 } from '../../core/math.js';

export class Acoustics {
  constructor({ world, speedOfSound = 343, marchStep = 8, maxMarch = 26 } = {}) {
    this.world = world;
    this.speedOfSound = speedOfSound; // m/s — the REAL speed in air
    this.marchStep = marchStep;       // terrain shadow march resolution (m)
    this.maxMarch = maxMarch;         // march budget (D-O15 on the COST, never the phenomenon)
    this.stats = { propagated: 0, occluded: 0 };
  }

  /**
   * How does a sound from `source` arrive at `listener`?
   * power = emitted acoustic power (0..1+). Returns the arrival truth:
   *   { gain, muffle, delay, occlusion, dist, audible }
   *   gain     — loudness multiplier after spreading + shadowing
   *   muffle   — spectral tilt proxy >=1 (1 = pristine; higher = duller)
   *   delay    — seconds the wave needs (speed of sound is FINITE)
   *   occlusion— 0 clear .. 1 deep terrain shadow
   */
  propagate({ source, listener, power = 1, humidity = null } = {}) {
    const t = this.world.terrain;
    const dx = listener[0] - source[0], dy = (listener[1] ?? 0) - (source[1] ?? 0), dz = listener[2] - source[2];
    const dist = Math.hypot(dx, dy || 0, dz);

    // ---- 1) geometric spreading (energy ∝ 1/d² → amplitude ∝ 1/d, ref 8m)
    const spread = Math.min(1, 8 / (8 + Math.max(0, dist - 8) * 1.2));

    // ---- 2) terrain acoustic shadow: march the straight 2D path and find
    // how DEEP the line of sight dips below the ground (diffracted sound
    // loses both level and brightness — that leakage is what we model).
    const steps = Math.min(this.maxMarch, Math.max(2, Math.floor(dist / this.marchStep)));
    let maxDeficit = 0;
    for (let i = 1; i < steps; i++) {
      const f = i / steps;
      const x = source[0] + dx * f, z = source[2] + dz * f;
      const lineY = (source[1] ?? t.height(source[0], source[2])) * (1 - f) +
                    (listener[1] ?? t.height(listener[0], listener[2])) * f + 1.6; // ear height
      const ground = t.height(x, z);
      if (ground > lineY) maxDeficit = Math.max(maxDeficit, ground - lineY);
    }
    const occlusion = clamp01(maxDeficit / 10); // 10 m of blockage ≈ full shadow
    if (occlusion > 0.5) this.stats.occluded++;

    // ---- 3) air absorption: HF dies with distance; humid air absorbs MORE
    // (represented humidity — the atmosphere owns this state, we consume it)
    const hum = humidity ?? this.world.atmosphere?.state.humidity ?? 0.3;
    const airAbsorption = Math.exp(-dist * (0.0009 + 0.0014 * hum));
    const muffle = 1 + dist * (0.004 + 0.010 * hum) + occlusion * 3.2;

    const gain = power * spread * airAbsorption * (1 - 0.78 * occlusion);
    const delay = dist / this.speedOfSound; // thunder after the flash — REALITY
    this.stats.propagated++;
    return {
      gain, muffle, delay, occlusion, dist: +dist.toFixed(1),
      audible: gain > 0.02,
    };
  }

  snapshot() {
    return { stats: { ...this.stats } };
  }
  restore(s) {
    Object.assign(this.stats, s?.stats ?? {});
    return this;
  }
}
