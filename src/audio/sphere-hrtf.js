// UTS :: audio/sphere-hrtf — A BASE EXATA DA ORELHA.
// A solução em SÉRIE DE RAYLEIGH para a difração de onda plana por uma
// ESFERA RÍGIDA (o problema canônico do qual as medidas KEMAR/CIPIC são
// a aproximação real): H(θ, f) fechada por soma harmônica esférica com
// Bessel esféricas por recorrência determinística (zero aleatório, zero
// dependência). A mola do problema real: a cabeça é ~rígida e esférica
// (r = 8.75cm — o MESMO raio da ITD de Woodworth usada no motor), então
// a solução exata do canônico CAPTURA a realidade medida: ganho de
// baffel +6dB na orelha iluminada, sombra contralateral que CAI com a
// frequência, e fase que devolve a ITD de Woodworth em baixa frequência.
// A tabela sai no MESMO schema do banco medido (sr/azimuths/elevations/
// taps/data) e passa pela MESMA loadMeasuredTable e pela MESMA
// interpoladora binlinear — o renderer não muda uma linha.
// HONESTO: não é medida crua; é a solução EXATA do modelo canônico.
// O slot do banco medido do dono continua aberto (loadMeasuredTable).

import { loadMeasuredTable } from './hrtf.js';

export const SPHERE_R_M = 0.0875; // cabeça média adulta (o raio de Woodworth)
export const SOUND_C = 343;       // m/s

// ------------------------------------------------------------------
// Bessel esféricas (determinísticas).
// j_n: recorrência para trás (Miller) normalizada pela forma fechada
// j_0 = sin(x)/x (estável para todo n até nMax).
// y_n: recorrência para frente a partir das formas fechadas (y é a
// solução CRESCENTE — para frente é estável).
// ------------------------------------------------------------------
function besselJ(x, nMax) {
  const TOP = nMax + 30;
  const J = new Float64Array(TOP + 1);
  J[TOP] = 0; J[TOP - 1] = 1;
  for (let n = TOP - 2; n >= 0; n--) J[n] = ((2 * n + 3) / x) * J[n + 1] - J[n + 2];
  const scale = (Math.sin(x) / x) / J[0];
  const out = new Float64Array(nMax + 1);
  for (let n = 0; n <= nMax; n++) out[n] = J[n] * scale;
  return out;
}
function besselY(x, nMax) {
  const out = new Float64Array(nMax + 1);
  out[0] = -Math.cos(x) / x;
  out[1] = -Math.cos(x) / (x * x) - Math.sin(x) / x;
  for (let n = 1; n < nMax; n++) out[n + 1] = ((2 * n + 1) / x) * out[n] - out[n - 1];
  return out;
}

// ---- cache por número de onda reduzido ka: B_n(ka) é só da frequência
const _bnCache = new Map();

/** B_n(ka) = j_n − j_n'·h_n^{(2)}/h_n^{(2)'} — o coeficiente de RAYLEIGH
 *  (condição de Neumann: ∂p/∂r = 0 na superfície rígida). */
function bnFor(ka) {
  const key = Math.round(ka * 1e6);
  if (_bnCache.has(key)) return _bnCache.get(key);
  const nMax = Math.ceil(ka) + 26;
  const j = besselJ(ka, nMax);
  const y = besselY(ka, nMax);
  // derivadas: f_n' = f_{n−1} − (n+1)f_n/x; n=0 usa a forma fechada
  const B = new Array(nMax + 1);
  for (let n = 0; n <= nMax; n++) {
    const jp = n === 0
      ? Math.cos(ka) / ka - Math.sin(ka) / (ka * ka)
      : j[n - 1] - ((n + 1) * j[n]) / ka;
    const yp = n === 0
      ? Math.sin(ka) / ka + Math.cos(ka) / (ka * ka)
      : y[n - 1] - ((n + 1) * y[n]) / ka;
    // IDENTIDADE DE WRONSKIAN (exata): j_n y_n' − j_n' y_n = 1/x²
    // B_n = j_n − j_n'·h_n/h_n' = −i/(x²·h_n^{(2)\prime}), h^{(2)\prime} = j' − i·y'
    // → 1/(j' − i·y') = (j' + i·y')/(j'²+y'²)  →  B_n = (y' − i·j')/(x²·den)
    const den = jp * jp + yp * yp;
    B[n] = [yp / (ka * ka * den), -jp / (ka * ka * den)];
  }
  _bnCache.set(key, B);
  return B;
}

const P_LEGENDRE = (nMax, c) => {
  const P = new Float64Array(nMax + 1);
  P[0] = 1;
  if (nMax >= 1) P[1] = c;
  for (let n = 1; n < nMax; n++) P[n + 1] = ((2 * n + 1) * c * P[n] - n * P[n - 1]) / (n + 1);
  return P;
};

