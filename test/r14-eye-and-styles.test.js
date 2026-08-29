// R14 — O OLHO HUMANO COMPLETO (pupila, acomodação, acuidade foveal,
// supressão sacádica, pós-imagem, véu óptico, CFF, aberração cromática)
// + O MOTOR DE ESTILO (o usuário FALA: anime, noir, ou o estilo dele —
// a física é UMA, a lente re-representa) + EROSÃO MULTI-ESCALA (a chuva
// escava o chão e sobe a escada até a geologia) + REVERB NO BUS do mixer.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import {
  VisionDynamics, pupilTarget, acuity, cocOf, cff, chromaticOffset, veilOf, VISION_CONST,
} from '../src/render/vision.js';
import { STYLES, STYLE_NAMES, styleParams, StyleEngine } from '../src/render/style.js';
import { Erosion } from '../src/world/erosion.js';
import { Mixer } from '../src/audio/mixer.js';
import { tailEnergy } from '../src/audio/reverb.js';
import { makeGL } from './helpers/mock-gl.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';
import * as SHADERS from '../src/render/shaders.js';

test('r14: A PUPILA — dilata lento no escuro, constrige rápido na luz (2–7mm)', () => {
  const eye = new VisionDynamics();
  const dark = eye.update(0.016, { ambient: 0.01, flash: 0, exposure: 1 });
  const bright = eye.update(0.016, { ambient: 100, flash: 0, exposure: 1 });
  assert.ok(dark.pupilMM > bright.pupilMM, `escuro ${dark.pupilMM.toFixed(2)}mm > luz ${bright.pupilMM.toFixed(2)}mm`);
  for (let i = 0; i < 60; i++) eye.update(0.05, { ambient: 100 }); // 3s de sol
  const day = eye.pupilMM;
  for (let i = 0; i < 60; i++) eye.update(0.05, { ambient: 0.015 });
  const night = eye.pupilMM;
  assert.ok(night > 5.5, `noite dilata: ${night.toFixed(2)}mm`);
  assert.ok(day < 3.2, `dia constrige: ${day.toFixed(2)}mm`);
  assert.ok(night <= VISION_CONST.PUPIL_MAX + 1e-6 && day >= VISION_CONST.PUPIL_MIN - 1e-6);
  // assimetria REAL: chegar à luz é mais rápido que chegar ao escuro
  const e2 = new VisionDynamics();
  e2.update(0.016, { ambient: 0.012 });
  let t = 0; while (e2.pupilMM > 3.0 && t < 20) { e2.update(0.05, { ambient: 400 }); t += 0.05; }
  const tConstrict = t;
  let t2 = 0; while (e2.pupilMM < 5.5 && t2 < 40) { e2.update(0.05, { ambient: 0.012 }); t2 += 0.05; }
  assert.ok(tConstrict < t2, `constricção ${tConstrict.toFixed(2)}s < dilatação ${t2.toFixed(2)}s`);
  assert.equal(pupilTarget(1000), VISION_CONST.PUPIL_MIN);
  assert.equal(pupilTarget(0.01), VISION_CONST.PUPIL_MAX);
});

test('r14: ACOMODAÇÃO — pupila aberta = foco raso (a óptica do olho é real)', () => {
  const wideOpen = cocOf(7, 10, 10);     // escuro, no foco
  const wideOff = cocOf(7, 30, 10);      // escuro, longe do foco
  const squintOff = cocOf(2, 30, 10);    // claro, longe do foco
  assert.ok(wideOpen < 0.01, `no foco é nítido (${wideOpen.toFixed(3)})`);
  assert.ok(wideOff > wideOpen * 5, `fora do foco borra (${wideOff.toFixed(3)})`);
  assert.ok(squintOff < wideOff, `pupila fechada corta o borramento (${squintOff.toFixed(3)} < ${wideOff.toFixed(3)})`);
});

test('r14: ACUIDADE FOVEAL — o olho amostra o CENTRO denso, a periferia é borrão sensível a movimento', () => {
  assert.equal(acuity(0), 1);
  assert.ok(acuity(5) > acuity(10), 'monótona decrescente');
  assert.ok(acuity(20) < 0.1, `a 20° sobra ${(acuity(20) * 100).toFixed(1)}% da acuidade`);
});

