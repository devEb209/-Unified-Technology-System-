// R9 — REALIDADE COMPLETA (ADR-020/019): a nuvem que se VÊ é a que SOMBREA
// o solo; o vento é UM campo (dobrar árvores, espalhar fogo, advectar nuvens);
// o olho se ADAPTA à luz real; florestas são mistas (não monoculturas).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { transmitToward, march, CLOUD_GLSL } from '../src/render/clouds.js';
import { treeMesh } from '../src/render/mesh.js';
import { SKY_FS, TERRAIN_FS, ENTITY_FS, WATER_FS, TREE_FS } from '../src/render/shaders.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';

const norm = (v) => { const l = Math.hypot(...v); return v.map(x => x / l); };
const sun = norm([0.3, 0.8, 0.4]);

test('r9: sombra de nuvem — a MESMA integração, do solo para o sol', () => {
  const p = [500, 5, 500];
  assert.equal(transmitToward(p, sun, 0.02, 1.3), 1, 'céu limpo: solo recebe sol integral');
  const mid = transmitToward(p, sun, 0.4, 1.3);
  const storm = transmitToward(p, sun, 0.95, 1.3);
  assert.ok(mid < 1 && storm < mid, `monótono na cobertura: 1 > ${mid.toFixed(2)} > ${storm.toFixed(2)}`);
  assert.ok(storm < 0.3, `tempestade corta o sol direto (${storm.toFixed(2)})`);
  // o mesmo march que pinta o céu (consistência da física única)
  const skyMarch = march([500, 200, 500], sun, sun, 0.95, { intensity: 1 }, { seedT: 1.3, steps: 8 });
  assert.ok(skyMarch.T <= storm + 1e-9, 'mesma física (T coerente com o march completo)');
});

test('r9: TERRAIN_FS integra a sombra de nuvem (fonte gerada compartilhada)', () => {
  assert.ok(TERRAIN_FS.includes(CLOUD_GLSL), 'TERRAIN usa o MESMO GLSL gerado das nuvens');
  assert.ok(TERRAIN_FS.includes('marchClouds(vPos + uSunDir*0.5'), 'amostrada do solo para o sol');
  assert.ok(TERRAIN_FS.includes('uCloudCov') && TERRAIN_FS.includes('ndl*0.75*sh*cloudT'),
    'sol direto atenuado pela transmitância da nuvem');
});

test('r9: o olho se ADAPTA à luz REAL (rápido no flash, lento no escuro)', () => {
  const uts = createUTS({ seed: 'olho' });
  uts.ues.run(3);
  const day = uts.world.observer.exposure;
  assert.ok(day > 0.6 && day < 1.4, `dia normaliza ~1 (${day.toFixed(2)})`);
  // flash: cone/íris constrige RÁPIDO (τ ~0.35s) — precisa dt fino (flash é sub-segundo)
  uts.world.environment.flash = 1;
  uts.world.updateWeather(0.25);
  const afterFlash = uts.world.observer.exposure;
  assert.ok(afterFlash < day * 0.9, `flash derruba a exposição (${afterFlash.toFixed(2)} < ${(day * 0.9).toFixed(2)})`);
  // noite REAL (relógio, não pintura): midnight = time 0. Ticks são 0.05s
  // (tickRate 20/s): 150 ticks = 7.5s — a dilatação LENTA (τ=11s) dá ~2.2×
  const night = createUTS({ seed: 'olho-noite' });
  night.world.clock.time = 0;
  night.ues.run(150);
  assert.ok(night.world.observer.exposure > 2, `escuro dilata LENTO (${night.world.observer.exposure.toFixed(2)} após 7.5s)`);
  assert.ok(night.world.clock.isNight, 'relógio confirma noite');
  // o frame carrega o ganho do observador
  const f = uts.ues.renderFrame();
  assert.equal(f.exposure, uts.world.observer.exposure, 'frame.exposure == mundo (uma verdade)');
});

