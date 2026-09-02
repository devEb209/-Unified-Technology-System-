import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDFrame, parseDFrame, serializeDFrame, registerMigration, DFrameError, type DFrameInit } from '../src/dframe.ts';
import { SCHEMA_VERSION } from '../src/schema.ts';

function base(over: Partial<DFrameInit> = {}): DFrameInit {
  return {
    regionId: 'r:12,-4',
    domain: 'visual',
    DCurrent: 2,
    DTarget: 3,
    Priority: 0.5,
    CostBudget: 120,
    QualityRequired: {
      QpMin: 0.9,
      QfMin: 0.5,
      QiMin: 0.5,
      minD: 0,
      maxD: 5,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      mode: 'ESTIMATE',
      overridden: false,
      reason: 'teste',
    },
    Representation: { biome_code: 'cerrado', heightfield_ref: 'hf:12,-4', material_class: 'soil_dry' },
    RecoveryRequired: ['biome_code', 'material_class_code'],
    OmittedFacts: ['per_texel_detail'],
    RecoverySet: ['biome_code', 'height_samples', 'material_class_code'],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: 2 },
    ...over,
  } as DFrameInit;
}

/**
 * Uma violação do contrato DEVE chegar como DFrameError com code — nunca como
 * TypeError/undefined, porque erro anônimo é o que vira "degradação silenciosa"
 * a um frame de distância.
 */
const codeOf = (fn: () => unknown): string => {
  try {
    fn();
  } catch (e) {
    if (!(e instanceof DFrameError)) throw new Error(`falha deveria ser DFrameError, foi ${(e as Error).name}: ${(e as Error).message}`);
    return e.code;
  }
  throw new Error('esperava falha, não falhou');
};

test('DF0 frame válido constrói, serializa e volta idêntico', () => {
  const f = makeDFrame(base());
  const back = parseDFrame(serializeDFrame(f));
  assert.deepEqual(JSON.parse(JSON.stringify(back)), JSON.parse(JSON.stringify({ ...f, entities: undefined, criticalEntities: undefined, Predicted: undefined })));
});

test('I1 vertex em qualquer lugar do frame é rejeitado por tipo', () => {
  const withVerts = base() as unknown as Record<string, unknown>;
  (withVerts as { Representation: Record<string, unknown> }).Representation = {
    biome_code: 'cerrado',
    vertices: new Float32Array([0, 0, 0, 1, 1, 1]),
  };
  // o varredor estrutural vê o Float32Array antes da allowlist: diagnóstico mais preciso
  assert.equal(codeOf(() => makeDFrame(withVerts as never)), 'FRAME_FORBIDDEN_KEY');
});

test('I1 chave de geometria proibida mesmo com valor inocente', () => {
  assert.equal(codeOf(() => makeDFrame({ ...base(), Representation: { mesh: 'a1b2' } } as never)), 'FRAME_FORBIDDEN_KEY');
  assert.equal(codeOf(() => makeDFrame({ ...base(), entities: [{ id: 'e1', delta: { draw_call: 3 } }] } as never)), 'FRAME_FORBIDDEN_KEY');
  // um payload fora da allowlist, sem chave proibida, é pego pela allowlist
  assert.equal(codeOf(() => makeDFrame({ ...base(), entities: [{ id: 'e1', delta: { segredo: 3 } }] } as never)), 'REPR_KEY_NOT_ALLOWED');
});

test('I1 buffer binário aninhado é rejeitado na serialização também', () => {
  const f = makeDFrame(base());
  const tampered = JSON.parse(serializeDFrame(f)) as Record<string, unknown>;
  tampered.sidecar = { data: new Uint8Array([1, 2, 3]) };
  assert.equal(codeOf(() => parseDFrame(tampered)), 'FRAME_CONTAINS_GEOMETRY');
});

test('I1 chave de geometria em nível raiz é pega pelo varredor', () => {
  const raw = JSON.parse(serializeDFrame(makeDFrame(base()))) as Record<string, unknown>;
  raw.shader_bytecode = 'Spirv...';
  assert.equal(codeOf(() => parseDFrame(raw)), 'FRAME_FORBIDDEN_KEY');
});

test('frame é imutável: o executor não pode ajustar o próprio D', () => {
  const f = makeDFrame(base());
  assert.throws(() => {
    (f as { DTarget: number }).DTarget = 0;
  }, TypeError);
  assert.throws(() => {
    (f.Representation as Record<string, unknown>).biome_code = 'asfalto';
  }, TypeError);
});

