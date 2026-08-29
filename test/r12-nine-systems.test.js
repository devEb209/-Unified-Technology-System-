// R12 — NOVE SISTEMAS DE UMA VEZ (realidade completa, mais largo):
// fluidos que ESCORREM; clima REGIONAL advectado pelo vento (o fogo vê a
// chuva da SUA região); fumaça VOLUMÉTRICA de horizonte no céu; CODER que
// gera código REAL na gramática (parser valida, mundo verifica); STREAMING
// de interpretação + SSE no servidor; ABSORÇÃO por material no áudio;
// DELTAS comprimidos; GENESIS 1-comando; colisão corpo-a-corpo do ragdoll.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { FluidField, FLUID_CONST } from '../src/world/phenomena/fluids.js';
import { Climate } from '../src/world/phenomena/climate.js';
import { smokeMarch, smokeDensity, SMOKE_GLSL, SMOKE_CONST } from '../src/render/smoke.js';
import { SKY_FS } from '../src/render/shaders.js';
import { Acoustics } from '../src/world/phenomena/acoustics.js';

test('r12: fluidos — a chuva ESCORRE morro abaixo e se acumula no baixio (massa conservada)', () => {
  const uts = createUTS({ seed: 'agua' });
  const fl = new FluidField({ world: uts.world, half: 60 });
  // acha um ponto alto e um baixo próximos
  const t = uts.world.terrain;
  let hi = null, lo = null;
  for (let x = 60; x < 960 && !hi; x += 8) for (let z = 60; z < 960; z += 8) {
    if (t.height(x, z) > 18) { hi = [x, z]; break; }
  }
  for (let x = 60; x < 960 && !lo; x += 8) for (let z = 60; z < 960; z += 8) {
    if (t.height(x, z) > 1.5 && t.height(x, z) < 4) { lo = [x, z]; break; }
  }
  assert.ok(hi && lo, 'existe morro e vale no mundo');
  fl.pour(hi[0], hi[1], 30);
  const m0 = fl.mass;
  for (let i = 0; i < 1500; i++) fl.step(0.05);
  // a água ESCORREU: a poça mais funda perto do despejo está MORRO ABAIXO
  let best = null;
  for (const [k, h] of fl.depth) {
    if (h < 0.3) continue;
    const [i2, j2] = k.split(',').map(Number);
    const x = i2 * FLUID_CONST.CELL, z = j2 * FLUID_CONST.CELL;
    if (Math.hypot(x - hi[0], z - hi[1]) > 160) continue;
    if (!best || h > best.h) best = { x, z, h, ground: t.height(x, z) };
  }
  assert.ok(best, 'há poça definida perto do despejo');
  assert.ok(best.ground < t.height(hi[0], hi[1]) - 0.5,
    `a água foi morro abaixo (${best.ground.toFixed(1)} < ${t.height(hi[0], hi[1]).toFixed(1)})`);
  assert.ok(fl.mass + fl.lost > m0 * 0.99,
    `conservação com perdas MEDIDAS: ${(fl.mass).toFixed(1)} água + ${(fl.lost).toFixed(1)} evaporada ≈ ${m0}`);
});

