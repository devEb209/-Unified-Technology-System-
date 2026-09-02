import type { DFrame } from '../../dframe/src/dframe.ts';
import type { Domain } from '../../d-system/src/types.ts';
import { capsAt } from '../../d-system/src/ladders.ts';
import { heightAt, codeValue, h32, vnoise } from './hash.ts';

export interface LuminanceGrid {
  readonly w: number;
  readonly h: number;
  readonly D: number;
  /** Luminância normalizada [0,1] da célula (raster ainda não existe aqui — ver nota do arquivo). */
  readonly samples: Float64Array;
}

export interface MaterializedFrame {
  readonly field: LuminanceGrid;
  /** RGB por célula (croma). Mantido separado: modulação multiplicativa não entra na soma. */
  readonly chroma: Float64Array;
  readonly caps: readonly string[];
  /** Custo real da materialização, para fechar o laço estimativa↔medição (I6). */
  readonly cells: number;
}

export interface MaterializeOptions {
  /** Lado da grade amostrada. Célula = região do Spatial Grid, nunca entidade. */
  gridSize?: number;
  /** Conjunto de capacidades efetivo. Default: derivado do D pela escada. */
  caps?: readonly string[];
}

/**
 * MATERIALIZAÇÃO (elo 7 da cadeia do REAL UES l.855).
 *
 * Isto NÃO é um renderer: não há mesh, raster, framebuffer nem shader. O que
 * existe aqui é a primeira coisa que pode existir antes do GPU — a função que
 * pega os CÓDIGOS SEMÂNTICOS do DFrame e devê informação luminosa por célula,
 * no granularidade em que a decisão foi tomada. O backend GL consome o campo,
 * não o contrário; por isso o campo é definido sem conhecer o backend.
 *
 * A regra estrutural é a do §37 (conversão): cada capability adiciona UM termo
 * determinístico ao campo, derivado do código + da posição da célula. Remover
 * uma capacidade remove um termo — e é isto que Qp mede depois.
 */
