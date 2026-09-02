import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDFrame, type DFrame } from '../../dframe/src/dframe.ts';
import type { Domain } from '../../d-system/src/types.ts';
import { createWorld, putFrame, updateLife, advance, loadWorld, serializeWorld, tickCost, WorldError, cellKey } from '../src/world.ts';

function frame(domain: Domain, D: number, x: number, y: number): DFrame {
  return makeDFrame({
    regionId: `r:${x},${y}`,
    domain,
    DCurrent: D,
    DTarget: D,
    Priority: 0.5,
    CostBudget: 10,
    Representation: { biome_code: 'restinga' },
    QualityRequired: {
      QpMin: 0, QfMin: 0, QiMin: 0, minD: 0, maxD: 5,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      mode: 'ESTIMATE', overridden: false, reason: 'teste',
    },
    OmittedFacts: [],
    RecoverySet: ['biome_code'],
    RecoveryRequired: [],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: D },
  });
}

const world = () => putFrame(putFrame(createWorld({ cellSize: 32, w: 4, h: 4 }), [1, 2], frame('visual', 3, 1, 2)), [1, 2], frame('physical', 2, 1, 2));

test('W1 putFrame é imutável: o estado antigo continua intacto (persistência não é mutable state)', () => {
  const w0 = createWorld({ cellSize: 32, w: 4, h: 4 });
  const w1 = putFrame(w0, [1, 2], frame('visual', 3, 1, 2));
  assert.equal(Object.keys(w0.records).length, 0);
  assert.equal(Object.keys(w1.records).length, 1);
  assert.equal(w1.records[cellKey(1, 2)].frames.visual.DCurrent, 3);
});

test('W2 célula fora da grade e região ≠ célula são erros nomeados', () => {
  assert.throws(() => putFrame(world(), [9, 9], frame('visual', 1, 9, 9)), (e: unknown) => (e as WorldError).code === 'CELL_OUT_OF_BOUNDS');
  const f = makeDFrame({ ...frame('visual', 1, 0, 0), regionId: 'r:3,3' });
  assert.throws(() => putFrame(world(), [0, 0], f), (e: unknown) => (e as WorldError).code === 'CELL_MISMATCH');
});

test('W3 frame inválido não entra no mundo (a validação é na porta, não no uso)', () => {
  assert.throws(() => makeDFrame({ ...frame('visual', 1, 0, 0), DCurrent: -1 }), (e: unknown) => typeof (e as { code?: string }).code === 'string');
});

test('W4 round-trip preserva D, histerese e histórico', () => {
  let w = world();
  w = putFrame(w, [1, 2], frame('visual', 4, 1, 2));
  const back = loadWorld(serializeWorld(w));
  assert.equal(back.records[cellKey(1, 2)].frames.visual.DCurrent, 4);
  assert.deepEqual(back.records[cellKey(1, 2)].dHistory.visual, [3, 4], 'o histórico de D sobrevive — é o que a histerese lê entre sessões');
  assert.equal(back.grid.cellSize, w.grid.cellSize);
});

test('W5 snapshot sem schemaVersion é ERRO, nunca mundo vazio (UTS l.2797-2818)', () => {
  const bare = JSON.parse(serializeWorld(world())) as Record<string, unknown>;
  delete bare.schemaVersion;
  assert.throws(() => loadWorld(JSON.stringify(bare)), (e: unknown) => (e as WorldError).code === 'SNAPSHOT_SCHEMA_MISSING');
  assert.throws(() => loadWorld(JSON.stringify({ ...bare, schemaVersion: 99 })), (e: unknown) => (e as WorldError).code === 'SNAPSHOT_SCHEMA_VERSION');
});

test('W6 vida adormecida preserva população e memória; tick não zera nada (I10)', () => {
  let w = updateLife(world(), [1, 2], { population: 4800, roles: { pescador: 900, guarda: 300 }, memory: ['incendio_no_molhe', 'divida_pescador_guarda'] });
  for (let i = 0; i < 1000; i++) w = advance(w);
  const life = w.records[cellKey(1, 2)].life;
  assert.equal(life.population, 4800);
  assert.deepEqual(life.roles, { pescador: 900, guarda: 300 });
  assert.deepEqual(life.memory, ['incendio_no_molhe', 'divida_pescador_guarda']);
});

test('W7 custo do tick é proporcional a células acordadas, não a entidades (o erro dos 216 ms/tick)', () => {
  let w = world();
  w = updateLife(w, [1, 2], { population: 4800 });
  for (let x = 0; x < 4; x++) for (let y = 0; y < 4; y++) w = putFrame(w, [x, y], frame('physical', 0, x, y));
  w = putFrame(w, [1, 2], frame('visual', 3, 1, 2));
  const cost = tickCost(w, { dormantHz: 0.1, now: 0 });
  assert.equal(cost.entitiesTouched, 0, 'nenhuma entidade é tocada por tick de célula dormente');
  assert.ok(cost.cellsDormant >= 15, `dormindo: ${cost.cellsDormant}`);
  const later = tickCost(w, { dormantHz: 0.1, now: 100 });
  assert.ok(later.cellsUpdated > cost.cellsUpdated, 'depois do período, agregados acordam');
});

test('W8 criar vida sem região é rejeitado: mundo não é cena', () => {
  assert.throws(() => updateLife(createWorld({ cellSize: 32, w: 4, h: 4 }), [0, 0], { population: 1 }), (e: unknown) => (e as WorldError).code === 'NO_RECORD');
});

test('W9 grade com célula menor que 4 unidades é recusada: célula ≠ entidade', () => {
  assert.throws(() => createWorld({ cellSize: 1, w: 8, h: 8 }), (e: unknown) => (e as WorldError).code === 'GRID_CELL_SIZE');
});

test('W10 o histórico de D é limitado (persistência não cresce para sempre)', () => {
  let w = world();
  for (let i = 0; i < 40; i++) w = putFrame(w, [1, 2], frame('visual', i % 6, 1, 2));
  assert.equal(w.records[cellKey(1, 2)].dHistory.visual.length, 8);
});
