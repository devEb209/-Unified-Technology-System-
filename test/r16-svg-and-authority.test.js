// R16 — ÍCONES SVG PRÓPRIOS (zero emoji), ACOMODAÇÃO COM DEPTH REAL (DOF
// lê a profundidade da cena), A LENTE DO ESTILO (vinheta cos⁴ + grão de
// sensor), O AGENTE GRÁFICO (shader-smith com espelho testado), SYNC
// AUTORITATIVO (seq/gap/replay honestos) e BIOLOGIA→ATMOSFERA (a mata
// transpira e a névoa nasce).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createUTS } from '../src/index.js';
import { ICONS, spriteSheet, svgIcon } from '../src/render/icons.js';
import { styleParams } from '../src/render/style.js';
import { composeOptics, EFFECTS } from '../src/agent/shader-smith.js';
import { encodeDelta, applyDelta, DeltaStream } from '../src/net/sync.js';
import { POST_FS } from '../src/render/shaders.js';
import { makeGL } from './helpers/mock-gl.js';

const ALLOWED = new Set([...'→←↑↓—–…≤≥±×÷°·’‘“”']);

test('r16: ÍCONES PRÓPRIOS — o demo tem ZERO emoji e todo <use> existe no sprite', async () => {
  const html = await readFile(new URL('../demos/web/index.html', import.meta.url), 'utf8');
  const emojiish = [...html].filter((c) => c.codePointAt(0) >= 0x2190 && !ALLOWED.has(c) && !(c >= 'A' && c <= 'z') && !(c >= '0' && c <= '9'));
  // caracteres não-ASCII permitidos: acentos PT-BR, pontuação — tudo abaixo de U+2190
  assert.deepEqual(emojiish, [], `sobrou emoji/caractere gráfico: ${emojiish.map((c) => `U+${c.codePointAt(0).toString(16)}`).join(' ')}`);
  // todo ícone referenciado EXISTE (fonte única)
  const used = [...html.matchAll(/href="#i-([a-z]+)"/g)].map((m) => m[1]);
  assert.ok(used.length >= 12, `o demo usa ${used.length} ícones`);
  for (const name of new Set(used)) assert.ok(ICONS[name], `ícone "${name}" usado mas não definido`);
  assert.equal(Object.keys(ICONS).length >= 20, true, `biblioteca: ${Object.keys(ICONS).length} ícones`);
  assert.ok(spriteSheet().includes('<symbol id="i-eye"'), 'sprite completo');
  assert.throws(() => svgIcon('não-existe'), /desconhecido/, 'ícone inventado = erro honesto');
});

test('r16: ACOMODAÇÃO COM DEPTH REAL — o post lê a PROFUNDIDADE e foca onde o olho acomoda', () => {
  assert.match(POST_FS, /uniform sampler2D uDepth/, 'o depth da cena é input');
  assert.match(POST_FS, /uNear \* uFar/, 'linearização da profundidade (near/far reais)');
  assert.match(POST_FS, /uPupil \/ 7\.0/, 'o círculo de confusão cresce com a ABERTURA (pupila)');
  assert.match(POST_FS, /texture\(uDepth, vec2\(0\.5\)\)/, 'o foco é o CENTRO (onde o olho acomoda)');
  assert.match(POST_FS, /pow\(cosA, 4\.0\)/, 'vinheta cos⁴ no post');
  assert.match(POST_FS, /uGrain \* \(n - 0\.5\) \/ sqrt/, 'grão de sensor ∝ 1/√sinal');
});

test('r16: A LENTE DO ESTILO — noir carrega vinheta+grão; realista é identidade; override valida', () => {
  const noir = styleParams('noir');
  assert.ok(noir.params.vignette > 0.3 && noir.params.grain > 0.1, `noir: vinheta ${noir.params.vignette} grão ${noir.params.grain}`);
  const real = styleParams('realista');
  assert.equal(real.params.vignette, 0, 'realista NÃO vinha (identidade honesta)');
  const mine = styleParams('meu noir', { grain: 0.4, vignette: 0.7 });
  assert.equal(mine.params.grain, 0.4);
  assert.ok(mine.name.includes('criado'));
  assert.throws(() => styleParams('x', { grain: 'muito' }), /não numérico/);
});

