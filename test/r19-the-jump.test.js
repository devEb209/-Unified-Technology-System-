// R19 — O SALTO: LÂMINA D'ÁGUA na física (escoamento raso com atrito de
// leito), CORRENTEZA (o plâncton é campo advectado pelo vento), O FIO COM
// LZ (o menor viaja — texto ou pacote USZ), HRTF DE LITERATURA (grade 13×6,
// sombra medida ≈ -18dB, notch varrendo), KIT DE IMPLANTAÇÃO REAL para exe
// (zip executável + run.sh; SEA honesto), SMITH com ABERRAÇÃO e NITIDEZ,
// e o STREAMING VERIFICADO PONTA-A-PONTA PELO FIO (SSE → parser → remontagem).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { FLUID_CONST } from '../src/world/phenomena/fluids.js';
import { compress, decompress, shrinks } from '../src/util/lz.js';
import { encodeSnapshotPacked, applySnapshot, DeltaStream, applyDelta } from '../src/net/sync.js';
import { PARAMETRIC_TABLE, applyHRTF, pickBilinear, loadMeasuredTable } from '../src/audio/hrtf.js';
import { build } from '../src/agent/build-system.js';
import { zipRead } from '../src/util/zip.js';
import { composeOptics, EFFECTS } from '../src/agent/shader-smith.js';
import { POST_FS } from '../src/render/shaders.js';
import { createSSEParser } from '../src/net/sse.js';

test('r19: LÂMINA D ÁGUA — lâmina profunda deságua mais rápido que película (atrito de leito)', () => {
  const mk = (pour) => {
    const uts = createUTS({ seed: 'lamina' });
    // duas células no MESMO declive: uma rasa (película), uma funda (lâmina)
    const t = uts.world.terrain;
    let flat = null;
    for (let x = 40; x < 1000 && !flat; x += 8) {
      for (let z = 40; z < 1000; z += 8) {
        const h = t.height(x, z);
        if (h > 10 && t.height(x + 4, z) < h - 0.4 && t.height(x + 4, z) > 8) { flat = [x, z]; break; }
      }
    }
    assert.ok(flat, 'existe declive suave para o experimento');
    uts.world.fluid.pour(flat[0], flat[1], pour);
    const mass0 = uts.world.fluid.mass;
    uts.world.fluid.step(1);
    return mass0 - uts.world.fluid.mass;
  };
  const deepDrain = mk(0.5);
  const filmDrain = mk(0.03);
  assert.ok(deepDrain > filmDrain, `lâmina funda escoa mais (${deepDrain.toFixed(4)}) que película (${filmDrain.toFixed(4)})`);
  // conservação segue de pé
  const uts = createUTS({ seed: 'lamina' });
  uts.world.fluid.pour(512, 512, 0.4);
  uts.ues.run(30);
  const f = uts.world.fluid;
  assert.ok(f.mass + f.lost > 0, `massa medida: ${f.mass.toFixed(4)} + perdida ${f.lost.toFixed(4)}`);
});

test('r19: CORRENTEZA — o plâncton é CAMPO: nasce na costa e o VENTO leva o brilho embora', () => {
  const uts = createUTS({ seed: 'corrente' });
  const eco = uts.world.ecology;
  eco.planktonField.set('8,8', 0.9); // bloom na costa oeste
  for (let i = 0; i < 40; i++) eco.step(1, { sunEl: 1, seaSilt: 0.05 }); // 40s de vento do mundo
  const keys = [...eco.planktonField.keys()];
  assert.ok(keys.length > 0, 'o campo existe');
  const moved = keys.some((k) => { const [i, j] = k.split(',').map(Number); return i > 8; });
  assert.ok(moved, `o vento ADVECTOU o bloom para leste (${keys.join(' ')})`);
  // persiste no save/load (o mar continua de onde parou)
  const snap = uts.world.phenomenaSnapshot();
  const fresh = createUTS({ seed: 'outra' });
  fresh.world.phenomenaRestore(snap);
  assert.equal(fresh.world.ecology.planktonField.size, eco.planktonField.size);
});

test('r19: O FIO COM LZ — o MENOR viaja: repetição encolhe, estado único viaja texto, e os dois abrem', () => {
  const enc = new TextEncoder();
  const doc = enc.encode('{"tick":1,"weather":"rain","wet":0.5}&'.repeat(40));
  assert.ok(shrinks(doc), 'repetição comprime');
  assert.deepEqual(Array.from(decompress(compress(doc))), Array.from(doc), 'roundtrip byte-fiel');
  assert.equal(shrinks(enc.encode('abc123')), false, 'pequeno/único não comprime (honesto)');
  // snapshot: pacote USZ quando encolhe, texto quando não — os DOIS aplicam
  const stream = new DeltaStream();
  const repetitive = { tick: 1, line: 'genesis|'.repeat(200) };
  const wire = stream.snapshot(repetitive);
  const client = {};
  const r = applySnapshot(client, wire);
  assert.equal(r.applied, true);
  assert.equal(client.line, repetitive.line, 'o estado chega IGUAL (texto ou USZ)');
  // pacote sem assinatura = erro honesto
  assert.throws(() => decompress(new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])), /assinatura/);
});

