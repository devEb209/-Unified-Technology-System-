// R7 — ADR-020: the sky is INTEGRATED physics, not painted.
// mock-gl does not execute GLSL — scattering is validated through the JS
// mirror + generation-consistency (the GLSL is GENERATED from the same
// constants, so equality of constants == same physics).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { skyColor, aerial, beamTransmittance, SCATTER_CONST, SCATTER_GLSL } from '../src/render/scattering.js';

const sat = (v) => (Math.max(...v) - Math.min(...v)) / (0.3 * v[0] + 0.6 * v[1] + 0.1 * v[2] + 1e-6);
const sunHigh = [0.3, 0.95, 0.35];
const noon = { mie: 1, intensity: SCATTER_CONST.INTENSITY };
const sunLow = [0.95, 0.06, 0.35];

test('r7: céu do meio-dia é azul porque o azul espalha mais (Rayleigh λ⁻⁴)', () => {
  const z = skyColor([0, 1, 0], sunHigh, noon);
  assert.ok(z[2] > z[0] * 1.3, `zênite deve dominar azul: ${z.map(v => v.toFixed(2))}`);
  const anti = skyColor([-0.3, 0.45, -0.35], sunHigh, noon);
  assert.ok(anti[2] > anti[0] * 1.4, `anti-solar azul: ${anti.map(v => v.toFixed(2))}`);
});

test('r7: o sol POENTE é vermelho porque o feixe cruza mais ar (transmitância)', () => {
  // o FEIXE DIRETO é o invariante físico (o pixel do disco inclui a aureola
  // de Mie espalhada perto do observador, que é pálida por natureza)
  const noonBeam = beamTransmittance(sunHigh, noon);
  const duskBeam = beamTransmittance([sunLow[0], 0.06, sunLow[2]], { mie: 1, intensity: 18 });
  const rNoon = noonBeam[2] / noonBeam[0], rDusk = duskBeam[2] / duskBeam[0];
  assert.ok(rDusk < rNoon / 100, `poente 100× mais vermelho no feixe: ${rDusk.toExponential(1)} vs ${rNoon.toFixed(2)}`);
  assert.ok(noonBeam[2] / noonBeam[0] < 0.9, 'até ao meio-dia o feixe perde mais azul (o céu é azul por isso)');
  const duskDisk = skyColor([sunLow[0], 0.06, sunLow[2]], [sunLow[0], 0.06, sunLow[2]], { mie: 1, intensity: 18 });
  assert.ok(duskDisk[0] > duskDisk[2], `pixel poente avermelhado: ${duskDisk.map(v => v.toFixed(2))}`);
});

test('r7: o disco solar tem pico direto Mie ≫ céu ao redor', () => {
  const disk = skyColor(sunHigh, sunHigh, noon);
  const off = skyColor([sunHigh[0] + 0.05, sunHigh[1] - 0.02, sunHigh[2]], sunHigh, noon);
  assert.ok(disk[1] > off[1] * 8, `disco deve dominar ${ (disk[1] / off[1]).toFixed(0) }x`);
});

test('r7: noite — ar quase não espalha sem sol', () => {
  const night = skyColor([0, 0.5, 0.9], [0.9, -0.3, 0.35], noon);
  assert.ok(night.every(v => v < 0.1), `noite escura: ${night.map(v => v.toFixed(3))}`);
});

test('r7: poeira (Mie↑) dessatura o céu — névoa branca, não azul', () => {
  const clean = skyColor([0, 1, 0], sunHigh, noon);
  const dusty = skyColor([0, 1, 0], sunHigh, { mie: 3, intensity: 20 });
  assert.ok(sat(dusty) < sat(clean), `poeira dessatura: ${sat(dusty).toFixed(3)} < ${sat(clean).toFixed(3)}`);
});

