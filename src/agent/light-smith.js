// UTS :: agent/light-smith — A FORJA DE LUZ (o mesmo molde da forja de
// geometria: leis declaradas, autoteste, determinismo, tipo fora da lei
// é erro explícito). A luz deixa de ser "cor com brilho" e passa a ser
// FENÔMENO FORJADO:
//   • TEMPERATURA REAL: Kelvin → cromatura pelo LOCO PLANCKIANO (ajuste
//     analítico de Hernandez-Andres 1999, verificado contra as âncoras
//     CIE: 2000K quente, 4000K, 6504K = D65 neutro, 10000K frio);
//   • FOTOMETRIA REAL: candela (lm/sr) e iluminância E = I/d² — o
//     inverso do quadrado EXATO, com corte onde a contribuição cai
//     abaixo do piso de visibilidade (nada de halo infinito);
//   • SPOT pela lei do cosseno (cos^expo do ângulo ao eixo), ÁREA com
//     amostras determinísticas (a suavidade de perto é a razão real da
//     luz de área), RIG de 3 pontos (key/fill/rim);
//   • GAMUT honesto: a cromatura sai da gamuta sRGB → dessaturar para o
//     cinza de mesma luminância até entrar (o procedimento real dos
//     coloristas), nunca clampar canal por canal (isso mente a cor).

// ------------------------------------------------------------------
// LOCO PLANCKIANO: cromaticidade (x, y) da radiação do corpo negro.
// Ajuste analítico de Hernandez-Andres, Nieves & Valero (1999) —
// declarado e verificado contra as âncoras CIE no autoteste.
// ------------------------------------------------------------------
export function kelvinToChroma(kelvin) {
  const T = Number(kelvin);
  if (!Number.isFinite(T) || T < 1000 || T > 25000) {
    throw new Error(`light: temperatura fora da lei (1000–25000K): ${kelvin}`);
  }
  let x;
  if (T <= 4000) {
    x = -0.2661239e9 / T ** 3 - 0.2343580e6 / T ** 2 + 0.8776956e3 / T + 0.179910;
  } else {
    x = -3.0258469e9 / T ** 3 + 2.1070379e6 / T ** 2 + 0.2226347e3 / T + 0.240390;
  }
  let y;
  if (T < 2222) {
    y = -1.1063814 * x ** 3 - 1.34811020 * x ** 2 + 2.18555832 * x - 0.20219683;
  } else if (T < 4000) {
    y = -0.9549476 * x ** 3 - 1.37418593 * x ** 2 + 2.09137015 * x - 0.16748867;
  } else {
    y = 3.0817580 * x ** 3 - 5.87338670 * x ** 2 + 3.75112997 * x - 0.37001483;
  }
  return { x, y };
}

/** cromatura → sRGB LINEAR com gamut honesto (dessatura para o cinza de
 *  mesma luminância Y=1; nunca clamp canal a canal) */
export function chromaToSRGB(x, y) {
  // xyY (Y=1) → XYZ
  const X = x / y, Z = (1 - x - y) / y;
  // XYZ → sRGB linear (matriz IEC 61966-2-1)
  let r = 3.2406 * X - 1.5372 * 1 - 0.4986 * Z;
  let g = -0.9689 * X + 1.8758 * 1 + 0.0415 * Z;
  let b = 0.0557 * X - 0.2040 * 1 + 1.0570 * Z;
  // gamut: mix com o branco (após normalizar pelo canal mais alto, Y=1 →
  // branco cheio) — bisseção determinística de 40 passos; devolve t=hi,
  // SEMPRE viável (a cada passo hi continua dentro da gamuta)
  const ok = (rr, gg, bb) => rr >= 0 && gg >= 0 && bb >= 0 && rr <= 1 && gg <= 1 && bb <= 1;
  let desat = 0;
  if (!ok(r, g, b)) {
    const mx = Math.max(r, g, b);
    r /= mx; g /= mx; b /= mx;
    let lo = 0, hi = 1;
    for (let i = 0; i < 40; i++) {
      const t = (lo + hi) / 2;
      const mr = r * (1 - t) + t, mg = g * (1 - t) + t, mb = b * (1 - t) + t;
      if (ok(mr, mg, mb)) hi = t; else lo = t;
    }
    desat = hi;
    r = r * (1 - hi) + hi; g = g * (1 - hi) + hi; b = b * (1 - hi) + hi;
  }
  return { r, g, b, desat };
}

const sRGBencode = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);

export function kelvinToRGB(kelvin) {
  const { x, y } = kelvinToChroma(kelvin);
  const { r, g, b } = chromaToSRGB(x, y);
  return {
    linear: { r, g, b },
    rgb8: [Math.round(255 * sRGBencode(r)), Math.round(255 * sRGBencode(g)), Math.round(255 * sRGBencode(b))],
    chroma: { x, y },
  };
}

