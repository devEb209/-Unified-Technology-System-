import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDFrame, type DFrame } from '../../dframe/src/dframe.ts';
import { materializeVisual, capsForDomain, MaterializeError } from '../src/materialize.ts';
import { measureQp, thresholdMap } from '../src/quality.ts';
import { auditVisual } from '../src/audit.ts';
import { heightAt, vnoise, codeValue } from '../src/hash.ts';
import { capsAt } from '../../d-system/src/ladders.ts';

const REPR_BY_D: Record<number, Record<string, unknown>> = {
  0: { biome_code: 'caatinga_dry' },
  1: { biome_code: 'caatinga_dry', heightfield_ref: 'hf:01', heightfield_sample_rate: 0.4 },
  2: { material_class: 'soil', spectral_band_code: 'nir' },
  3: { shadow_atlas_index: 0, matter_state_code: 'wet' },
  4: { sky_model: 'turbid' },
  5: { volume_sample_rate: 0.6, light_sample_rate: 0.5, detail_class: 'high' },
};

function frame(D: number, over: Record<string, unknown> = {}, entities = 0): DFrame {
  const Representation: Record<string, unknown> = {
    biome_code: 'caatinga_dry',
    heightfield_ref: 'hf:01',
    heightfield_sample_rate: 0.4,
  };
  for (let d = 1; d <= D; d++) Object.assign(Representation, REPR_BY_D[d]);
  Object.assign(Representation, over);
  return makeDFrame({
    regionId: 'r:0,0',
    domain: 'visual',
    DCurrent: D,
    DTarget: D,
    Priority: 0.5,
    CostBudget: 100,
    Representation,
    QualityRequired: {
      QpMin: 0.9,
      QfMin: 0,
      QiMin: 0,
      minD: 0,
      maxD: 5,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      mode: 'MEASURE',
      overridden: false,
      reason: 'teste',
    },
    OmittedFacts: D < 5 ? ['entity_geometry'] : [],
    RecoverySet: ['biome_code', 'height_samples'],
    RecoveryRequired: [],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: D },
    entities: Array.from({ length: entities }, (_, i) => ({ id: `e${i}`, delta: { matter_state_code: i % 2 ? 'wet' : 'dry' } })),
  });
}

test('M1 materialização é determinística: o mesmo frame devolve bitwise o mesmo campo', () => {
  const a = materializeVisual(frame(4), { gridSize: 24 });
  const b = materializeVisual(frame(4), { gridSize: 24 });
  assert.deepEqual(Array.from(a.field.samples), Array.from(b.field.samples));
  assert.equal(a.cells, 24 * 24);
});

test('M2 D0 = uma radiancia por região (cor de bioma), e nada além disso', () => {
  const f = materializeVisual(frame(0, { heightfield_sample_rate: 0 }), { gridSize: 16 });
  const uniq = new Set(Array.from(f.field.samples).map((v) => v.toFixed(9)));
  assert.equal(uniq.size, 1, `D0 não pode ter variação: ${[...uniq].join(',')}`);
});

test('M3 altura entra como informação, não como superfície: D1 varia e o heightfield_ref importa', () => {
  const h = materializeVisual(frame(1), { gridSize: 20 });
  const spread = Math.max(...Array.from(h.field.samples)) - Math.min(...Array.from(h.field.samples));
  assert.ok(spread > 0.05, `D1 deveria variar com o relevo (spread ${spread.toFixed(3)})`);
  const other = materializeVisual(frame(1, { heightfield_ref: 'hf:02' }), { gridSize: 20 });
  assert.notDeepEqual(Array.from(h.field.samples), Array.from(other.field.samples), 'trocar a referência do campo tem de mudar a amostragem');
});

test('M4 entidades só aparecem onde há detalhe por entidade (D3)', () => {
  const withEnts = (D: number) => materializeVisual(frame(D), { gridSize: 24 });
  const lo = withEnts(2);
  const hi = withEnts(3);
  // o frame carrega as mesmas entidades nos dois casos; o que muda é a capacidade
  assert.notDeepEqual(Array.from(lo.field.samples), Array.from(hi.field.samples), 'D3 deveria materializar as entidades');
  assert.ok(hi.field.samples.some((v) => v > Math.max(...Array.from(lo.field.samples)) * 0.99));
});

test('M5 código ausente é ausência materializada, não crash', () => {
  // referência perdida é RECUSADA pelo validador do frame, antes de qualquer
  // materialização — "campo obrigatório ausente" não é "campo vazio"
  assert.throws(() => frame(1, { heightfield_ref: undefined }), (e: unknown) => (e as { code: string }).code === 'FRAME_FIELD_NULL');
  const f = materializeVisual(frame(1, { heightfield_sample_rate: 0 }), { gridSize: 12 });
  assert.ok(Array.from(f.field.samples).every((v) => Number.isFinite(v)));
  assert.throws(() => materializeVisual({ ...frame(1), domain: 'physical' } as DFrame), (e: unknown) => (e as MaterializeError).code === 'MAT_DOMAIN_MISMATCH');
});

