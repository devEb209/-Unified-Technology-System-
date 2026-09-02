// Esquema do DFrame. Alterar isto é alterar o contrato entre decisão e
// materialização — por isso o versionamento é obrigatório (contrato §5.4).

export const SCHEMA_VERSION = 1;
export const ENGINE_VERSION = '0.1.0-genesis';

/**
 * Allowlist do campo `Representation` (contrato §4.2).
 *
 * É a única forma de a proibição do `REAL UES:11-17` sobreviver à implementação:
 * declaração não impede deriva, tipo impede. Nada aqui é um objeto de cena.
 */
export const REPRESENTATION_KEY_TYPES: Record<string, 'number' | 'integer' | 'enum' | 'id' | 'code'> = {
  heightfield_ref: 'id', // referência a um campo de elevação, não o campo
  heightfield_sample_rate: 'number',
  biome_code: 'code',
  material_class: 'code',
  spectral_band_code: 'code',
  implicit_shape: 'enum',
  light_sample_rate: 'number',
  volume_sample_rate: 'number',
  shadow_atlas_index: 'integer',
  detail_class: 'enum',
  matter_state_code: 'code',
  sky_model: 'enum',
};

/** Chaves proibidas em qualquer nível do frame, independentemente do valor. */
export const FORBIDDEN_KEYS = [
  'mesh',
  'vertices',
  'vertex_buffer',
  'texels',
  'texture_data',
  'shader_source',
  'shader_bytecode',
  'pipeline_state',
  'draw_call',
  'draw_calls',
  'index_buffer',
  'scene_graph',
] as const;

/**
 * Limites de materialização: resolução interna é um RECURSO sob decisão do
 * D-O15, não um preset. Estes valores são as razões de escala usadas pela
 * GÊNESIS para converter "pixels" em trabalho, calibráveis pelo plano do
 * dispositivo.
 */
export interface DeviceLimits {
  id: string;
  width: number;
  height: number;
  /** Fator de render interno permitido pela política de Qp (0..1]. */
  maxInternalScale: number;
  /** Orçamento de trabalho por frame, nas unidades de custo da escada. */
  frameBudget: number;
  /** Bytes utilizáveis pela app (não é a RAM total do aparelho). */
  appMemoryBytes: number;
  /** Regras da Tese §69/§70: nada disto é Q. */
  notes?: string;
}

/** Perfil medido pelo `kairos-plan`/plano do dispositivo — nunca assumido. */
export interface ResourceContext {
  device: DeviceLimits;
  thermal: 'nominal' | 'throttling' | 'critical';
  batterySaver: boolean;
  headroom: number; // 0..1, folga medida no frame anterior
}

export const RESOURCE_RULES = {
  /** Tese §70: Q jamais é expresso por estas grandezas. */
  forbiddenAsQuality: ['fps', 'ram', 'resolution', 'polygons', 'clock'],
  /** Tese §69: são contexto que INFLUENCIA a escolha de D, não o D. */
  resourceFields: ['frameBudget', 'headroom', 'thermal', 'batterySaver'],
} as const;
