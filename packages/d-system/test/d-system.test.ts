import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ladderFor, validateAll, validateLadder, capsAt, costOf } from '../src/ladders.ts';
import { resolveRequirements, deriveMinD } from '../src/requirements.ts';
import { GEN1_DOMAINS, DOMAINS } from '../src/types.ts';

test('L0 as escadas da GÊNESIS validam contra o §98.1', () => {
  assert.deepEqual(validateAll(), []);
});

test('L1 toda escada começa em D0', () => {
  for (const d of GEN1_DOMAINS) {
    const l = ladderFor(d);
    assert.equal(l.steps[0].D, 0, `${d} não começa em D0`);
  }
});

test('M2 subir de D nunca remove capacidade (monotonicidade estrutural)', () => {
  for (const d of GEN1_DOMAINS) {
    const steps = ladderFor(d).steps;
    for (let i = 1; i < steps.length; i++) {
      const prev = new Set(steps[i - 1].caps);
      for (const cap of prev) assert.ok(steps[i].caps.includes(cap), `${d}: "${cap}" sumiu em D${steps[i].D}`);
    }
  }
});

test('M3 custo é não-decrescente ao subir de D', () => {
  const region = { pixels: 1161824, entities: 20, lights: 3, volumes: 4096 };
  for (const d of GEN1_DOMAINS) {
    const steps = ladderFor(d).steps;
    for (let i = 1; i < steps.length; i++) {
      assert.ok(costOf(steps[i], region) >= costOf(steps[i - 1], region), `${d}: D${steps[i].D} mais barato que D${steps[i - 1].D}`);
    }
  }
});

test('M2 o validador REJEITA escada que perde capacidade ao subir (prova de que o teste não é decorativo)', () => {
  const broken = structuredClone(ladderFor('visual'));
  broken.steps = broken.steps.map((s, i) => (i === 2 ? { ...s, caps: ['solid_fill'] } : s));
  const codes = validateLadder(broken).map((i) => i.code);
  assert.ok(codes.includes('M2_CAPABILITY_LOST_ON_RISE'), `esperava M2_CAPABILITY_LOST_ON_RISE, veio ${codes}`);
});

test('M3 o validador REJEITA degrau mais barato que o anterior', () => {
  const broken = structuredClone(ladderFor('visual'));
  broken.steps = broken.steps.map((s, i) => (i === 3 ? { ...s, cost: { ...s.cost, perPixel: 0.000001 } } : s));
  assert.ok(validateLadder(broken).some((i) => i.code === 'M3_COST_REGRESSION'));
});

test('LADDER_DEAD_STEP degrau que não agrega nada é nomenclatura vazia (Tese §89)', () => {
  const broken = structuredClone(ladderFor('visual'));
  const dup = { ...broken.steps[2] };
  broken.steps = [...broken.steps.slice(0, 3), { ...dup, D: dup.D + 1 }];
  assert.ok(validateLadder(broken).some((i) => i.code === 'LADDER_DEAD_STEP'));
});

test('M1 todo degrau declara medidor por componente de Q', () => {
  const broken = structuredClone(ladderFor('physical'));
  broken.steps = broken.steps.map((s, i) => (i === 1 ? { ...s, quality: { ...s.quality, operators: { ...s.quality.operators, Qf: '' } } } : s));
  assert.ok(validateLadder(broken).some((i) => i.code === 'M1_NO_MEASURER'));
});

test('I8 classe de qualidade inválida é rejeitada', () => {
  const broken = structuredClone(ladderFor('temporal'));
  broken.steps = broken.steps.map((s, i) =>
    i === 2 ? { ...s, quality: { ...s.quality, class: { ...s.quality.class, Qp: 'ESPIRITUAL' as never } } } : s,
  );
  assert.ok(validateLadder(broken).some((i) => i.code === 'I8_UNCLASSIFIED_QUALITY'));
});

test('D0 de physical/temporal tem Qf zero — a tese só vale se "não simular" for uma opção real', () => {
  assert.equal(ladderFor('physical').steps[0].quality.Qf, 0);
  assert.equal(ladderFor('temporal').steps[0].quality.Qf, 0);
});

test('requisitos derivam um minD vincante, não um número chutado', () => {
  const r = resolveRequirements('visual', { domain: 'visual', requires: ['per_entity_detail'] });
  assert.equal(r.minD, 3);
  const r2 = resolveRequirements('visual', { domain: 'visual', requires: ['participating_media'] });
  assert.equal(r2.minD, 5);
});

test('requisito de reconstrução eleva o minD (Qi não é decorativo)', () => {
  const a = resolveRequirements('physical', { domain: 'physical' });
  const b = resolveRequirements('physical', { domain: 'physical', mustRecover: ['joint_state'] });
  assert.equal(a.minD, 0);
  assert.ok(b.minD >= 4, `joint_state deve exigir D≥4, veio ${b.minD}`);
});

test('requisito insatisfaível vira erro nomeado, não degradação', () => {
  assert.throws(
    () => resolveRequirements('visual', { domain: 'visual', requires: ['telepatia'] }),
    /REQUIREMENT_UNSATISFIABLE/,
  );
});

test('domínio sem escada é slot do contrato, não capacidade falsa', () => {
  assert.throws(() => resolveRequirements('social', { domain: 'social' }), /LADDER_NOT_DEFINED/);
  assert.equal(capsAt('social', 2).size, 0);
});

test('deriveMinD com requisito vazio é D0', () => {
  assert.equal(deriveMinD(ladderFor('visual'), []), 0);
});

test('override humano de piso fica marcado (auditoria de decisão)', () => {
  const r = resolveRequirements('visual', { domain: 'visual', requires: ['solid_fill'], floors: { QpMin: 0.4 } });
  assert.equal(r.QpMin, 0.4);
  assert.equal(r.overridden, true);
});

test('NENHUM domínio da lista canônica está ausente do registro', () => {
  for (const d of DOMAINS) assert.equal(ladderFor(d).domain, d);
  assert.throws(() => ladderFor('quântico' as never), /LADDER_UNKNOWN/);
});

test('I3 as escadas são estritamente crescentes em custo E em qualidade, degrau a degrau', () => {
  for (const dom of ['visual', 'physical', 'temporal']) {
    const steps = ladderFor(dom).steps;
    const zero = { pixels: 4096, entities: 1000, lights: 8, volumes: 10000 };
    for (let i = 1; i < steps.length; i++) {
      assert.ok(costOf(steps[i], zero) > costOf(steps[i - 1], zero), `${dom} D${steps[i].D} não custa mais que D${steps[i - 1].D}`);
      assert.ok(steps[i].quality.Qf > steps[i - 1].quality.Qf, `${dom} D${steps[i].D} não agrega função`);
      assert.ok(steps[i].quality.Qi >= steps[i - 1].quality.Qi, `${dom} D${steps[i].D} perde reconstruibilidade`);
    }
    // todo degrau intermediário tem de poder ser o mínimo-vinculante de algum piso
    for (let i = 0; i < steps.length; i++) {
      const q = steps[i].quality;
      const floors = { QpMin: q.Qp, QfMin: i === 0 ? 0 : steps[i - 1].quality.Qf + 1e-9, QiMin: 0 };
      const minD = deriveMinDFromFloors(steps, floors);
      assert.equal(minD, i, `${dom}: nenhum piso vincula exatamente D${i}`);
    }
  }
});

function deriveMinDFromFloors(steps, floors) {
  const hit = steps.find((s) => s.quality.Qp >= floors.QpMin && s.quality.Qf >= floors.QfMin && s.quality.Qi >= floors.QiMin);
  return hit ? hit.D : Infinity;
}
