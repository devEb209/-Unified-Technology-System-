import type { LuminanceGrid } from './materialize.ts';

export interface ThresholdMap {
  readonly w: number;
  readonly h: number;
  /** Erro de luminância tolerável por célula, em luminância relativa (0..1). */
  readonly t: Float64Array;
  readonly source: 'model' | 'measured';
}

/**
 * Mapa de limiar perceptual (contraste local). Forma funcional idêntica à de
 * Ramasubramanian/Pattanaik/Greenberg, SIGGRAPH'99 — "A Perceptually Based
 * Physical Error Metric for Realistic Image Synthesis", que é o que permite a
 * eles usarem 6% das amostras de GI sem diferença visível.
 *
 * Importante sobre honestidade do número: aqueles 6% são AMOSTRAGEM offline de
 * Monte-Carlo. Isto aqui decide o que materializar por célula, que é outra
 * despesa; nenhum fator de economia é reivindicado a partir daquele paper.
 * As constantes abaixo são prior de psicofísica (TVC ~1% em plateau, subindo
 * com contraste local); calibrar exige medir no A70, não confiar nelas.
 */
export function thresholdMap(ref: LuminanceGrid, k = 0.6, floor = 0.01): ThresholdMap {
  const { w, h, samples } = ref;
  const t = new Float64Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      // Contraste de Michelson LOCAL, não erro global normalizado pelo range:
      // é o que a psicofísica usa para TVC, e sem isto o limiar ficava maior que
      // a imagem inteira (nada seria jamais percebido — o medidor virava enfeite).
      const nb = (j: number) => samples[Math.min(w * h - 1, Math.max(0, j))];
      const mich = (a: number, b: number) => Math.abs(a - b) / Math.max(1e-4, a + b);
      const contrast = Math.max(mich(samples[i], nb(i + 1)), mich(samples[i], nb(i + w)));
      t[i] = Math.min(0.2, floor + k * contrast);
    }
  }
  return { w, h, t, source: 'model' };
}

export interface QualityMeasure {
  /** Fração de células cujo erro físico fica dentro do limiar local. Qp. */
  readonly Qp: number;
  readonly meanError: number;
  readonly p95Error: number;
  readonly worstCells: ReadonlyArray<{ x: number; y: number; err: number; limit: number }>;
  /** Células que violam o limiar: é isto que vira `deviations` no ResultFrame. */
  readonly violations: number;
}

/**
 * Medida de Qp entre a cena de referência e a materialização candidata, na
 * MESMA cena e mesma grade (contrato §2.3: Q sem par REF↔CAND é adjetivo).
 *
 * Diferente de "diferença de imagem", aqui o erro é normalizado pelo limiar:
 * cortar o que não é percebido é desperdício removido, cortar o que é percebido
 * é proibido. Isto é o que dá conteúdo operável a "Reality ≠ Ultra preset".
 */
export function measureQp(ref: LuminanceGrid, cand: LuminanceGrid, map?: ThresholdMap): QualityMeasure {
  if (ref.w !== cand.w || ref.h !== cand.h) {
    throw new Error(`Qp: grade ${ref.w}×${ref.h} vs ${cand.w}×${cand.h} — medida exige a mesma cena e a mesma granularidade`);
  }
  const tm = map ?? thresholdMap(ref);
  const errs = new Float64Array(ref.samples.length);
  const worst: { x: number; y: number; err: number; limit: number }[] = [];
  let ok = 0;
  let sum = 0;
  let violations = 0;
  for (let i = 0; i < ref.samples.length; i++) {
    const e = Math.abs(ref.samples[i] - cand.samples[i]);
    errs[i] = e;
    sum += e;
    const limit = tm.t[i];
    if (e <= limit) ok++;
    else violations++;
    if (worst.length < 8 || e > worst[worst.length - 1].err) {
      worst.push({ x: i % ref.w, y: (i / ref.w) | 0, err: e, limit });
      worst.sort((a, b) => b.err - a.err);
      if (worst.length > 8) worst.pop();
    }
  }
  const sorted = Float64Array.from(errs).sort();
  return {
    Qp: ok / ref.samples.length,
    meanError: sum / ref.samples.length,
    p95Error: sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))],
    worstCells: worst,
    violations,
  };
}
