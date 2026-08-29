// R10 — O MAR E O AR RESPONDEM (realidade completa): ondas com dispersão
// real ω=√gk esculpidas pelo MESMO vento; fumaça que ESPALHA a luz do céu
// (e brilha com a do fogo); neblina de radiação que nasce na alvorada
// úmida e queima com o sol. mock-gl não executa GLSL — física no espelho
// JS + consistência de geração.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { OCEAN_CONST, omega, waveField, OCEAN_GLSL } from '../src/render/ocean.js';
import { emitFire, skyLight, FIRE_CONST } from '../src/render/fire.js';
import { WATER_VS, WATER_FS, TREE_VS } from '../src/render/shaders.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';

test('r10: dispersão de águas profundas REAL (ω=√gk) — o swell corre mais que o chop', () => {
  assert.ok(Math.abs(omega(0.11) - Math.sqrt(9.81 * 0.11)) < 1e-12, 'ω = √(g·k) exato');
  const cSwell = omega(OCEAN_CONST.WAVES[2].k) / OCEAN_CONST.WAVES[2].k;   // c = √(g/k)
  const cChop = omega(OCEAN_CONST.WAVES[1].k) / OCEAN_CONST.WAVES[1].k;
  assert.ok(cSwell / cChop > 1.5, `swell viaja ≫ chop (${(cSwell / cChop).toFixed(2)}×) — física visível`);
});

test('r10: o vento ESCULPE o mar (energia v²) e o BRANQUEIA (cristas que quebram)', () => {
  const wd = [1, 0];
  const hAvg = (wind) => {
    let s = 0, n = 0;
    for (let x = -200; x < 200; x += 7) { s += Math.abs(waveField(x, 0, 3, wind, wd).h); n++; }
    return s / n;
  };
  const calm = hAvg(0.2), storm = hAvg(0.9);
  assert.ok(storm / calm > 2, `mar de tempestade ≫ mar calmo (${(storm / calm).toFixed(1)}×)`);
  const foam = (wind) => {
    let f = 0, n = 0;
    for (let x = -300; x < 300; x += 3.1) for (let z = -60; z < 60; z += 13) { f += waveField(x, z, 17.3, wind, wd).foam; n++; }
    return f / n;
  };
  const fCalm = foam(0.15), fStorm = foam(0.9);
  assert.ok(fStorm > fCalm * 5, `espuma: tempestade ${(fStorm * 100).toFixed(1)}% ≫ calmo ${(fCalm * 100).toFixed(2)}%`);
  assert.ok(fCalm > 0, 'até o mar calmo tem cristas raras que quebram');
  // direção: as ondas viajam NO EIXO do vento (fase avança ao longo de d)
  const a = waveField(0, 0, 5, 0.5, wd), b = waveField(14, 0, 5, 0.5, wd);
  assert.notEqual(a.h, b.h, 'fase avança ao longo da direção do vento');
});

test('r10: OCEAN_GLSL gerado das MESMAS constantes; água e árvore recebem a direção', () => {
  const C = OCEAN_CONST;
  assert.ok(OCEAN_GLSL.includes('do not hand-edit'));
  assert.ok(OCEAN_GLSL.includes(`OCEAN_G = ${C.G}`), 'g idêntico');
  assert.ok(OCEAN_GLSL.includes(`OK0 = ${C.WAVES[0].k}`) && OCEAN_GLSL.includes(`OK1 = ${C.WAVES[1].k}`), 'números de onda idênticos');
  assert.ok(OCEAN_GLSL.includes('sqrt(OCEAN_G*OK0)'), 'dispersão gerada no GLSL');
  assert.ok(WATER_VS.includes('waveField(xz, uTime, uWind, uWindDir'), 'VS desloca com o campo real');
  assert.ok(WATER_FS.includes('waveField(vPos.xz') && WATER_FS.includes('vFoam'), 'FS: normal consistente + espuma');
  assert.ok(WATER_FS.includes('skyColor(vec3(0.0,1.0,0.0)'), 'espuma espalha a cor do CÉU (não branco pintado)');
  assert.ok(TREE_VS.includes('uWindDir.x'), 'a árvore dobra NA direção do vento');
});

test('r10: fumaça iluminada — espalha a luz do céu e brilha com a do fogo', () => {
  const noon = [0.3, 0.95, 0.35].map((v, _, a) => v / Math.hypot(...a));
  assert.ok(skyLight(noon) > 0.8, 'meio-dia ilumina');
  assert.ok(skyLight([0.9, -0.3, 0.35]) < 0.06, 'noite quase não ilumina');
  const mk = () => ({ pos: [100, 3, 100], intensity: 0.7, fuel: 40, cellKey: '9,9' });
  const day = emitFire(mk(), 3.3, 0.2, [], [1, 0, 0], { skyL: 1 });
  const night = emitFire(mk(), 3.3, 0.2, [], [1, 0, 0], { skyL: 0.03 });
  let dayL = 0, nightL = 0, c = 0;
  for (let i = 0; i < day.length / 8; i++) {
    const vi = i * 8 + 4;
    dayL += 0.3 * day[vi] + 0.6 * day[vi + 1];
    nightL += 0.3 * night[vi] + 0.6 * night[vi + 1];
    c++;
  }
  assert.ok(dayL > nightL, `fumaça mais clara de dia (${dayL / c .toFixed(2)} vs ${(nightL / c).toFixed(2)})`);
  assert.ok(nightL / c > 0.3, 'à noite o PRÓPRIO fogo ilumina a fumaça (brilho residual)');
});