test('r14: SUPRESSÃO SACÁDICA — virar o olho rápido APAGA a visão por um instante', () => {
  const uts = createUTS({ seed: 'sacada' });
  uts.ues.run(1);
  const eye = uts.world._eye ?? null; // nasce no primeiro frame
  uts.ues.renderFrame();
  const eye2 = uts.world._eye;
  assert.ok(eye2, 'o olho vive no mundo (persiste entre frames)');
  const still = eye2.update(0.05, { ambient: 1, yaw: eye2.lastYaw, pitch: eye2.lastPitch });
  assert.equal(still.suppress, 0, 'parado = visão plena');
  const fast = eye2.update(0.016, { ambient: 1, yaw: eye2.lastYaw + 0.6, pitch: 0 }); // ~34°/frame = 2100°/s
  assert.ok(fast.suppress > 0.5, `sacada suprime (${fast.suppress.toFixed(2)})`);
  const f = uts.ues.renderFrame();
  assert.ok(f.vision.pupilMM >= 2 && f.vision.pupilMM <= 7, 'o frame carrega o órgão (pupila)');
  assert.ok(f.vision.cff && f.vision.cff.fovea > 20, 'o frame carrega CFF');
});

test('r14: PÓS-IMAGEM NEGATIVA — o flash queima o complemento que DECAI em segundos', () => {
  const eye = new VisionDynamics();
  const hit = eye.update(0.016, { ambient: 1, flash: 1, exposure: 1 });
  assert.ok(hit.after.every((v) => v < 0), `queimou negativo: [${hit.after.map((v) => v.toFixed(2))}]`);
  const later = eye.update(2.0, { ambient: 1, flash: 0 });
  const mag = (a) => Math.hypot(a[0], a[1], a[2]);
  assert.ok(mag(later.after) < mag(hit.after) * 0.25, `decai (${mag(hit.after).toFixed(2)} → ${mag(later.after).toFixed(2)})`);
  // determinística: mesma história = mesmo olho
  const clone = new VisionDynamics();
  clone.update(0.016, { ambient: 1, flash: 1 });
  const c2 = clone.update(2.0, { ambient: 1 });
  assert.deepEqual(c2.after.map((v) => +v.toFixed(9)), later.after.map((v) => +v.toFixed(9)));
});

test('r14: VÉU ÓPTICO + CFF + ABERRAÇÃO CROMÁTICA — a óptica do olho, medidas', () => {
  assert.ok(veilOf(2) > veilOf(0.1), 'dia levanta o preto mais que a noite');
  assert.ok(veilOf(0.01) < 0.001, 'escuro: o preto fica preto (véu é ∝ luz)');
  const day = cff(0), night = cff(1);
  assert.ok(day.fovea > night.fovea, `fusão cai no escuro (${day.fovea} > ${night.fovea}Hz)`);
  assert.ok(day.periphery > day.fovea, 'a periferia funde MAIS ALTO (é detector de movimento)');
  assert.ok(chromaticOffset(20) > chromaticOffset(2), 'aberração cresce com a excentricidade');
  assert.ok(chromaticOffset(10) < 0.005, '…mas minúscula (<0.5% do raio a 10°)');
});

test('r14: ESTILOS — presets prontos e o estilo do USUÁRIO criado na hora (sem limites)', () => {
  assert.ok(STYLE_NAMES.length >= 7, `presets: ${STYLE_NAMES.join(', ')}`);
  assert.deepEqual(STYLES.realista.tint, [1, 1, 1], 'realista é a identidade honesta');
  const anime = styleParams('anime');
  assert.equal(anime.params.bands, 4, 'anime = cel shading em bandas');
  assert.ok(anime.params.rim > 0.4, 'anime = rim light');
  // desconhecido sem parâmetros = erro honesto; COM parâmetros = o AI CRIA
  assert.throws(() => styleParams('estilo do sonho'), /desconhecido/);
  const mine = styleParams('estilo do sonho', { sat: 1.3, contrast: 0.9, tint: [1.05, 0.95, 1.1] });
  assert.match(mine.name, /criado/);
  assert.equal(mine.params.sat, 1.3);
  assert.throws(() => styleParams('x', { sat: 'muito' }), /não numérico/, 'parâmetro inválido = erro honesto');
});

test('r14: ESTILO NÃO MEXE NA FÍSICA — mesma luz, olho IGUAL, lente diferente (a lei da casa)', async () => {
  const plain = createUTS({ seed: 'lente' });
  plain.ues.run(2);
  plain.ues.renderFrame(); plain.ues.renderFrame(); plain.ues.renderFrame();
  const uts = createUTS({ seed: 'lente' });
  uts.ues.run(2);
  const engine = new StyleEngine(uts.world);
  engine.apply('anime');
  uts.ues.renderFrame(); uts.ues.renderFrame();
  const f = uts.ues.renderFrame();
  assert.equal(f.style.bands, 4, 'o frame leva a lente ao shader');
  // MESMA história de luz → MESMO olho (o estilo não toca na física)
  assert.equal(
    plain.world._eye.pupilMM.toFixed(12), uts.world._eye.pupilMM.toFixed(12),
    'o OLHO vê o mesmo mundo (pupila idêntica)');
  assert.equal(
    plain.world._eye.L.toFixed(12), uts.world._eye.L.toFixed(12),
    'a LUZ resolvida é idêntica');
  // e o chat manda: a tool world.style integra o engine
  const r = await uts.core.tools.execute('world.style', { style: 'cyberpunk' });
  assert.equal(r.style.params.tint[2] > 1.1, true, 'cyberpunk pinta de azul');
  assert.equal(uts.ues.renderFrame().style.tint[2] > 1.1, true, '…e chega ao frame');
});