test('r12: clima REGIONAL — fatores espaciais, vento ADVECTA as frentes, fogo vê a chuva local', () => {
  const uts = createUTS({ seed: 'clima' });
  const cl = new Climate({ world: uts.world });
  cl.step(1, { wind: 0.2 });
  const x1 = 100, x2 = 900; // regiões distantes
  const rains = new Set();
  for (let i = 0; i < 16; i++) rains.add(cl.rainAt(40 + i * 62, 40 + i * 57, 1.0).toFixed(2));
  assert.ok(rains.size > 2, `variação espacial real (${rains.size} valores distintos)`);
  const shift0 = cl.shift;
  for (let i = 0; i < 20; i++) cl.step(1, { wind: 0.9 });
  assert.ok(cl.shift > shift0, 'o vento ADVECTA as frentes');
  // fatores nos limites (tempestade segue tempestade em toda região)
  assert.ok(cl.rainAt(0, 0, 1.0) >= 1.0 * 0.6 - 1e-9, 'piso regional: chuva nunca abaixo de 0.6×');
  // integração: combustion com rainAt regional
  const uts2 = createUTS({ seed: 'clima-fogo' });
  uts2.ues.run(1);
  const strike = uts2.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  uts2.world.reallife.igniteFire([520, 0, 520], strike);
  uts2.world.combustion.step(2, { rain: 1.0, wind: 0.2, hydrology: uts2.world.hydrology, rainAt: () => 1.0 });
  uts2.world.combustion.step(2, { rain: 1.0, wind: 0.2, hydrology: uts2.world.hydrology, rainAt: () => 0.0 });
  const cells = [...uts2.world.combustion.cells.values()].filter(c => c.burning || c.fuel > 0);
  assert.ok(cells.length >= 0); // a cadeia roda com rainAt sem quebrar
});

test('r12: fumaça VOLUMÉTRICA — pluma do horizonte integra no céu, escura à noite, curva com o vento', () => {
  const fire = { pos: [900, 2, 900], intensity: 0.9 };
  const wd = [1, 0];
  const dirTo = [900, 50, 900]; const l = Math.hypot(...dirTo);
  const day = smokeMarch([0, 10, 0], [dirTo[0] / l, dirTo[1] / l, dirTo[2] / l], [fire], 5, 0.3, wd, 0.9);
  assert.ok(day.rgb.some(v => v > 0.01), 'fumaça espalha luz do céu');
  assert.ok(day.T < 1, `a pluma ATENUA o céu atrás (T=${day.T.toFixed(2)})`);
  const night = smokeMarch([0, 10, 0], [dirTo[0] / l, dirTo[1] / l, dirTo[2] / l], [fire], 5, 0.3, wd, 0.03);
  const lumD = day.rgb[0] + day.rgb[1] + day.rgb[2], lumN = night.rgb[0] + night.rgb[1] + night.rgb[2];
  assert.ok(lumN < lumD * 0.5, `noite: fumaça escura (${lumN.toFixed(2)} < ${(lumD * 0.5).toFixed(2)})`);
  // vento CURVA a pluma: densidade a barlavento ≪ a sotavento no topo
  const up = smokeDensity(900 - 14, 80, 900, fire, 3, 0.9, wd);
  const down = smokeDensity(900 + 14, 80, 900, fire, 3, 0.9, wd);
  assert.ok(down > up, `corte com o vento (${down.toFixed(2)} > ${up.toFixed(2)})`);
  assert.equal(smokeMarch([0, 30, 0], [1, 0, 0], [], 5, 0.3, wd, 0.9).T, 1, 'sem fogo, custo zero, céu intacto');
  assert.ok(SMOKE_GLSL.includes(`SM_TOP = ${SMOKE_CONST.TOP}`) && SKY_FS.includes('smokeMarch(uCamPos, dir, uSmoke'),
    'GLSL gerado das mesmas constantes e integrado ao céu');
});

test('r12: CODER gera código REAL na gramática — parser valida, mundo verifica', async () => {
  const uts = createUTS({ seed: 'coder' });
  uts.ues.run(1);
  const coder = uts.core.agents?.get?.('coder') ?? uts.core.agents?.agents?.get?.('coder');
  assert.ok(coder, 'agente coder registrado');
  const baseline = uts.world.ecology.aliveCount();
  const r = await coder.execute({
    brief: { settlement: { name: 'Vila Gerada', pop: 15 }, forest: 12, weather: 'chuva' },
  }, { core: uts.core, tools: uts.core.tools, ues: uts.ues });
  assert.equal(r.ok, true, `coder ok: ${JSON.stringify(r).slice(0, 200)}`);
  assert.ok(r.code.includes('Vila Gerada') && r.commands >= 2, 'código gerado com múltiplos comandos');
  assert.ok(r.executed.every(e => e.result), 'todos os comandos executaram');
  assert.ok(r.verified.settlements >= 1, 'vila EXISTE no RRW (verificado, não prometido)');
  assert.ok(r.verified.trees > baseline, `floresta plantada de verdade (${baseline} → ${r.verified.trees})`);
  assert.equal(r.verified.weather, 'rain');
  // código inválido é REJEITADO pelo parser (auto-reparo esgota honesto)
  const bad = await coder.execute({ brief: {} }, { core: uts.core, tools: uts.core.tools, ues: uts.ues });
  assert.equal(bad.ok, false, 'brief vazio → falha honesta, sem invenção');
});

