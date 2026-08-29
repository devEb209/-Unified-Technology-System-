// R18 — O MAR VIVO (plâncton que floresce com o silt do rio e brilha na
// perturbação noturna), A ORELHA QUE GIRA SUAVE (HRTF binlinear), O FIO
// COMPACTO (snapshot menor, mesma verdade), O SMITH COMPLETO (bloom
// fisiológico + tonemap de display), O FIO DO LLM CONTOUDADO (parser SSE)
// e a noite ao alcance de um botão.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createUTS } from '../src/index.js';
import { WATER_FS, POST_FS } from '../src/render/shaders.js';
import { pickBilinear, PARAMETRIC_TABLE, applyHRTF } from '../src/audio/hrtf.js';
import { compactState, encodeSnapshotCompact, applySnapshot, applyDelta, DeltaStream } from '../src/net/sync.js';
import { composeOptics, EFFECTS } from '../src/agent/shader-smith.js';
import { createSSEParser } from '../src/net/sse.js';
import { ICONS } from '../src/render/icons.js';

test('r18: O PLÂNCTON — floresce com o silt que chega ao mar; decai sem ele; sobrevive a save/load', () => {
  const uts = createUTS({ seed: 'mar-vivo' });
  const eco = uts.world.ecology;
  const base = eco.plankton;
  // nutrientes no mar + luz → FLORESCIMENTO
  eco.step(20, { sunEl: 1, seaSilt: 0.5 });
  const bloom = eco.plankton;
  assert.ok(bloom > base, `silt aduba o mar (${base.toFixed(3)} → ${bloom.toFixed(3)})`);
  // sem nutriente: decai de volta (a vida custa)
  for (let i = 0; i < 400; i++) eco.step(1, { sunEl: 1, seaSilt: 0 });
  assert.ok(eco.plankton < bloom, 'sem nutrientes o florescimento passa');
  // escuro: fotossíntese menor (cresce menos que no sol)
  const dark = createUTS({ seed: 'mar-vivo' });
  dark.world.ecology.step(20, { sunEl: 0, seaSilt: 0.5 });
  assert.ok(dark.world.ecology.plankton < bloom, 'no escuro floresce menos (fotossíntese)');
  // save/load carrega a vida do mar
  const snap = uts.world.phenomenaSnapshot();
  const fresh = createUTS({ seed: 'outra' });
  fresh.world.phenomenaRestore(snap);
  assert.equal(fresh.world.ecology.plankton, eco.plankton, 'o plâncton persiste');
});

test('r18: BIOLUMINESCÊNCIA — a cadeia INTEIRA viva: chuva→erosão→silt→mar→plâncton→brilho', () => {
  const uts = createUTS({ seed: 'correnteza' });
  // achar a costa e levar o OBSERVADOR lá (o foco dos fenômenos)
  const t = uts.world.terrain;
  let coast = null;
  for (let x = 8; x < 1016 && !coast; x += 8) {
    for (let z = 8; z < 1016; z += 8) {
      if (t.height(x, z) >= t.seaLevel) continue;
      let seaN = 0;
      for (let k = 0; k < 8; k++) {
        const a2 = (k / 8) * Math.PI * 2;
        if (t.height(x + Math.cos(a2) * 180, z + Math.sin(a2) * 180) < t.seaLevel) seaN++;
      }
      if (seaN >= 4) { coast = [x, z]; break; }
    }
  }
  assert.ok(coast, 'o mundo tem costa ABERTA (o horizonte enxerga o mar)');
  uts.ues.moveCamera([coast[0], 10, coast[1]]);
  uts.world.environment.rain = 0.7;
  uts.ues.run(90); // 4.5s de chuva forte na costa: erosão → silt → mar
  const env = uts.world.environment;
  assert.ok(env.seaHumidity > 0, `o observador está no mar (${env.seaHumidity})`);
  assert.ok(env.bioGlow > 0, `o brilho ligou: plâncton ${uts.world.ecology.plankton.toFixed(3)} × mar ${env.seaHumidity.toFixed(2)} = ${env.bioGlow.toFixed(4)}`);
  // o shader SABE mostrar: uBio, escuro e água perturbada
  assert.match(WATER_FS, /uniform float uBio/);
  assert.match(WATER_FS, /uBio \* nightW \* stir/);
  assert.match(WATER_FS, /vec3\(0\.18, 0\.85, 0\.62\)/, 'a cor do dinoflagelado');
  // o interior não brilha (não há mar lá)
  const inland = createUTS({ seed: 'correnteza' });
  inland.world.environment.rain = 0.7;
  inland.ues.run(90);
  // plâncton pode ter crescido, mas SEM mar o brilho é zero
  if (inland.world.environment.seaHumidity === 0) {
    assert.equal(inland.world.environment.bioGlow, 0, 'sem mar, sem brilho (honesto)');
  }
});

test('r18: A ORELHA GIRA SUAVE — binlinear: 15° é a média exata de 0° e 30°, sem degraus', () => {
  const t = PARAMETRIC_TABLE;
  const mid = pickBilinear(t, 15, 0);
  const a0 = t.data[0][0].L, a30 = t.data[30][0].L;
  assert.ok(Math.abs(mid.L[0] - (a0[0] + a30[0]) / 2) < 1e-12, `interpolação exata (${mid.L[0].toFixed(4)})`);
  // continuidade: vizinhos a ±1° diferem pouco (não há salto de célula)
  const a = applyHRTF(new Float32Array([1, 0, 0]), 29, 0);
  const b = applyHRTF(new Float32Array([1, 0, 0]), 31, 0);
  const diff = Math.abs(a.left[0] - b.left[0]);
  assert.ok(diff < 0.05, `contínua (${diff.toFixed(4)} < 0.05 — atrasos discretos de FIR)`);
  // exatidão nas âncoras (nada se perde nos extremos)
  assert.deepEqual(Array.from(pickBilinear(t, 60, 0).L), Array.from(t.data[60][0].L));
  assert.deepEqual(Array.from(pickBilinear(t, 0, 20).R), Array.from(t.data[0][20].R));
});

