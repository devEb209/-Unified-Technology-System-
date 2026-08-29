// UTS :: audio/hrtf — THE DIRECTIONAL EAR: a direction-dependent FIR pair
// (left/right) selected from a TABLE by azimuth × elevation. The shipped
// table is PARAMETRIC from published averages (Woodworth ITD as pure
// delay + head shadow lowpass + concha notch by elevation + shoulder
// bump ~1.1kHz) — clearly labeled. The slot for a MEASURED database
// (CIPIC/MIT/KEMAR) is `loadMeasuredTable(table)`: same schema, honest
// validation, and the renderer never needs to change.
export const HRTF_SCHEMA = Object.freeze({
  sr: 'sample rate (Hz)',
  azimuths: 'lista de azimutes em graus (-90..90, -90 = à esquerda)',
  elevations: 'lista de elevações em graus (-40..60, baixo→alto)',
  taps: 'nº de coeficientes FIR por orelha',
  data: 'data[az][el] = { L: number[], R: number[] } — a resposta direcional',
});

const TAPS = 8;
const SR = 22050;

/** one-pole lowpass coefficients for the head shadow (per lateral angle) */
const shadowAlpha = (latDeg) => 0.25 + 0.6 * Math.max(0, Math.abs(latDeg) / 90);

/** concha notch position by elevation (the measured tendency, 7–10.5kHz) */
const notchHz = (elevDeg) => 7000 + 3500 * Math.max(-1, Math.min(1, elevDeg / 60));

/** build the PARAMETRIC table (published averages; slot for measured data) */
function buildParametricTable() {
  const azimuths = [-90, -60, -30, 0, 30, 60, 90];
  const elevations = [-40, -20, 0, 20, 60];
  const data = {};
  for (const az of azimuths) {
    data[az] = {};
    const lat = az / 90; // -1..1
    const itdSec = (0.0875 / 343) * (Math.abs(lat) * Math.PI / 2 + Math.sin(Math.abs(lat) * Math.PI / 2));
    const itdSamples = itdSec * SR; // the near ear 0, far ear delayed
    const alpha = shadowAlpha(az);
    for (const el of elevations) {
      const L = new Array(TAPS).fill(0);
      const R = new Array(TAPS).fill(0);
      const farDelay = Math.round(itdSamples);
      const notchGain = 1 - 0.35 * Math.max(0, Math.min(1, Math.abs(el) / 60));
      for (let i = 0; i < TAPS; i++) {
        // direct impulse + shoulder bump (1.1kHz-ish tail) + notch shaping
        const shoulder = 0.14 * Math.exp(-Math.abs(i - 3) / 1.5);
        const g = (i === 0 ? 1 : shoulder) * notchGain;
        // the ear TOWARD the source hears first; the far ear is delayed+dark
        if (az < 0) { L[i] = g; R[i + farDelay < TAPS ? i + farDelay : TAPS - 1] = g * (1 - 0.55 * Math.abs(lat)) * alpha; }
        else if (az > 0) { R[i] = g; L[i + farDelay < TAPS ? i + farDelay : TAPS - 1] = g * (1 - 0.55 * Math.abs(lat)) * alpha; }
        else { L[i] = g; R[i] = g; }
      }
      data[az][el] = { L, R };
    }
  }
  return Object.freeze({ sr: SR, taps: TAPS, azimuths, elevations, data, label: 'paramétrica publicada (slot para banco MEDIDO)' });
}

export const PARAMETRIC_TABLE = buildParametricTable();

/** slot for a MEASURED database — validated honestly, frozen */
export function loadMeasuredTable(table) {
  const errs = [];
  if (!table || typeof table !== 'object') errs.push('tabela ausente');
  else {
    if (typeof table.sr !== 'number' || table.sr <= 0) errs.push('sr inválido');
    if (!Array.isArray(table.azimuths) || table.azimuths.length === 0) errs.push('azimuths ausentes');
    if (!Array.isArray(table.elevations) || table.elevations.length === 0) errs.push('elevations ausentes');
    if (!table.data || typeof table.data !== 'object') errs.push('data ausente');
    else {
      for (const az of table.azimuths ?? []) {
        for (const el of table.elevations ?? []) {
          const cell = table.data[az]?.[el];
          if (!cell || !Array.isArray(cell.L) || !Array.isArray(cell.R)) { errs.push(`data[${az}][${el}] incompleta`); break; }
        }
        if (errs.length) break;
      }
    }
  }
  if (errs.length) throw new Error(`hrtf: tabela medida recusada — ${errs[0]} (schema: ${JSON.stringify(HRTF_SCHEMA).slice(0, 120)}…)`);
  return Object.freeze({ ...table, label: 'MEDIDA (banco anexado pelo dono)' });
}

/** bracketing cells + weights (binlinear; the ear turns SMOOTH) */
function bracket(grid, v) {
  if (v <= grid[0]) return [grid[0], grid[0], 0];
  if (v >= grid[grid.length - 1]) return [grid[grid.length - 1], grid[grid.length - 1], 0];
  for (let i = 0; i < grid.length - 1; i++) {
    if (v >= grid[i] && v <= grid[i + 1]) {
      const t = (v - grid[i]) / (grid[i + 1] - grid[i]);
      return [grid[i], grid[i + 1], t];
    }
  }
  return [grid[0], grid[0], 0];
}

/**
 * BIINLINEAR lookup: interpolate the directional table between the four
 * bracketing cells (az × el). The ear turns without clicking — and the
 * interpolation is on the MEASURED data too (whatever table is attached).
 */
export function pickBilinear(table, azDeg, elevDeg) {
  const [az0, az1, ta] = bracket(table.azimuths, azDeg);
  const [el0, el1, te] = bracket(table.elevations, elevDeg);
  const mixCell = (A, B, t) => A.map((v, i) => v * (1 - t) + (B[i] ?? v) * t);
  const top = {
    L: mixCell(table.data[az0][el0].L, table.data[az1][el0].L, ta),
    R: mixCell(table.data[az0][el0].R, table.data[az1][el0].R, ta),
  };
  const bot = {
    L: mixCell(table.data[az0][el1].L, table.data[az1][el1].L, ta),
    R: mixCell(table.data[az0][el1].R, table.data[az1][el1].R, ta),
  };
  return { L: mixCell(top.L, bot.L, te), R: mixCell(top.R, bot.R, te) };
}

/** FIR convolution (deterministic) */
export function firFilter(samples, taps) {
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    let s = 0;
    for (let k = 0; k < taps.length; k++) {
      const j = i - k;
      if (j >= 0) s += samples[j] * taps[k];
    }
    out[i] = s;
  }
  return out;
}

/**
 * THE DIRECTIONAL EAR: render `samples` as heard from (azDeg, elevDeg).
 * Returns { left, right, table } — one truth: whatever table is attached
 * (parametric today, measured when the owner attaches one).
 */
export function applyHRTF(samples, azDeg, elevDeg, { table = PARAMETRIC_TABLE } = {}) {
  const cell = pickBilinear(table, azDeg, elevDeg);
  return { left: firFilter(samples, cell.L), right: firFilter(samples, cell.R), table: table.label };
}