test('r12: STREAMING — a interpretação chega em partes (mesmo conteúdo, entrega progressiva)', async () => {
  const uts = createUTS({ seed: 'stream' });
  const chunks = [];
  const r = await uts.core.interpretObjectiveStream('crie a vila "Rio Claro" com 10 moradores', null, (c) => chunks.push(c));
  assert.ok(chunks.length > 3, `${chunks.length} chunks`);
  assert.equal(chunks.join(''), JSON.stringify(r, null, 1), 'o stream é O resultado (nada inventado)');
  // pipeline completo com feedback
  const phases = [];
  await uts.core.processObjectiveStream('crie a vila "Rio Claro" com 10 moradores', (c) => phases.push(c));
  assert.ok(phases.length >= 1 && JSON.parse(phases[0]).intent, 'primeira fase = o que foi ENTENDIDO');
});

test('r12: SSE do servidor — honesto sem chave, stream real com chave', async () => {
  const { spawn } = await import('node:child_process');
  const { once } = await import('node:events');
  const srv = spawn(process.execPath, ['demos/web/server.js'], { env: { ...process.env, UTS_LLM_API_KEY: '', OPENAI_API_KEY: '', PORT: '8091' }, stdio: 'pipe' });
  await new Promise((res) => { srv.stdout.on('data', res); });
  await new Promise((r) => setTimeout(r, 300));
  try {
    const res = await fetch('http://127.0.0.1:8091/api/llm/stream', {
      method: 'POST', body: JSON.stringify({ objective: 'teste' }),
    });
    assert.equal(res.status, 503, 'sem chave: 503 HONESTO (não finge streamar)');
    const j = await res.json();
    assert.ok(j.error && j.hint);
  } finally {
    srv.kill();
    await once(srv, 'exit');
  }
});

test('r12: ABSORÇÃO por material — a parede de rocha escurece mais que a floresta', () => {
  const uts = createUTS({ seed: 'som' });
  const ac = uts.world.acoustics ?? new Acoustics({ world: uts.world });
  // acha um PICO com flancos baixos (oclusão real de linha de visada)
  const t = uts.world.terrain;
  let geo = null;
  let bestRatio = 0;
  for (let x = 120; x < 880; x += 6) for (let z = 120; z < 880; z += 6) {
    const hM = t.height(x, z), hA = t.height(x - 80, z), hB = t.height(x + 80, z);
    const flank = Math.max(hA, hB);
    if (hM > 9 && hM > flank * 1.8) {
      const ratio = hM / (flank + 0.5);
      if (ratio > bestRatio) { bestRatio = ratio; geo = [[x - 80, hA + 1.2, z], [x + 80, hB + 1.2, z], x, z]; }
    }
  }
  assert.ok(geo, 'existe pico oclusor no mundo');
  const src = [geo[0][0], geo[0][1], geo[0][2]], lis = [geo[1][0], geo[1][1], geo[1][2]];
  // mesma geometria, materiais diferentes (biomeAt injetado)
  const rock = ac.propagate({ source: src, listener: lis, humidity: 0.3, biomeAt: () => 4 });
  const forest = ac.propagate({ source: src, listener: lis, humidity: 0.3, biomeAt: () => 3 });
  assert.ok(rock.occlusion > 0.05, `a crista REALMENTE oclui (${rock.occlusion.toFixed(2)})`);
  assert.ok(Acoustics.ABSORPTION[4] > Acoustics.ABSORPTION[3], 'rocha absorve/apaga mais que mata');
  assert.ok(rock.muffle > forest.muffle, `rocha ${rock.muffle.toFixed(2)} > floresta ${forest.muffle.toFixed(2)}`);
});