test('r10: neblina de radiação — madrugada úmida cria, o sol e o vento queimam', () => {
  const night = (weather) => {
    const u = createUTS({ seed: 'neblina' });
    u.world.clock.time = 0; // madrugada: sol abaixo do horizonte
    u.world.environment.weather = weather; // o clima é EVENTO (applyWeatherTargets manda)
    for (let i = 0; i < 40; i++) u.world.updateWeather(1); // a CADEIA real
    return u;
  };
  const uts = night('rain'); // chuva de madrugada satura o ar → névoa de radiação
  const built = uts.world.atmosphere.state.fog;
  assert.ok(built > 0.4, `névoa se forma na madrugada úmida (${built.toFixed(2)} em 40s)`);
  // sol alto (meio-dia) → QUEIMA
  uts.world.clock.time = 0.5 * uts.world.clock.dayLengthSec;
  uts.world.environment.weather = 'clear';
  for (let i = 0; i < 30; i++) uts.world.updateWeather(1);
  assert.ok(uts.world.atmosphere.state.fog < built * 0.2, `o sol queima a névoa (${uts.world.atmosphere.state.fog.toFixed(3)})`);
  // vento dispersa mais rápido que ar parado (madrugada: só o vento queima)
  const windy = night('rain'), still = night('rain');
  for (const u of [windy, still]) { u.world.clock.time = 100; u.world.atmosphere.state.fog = 0.5; } // sol −0.5: sem queima solar
  windy.world.environment.weather = 'windy';  // alvo de vento 0.85
  still.world.environment.weather = 'cloudy'; // alvo de vento 0.3
  for (let i = 0; i < 30; i++) { windy.world.updateWeather(0.5); still.world.updateWeather(0.5); }
  assert.ok(windy.world.atmosphere.state.fog < still.world.atmosphere.state.fog,
    `vento acelera a dispersão (${windy.world.atmosphere.state.fog.toFixed(2)} < ${still.world.atmosphere.state.fog.toFixed(2)})`);
});

test('r10: os bancos de névoa são MATERIALIZADOS nos baixios (cor = céu real)', () => {
  const uts = createUTS({ seed: 'nevoeiro' });
  uts.ues.run(2);
  uts.world.clock.time = 0; // meia-noite (sol abaixo → a névoa não queima)
  uts.world.environment.weather = 'rain'; // a chuva satura o ar (cadeia real)
  for (let i = 0; i < 45; i++) uts.world.updateWeather(1);
  assert.ok(uts.world.atmosphere.state.fog > 0.25);
  const cam = uts.ues.camera;
  // acha um baixio perto da câmera e move pra lá
  let spot = null;
  for (let r = 0; r < 400 && !spot; r += 24) {
    for (let a = 0; a < 6.28; a += 0.4) {
      const x = cam.pos[0] + Math.cos(a) * r, z = cam.pos[2] + Math.sin(a) * r;
      const h = uts.world.terrain.height(x, z);
      if (h > 2 && h < 8) { spot = [x, z]; break; }
    }
  }
  assert.ok(spot, 'existe baixio no mundo');
  uts.ues.moveCamera([spot[0], 20, spot[2]]);
  const f = uts.ues.renderFrame();
  const fog = f.horizon.filter(hz => hz.kind === 'fog');
  assert.ok(fog.length > 0, `bancos de névoa no frame (${fog.length})`);
  assert.ok(fog.every(hz => hz.alpha <= 0.5 && hz.size > 50), 'sprites suaves, alpha contido');
  // sem névoa → nenhum banco
  uts.world.atmosphere.state.fog = 0;
  const f2 = uts.ues.renderFrame();
  assert.equal(f2.horizon.filter(hz => hz.kind === 'fog').length, 0, 'D-O15: sem estado, sem materialização');
});

test('r10: integração mock-GL — o mar novo desenha com o vento do mundo', async () => {
  const C = { VERTEX_SHADER: 1, FRAGMENT_SHADER: 2 };
  const gl = {
    ...C,
    canvas: { width: 1280, height: 720 },
    DEPTH_COMPONENT: 30, UNSIGNED_INT: 31, TEXTURE_MAG_FILTER: 32, FRAMEBUFFER_COMPLETE: 33, TEXTURE0: 0x84C0,
    createShader: t => ({ t }), shaderSource: () => {}, compileShader: () => {},
    getShaderParameter: () => true, getShaderInfoLog: () => '', deleteShader: () => {},
    createProgram: () => ({}), attachShader: () => {}, linkProgram: () => {}, getProgramParameter: () => true, deleteProgram: () => {},
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
  const uts = createUTS({ seed: 'mar' });
  uts.ues.run(3);
  uts.world.environment.wind = 0.85;
  uts.world.updateWeather(1); // materializa env.windDir (fonte única)
  uts.ues.moveCamera([440, 22, 440], 0.5, 0.1);
  const r = new WebGL2Renderer(gl);
  r.init();
  const frame = uts.ues.renderFrame();
  assert.ok(Array.isArray(frame.environment.windDir) && frame.environment.windDir.length === 2,
    'env.windDir existe (mar, árvores, fogo e nuvens compartilham)');
  const res = r.render(frame);
  assert.ok(res.drawCalls > 0);
  assert.ok(r.stats.waterDraws === 1, 'o mar com dispersão desenha uma vez');
});
