// R25 — LUZ E SOM MEDIDOS PELA FÍSICA: A BASE EXATA DA ORELHA (a solução
// em série de Rayleigh da esfera rígida no MESMO schema do banco medido —
// baffel +6dB, ILD crescente, ITD = 3a/c de Rayleigh), A FORJA DE LUZ
// (loco Planckiano nas âncoras CIE, fotometria candela/lux com 1/r² exato,
// gamut honesto), A FUMAÇA EMPURRA MALHAS COMPOSTAS (força por parte +
// torque, contato segura o corpo apoiado) e O LANÇAMENTO ASSINADO
// (build ed25519 com selo verificável — o artefato leva identidade).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { SPHERE_TABLE, SPHERE_R_M, SOUND_C, sphereGain, selfTests as sphereTests } from '../src/audio/sphere-hrtf.js';
import { applyHRTF, pickBilinear } from '../src/audio/hrtf.js';
import { forgeLight, forgeRig, selfTests as lightTests } from '../src/agent/light-smith.js';
import { build, verifySelo, newSigningKey } from '../src/agent/build-system.js';

const dB = (g) => 20 * Math.log10(Math.max(1e-9, g));

// ----------------------------------------------- a base exata da orelha
test('r25: A ORELHA EXATA — série de Rayleigh devolve a física medida e anda no schema do banco medido', () => {
  const provas = sphereTests();
  assert.equal(provas.length, 6, 'seis provas da solução exata');
  for (const p of provas) assert.ok(p.ok, `física da orelha: ${p.name} — ${p.detail}`);

  // a tabela passou pelo MESMO portão do banco medido (loadMeasuredTable)
  assert.equal(SPHERE_TABLE.azimuths.length, 13);
  assert.equal(SPHERE_TABLE.elevations.length, 6);
  assert.equal(SPHERE_TABLE.taps, 48);
  for (const az of SPHERE_TABLE.azimuths) {
    for (const el of SPHERE_TABLE.elevations) {
      const cell = SPHERE_TABLE.data[az][el];
      assert.ok(Array.isArray(cell.L) && Array.isArray(cell.R));
      for (const v of cell.L) assert.ok(Number.isFinite(v));
    }
  }

  // ganho de baffel: a orelha iluminada recebe ~+6dB em alta frequência
  const g8k = sphereGain(0, 8000);
  assert.ok(g8k > 1.7 && g8k < 2.2, `baffel +6dB: ${g8k.toFixed(3)}`);

  // ILD cresce com a frequência (a sombra exata da esfera)
  const ild = (f) => sphereGain(0, f) / sphereGain(Math.PI, f);
  assert.ok(ild(11000) > ild(2000), `ILD(11k)=${dB(ild(11000)).toFixed(1)}dB > ILD(2k)=${dB(ild(2000)).toFixed(1)}dB`);

  // a interpoladora binlinear e a orelha COMPLETA funcionam na base exata
  const meio = pickBilinear(SPHERE_TABLE, 37.5, 10);
  assert.ok(meio.L.every(Number.isFinite) && meio.R.every(Number.isFinite));
  const ouvido = applyHRTF(new Float32Array([0, 0.5, 0.8, 0.4, 0.1, 0, 0, 0.2, 0.6, 0.9, 0.3, 0, 0, 0]), 90, 0, { table: SPHERE_TABLE });
  assert.ok(ouvido.left.length === 14 && ouvido.right.length === 14);
  assert.ok(ouvido.table.includes('EXATA'), 'a orelha informa a base em uso');
  // o ATRASO vive nos taps da célula (fonte à direita → orelha esquerda depois)
  const cel = pickBilinear(SPHERE_TABLE, 90, 0);
  const argmax = (a) => a.reduce((b, v, i, arr) => (v > arr[b] ? i : b), 0);
  const picoL = argmax(cel.L), picoR = argmax(cel.R);
  assert.ok(picoL > picoR + 8, `fonte à direita: orelha esquerda recebe DEPOIS (picoL ${picoL} > picoR ${picoR})`);

  // o raio é o MESMO da ITD de Woodworth do motor (uma cabeça, uma verdade)
  assert.equal(SPHERE_R_M, 0.0875);
  assert.equal(SOUND_C, 343);
});

// --------------------------------------------------- a forja de luz
test('r25: A FORJA DE LUZ — loco Planckiano nas âncoras CIE, fotometria real, determinismo', () => {
  const provas = lightTests();
  assert.equal(provas.length, 13, 'treze provas da luz');
  for (const p of provas) assert.ok(p.ok, `luz: ${p.name} — ${p.detail}`);

  // vela quente × dia frio (8-bit)
  const vela = forgeLight({ kind: 'point', kelvin: 2000, candela: 800 });
  const fria = forgeLight({ kind: 'point', kelvin: 9500, candela: 800 });
  assert.ok(vela.rgb[0] > vela.rgb[2] + 40, `vela é quente: rgb ${vela.rgb}`);
  assert.ok(fria.rgb[2] >= fria.rgb[0], `sombra de céu é fria: rgb ${fria.rgb}`);

  // o rig de 3 pontos avalia a key com a MESMA lei de um ponto
  const rig = forgeRig({ kelvin: 5200, keyCd: 800, fillCd: 0, rimCd: 0, rigDist: 5 });
  const kp = rig.lights[0].pos;
  const ponto = forgeLight({ kind: 'point', candela: 800, kelvin: 5200, x: kp[0], y: kp[1], z: kp[2] });
  const p = [1, 0.5, 0.2];
  assert.ok(Math.abs(rig.evaluate(p).lux - ponto.evaluate(p).lux) < 1e-9, 'rig e ponto: mesma lei');

  // erro honesto fora da lei
  assert.throws(() => forgeLight({ kind: 'neon-magico' }), /fora da lei/);
});

