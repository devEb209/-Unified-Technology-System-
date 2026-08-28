// UTS :: render/lighting — OUR lighting system.
// Light is DERIVED from the represented reality: the sun comes from the
// clock/atmosphere (RealLife), point lights come from RRW phenomena
// (fires), culled by distance and bounded by D-O15 quality.

import { dist2 } from '../core/math.js';

export class LightSystem {
  constructor() {
    this.maxPointLightsFull = 4;
    this.maxPointLightsReduced = 2;
  }

  /**
   * Collect lights for a Frame. Measurable + D-O15-aware:
   * pressure (strategy.particleDensity<1 or shadows off) reduces the
   * number of point lights; the sun always dominates.
   */
  collect(world, cameraPos, strategy = null) {
    const env = world.environment;
    const reduced = !strategy?.shadows || (strategy?.particleDensity ?? 1) < 1;
    const maxPoints = reduced ? this.maxPointLightsReduced : this.maxPointLightsFull;

    const sun = {
      dir: [...env.sunDir],
      color: [...env.sunColor],
      ambient: env.ambient,
      castShadow: strategy?.shadows ?? true,
    };

    // point lights from fire hazards (nearest, brightest first)
    const candidates = [];
    for (const id of world.rrw.query({ kind: 'hazard' })) {
      const hz = world.rrw.getComponent(id, 'hazard');
      const sp = world.rrw.getComponent(id, 'spatial');
      if (!hz || !sp || hz.type !== 'fire') continue;
      const d2 = dist2(sp.pos[0], sp.pos[2], cameraPos[0], cameraPos[2]);
      if (d2 > 160 * 160) continue; // contribution radius
      const flicker = 0.85 + 0.15 * Math.sin(world.clock.time * 23 + d2);
      candidates.push({
        kind: 'fire',
        pos: [sp.pos[0], (sp.pos[1] ?? 0) + 1.2 + hz.intensity, sp.pos[2]],
        color: [1.0 * hz.intensity * flicker, 0.55 * hz.intensity * flicker, 0.18 * hz.intensity],
        intensity: hz.intensity,
        radius: 26 * (0.6 + hz.intensity),
        sourceId: id,
        dist2: d2,
      });
    }
    candidates.sort((a, b) => a.dist2 - b.dist2);
    const points = candidates.slice(0, maxPoints).map(({ dist2: _d, ...l }) => l);

    return { sun, points, stats: { candidates: candidates.length, active: points.length, reduced } };
  }
}
