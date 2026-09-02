// UTS/UES — MATERIALIZAÇÃO DE TERRENO
//
// Terreno aqui não é malha nem altura importada: é um CAMPO com leis. Cada degrau da
// escada `terrain` liga UMA lei de formação (orogenia → hidrologia → gravidade do
// solo → clima → deformação), e a materialização é O(células da região), nunca
// O(entidades) — o mesmo princípio que já matou os 216 ms/tick do `UTS.txt` l.326-331.
//
// Por que isto importa para "construir a realidade": no pipeline tradicional o relevo
// é um ASSET que alguém pintou, e o motor só obedece. Aqui o relevo é uma CONSEQUÊNCIA
// de leis ativas, o que dá duas coisas que preset nenhum dá: (a) neve, rio e encosta
// instável aparecem nos lugares certos sem ninguém marcá-los; (b) o que o jogador faz
// ao terreno no D5 é FATO persistente, não decalque em textura.
import { capsAt, ladderFor } from '../../d-system/src/ladders.ts';
import { makeDFrame, type DFrame } from '../../dframe/src/dframe.ts';

export interface TerrainField {
  readonly g: number;
  readonly D: number;
  /** altitude em metros (0 quando a lei de relevo ainda não está ativa) */
  readonly elevation: Float64Array;
  /** água acumulada por célula (fluxo downhill); 0 sem hidrologia */
  readonly flow: Float64Array;
  /** máscara: 1 = água parada (lago), 0 = seco */
  readonly water: Float64Array;
  /** 0 = indefinido, 1 = rocha, 2 = solo, 3 = areia */
  readonly material: Uint8Array;
  /** true = encosta acima do ângulo de repouso do material (instável) */
  readonly unstable: Uint8Array;
  /** temperatura (°C) e umidade relativas [0,1]; 0/0 sem clima */
  readonly temperature: Float64Array;
  readonly moisture: Float64Array;
  /** código de zona de vegetação, derivado de clima (não pintado) */
  readonly vegetation: string[];
  readonly caps: readonly string[];
  /** trabalho cobrado: células de campo (o canal `perVolume` da escada) */
  readonly cells: number;
}

export interface TerrainOptions {
  gridSize?: number;
  /** espaçamento físico da célula em metros (define inclinação real) */
  cellSize?: number;
  /**
   * extensão física do DOMÍNIO em metros (o mundo, não a resolução amostrada).
   * Sem isto, a latitude do modelo inteiro viria de `g × cellSize` e uma cordilheira
   * de 48 amostras teria 190 m de largura — clima sairia "plano" por construção. A
   * extensão é do mundo; a grade é só com que frequência ela é consultada.
   */
  domainMeters?: number;
  /**
   * amplitude do relevo em metros. Default: proporcional à altitude de base do bioma.
   * Explicitar é o que a cena deve fazer, porque amplitude e ESPAÇAMENTO da grade são
   * grandezas independentes: deixar a amplitude presa ao cellSize faz um mundo de
   * 60 km amostrado a cada 4 m virar parede vertical de 1700° — que é o que a
   * primeira versão deste arquivo fazia, e o ângulo de repouso não consertou nada.
   */
  reliefM?: number;
  /**
   * MEIA-amplitude latitudinal do domínio, em graus. Default: derivada de
   * `gridSize × cellSize` (o que o mundo realmente mede), NUNCA de `domainMeters`.
   * Errar isso é o que fazia uma cena de 48×48 células de 4 m ter 270 km de latitude
   * e nevar a −730 °C: extensão de consulta e extensão geográfica são grandezas
   * diferentes, e quando uma é usada para calcular a outra o clima vira decorativo.
   */
  latitudeSpanDeg?: number;
  /** semente do campo — determinismo é contrato, não sorteio */
  seed?: string;
  /** deformações acumuladas (crateras, escavação de tsunami), em ordem de aplicação */
  deformations?: ReadonlyArray<{ x: number; y: number; radius: number; depth: number }>;
}

const LATITUDE_KM = 111; // graus de latitude ≈ 111 km, usado para o gradiente de clima
/** gradiente térmico padrão do ar (°C por km de altitude) */
const LAPSE_C_PER_KM = 6.5;
/**
 * Limite de neperenidade: a linha de neve EQUATORIAL é ~4.700 m, não um número que
 * alguém escolhe por bioma. Ela sai da MESMA fórmula da temperatura — o que faz a
 * neve aparecer onde deve em vez de ser pintada — e por isso é uma constante física
 * aqui, não um parâmetro de cena (a cena escolhe altitude e latitude, não onde neva).
 */
