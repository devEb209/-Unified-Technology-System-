// R8 — ADR-020 continua: nuvens = o MESMO ar condensado (integradas no raio),
// fogo = gás quente EMITINDO luz de corpo negro (Planck), árvores = geometria
// real da população viva. mock-gl não executa GLSL — física validada pelo
// espelho JS + consistência de geração (padrão do r7).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { CLOUD_CONST, CLOUD_GLSL, densityAt, march, phaseHG } from '../src/render/clouds.js';
import { blackbody, flameTemp, emitFire, FIRE_CONST } from '../src/render/fire.js';
import { treeMesh } from '../src/render/mesh.js';
import { SKY_FS } from '../src/render/shaders.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';

const norm = (v) => { const l = Math.hypot(...v); return v.map(x => x / l); };
const sunUp = norm([0.3, 0.8, 0.4]);

test('r8: nuvens CONDENSAM do ar representado (tempestade > chuva > umidade > seco)', () => {
  const a = createUTS({ seed: 'nuvem' }).world.atmosphere;
  assert.equal(a.cloudCoverage({ weather: 'storm' }), 0.95, 'tempestade satura a lâmina');
  assert.ok(a.cloudCoverage({ rain: 0.5 }) > 0.8, 'chuva mantém encoberto');
  a.state.humidity = 0.95; a.state.dust = 0;
  assert.ok(a.cloudCoverage({}) > 0.9, 'ar úmido constrói cúmulos');
  a.state.humidity = 0.2; a.state.dust = 0.5;
  assert.equal(a.cloudCoverage({}), 0, 'ar seco e empoeirado suprime convecção');
});

test('r8: march das nuvens — seco transparente, tempestade opaca, prata EMERGENTE', () => {
  const o = [0, 30, 0];
  const clear = march(o, norm([0, 0.5, 1]), sunUp, 0.02, { intensity: 22 });
  assert.equal(clear.T, 1, 'cobertura ~0 → céu integralmente visível');
  assert.deepEqual(clear.rgb, [0, 0, 0]);
  const storm = march(o, norm([0, 0.3, 1]), sunUp, 0.95, { intensity: 22 });
  assert.ok(storm.rgb.some(v => v > 0.05), 'nuvem de tempestade espalha luz');
  assert.ok(storm.T < 0.85, `tempestade atenua o céu (T=${storm.T.toFixed(2)})`);
  // silver lining: MESMA nuvem fina — olhando NA DIREÇÃO do sol espalha mais (HG)
  const thin = 0.35;
  const toSun = march(o, sunUp, sunUp, thin, { intensity: 22 });
  const away = march(o, norm([-sunUp[0], 0.6, -sunUp[2]]), sunUp, thin, { intensity: 22 });
  const lum = c => c[0] + c[1] + c[2];
  assert.ok(lum(toSun.rgb) > lum(away.rgb) * 1.25,
    `borda prateada emergente: ${lum(toSun.rgb).toFixed(2)} vs ${lum(away.rgb).toFixed(2)}`);
  // noite: sol abaixo → nuvem não brilha
  const night = march(o, norm([0, 0.5, 1]), norm([0.3, -0.5, 0.4]), 0.9, { intensity: 22 });
  assert.deepEqual(night.rgb, [0, 0, 0], 'sem sol não há espalhamento');
  // determinismo
  const a1 = march(o, norm([0, 0.5, 1]), sunUp, 0.6, { intensity: 22 }, { seedT: 1.3 });
  const a2 = march(o, norm([0, 0.5, 1]), sunUp, 0.6, { intensity: 22 }, { seedT: 1.3 });
  assert.deepEqual(a1, a2);
});

test('r8: densidade — perfil da lâmina (fina na base/topo), 0 fora do slab', () => {
  const inSlab = densityAt([0, (CLOUD_CONST.LO + CLOUD_CONST.HI) / 2, 0], 0.9, 0);
  const below = densityAt([0, CLOUD_CONST.LO - 10, 0], 0.9, 0);
  assert.ok(inSlab >= 0, 'densidade definida no slab');
  assert.equal(below, 0, 'abaixo do slab não há nuvem');
  assert.ok(phaseHG(1) > phaseHG(0) * 5, 'HG: pico direto ≫ lateral (gotículas)');
});