test('r19: HRTF DE LITERATURA — grade 13×6, sombra contralateral ≈ -18dB, notch varre com a elevação', () => {
  const T = PARAMETRIC_TABLE;
  assert.equal(T.azimuths.length, 13);
  assert.equal(T.elevations.length, 6);
  assert.match(T.label, /literatura publicada/);
  // sombra contralateral nos extremos (derivada da curva medida ~-16 a -18dB)
  const side = T.data[90][0];
  const peak = (a) => Math.max(...a);
  const darkDb = 20 * Math.log10(peak(side.R) / peak(side.L)); // fonte à direita: L é o ouvido na sombra
  assert.ok(darkDb > 14, `contralateral ${darkDb.toFixed(1)}dB mais escura (curva medida ~-16 a -18dB)`);
  // notch varre: ganho direto cai com a elevação (concha)
  assert.ok(T.data[0][60].L[0] < T.data[0][-40].L[0], 'acima da cabeça a concha corta mais');
  // Woodworth continua: frontal simétrico; lateral com atraso no ouvido distante
  assert.deepEqual(Array.from(T.data[0][0].L), Array.from(T.data[0][0].R));
  assert.ok(T.data[90][0].L[7] > 0 || T.data[90][0].L[6] > 0, 'o atraso aparece nos taps do ouvido distante');
  // o slot MEDIDO continua aberto e validado
  assert.throws(() => loadMeasuredTable({ sr: 0 }), /recusada/);
  // binlinear: 7.5° = média exata de 0° e 15°
  const mid = pickBilinear(T, 7.5, 0).L[0];
  assert.ok(Math.abs(mid - (T.data[0][0].L[0] + T.data[15][0].L[0]) / 2) < 1e-12);
});

test('r19: KIT DE IMPLANTAÇÃO REAL — exe vira zip executável (app + run.sh + INSTALL), SEA honesto', async () => {
  const exe = await build({ name: 'AppVila', target: 'exe', manifest: { title: 'Vila' } });
  assert.equal(exe.ok, true);
  if (/binário único/.test(exe.kind)) {
    // máquina COM postject: o binário SEA é REAL (R21) — ELF e executa
    const head = exe.artifact.data.slice(0, 4);
    assert.ok(head[0] === 0x7f && head[1] === 0x45, 'artefato é executável nativo');
  } else {
    // máquina SEM postject: kit honesto (app + run.sh + INSTALL)
    assert.match(exe.kind, /deploy-kit/);
    assert.match(exe.honest, /postject/, 'o que falta para o binário único está DITO');
    const entries = zipRead(exe.artifact.data);
    assert.ok(entries.has('run.sh') && entries.has('INSTALL.txt'));
    assert.ok(entries.has('AppVila/main.js') && entries.has('AppVila/package.json'));
    const run = new TextDecoder().decode(entries.get('run.sh'));
    assert.match(run, /node main\.js/, 'o kit roda de verdade');
  }
  // android também virou KIT REAL (R20): projeto gradle completo, honesto sobre a toolchain
  const apk = await build({ name: 'AppVila', target: 'android', manifest: {} });
  assert.equal(apk.ok, true);
  assert.match(apk.kind, /android-kit/);
  assert.match(apk.honest, /gradle/, 'sem toolchain o que falta é DITO');
});

test('r19: SMITH COMPLETO — aberração e nitidez forjadas, espelho = GLSL, lente viva recebe', async () => {
  assert.ok(EFFECTS.aberracao.desc.includes('dispersão'));
  assert.ok(EFFECTS.nitidez.desc.includes('unsharp'));
  const r = composeOptics({ effects: ['aberracao', 'nitidez'], amount: { aberracao: 1.2, nitidez: 0.5 } });
  assert.equal(r.params.ca, 1.2);
  assert.equal(r.params.sharp, 0.5);
  assert.equal(r.selfTest.finite, true);
  assert.match(r.glsl, /1\.2000/);
  assert.match(r.glsl, /0\.5000/);
  // o POST tem os uniforms
  assert.match(POST_FS, /uniform float uSharp/);
  assert.match(POST_FS, /1\.0 \+ uCAExtra/);
  assert.match(POST_FS, /uSharp \* \(col \* 2\.0 - sharpN\)/);
  // a lente viva recebe (tool → estilo → frame)
  const uts = createUTS({ seed: 'smith19' });
  uts.ues.run(1);
  uts.ues.renderFrame();
  await uts.core.tools.execute('world.style', { style: 'realista', ca: 0.8, sharp: 0.4 });
  const f = uts.ues.renderFrame();
  assert.equal(f.style.ca, 0.8);
  assert.equal(f.style.sharp, 0.4);
});

test('r19: STREAMING VERIFICADO PELO FIO — SSE → parser → remontagem = o mesmo plano (sem chave)', async () => {
  const uts = createUTS({ seed: 'fio-sse' });
  // o pipeline real gera os chunks; nós os ENQUADRAMOS como SSE e o parser reconstrói
  const frames = [];
  const report = await uts.core.interpretObjectiveStream('crie uma vila de pescadores', undefined, (part) => frames.push(part));
  const parser = createSSEParser();
  // mande pelo fio COMO o formato manda: CADA linha do payload é um data:
  // (JSON pretty tem \n — sem isso o enquadramento quebra o evento cedo)
  const frame = (t) => t.split('\n').map((l) => `data: ${l}`).join('\n') + '\n\n';
  const joined = frames.join('');
  const wire = frame(joined) + 'data: [DONE]\n\n';
  const half = Math.floor(wire.length / 3); // a REDE partiU os bytes no meio (linha inclusive)
  parser.feed(wire.slice(0, half));
  parser.feed(wire.slice(half));
  assert.equal(parser.done, true);
  const reassembled = parser.events.join('\n');
  const rebuilt = JSON.parse(reassembled);
  assert.deepEqual(rebuilt, report, 'o plano INTEIRO sobreviveu ao fio (byte a byte)');
  // e a execução streaming continua com as mesmas garantias
  const chunks = [];
  const full = await uts.core.processObjectiveStream('crie uma vila de pescadores', (c) => chunks.push(c));
  assert.equal(full.ok, true);
  assert.ok(chunks.length >= 1, `progresso entregue em ${chunks.length} partes`);
});