test('r7: perspectiva aérea devolve a cor no infinito ≈ cor do céu', () => {
  const inf = aerial([0.2, 0.6, 0.3], [0, 0.2, 1], 900, sunHigh, noon);
  const skyH = skyColor([0, 0.2, 1], sunHigh, noon, 8);
  for (let i = 0; i < 3; i++) assert.ok(Math.abs(inf[i] - skyH[i]) < 0.25, `infinito ≈ céu: ${inf.map(v => v.toFixed(2))} vs ${skyH.map(v => v.toFixed(2))}`);
  const near = aerial([0.2, 0.6, 0.3], [0, 0.2, 1], 0.001, sunHigh, noon);
  for (let i = 0; i < 3; i++) assert.ok(Math.abs(near[i] - 0.2 * (i === 0) - 0.6 * (i === 1) - 0.3 * (i === 2)) < 0.05, 'perto = objeto puro');
});

test('r7: consistência de geração — o GLSL é GERADO das MESMAS constantes', () => {
  const c = SCATTER_CONST;
  assert.ok(SCATTER_GLSL.includes('generated — do not hand-edit'), 'marcador de geração');
  const num = (x) => String(Number(x)); // fmt() adds ".0" — compare numerically
assert.ok(SCATTER_GLSL.includes(`vec3(${c.BETA_R.map(num).join(',')})`), 'BETA_R idêntico');
  assert.ok(SCATTER_GLSL.includes(`float BETA_M = ${num(c.BETA_M)}`), 'BETA_M idêntico');
  assert.ok(SCATTER_GLSL.includes(`float MIE_G = ${num(c.MIE_G)}`), 'MIE_G idêntico');
  assert.ok(SCATTER_GLSL.includes(`float HR = ${num(c.HR)}`), 'HR idêntico');
  assert.ok(SCATTER_GLSL.includes(`float HM = ${num(c.HM)}`), 'HM idêntico');
  assert.ok(SCATTER_GLSL.includes('vec3 skyColor(') && SCATTER_GLSL.includes('vec3 aerial(') && SCATTER_GLSL.includes('float phaseR(') && SCATTER_GLSL.includes('float phaseM('), 'funções físicas presentes');
});

test('r7: frame.air — a atmosfera é DONA da óptica que o renderer integra', () => {
  const uts = createUTS({ seed: 'r7-air' });
  uts.ues.run(2);
  const f = uts.ues.renderFrame();
  assert.ok(f.air && isFinite(f.air.mie) && f.air.mie >= 1, `mie físico: ${JSON.stringify(f.air)}`);
  assert.ok(f.air.intensity > 0, 'intensidade > 0');
  assert.ok(f.air.intensity <= 22 * 1.0 + 1e-9, 'nuvem/chuva nunca AUMENTAM a intensidade');
  assert.equal(f.air.mie, uts.world.atmosphere.optics(f.environment).mie, 'frame.air == atmosphere.optics (dono único)');
  const f2 = uts.ues.renderFrame();
  assert.deepEqual(f2.air, f.air, 'determinismo da óptica');
});

test('r7: SKY_FS integra a física por pixel (não pinta gradiente)', async () => {
  const { SKY_FS } = await import('../src/render/shaders.js');
  assert.ok(SKY_FS.includes('skyColor(dir, uSunDir'), 'céu = integral do espalhamento por raio de visão');
  assert.ok(SKY_FS.includes('uCamFwd'), 'raio construído da câmera real');
  assert.ok(!SKY_FS.includes('mix(uSkyBottom, uSkyTop'), 'gradiente pintado REMOVIDO');
  const { TERRAIN_FS, ENTITY_FS, WATER_FS } = await import('../src/render/shaders.js');
  for (const [n, fs] of [['TERRAIN', TERRAIN_FS], ['ENTITY', ENTITY_FS], ['WATER', WATER_FS]]) {
    assert.ok(fs.includes('aerial('), `${n} usa perspectiva aérea física`);
    assert.ok(!fs.includes('uFog*0.008'), `${n} sem fog cinza pintado`);
  }
});