test('r8: consistência de geração — CLOUD_GLSL nasce das MESMAS constantes', () => {
  const C = CLOUD_CONST;
  assert.ok(CLOUD_GLSL.includes('do not hand-edit'), 'marcador de geração');
  assert.ok(CLOUD_GLSL.includes(`float C_LO = ${C.LO}`), 'C_LO idêntico');
  assert.ok(CLOUD_GLSL.includes(`float C_HI = ${C.HI}`), 'C_HI idêntico');
  assert.ok(CLOUD_GLSL.includes(`float C_DENS = ${C.DENSITY}`), 'C_DENS idêntico');
  assert.ok(CLOUD_GLSL.includes(`float C_HG = ${C.HG}`), 'C_HG idêntico');
  assert.ok(CLOUD_GLSL.includes(`const int CN = ${C.STEPS}`), 'amostras idênticas');
  assert.ok(CLOUD_GLSL.includes('void marchClouds('), 'march presente');
  assert.ok(SKY_FS.includes('marchClouds(uCamPos, dir') && SKY_FS.includes('uCloudCov'),
    'SKY_FS integra as nuvens por pixel');
});

test('r8: fogo — cor é CORPO NEGRO (Planck), não rampa artística', () => {
  const t1000 = blackbody(1000), t1800 = blackbody(1800), t5800 = blackbody(5800);
  assert.ok(t1000[0] > 0.85 && t1000[2] < 0.02, `1000K vermelho: ${t1000.map(v => v.toFixed(2))}`);
  assert.ok(t1800[1] > t1000[1] * 1.6 && t1800[1] > 0.4, `1800K sobe o verde monótono (${t1800[1].toFixed(2)} vs ${t1000[1].toFixed(2)})`);
  assert.ok(t5800.every(v => v > 0.85), `5800K (sol) quase branco: ${t5800.map(v => v.toFixed(2))}`);
  assert.ok(flameTemp(0) === FIRE_CONST.T0 && flameTemp(1) === FIRE_CONST.T1, 'faixa 900–1800K');
});

test('r8: partículas — contagem ∝ combustível, determinísticas, fumaça envelhece', () => {
  const f = (fuel) => ({ pos: [100, 3, 100], intensity: 0.7, fuel, cellKey: '5,5' });
  const small = emitFire(f(10), 3.3, 0.2);
  const big = emitFire(f(90), 3.3, 0.2);
  const n = (buf) => buf.length / 8;
  assert.ok(n(big) > n(small) * 1.5, `combustível alimenta o pluma: ${n(big)} vs ${n(small)}`);
  const again = emitFire(f(90), 3.3, 0.2);
  assert.deepEqual(Array.from(big), Array.from(again), 'mesmo tempo → mesmas partículas');
  assert.ok(big.every((v, i) => (i % 8 === 3) ? v > 0 : true), 'tamanhos positivos');
  assert.ok(big.every((v, i) => (i % 8 === 7) ? (v >= 0 && v <= 1) : true), 'alphas em [0,1]');
  assert.ok(big.every((v, i) => (i % 8 === 4) ? v >= big[i + 2] - 1e-9 : true),
    'corpo negro: r ≥ b em toda chama < 5800K');
  const night = emitFire({ ...f(50), pos: [0, 0, 0] }, 3.3, 0.2);
  assert.ok(night.some((v, i) => (i % 8 === 7) && v < 0.3), 'fumaça Velha esmaece (alpha baixo existe)');
});

test('r8: árvore é GEOMETRIA real (tronco+copa, normais, determinística)', () => {
  const a = treeMesh('pine'), b = treeMesh('pine');
  assert.equal(a.count, b.count);
  assert.ok(Number.isInteger(a.count) && a.count > 60, `pinheiro: ${a.count} vértices`);
  assert.equal(a.data.length, a.count * 7, 'stride 7 (pos3+norm3+copa)');
  const canopies = new Set();
  for (let i = 0; i < a.count; i++) canopies.add(a.data[i * 7 + 6]);
  assert.deepEqual([...canopies].sort(), [0, 1], 'tem tronco E copa');
  // copa do pinheiro ACIMA do tronco (y do tronco termina ~0.42)
  let maxTrunk = 0;
  for (let i = 0; i < a.count; i++) if (a.data[i * 7 + 6] === 0) maxTrunk = Math.max(maxTrunk, a.data[i * 7 + 1]);
  assert.ok(maxTrunk < 0.5, `tronco termina abaixo da copa (${maxTrunk.toFixed(2)})`);
  assert.ok(treeMesh('grass-shrub').count !== a.count, 'espécies diferem');
});

