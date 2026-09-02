import { test } from 'node:test';
import assert from 'node:assert/strict';
import { measureDevice, calibrationFrame, CALIBRATION } from '../src/measure.ts';
import { materializeVisual } from '../../rrw-mat/src/materialize.ts';
import { ladderFor, costOf } from '../../d-system/src/ladders.ts';

test('S1 a calibração por diferença produz uma constante positiva e declarada', () => {
  const p = measureDevice({ iterations: 60, gridSize: 24 });
  assert.equal(p.kind, 'uts.genesis.device');
  assert.ok(p.unitsPerSecond > 0, `unitsPerSecond=${p.unitsPerSecond}`);
  assert.ok(p.calibrationBand!.msHigh > p.calibrationBand!.msLow, 'o degrau mais rico tem de custar mais tempo: sem Δ mensurável não há constante');
  assert.match(p.note, /NÃO é raster|FALHOU/);
  assert.ok(p.measuredAt.length > 10);
});

test('S2 a limitação da calibração viaja junto do número, não fica escondida no código', () => {
  const p = measureDevice({ iterations: 40, gridSize: 16 });
  assert.match(p.limitation, /perLight\/perVolume/);
  assert.match(p.note, /LIMITAÇÃO CONHECIDA/);
  const json = JSON.parse(JSON.stringify(p));
  assert.equal(json.limitation, p.limitation, 'o device.json gravado tem de conter a restrição de validade');
});

test('S3 o workload de calibração escala com D (senão o Δ é ruído)', () => {
  const t = (D: number) => {
    const f = calibrationFrame(D);
    const a = materializeVisual(f, { gridSize: 32 });
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < 40; i++) materializeVisual(f, { gridSize: 32 });
    return Number(process.hrtime.bigint() - t0) / 1e6 / 40 + a.cells * 0;
  };
  assert.ok(t(5) > t(1), `D5 ${t(5).toFixed(3)} ms vs D1 ${t(1).toFixed(3)} ms`);
  assert.ok(CALIBRATION.cells.w * CALIBRATION.cells.h > 1e5, 'workload tem de ser de tamanho realista');
});

test('S4 iterações baixas não geram constante silenciosa: Δ pequeno é declarado', () => {
  const p = measureDevice({ iterations: 2, gridSize: 4, Dlow: 4, Dhigh: 5 });
  assert.ok(p.unitsPerSecond >= 0);
  assert.ok(typeof p.note === 'string' && p.note.length > 20, 'toda calibração carrega a declaração do que mediu');
});