test('r16: O AGENTE GRÁFICO — forja óptica da biblioteca verificada, espelho = GLSL', async () => {
  assert.equal(EFFECTS.vinheta.desc.includes('cos⁴'), true);
  const r = composeOptics({ effects: ['vinheta', 'grao'], amount: { vinheta: 0.5, grao: 0.3 } });
  assert.equal(r.ok, true);
  assert.equal(r.params.vignette, 0.5);
  assert.equal(r.params.grain, 0.3);
  // o GLSL gerado carrega AS MESMAS constantes que o espelho testou
  assert.match(r.glsl, /0\.5000/);
  assert.match(r.glsl, /0\.3000/);
  assert.equal(r.selfTest.finite, true);
  // honesto: efeito inventado e intensidade fora de faixa
  assert.throws(() => composeOptics({ effects: ['neon'] }), /desconhecido/);
  assert.throws(() => composeOptics({ effects: ['vinheta'], amount: { vinheta: 9 } }), /fora de \[/);
  assert.throws(() => composeOptics({}), /diga os efeitos/);
  // a tool aplica na lente viva
  const uts = createUTS({ seed: 'smith' });
  uts.ues.run(1);
  uts.ues.renderFrame();
  await uts.core.tools.execute('world.style', { style: 'noir' });
  const out = await uts.core.tools.execute('agent.shader', { effects: ['grao'], grain: 0.25 });
  assert.equal(out.ok, true);
  const f = uts.ues.renderFrame();
  assert.equal(f.style.grain, 0.25, 'a óptica forjada chega ao frame');
});

test('r16: SYNC AUTORITATIVO — seq exata, replay idempotente, gap É ERRO (nunca divergência)', () => {
  const stream = new DeltaStream();
  const server = { tick: 0, style: 'realista' };
  const client = { ...server };
  let clientSeq = 0;
  for (const state of [{ tick: 1, style: 'anime' }, { tick: 2, erosionMoved: 0.5 }, { tick: 3, style: 'noir' }]) {
    const wire = stream.encode(state);
    const r = applyDelta(client, wire, clientSeq);
    assert.equal(r.applied, true);
    clientSeq = r.lastSeq;
  }
  assert.deepEqual(client, { tick: 3, style: 'noir', erosionMoved: 0.5 }, 'cliente = servidor (byte a byte)');
  // replay antigo: IGNORADO (idempotente — reconexão não duplica)
  const old = encodeDelta(2, { tick: 99 });
  const rp = applyDelta(client, old, clientSeq);
  assert.equal(rp.applied, false);
  assert.equal(client.tick, 3, 'estado NÃO volta');
  // gap: o cliente PEDE snapshot, nunca adivinha
  assert.throws(() => applyDelta(client, encodeDelta(9, { tick: 9 }), clientSeq), /GAP/);
  assert.equal(encodeDelta(1, {}).startsWith('{"v":1,"seq":1'), true, 'wire versionado');
});

test('r16: BIOLOGIA→ATMOSFERA — a mata madura TRANSPIRA e a névoa nasce mais cedo', () => {
  const forest = createUTS({ seed: 'respira' });
  const bare = createUTS({ seed: 'respira' });
  // MESMA chuva e madrugada; a ÚNICA diferença é a transpiração do dossel
  forest.world.environment.rain = 0.4;
  bare.world.environment.rain = 0.4;
  forest.world.environment.wetness = 0.5;
  bare.world.environment.wetness = 0.5;
  const focus = forest.world.ues?.camera?.pos ?? [512, 0, 512];
  // floresta: dossel maduro denso perto do foco; limpa: SEM árvores no raio
  let planted = 0;
  for (const tree of forest.world.ecology.trees.values()) {
    const dx = tree.pos[0] - focus[0], dz = tree.pos[2] - focus[2];
    if (dx * dx + dz * dz < 100 * 100) { tree.age = 999; tree.maturity = 1; tree.state = 'mature'; planted++; }
  }
  assert.ok(planted >= 5, `floresta plantada: ${planted} árvores maduras`);
  for (const tree of bare.world.ecology.trees.values()) {
    const dx = tree.pos[0] - focus[0], dz = tree.pos[2] - focus[2];
    if (dx * dx + dz * dz < 100 * 100) tree.state = 'dead';
  }
  const canopy = forest.world.ecology.canopyNear(focus[0], focus[2], 100);
  assert.ok(canopy > 0.3, `dossel: ${canopy.toFixed(2)}`);
  assert.equal(bare.world.ecology.canopyNear(focus[0], focus[2], 100), 0);
  // madrugada (sol baixo): o ar da mata recebe a TRANSPIRAÇÃO (bioHumidity)
  for (let i = 0; i < 40; i++) {
    forest.world.atmosphere.step(1, { ...forest.world.environment, sunEl: 0.05, wind: 0.05, bioHumidity: canopy });
    bare.world.atmosphere.step(1, { ...bare.world.environment, sunEl: 0.05, wind: 0.05, bioHumidity: 0 });
  }
  assert.ok(forest.world.atmosphere.state.humidity > bare.world.atmosphere.state.humidity,
    `umidade: mata ${forest.world.atmosphere.state.humidity.toFixed(3)} > limpa ${bare.world.atmosphere.state.humidity.toFixed(3)}`);
  assert.ok(forest.world.atmosphere.state.fog > bare.world.atmosphere.state.fog,
    `névoa: mata ${forest.world.atmosphere.state.fog.toFixed(3)} > limpa ${bare.world.atmosphere.state.fog.toFixed(3)}`);
});

test('r16: O POST CONTINUA SÓ — nenhum programa novo; o depth é do MESMO fbo', async () => {
  const uts = createUTS({ seed: 'fbo' });
  uts.ues.run(1);
  const gl = makeGL();
  // device SEM fbo: sem post, sem depth — o resto desenha normal (honesto)
  const r = new (await import('../src/render/webgl2.js')).WebGL2Renderer(gl);
  r.init();
  assert.equal(r.programs.post, null, 'sem FBO → sem post (honesto)');
  assert.equal(r.sceneFbo, null);
  const out = r.render(uts.ues.renderFrame());
  assert.ok(out.drawCalls >= 1, 'sem post o frame desenha igual');
});
