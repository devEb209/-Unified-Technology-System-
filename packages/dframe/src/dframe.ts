import type { Domain } from '../../d-system/src/types.ts';
import {
  SCHEMA_VERSION,
  ENGINE_VERSION,
  REPRESENTATION_KEY_TYPES,
  FORBIDDEN_KEYS,
  type ResourceContext,
} from './schema.ts';
import type { QMode } from '../../d-system/src/types.ts';

/** Estado de histerese por (região, domínio) — Tese §82, contrato §1.3. */
export interface HysteresisState {
  h: number;
  lastChangeTick: number;
  lastQ: number;
  lastD: number;
}

export interface QualityRequired {
  QpMin: number;
  QfMin: number;
  QiMin: number;
  /** Menor D permitido pelo requisito de capacidade. Vincante (não dedutível dos pisos). */
  minD: number;
  maxD: number;
  /** classe por componente — I8 */
  class: { Qp: string; Qf: string; Qi: string };
  /** ESTIMATE no caminho quente, MEASURE na auditoria — contrato §2.4. */
  mode: QMode;
  overridden: boolean;
  reason: string;
}

export interface Predicted {
  /** D esperado em um horizonte (Tese §83/§84). */
  dExpected: number;
  horizon: number;
  /** Margem máxima de folga que a previsão justifica (contrato §1.4). */
  marginCeiling: number;
}

/**
 * O payload semântico. Só aceita chaves da allowlist com valor primitivo.
 * A validação é recursiva e ocorre na construção E na serialização.
 */
export type RepresentationCode = Readonly<Record<string, number | string | boolean>>;

export interface DFrameInit {
  regionId: string;
  domain: Domain;
  DCurrent: number;
  DTarget: number;
  Priority: number;
  CostBudget: number;
  QualityRequired: QualityRequired;
  Representation: RepresentationCode;
  /** Fatos omitidos ao abstrair (Tese §10: informação perdida/aproximada). */
  OmittedFacts: readonly string[];
  /** Tipos de fato reconstruíveis a partir do estado preservado. */
  RecoverySet: readonly string[];
  /** Fatos que DTarget exige para reconstruir. Qi é verificado contra isto (contrato §4.3). */
  RecoveryRequired: readonly string[];
  Hysteresis: HysteresisState;
  Predicted?: Predicted;
  /** deltas por entidade dentro da região (contrato §4.1). */
  entities?: ReadonlyArray<{ id: string; delta: RepresentationCode }>;
  /**
   * Tese §49: uma entidade crítica carrega exceção própria e não herda o D da
   * região. A exceção é declarada, nunca implícita.
   */
  criticalEntities?: ReadonlyArray<{ id: string; DOverride: number; why: string }>;
}

export interface DFrame extends DFrameInit {
  readonly schemaVersion: number;
  readonly engineVersion: string;
  readonly frozen: true;
}

export interface ResultFrame {
  readonly regionId: string;
  readonly domain: Domain;
  readonly DApplied: number;
  readonly Q_measured: { Qp: number; Qf: number; Qi: number };
  readonly C_measured: number;
  readonly deviations: readonly string[];
  readonly schemaVersion: number;
}

export class DFrameError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(`${code}: ${message}`);
    this.code = code;
    this.name = 'DFrameError';
  }
}

const ALLOW = new Set(Object.keys(REPRESENTATION_KEY_TYPES));

function assertRepresentationPayload(repr: unknown, where: string): asserts repr is RepresentationCode {
  if (repr === null || typeof repr !== 'object' || Array.isArray(repr)) {
    throw new DFrameError('REPR_NOT_MAP', `${where} deve ser um mapa de códigos, não ${Array.isArray(repr) ? 'array' : typeof repr}`);
  }
  for (const [k, v] of Object.entries(repr as Record<string, unknown>)) {
    const lk = k.toLowerCase();
    if ((FORBIDDEN_KEYS as readonly string[]).includes(lk)) {
      throw new DFrameError('REPR_FORBIDDEN_KEY', `${where}.${k} é geometria/sombreador explícito — proibido por tipo (§4.2)`);
    }
    if (!ALLOW.has(k)) {
      throw new DFrameError(
        'REPR_KEY_NOT_ALLOWED',
        `${where}.${k} não está na allowlist do Representation. O frame transporta códigos; quem expande código em material é o RRW.`,
      );
    }
    const t = typeof v;
    if (t !== 'number' && t !== 'string' && t !== 'boolean') {
      throw new DFrameError('REPR_VALUE_NOT_PRIMITIVE', `${where}.${k} deve ser número/string/boolean, veio ${t}`);
    }
    if (t === 'number' && !Number.isFinite(v as number)) {
      throw new DFrameError('REPR_VALUE_NOT_FINITE', `${where}.${k} é não-finito — orçamento corrompido materializa lixo em silêncio`);
    }
  }
}

