// UTS/UES GEN-1 — MATERIALIZAÇÃO VISÍVEL (último elo da cadeia do REAL UES l.855:
// ... → RRW → MATERIALIZAÇÃO → EXPERIÊNCIA).
//
// Por que isto existe: o kernel decidia e media, mas ninguém VIA o resultado, e
// "ninguém vê" é como um kernel vira fé. Este arquivo NÃO é um renderer — não há
// mesh, raster, framebuffer nem shader aqui. É a conversão do CAMPO materializado
// (luminância + croma por célula do Spatial Grid) em bytes de imagem, mantendo a
// célula visível: pixelar é declarar a granularidade da decisão, não escondê-la.
//
// Zero dependências, inclusive do browser: o PNG é escrito à mão (IHDR/IDAT/IEND
// + zlib do Node), porque um codificador de imagem é a única coisa desta stack que
// pode ser conferida byte a byte por quem não confia em nós.
import { deflateSync } from 'node:zlib';
import { makeDFrame, type DFrame } from '../../dframe/src/dframe.ts';
import { capsAt, ladderFor } from '../../d-system/src/ladders.ts';
import { materializeVisual, type MaterializedFrame } from './materialize.ts';

export interface RenderOptions {
  /** lado da imagem de saída em pixels (default 512) */
  size?: number;
  /** desenha a grade de células por cima do campo (default true) */
  grid?: boolean;
}

/**
 * Capacidade (escada) → chave da allowlist do Representation (contrato §4.2).
 *
 * É o mapa mais importante deste arquivo e ele existe por um motivo duro: o frame
 * não pode transportar "slope_shading: 1", porque a allowlist de chaves é o que
 * impede a deriva para mesh/texture/shader. Quem liga capacidade a CÓDIGO é esta
 * tabela; quem liga código a material é o materializador. Nenhum dos dois conhece
 * o terceiro, e é assim que a proibição do REAL UES l.11-17 sobrevive à implementação.
 */
const CAP_TO_REPR: Record<string, [string, unknown]> = {
  solid_fill: ['implicit_shape', 'block'],
  height_silhouette: ['heightfield_ref', 'hf:01'],
  slope_shading: ['heightfield_sample_rate', 0.4],
  material_class: ['material_class', 'soil_rock'],
  spectral_reflectance: ['spectral_band_code', 'vis_3band'],
  analytic_light: ['light_sample_rate', 0.5],
  per_entity_detail: ['detail_class', 'high'],
  projected_shadow: ['shadow_atlas_index', 1],
  matter_state: ['matter_state_code', 'wet'],
  global_illumination: ['light_sample_rate', 0.9],
  reflection: ['material_class', 'wet_rock'],
  sky_dispersion: ['sky_model', 'turbid'],
  participating_media: ['volume_sample_rate', 0.6],
};

/**
 * Compõe um frame do domínio `visual` no D pedido. A fonte das capacidades é a
 * ESCADA (capsAt) — existir uma segunda tabela de "o que cada D tem" aqui é como
 * um modelo mental divergente nasce entre materializador e otimizador.
 */
export function visualFrameAtD(D: number, opts: { entities?: number; tick?: number; regionId?: string; biome?: string } = {}): DFrame {
  const caps = capsAt('visual', D);
  // só biome_code é sempre presente (é o que dá identidade à célula, não
  // capacidade); tudo o mais entra POR CAPACIDADE — um frame D0 com heightfield_ref
  // seria um frame que afirma representar relevo que ele não materializa.
  const Representation: Record<string, unknown> = { biome_code: opts.biome ?? 'caatinga_dry' };
  for (const cap of caps) {
    const kv = CAP_TO_REPR[cap];
    if (!kv) continue; // capacidade ainda sem código correspondente: omitida, não inventada
    Representation[kv[0]] = kv[1];
  }
  const ents = opts.entities ?? 0;
  const tick = opts.tick ?? 0;
  const maxD = ladderFor('visual').steps.length - 1;
  return makeDFrame({
    regionId: opts.regionId ?? 'r:0,0',
    domain: 'visual',
    DCurrent: D,
    DTarget: maxD,
    Priority: 0.5,
    CostBudget: 100,
    Representation,
    QualityRequired: {
      QpMin: 0.9, QfMin: 0, QiMin: 0, minD: 0, maxD,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      // modo é obrigatório: requisito que não declara se é estimado ou medido não é
      // auditável, e a Gênesis não aceita "otimizado" sem medição (UTS l.2181).
      mode: 'ESTIMATE', overridden: false, reason: 'demo GEN-1: sem device.json medido',
    },
    // o que o D escolhido não carrega: a ledger de omissão é fato do frame, é ela
    // que o Qi cobra, e o humano tem de poder ler o que se deixou de representar.
    OmittedFacts: [...capsAt('visual', maxD)].filter((c) => !caps.has(c)),
    RecoverySet: ['biome_code', 'height_samples'],
    RecoveryRequired: [],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: D },
    // Entidades entram pelo STATE do mundo e pelo snapshot que o `present`
    // interpola. No frame visual elas só deixam pegada em chaves da allowlist — a
    // recusa de uma `position` aqui é a allowlist funcionando, não um detalhe a
    // contornar: quem pinta posição a partir do código é o RRW.
    // `entities: []` é um fato ("a célula não tem entidades vivas neste quadro");
    // omitir o campo é uma pergunta não respondida — o frame recusa o segundo.
    entities: Array.from({ length: ents }, (_, i) => ({
      id: `npc${i}`,
      delta: { matter_state_code: `state_${(i + tick) % 4}` },
    })),
  } as never);
}

