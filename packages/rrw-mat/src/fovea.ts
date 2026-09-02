// UTS/UES — DENSIDADE DE REPRESENTAÇÃO POR CÉLULA (o "desrenderizar o desnecessário")
//
// Por que este arquivo existe: eu declarei foveação "impossível" porque ela depende
// de hardware que o aparelho não tem. Isso era um raciocínio de catálogo de indústria,
// exatamente o que a Gênesis proíbe. A forma correta do problema não é "quanto de
// pixels eu corto com um preset" — é "qual é a DENSIDADE de representação que a
// região suporta sem cruzar o piso". Essa formulação não precisa de eye-tracker,
// precisa de uma hipótese de atenção e de uma medição. Este módulo é o instrumento.
//
// O que NÃO é: não é filtro de desfoque, não é "lower graphics". Nenhuma célula aqui
// perde capacidade (o degrau D da região é um só, e o piso Qp é medido contra a
// referência na MESMA cena) — o que muda é a densidade com que o campo é amostrado
// dentro da célula, e o corte só é aceito se o Qp medido continuar acima do piso.
import type { LuminanceGrid } from './quality.ts';

export type AttentionSource =
  | 'reticle'            // mira: atenção onde a arma aponta (jogo de tiro)
  | 'salience'           // cena: onde há movimento/entidades
  | 'head-pose'          // IMU: aproxima gaze por orientação da cabeça
  | 'front-camera'       // webcam frontal: gaze aproximado, com custo próprio
  | 'static-prior'       // nada: assume centro; é o piso da família, não um fallback mudo
  | 'prediction'         // estado futuro previsto (o mais barato, o mais arriscado)
  | 'manual';            // decisão humana explícita

export interface FoveaInput {
  /** lado da grade (grade quadrada g×g) */
  g: number;
  /** centro da atenção em coordenadas normalizadas [0,1] */
  focus: readonly [number, number];
  /** raio (normalizado) dentro do qual a densidade é máxima */
  radius?: number;
  /** anel em que a densidade cai a ~1/e; default = radius */
  falloff?: number;
  /** densidade mínima no anel externo (fração das amostras plenas) */
  minDensity?: number;
  /** onde a hipótese de atenção veio de — viaja no resultado, porque o custo dela é real */
  source?: AttentionSource;
}

export interface FoveaField {
  /** densidade por célula em (0,1]; amostras plenas = 1 */
  readonly weights: Float64Array;
  readonly g: number;
  readonly source: AttentionSource;
  /** fração do trabalho de amostragem em relação a densidade plena (o "quanto se economiza") */
  readonly workFraction: number;
  readonly meanDensity: number;
  readonly minDensity: number;
}

/**
 * Campo de densidade. Determinístico e sem estado: a hipótese de atenção entra por
 * argumento, nunca por adivinhação, e a origem dela fica registrada no resultado —
 * uma economia atribuída a "foveação" sem dizer de onde veio a atenção é o tipo de
 * número que vira mito de engine.
 */
export function foveaField(input: FoveaInput): FoveaField {
  const { g } = input;
  if (!Number.isInteger(g) || g < 4) throw new Error(`FOVEA_GRID: g=${g} exige grade quadrada com lado ≥ 4`);
  const [fx, fy] = input.focus;
  for (const [k, v] of [['focus.x', fx], ['focus.y', fy]] as const) {
    if (!(v >= 0 && v <= 1)) throw new Error(`FOVEA_FOCUS: ${k}=${v} fora de [0,1]`);
  }
  const radius = input.radius ?? 0.18;
  const falloff = input.falloff ?? Math.max(radius, 0.02);
  const minDensity = input.minDensity ?? 0.25;
  if (!(radius > 0)) throw new Error(`FOVEA_RADIUS: radius=${radius}`);
  if (!(minDensity > 0 && minDensity <= 1)) throw new Error(`FOVEA_DENSITY: minDensity=${minDensity} fora de (0,1]`);

  const w = new Float64Array(g * g);
  let sum = 0;
  let lo = 1;
  for (let y = 0; y < g; y++) {
    for (let x = 0; x < g; x++) {
      const dx = (x + 0.5) / g - fx;
      const dy = (y + 0.5) / g - fy;
      const d = Math.hypot(dx, dy);
      // 1 dentro do raio de atenção plena, decaimento suave até o piso; o piso nunca é
      // zero porque "não amostrar" é corte de informação, e corte de informação é o que
      // o Qp mede — densidade mínima é a parte da cena que continua representada.
      const t = Math.max(0, d - radius) / falloff;
      const v = minDensity + (1 - minDensity) * Math.exp(-t);
      w[y * g + x] = v;
      sum += v;
      if (v < lo) lo = v;
    }
  }
  return {
    weights: w,
    g,
    source: input.source ?? 'static-prior',
    workFraction: Number((sum / (g * g)).toFixed(4)),
    meanDensity: Number((sum / (g * g)).toFixed(4)),
    minDensity: Number(lo.toFixed(4)),
  };
}