const SNOWLINE_ELEVATION_M = 4700;

function hash2(x: number, y: number, s: number): number {
  let h = (x | 0) * 374761393 + (y | 0) * 668265263 + s * 1274126177;
  h = (h ^ (h >>> 13)) >>> 0;
  h = (h * 1274126177) >>> 0;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

function vnoise2(x: number, y: number, s: number): number {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash2(xi, yi, s), b = hash2(xi + 1, yi, s), c = hash2(xi, yi + 1, s), d = hash2(xi + 1, yi + 1, s);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
}

/** fBm com cristas (1−|·|): forma cordilheira sem mesh nem asset. */
function fbmRidge(x: number, y: number, oct: number, freq: number, seed: number, ridged: boolean): number {
  let amp = 1, f = freq, sum = 0, norm = 0;
  for (let o = 0; o < oct; o++) {
    const n = vnoise2(x * f, y * f, seed + o * 131);
    sum += (ridged ? 1 - Math.abs(n * 2 - 1) : n) * amp;
    norm += amp;
    amp *= 0.5;
    f *= 2.03; // não-duplo para quebrar alinhamento de eixos
  }
  return sum / norm;
}

export function materializeTerrain(frame: DFrame, opts: TerrainOptions = {}): TerrainField {
  if (frame.domain !== 'terrain') {
    throw new Error(`TERRAIN_DOMAIN_MISMATCH: materializeTerrain recebeu domínio "${frame.domain}"`);
  }
  const g = opts.gridSize ?? 32;
  if (!Number.isInteger(g) || g < 4 || g > 256) throw new Error(`TERRAIN_GRID_SIZE: g=${g} fora de [4,256] — grade de decisão não é textura`);
  const cell = opts.cellSize ?? 120;
  const domainM = opts.domainMeters ?? Math.max(g * cell, 12000);
  const n = g * g;
  const caps = new Set<string>(capsAt('terrain', frame.DCurrent));
  const seedNum = hashOf(opts.seed ?? 'uts');

  const elev = new Float64Array(n);
  const flow = new Float64Array(n);
  const water = new Float64Array(n);
  const material = new Uint8Array(n);
  const unstable = new Uint8Array(n);
  const temp = new Float64Array(n);
  const moist = new Float64Array(n);
  const vegetation: string[] = new Array(n).fill('none');

  // D1 — orogenia: altura existe como campo, com base do bioma por baixo
  if (caps.has('heightfield_fractal')) {
    const base = baseElevation(frame);
    for (let y = 0; y < g; y++) {
      for (let x = 0; x < g; x++) {
        const t = fbmRidge(x, y, 5, 1 / 9, seedNum, true);
        const valleys = fbmRidge(x, y, 3, 1 / 5, seedNum + 7, false);
        // amplitude relativa à ALTITUDE DE BASE do bioma: planície não ganha montanha
        // de 240 m do nada, e uma cordilheira de 2600 m não fica com rugosidade de
        // morro. Um número fixo de amplitude era o tipo de constante que faz o campo
        // parecer "terreno" sem nunca escalar com o que a cena pede.
        elev[y * g + x] = base + (t * 0.75 + valleys * 0.25) * (opts.reliefM ?? Math.max(120, base * 0.25));
      }
    }
  } else {
    const base = baseElevation(frame);
    for (let i = 0; i < n; i++) elev[i] = base;
  }

  // D5 — deformação contínua: o histórico do que aconteceu no terreno
  if (caps.has('dynamic_deformation') && opts.deformations?.length) {
    for (const d of opts.deformations) {
      const cx = d.x * g, cy = d.y * g, r = Math.max(1, d.radius * g);
      for (let y = 0; y < g; y++) {
        for (let x = 0; x < g; x++) {
          const dd = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
          if (dd >= r) continue;
          const k = 0.5 + 0.5 * Math.cos((dd / r) * Math.PI); // borda suave, centro fundo
          elev[y * g + x] -= d.depth * k;
        }
      }
    }
  }

  // D2 — hidrologia: acumulação de fluxo downhill com desempate determinístico, e
  // lago onde a água não tem para onde descer (sem "depressão mágica" escondida).
  if (caps.has('hydrology')) {
    // Duas fases, e é a fase que torna o resultado honesto: o ROTEAMENTO é decidido
    // contra uma cópia congelada da altura, e a erosão é acumulada num campo próprio
    // aplicado no fim. Mutar `elev` durante o passeio faria a ordem de sortear
    // depender do que já foi cortado — o rio passaria a cavar o próprio leito
    // retroativamente e o mesmo frame deixaria de ser determinístico.
    const route = Float64Array.from(elev);
    const cut = new Float64Array(n);
    const order = Array.from({ length: n }, (_, i) => i).sort((a, b) => route[b] - route[a] || a - b);
    for (const i of order) flow[i] += 1;
    for (const i of order) {
      if (flow[i] <= 0) continue;
      const x = i % g, y = (i / g) | 0;
      let best = -1;
      let bestH = route[i];
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= g || ny >= g) continue;
          const j = ny * g + nx;
          if (route[j] < bestH) { bestH = route[j]; best = j; }
        }
      }
      if (best < 0) {
        water[i] = Math.min(1, flow[i] / Math.max(8, n * 0.02)); // fechou: é lago
        continue;
      }
      // o corte é pago com o fluxo ANTES de transferi-lo (cobrar depois dava sempre 0
      // — bug que sobreviveu ao primeiro teste porque "média igual" também é verdade
      // quando a lei não roda)
      if (caps.has('sediment_transport')) cut[best] += Math.min(6, flow[i] * 0.05);
      flow[best] += flow[i];
      flow[i] = 0;
    }
    if (caps.has('sediment_transport')) {
      for (let i = 0; i < n; i++) if (cut[i] > 0) elev[i] -= cut[i]; // conservação: a
      // sedimentação aparece como deposição na foz, não como desaparecimento de massa
      const mouths = order.filter((i) => flow[i] > 0);
      for (const i of mouths) for (const d of [-1, 1]) {
        const j = i + d;
        if (j >= 0 && j < n && j % g === i % g) elev[j] += cut[i] * 0.002;
      }
    }
  }

  // D3 — material e ângulo de repouso: o declive decide a classe, e encosta acima do
  // limite do material é marcada como instável em vez de ser suavizada pelo artista.
  if (caps.has('material_class') || caps.has('angle_of_repose')) {
    for (let y = 0; y < g; y++) {
      for (let x = 0; x < g; x++) {
        const i = y * g + x;
        const dx = elev[Math.min(n - 1, i + 1)] - elev[i];
        const dy = elev[Math.min(n - 1, i + g)] - elev[i];
        const slopeDeg = (Math.atan(Math.hypot(dx, dy) / (cell * (g > 1 ? 1 : 1))) * 180) / Math.PI;
        if (caps.has('angle_of_repose')) {
          const m = water[i] > 0 ? 3 : slopeDeg > 38 ? 1 : slopeDeg > 14 ? 2 : flow[i] > 4 ? 3 : 2;
          material[i] = m as 0 | 1 | 2 | 3;
          const repose = [0, 90, 34, 30][m]; // rocha segura quase tudo; areia não
          unstable[i] = slopeDeg > repose ? 1 : 0;
        } else {
          material[i] = (water[i] > 0 ? 3 : slopeDeg > 30 ? 1 : 2) as 0 | 1 | 2 | 3;
        }
      }
    }
  }

  // D4 — clima: temperatura com gradiente altimétrico e de latitude, umidade pelo
  // fluxo, e zona de vegetação DERIVADA dos dois (é isto que faz neve ficar onde deve).
  if (caps.has('climate_zones')) {
    for (let y = 0; y < g; y++) {
      for (let x = 0; x < g; x++) {
        const i = y * g + x;
        const latSpanDeg = opts.latitudeSpanDeg ?? ((g - 1) * cell) / (2 * LATITUDE_KM);
        const latKm = ((y / Math.max(1, g - 1)) * 2 - 1) * latSpanDeg * LATITUDE_KM;
        const t = 28 - LAPSE_C_PER_KM * (elev[i] / 1000) - 0.55 * Math.abs(latKm);
        temp[i] = t;
        moist[i] = Math.min(1, 0.15 + (caps.has('hydrology') ? Math.min(1, flow[i] / 40) : 0.2) + (t > 4 ? 0.1 : 0));
        if (caps.has('vegetation_zones')) {
          vegetation[i] = elev[i] > SNOWLINE_ELEVATION_M
            ? 'snow'
            : t < 2
              ? 'tundra'
              : t < 6
                ? 'conifer'
                : moist[i] > 0.7
                  ? 'forest'
                  : moist[i] > 0.35
                    ? 'shrub'
                    : 'bare';
        }
      }
    }
  }

  return {
    g,
    D: frame.DCurrent,
    elevation: elev,
    flow,
    water,
    material,
    unstable,
    temperature: temp,
    moisture: moist,
    vegetation,
    caps: [...caps],
    cells: n,
  };
}