/** Converte o campo materializado em RGBA8, com a célula visível. */
export function frameToRGBA(m: MaterializedFrame, opts: RenderOptions = {}): { w: number; h: number; data: Uint8Array } {
  const g = m.field.w;
  const size = opts.size ?? 512;
  const showGrid = opts.grid !== false;
  const cell = Math.max(1, Math.floor(size / g));
  // normalização de EXIBIÇÃO (stretch ao alcance do quadro): sem isto o campo
  // materializado — que vive em [0,0.15] — sai como um quadrado cinza e o olho não
  // compara nada. Quem mede qualidade é o Qp no campo bruto, nunca o PNG exibido;
  // a imagem mostra, o número decide.
  let lo = Infinity, hi = -Infinity;
  for (let i = 0; i < m.field.samples.length; i++) {
    const v = m.field.samples[i];
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  const span = hi - lo > 1e-9 ? hi - lo : 1;
  const out = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    const cy = Math.min(g - 1, Math.floor((y * g) / size));
    for (let x = 0; x < size; x++) {
      const cx = Math.min(g - 1, Math.floor((x * g) / size));
      const i = cy * g + cx;
      const L = Math.max(0, Math.min(1, (m.field.samples[i] - lo) / span));
      const r = m.chroma[i * 3], gr = m.chroma[i * 3 + 1], b = m.chroma[i * 3 + 2];
      // luminância é a grandeza; croma é a TINTA que a modula, nunca a substitui
      let R = L * (0.35 + 0.65 * r), G = L * (0.35 + 0.65 * gr), B = L * (0.35 + 0.65 * b);
      // o traço de grade só é honesto quando a célula tem largura suficiente para
      // ser lida como célula; com célula < 8 px ele viraria textura e mentiria
      // sobre a granularidade (que é justamente o que ele quer mostrar).
      if (showGrid && cell >= 8 && (x % cell === 0 || y % cell === 0)) { R *= 0.55; G *= 0.55; B *= 0.55; }
      const o = (y * size + x) * 4;
      out[o] = Math.round(255 * Math.min(1, Math.max(0, R)));
      out[o + 1] = Math.round(255 * Math.min(1, Math.max(0, G)));
      out[o + 2] = Math.round(255 * Math.min(1, Math.max(0, B)));
      out[o + 3] = 255;
    }
  }
  return { w: size, h: size, data: out };
}

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf: Uint8Array): number {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  // layout do PNG: length(4) · type(4) · data · CRC(4), e o CRC cobre type+data.
  // Errar aqui produz um arquivo que um parser tolerante até lê — e é exatamente
  // por isso que o teste abaixo confere o CRC de cada chunk, não só a assinatura.
  const out = new Uint8Array(8 + data.length + 4);
  const dv = new DataView(out.buffer);
  dv.setUint32(0, data.length);
  for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
  out.set(data, 8);
  dv.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

/** PNG truecolor 8-bit, filtro 0 por scanline — determinístico e verificável. */
export function encodePNG(rgba: { w: number; h: number; data: Uint8Array }): Uint8Array {
  const { w, h, data } = rgba;
  const stride = w * 4;
  const raw = new Uint8Array(h * (stride + 1));
  for (let y = 0; y < h; y++) {
    raw[y * (stride + 1)] = 0;
    raw.set(data.subarray(y * stride, (y + 1) * stride), y * (stride + 1) + 1);
  }
  const ihdr = new Uint8Array(13);
  const dv = new DataView(ihdr.buffer);
  dv.setUint32(0, w); dv.setUint32(4, h);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const parts = [
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 6 })),
    chunk('IEND', new Uint8Array(0)),
  ];
  let o = 0;
  const out = new Uint8Array(parts.reduce((a, p) => a + p.length, 0));
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

/** uma imagem por frame, lado a lado — "o D é escolha por célula, não preset" à vista */
export function contactSheetPNG(frames: ReadonlyArray<DFrame>, opts: RenderOptions & { gridSize?: number; size?: number } = {}): Uint8Array {
  const size = opts.size ?? 256;
  const cols = Math.max(1, Math.ceil(Math.sqrt(frames.length)));
  const rows = Math.max(1, Math.ceil(frames.length / cols));
  const w = cols * size, h = rows * size;
  const data = new Uint8Array(w * h * 4);
  for (let f = 0; f < frames.length; f++) {
    const img = frameToRGBA(materializeVisual(frames[f], { gridSize: opts.gridSize }), { ...opts, size });
    const cx = (f % cols) * size, cy = Math.floor(f / cols) * size;
    for (let y = 0; y < size; y++) data.set(img.data.subarray(y * size * 4, (y + 1) * size * 4), ((cy + y) * w + cx) * 4);
  }
  return encodePNG({ w, h, data });
}

/** atalho: frame → imagem PNG (o que o olho confere, com o Qp medido ao lado) */
export function renderDFrame(frame: DFrame, opts: RenderOptions & { gridSize?: number } = {}): Uint8Array {
  return encodePNG(frameToRGBA(materializeVisual(frame, { gridSize: opts.gridSize }), opts));
}
