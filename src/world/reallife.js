// UTS :: world/reallife — "Real Life" system: real-world-inspired phenomena
// represented causally, not cosmetically.
//
// Rules (open set — examples, not limits):
//   rain  -> wetness rises            (causal event chain)
//   sun   -> dryness -> wind+dry -> dust
//   storm -> lightning -> fire ignition -> hazards -> NPC perception
//   time  -> day/night lighting
// Every derived event cites its real cause; chains are verifiable in RRW.

import { clamp01, lerp, normalize } from '../core/math.js';
import { RNG } from '../core/rng.js';

export const WEATHER_STATES = ['clear', 'cloudy', 'rain', 'storm', 'windy', 'dust'];

/** transition probabilities per state (open, data-driven) */
const TRANSITIONS = {
  clear:  { clear: 0.55, cloudy: 0.35, windy: 0.10 },
  cloudy: { clear: 0.30, cloudy: 0.30, rain: 0.35, windy: 0.05 },
  rain:   { rain: 0.55, cloudy: 0.25, storm: 0.20 },
  storm:  { storm: 0.45, rain: 0.45, cloudy: 0.10 },
  windy:  { windy: 0.40, clear: 0.30, cloudy: 0.20, dust: 0.10 },
  dust:   { dust: 0.35, clear: 0.40, windy: 0.25 },
};

export class RealLife {
  constructor({ world }) {
    this.world = world;
    this.strikeChance = 0.18;      // lightning per tick during storm
    this.igniteChance = 0.35;      // lightning starts a fire
    this.rainRate = 0.08;
    this.dryRate = 0.03;
  }

  /** explicit weather control (chained events, never silent mutation) */
  forceWeather(state) {
    const w = this.world;
    const env = w.environment;
    if (!WEATHER_STATES.includes(state)) throw new Error(`unknown weather: ${state}`);
    const cause = env.lastWeatherEventId ?? null;
    const id = w.rrw.emitEvent({
      type: 'reallife.weather.changed',
      subject: 'world',
      cause,
      data: { from: env.weather, to: state, forced: true },
      tick: w.clock.tick,
    });
    env.weather = state;
    env.lastWeatherEventId = id;
    applyWeatherTargets(env);
    return id;
  }

  strikeLightning(nearPos = null) {
    const w = this.world;
    const env = w.environment;
    const t = w.terrain;
    const pos = nearPos ?? [
      t.size * w.rng.next(), 0, t.size * w.rng.next(),
    ];
    const cause = env.lastWeatherEventId ?? null;
    const strikeId = w.rrw.emitEvent({
      type: 'reallife.lightning.strike',
      subject: 'world',
      cause,
      data: { pos },
      tick: w.clock.tick,
    });
    env.flash = 1;
    this.lastStrike = { pos: [...pos], tick: w.clock.tick }; // acoustic source (delay = d/343)
    if (w.rng.chance(this.igniteChance)) {
      this.igniteFire(pos, strikeId);
    }
    return strikeId;
  }

  /**
   * ADR-019 rewire: the COMBUSTION FIELD (fuel, moisture, wind) is the
   * reality that decides whether fire exists. The hazard entity is only the
   * PERCEPTION ANCHOR (grid index → lights → audio → NPC sight), fed by the
   * field — never a fire with a countdown inside it.
   */
  igniteFire(pos, causeEventId) {
    const w = this.world;
    const land = w.terrain.findLand(pos[0], pos[2], 30);
    const ev = w.combustion?.ignite(land[0], land[2], { causeEvent: causeEventId });
    if (!ev) {
      // honest refusal: the strike happened, the world said no (wet/no fuel)
      w.rrw.emitEvent({
        type: 'reallife.fire.refused',
        subject: 'ground',
        cause: causeEventId,
        data: { pos: [land[0], 0, land[2]], wetness: +w.environment.wetness.toFixed(2) },
        tick: w.clock.tick,
      });
      return null;
    }
    const cellKey = w.combustion._key(land[0], land[2]);
    const ent = w.rrw.createEntity({
      kind: 'hazard',
      materialization: 'full',
      importance: 1.0,
      tags: ['fire', 'hazard'],
      pos: [land[0], 0, land[2]],
      components: {
        hazard: { type: 'fire', intensity: 1.0, fuel: 45, cellKey, causeEvent: causeEventId },
      },
    });
    const evId = w.rrw.emitEvent({
      type: 'reallife.fire.started',
      subject: ent.id,
      cause: causeEventId,
      data: { pos: [land[0], 0, land[2]], cell: cellKey },
      tick: w.clock.tick,
    });
    w.rrw.patchComponent(ent.id, 'hazard', { startedEvent: evId });
    w.grid.update(ent.id, land[0], land[2]); // hazards enter the spatial index (perceivable reality)
    this.fireAnchors = this.fireAnchors ?? new Map(); // cellKey -> entity id
    this.fireAnchors.set(cellKey, ent.id);
    return ent.id;
  }

