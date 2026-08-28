// UTS :: world/phenomena/atmosphere — THE ATMOSPHERE, modeled.
//
//   reality question first: WHAT IS AIR DOING HERE AND NOW?
//   → a thin gas column whose moisture, dust load and sunlight path
//     determine scattering → the sky IS this scattering, seen from inside.
//
// NOT a skybox: every color the renderer shows is COMPUTED from the air
// state that the simulation carries. Rayleigh (sky blue at day, orange at
// low sun because the light path through the air is LONGER) + Mie (haze
// halo from humidity+dust) + sun disk visibility. Deterministic; the Frame
// carries the state and the PRESENTATION just reads it.

import { clamp01, lerp } from '../../core/math.js';

/**
 * Realistic gase constants (visual-scale approximations, documented):
 *  - sun angular radius ~0.0047 rad; we use a cos^k hot core for the disk
 *  - Rayleigh: sky dominant blue ∝ 1/λ^4 → at low sun, longer path shifts
 *    the transmitted color toward red (the honest cause of sunsets)
 *  - Mie: haze ∝ humidity + dust, forward-scattered (bright halo near sun)
 */
const RAYLEIGH_DAY = [0.24, 0.46, 1.0];    // blue-dominant (λ^-4 weighting)
const RAYLEIGH_SUNSET = [1.15, 0.42, 0.14]; // red-dominant when the path is long
const NIGHT_AIR = [0.012, 0.02, 0.05];      // starless moonless air is NOT black

export class Atmosphere {
  constructor() {
    /** air state — the reality, carried in world.environment by reallife */
    this.state = {
      humidity: 0.35,   // 0..1 absolute-ish humidity
      dust: 0,          // 0..1 suspended particulate load
      pollution: 0,     // 0..1 (future: settlements emit)
    };
  }

  /** air responds to represented weather (evaporative humidity, dust load) */
  step(dt, env) {
    const targetH = clamp01(0.3 + env.rain * 0.7 - env.dust * 0.2);
    const targetD = clamp01(env.dust + (env.weather === 'storm' ? 0.15 : 0));
    const k = 1 - Math.exp(-dt / 6); // air has inertia (~6s to follow weather)
    this.state.humidity += (targetH - this.state.humidity) * k;
    this.state.dust += (targetD - this.state.dust) * k;
    return this.state;
  }

  /**
   * THE SKY AS A CONSEQUENCE.
   * @param sunEl sun elevation in [-1, 1] (from the clock)
   * @returns {skyTop, skyBottom, fog, extinction, sunColor, sunVisible}
   * — everything the Frame/renderer needs, derived from air + sun path.
   */
  sky({ sunEl, ambient }) {
    const { humidity, dust } = this.state;
    // optical path length: long at the horizon → Rayleigh shifts to red
    const path = clamp01(1 - Math.max(0, sunEl)); // 1 = horizon, 0 = zenith
    const day = clamp01(sunEl * 1.6 + 0.2);
    const rayleigh = [
      lerp(RAYLEIGH_DAY[0], RAYLEIGH_SUNSET[0], path * path),
      lerp(RAYLEIGH_DAY[1], RAYLEIGH_SUNSET[1], path * path),
      lerp(RAYLEIGH_DAY[2], RAYLEIGH_SUNSET[2], path * path),
    ];
    // Mie haze brightens toward the sun side and desaturates the horizon
    const haze = clamp01(0.08 + humidity * 0.35 + dust * 0.55 + this.state.pollution * 0.3);
    const top = [
      rayleigh[0] * ambient * (1 - haze * 0.35) + NIGHT_AIR[0] + haze * 0.04,
      rayleigh[1] * ambient * (1 - haze * 0.25) + NIGHT_AIR[1] + haze * 0.04,
      rayleigh[2] * ambient * (1 - haze * 0.15) + NIGHT_AIR[2] + haze * 0.05,
    ];
    const bottom = [
      (rayleigh[0] * 0.9 + haze * 0.55) * ambient * (1 - dust * 0.3) + NIGHT_AIR[0] + haze * 0.05,
      (rayleigh[1] * 0.92 + haze * 0.5) * ambient * (1 - dust * 0.45) + NIGHT_AIR[1] + haze * 0.05,
      (rayleigh[2] * 0.95 + haze * 0.42) * ambient * (1 - dust * 0.6) + NIGHT_AIR[2] + haze * 0.06,
    ];
    // extinction: how much the air REMOVES light along a view path (fog)
    const extinction = clamp01(0.05 + humidity * 0.25 + dust * 0.6 + (1 - day) * 0.1);
    // the disk: visible when the sun is up and the air is not opaque
    const sunVisible = clamp01(day * (1 - extinction * 0.75));
    const sunColor = [
      lerp(1.0, 1.0, path) * (0.75 + sunVisible * 0.25),
      lerp(0.92, 0.45, path * haze) ,
      lerp(0.78, 0.18, path),
    ];
    return {
      skyTop: top, skyBottom: bottom,
      fog: extinction,
      extinction,
      haze,
      sunVisible,
      sunColor,
    };
  }
}
