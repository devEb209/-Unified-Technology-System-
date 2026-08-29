// UTS :: world/phenomena/climate — REGIONAL weather (escalas R3): the world
// is bigger than one sky. A grid of regions carries its own weather state,
// advected BY THE WIND (fronts move), with spatial variation of the SAME
// system (the global env stays the master chain — regions modulate it where
// space matters: fire sees the rain of ITS region, mist pools regionally).

export const CLIMATE_CONST = Object.freeze({
  REGION: 256,          // world units per region
  GRID: 6,              // regions per axis (centered on the world origin-ish)
  EVOLVE_EVERY: 0.5,    // seconds between region evolution ticks
  FACTOR_MIN: 0.6,      // regional rain/wind modulation floor (storms stay storms)
  FACTOR_MAX: 1.35,
  ADVECT: 0.02,         // how fast fronts drift with the wind (cells/sec·wind)
});

export class Climate {
  constructor({ world } = {}) {
    this.world = world;
    this.t = 0;
    // factor field: per-region multipliers of the GLOBAL weather system
    this.rainF = new Array(CLIMATE_CONST.GRID * CLIMATE_CONST.GRID).fill(1);
    this.fogF = new Array(CLIMATE_CONST.GRID * CLIMATE_CONST.GRID).fill(1);
    this.shift = 0; // advected offset (cells) — fronts move with the wind
  }

  idx(i, j) {
    const G = CLIMATE_CONST.GRID;
    return ((j % G) + G) % G * G + ((i % G) + G) % G;
  }

  regionOf(x, z) {
    const R = CLIMATE_CONST.REGION;
    return [Math.floor((x - this.shift * R) / R) + (CLIMATE_CONST.GRID >> 1),
            Math.floor(z / R) + (CLIMATE_CONST.GRID >> 1)];
  }

  /** evolve: smooth noise drifts; the WIND advects the whole field (fronts!) */
  step(dt, { wind = 0.2 } = {}) {
    this.t += dt;
    if (this.t < CLIMATE_CONST.EVOLVE_EVERY) return;
    const dtE = this.t; this.t = 0;
    this.shift += wind * dtE * CLIMATE_CONST.ADVECT * 0.1;
    // slow deterministic breathing of each region's factors
    const ph = this.world.clock.time * 0.13;
    for (let j = 0; j < CLIMATE_CONST.GRID; j++) {
      for (let i = 0; i < CLIMATE_CONST.GRID; i++) {
        const k = this.idx(i, j);
        const n = 0.5 + 0.5 * Math.sin(ph + i * 2.1 + j * 3.7) * Math.cos(ph * 0.7 + j * 1.3);
        this.rainF[k] = CLIMATE_CONST.FACTOR_MIN + (CLIMATE_CONST.FACTOR_MAX - CLIMATE_CONST.FACTOR_MIN) * n;
        this.fogF[k] = CLIMATE_CONST.FACTOR_MIN + (CLIMATE_CONST.FACTOR_MAX - CLIMATE_CONST.FACTOR_MIN) * (1 - n * 0.8);
      }
    }
  }

  rainAt(x, z, globalRain = 0) {
    const [i, j] = this.regionOf(x, z);
    return Math.min(1, globalRain * this.rainF[this.idx(i, j)]);
  }

  fogAt(x, z, globalFog = 0) {
    const [i, j] = this.regionOf(x, z);
    return Math.min(1, globalFog * this.fogF[this.idx(i, j)]);
  }
}
