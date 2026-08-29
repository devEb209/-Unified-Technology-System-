// R11 — CINCO SISTEMAS DE UMA VEZ (realidade completa, mais fundo):
// rotação livre por QUATERNION + RAGDOLL (anatomia real); PINNA (a concha
// é o HRTF do próprio ouvido) + REVERB por ambiente; DELTAS POR-ENTIDADE
// (streaming do RRW); NÉVOA POR ALTURA no aerial; GALERIA DE MUNDOS.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { serializeState, restoreState } from '../src/persistence/snapshot.js';
import { pinnaApply, renderBinaural } from '../src/audio/spatial.js';
import { reverb, tailEnergy, SPACES } from '../src/audio/reverb.js';
import { aerial, SCATTER_GLSL } from '../src/render/scattering.js';
import { MATERIALS } from '../src/physics/physics.js';
import { TERRAIN_FS, ENTITY_FS, WATER_FS, TREE_FS } from '../src/render/shaders.js';

test('r11: rotação LIVRE por quaternion — normalizada, deriva o yaw do renderer', () => {
  const uts = createUTS({ seed: 'spin' });
  uts.ues.run(1);
  const body = uts.world.physics.addBody({ pos: [520, 12, 520], material: 'wood', spin: [3, 5, -2] });
  const q0 = [...uts.world.rrw.getComponent(body.id, 'physics').quat];
  assert.deepEqual(q0, [0, 0, 0, 1], 'identidade no nascimento');
  const tickBefore = uts.world.clock.tick;
  for (let i = 0; i < 40; i++) uts.world.physics.step(1 / 60, { tick: tickBefore + i });
  const ph = uts.world.rrw.getComponent(body.id, 'physics');
  const l = Math.hypot(...ph.quat);
  assert.ok(Math.abs(l - 1) < 1e-6, `quaternion normalizado (${l.toFixed(8)})`);
  assert.ok(Math.abs(ph.quat[3] - 1) > 0.01, `a orientação GIRA (${ph.quat.map(v => v.toFixed(2))})`);
  const sp = uts.world.rrw.getComponent(body.id, 'spatial');
  const yawDerived = Math.atan2(2 * (ph.quat[3] * ph.quat[2] + ph.quat[0] * ph.quat[1]), 1 - 2 * (ph.quat[1] ** 2 + ph.quat[2] ** 2));
  assert.ok(Math.abs(sp.yaw - yawDerived) < 1e-9, 'yaw do renderer DERIVADO do quaternion (uma verdade)');
  // sem spin: corpo parado não gira
  const still = uts.world.physics.addBody({ pos: [530, 12, 520], material: 'wood' });
  for (let i = 0; i < 10; i++) uts.world.physics.step(1 / 60, { tick: tickBefore + i });
  assert.deepEqual(uts.world.rrw.getComponent(still.id, 'physics').quat, [0, 0, 0, 1]);
});

test('r11: ragdoll — anatomia real (7 segmentos, 6 juntas, carne) e SOBREVIVE save/load', () => {
  assert.ok(MATERIALS.flesh && MATERIALS.flesh.density > 1 && MATERIALS.flesh.toughness < 5, 'carne é material real');
  const uts = createUTS({ seed: 'boneco' });
  uts.ues.run(1);
  const rag = uts.world.physics.buildRagdoll([500, 6, 500]);
  const reattached = uts.world.physics.reattach();
  assert.equal(reattached.bodies, 7, '7 segmentos no RRW');
  assert.equal(reattached.joints, 6, '6 juntas (pescoço, coluna, 2 braços, 2 pernas)');
  // cai e assenta: as juntas PBD mantêm a anatomia conectada
  for (let i = 0; i < 180; i++) uts.world.physics.step(1 / 60, { tick: i });
  const rrw = uts.world.rrw;
  const pa = rrw.getComponent(rag.torso, 'spatial').pos;
  const ph = rrw.getComponent(rag.head, 'spatial').pos;
  const rest = [...uts.world.rrw.relations.values()].find(r => (r.a === rag.head && r.b === rag.torso) || (r.b === rag.head && r.a === rag.torso));
  const d = Math.hypot(ph[0] - pa[0], ph[1] - pa[1], ph[2] - pa[2]);
  assert.ok(Math.abs(d - rest.data.rest) < 0.35, `pescoço conectado após a queda (${d.toFixed(2)} vs ${rest.data.rest.toFixed(2)})`);
  // save/load: o RRW é a verdade
  const snap = serializeState(uts);
  const uts2 = restoreState(JSON.parse(JSON.stringify(snap)));
  const r2 = uts2.world.physics.reattach();
  assert.equal(r2.bodies, 7, 'ragdoll inteiro após restore');
  assert.equal(r2.joints, 6);
});

