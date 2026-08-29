// UTS :: ues/frame — Visual extraction (Gênesis).
// The Frame = visual description DERIVED from the represented reality:
// streamed terrain residency, resolved OUR materials, OUR lights (sun +
// fire point lights), aggregates, audio state, D-O15 quality. The renderer
// only manifests this; it invents nothing.

import { eyeState, VisionDynamics } from '../render/vision.js';
import { dist2 } from '../core/math.js';

const SHAPE_BY_KIND = {
  npc: 'capsule', hazard: 'sphere', tree: 'cone', bush: 'sphere',
  settlement: 'box', prop: 'sphere',
};

export function extractFrame(ues, perf = null) {
  const world = ues.world;
  const rrw = world.rrw;
  const cam = ues.camera;
  const strategy = ues.do15?.strategy;
  const tk = perf?.start('frame.extract') ?? null;

  // ---- terrain from OUR streaming residency (ready patches only)
  world.streaming.update(cam.pos, {
    radius: strategy?.terrainRadius ?? 220,
    budgetMs: (strategy?.perceptionResolution ?? 'full') === 'coarse' ? 1 : 2.5,
  });
  const patches = [];
  let meshPatches = 0, impostorPatches = 0, fades = 0;
  const cs = world.terrain.chunkSize;
  const radius = strategy?.terrainRadius ?? 220;
  const impostorAfter = strategy?.terrainImpostorAfter ?? 150; // D-O15: LOD quality tier
  const IMPOSTOR_FADE = 50; // cross-fade band (u): mesh dissolves into impostor
  const c0x = Math.floor((cam.pos[0] - radius) / cs), c1x = Math.floor((cam.pos[0] + radius) / cs);
  const c0z = Math.floor((cam.pos[2] - radius) / cs), c1z = Math.floor((cam.pos[2] + radius) / cs);
  for (let cx = c0x; cx <= c1x && patches.length < 64; cx++) {
    for (let cz = c0z; cz <= c1z && patches.length < 64; cz++) {
      if (cx < 0 || cz < 0 || cx >= world.terrain.chunksPerSide || cz >= world.terrain.chunksPerSide) continue;
      const ccx = cx * cs + cs / 2, ccz = cz * cs + cs / 2;
      if (Math.sqrt(dist2(ccx, ccz, cam.pos[0], cam.pos[2])) > radius) continue;
      const entry = world.streaming.getPatch(cx, cz, 24) ?? world.streaming.getPatch(cx, cz, 16) ?? world.streaming.getPatch(cx, cz, 8);
      if (!entry) continue; // not resident yet — the stream decides, we never fake
      const d = Math.sqrt(dist2(ccx, ccz, cam.pos[0], cam.pos[2]));
      // GÊNESIS-LOD: 3 tiers — mesh | fade (mesh + dissolving impostor) | impostor
      const lod = d > impostorAfter + IMPOSTOR_FADE ? 'impostor' : (d > impostorAfter ? 'fade' : 'mesh');
      if (lod === 'impostor') impostorPatches++; else if (lod === 'fade') fades++; else meshPatches++;
      patches.push({
        id: `${cx}:${cz}`, x0: cx * cs, z0: cz * cs, size: cs,
        res: entry.res, heights: entry.patch.heights, biomes: entry.patch.biomes,
        version: entry.version ?? 1, lod, dist: d,
      });
    }
  }

  // ---- entities: materialized ones become instanced geometry with OUR materials
  const entities = [];
  const pushEntity = (id, e, lod) => {
    const sp = e.components.get('spatial');
    if (!sp) return;
    let scale = 1;
    if (e.kind === 'npc') scale = 1.7;
    if (e.kind === 'tree') scale = 5;
    if (e.kind === 'bush') scale = 0.8;
    if (e.kind === 'settlement') scale = 4;
    if (e.kind === 'prop') scale = e.components.get('physics')?.radius * 2 ?? 1.2;
    const params = {};
    let fire = null;
    if (e.kind === 'hazard') {
      const hz = e.components.get('hazard');
      scale = 1 + (hz?.intensity ?? 0.5) * (1 + Math.sin(((world.clock.tick % 7) / 7) * Math.PI * 2) * 0.15);
      params.emissive = hz?.intensity ?? 0.5;
      // the renderer's fire PARTICLES mirror the combustion field (RRW truth)
      if (hz?.type === 'fire') fire = { intensity: hz.intensity ?? 0.5, fuel: hz.fuel ?? 20, cellKey: hz.cellKey ?? null };
    }
    const material = world.materials.resolve(e.kind, params);
    entities.push({
      id, kind: e.kind, pos: sp.pos, yaw: sp.yaw ?? 0,
      shape: SHAPE_BY_KIND[e.kind] ?? 'box', scale, lod, material,
      emissive: material.emissive, color: material.albedo, fire,
    });
  };
  for (const id of rrw.query({ kind: 'npc', materialization: 'full' })) pushEntity(id, rrw.get(id), 2);
  for (const id of rrw.query({ kind: 'npc', materialization: 'partial' })) pushEntity(id, rrw.get(id), 1);
  for (const kind of ['hazard', 'tree', 'bush', 'prop']) {
    for (const id of rrw.query({ kind, materialization: 'full' })) pushEntity(id, rrw.get(id), 2);
  }
  for (const id of rrw.query({ kind: 'settlement', materialization: 'partial' })) pushEntity(id, rrw.get(id), 2);

  // ---- aggregates: abstract settlements as population blobs
  const aggregates = [];
  for (const id of rrw.query({ kind: 'settlement', materialization: 'abstract' })) {
    const s = rrw.getComponent(id, 'settlement');
    const sp = rrw.getComponent(id, 'spatial');
    if (!s || !sp) continue;
    if (Math.sqrt(dist2(sp.pos[0], sp.pos[2], cam.pos[0], cam.pos[2])) > radius * 2.5) continue;
    const material = world.materials.resolve('aggregate');
    aggregates.push({ id, pos: sp.pos, radius: 6 + Math.min(20, Math.sqrt(s.pop)), density: s.pop, material, color: material.albedo });
  }

  // ---- REALITY CHAIN for the Frame: sources first, then HOW THEY ARRIVE
  const lights = world.lighting.collect(world, cam.pos, strategy);
  const audioState = world.reallife.audioState();
  // ACOUSTICS (pressure-wave reality): every sound source gets its arrival
  // truth at the listener — geometric spreading, air absorption (humidity!),
  // terrain acoustic shadow, and the FINITE speed of sound (delay).
  if (world.acoustics) {
    const ac = world.acoustics;
    const hum = world.atmosphere?.state.humidity;
    for (const l of lights.points ?? []) {
      if (l.kind !== 'fire') continue;
      l.acoustic = ac.propagate({ source: l.pos, listener: cam.pos, power: Math.max(0.35, l.intensity ?? 1), humidity: hum });
    }
    for (const shot of audioState.oneShots ?? []) {
      if (!shot.pos) continue;
      // emitted power: thunder is ENORMOUS (audible for km), a thud is local
      const emitted = shot.name === 'thunder' ? 25 : 6 * (shot.power ?? 1);
      shot.acoustic = ac.propagate({ source: shot.pos, listener: cam.pos, power: emitted, humidity: hum });
    }
  }

  const frame = {
    version: 2,
    tick: world.clock.tick,
    time: world.clock.time,
    camera: { ...cam },
    terrain: { patches, seaLevel: world.terrain.seaLevel, chunkSize: cs, impostorAfter, fade: IMPOSTOR_FADE },
    entities, aggregates,
    lights,
    audio: audioState,
    // vegetation is REALITY (ecology population), materialized under D-O15:
    // identity preserved, budget applied to COUNT only
    vegetation: world.ecology
      ? world.ecology.materialize(cam.pos, 160, Math.round((strategy?.particleDensity ?? 1) * 140))
      : null,
    // surface water around the camera (the film IS the data; renderers read it)
    water: world.hydrology ? world.hydrology.sample(cam.pos[0], cam.pos[2]) : null,
    // SCALE (R3): the world does not end at the render bubble.
    waterFilm: world.hydrology ? world.hydrology.filmNear(cam.pos, 220, 120) : null,
    terrainSeed: world.terrain?.seedNum ?? 0, // a água reflete ESTE mundo
    // burn scars are REAL persistent field state, materialized near the camera
    burntGround: world.combustion ? world.combustion.burntNear(cam.pos, 240, 90) : null,
    horizon: buildHorizon(world, cam, radius),
    environment: { ...world.environment },
    // the air's optical truth (scattering physics consumes THIS, not colors)
    air: world.atmosphere?.optics
      ? { ...world.atmosphere.optics(world.environment), fogH: world.atmosphere.state?.fog ?? 0 }
      : null,
    // cloud coverage FROM the represented air (the renderer only integrates)
    clouds: world.atmosphere?.cloudCoverage ? {
      coverage: world.atmosphere.cloudCoverage(world.environment),
      seedT: world.atmosphere.state?.cloudDrift ?? 0, // the wind advects the field
    } : null,
    // THE HUMAN EYE AS AN ORGAN: pupil mid-motion, saccadic masking,
    // afterimages and veil — state that PERSISTS between frames
    vision: (() => {
      const eye = (world._eye ??= new VisionDynamics());
      const dt = Math.max(1e-3, ((world.clock.tick ?? 0) - (world._eyeTick ?? world.clock.tick ?? 0)) * 0.05);
      world._eyeTick = world.clock.tick;
      return eye.update(dt, {
        ambient: world.environment.ambient ?? 1,
        flash: world.environment.flash ?? 0,
        exposure: world.observer?.exposure ?? 1,
        yaw: world.observer?.yaw ?? 0, pitch: world.observer?.pitch ?? 0,
      });
    })(),
    // the observer's eye gain — the saccade MASKS the gain (the eye blinks fast)
    exposure: (world.observer?.exposure ?? 1) * (1 - (world._eye?.suppress ?? 0)),
    // THE STYLE (D-O15 re-representation): params for the lens in the shaders
    style: world.style?.params ? { ...world.style.params } : null,
    // TRUE sun direction (unclamped — the sky must be able to set)
    sunDirTrue: (() => {
      const a = world.clock.timeOfDay * Math.PI * 2 - Math.PI / 2;
      const el = world.clock.sunElevation;
      const l = Math.hypot(Math.cos(a) * 0.6, el, 0.35) || 1;
      return [Math.cos(a) * 0.6 / l, el / l, 0.35 / l];
    })(),
    stats: {
      patches: patches.length,
      terrain: { meshes: meshPatches, impostors: impostorPatches, fades },
      entities: entities.length,
      aggregates: aggregates.length,
      npcsMaterialized: rrw.query({ kind: 'npc', materialization: 'full' }).length,
      npcsPartial: rrw.query({ kind: 'npc', materialization: 'partial' }).length,
      pressure: ues.do15?.pressure ?? 0,
      perceptionResolution: strategy?.perceptionResolution ?? 'full',
      particles: strategy?.particleDensity ?? 1,
      lights: frame_lights_stats(world),
      streaming: world.streaming.report(),
      physics: world.physics.report(),
      vegetation: world.ecology ? world.ecology.aliveCount() : 0,
      fireCells: world.combustion ? [...world.combustion.cells.values()].filter(c => c.burning).length : 0,
    },
  };
  perf?.end(tk);
  ues.tese?.touch('D-11', `audio ambience=${frame.audio.ambience}`, frame.tick);
  return frame;
}