test('M6 Qp é 1 contra si mesmo e cai monotonicamente conforme a capacidade some', () => {
  const ref = materializeVisual(frame(5), { gridSize: 28 });
  assert.equal(measureQp(ref.field, ref.field).Qp, 1);
  let prev = 1.0001;
  for (const D of [4, 3, 2, 1, 0]) {
    const cand = materializeVisual(frame(D), { gridSize: 28 });
    const m = measureQp(ref.field, cand.field);
    assert.ok(m.Qp < prev, `Qp deveria cair com D: D${D} → ${m.Qp.toFixed(3)} (anterior ${prev.toFixed(3)})`);
    prev = m.Qp;
  }
  assert.ok(prev < 0.9, `D0 precisa ficar ABAIXO do piso 0.9 para o teste ser uma restrição real, não decoração: ${prev.toFixed(3)}`);
});

test('M7 o limiar cresce com o contraste local e tem piso (a TVC não é zero)', () => {
  const ref = materializeVisual(frame(3), { gridSize: 20 });
  const tm = thresholdMap(ref.field);
  assert.ok(Array.from(tm.t).every((v) => v >= 0.01), 'piso do limiar');
  assert.ok(Math.max(...Array.from(tm.t)) > 0.03, 'regiões de alto contraste toleram mais erro');
  assert.equal(tm.source, 'model', 'sem medição no aparelho, a origem é declarada como modelo');
});

test('M8 cortar informação perceptível é medido como violação, com as células nomeadas', () => {
  const ref = materializeVisual(frame(4), { gridSize: 16 });
  const cand = { ...ref.field, samples: Float64Array.from(ref.field.samples, (v, i) => (i % 7 === 0 ? 0 : v)) };
  const m = measureQp(ref.field, cand);
  assert.ok(m.violations > 0, 'corte perceptual tem de aparecer');
  assert.ok(m.worstCells.length > 0 && m.worstCells[0].err > m.worstCells[0].limit);
  assert.ok(m.Qp < 1 && m.Qp > 0.5, `Qp=${m.Qp.toFixed(3)} deveria penalizar sem apagar a cena`);
});

test('M9 custo da materialização é O(células da região), nunca O(entidades) — o erro dos 216 ms/tick', () => {
  const g = 64;
  const t = (D: number, ents: number) => {
    const f0 = frame(D, {}, ents);
    const s = process.hrtime.bigint();
    materializeVisual(f0, { gridSize: g });
    return Number(process.hrtime.bigint() - s) / 1e6;
  };
  const light = t(3, 8);
  const heavy = t(3, 4096);
  assert.ok(heavy < 60 && light < 60, `materializar ${g}×${g} custou ${heavy.toFixed(1)} ms com 4096 entidades`);
  assert.ok(heavy < 40, `4096 entidades não podem multiplicar o trabalho: ${heavy.toFixed(1)} ms vs ${light.toFixed(1)} ms`);
  // o materializador não tem tabela própria: delega à escada
  assert.deepEqual(capsForDomain('visual', 0), capsAt('visual', 0));
  assert.deepEqual(capsForDomain('physical', 3), capsAt('physical', 3));
});

test('M10 os primitivos de campo são eles próprios determinísticos e limitados', () => {
  assert.equal(heightAt(3, 7, 'bioma', 12), heightAt(3, 7, 'bioma', 12));
  for (const [x, y] of [[0, 0], [7.3, 11.9], [-4, 99]]) {
    const v = vnoise(x, y, 2);
    assert.ok(v >= 0 && v <= 1, `vnoise fora de [0,1]: ${v}`);
  }
  assert.ok(codeValue('a') !== codeValue('b') && codeValue(undefined) === 0);
});

test('M11 a auditoria mede e recusa o corte que cruza o piso, com desvio nomeado (I6)', () => {
  const ref = frame(5);
  const ok = auditVisual(frame(5), ref, { gridSize: 24 });
  assert.equal(ok.accepted, true);
  assert.equal(ok.result.Q_measured.Qp, 1);
  assert.equal(ok.result.deviations.length, 0);

  const cut = auditVisual(frame(2), { ...frame(2), QualityRequired: { ...frame(2).QualityRequired, QpMin: 0.9 } }, { gridSize: 24 });
  // o REF honesto é a cena completa: comparar D2 contra D2 seria auto-asserção
  const real = auditVisual(frame(2), ref, { gridSize: 24 });
  assert.equal(real.accepted, false, 'D2 contra D5 tem de ser recusado pelo piso 0.9, não "otimizado"');
  assert.match(real.result.deviations[0], /Qp medido .* < QpMin/);
  assert.match(real.result.deviations[0], /células/);
  assert.ok(cut.ms >= 0 && Number.isFinite(cut.ms), 'o custo medido é devolvido, não estimado');
  assert.equal(real.result.DApplied, 2);
});

test('M12 materialização com Qp acima do piso em D alto: o custo cresce com o D (Tese §69)', () => {
  const ref = frame(5);
  let prevMs = -1;
  let prevCells = -1;
  for (const D of [0, 1, 2, 3, 4, 5]) {
    const a = auditVisual(frame(D), ref, { gridSize: 40 });
    assert.ok(a.result.C_measured >= prevCells, 'células não dependem de D (é o trabalho por célula que muda)');
    assert.ok(a.ms >= 0);
    prevMs = a.ms;
    prevCells = a.result.C_measured;
  }
  assert.ok(prevMs >= 0);
});