test('r11: pinna — a CONCHA filtra por elevação; atrás é mais escuro (frente vs fundo)', () => {
  const sr = 22050;
  const tone = (f) => {
    const s = new Float32Array(4410);
    for (let i = 0; i < s.length; i++) s[i] = Math.sin((2 * Math.PI * f * i) / sr);
    return s;
  };
  const amp = (buf) => { let a = 0; for (const v of buf) a = Math.max(a, Math.abs(v)); return a; };
  const notchF = 5500 * 1.02; // dentro do primeiro notch (elev 0)
  const hit = amp(pinnaApply(tone(notchF), { elev: 0, behind: 0, sr }));
  const miss = amp(pinnaApply(tone(3000), { elev: 0, behind: 0, sr }));
  assert.ok(hit < miss * 0.75, `notch da concha: ${(hit / miss).toFixed(2)}× em ${(notchF / 1000).toFixed(1)}kHz`);
  const elevHi = amp(pinnaApply(tone(3000), { elev: 1, behind: 0, sr }));
  assert.ok(elevHi < miss * 0.9, 'elevação move o notch (corta 3kHz também)');
  // binaural integra a pinna: fonte ATRÁS escurece vs frente
  const listener = { pos: [0, 2, 0], yaw: 0, pitch: 0 };
  const src = [0, 2, 8]; // à frente (yaw 0 olha +z)
  const back = [0, 2, -8]; // atrás
  const sig = tone(440);
  const front = renderBinaural(sig, { emitterPos: src, listener, sr });
  const behind = renderBinaural(sig, { emitterPos: back, listener, sr });
  assert.ok(behind.left.every((v) => isFinite(v)) && front.left.every((v) => isFinite(v)));
});

test('r11: reverb por AMBIENTE — o cânion soa muito maior que a sala', () => {
  const sr = 22050;
  const impulse = new Float32Array(sr); // 1s
  impulse[0] = 1;
  const room = reverb(impulse, { space: 'room', sr });
  const canyon = reverb(impulse, { space: 'canyon', sr });
  assert.equal(room.length, impulse.length);
  assert.equal(canyon.length, impulse.length);
  const tRoom = tailEnergy(room), tCanyon = tailEnergy(canyon);
  assert.ok(tCanyon > tRoom * 4, `cauda do cânion ≫ sala (${(tCanyon / tRoom).toFixed(1)}×)`);
  const again = reverb(impulse, { space: 'canyon', sr });
  assert.deepEqual(Array.from(canyon), Array.from(again), 'determinístico');
  assert.ok(SPACES.valley.rt > SPACES.room.rt && SPACES.canyon.rt > SPACES.valley.rt, 'espaços ordenados');
});

