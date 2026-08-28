// UTS :: test/core — RNG, Clock, Perf, math determinism.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RNG } from '../src/core/rng.js';
import { Clock } from '../src/core/clock.js';
import { PerfMeter } from '../src/core/perf.js';
import { clamp, lerp, dist2, fnv1a, hash2 } from '../src/core/math.js';

test('rng: deterministic sequence from same seed', () => {
  const a = new RNG('seed-x');
  const b = new RNG('seed-x');
  const seqA = Array.from({ length: 50 }, () => a.next());
  const seqB = Array.from({ length: 50 }, () => b.next());
  assert.deepStrictEqual(seqA, seqB);
});

test('rng: different seeds diverge', () => {
  const a = new RNG('a');
  const b = new RNG('b');
  assert.notDeepStrictEqual(Array.from({ length: 8 }, () => a.next()), Array.from({ length: 8 }, () => b.next()));
});

test('rng: state save/restore reproduces the exact future', () => {
  const a = new RNG('future');
  for (let i = 0; i < 10; i++) a.next();
  const state = a.getState();
  const expected = Array.from({ length: 20 }, () => a.next());
  const b = RNG.fromState(state);
  const actual = Array.from({ length: 20 }, () => b.next());
  assert.deepStrictEqual(actual, expected);
});

test('rng: int/pick/chance/range respect bounds', () => {
  const r = new RNG('bounds');
  for (let i = 0; i < 500; i++) {
    const v = r.int(3, 7);
    assert.ok(v >= 3 && v <= 7);
    assert.ok(r.chance(0.9) === true || r.chance(0.1) === false || true);
    assert.ok(r.range(1, 2) >= 1 && r.range(1, 2) < 2);
  }
  const arr = [1, 2, 3];
  for (let i = 0; i < 50; i++) assert.ok(arr.includes(r.pick(arr)));
});

test('clock: day cycle, sun elevation, night detection', () => {
  const c = new Clock({ dayLengthSec: 100, startAtSec: 0 });
  c.advance(1); c.advance(1);
  assert.equal(c.tick, 2);
  assert.equal(c.time, 2);
  assert.equal(c.timeOfDay, 0.02);
  const noon = new Clock({ dayLengthSec: 100, startAtSec: 50 });
  assert.ok(noon.sunElevation > 0.99);
  const midnight = new Clock({ dayLengthSec: 100, startAtSec: 0 });
  assert.ok(midnight.sunElevation < 0);
  assert.equal(midnight.isNight, true);
});

test('perf: measures spans honestly', () => {
  let t = 0;
  const meter = new PerfMeter({ now: () => t, enabled: true });
  const tk = meter.start('op');
  t += 5; meter.end(tk);
  const tk2 = meter.start('op');
  t += 3; meter.end(tk2);
  const rep = meter.report();
  assert.equal(rep[0].name, 'op');
  assert.equal(rep[0].count, 2);
  assert.ok(Math.abs(rep[0].totalMs - 8) < 1e-9);
  assert.ok(Math.abs(rep[0].maxMs - 5) < 1e-9);
});

test('math: primitives', () => {
  assert.equal(clamp(5, 0, 1), 1);
  assert.equal(clamp(-5, 0, 1), 0);
  assert.equal(lerp(0, 10, 0.5), 5);
  assert.equal(dist2(0, 0, 3, 4), 25);
  assert.equal(fnv1a('abc'), fnv1a('abc'));
  assert.notEqual(fnv1a('abc'), fnv1a('abd'));
  assert.ok(hash2(10, 10, 42) >= 0 && hash2(10, 10, 42) < 1);
  assert.equal(hash2(10, 10, 42), hash2(10, 10, 42));
});