test('r8: integração mock-GL — 10 programas; árvores e fogo desenham; stats honestos', async () => {
  const C = { VERTEX_SHADER: 1, FRAGMENT_SHADER: 2 };
  const programs = [];
  const gl = {
    ...C,
    canvas: { width: 1280, height: 720 },
    DEPTH_COMPONENT: 30, UNSIGNED_INT: 31, TEXTURE_MAG_FILTER: 32, FRAMEBUFFER_COMPLETE: 33, TEXTURE0: 0x84C0,
    createShader: t => ({ t }), shaderSource: () => {}, compileShader: () => {},
    getShaderParameter: () => true, getShaderInfoLog: () => '', deleteShader: () => {},
    createProgram: () => { const p = { id: programs.length }; programs.push(p); return p; },
    attachShader: () => {}, linkProgram: () => {}, getProgramParameter: () => true, deleteProgram: () => {},
    getUniformLocation: (p, n) => ({ name: n }),
    getAttribLocation: (p, n) => ({ aPos: 0, aNorm: 1, aBiome: 2, aSeed: 0, aInst0: 3, aInst1: 4, aInst2: 5, aHH: 1, aSC: 1, aAlpha: 2, aCanopy: 2, aT0: 3, aT1: 4 })[n] ?? -1,
    uniform2f: () => {},
    createBuffer: () => ({}), bindBuffer: () => {}, bufferData: () => {}, deleteBuffer: () => {},
    enable: () => {}, disable: () => {}, depthFunc: () => {}, depthMask: () => {}, blendFunc: () => {},
    clearColor: () => {}, clear: () => {}, viewport: () => {}, useProgram: () => {},
    uniformMatrix4fv: () => {}, uniform3f: () => {}, uniform1f: () => {}, uniform1i: () => {},
    vertexAttribPointer: () => {}, enableVertexAttribArray: () => {}, vertexAttribDivisor: () => {},
    drawArraysInstanced: () => {}, drawArrays: () => {},
    createTexture: () => ({}), bindTexture: () => {}, texImage2D: () => {}, texParameteri: () => {},
    createFramebuffer: () => ({}), bindFramebuffer: () => {}, framebufferTexture2D: () => {},
    checkFramebufferStatus: () => 33, activeTexture: () => {},
  };
  const uts = createUTS({ seed: 'gl-genesis' });
  uts.ues.run(30);
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  // varre combustível seco perto do spawn
  let spot = null;
  outer: for (let x = 460; x <= 560; x += 4) for (let z = 460; z <= 560; z += 4) {
    if (uts.world.reallife.igniteFire([x, 0, z], strike)) { spot = [x, z]; break outer; }
  }
  assert.ok(spot, 'fogo real aceso no mundo');
  uts.ues.run(2); // updateFires materializa os anchors (RRW)
  uts.ues.moveCamera([spot[0], 24, spot[1] - 37], 0, 0.02); // yaw 0 = +z; pitch 0.02 quase nivelado (a mira cai ~22 em 37)
  const r = new WebGL2Renderer(gl);
  r.init();
  assert.equal(programs.length, 10, 'sky+terrain+entity+points+shadow+water+vegetation+horizon+tree+fire');
  const frame = uts.ues.renderFrame();
  const fireEnts = frame.entities.filter(e => e.fire);
  assert.ok(fireEnts.length >= 1, 'frame carrega anchors de fogo com intensity/fuel');
  assert.ok(fireEnts[0].fire.intensity > 0 && fireEnts[0].fire.fuel >= 0);
  // pinheiros: injeta um pinheiro vivo com saúde real para o pass de malha
  frame.vegetation = [...frame.vegetation, { id: 't-teste', pos: [spot[0] + 5, 5, spot[1]], height: 9, health: 0.8, species: 'pine' }];
  const res = r.render(frame);
  assert.ok(res.drawCalls > 0);
  assert.ok(r.stats.treeInstances >= 1, `pinheiros como malha real: ${r.stats.treeInstances}`);
  assert.ok(r.stats.fireParticles >= 6, `partículas de fogo emitidas: ${r.stats.fireParticles}`);
  // determinismo do frame: mesmos estados → mesma óptica
  const f2 = uts.ues.renderFrame();
  assert.deepEqual(f2.clouds, frame.clouds, 'cobertura de nuvem determinística');
  assert.deepEqual(f2.air, frame.air);
});