test('r9: UM vento — o mesmo campo advecta nuvens, dobra árvores, espalha fogo', () => {
  const drive = (wind, seconds) => {
    const u = createUTS({ seed: 'vento' });
    u.ues.run(2);
    u.world.environment.wind = wind;
    for (let i = 0; i < seconds; i++) u.world.updateWeather(1); // a inércia (targetWind) é parte da realidade
    return u;
  };
  const strong = drive(0.9, 5), weak = drive(0.2, 5);
  assert.ok(strong.world.atmosphere.state.cloudDrift > weak.world.atmosphere.state.cloudDrift * 1.8,
    `vento forte deriva ≫ vento fraco (${strong.world.atmosphere.state.cloudDrift.toFixed(3)} vs ${weak.world.atmosphere.state.cloudDrift.toFixed(3)})`);
  assert.equal(strong.ues.renderFrame().clouds.seedT, strong.world.atmosphere.state.cloudDrift,
    'o campo de nuvens usa a DERIVADA do vento');
  // determinismo: mesmo vento, mesma deriva
  const again = drive(0.9, 5);
  assert.equal(again.world.atmosphere.state.cloudDrift, strong.world.atmosphere.state.cloudDrift);
  // o vento que o renderer usa nas árvores/fogo é o do mundo (uma só fonte)
  assert.equal(strong.ues.renderFrame().environment.wind, strong.world.environment.wind);
});

test('r9: floresta MISTA — pinheiro e broadleaf competem no mesmo bioma', () => {
  const uts = createUTS({ seed: 'mata' });
  const eco = uts.world.ecology;
  const list = eco.speciesListFor(3);
  assert.equal(list.length, 2, 'FOREST tem duas espécies');
  assert.equal(eco.speciesFor(3).name, 'pine', 'compat: primária continua pine');
  let pine = 0, broad = 0, shrub = 0;
  for (let x = 400; x < 640; x += 8) for (let z = 400; z < 640; z += 8) {
    const t = eco.seed(x, z);
    if (!t) continue;
    if (t.species === 'pine') pine++;
    else if (t.species === 'broadleaf') broad++;
    else shrub++;
  }
  assert.ok(pine > 0 && broad > 0, `povoamento misto real: ${pine} pinheiros + ${broad} broadleaf (+${shrub} arbustos no gramado)`);
  // parâmetros distintos (a realidade diferencia as espécies)
  const sp = eco.speciesListFor(3).find(s => s.name === 'broadleaf');
  assert.ok(sp.height < 9 && sp.mature < 26, `broadleaf: menor e mais rápida (${sp.height} vs 9)`);
});

test('r9: broadleaf é geometria real distinta (copa blob, tronco, stride 7)', () => {
  const pine = treeMesh('pine'), broad = treeMesh('broadleaf');
  assert.notEqual(broad.count, pine.count);
  assert.equal(broad.data.length, broad.count * 7);
  let canopy = 0, trunk = 0;
  for (let i = 0; i < broad.count; i++) broad.data[i * 7 + 6] === 1 ? canopy++ : trunk++;
  assert.ok(canopy > broad.count * 0.4, `copa dominante (${canopy}/${broad.count})`);
  assert.ok(trunk > 0, 'tronco presente');
});

test('r9: integração mock-GL — duas malhas, dois grupos, 10 programas', async () => {
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
  const uts = createUTS({ seed: 'gl-mata' });
  uts.ues.run(5);
  uts.ues.moveCamera([520, 30, 540], 0.5, 0.1);
  const r = new WebGL2Renderer(gl);
  r.init();
  assert.equal(programs.length, 11, 'o POST é o único programa novo (a óptica do olho na tela)');
  const frame = uts.ues.renderFrame();
  frame.vegetation = [
    ...frame.vegetation,
    { id: 'tp', pos: [521, 5, 541], height: 9, health: 1, species: 'pine' },
    { id: 'tb', pos: [523, 5, 543], height: 7, health: 0.7, species: 'broadleaf' },
  ];
  const res = r.render(frame);
  assert.ok(res.drawCalls > 0);
  assert.ok(r.stats.treeInstances >= 2, `ambas as espécies materializadas: ${r.stats.treeInstances}`);
  assert.equal(frame.exposure, uts.world.observer.exposure, 'exposição chega ao renderer');
  // sombra de nuvem: uniforms causalmente ligados ao mesmo estado
  assert.equal(frame.clouds.seedT, uts.world.atmosphere.state.cloudDrift);
});

test('r9: o ganho do olho existe nos 5 shaders que produzem imagem', () => {
  for (const [n, fs] of [['SKY', SKY_FS], ['TERRAIN', TERRAIN_FS], ['ENTITY', ENTITY_FS], ['WATER', WATER_FS], ['TREE', TREE_FS]]) {
    const n1 = (fs.match(/uniform float uExposure;/g) || []).length;
    const n2 = (fs.match(/col \*= uExposure;/g) || []).length;
    assert.ok(n1 >= 1 && n2 >= 1, `${n}: declara e aplica o ganho (${n1}/${n2})`);
  }
});
