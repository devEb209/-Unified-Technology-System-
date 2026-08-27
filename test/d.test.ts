import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TeseDosD, createDefaultTese } from '../src/d/index.ts';

test('D: camadas possuem função operacional completa (9 atributos)', () => {
  const t = createDefaultTese();
  for (const l of t.ordered()) {
    assert.ok(l.purpose.length > 5, `${l.id} sem objetivo`);
    assert.ok(l.solves.length > 5, `${l.id} sem problema resolvido`);
    assert.ok(l.representation.length > 5, `${l.id} sem representação`);
    assert.ok(l.data.length > 5, `${l.id} sem dados`);
    assert.ok(l.affected.length > 0, `${l.id} sem sistemas afetados`);
    assert.ok(l.integration.length > 0, `${l.id} sem integração`);
    assert.ok(l.cost.length > 5, `${l.id} sem custo`);
    assert.ok(l.optimization.length > 5, `${l.id} sem otimização`);
    assert.ok(l.observable.length > 5, `${l.id} sem resultado observável`);
    assert.ok(l.provides.length > 0, `${l.id} sem capacidades`);
  }
});

test('D: valores podem ser fracionários (D.x.25 etc.)', () => {
  const t = createDefaultTese();
  t.define({
    id: 'D-1.25',
    value: 1.25,
    name: 'Teste fracionário',
    purpose: 'x',
    solves: 'x',
    representation: 'x',
    data: 'x',
    affected: ['x'],
    integration: ['x'],
    cost: 'x',
    optimization: 'x',
    observable: 'x',
    provides: ['custom'],
    fallbackId: 'D-1',
  });
  const vals = t.ordered().map((l) => l.value);
  assert.ok(vals.includes(1.25));
  // ordenação respeita o fracionário
  const i1 = t.ordered().findIndex((l) => l.id === 'D-1');
  const i125 = t.ordered().findIndex((l) => l.id === 'D-1.25');
  const i2 = t.ordered().findIndex((l) => l.id === 'D-2');
  assert.ok(i1 < i125 && i125 < i2);
  assert.ok(t.byCapability('custom').length === 1);
});

test('D: D-MAXIMO é dinâmico (nível mais avançado atualmente definido)', () => {
  const t = createDefaultTese();
  assert.equal(t.max().id, 'D-O15'); // maior valor registrado (15)
  assert.equal(t.bottom().id, 'D-0');
  // Ao registrar um D mais avançado, D-MAXIMO acompanha — não é número fixo antigo.
  t.define({
    id: 'D-16',
    value: 16,
    name: 'Novo nível',
    purpose: 'x',
    solves: 'x',
    representation: 'x',
    data: 'x',
    affected: ['x'],
    integration: ['x'],
    cost: 'x',
    optimization: 'x',
    observable: 'x',
    provides: ['new'],
  });
  assert.equal(t.max().id, 'D-16');
});

test('D: resolução — pedido vs concedido (downgrade com floor)', () => {
  const t = createDefaultTese();
  const r1 = t.resolve({ requestedValue: 4, grantedValue: 4 });
  assert.deepEqual(r1.layers.map((l) => l.id).filter((id) => id !== 'D-O15'), ['D-0', 'D-1', 'D-2', 'D-3', 'D-4']);
  assert.equal(r1.downgradedFrom, null);
  // D-O15 concede só até D-1 (pressão extrema): floor = estado semântico preservado
  const r2 = t.resolve({ requestedValue: 4, grantedValue: 1 });
  assert.deepEqual(r2.layers.map((l) => l.id), ['D-0', 'D-1']);
  assert.ok(r2.downgradedFrom);
  // floor: nunca abaixo do D-0
  const r3 = t.resolve({ requestedValue: 0, grantedValue: -5 });
  assert.deepEqual(r3.layers.map((l) => l.id), ['D-0']);
  // pedido acima do D-MAXIMO é clamped
  const r4 = t.resolve({ requestedValue: 999, grantedValue: 999 });
  assert.ok(r4.value <= t.max().value);
});

test('D: valueForDetail mapeia materialização RRW (0..1) para D', () => {
  const t = createDefaultTese();
  const d0 = t.valueForDetail(0);
  const d1 = t.valueForDetail(1);
  const dMid = t.valueForDetail(0.5);
  assert.equal(d0, t.get('D-1')?.value); // abstrato → até estado semântico
  assert.equal(d1, t.max().value); // material → D-MAXIMO
  assert.ok(dMid > d0 && dMid < d1);
});

test('D: fallback encadeia para baixo', () => {
  const t = createDefaultTese();
  assert.equal(t.fallback('D-4')?.id, 'D-3');
  assert.equal(t.fallback('D-3')?.id, 'D-2');
  assert.equal(t.fallback('D-1')?.id, 'D-0');
  assert.equal(t.fallback('D-0'), null);
  assert.equal(t.fallback('D-O15'), null);
});

test('D: extensibilidade — novo D de realidade entra em runtime', () => {
  const t = new TeseDosD();
  t.define({
    id: 'D-5',
    value: 5,
    name: 'Exemplo: Consciência Fenomenal',
    purpose: 'x',
    solves: 'x',
    representation: 'x',
    data: 'x',
    affected: ['ai'],
    integration: ['ai.memory'],
    cost: 'x',
    optimization: 'x',
    observable: 'x',
    provides: ['consciousness'],
  });
  assert.ok(t.get('D-5'));
  assert.equal(t.max().id, 'D-5');
  const desc = t.describe();
  assert.ok(desc.includes('D-MAX'));
  assert.ok(desc.includes('D-5'));
});