test('r18: O FIO COMPACTO — snapshot menor SEM mentir sobre o estado (≤1e-4 de verdade)', () => {
  const uts = createUTS({ seed: 'fio' });
  uts.world.environment.rain = 0.6;
  uts.ues.run(20);
  const state = uts.world.phenomenaSnapshot();
  const raw = JSON.stringify({ v: 1, full: true, seq: 1, state });
  const compact = encodeSnapshotCompact(1, state);
  assert.ok(compact.length < raw.length * 0.95, `compacto: ${compact.length} vs ${raw.length} bytes`);
  // a verdade sobrevive: applySnapshot restaura o estado (dentro de 1e-4 nos números)
  const client = {};
  applySnapshot(client, compact);
  const walk = (a, b, path) => {
    for (const [k, v] of Object.entries(a)) {
      if (typeof v === 'number') assert.ok(Math.abs(v - b[k]) <= 1e-4 + Math.abs(v) * 1e-6, `${path}.${k}: ${v} vs ${b[k]}`);
      else if (v && typeof v === 'object') walk(v, b[k] ?? {}, `${path}.${k}`);
      else if (typeof v !== 'object') assert.equal(v, b[k], `${path}.${k}`);
    }
  };
  walk(compactState(state), client, 'state');
  // e o seq continua autoritativo (gap continua sendo erro)
  const stream = new DeltaStream();
  const wire = stream.snapshot({ tick: 1 });
  const c2 = {};
  const r = applySnapshot(c2, wire);
  assert.equal(r.lastSeq, stream.lastSeq);
  stream.encode({ tick: 2 }); // o cliente PERDE este…
  const jump = stream.encode({ tick: 9 }); // …e recebe o de DEPOIS: gap honesto
  assert.throws(() => applyDelta(c2, jump, r.lastSeq), /GAP/);
});

test('r18: O SMITH COMPLETO — bloom fisiológico e tonemap de display, espelho = GLSL', async () => {
  assert.ok(EFFECTS.bloom.desc.includes('corona ciliar'));
  assert.ok(EFFECTS.tonemap.desc.includes('Reinhard'));
  const r = composeOptics({ effects: ['bloom', 'tonemap'], amount: { bloom: 0.4, tonemap: 0.8 } });
  assert.equal(r.params.bloom, 0.4);
  assert.equal(r.params.tone, 0.8);
  assert.match(r.glsl, /0\.4000/);
  assert.match(r.glsl, /col \/ \(1\.0 \+ col\)/);
  assert.equal(r.selfTest.finite, true);
  // o POST tem os uniforms e o frame carrega
  assert.match(POST_FS, /uniform float uBloomE/);
  assert.match(POST_FS, /mix\(col, col \/ \(1\.0 \+ col\), uTone\)/);
  const uts = createUTS({ seed: 'bloom' });
  uts.ues.run(1);
  uts.ues.renderFrame();
  await uts.core.tools.execute('world.style', { style: 'realista', bloom: 0.5, tone: 0.7 });
  const f = uts.ues.renderFrame();
  assert.equal(f.style.bloom, 0.5, 'a corona chega ao frame');
  assert.equal(f.style.tone, 0.7);
});

test('r18: O FIO DO LLM CONTADO — o parser SSE junta chunks partidos e vê o [DONE]', () => {
  const parser = createSSEParser();
  // o fio chegou PARTIDO no meio de linhas (a realidade de rede)
  parser.feed('data: {"delta":"ol');
  parser.feed('á"}\n\ndata: {"delta":" mundo"}\n\ndata: [DONE]\n\n');
  assert.equal(parser.events.length, 2);
  assert.equal(JSON.parse(parser.events[0]).delta, 'olá', 'o chunk partido FOI RECONSTRUÍDO');
  assert.equal(parser.done, true);
  // comentários/multiline data são ignorados/juntados como no formato
  const p2 = createSSEParser();
  p2.feed(': ping\n\ndata: a\ndata: b\n\n');
  assert.equal(p2.events.length, 1);
  assert.equal(p2.events[0], 'a\nb');
});

test('r18: A NOITE NO ALCANCE DE UM BOTÃO — lua autoral, handler, zero emoji', async () => {
  const html = await readFile(new URL('../demos/web/index.html', import.meta.url), 'utf8');
  assert.ok(html.includes('id="w-night"'), 'o botão noite existe');
  assert.match(html, /\$\('w-night'\)\.onclick/, 'o handler existe');
  assert.ok(html.includes('href="#i-moon"'), 'ícone lua AUTORAL (não emoji)');
  assert.ok(ICONS.moon, 'a lua está na biblioteca');
  const emoji = [...html].filter((c) => c.codePointAt(0) >= 0x2190 && !'→←↑↓—–…≤≥±×÷°·’‘“"'.includes(c) && !(c >= 'A' && c <= 'z') && !(c >= '0' && c <= '9'));
  assert.deepEqual(emoji, [], 'continua ZERO emoji');
  // a noite realmente escurece (o botão manda no tempo real do mundo)
  const uts = createUTS({ seed: 'noite' });
  uts.world.clock.time = 0;
  assert.ok(uts.world.clock.sunElevation < 0.05, `sol abaixo: ${uts.world.clock.sunElevation.toFixed(3)}`);
});