  update(dt) {
    const w = this.world;
    const env = w.environment;

    // ---- weather state machine (D-5) — transitions are real events
    if (w.rng.chance(0.02)) {
      const row = TRANSITIONS[env.weather] ?? TRANSITIONS.clear;
      const roll = w.rng.next();
      let acc = 0, next = env.weather;
      for (const [state, p] of Object.entries(row)) {
        acc += p;
        if (roll <= acc) { next = state; break; }
      }
      if (next !== env.weather) {
        const id = w.rrw.emitEvent({
          type: 'reallife.weather.changed',
          subject: 'world',
          cause: env.lastWeatherEventId ?? null,
          data: { from: env.weather, to: next },
          tick: w.clock.tick,
        });
        env.weather = next;
        env.lastWeatherEventId = id;
      }
    }
    applyWeatherTargets(env);

    // ---- physical effects
    env.rain = lerp(env.rain, env.targetRain, clamp01(dt * 0.5));
    env.wind = lerp(env.wind, env.targetWind, clamp01(dt * 0.3));
    // wetness is OWNED by hydrology.soil (the water table is a substance,
    // not a weather flag). dryness is DERIVED from it for dust generation.
    env.dryness = clamp01(1 - (this.world.hydrology?.soil.wetness ?? env.wetness));
    env.dust = clamp01(env.wind * env.dryness * (env.weather === 'dust' ? 1.6 : 0.4));
    env.flash = Math.max(0, env.flash - dt * 2);

    // ---- lightning during storm
    if (env.weather === 'storm' && w.rng.chance(this.strikeChance * dt)) {
      this.strikeLightning();
    }

    // ---- fire DYNAMICS live in combustion (world.updateWeather orders the
    // chain: reallife → atmosphere → hydrology → combustion → anchors)
    // ---- day/night lighting from the clock (D-3 + D-5)
    const sunEl = w.clock.sunElevation;
    const dayAmt = clamp01(sunEl * 1.6 + 0.2);
    env.sunDir = normalize([Math.cos(w.clock.timeOfDay * Math.PI * 2 - Math.PI / 2) * 0.6, Math.max(0.08, sunEl), 0.35]);
    env.ambient = lerp(0.16, 1.0, dayAmt) * lerp(1.0, 0.45, env.rain * 0.6 + (env.weather === 'storm' ? 0.4 : 0)) + env.flash * 0.8;
    // skyTop/skyBottom/fog/sunColor are computed by world.atmosphere.sky()
    // from AIR STATE (Rayleigh + Mie) — reallife no longer paints the sky.
  }