function frame_lights_stats(world) {
  return world.lightingStatsCache ?? { candidates: 0, active: 0 };
}

/**
 * HORIZON (R3 — escala materializada): what is FAR is still REAL and still
 * shown — re-represented, never discarded (D-O15). Far fires become horizon
 * glow driven by the combustion field; far settlements become causal-state
 * markers sized by population. Identity (id) travels with every marker.
 */
function buildHorizon(world, cam, radius) {
  const out = [];
  const horizonRadius = 1400;
  // ---- far fire glow (beyond the light-contribution radius 160)
  if (world.combustion) {
    const fires = world.combustion.burningNear(cam.pos[0], cam.pos[2], 700);
    for (const f of fires) {
      if (f.dist <= 170) continue;
      out.push({
        kind: 'fire', id: `fire:${f.pos[0].toFixed(0)},${f.pos[2].toFixed(0)}`,
        pos: [f.pos[0], (world.terrain.height(f.pos[0], f.pos[2]) ?? 0) + 6, f.pos[2]],
        size: 26 + f.intensity * 40, alpha: 0.22 + f.intensity * 0.4,
        color: [1.0, 0.42, 0.1], intensity: f.intensity,
      });
    }
  }
  // ---- far settlements: causal state (pop/store) as a marker, never a texture
  const rrw = world.rrw;
  for (const id of rrw.query({ kind: 'settlement', materialization: 'abstract' })) {
    const sp = rrw.getComponent(id, 'spatial');
    const st = rrw.getComponent(id, 'settlement');
    if (!sp || !st) continue;
    const d = Math.hypot(sp.pos[0] - cam.pos[0], sp.pos[2] - cam.pos[2]);
    if (d <= radius * 2.5 || d > horizonRadius) continue; // near ones are aggregates
    const prom = Math.sqrt(st.pop ?? 10);
    out.push({
      kind: 'settlement', id,
      pos: [sp.pos[0], (world.terrain.height(sp.pos[0], sp.pos[2]) ?? 0) + 10, sp.pos[2]],
      size: 18 + prom * 2.2, alpha: Math.min(0.7, 0.18 + prom * 0.05),
      color: [0.92, 0.85, 0.66], pop: st.pop ?? 0,
    });
  }
  // ---- RADIATION FOG at dawn: humid valleys breathe mist; it BURNS OFF as
  // the sun climbs (atmosphere.state.fog is the causal amount)
  const fogAmt = world.atmosphere?.state?.fog ?? 0;
  if (fogAmt > 0.12) {
    const cell = 96, R = 3;
    const frac = (x) => x - Math.floor(x);
    const cx = Math.floor(cam.pos[0] / cell), cz = Math.floor(cam.pos[2] / cell);
    for (let i = -R; i <= R; i++) for (let j = -R; j <= R; j++) {
      const gx = cx + i, gz = cz + j;
      const hsh = frac(Math.sin(gx * 127.1 + gz * 311.7) * 43758.5453);
      if (hsh > 0.42) continue; // deterministic placement
      const x = (gx + 0.5) * cell + (hsh - 0.5) * 40;
      const z = (gz + 0.5) * cell + (frac(hsh * 7) - 0.5) * 40;
      const hy = world.terrain.height(x, z) ?? 0;
      if (hy > 9 || hy < world.terrain.seaLevel - 2) continue; // fog POOLS in lowlands
      const c = world.environment.skyBottom ?? [0.7, 0.8, 0.9];
      out.push({
        kind: 'fog', id: `fog:${gx}:${gz}`,
        pos: [x, hy + 4, z], size: 60 + hsh * 50,
        alpha: Math.min(0.5, fogAmt * 0.55),
        color: [Math.min(1, c[0] * 1.05 + 0.05), Math.min(1, c[1] * 1.05 + 0.05), Math.min(1, c[2] * 1.05 + 0.05)],
      });
    }
  }
  // D-O15 budget: brightest/most prominent first
  out.sort((a, b) => (b.intensity ?? 0) * 2 + ((b.pop ?? 10) ** 0.5) - ((a.intensity ?? 0) * 2 + ((a.pop ?? 10) ** 0.5)));
  return out.slice(0, 24);
}
