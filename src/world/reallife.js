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
    if (w.rng.chance(this.igniteChance)) {
      this.igniteFire(pos, strikeId);
    }
    return strikeId;
  }

  igniteFire(pos, causeEventId) {
    const w = this.world;
    const land = w.terrain.findLand(pos[0], pos[2], 30);
    const ent = w.rrw.createEntity({
      kind: 'hazard',
      materialization: 'full',
      importance: 1.0,
      tags: ['fire', 'hazard'],
      pos: [land[0], 0, land[2]],
      components: {
        hazard: { type: 'fire', intensity: 1.0, fuel: 45 + w.rng.range(0, 30), causeEvent: causeEventId },
      },
    });
    const evId = w.rrw.emitEvent({
      type: 'reallife.fire.started',
      subject: ent.id,
      cause: causeEventId,
      data: { pos: [land[0], 0, land[2]] },
      tick: w.clock.tick,
    });
    w.rrw.patchComponent(ent.id, 'hazard', { startedEvent: evId });
    w.grid.update(ent.id, land[0], land[2]); // hazards enter the spatial index (perceivable reality)
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
    if (env.rain > 0.05) {
      env.wetness = clamp01(env.wetness + env.rain * this.rainRate * dt);
    } else {
      env.dryness = clamp01(env.dryness + this.dryRate * dt * (env.sunElevation > 0 ? 1.5 : 0.3));
      env.wetness = clamp01(env.wetness - this.dryRate * dt * (env.sunElevation > 0 ? 2 : 0.2));
    }
    env.dust = clamp01(env.wind * env.dryness * (env.weather === 'dust' ? 1.6 : 0.4));
    env.flash = Math.max(0, env.flash - dt * 2);

    // ---- lightning during storm
    if (env.weather === 'storm' && w.rng.chance(this.strikeChance * dt)) {
      this.strikeLightning();
    }

    // ---- fire dynamics (intensity, spread, extinguish)
    this.updateFires(dt);

    // ---- day/night lighting from the clock (D-3 + D-5)
    const sunEl = w.clock.sunElevation;
    const dayAmt = clamp01(sunEl * 1.6 + 0.2);
    env.sunDir = normalize([Math.cos(w.clock.timeOfDay * Math.PI * 2 - Math.PI / 2) * 0.6, Math.max(0.08, sunEl), 0.35]);
    env.ambient = lerp(0.16, 1.0, dayAmt) * lerp(1.0, 0.45, env.rain * 0.6 + (env.weather === 'storm' ? 0.4 : 0)) + env.flash * 0.8;
    env.sunColor = [
      lerp(1.0, 0.6, env.rain),
      lerp(0.95, 0.62, env.rain),
      lerp(0.8, 0.6, env.rain),
    ];
    env.skyTop = [0.25 * env.ambient, 0.45 * env.ambient, 0.9 * env.ambient];
    env.skyBottom = [
      lerp(0.75, 0.35, env.rain) * env.ambient,
      lerp(0.82, 0.37, env.rain) * env.ambient,
      lerp(0.9, 0.42, env.rain) * env.ambient,
    ];
    env.fog = clamp01(0.12 + env.rain * 0.35 + env.dust * 0.5);
  }

  updateFires(dt) {
    const w = this.world;
    const env = w.environment;
    for (const id of w.rrw.query({ kind: 'hazard', materialization: null })) {
      const hz = w.rrw.getComponent(id, 'hazard');
      if (!hz || hz.type !== 'fire') continue;
      hz.fuel -= dt;
      hz.intensity = clamp01(Math.min(1, hz.fuel / 30));
      const sp = w.rrw.getComponent(id, 'spatial');
      // rain extinguishes
      if (env.rain > 0.35) {
        hz.fuel -= dt * 8;
      }
      // spread to nearby trees
      if (hz.intensity > 0.4 && w.rng.chance(0.02 * dt)) {
        const near = w.grid.queryCircle(sp.pos[0], sp.pos[2], 12)
          .map(nid => ({ nid, kind: w.rrw.get(nid)?.kind }))
          .filter(x => x.kind === 'tree');
        if (near.length > 0 && w.rng.chance(0.5)) {
          const tree = w.rrw.get(w.rng.pick(near).nid);
          const tsp = w.rrw.getComponent(tree.id, 'spatial');
          const parentEv = w.rrw.getComponent(id, 'hazard').startedEvent;
          this.igniteFire([tsp.pos[0], 0, tsp.pos[2]], parentEv); // causal spread
        }
      }
      if (hz.fuel <= 0) {
        w.rrw.emitEvent({
          type: 'reallife.fire.extinguished',
          subject: id,
          cause: hz.startedEvent ?? null,
          data: { pos: sp.pos },
          tick: w.clock.tick,
        });
        w.grid.remove(id);
        w.rrw.destroy(id);
      }
    }
  }

  /** audio channel state for the Frame (D-11) — derived from represented state */
  audioState() {
    const env = this.world.environment;
    const night = this.world.clock.isNight;
    let ambience = night ? 'crickets' : 'birds';
    if (env.weather === 'storm') ambience = 'storm';
    else if (env.rain > 0.2) ambience = 'rain';
    else if (env.dust > 0.3) ambience = 'wind';
    else if (env.wind > 0.5) ambience = 'wind';
    const oneShots = [];
    if (env.flash > 0.6) oneShots.push({ name: 'thunder' });
    this.world.tese?.touch('D-11', `ambience=${ambience} oneShots=${oneShots.length}`, this.world.clock.tick);
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