// ------------------------------ a fumaça empurra malhas compostas
test('r25: A FUMAÇA EMPURRA MALHAS COMPOSTAS — força por parte, contato segura o apoiado, bit a bit', () => {
  const montar = () => {
    const { world: w } = createUTS({ seed: 7 });
    const ex = w.fluid3d.origin[0] + 120, ez = w.fluid3d.origin[2] + 120;
    const eh = w.terrain.height(ex, ez);
    const mk = (mat, dy) => w.physics.addBody({
      pos: [ex + 1.5, eh + 3.0 + dy, ez], radius: 0.5, material: mat, label: 'comp',
      parts: [{ offset: [-1.5, 0, 0], radius: 1.2, material: mat }, { offset: [+1.5, 0, 0], radius: 1.2, material: mat }],
    });
    const rock = mk('rock', 0), wood = mk('wood', 0);
    const y0r = w.rrw.getComponent(rock.id, 'spatial').pos[1];
    for (let i = 0; i < 220; i++) {
      w.fluid3d.emit(ex, eh + 2, ez, { amount: 0.4, heat: 1.2 });
      w.fluid3d.step(0.05);
      w.physics.step(0.05);
    }
    const st = (b) => {
      const sp = w.rrw.getComponent(b.id, 'spatial'), ph = w.rrw.getComponent(b.id, 'physics');
      return { y: sp.pos[1], tilt: Math.acos(Math.max(-1, Math.min(1, ph.quat[3]))) * 2, ph };
    };
    return { w, rock, wood, y0r, st, ex, eh };
  };
  const { w, rock, wood, y0r, st } = montar();
  const R = st(rock), W = st(wood);

  // a massa da malha composta é a SOMA das partes (ρV/4 cada)
  const esperado = 2 * ((0.7 * (4 / 3) * Math.PI * 1.2 ** 3) / 4);
  assert.ok(Math.abs(W.ph.mass - esperado) < 1e-9, `massa composta = soma: ${W.ph.mass.toFixed(4)} vs ${esperado.toFixed(4)}`);
  assert.equal(W.ph.parts.length, 2);
  // o raio de colisão alcança a parte mais distante
  assert.ok(W.ph.radius >= 1.5 + 1.2, `raio da malha alcança a parte: ${W.ph.radius}`);

  // o fogo TOMBA a estrutura leve e a levanta; a pedra apoiada NEM SENTE
  assert.ok(W.tilt > 0.3, `a fumaça tomba a malha leve: tilt ${W.tilt.toFixed(3)} rad`);
  assert.ok(W.y > st(wood).y - 1 && W.ph.vel[1] > -1, 'a malha leve não atravessa o chão');
  assert.ok(Math.abs(R.y - y0r) < 0.5, `pedra apoiada não sobe: Δy ${(R.y - y0r).toFixed(3)}m`);
  assert.ok(R.tilt < 0.01, `pedra apoiada não tomba: tilt ${R.tilt.toFixed(4)} rad`);

  // determinismo: a MESMA cena reconstruída é bit a bit idêntica
  const b2 = montar();
  const jt = (m, a, b2) => JSON.stringify({
    pw: m.w.rrw.getComponent(a.id, 'spatial').pos,
    qw: m.w.rrw.getComponent(a.id, 'physics').quat,
    pr: m.w.rrw.getComponent(b2.id, 'spatial').pos,
  });
  assert.equal(jt({ w }, wood, rock), jt(b2, b2.wood, b2.rock), 'mesma semente = mesma realidade');
});

// ------------------------------------------- o lançamento assinado
test('r25: O LANÇAMENTO ASSINADO — o artefato carrega identidade ed25519 verificável', async () => {
  const key = newSigningKey();
  const app = await build({ name: 'GenesisR25', target: 'web', manifest: { title: 'Genesis' }, signingKey: key.privateKey });
  assert.equal(verifySelo(app.artifact).ok, true, 'selo com assinatura valida');

  const bytes = new Uint8Array(app.artifact.data);
  bytes[Math.floor(bytes.length / 2)] ^= 0xff;
  assert.equal(verifySelo({ ...app.artifact, data: bytes }).ok, false, 'UM byte alterado reprova a identidade');

  const outro = newSigningKey();
  const trocado = await build({ name: 'GenesisR25b', target: 'web', manifest: { title: 'Genesis' }, signingKey: outro.privateKey });
  const misturado = { ...app.artifact, selo: { ...app.artifact.selo, pub: JSON.parse(JSON.stringify(trocado.artifact.selo)).pub } };
  assert.equal(verifySelo(misturado).ok, false, 'chave trocada não valida');
});