function baseElevation(frame: DFrame): number {
  const r = frame.Representation as Record<string, unknown>;
  // a altitude declarada no frame MANDA sobre a tabela de bioma: tabela é default,
  // não oráculo — senão o materializador estaria corrigindo a cena em vez de
  // materializá-la (e o clima sairia derivado de um chute nosso).
  const declared = r.base_altitude_m;
  if (typeof declared === 'number' && Number.isFinite(declared)) return Math.max(0, declared);
  const code = String(r.biome_code ?? 'default');
  // elevação-base por bioma vem do código, não de um campo paralelo: é o §37
  // (conversão) aplicado ao ponto mais bobo — bioma "planície" não pode nascer a 2 km.
  const table: Record<string, number> = { caatinga_dry: 240, floodplain: 8, plateau: 900, coast: 2, mountain: 2600, default: 200 };
  return table[code] ?? 200;
}

function hashOf(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = ((h ^ s.charCodeAt(i)) * 16777619) >>> 0;
  return h % 65521;
}

/** Compõe um frame do domínio `terrain` no D pedido (a escada é a única fonte). */
export function terrainFrameAtD(D: number, opts: { biome?: string; regionId?: string; deformations?: number; baseAltitudeM?: number } = {}): DFrame {
  const maxD = ladderFor('terrain').steps.length - 1;
  const Representation: Record<string, unknown> = { biome_code: opts.biome ?? 'plateau' };
  if (opts.baseAltitudeM !== undefined) Representation.base_altitude_m = opts.baseAltitudeM;
  if (D >= 1) Representation.heightfield_ref = `hf:${opts.biome ?? 'plateau'}:${D}`;
  return makeDFrame({
    regionId: opts.regionId ?? 'r:0,0',
    domain: 'terrain',
    DCurrent: D,
    DTarget: D,
    Priority: 0.5,
    CostBudget: 100,
    Representation,
    QualityRequired: {
      QpMin: 0, QfMin: 0, QiMin: 0, minD: 0, maxD,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      mode: 'ESTIMATE', overridden: false, reason: 'terreno GEN-1: leis ativas, não altura pintada',
    },
    OmittedFacts: [...capsAt('terrain', maxD)].filter((c) => !capsAt('terrain', D).has(c)),
    RecoverySet: ['biome_code'],
    RecoveryRequired: [],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: D },
    entities: Array.from({ length: opts.deformations ?? 0 }, (_, i) => ({
      id: `def${i}`,
      delta: { matter_state_code: `scour_${i % 4}` },
    })),
  } as never);
}