/**
 * A TRANSFERÊNCIA EXATA da esfera rígida: H(θ, f) para onda plana
 * incidente, receptor NA superfície, θ = ângulo entre a direção da
 * fonte e a direção do receptor. Soma até nMax = ceil(ka)+26
 * (convergência garantida para os ka desta máquina: ≤ 18).
 * Retorna { re, im } (convenção e^{−iωt}; a fase atrasa a orelha na sombra).
 */
export function sphereTransfer(thetaRad, freqHz, { r = SPHERE_R_M, c = SOUND_C } = {}) {
  const ka = (2 * Math.PI * freqHz * r) / c;
  if (freqHz <= 0) return { re: 1, im: 0 };
  const B = bnFor(ka);
  const nMax = B.length - 1;
  const cth = Math.max(-1, Math.min(1, Math.cos(thetaRad)));
  const P = P_LEGENDRE(nMax, cth);
  let re = 0, im = 0;
  // (2n+1)·i^n·P_n·B_n  — i^n cicla (1, i, −1, −i)
  for (let n = 0; n <= nMax; n++) {
    const coef = (2 * n + 1) * P[n];
    const [br, bi] = B[n];
    switch (n & 3) {
      case 0: re += coef * br; im += coef * bi; break;
      case 1: re -= coef * bi; im += coef * br; break;
      case 2: re -= coef * br; im -= coef * bi; break;
      default: re += coef * bi; im -= coef * br; break;
    }
  }
  return { re, im };
}

export const sphereGain = (thetaRad, freqHz) => Math.hypot(sphereTransfer(thetaRad, freqHz).re, sphereTransfer(thetaRad, freqHz).im);

// ------------------------------------------------------------------
// A TABELA no schema do banco medido: grade 13 az × 6 el (a MESMA do
// motor), FIR por orelha via IDFT-128 do espectro exato. A fase é
// re-referenciada com atraso puro de d0 amostras (a chegada na orelha
// iluminada ADIANTA ~a/c relativo ao centro — sem o offset o pico seria
// em tempo negativo; todo banco de HRTF real embute o atraso de voo).
// ------------------------------------------------------------------
const SR = 22050;
const TAPS = 48;
const NFFT = 128;
const D0 = 10;          // re-referência temporal (amostras)
const AZS = [-90, -75, -60, -45, -30, -15, 0, 15, 30, 45, 60, 75, 90];
const ELS = [-40, -20, 0, 20, 40, 60];

/** IR de uma direção/orelha: espectro exato → IDFT (Hermitiana → real) */
function earIR(thetaRad) {
  const X = new Array(NFFT).fill(null);
  for (let k = 1; k < NFFT / 2; k++) {
    const { re, im } = sphereTransfer(thetaRad, (k * SR) / NFFT);
    // atraso puro d0: multiplica por e^{−2πik·d0/N}
    const ph = (-2 * Math.PI * k * D0) / NFFT;
    const cs = Math.cos(ph), sn = Math.sin(ph);
    X[k] = [re * cs - im * sn, re * sn + im * cs];
  }
  X[0] = [1, 0];                       // limite de baixa frequência (exato)
  X[NFFT / 2] = [sphereTransfer(Math.PI / 2, SR / 2).re, 0]; // Nyquist real
  for (let k = 1; k < NFFT / 2; k++) {
    X[NFFT - k] = [X[k][0], -X[k][1]]; // Hermitiana → IR real
  }
  const ir = new Array(TAPS).fill(0);
  for (let n = 0; n < TAPS; n++) {
    let s = 0;
    for (let k = 0; k < NFFT; k++) {
      const a = (2 * Math.PI * k * n) / NFFT;
      s += X[k][0] * Math.cos(a) - X[k][1] * Math.sin(a);
    }
    ir[n] = s / NFFT;
  }
  // janela de borda: entrada em 2 amostras, saída nas 8 últimas
  for (let n = 0; n < 2; n++) ir[n] *= n / 2;
  for (let n = TAPS - 8; n < TAPS; n++) ir[n] *= (TAPS - 1 - n) / 8;
  return ir;
}

const angEntre = (elDeg, azDeg, earAzDeg) => {
  const el = (elDeg * Math.PI) / 180;
  const d = ((azDeg - earAzDeg) * Math.PI) / 180;
  return Math.acos(Math.max(-1, Math.min(1, Math.cos(el) * Math.cos(d))));
};