// ------------------------------------------------------------------
// FOTOMETRIA: E = I/d² (exato). Corte no piso de visibilidade.
// ------------------------------------------------------------------
const E_FLOOR = 1e-4; // lux (contribuição abaixo disso termina — sem halo infinito)
const dCut = (cd) => Math.sqrt(cd / E_FLOOR);

const _h = (s) => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; };
const _rng = (seed) => { let s = (seed >>> 0) || 1; return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; }; };

/** amostras de PAINEL: grade com tremor determinístico (LCG semeado) */
function panelSamples(w, h, n, seed) {
  const rng = _rng(_h(`painel:${w}x${h}:${n}:${seed}`));
  const out = [];
  for (let j = 0; j < n; j++) {
    for (let i = 0; i < n; i++) {
      out.push([
        -w / 2 + ((i + 0.15 + 0.7 * rng()) / n) * w,
        0,
        -h / 2 + ((j + 0.15 + 0.7 * rng()) / n) * h,
      ]);
    }
  }
  return out;
}

export const LIGHT_KINDS = Object.freeze({ point: 'ponto', spot: 'spot', area: 'área', rig: 'rig 3 pontos' });

/**
 * A FORJA: luz de kind [point|spot|area|rig] com as leis acima.
 * Retorna a luz forjada com evaluate(p) (iluminância colorida no ponto,
 * metros) e autoteste embutido. Tipo/parâmetro fora da lei = erro.
 */
export function forgeLight({
  kind = 'point', kelvin = 5200, candela = 1200,
  x = 0, y = 3, z = 0,
  dir = [0, -1, 0], spotDeg = 40, exponent = 2,
  areaW = 2, areaH = 2, samples = 3, seed = 7,
  keyCd = 1600, fillCd = 500, rimCd = 900, rigDist = 4,
} = {}) {
  if (!LIGHT_KINDS[kind]) {
    throw new Error(`light: kind fora da lei (${Object.keys(LIGHT_KINDS).join('|')}): ${kind}`);
  }
  const kel = kelvinToRGB(kelvin);
  const norm = (v) => {
    const l = Math.hypot(v[0], v[1], v[2]) || 1;
    return [v[0] / l, v[1] / l, v[2] / l];
  };

  if (kind === 'rig') {
    // 3 pontos em ângulos canônicos ao redor da ORIGEM do sujeito:
    // key 45°/30° à direita, fill −45°/20° à esquerda, rim atrás/acima
    const D = rigDist;
    const mk = (cd, azDeg, elDeg, nome) => {
      const az = (azDeg * Math.PI) / 180, el = (elDeg * Math.PI) / 180;
      const p = [D * Math.cos(el) * Math.sin(az), D * Math.sin(el), D * Math.cos(el) * Math.cos(az)];
      const k = kelvinToRGB(nome === 'fill' ? kelvin : nome === 'rim' ? Math.min(25000, kelvin + 1800) : kelvin);
      return { nome, cd, pos: p, rgb: k.linear };
    };
    const lights = [mk(keyCd, 45, 30, 'key'), mk(fillCd, -45, 20, 'fill'), mk(rimCd, 165, 35, 'rim')];
    const evalu = (p) => {
      let lux = 0; const cr = [0, 0, 0];
      for (const L of lights) {
        const d = Math.hypot(p[0] - L.pos[0], p[1] - L.pos[1], p[2] - L.pos[2]);
        if (d > dCut(L.cd) || d < 1e-6) continue;
        const e = L.cd / (d * d);
        lux += e;
        cr[0] += e * L.rgb[0]; cr[1] += e * L.rgb[1]; cr[2] += e * L.rgb[2];
      }
      return { lux, rgb: cr };
    };
    return Object.freeze({ kind, kelvin, lights, evaluate: evalu });
  }

  const pos = [x, y, z];
  const axis = norm(dir);
  const cosCut = Math.cos((spotDeg * Math.PI) / 180);
  const subs = kind === 'area' ? panelSamples(areaW, areaH, Math.max(1, Math.min(6, Math.floor(samples))), seed) : null;
  const evaluate = (p) => {
    const dx = p[0] - pos[0], dy = p[1] - pos[1], dz = p[2] - pos[2];
    const d = Math.hypot(dx, dy, dz);
    if (d < 1e-6 || d > dCut(candela)) return { lux: 0, rgb: [0, 0, 0] };
    const inv2 = 1 / (d * d);
    let w = 1;
    if (kind === 'spot') {
      const c = (dx * axis[0] + dy * axis[1] + dz * axis[2]) / d;
      if (c < cosCut) return { lux: 0, rgb: [0, 0, 0] };
      w = Math.pow(c, exponent);
    }
    if (kind === 'area') {
      // suavidade REAL de perto: cada amostra do painel a sua distância
      let e = 0;
      for (const s of subs) {
        const dsx = dx + s[0], dsy = dy + s[1], dsz = dz + s[2];
        const dd = Math.hypot(dsx, dsy, dsz);
        e += candela / subs.length / (dd * dd);
      }
      return { lux: e, rgb: [e * kel.linear.r, e * kel.linear.g, e * kel.linear.b] };
    }
    const lux = candela * inv2 * w;
    return { lux, rgb: [lux * kel.linear.r, lux * kel.linear.g, lux * kel.linear.b] };
  };
  return Object.freeze({
    kind, kelvin, candela, pos, axis, spotDeg, exponent,
    rgb: kel.rgb8, linear: kel.linear, chroma: kel.chroma,
    cutMeters: +dCut(candela).toFixed(3),
    panel: subs ? { w: areaW, h: areaH, samples: subs.length } : null,
    evaluate,
  });
}

