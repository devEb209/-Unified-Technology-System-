// Densidade de representação por célula — o "desrenderizar o desnecessário" como
// instrumento medido, não como promessa nem como recusa.
import test from 'node:test';
import assert from 'node:assert/strict';
import { foveaField, applyFovea, budgetFovea } from '../src/fovea.ts';
import { measureQp } from '../src/quality.ts';
import { materializeVisual } from '../src/materialize.ts';
import { visualFrameAtD } from '../src/render.ts';
import { vnoise } from '../src/hash.ts';

function coherent(g: number, oct = 1) {
  const s = new Float64Array(g * g);
  for (let y = 0; y < g; y++) for (let x = 0; x < g; x++) {
    let v = 0, a = 1, f = 1 / 8;
    for (let o = 0; o < oct; o++) { v += a * vnoise(x * f, y * f, o * 7.3); a *= 0.5; f *= 2; }
    s[y * g + x] = v;
  }
  let lo = Infinity, hi = -Infinity;
  for (const v of s) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
  for (let i = 0; i < s.length; i++) s[i] = (s[i] - lo) / (hi - lo || 1);
  return { w: g, h: g, D: 5, samples: s };
}

test('F0 entrada inválida é recusada com erro nomeado (sem densidade silenciosa)', () => {
  for (const [over, code] of [
    [{ g: 3 }, 'FOVEA_GRID'],
    [{ focus: [1.4, 0.5] }, 'FOVEA_FOCUS'],
    [{ radius: 0 }, 'FOVEA_RADIUS'],
    [{ minDensity: 0 }, 'FOVEA_DENSITY'],
  ] as const) {
    assert.throws(() => foveaField({ g: 24, focus: [0.5, 0.5], ...(over as object) } as never), (e: Error) => e.message.startsWith(code));
  }
  assert.throws(() => budgetFovea({ g: 24, allowedWork: 1.7 } as never), /FOVEA_BUDGET/);
});

test('F1 a densidade é 1 na atenção e decai até o piso, monotonicamente com a distância', () => {
  const f = foveaField({ g: 32, focus: [0.5, 0.5], radius: 0.1, falloff: 0.2, minDensity: 0.3, source: 'reticle' });
  const c = f.weights[16 * 32 + 16];
  const m = f.weights[16 * 32 + 24];
  const e = f.weights[1];
  assert.ok(c > m && m > e, `esperado centro ${c} > anel ${m} > canto ${e}`);
  assert.ok(Math.abs(c - 1) < 1e-9, 'densidade no foco é plena');
  assert.ok(e > 0, 'a periferia é REAPRESENTADA com menos densidade, nunca apagada');
  assert.equal(f.source, 'reticle', 'a origem da hipótese de atenção viaja no resultado');
});

test('F2 aplicar a densidade NUNCA aumenta o trabalho, e o workFraction bate com a soma', () => {
  const f = foveaField({ g: 32, focus: [0.5, 0.5] });
  let s = 0;
  for (const v of f.weights) s += v;
  assert.ok(Math.abs(s / (32 * 32) - f.workFraction) < 1e-3);
  assert.ok(f.workFraction <= 1);
});

test('F3 O QUE IMPORTA: em cena coerente, cortar densidade é aceito pelo piso até um limite — e o limite é MEDIDO', () => {
  const ref = coherent(32, 1);
  let best = 0;
  for (let md = 1; md >= 0.25; md -= 0.05) {
    const f = foveaField({ g: 32, focus: [0.5, 0.5], radius: 0.18, minDensity: md, source: 'reticle' });
    const q = measureQp(ref, applyFovea(ref, f));
    if (q.Qp >= 0.9) best = Math.max(best, 1 - f.workFraction);
  }
  assert.ok(best > 0.3, `economia aceita pelo piso medida em ${best} — se cair abaixo de 30%, a medição mudou e a conclusão precisa ser reescrita`);
  assert.ok(best < 0.6, 'ninguém tem direito a prometer metade da tela sem medir a cena');
});

test('F4 o limite é da CENA, não do hardware: mesma densidade, mais alta-frequência → menos aceito', () => {
  const f = foveaField({ g: 32, focus: [0.5, 0.5], radius: 0.18, minDensity: 0.5, source: 'reticle' });
  const low = measureQp(coherent(32, 1), applyFovea(coherent(32, 1), f));
  const hi = measureQp(coherent(32, 6), applyFovea(coherent(32, 6), f));
  assert.ok(low.Qp > hi.Qp, `cena coerente ${low.Qp} vs alta-frequência ${hi.Qp}: se inverter, o medidor de Qp está cego`);
});

test('F5 densidade plena reproduz o campo bitwise (a economia começa em 0, não em viés)', () => {
  const ref = materializeVisual(visualFrameAtD(4, { entities: 12 }), { gridSize: 24 }).field;
  const full = foveaField({ g: 24, focus: [0.5, 0.5], radius: 1, falloff: 1, minDensity: 1 });
  assert.deepEqual(Array.from(applyFovea(ref, full).samples), Array.from(ref.samples));
});

test('F6 budgetFovea resolve o maior raio que cabe no orçamento — e para quando não cabe', () => {
  const a = budgetFovea({ g: 32, allowedWork: 0.8 });
  const b = budgetFovea({ g: 32, allowedWork: 0.95 });
  assert.ok(a.density <= 0.8 + 1e-3 && b.density > a.density, `${a.density} vs ${b.density}`);
  assert.equal(a.fovea.source, 'static-prior', 'sem hipótese de atenção declarada, a origem é dita: piso da família, não fallback mudo');
  // o "não cabe" tem de ser erro nomeado, não preset rebaixado
  assert.throws(() => budgetFovea({ g: 32, allowedWork: 0.01, minDensity: 0.99 }), /FOVEA_BUDGET/);
});
