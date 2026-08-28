// UTS :: ues/frame — Visual extraction.
//
// REPRESENTATION ≠ RENDERIZATION. The Frame is a visual DESCRIPTION derived
// from the represented reality (RRW -> world state -> D-O15 -> materialization
// level -> Frame). The renderer never invents state; it only manifests it.

import { dist2 } from '../core/math.js';

const NPC_SHAPE = 'capsule';
const SHAPE_BY_KIND = {
  npc: NPC_SHAPE,
  hazard: 'sphere',
  tree: 'cone',
  bush: 'sphere',
  settlement: 'box',
};

const COLORS = {
  npc: [0.85, 0.65, 0.45],
  hazard: [1.0, 0.35, 0.08],
  tree: [0.16, 0.42, 0.2],
  bush: [0.35, 0.6, 0.25],
  settlement: [0.62, 0.55, 0.48],
  aggregate: [0.5, 0.52, 0.55],
};

/** choose terrain resolution for a chunk at distance d (LOD integrated with D-O15) */
function terrainRes(d, strategy) {
  const bias = (strategy?.terrainLodBias ?? 0) * 8;
  if (d < 70) return Math.max(8, 24 - bias);
  if (d < 150) return Math.max(8, 16 - bias);
  return 8;
}

export function extractFrame(ues, perf = null) {
  const world = ues.world;
  const rrw = world.rrw;
  const cam = ues.camera;
  const strategy = ues.do15?.strategy;
  const tk = perf?.start('frame.extract') ?? null;

  // ---- terrain patches near the camera (from the represented heightfield)
  const patches = [];
  const cs = world.terrain.chunkSize;
  const radius = strategy?.terrainRadius ?? 220;
  const c0x = Math.floor((cam.pos[0] - radius) / cs), c1x = Math.floor((cam.pos[0] + radius) / cs);
  const c0z = Math.floor((cam.pos[2] - radius) / cs), c1z = Math.floor((cam.pos[2] + radius) / cs);
  for (let cx = c0x; cx <= c1x && patches.length < 64; cx++) {
    for (let cz = c0z; cz <= c1z && patches.length < 64; cz++) {
      if (cx < 0 || cz < 0 || cx >= world.terrain.chunksPerSide || cz >= world.terrain.chunksPerSide) continue;
      const ccx = cx * cs + cs / 2, ccz = cz * cs + cs / 2;
      const d = Math.sqrt(dist2(ccx, ccz, cam.pos[0], cam.pos[2]));
      if (d > radius) continue;
      const res = terrainRes(d, strategy);
      const patch = world.getTerrainPatch(cx, cz, res);
      patches.push({
        id: `${cx}:${cz}`, x0: cx * cs, z0: cz * cs, size: cs,
        res, heights: patch.heights, biomes: patch.biomes, version: patch.version,
      });
    }
  }

  // ---- entities: only materialized ones become individual geometry
  const entities = [];
  const pushEntity = (id, e, lod) => {
    const sp = e.components.get('spatial');
    if (!sp) return;
    let scale = 1, color = COLORS[e.kind] ?? [0.7, 0.7, 0.7];
    if (e.kind === 'npc') scale = 1.7;
    if (e.kind === 'tree') scale = 5;
    if (e.kind === 'bush') scale = 0.8;
    if (e.kind === 'hazard') {
      const hz = e.components.get('hazard');
      scale = 1 + (hz?.intensity ?? 0.5) * (1 + Math.sin((world.clock.tick % 7) / 7 * Math.PI * 2) * 0.15);
    }
    if (e.kind === 'settlement') scale = 4;
    entities.push({
      id, kind: e.kind, pos: sp.pos, yaw: sp.yaw ?? 0,
      shape: SHAPE_BY_KIND[e.kind] ?? 'box', color, scale, lod,
      emissive: e.kind === 'hazard' ? 1 : 0,
    });
  };
  for (const id of rrw.query({ kind: 'npc', materialization: 'full' })) pushEntity(id, rrw.get(id), 2);
  for (const id of rrw.query({ kind: 'npc', materialization: 'partial' })) pushEntity(id, rrw.get(id), 1);
  for (const kind of ['hazard', 'tree', 'bush']) {
    for (const id of rrw.query({ kind, materialization: 'full' })) pushEntity(id, rrw.get(id), 2);
  }
  for (const id of rrw.query({ kind: 'settlement', materialization: 'partial' })) pushEntity(id, rrw.get(id), 2);

  // ---- aggregates: abstract settlements manifest as population blobs
  const aggregates = [];
  for (const id of rrw.query({ kind: 'settlement', materialization: 'abstract' })) {
    const s = rrw.getComponent(id, 'settlement');
    const sp = rrw.getComponent(id, 'spatial');
    if (!s || !sp) continue;
    const d = Math.sqrt(dist2(sp.pos[0], sp.pos[2], cam.pos[0], cam.pos[2]));
    if (d > radius * 2.5) continue;
    aggregates.push({ id, pos: sp.pos, radius: 6 + Math.min(20, Math.sqrt(s.pop)), density: s.pop, color: COLORS.aggregate });
  }

  const env = { ...world.environment };
  const frame = {
    version: 1,
    tick: world.clock.tick,
    time: world.clock.time,
    camera: { ...cam },
    terrain: { patches, seaLevel: world.terrain.seaLevel, chunkSize: cs },
    entities,
    aggregates,
    environment: env,
    audio: world.reallife.audioState(),
    stats: {
      patches: patches.length,
      entities: entities.length,
      aggregates: aggregates.length,
      npcsMaterialized: rrw.query({ kind: 'npc', materialization: 'full' }).length,
      npcsPartial: rrw.query({ kind: 'npc', materialization: 'partial' }).length,
      pressure: ues.do15?.pressure ?? 0,
      perceptionResolution: strategy?.perceptionResolution ?? 'full',
      particles: strategy?.particleDensity ?? 1,
    },
  };
  perf?.end(tk);
  ues.tese?.touch('D-11', `audio ambience=${frame.audio.ambience}`, frame.tick);
  return frame;
}