test('I8 requisito sem classe declarada é rejeitado', () => {
  const q = { ...base().QualityRequired, class: { Qp: 'FEELING', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' } };
  assert.equal(codeOf(() => makeDFrame({ ...base(), QualityRequired: q })), 'I8_UNCLASSIFIED_QUALITY');
});

test('contrato §2.4 requisito sem modo é rejeitado', () => {
  // `base(over)` substitui o objeto inteiro, então o override precisa partir do objeto da base.
  // campo *ausente* é requisito incompleto; campo explicitamente null é outro erro nomeado.
  const q = base().QualityRequired as Record<string, unknown>;
  delete q.mode;
  assert.equal(codeOf(() => makeDFrame(base({ QualityRequired: q }))), 'Q_MODE_MISSING');
  // classe ausente / objeto parcial também não pode virar TypeError anônimo
  assert.throws(() => makeDFrame(base({ QualityRequired: { mode: 'ESTIMATE' } as never })), DFrameError);
  // ledger ausente é requisito incompleto, não vazio
  assert.throws(() => makeDFrame({ ...base(), RecoveryRequired: undefined } as never), DFrameError);
  assert.equal(codeOf(() => makeDFrame(base({ QualityRequired: { ...base().QualityRequired, mode: null as never } }))), 'FRAME_FIELD_NULL');
});

test('piso satisfeito por D sem capacidade é impossível (minD vincante)', () => {
  const q = { ...base().QualityRequired, minD: 4 };
  assert.equal(codeOf(() => makeDFrame({ ...base(), DCurrent: 2, QualityRequired: q })), 'MIN_D_VIOLATED');
});

test('DTarget acima da escada é erro, não clamp silencioso', () => {
  assert.equal(codeOf(() => makeDFrame({ ...base(), DTarget: 9 })), 'MAX_D_EXCEEDED');
});

test('Q fora de [0,1] é erro', () => {
  const q = { ...base().QualityRequired, QpMin: 1.2 };
  assert.equal(codeOf(() => makeDFrame({ ...base(), QualityRequired: q })), 'Q_OUT_OF_RANGE');
});

test('orçamento não-finito é bloqueado (NaN materializa lixo)', () => {
  assert.equal(codeOf(() => makeDFrame({ ...base(), CostBudget: Number.NaN })), 'BUDGET_INVALID');
  const repr = { ...base().Representation, light_sample_rate: Number.NaN };
  assert.equal(codeOf(() => makeDFrame({ ...base(), Representation: repr })), 'REPR_VALUE_NOT_FINITE');
});

test('Qi: omissão exigida pelo DTarget vira erro nomeado', () => {
  assert.equal(
    codeOf(() => makeDFrame({ ...base(), RecoveryRequired: ['biome_code', 'entity_visual_state'] })),
    'QI_UNRECOVERABLE_OMISSION',
  );
});

test('I7 schemaVersion antigo sem migração falha explicitamente', () => {
  const raw = JSON.parse(serializeDFrame(makeDFrame(base()))) as Record<string, unknown>;
  raw.schemaVersion = -7; // versão sem migração registrada, para não depender de ordem de teste
  assert.equal(codeOf(() => parseDFrame(raw)), 'FRAME_VERSION_UNSUPPORTED');
});

test('I7 schemaVersion do futuro falha em vez de chutar', () => {
  const raw = JSON.parse(serializeDFrame(makeDFrame(base()))) as Record<string, unknown>;
  raw.schemaVersion = SCHEMA_VERSION + 5;
  assert.equal(codeOf(() => parseDFrame(raw)), 'FRAME_VERSION_FROM_FUTURE');
});

test('I7 migração passo único leva o frame antigo a materializar corretamente', () => {
  const raw = { ...JSON.parse(serializeDFrame(makeDFrame(base()))), RecoveryRequired: undefined } as Record<string, unknown>;
  raw.schemaVersion = 0;
  assert.throws(() => parseDFrame(raw), /FRAME_VERSION_UNSUPPORTED/);
  registerMigration({
    from: 0,
    to: 1,
    apply: (o) => ({ ...o, schemaVersion: 1, RecoveryRequired: ['biome_code', 'material_class_code'] }),
  });
  const migrated = parseDFrame(raw);
  assert.equal(migrated.schemaVersion, SCHEMA_VERSION);
  assert.deepEqual([...migrated.RecoveryRequired], ['biome_code', 'material_class_code']);
});

test('JSON malformado não vira mundo vazio', () => {
  assert.equal(codeOf(() => parseDFrame('{')), 'FRAME_MALFORMED');
  assert.equal(codeOf(() => parseDFrame(null)), 'FRAME_MALFORMED');
});

test('thermal crítico não permite expansão automática (Tese §69, recursos são contexto)', () => {
  assert.equal(
    codeOf(() => makeDFrame(base(), { resources: { device: { id: 'a70', width: 720, height: 1612, maxInternalScale: 1, frameBudget: 100, appMemoryBytes: 1e9 }, thermal: 'critical', batterySaver: false, headroom: 0.1 } })),
    'THERMAL_EXPANSION_BLOCKED',
  );
});