export function materializeVisual(frame: DFrame, opts: MaterializeOptions = {}): MaterializedFrame {
  if (frame.domain !== 'visual') {
    throw new MaterializeError('MAT_DOMAIN_MISMATCH', `materializeVisual recebeu um frame do domínio "${frame.domain}"`);
  }
  const g = opts.gridSize ?? 32;
  if (!Number.isInteger(g) || g < 4 || g > 512) {
    throw new MaterializeError('MAT_GRID_SIZE', `gridSize=${g} fora de [4,512] — grade de decisão não é tela`);
  }
  // a fonte das capacidades é a ESCADA (d-system), não uma tabela paralela
  const caps = new Set<string>(opts.caps ?? capsAt('visual', frame.DCurrent));
  const r = frame.Representation as Record<string, unknown>;
  const biome = r.biome_code as string | number | undefined;
  const ref = codeValue(r.heightfield_ref as string | number | undefined) * 64;
  const sampleRate = typeof r.heightfield_sample_rate === 'number' ? r.heightfield_sample_rate : 0;
  const shadowAtlas = typeof r.shadow_atlas_index === 'number' ? r.shadow_atlas_index : 0;
  const lightRate = typeof r.light_sample_rate === 'number' ? r.light_sample_rate : 0;
  const volRate = typeof r.volume_sample_rate === 'number' ? r.volume_sample_rate : 0;
  const entityCount = frame.entities?.length ?? 0;
  const step = Math.max(1, Math.floor(g / (1 + Math.floor(Math.sqrt(entityCount)) * 2)));
  const blob = Math.max(1, step >> 1);

  const n = g * g;
  const lum = new Float64Array(n);
  const chr = new Float64Array(n * 3);
  const heights = new Float64Array(n);

  // INVARIANTE DESTE ARQUIVO (e o que torna Qp monotônico por construção):
  // cada capacidade adiciona um termo NÃO-NEGATIVO e não altera os anteriores.
  // Modulação multiplicativa (matéria molhada, reflexo que escurece) vai para o
  // campo de CROMA, nunca para a soma. Assum em [0,1] preserva a monotonicidade.
  for (let y = 0; y < g; y++) {
    for (let x = 0; x < g; x++) {
      const i = y * g + x;
      heights[i] = caps.has('height_silhouette') ? heightAt(x, y, biome, ref) : 0.5;
      lum[i] = caps.has('solid_fill') ? 0.12 + biomeTone(biome) : 0;
    }
  }
  const add = (i: number, v: number) => {
    if (v > 0) lum[i] += v;
  };
  const tone = (i: number, dr: number, dg: number, db: number) => {
    chr[i * 3] = Math.min(1, Math.max(0, chr[i * 3] + dr));
    chr[i * 3 + 1] = Math.min(1, Math.max(0, chr[i * 3 + 1] + dg));
    chr[i * 3 + 2] = Math.min(1, Math.max(0, chr[i * 3 + 2] + db));
  };

  if (caps.has('height_silhouette')) {
    for (let i = 0; i < n; i++) add(i, heightGain(sampleRate) * Math.max(0, heights[i] - 0.4));
  }
  if (caps.has('slope_shading')) {
    for (let y = 0; y < g; y++) {
      for (let x = 0; x < g; x++) {
        const i = y * g + x;
        const dx = heights[Math.min(n - 1, i + 1)] - heights[i];
        const dy = heights[Math.min(n - 1, i + g)] - heights[i];
        add(i, heightGain(sampleRate) * Math.max(0, 0.5 - (Math.abs(dx) + Math.abs(dy)) * 4));
      }
    }
  }
  if (caps.has('solid_fill')) {
    for (let i = 0; i < n; i++) chr[i * 3 + 2] = 0.05 + 0.1 * codeValue(biome);
  }
  if (caps.has('material_class')) {
    for (let i = 0; i < n; i++) add(i, 0.05 * vnoise((i % g) * 0.5, ((i / g) | 0) * 0.5, 13));
  }
  if (caps.has('spectral_reflectance')) {
    for (let i = 0; i < n; i++) tone(i, 0.04, 0.02, -0.03 < 0 ? 0 : 0.03);
  }
  if (caps.has('analytic_light')) {
    for (let i = 0; i < n; i++) add(i, 0.06 * (0.5 + 0.5 * ((i % g) / g)) * (1 + lightRate));
  }
  if (caps.has('projected_shadow')) {
    // oclusão analítica pelo próprio campo de altura: sem mesh, sem depth buffer.
    // Empurra o lado ensombrado para a banda de luz recebida, preservando a
    // monotonicidade (é um termo aditivo do lado iluminado, não uma subtração).
    const dir = 1 + (shadowAtlas & 3);
    for (let y = 0; y < g; y++) {
      for (let x = 0; x < g; x++) {
        const sx = Math.min(g - 1, Math.max(0, x - dir));
        if (heights[y * g + sx] > 0.62) add(y * g + Math.min(g - 1, x + dir), 0.05);
      }
    }
  }
  if (caps.has('per_entity_detail')) {
    for (let e = 0; e < entityCount; e++) {
      const ex = (e * step) % g;
      const ey = Math.floor((e * step) / g) % g;
      for (let dy = 0; dy < blob; dy++) {
        for (let dx = 0; dx < blob; dx++) add(((ey + dy) % g) * g + ((ex + dx) % g), 0.08 + 0.1 * h32(dx, dy, 11 + e));
      }
    }
  }
  if (caps.has('matter_state')) {
    for (let e = 0; e < entityCount; e++) {
      const delta = (frame.entities?.[e]?.delta ?? {}) as Record<string, unknown>;
      const wet = codeValue(delta.matter_state_code as string | number | undefined);
      const ex = (e * step) % g;
      const ey = Math.floor((e * step) / g) % g;
      for (let dy = 0; dy < blob; dy++) {
        for (let dx = 0; dx < blob; dx++) tone(((ey + dy) % g) * g + ((ex + dx) % g), 0, 0.02 * wet, 0.05 * wet);
      }
    }
  }
  if (caps.has('global_illumination')) {
    for (let i = 0; i < n; i++) add(i, 0.08 * Math.max(0, 0.5 - heights[i]));
  }
  if (caps.has('reflection')) {
    for (let i = 0; i < n; i++) add(i, 0.04 * h32(i % g, (i / g) | 0, 5));
  }
  if (caps.has('sky_dispersion')) {
    for (let y = 0; y < g; y++) for (let x = 0; x < g; x++) add(y * g + x, 0.03 * (1 - y / g));
  }
  if (caps.has('participating_media')) {
    for (let i = 0; i < n; i++) add(i, 0.06 * volRate * vnoise((i % g) * 0.3, ((i / g) | 0) * 0.3, 3));
  }
  for (let i = 0; i < n; i++) lum[i] = Math.min(1, lum[i] / Math.max(1, MAX_ACCUM));
  for (let i = 0; i < n; i++) for (let c = 0; c < 3; c++) chr[i * 3 + c] = Math.min(1, chr[i * 3 + c]);

  return { field: { w: g, h: g, D: frame.DCurrent, samples: lum }, chroma: chr, caps: [...caps], cells: n };
}

/** Soma máxima acumulável, para normalizar sem quebrar a monotonicidade. */
const MAX_ACCUM = 1 + 0.55;

function heightGain(sampleRate: number): number {
  return sampleRate > 0 ? Math.min(1, 0.35 + 0.65 * sampleRate) : 0;
}

/**
 * Capacidades efetivas do degrau. Delega à escada: existir uma segunda fonte de
 * verdade aqui (uma tabela de "o que cada D tem") é exatamente como um modelo
 * mental divergente nasce entre o materializador e o validador.
 */
export function capsForDomain(domain: Domain, D: number): readonly string[] {
  return capsAt(domain, D);
}

function biomeTone(code: string | number | undefined): number {
  return 0.28 + 0.34 * codeValue(code);
}

export class MaterializeError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(`${code}: ${message}`);
    this.code = code;
    this.name = 'MaterializeError';
  }
}
