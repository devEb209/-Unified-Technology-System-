// Tipos centrais da Tese dos D operacionalizada.
// Contrato: docs/canonical/Q-System-e-DFrame.md
// Regra do repositório: zero dependências, núcleo testável em CPU, Node 22.

export const DOMAINS = [
  'visual',
  'physical',
  'behavioral',
  'social',
  'economic',
  'temporal',
] as const;

export type Domain = (typeof DOMAINS)[number];

/** Domínios com escada definida nesta geração (GÊNESIS). Os demais são slots do contrato. */
export const GEN1_DOMAINS: readonly Domain[] = ['visual', 'physical', 'temporal'];

/**
 * Classes de qualidade (Tese §16). A tri-partição precisa ser declarada por
 * dados, não por hábito — ver invariante I8 do contrato.
 */
export const Q_CLASSES = ['PERCEPTUAL', 'FUNCTIONAL', 'INFORMATIONAL'] as const;
export type QClass = (typeof Q_CLASSES)[number];

/** Como um valor de Q foi obtido. Requisito sem modo é rejeitado (contrato §2.4). */
export const Q_MODES = ['ESTIMATE', 'MEASURE'] as const;
export type QMode = (typeof Q_MODES)[number];

/**
 * Custo por passo de representação. É uma RELAÇÃO declarada, não uma constante:
 * `perPixel` multiplica o fill da região (largura de banda / framebuffer),
 * `perEntity` multiplica entidades materializadas, `fixed` é o piso do sistema.
 * Nada aqui é FPS, RAM ou resolução — Tese §70.
 */
export interface CostRelation {
  fixed: number;
  perPixel: number;
  perEntity: number;
}

export interface QualityProfile {
  /** Fração da região sob limiar perceptual (0..1]. */
  Qp: number;
  /** Suficiência funcional (0..1]. */
  Qf: number;
  /** Integridade informacional reconstruível (0..1]. */
  Qi: number;
  /** O que este passo mede de fato, por componente. Exigido pelo I8. */
  class: Record<'Qp' | 'Qf' | 'Qi', QClass>;
  /** Operador de medida nomeado, resolvido em runtime. Exigido pelo §98.1. */
  operators: Record<'Qp' | 'Qf' | 'Qi', string>;
}

/** Um degrau da escada de D de um domínio. */
export interface DStep {
  D: number;
  name: string;
  description: string;
  quality: QualityProfile;
  cost: CostRelation & { perLight?: number; perVolume?: number };
  /**
   * Capacidades que este degrau oferece. Cumulativa por definição de escada:
   * subir de D nunca remove capacidade (invariante M2). É isto que torna Q
   * monotônico por construção em vez de por promessa.
   */
  caps: readonly string[];
  /**
   * Tese §80/§81 + contrato §4.3: tipos de fato que este degrau é capaz de
   * reconstruir a partir do estado preservado. Qi é avaliado contra isto.
   */
  recoverable: readonly string[];
  /**
   * Dependências entre domínios (Tese §8). Não é decorativo: materializar
   * visual em D alto sobre física abstrata é incoerência, e o contrato exige
   * que incoerência seja detectável.
   */
  prereq?: Partial<Record<Domain, number>>;
  /** Tese §10: o que se perde ao descer para este degrau. */
  drops?: readonly string[];
}

export interface Ladder {
  domain: Domain;
  /** Justificativa de existência (Tese §40, requisito 9). */
  purpose: string;
  steps: readonly DStep[];
  /**
   * Pisos padrão por domínio. Um valor de Q_min não é um palpite de engine:
   * é calibração psicofísica mediada por observador humano (contrato §10.1).
   * Estes são os valores-semente da GÊNESIS, declarados como semente.
   */
  defaults: { QpMin: number; QfMin: number; QiMin: number };
  /** Constante de histerese (Tese §82, contrato §1.3). */
  hysteresis: number;
}

export const ZERO_COST: CostRelation = { fixed: 0, perPixel: 0, perEntity: 0 };

export function addCost(a: CostRelation, b: CostRelation): CostRelation {
  return { fixed: a.fixed + b.fixed, perPixel: a.perPixel + b.perPixel, perEntity: a.perEntity + b.perEntity };
}

export function scaleCost(c: CostRelation, k: number): CostRelation {
  return { fixed: c.fixed * k, perPixel: c.perPixel * k, perEntity: c.perEntity * k };
}

/** Custo concreto para uma região com `pixels` e `entities`. */
export function costOf(step: DStep, region: { pixels: number; entities: number }): number {
  return step.cost.fixed + step.cost.perPixel * region.pixels + step.cost.perEntity * region.entities;
}