/**
 * Varredura estrutural. Todo nó problemático vira DFrameError: um TypeError
 * anônimo aqui é o mecanismo pelo qual "requisito incompleto" viraria
 * "materialização errada em silêncio" a um frame de distância.
 */
function rejectGeometryAnywhere(value: unknown, path: string, depth = 0): void {
  if (depth > 12) throw new DFrameError('FRAME_TOO_DEEP', path);
  if (value === null || value === undefined) {
    if (depth === 0) return;
    throw new DFrameError('FRAME_FIELD_NULL', `${path} é ${String(value)} — campo obrigatório ausente não é campo vazio`);
  }
  const t = typeof value;
  if (t === 'number' || t === 'string' || t === 'boolean') return;
  if (ArrayBuffer.isView(value) || value instanceof ArrayBuffer) {
    throw new DFrameError('FRAME_CONTAINS_GEOMETRY', `${path} é um buffer binário; um DFrame não carrega vértice, texel nem bytecode (I1)`);
  }
  if (t !== 'object') {
    throw new DFrameError('FRAME_FIELD_TYPE', `${path} é ${t}, e não é um tipo aceito por um DFrame`);
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => rejectGeometryAnywhere(v, `${path}[${i}]`, depth + 1));
    return;
  }
  let entries: [string, unknown][];
  try {
    entries = Object.entries(value as Record<string, unknown>);
  } catch (e) {
    throw new DFrameError('FRAME_FIELD_UNPARSEABLE', `${path}: ${(e as Error).message}`);
  }
  for (const [k, v] of entries) {
    if ((FORBIDDEN_KEYS as readonly string[]).includes(k.toLowerCase())) {
      throw new DFrameError('FRAME_FORBIDDEN_KEY', `${path}.${k} não pode existir num DFrame (I1)`);
    }
    rejectGeometryAnywhere(v, `${path}.${k}`, depth + 1);
  }
}

function deepFreeze<T>(v: T): T {
  if (v && typeof v === 'object' && !Object.isFrozen(v)) {
    Object.freeze(v);
    for (const o of Object.values(v as Record<string, unknown>)) deepFreeze(o);
  }
  return v;
}

/** Constrói um DFrame validado e imutável. Toda violação é erro nomeado. */
export function makeDFrame(init: DFrameInit, ctx?: { resources?: ResourceContext }): DFrame {
  rejectGeometryAnywhere(init, 'DFrame');
  assertRepresentationPayload(init.Representation, 'DFrame.Representation');
  if (init.entities) {
    init.entities.forEach((e, i) => assertRepresentationPayload(e.delta, `DFrame.entities[${i}].delta`));
  }

  const q = init.QualityRequired;
  if (!q || typeof q !== 'object') {
    throw new DFrameError('QUALITY_REQUIRED_MISSING', 'QualityRequired ausente — requisito incompleto não é "sem requisito"');
  }
  for (const k of ['minD', 'maxD'] as const) {
    if (typeof q[k] !== 'number' || !Number.isFinite(q[k])) {
      throw new DFrameError('QUALITY_REQUIRED_MISSING', `QualityRequired.${k} foi perdido ao compor o frame: requisito parcial é proibido`);
    }
  }
  if (!q.class || typeof q.class !== 'object') {
    throw new DFrameError('QUALITY_REQUIRED_MISSING', 'QualityRequired/class ausente — requisito incompleto não é "sem requisito"');
  }
  for (const k of ['QpMin', 'QfMin', 'QiMin'] as const) {
    const v = q[k];
    if (!(typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1)) {
      throw new DFrameError('Q_OUT_OF_RANGE', `${k}=${v} fora de [0,1]`);
    }
  }
  for (const k of ['Qp', 'Qf', 'Qi'] as const) {
    if (!['PERCEPTUAL', 'FUNCTIONAL', 'INFORMATIONAL'].includes(q.class[k])) {
      throw new DFrameError('I8_UNCLASSIFIED_QUALITY', `${k}.class="${q.class[k]}" — todo requisito precisa declarar sua classe (Tese §16)`);
    }
  }
  if (q.mode !== 'ESTIMATE' && q.mode !== 'MEASURE') {
    throw new DFrameError('Q_MODE_MISSING', `mode="${String(q.mode)}" — requisito sem modo não é auditável (contrato §2.4)`);
  }
  if (init.DCurrent < q.minD) {
    throw new DFrameError('MIN_D_VIOLATED', `DCurrent=${init.DCurrent} abaixo do requisito D${q.minD}: piso não se satisfaz apagando capacidade`);
  }
  if (init.DTarget > q.maxD) {
    throw new DFrameError('MAX_D_EXCEEDED', `DTarget=${init.DTarget} acima do maior D existente (${q.maxD})`);
  }
  if (!Number.isFinite(init.CostBudget) || init.CostBudget < 0) {
    throw new DFrameError('BUDGET_INVALID', `CostBudget=${init.CostBudget}`);
  }
  if (ctx?.resources) {
    if (ctx.resources.thermal === 'critical' && init.DTarget > init.DCurrent) {
      throw new DFrameError('THERMAL_EXPANSION_BLOCKED', 'thermal crítico: expansão deve ser decisão humana, não otimização automática');
    }
  }

  for (const k of ['OmittedFacts', 'RecoverySet', 'RecoveryRequired'] as const) {
    if (!Array.isArray(init[k])) {
      throw new DFrameError('FRAME_LEDGER_MISSING', `${k} ausente — sem ledger não há como distinguir economia de destruição (Tese §10)`);
    }
  }
  // Qi: só o que o DTarget precisa de volta é obrigatório. Abstrair fato
  // inútil é a economia; abstrair fato exigido é destruição (Tese §80/§81).
  const missing = init.RecoveryRequired.filter((f) => !init.RecoverySet.includes(f));
  if (missing.length) {
    throw new DFrameError(
      'QI_UNRECOVERABLE_OMISSION',
      `D${init.DTarget} exige reconstrução de ${missing.join(', ')} e o RecoverySet não cobre — isto é perda, não otimização`,
    );
  }

  const frame = { ...init, schemaVersion: SCHEMA_VERSION, engineVersion: ENGINE_VERSION, frozen: true } as DFrame;
  return deepFreeze(frame);
}

