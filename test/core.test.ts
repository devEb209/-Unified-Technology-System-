import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventBus, Logger, PerfMeter, Rng, SimClock, clamp, damp, dist2d, lerp, newId } from '../src/core/index.ts';

test('newId: únicos e prefixados', () => {
  const a = newId('ent');
  const b = newId('ent');
  assert.notEqual(a, b);
  assert.ok(a.startsWith('ent_'));
  const set = new Set(Array.from({ length: 5000 }, () => newId()));
  assert.equal(set.size, 5000);
});

test('Rng: determinístico por seed', () => {
  const r1 = new Rng(1234);
  const r2 = new Rng(1234);
  const s1 = Array.from({ length: 100 }, () => r1.next());
  const s2 = Array.from({ length: 100 }, () => r2.next());
  assert.deepEqual(s1, s2);
  const r3 = new Rng(999);
  const s3 = Array.from({ length: 100 }, () => r3.next());
  assert.notDeepEqual(s1, s3);
  // intervalo
  for (let i = 0; i < 200; i++) {
    const v = new Rng(7).next();
    assert.ok(v >= 0 && v < 1);
  }
  const r = new Rng(5);
  for (let i = 0; i < 200; i++) {
    const v = r.range(2, 3);
    assert.ok(v >= 2 && v < 3);
  }
});

test('SimClock: avança tempo e contagens', () => {
  const c = new SimClock();
  c.tick(0.1);
  c.tick(0.1);
  c.renderFrame();
  assert.equal(c.time, 0.2);
  assert.equal(c.tickCount, 2);
  assert.equal(c.frame, 1);
  c.reset();
  assert.equal(c.time, 0);
});

test('EventBus: prioridade, off, isolamento', () => {
  const bus = new EventBus();
  const seen: string[] = [];
  const off = bus.on('x', () => seen.push('low'), 0);
  bus.on('x', () => seen.push('high'), 10);
  bus.emit('x', null);
  assert.deepEqual(seen, ['high', 'low']);
  off();
  bus.emit('x', null);
  assert.deepEqual(seen, ['high', 'low', 'high']);
  assert.equal(bus.listenerCount('y'), 0);
});

test('Logger: níveis, escopo, sink', () => {
  const entries: string[] = [];
  Logger.sink = (e) => entries.push(`${e.level}:${e.scope}:${e.msg}`);
  Logger.level = 'debug';
  const log = new Logger('uts').child('rrw');
  log.info('oi');
  log.warn('ah');
  Logger.sink = () => {};
  assert.ok(entries.includes('info:uts:rrw:oi'));
  assert.ok(entries.includes('warn:uts:rrw:ah'));
  Logger.level = 'info';
});

test('PerfMeter: mede e agrega', () => {
  const m = new PerfMeter();
  for (let i = 0; i < 10; i++) m.measure('work', () => String.fromCharCode(65 + i));
  const e = m.get('work');
  assert.ok(e);
  assert.equal(e.count, 10);
  assert.ok(e.totalMs >= 0);
  assert.ok(m.totalMs() >= 0);
  m.reset();
  assert.equal(m.get('work'), undefined);
});

test('utils: clamp/lerp/damp/dist2d', () => {
  assert.equal(clamp(5, 0, 1), 1);
  assert.equal(clamp(-1, 0, 1), 0);
  assert.equal(lerp(0, 10, 0.5), 5);
  assert.ok(Math.abs(damp(0, 10, 5, 0.1) - lerp(0, 10, 1 - Math.exp(-0.5))) < 1e-9);
  assert.ok(Math.abs(dist2d(0, 0, 3, 4) - 5) < 1e-12);
});