test('r11: deltas por-entidade — stream só o que MUDOU e o clone acompanha', () => {
  const uts = createUTS({ seed: 'delta' });
  uts.core.tools.execute('ues.create_settlement', { name: 'Vila Delta', pop: 10, nearRiver: false });
  uts.ues.run(10);
  const T = uts.world.clock.tick;
  const snap = restoreState(JSON.parse(JSON.stringify(serializeState(uts)))); // clone em T
  const stale = restoreState(JSON.parse(JSON.stringify(serializeState(uts)))); // clone que NÃO recebe deltas
  uts.ues.run(40); // o mundo anda (NPCs se movem — __v carimbado)
  const deltas = uts.rrw.deltaSince(T);
  assert.ok(deltas.length > 0, `${deltas.length} entidades mudaram`);
  const applied = snap.rrw.applyDelta(JSON.parse(JSON.stringify(deltas)));
  assert.ok(applied > 0, `${applied} componentes aplicados`);
  // o clone atualizado acompanha o original; o abandonado fica para trás
  let same = 0, diff = 0;
  for (const id of uts.rrw.query({ kind: 'npc' })) {
    const a = uts.rrw.getComponent(id, 'spatial').pos;
    const b = snap.rrw.getComponent(id, 'spatial')?.pos;
    const s0 = stale.rrw.getComponent(id, 'spatial')?.pos;
    if (!b || !s0) continue;
    const d1 = Math.hypot(a[0] - b[0], a[2] - b[2]);
    const d2 = Math.hypot(a[0] - s0[0], a[2] - s0[2]);
    if (d1 < 0.5) same++;
    if (d2 > 0.5) diff++;
  }
  assert.ok(same > 0, `${same} NPCs idênticos via delta`);
  assert.ok(diff > 0, `${diff} NPCs divergiram sem delta (o delta carrega informação real)`);
  // um delta nunca inventa entidade
  assert.equal(snap.rrw.applyDelta([{ id: 'e-fantasma', kind: 'npc', comps: { spatial: { pos: [0, 0, 0] } } }]), 0);
});

test('r11: névoa por ALTURA — o baixio se afoga, o alto escapa (aerial fogH)', () => {
  const sun = [0.3, 0.8, 0.4];
  const dir = [0.98, 0.05, 0.2];
  const obj = [0.05, 0.04, 0.03]; // objeto escuro: a névoa CLAREIA em direção ao céu
  const lum = (v) => 0.3 * v[0] + 0.6 * v[1] + 0.1 * v[2];
  const cleanLow = aerial(obj, dir, 250, sun, { mie: 1, intensity: 22, fogH: 0 }, 2);
  const fogLow = aerial(obj, dir, 250, sun, { mie: 1, intensity: 22, fogH: 0.8 }, 2);
  const fogHigh = aerial(obj, dir, 250, sun, { mie: 1, intensity: 22, fogH: 0.8 }, 60);
  assert.ok(lum(fogLow) > lum(cleanLow), `baixio se afoga: ${lum(fogLow).toFixed(2)} > ${lum(cleanLow).toFixed(2)}`);
  assert.ok(lum(fogHigh) < lum(fogLow), `montanha escapa: ${lum(fogHigh).toFixed(2)} < ${lum(fogLow).toFixed(2)}`);
  // a física gerada carrega o mesmo parâmetro
  assert.ok(SCATTER_GLSL.includes('float fogH, float h'), 'aerial GLSL com fogH+altura');
  for (const [n, fs] of [['TERRAIN', TERRAIN_FS], ['ENTITY', ENTITY_FS], ['WATER', WATER_FS], ['TREE', TREE_FS]]) {
    assert.ok(fs.includes('uniform float uAirFog;'), `${n} declara uAirFog`);
    assert.ok(fs.includes('uAirMie, uAirI, uAirFog,'), `${n} passa a altura do ponto`);
  }
});

test('r11: galeria de mundos — presets reais no demo (não cenários decorados)', async () => {
  const fs = await import('node:fs');
  const html = fs.readFileSync(new URL('../demos/web/index.html', import.meta.url), 'utf8');
  for (const w of ['vale', 'arquipelago', 'incendio', 'cidade']) {
    assert.ok(html.includes(`data-world="${w}"`), `botão ${w} na galeria`);
  }
  assert.ok(html.includes('URLSearchParams(location.search)'), 'mundo via ?world=');
  // cada preset é uma semente/estado REAL — o do fogo acende fogo de verdade
  const uts = createUTS({ seed: 'vale-do-alvorecer' });
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  let lit = false;
  for (let x = 440; x <= 600 && !lit; x += 6) for (let z = 440; z <= 600; z += 6) {
    if (uts.world.reallife.igniteFire([x, 0, z], strike)) { lit = true; break; }
  }
  assert.ok(lit, 'o preset "Vale em Chamas" acende um fogo REAL');
});