test('r14: O OLHO LÊ O ESTILO — eye.readout mostra o que a retina captura', async () => {
  const uts = createUTS({ seed: 'readout' });
  const no = await uts.core.tools.execute('eye.readout', {});
  assert.equal(no.ok, false, 'honesto: sem frame ainda, o olho não viu nada');
  uts.ues.run(1);
  uts.ues.renderFrame();
  const yes = await uts.core.tools.execute('eye.readout', {});
  assert.equal(yes.ok, true);
  assert.ok(yes.pupilMM >= 2 && yes.pupilMM <= 7);
  assert.ok(yes.veil >= 0);
});

test('r14: A LENTE CHEGA AO GPU — uniforms de estilo/véu/pós-imagem nos 5 shaders e no draw', () => {
  const src = Object.values(SHADERS).join('\n');
  for (const u of ['uStyleSat', 'uStyleCon', 'uStyleBands', 'uStyleTint', 'uVeil', 'uAfter']) {
    const n = (src.match(new RegExp(`uniform.*${u}`, 'g')) ?? []).length;
    assert.ok(n >= 5, `${u} declarado ${n}× (5 FS)`);
  }
  const rimCount = (src.match(/RIM cel/g) ?? []).length;
  assert.equal(rimCount, 2, 'rim (assinatura cel) na entidade e na vegetação');
  // o renderer ALIMENTA (identidade quando não há estilo — nada muda sem chat)
  const gl = makeGL();
  const uts = createUTS({ seed: 'gpu' });
  uts.ues.run(1);
  const r = new WebGL2Renderer(gl);
  r.init();
  r.render(uts.ues.renderFrame());
  const sat = gl._calls.filter((c) => c[0] === 'uniform1f' && c[1] === 'uStyleSat');
  assert.ok(sat.length >= 4, `uStyleSat enviado ${sat.length}× (os FS desenhados neste frame)`);
  assert.ok(sat.every((c) => c[2] === 1), 'sem estilo = identidade (sat 1)');
  const veil = gl._calls.filter((c) => c[0] === 'uniform1f' && c[1] === 'uVeil');
  assert.ok(veil.length >= 4 && veil.every((c) => c[2] >= 0), `véu enviado: n=${veil.length}`);
});

test('r14: EROSÃO MULTI-ESCALA — a chuva escava, conserva massa e SOBE A ESCADA até a geologia', () => {
  const uts = createUTS({ seed: 'chuva' });
  uts.world.environment.rain = 0.8;
  const ero = uts.world.erosion;
  assert.ok(ero instanceof Erosion, 'o mundo NASCE com a erosão');
  const pristine = createUTS({ seed: 'chuva' });
  uts.ues.run(60); // 3s de chuva forte
  // sondar uma célula que a chuva REALMENTE mordeu (delta ≠ 0)
  const entry = [...uts.world.terrain.deltas.entries()].find(([, v]) => Math.abs(v) > 1e-4);
  assert.ok(entry, 'existem deltas de erosão no terreno');
  const [kx, kz] = entry[0].split(',').map(Number);
  const probeX = kx * 3, probeZ = kz * 3;
  const before = pristine.world.terrain.height(probeX, probeZ);
  assert.ok(ero.stats.eroded > 0, `chão mordido: ${ero.stats.eroded.toFixed(4)}m`);
  // CONSERVAÇÃO: o que saiu virou depósito + sedimento em trânsito
  assert.ok(Math.abs(ero.stats.eroded - (ero.stats.deposited + ero.stats.inMotion)) < 1e-9,
    `erodido ${ero.stats.eroded.toFixed(6)} == depositado ${ero.stats.deposited.toFixed(6)} + em trânsito ${ero.stats.inMotion.toFixed(6)}`);
  // o terreno mudou de verdade (height lê os deltas)
  const after = uts.world.terrain.height(probeX, probeZ);
  assert.ok(Math.abs(after - before) > 1e-6, `o MUNDO é esculpido (${before.toFixed(4)} → ${after.toFixed(4)})`);
  // determinismo: mesma semente, mesma chuva, mesma erosão
  const twin = createUTS({ seed: 'chuva' });
  twin.world.environment.rain = 0.8;
  twin.ues.run(60);
  assert.equal(twin.world.erosion.stats.eroded.toFixed(9), ero.stats.eroded.toFixed(9), 'determinística');
  // a escada: acumular movimento dispara o registro geológico no nível PLANETA
  ero.accum = ero.geologyEvery + 1;
  const ticks = uts.world.clock.tick;
  ero.step(0.05);
  assert.ok(ero.events.length > 0, 'evento geológico registrado');
  assert.ok(ero.events.at(-1).up && ero.events.at(-1).up.n >= 1, 'a escada entregou ao nível de cima (planeta)');
  // save/load carrega a erosão (fenômenos são estado do RRW)
  const snap = uts.world.phenomenaSnapshot();
  const fresh = createUTS({ seed: 'outra' });
  fresh.world.phenomenaRestore?.(snap);
  assert.equal(fresh.world.erosion.stats.eroded, ero.stats.eroded, 'o histórico geológico sobrevive');
});