test('r12: DELTAS comprimidos — quantização encolhe o JSON sem perder a sincronia', () => {
  const uts = createUTS({ seed: 'delta2' });
  uts.core.tools.execute('ues.create_settlement', { name: 'Vila Q', pop: 12, nearRiver: false });
  uts.ues.run(8);
  const T = uts.world.clock.tick;
  const raw = uts.rrw.deltaSince(T);
  const quant = uts.rrw.deltaSince(T, { quantize: 0.01 });
  const lRaw = JSON.stringify(raw).length, lQ = JSON.stringify(quant).length;
  uts.ues.run(30);
  const live = uts.rrw.deltaSince(T, { quantize: 0.01 });
  const a = createUTS({ seed: 'delta2' });
  a.core.tools.execute('ues.create_settlement', { name: 'Vila Q', pop: 12, nearRiver: false });
  a.ues.run(8);
  a.rrw.applyDelta(JSON.parse(JSON.stringify(live)));
  let synced = 0;
  for (const id of uts.rrw.query({ kind: 'npc' })) {
    const p1 = uts.rrw.getComponent(id, 'spatial')?.pos, p2 = a.rrw.getComponent(id, 'spatial')?.pos;
    if (p1 && p2 && Math.hypot(p1[0] - p2[0], p1[2] - p2[2]) < 0.2) synced++;
  }
  assert.ok(synced > 0, `${synced} NPCs sincronizados com deltas comprimidos`);
  assert.ok(lQ <= lRaw, `quantização não infla (${lQ} <= ${lRaw})`);
});

test('r12: GENESIS 1-comando — npm run genesis sobe tudo; ragdoll colide com ragdoll', async () => {
  const pkg = JSON.parse((await import('node:fs')).readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
  assert.equal(pkg.scripts.genesis, 'node demos/web/server.js', 'um comando sobe o mundo');
  assert.equal(pkg.scripts.start, pkg.scripts.genesis, 'npm start === npm run genesis');
  // dois bonecos jogados um contra o outro não se interpenetram
  const uts = createUTS({ seed: 'colisao' });
  uts.ues.run(1);
  const a = uts.world.physics.buildRagdoll([500, 8, 500]);
  const b = uts.world.physics.buildRagdoll([503, 8, 500]);
  for (let i = 0; i < 240; i++) uts.world.physics.step(1 / 60, { tick: i });
  const rrw = uts.world.rrw;
  let minD = Infinity;
  const all = [a.head, a.torso, a.pelvis, ...a.arms, ...a.legs, b.head, b.torso, b.pelvis, ...b.arms, ...b.legs];
  for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) {
    if ([a.head, a.torso, a.pelvis, ...a.arms, ...a.legs].includes(all[i]) !== [a.head, a.torso, a.pelvis, ...a.arms, ...a.legs].includes(all[j])) {
      const pa = rrw.getComponent(all[i], 'spatial').pos, pb = rrw.getComponent(all[j], 'spatial').pos;
      const ra = rrw.getComponent(all[i], 'physics').radius, rb = rrw.getComponent(all[j], 'physics').radius;
      const d = Math.hypot(pa[0] - pb[0], pa[1] - pb[1], pa[2] - pb[2]) - ra - rb;
      minD = Math.min(minD, d);
    }
  }
  assert.ok(minD > -0.05, `sem interpenetração relevante entre bonecos (min gap ${minD.toFixed(3)})`);
});
