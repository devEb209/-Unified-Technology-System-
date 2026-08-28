// UTS :: ues/frame — Visual extraction (Gênesis).
// The Frame = visual description DERIVED from the represented reality:
// streamed terrain residency, resolved OUR materials, OUR lights (sun +
// fire point lights), aggregates, audio state, D-O15 quality. The renderer
// only manifests this; it invents nothing.

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
    if (e.kind === 'hazard') {
      const hz = e.components.get('hazard');
      scale = 1 + (hz?.intensity ?? 0.5) * (1 + Math.sin(((world.clock.tick % 7) / 7) * Math.PI * 2) * 0.15);
      params.emissive = hz?.intensity ?? 0.5;
    }
    const material = world.materials.resolve(e.kind, params);
    entities.push({
      id, kind: e.kind, pos: sp.pos, yaw: sp.yaw ?? 0,
      shape: SHAPE_BY_KIND[e.kind] ?? 'box', scale, lod, material,
      emissive: material.emissive, color: material.albedo,
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

  const frame = {
    version: 2,
    tick: world.clock.tick,
    time: world.clock.time,
    camera: { ...cam },
    terrain: { patches, seaLevel: world.terrain.seaLevel, chunkSize: cs, impostorAfter, fade: IMPOSTOR_FADE },
    entities, aggregates,
    lights: world.lighting.collect(world, cam.pos, strategy),
    // vegetation is REALITY (ecology population), materialized under D-O15:
    // identity preserved, budget applied to COUNT only
    vegetation: world.ecology
      ? world.ecology.materialize(cam.pos, 160, Math.round((strategy?.particleDensity ?? 1) * 140))
      : null,
    // surface water around the camera (the film IS the data; renderers read it)
    water: world.hydrology ? world.hydrology.sample(cam.pos[0], cam.pos[2]) : null,
    environment: { ...world.environment },
    audio: world.reallife.audioState(),
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