export interface Migration {
  from: number;
  to: number;
  apply: (raw: Record<string, unknown>) => Record<string, unknown>;
}

const migrations = new Map<number, Migration>();

export function registerMigration(m: Migration): void {
  if (m.to !== m.from + 1) throw new DFrameError('MIGRATION_NOT_SEQUENTIAL', `migração ${m.from}→${m.to}: só é aceito passo único`);
  migrations.set(m.from, m);
}

/**
 * Parse com versionamento explícito. Frame incompatível FALHA; nunca materializa
 * o nível errado em silêncio (contrato §5.4, padrão de `UTS.txt` §52).
 */
export function parseDFrame(raw: unknown): DFrame {
  let obj: Record<string, unknown>;
  try {
    obj = typeof raw === 'string' ? (JSON.parse(raw) as Record<string, unknown>) : (raw as Record<string, unknown>);
  } catch (e) {
    throw new DFrameError('FRAME_MALFORMED', `não é JSON válido: ${(e as Error).message}`);
  }
  if (!obj || typeof obj !== 'object') throw new DFrameError('FRAME_MALFORMED', 'não é objeto');

  let version = obj.schemaVersion;
  let guard = 0;
  while (typeof version === 'number' && version < SCHEMA_VERSION) {
    const m = migrations.get(version);
    if (!m) throw new DFrameError('FRAME_VERSION_UNSUPPORTED', `schemaVersion=${version} → ${SCHEMA_VERSION} sem migração registrada`);
    obj = m.apply(obj);
    version = obj.schemaVersion;
    if (++guard > 16) throw new DFrameError('FRAME_MIGRATION_LOOP', 'cadeia de migração não converge');
  }
  if (version !== SCHEMA_VERSION) {
    throw new DFrameError('FRAME_VERSION_FROM_FUTURE', `schemaVersion=${String(version)} > ${SCHEMA_VERSION}: engine precisa ser atualizada antes`);
  }
  return makeDFrame(obj as unknown as DFrameInit);
}

/** Serialização canônica. A validação roda de novo: frame mutável não existe. */
export function serializeDFrame(f: DFrame): string {
  const clone = JSON.parse(JSON.stringify(f)) as Record<string, unknown>;
  rejectGeometryAnywhere(clone, 'DFrame(serialized)');
  return JSON.stringify(clone);
}

export function assertFrameHasNoGeometry(f: DFrame): void {
  rejectGeometryAnywhere(JSON.parse(JSON.stringify(f)), 'DFrame');
}

export function makeResultFrame(
  regionId: string,
  domain: Domain,
  DApplied: number,
  Q: { Qp: number; Qf: number; Qi: number },
  C: number,
  deviations: readonly string[] = [],
): ResultFrame {
  return deepFreeze({ regionId, domain, DApplied, Q_measured: { ...Q }, C_measured: C, deviations: [...deviations], schemaVersion: SCHEMA_VERSION });
}