test('r14: O BUS DO MIXER MORA NUM LUGAR — cânion tem cauda LONGA, sala curta (dívida R11 paga)', () => {
  const dry = new Mixer({ sr: 8000 });
  dry.add(new Float32Array([1, 0, 0, 0]), { gain: 1 });
  const outDry = dry.render(0.5);
  const room = new Mixer({ sr: 8000 }).setSpace('room');
  room.add(new Float32Array([1, 0, 0, 0]), { gain: 1 });
  const outRoom = room.render(0.5);
  const canyon = new Mixer({ sr: 8000 }).setSpace('canyon');
  canyon.add(new Float32Array([1, 0, 0, 0]), { gain: 1 });
  const outCanyon = canyon.render(0.5);
  const tail = (o) => tailEnergy(o.left, 320);
  assert.ok(tail(outRoom) > tail(outDry), 'a sala ecoa mais que o seco');
  assert.ok(tail(outCanyon) > tail(outRoom) * 1.3, `cânion ${tail(outCanyon).toFixed(4)} ≫ sala ${tail(outRoom).toFixed(4)}`);
  assert.throws(() => new Mixer({}).setSpace('galeria'), /desconhecido/, 'espaço inventado = erro honesto');
});

test('r14: /api/style no servidor — o chat aplica e o inventado responde honesto (HTTP real)', async () => {
  const { spawn } = await import('node:child_process');
  const srv = spawn(process.execPath, ['demos/web/server.js'], {
    env: { ...process.env, PORT: '8097', UTS_WORKSPACE: '/tmp/ws-r14' }, stdio: 'pipe',
  });
  await new Promise((res) => { srv.stdout.once('data', res); setTimeout(res, 2000); });
  const api = (path, body) => fetch(`http://127.0.0.1:8097${path}`, body ? { method: 'POST', body: JSON.stringify(body) } : {});
  let up = null;
  for (let i = 0; i < 12 && !up; i++) {
    try { up = await api('/api/style'); } catch { await new Promise((r) => setTimeout(r, 150)); }
  }
  assert.ok(up, 'servidor subiu');
  try {
    const anime = await (await api('/api/style', { style: 'anime' })).json();
    assert.equal(anime.name, 'anime');
    assert.equal(anime.params.bands, 4);
    const custom = await (await api('/api/style', { style: 'sonho azul', params: { sat: 1.4, tint: [0.9, 0.95, 1.25] } })).json();
    assert.match(custom.name, /criado/);
    const bad = await api('/api/style', { style: 'nada' });
    assert.equal(bad.status, 400, 'estilo inexistente sem params = 400 honesto');
    const cur = await (await api('/api/style')).json();
    assert.match(cur.name, /criado/, 'GET devolve o estado');
  } finally {
    srv.kill();
  }
});

test('r14: FRONTEND — os botões de estilo têm handler (a auditoria automática cobre)', async () => {
  const { readFile } = await import('node:fs/promises');
  const html = await readFile(new URL('../demos/web/index.html', import.meta.url), 'utf8');
  for (const n of ['realista', 'anime', 'noir', 'pastel', 'cyberpunk', 'carvao', 'apply']) {
    assert.ok(html.includes(`id="style-${n}"`), `botão style-${n} existe`);
    assert.ok(new RegExp(`\\$\\('style-${n}'\\)`).test(html), `style-${n} tem handler`);
  }
  assert.ok(html.includes('styleParams'), 'o demo importa o MESMO engine (uma verdade)');
});