/** Conversão §37: o que `terrain` produz é o que `physical` consome em D2/D3. */
export function restHeightAt(field: TerrainField, u: number, v: number): number {
  const g = field.g;
  const x = Math.min(g - 1, Math.max(0, Math.floor(u * g)));
  const y = Math.min(g - 1, Math.max(0, Math.floor(v * g)));
  return field.elevation[y * g + x];
}

/** Altura interpolada (bicubic-lite: bilinear) — contato não pode quicar na célula. */
export function surfaceHeightAt(field: TerrainField, u: number, v: number): number {
  const g = field.g;
  const fx = Math.min(g - 1e-6, Math.max(0, u * (g - 1)));
  const fy = Math.min(g - 1e-6, Math.max(0, v * (g - 1)));
  const x0 = Math.floor(fx), y0 = Math.floor(fy);
  const tx = fx - x0, ty = fy - y0;
  const h = (x: number, y: number) => field.elevation[y * g + x];
  const a = h(x0, y0) * (1 - tx) + h(Math.min(g - 1, x0 + 1), y0) * tx;
  const b = h(x0, Math.min(g - 1, y0 + 1)) * (1 - tx) + h(Math.min(g - 1, x0 + 1), Math.min(g - 1, y0 + 1)) * tx;
  return a * (1 - ty) + b * ty;
}