/**
 * Amostragem não-uniforme do campo materializado: dentro do raio, célula a célula;
 * fora, blocos crescentes. Isto é o que "densidade" significa em execução: a
 * materialização ainda é O(células), mas o número de células *de alta densidade*
 * passa a ser decisão por região, não constante da tela.
 */
export function applyFovea(field: LuminanceGrid, fovea: FoveaField): LuminanceGrid {
  if (fovea.g !== field.w || fovea.g !== field.h) {
    throw new Error(`FOVEA_GRID_MISMATCH: campo ${field.w}×${field.h} vs densidade ${fovea.g}×${fovea.g}`);
  }
  const g = fovea.g;
  const out = new Float64Array(field.samples.length);
  for (let y = 0; y < g; y++) {
    for (let x = 0; x < g; x++) {
      const i = y * g + x;
      const w = fovea.weights[i];
      // densidade → passo de bloco: 1 = amostra própria, ≥2 = replicar a amostra do
      // bloco (a célula externa é REAPRESENTADA, não apagada)
      const block = Math.max(1, Math.round(1 / Math.max(1e-6, w)));
      const bx = Math.min(g - 1, Math.floor(x / block) * block);
      const by = Math.min(g - 1, Math.floor(y / block) * block);
      let acc = 0;
      let cnt = 0;
      for (let dy = 0; dy < block; dy++) {
        for (let dx = 0; dx < block; dx++) {
          const s = (by + dy) % g;
          const t = (bx + dx) % g;
          acc += field.samples[s * g + t];
          cnt++;
        }
      }
      out[i] = acc / cnt;
    }
  }
  return { w: g, h: g, D: field.D, samples: out };
}

/**
 * O dial que a Gênesis pode ter: NÃO "qualidade menor", e sim "quanta densidade o
 * quadro aguenta sem cruzar o piso". Busca binária no raio de atenção plena contra um
 * orçamento de trabalho; devolve o campo que cabe e para de subir quando o próximo
 * raio violaria o teto — sem nunca oferecer um preset abaixo do Qp mínimo.
 */
export function budgetFovea(opts: {
  g: number;
  /** fração do custo de densidade plena que o quadro permite gastar, ex.: 0.62 */
  allowedWork: number;
  minDensity?: number;
  focus?: readonly [number, number];
  source?: AttentionSource;
}): { density: number; fovea: FoveaField; search: number } {
  const { g, allowedWork, minDensity = 0.25 } = opts;
  if (!(allowedWork > 0 && allowedWork <= 1)) throw new Error(`FOVEA_BUDGET: allowedWork=${allowedWork} fora de (0,1]`);
  let rlo = 0.02;
  let rhi = 0.9;
  let best: FoveaField | null = null;
  let search = 0;
  for (; search < 24; search++) {
    const r = (rlo + rhi) / 2;
    const f = foveaField({ g, focus: opts.focus ?? [0.5, 0.5], radius: r, falloff: Math.max(r, 0.02), minDensity, source: opts.source });
    if (f.workFraction > allowedWork) rhi = r;
    else {
      rlo = r;
      best = f;
    }
  }
  if (!best) throw new Error('FOVEA_BUDGET: nenhuma densidade coube no orçamento — o corte exigido passa do piso');
  return { density: best.workFraction, fovea: best, search };
}