  /**
   * D-O15 anchor sync: the combustion FIELD is the source of truth; hazard
   * entities are materialized while (and only while) their cell burns.
   * Spread is NOT here — combustion.step owns dynamics (fuel+wind+moisture).
   */
  updateFires(dt) {
    const w = this.world;
    const comb = w.combustion;
    if (!comb) return;
    this.fireAnchors = this.fireAnchors ?? new Map();
    // 1) every burning cell gets a perceivable anchor (lights + audio + sight)
    for (const [k, c] of comb.cells) {
      if (!c.burning) continue;
      let id = this.fireAnchors.get(k);
      if (!id || !w.rrw.get(id)) {
        const [cx, cz] = k.split(',').map(Number);
        const pos = [cx * comb.cell + comb.cell / 2, 0, cz * comb.cell + comb.cell / 2];
        const startedEvId = w.rrw.emitEvent({
          type: 'reallife.fire.started', subject: null, cause: c.startedEvent ?? null,
          data: { pos, cell: k, via: 'spread' }, tick: w.clock.tick,
        });
        const ent = w.rrw.createEntity({
          kind: 'hazard', materialization: 'full', importance: 1.0,
          tags: ['fire', 'hazard'], pos,
          components: { hazard: { type: 'fire', intensity: c.intensity, fuel: c.fuel * 100, cellKey: k, causeEvent: c.startedEvent ?? null } },
        });
        w.rrw.patchComponent(ent.id, 'hazard', { startedEvent: startedEvId });
        w.grid.update(ent.id, pos[0], pos[2]);
        this.fireAnchors.set(k, ent.id);
      } else {
        const hz = w.rrw.getComponent(id, 'hazard');
        hz.intensity = c.intensity;      // the anchor MIRRORS the field (never invents)
        hz.fuel = c.fuel * 100;
      }
    }
    // FUMAÇA É SOLUÇÃO: cada fogo vivo injeta densidade+calor no solver 3D
    if (w.fluid3d) {
      for (const [k, c] of comb.cells) {
        if (!c.burning) continue;
        const [cx, cz] = k.split(',').map(Number);
        const gy = w.terrain.height(cx * comb.cell + comb.cell / 2, cz * comb.cell + comb.cell / 2) ?? 0;
        w.fluid3d.emit(cx * comb.cell + comb.cell / 2, gy + 2, cz * comb.cell + comb.cell / 2,
                       { amount: Math.min(0.5, 0.15 + c.intensity * 0.3), heat: 1 + c.intensity });
      }
    }
    // 2) anchors whose cell died are destroyed WITH the causal chain intact
    for (const [k, id] of [...this.fireAnchors]) {
      const c = comb.cells.get(k);
      if (c?.burning) continue;
      const hz = id ? w.rrw.getComponent(id, 'hazard') : null;
      if (hz) {
        w.rrw.emitEvent({
          type: 'reallife.fire.extinguished',
          subject: id,
          cause: hz.startedEvent ?? null,
          data: { pos: w.rrw.getComponent(id, 'spatial')?.pos ?? null, cell: k },
          tick: w.clock.tick,
        });
        w.grid.remove(id);
        w.rrw.destroy(id);
      }
      this.fireAnchors.delete(k);
    }
  }
  /** audio channel state for the Frame (D-11) — derived from represented state.
   *  ADR-019: one-shots are REAL acoustic sources (pos + power) — the
   *  ACOUSTICS phenomenon computes how they arrive at the listener. */
  audioState() {
    const w = this.world;
    const env = w.environment;
    const night = w.clock.isNight;
    let ambience = night ? 'crickets' : 'birds';
    if (env.weather === 'storm') ambience = 'storm';
    else if (env.rain > 0.2) ambience = 'rain';
    else if (env.dust > 0.3) ambience = 'wind';
    else if (env.wind > 0.5) ambience = 'wind';
    const oneShots = [];
    if (env.flash > 0.6 && this.lastStrike) {
      oneShots.push({ name: 'thunder', pos: this.lastStrike.pos, power: 1 });
    }
    // impacts are sound: recent physics impacts emit thuds with real energy
    for (const im of w.physics.recentImpacts ?? []) {
      if (w.clock.tick - im.tick > 1) continue; // only fresh ones (sound fades in ms)
      oneShots.push({ name: 'impact', pos: im.pos, power: Math.min(1, im.energy / 120), key: im.key });
    }
    w.tese?.touch('D-11', `ambience=${ambience} oneShots=${oneShots.length}`, w.clock.tick);
    return { ambience, oneShots };
  }
}

function applyWeatherTargets(env) {
  switch (env.weather) {
    case 'rain': env.targetRain = 0.8; env.targetWind = 0.35; break;
    case 'storm': env.targetRain = 1.0; env.targetWind = 0.9; break;
    case 'windy': env.targetRain = 0; env.targetWind = 0.85; break;
    case 'dust': env.targetRain = 0; env.targetWind = 0.7; break;
    case 'cloudy': env.targetRain = 0; env.targetWind = 0.3; break;
    default: env.targetRain = 0; env.targetWind = 0.2;
  }
}
