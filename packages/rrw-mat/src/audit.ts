import { makeResultFrame, type DFrame, type ResultFrame } from '../../dframe/src/dframe.ts';
import { materializeVisual, type MaterializeOptions } from './materialize.ts';
import { measureQp, thresholdMap, type QualityMeasure } from './quality.ts';

export interface AuditResult {
  readonly result: ResultFrame;
  readonly measure: QualityMeasure;
  /** true se a materialização medida está dentro do piso declarado no frame. */
  readonly accepted: boolean;
  /** Custo medido da materialização (ms), para fechar §11 (estimativa ↔ medição). */
  readonly ms: number;
}

/**
 * AUDITORIA DE UMA REGIÃO (contrato §2.3/§2.4, invariante I6).
 *
 * É a única forma honesta de dizer "otimizado": materializa a cena, mede contra
 * a referência, compara com o piso que o próprio frame carrega e devolve um
 * ResultFrame com os desvios NOMADOS. Sem isto, `Q ≥ Q_min` é uma asserção do
 * otimizador sobre si mesmo — que é o que UTS l.2181 proíbe ("Não aceite
 * 'otimizado' sem medição").
 *
 * O candidato de referência é o mesmo frame ao D alvo: REF é a cena completa,
 * CAND é a cena escolhida. Nunca REF = outra cena, nunca REF = preset.
 */
export function auditVisual(frame: DFrame, refFrame: DFrame, opts: MaterializeOptions = {}): AuditResult {
  const t0 = process.hrtime.bigint();
  const cand = materializeVisual(frame, opts);
  const ref = materializeVisual(refFrame, opts);
  const map = thresholdMap(ref.field);
  const measure = measureQp(ref.field, cand.field, map);
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;

  const q = frame.QualityRequired;
  const deviations: string[] = [];
  if (measure.Qp + 1e-9 < q.QpMin) {
    deviations.push(
      `Qp medido ${measure.Qp.toFixed(3)} < QpMin ${q.QpMin.toFixed(3)} em ${measure.violations} células ` +
        `(pior em r=${measure.worstCells[0]?.x ?? '?'},c=${measure.worstCells[0]?.y ?? '?'}: erro ${measure.worstCells[0]?.err.toFixed(3)} vs limiar ${measure.worstCells[0]?.limit.toFixed(3)})`,
    );
  }
  if (frame.DCurrent < q.minD) deviations.push(`DCurrent ${frame.DCurrent} abaixo do minD ${q.minD}`);
  if (frame.OmittedFacts.length > 0 && frame.RecoveryRequired.length > 0) {
    const missing = frame.RecoveryRequired.filter((f) => !frame.RecoverySet.includes(f));
    if (missing.length) deviations.push(`RecoveryRequired não reconstruível a partir do RecoverySet: ${missing.join(', ')}`);
  }
  const result = makeResultFrame(
    frame.regionId,
    frame.domain,
    frame.DCurrent,
    { Qp: measure.Qp, Qf: frame.DCurrent / Math.max(1, q.maxD), Qi: 1 - frame.OmittedFacts.length / Math.max(1, frame.OmittedFacts.length + frame.RecoverySet.length) },
    cand.cells,
    deviations,
  );
  return { result, measure, accepted: deviations.length === 0, ms };
}