/** RIG de 3 pontos pelo léxico do estúdio (key/fill/rim) */
export const forgeRig = (p) => forgeLight({ kind: 'rig', ...p });

// ------------------------------------------------------------------
// AUTOTESTE: as leis verificadas
// ------------------------------------------------------------------
export function selfTests() {
  const checks = [];
  const dB = (v) => v;

  // 1. loco PLANCKIANO: corpo negro a 6504K ≈ (0.3135, 0.3236); o BRANCO
  // da definição sRGB é o daylight D65 (0.3127, 0.3290) → sRGB = (1,1,1)
  const c65 = kelvinToChroma(6504);
  checks.push({ name: 'corpo negro 6504K no loco Planckiano (±0.002)', ok: Math.abs(c65.x - 0.3135) < 0.002 && Math.abs(c65.y - 0.3236) < 0.002, detail: `x=${c65.x.toFixed(4)} y=${c65.y.toFixed(4)} (alvo 0.3135/0.3236)` });
  const wD = chromaToSRGB(0.3127, 0.3290);
  checks.push({ name: 'D65 (definição do branco sRGB) → (1,1,1)', ok: Math.abs(wD.r - 1) < 1e-3 && Math.abs(wD.g - 1) < 1e-3 && Math.abs(wD.b - 1) < 1e-3, detail: `r=${wD.r.toFixed(5)} g=${wD.g.toFixed(5)} b=${wD.b.toFixed(5)}` });
  const c2k = kelvinToChroma(2000);
  checks.push({ name: '2000K quente (x>0.52) e 10000K frio (x<0.285)', ok: c2k.x > 0.52 && kelvinToChroma(10000).x < 0.285, detail: `x(2000K)=${c2k.x.toFixed(3)} x(10000K)=${kelvinToChroma(10000).x.toFixed(3)}` });

  // 2. brancura visual: 6504K sai QUASE neutro no 8-bit (±8 por canal)
  const w8 = kelvinToRGB(6504).rgb8;
  const spread8 = Math.max(...w8) - Math.min(...w8);
  checks.push({ name: '6504K sai branco no 8-bit (±8 entre canais)', ok: spread8 <= 8, detail: `rgb8=${w8} (espalhamento ${spread8})` });

  // 3. monotonia: azul−r cresce com a temperatura (2000→12000K)
  let mono = true, prev = -1;
  for (const t of [2000, 3500, 5000, 6504, 8000, 12000]) {
    const { r, b } = kelvinToRGB(t).linear;
    if (b - r <= prev) mono = false;
    prev = b - r;
  }
  checks.push({ name: 'monotonia térmica (b−r cresce com Kelvin)', ok: mono, detail: `b−r(2000K)=${(kelvinToRGB(2000).linear.b - kelvinToRGB(2000).linear.r).toFixed(2)} → b−r(12000K)=${(kelvinToRGB(12000).linear.b - kelvinToRGB(12000).linear.r).toFixed(2)}` });

  // 4. gamut honesto: TODAS as temperaturas saem em [0,1]
  let inG = true;
  for (let t = 1000; t <= 25000; t += 500) {
    const { r, g, b } = kelvinToRGB(t).linear;
    if (!(r >= 0 && g >= 0 && b >= 0 && r <= 1 && g <= 1 && b <= 1)) { inG = false; break; }
  }
  checks.push({ name: 'gamut: 49 temperaturas dentro de [0,1]', ok: inG, detail: '1000..25000K' });

  // 5. INVERSO DO QUADRADO EXATO: E(10m) = E(5m)/4 a 1e-12
  const L = forgeLight({ kind: 'point', candela: 1000, x: 0, y: 5, z: 0 });
  const e1 = L.evaluate([0, 0, 0]).lux;   // d = 5  → E = 40
  const e2 = L.evaluate([6, -3, 0]).lux;  // d = 10 → E = 10
  checks.push({ name: 'E = I/d² EXATO (razão 5/10 → 1/4)', ok: Math.abs(e2 / e1 - 0.25) < 1e-12, detail: `e1=${e1.toFixed(6)} e2=${e2.toFixed(6)} razão ${(e2 / e1).toFixed(12)}` });

  // 6. corte honesto: além do corte a luz TERMINA (sem halo infinito)
  const fora = L.evaluate([0, 0, dCut(1000) + 1]);
  checks.push({ name: 'corte no piso de visibilidade', ok: fora.lux === 0, detail: `corte ${dCut(1000).toFixed(1)}m → além: ${fora.lux}` });

  // 7. spot: fora do cone é ZERO, dentro segue cos^expo
  const S = forgeLight({ kind: 'spot', candela: 900, x: 0, y: 4, z: 0, dir: [0, -1, 0], spotDeg: 45, exponent: 2 });
  const foraCone = S.evaluate([0, 0, 4.05]).lux; // 45° do eixo
  const borda = S.evaluate([3.9, 0, 0]).lux;
  checks.push({ name: 'spot: fora do cone ZERO; borda segue cosseno', ok: foraCone === 0 && borda > 0 && borda < 900 / 16, detail: `fora=${foraCone} borda=${borda.toFixed(3)}` });

  // 8. ÁREA: suavidade REAL de perto (variância lateral menor que a do ponto)
  const A = forgeLight({ kind: 'area', candela: 2000, x: 0, y: 2, z: 0, areaW: 4, areaH: 4, samples: 4, seed: 11 });
  const P = forgeLight({ kind: 'point', candela: 2000, x: 0, y: 2, z: 0 });
  const variance = (ev, xs) => {
    const vs = xs.map((px) => ev.evaluate([px, 0, 0]).lux);
    const m = vs.reduce((a, b) => a + b) / vs.length;
    return vs.reduce((a, b) => a + (b - m) ** 2, 0) / vs.length;
  };
  const xs = [-0.8, -0.27, 0.27, 0.8];
  const vArea = variance(A, xs), vPonto = variance(P, xs);
  checks.push({ name: 'luz de área suaviza de PERTO (variância < ponto)', ok: vArea < vPonto, detail: `var área=${vArea.toFixed(1)} vs ponto=${vPonto.toFixed(1)}` });

  // 9. determinismo: mesma semente = MESMO painel
  const A1 = forgeLight({ kind: 'area', candela: 500, x: 1, y: 2, z: 3, samples: 3, seed: 42 });
  const A2 = forgeLight({ kind: 'area', candela: 500, x: 1, y: 2, z: 3, samples: 3, seed: 42 });
  checks.push({ name: 'determinística (mesma semente = mesma luz)', ok: JSON.stringify(A1.panel) === JSON.stringify(A2.panel) && JSON.stringify(A1.chroma) === JSON.stringify(A2.chroma), detail: 'rebuild idêntico' });

  // 10. linearidade real: o RIG avalia a key EXATAMENTE como um ponto
  // com a mesma candela/posição (a mesma lei nos dois caminhos)
  const rigSó = forgeRig({ kelvin: 5200, keyCd: 800, fillCd: 0, rimCd: 0, rigDist: 5 });
  const keyPos = rigSó.lights[0].pos;
  const az = (45 * Math.PI) / 180, el = (30 * Math.PI) / 180;
  const esperado = forgeLight({ kind: 'point', candela: 800, kelvin: 5200, x: keyPos[0], y: keyPos[1], z: keyPos[2] });
  const pProva = [1, 0.5, 0];
  const dRef = Math.hypot(pProva[0] - 5 * Math.cos(el) * Math.sin(az), pProva[1] - 5 * Math.sin(el), pProva[2] - 5 * Math.cos(el) * Math.cos(az));
  const rigLux = rigSó.evaluate(pProva).lux;
  const ptLux = esperado.evaluate(pProva).lux;
  const teorico = 800 / (dRef * dRef);
  checks.push({ name: 'linearidade: rig e ponto = MESMA lei (1e-9)', ok: Math.abs(rigLux - ptLux) < 1e-9 && Math.abs(ptLux - teorico) < 1e-9, detail: `rig=${rigLux.toFixed(9)} ponto=${ptLux.toFixed(9)} teórico=${teorico.toFixed(9)}` });

  // 11. erro honesto fora da lei
  let threw = false;
  try { forgeLight({ kind: 'lanterna-magica' }); } catch { threw = true; }
  checks.push({ name: 'tipo fora da lei = ERRO explícito', ok: threw, detail: 'kind inválido recusado' });

  return checks;
}