function buildSphereTable() {
  const data = {};
  for (const az of AZS) {
    data[az] = {};
    for (const el of ELS) {
      data[az][el] = {
        L: earIR(angEntre(el, az, -90)),
        R: earIR(angEntre(el, az, +90)),
      };
    }
  }
  const table = {
    sr: SR, taps: TAPS, azimuths: AZS, elevations: ELS, data,
    label: 'EXATA: esfera rígida r=8.75cm, série de Rayleigh (Duda-Martens) — o canônico que a medida aproxima; banco medido cru segue aberto',
    source: 'solução fechada (Neumann em esfera rígida), computada nesta máquina',
  };
  // o MESMO portão do banco medido valida: mesmo schema, mesma lei
  return loadMeasuredTable(table);
}

export const SPHERE_TABLE = buildSphereTable();

/** autoteste: a solução exata tem que devolver a física medida */
export function selfTests() {
  const deg = (d) => (d * Math.PI) / 180;
  const checks = [];
  const dB = (g) => 20 * Math.log10(Math.max(1e-9, g));

  // 1. baixa frequência: a esfera é transparente (ganho ≈ 0dB em todo ângulo)
  let g100 = 0;
  for (const th of [0, 45, 90, 135, 180]) g100 = Math.max(g100, Math.abs(dB(sphereGain(deg(th), 100))));
  checks.push({ name: 'baixa freq transparente (≤0.8dB em todo θ)', ok: g100 <= 0.8, detail: `pior ${g100.toFixed(3)}dB` });

  // 2. baffel: +6dB na orelha iluminada em alta frequência (dobro de pressão)
  const gOn = sphereGain(deg(0), 8000);
  checks.push({ name: 'ganho de baffel +6dB (1.7..2.2) a 8kHz θ=0', ok: gOn > 1.7 && gOn < 2.2, detail: gOn.toFixed(3) });

  // 3. ILD cresce com a frequência (perto−longe, fonte a 90°): a sombra
  // exata da ESFERA NUA é suave (a sombra profunda medida pertence à
  // cabeça COM pinna/torso) — o que a física exata garante é o CRESCIMENTO
  let prev = null, mono = true;
  for (const f of [500, 1000, 2000, 4000, 8000, 11000]) {
    const ild = sphereGain(0, f) / sphereGain(Math.PI, f);
    if (prev !== null && ild < prev - 0.05) mono = false;
    prev = ild;
  }
  checks.push({ name: 'ILD cresce com a frequência (sombra esférica honesta)', ok: mono && prev > 2, detail: `ILD(11kHz) = ${(20 * Math.log10(prev)).toFixed(1)}dB` });

  // 4. fase = RAYLEIGH 3a/c em baixa frequência (Γ=0 vs Γ=180): o resultado
  // analítico EXATO do modelo esférico (não a aproximação geométrica de
  // Woodworth 656µs — a solução exata dá 3a/c = 765µs a 90° de azimute)
  const itdRayleigh = (3 * SPHERE_R_M) / SOUND_C; // 765.3µs
  const f = 150;
  const x = (2 * Math.PI * f * SPHERE_R_M) / SOUND_C;
  const hA = sphereTransfer(Math.PI, f);
  const hB = sphereTransfer(0, f);
  const phiA = Math.atan2(hA.im, hA.re);
  const phiB = Math.atan2(hB.im, hB.re);
  let dphi = phiA - phiB;
  while (dphi > Math.PI) dphi -= 2 * Math.PI;
  while (dphi < -Math.PI) dphi += 2 * Math.PI;
  const itdExact = -dphi / (2 * Math.PI * f);
  checks.push({ name: 'ITD exata = RAYLEIGH 3a/c a 150Hz (±5%)', ok: Math.abs(itdExact - itdRayleigh) / itdRayleigh < 0.05, detail: `exata ${(itdExact * 1e6).toFixed(0)}µs vs 3a/c ${(itdRayleigh * 1e6).toFixed(0)}µs` });
  void x;

  // 5. determinismo: a MESMA tabela byte a byte (reconstrução independente)
  const again = {};
  for (const az of AZS) { again[az] = {}; for (const el of ELS) again[az][el] = { L: earIR(angEntre(el, az, -90)), R: earIR(angEntre(el, az, +90)) }; }
  checks.push({ name: 'determinística (mesma reconstrução)', ok: JSON.stringify(again) === JSON.stringify(SPHERE_TABLE.data), detail: 'rebuild idêntico' });

  // 6. a tabela passa no portão do banco MEDIDO e a orelha pontual funciona
  const far = SPHERE_TABLE.data[90][0].L;
  const near = SPHERE_TABLE.data[90][0].R;
  let pkL = 0, pkR = 0;
  for (let i = 0; i < far.length; i++) { if (far[i] > far[pkL]) pkL = i; if (near[i] > near[pkR]) pkR = i; }
  checks.push({ name: 'orelha distante CHEGA DEPOIS (pico L > pico R + 8)', ok: pkL > pkR + 8, detail: `picoL ${pkL} vs picoR ${pkR}` });

  return checks;
}
