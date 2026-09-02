import type { CostRelation, DStep, Domain, Ladder, QualityProfile } from './types.ts';
import { DOMAINS } from './types.ts';

/**
 * Escadas de D — a §98.1 do contrato.
 *
 * Regra fundante: D sobe ⇒ capacidade sobe. Qp/Qf/Qi nunca são escolhidos
 * "no feeling": cada componente de qualidade é DERIVADA do conjunto de
 * capacidades que o degrau declara. Isso torna a exigência de monotonicidade
 * verificável por construção (teste M2), e não uma afirmação de fé.
 *
 * Custo nunca diminui ao subir de D (teste M3): se um degrau mais capaz fosse
 * mais barato que o anterior, a tese não teria o que otimizar.
 */

interface CapSet {
  Qp: number;
  Qf: number;
  Qi: number;
  caps: string[];
  recoverable: string[];
  drops?: string[];
  operators?: Partial<Record<'Qp' | 'Qf' | 'Qi', string>>;
}

const Q_CLASS_VALUES = ['PERCEPTUAL', 'FUNCTIONAL', 'INFORMATIONAL'] as const;
const DOMAIN_QS = Q_CLASS_VALUES;

const DEFAULT_OPS = {
  Qp: 'perceptual_diff/region',
  Qf: 'capability_presence',
  Qi: 'recovery_ledger ⊇ required',
} as const;

function profile(c: CapSet, cls: QualityProfile['class'] = { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' }): QualityProfile {
  return {
    Qp: c.Qp,
    Qf: c.Qf,
    Qi: c.Qi,
    class: cls,
    operators: { Qp: c.operators?.Qp ?? DEFAULT_OPS.Qp, Qf: c.operators?.Qf ?? DEFAULT_OPS.Qf, Qi: c.operators?.Qi ?? DEFAULT_OPS.Qi },
  };
}

function step(D: number, name: string, description: string, cost: CostRelation, caps: CapSet, extra: Partial<DStep> = {}): DStep {
  const s: DStep = {
    D,
    name,
    description,
    cost,
    caps: caps.caps,
    quality: profile(caps),
    recoverable: caps.recoverable,
    ...extra,
  };
  if (caps.drops) s.drops = caps.drops;
  return s;
}

const c = (fixed: number, perPixel = 0, perEntity = 0, perLight = 0, perVolume = 0): CostRelation & { perLight: number; perVolume: number } =>
  ({ fixed, perPixel, perEntity, perLight, perVolume });

/**
 * Custo completo de um degrau. `perLight`/`perVolume` são extensões: `perVolume` é
 * o canal de quem trabalha por CÉLULA DE CAMPO (visual volumétrico e terreno), por
 * isso o terreno não precisa de um quinto termo paralelo — um segundo dono para a
 * mesma grandeza é como escalas divergem.
 */
export function costOf(step: DStep, region: { pixels: number; entities: number; lights?: number; volumes?: number }): number {
  const k = step.cost as CostRelation & { perLight?: number; perVolume?: number };
  return (
    k.fixed +
    k.perPixel * region.pixels +
    k.perEntity * region.entities +
    (k.perLight ?? 0) * (region.lights ?? 0) +
    (k.perVolume ?? 0) * (region.volumes ?? 0)
  );
}

// ————————————————————————————————————————————————————— VISUAL ———————
const VISUAL: DStep[] = [
  step(0, 'solid_region', 'Região recebe uma única radiancia constante (cor de bioma). Nenhum detalhe geométrico ou material. Materializa o fundo do mundo.',
    c(0, 0.0002), { Qp: 1, Qf: 0.45, Qi: 0.35, caps: ['solid_fill'], recoverable: ['biome_code'] }),
  step(1, 'heightfield_silhouette', 'Silhueta e horizonte do heightfield; sombreamento por declive. Altura existe como informação, não como superfície colada.',
    c(0, 0.0003, 0, 0, 0), { Qp: 1, Qf: 0.6, Qi: 0.5, caps: ['solid_fill', 'height_silhouette', 'slope_shading'], recoverable: ['biome_code', 'height_samples'] },
    { prereq: { physical: 1 } }),
  step(2, 'regional_material_light', 'Propriedades de matéria por região (classe de material, reflectância por banda espectral, ruído procedural) e luz analítica com penumbra.',
    c(0, 0.0004, 0.004), { Qp: 1, Qf: 0.7, Qi: 0.65, caps: ['solid_fill', 'height_silhouette', 'slope_shading', 'material_class', 'spectral_reflectance', 'analytic_light'], recoverable: ['biome_code', 'height_samples', 'material_class_code'] },
    { prereq: { physical: 1 } }),
  step(3, 'per_entity_lit_detail', 'Entidades materializadas com detalhe por texel, sombras projetadas por atlas, e o estado de matéria (molhado, empoeirado, gasto) vindo da física.',
    c(0, 0.00055, 0.02), { Qp: 1, Qf: 0.85, Qi: 0.8, caps: ['solid_fill', 'height_silhouette', 'slope_shading', 'material_class', 'spectral_reflectance', 'analytic_light', 'per_entity_detail', 'projected_shadow', 'matter_state'], recoverable: ['biome_code', 'height_samples', 'material_class_code', 'entity_visual_state'] },
    { prereq: { physical: 2 } }),
  step(4, 'time_dependent_light_transport', 'Iluminação global temporal, reflexão por superfície, polarização e céu com dispersão — transporte de luz tratado como fenômeno, não como preset.',
    c(0, 0.00075, 0.03, 0.01), { Qp: 1, Qf: 0.95, Qi: 0.9, caps: ['solid_fill', 'height_silhouette', 'slope_shading', 'material_class', 'spectral_reflectance', 'analytic_light', 'per_entity_detail', 'projected_shadow', 'matter_state', 'global_illumination', 'reflection', 'sky_dispersion'], recoverable: ['biome_code', 'height_samples', 'material_class_code', 'entity_visual_state', 'light_transport_state'] },
    { prereq: { physical: 3 } }),
  step(5, 'volumetric_full', 'Volumétrico completo com meio participante, múltiplos caminhos e variação material por vista.',
    c(0, 0.001, 0.035, 0.015, 0.0005), { Qp: 1, Qf: 1, Qi: 1, caps: ['solid_fill', 'height_silhouette', 'slope_shading', 'material_class', 'spectral_reflectance', 'analytic_light', 'per_entity_detail', 'projected_shadow', 'matter_state', 'global_illumination', 'reflection', 'sky_dispersion', 'participating_media', 'multi_view_material'], recoverable: ['biome_code', 'height_samples', 'material_class_code', 'entity_visual_state', 'light_transport_state', 'medium_samples'] },
    { prereq: { physical: 3 } }),
];

// ————————————————————————————————————————————————————— PHYSICAL ——————
const PHYSICAL: DStep[] = [
  step(0, 'aggregate_no_motion', 'Física agregada da região: nada individual é resolvido. Existência preservada, movimento não simulado (Tese §52). Custo não é zero: a agregação também tem de ser mantida.',
    c(0, 0, 0.0005), { Qp: 1, Qf: 0, Qi: 0.4, caps: [], recoverable: ['aggregate_stats'], operators: { Qf: 'no_motion_supported' } }),
  step(1, 'presence_indexed', 'Presença e posição por índice espacial. Célula existe, corpo não colide.',
    c(0, 0, 0.0008, 0.002), { Qp: 1, Qf: 0.5, Qi: 0.6, caps: ['spatial_presence'], recoverable: ['spatial_presence', 'position'], operators: { Qf: 'capability_presence(spatial_presence)' } }),
  step(2, 'kinematic_aabb', 'Colisão AABB cinemática por entidade, com resposta de repouso.',
    c(0, 0, 0.008), { Qp: 1, Qf: 0.8, Qi: 0.8, caps: ['spatial_presence', 'aabb_collision', 'resting_contact'], recoverable: ['spatial_presence', 'position', 'aabb', 'contact_state'], drops: ['rotation', 'mass'] }),
  step(3, 'rigid_body', 'Corpos rígidos com massa, força, impulso e atrito.',
    c(0, 0, 0.02), { Qp: 1, Qf: 0.92, Qi: 0.9, caps: ['spatial_presence', 'aabb_collision', 'resting_contact', 'rigid_body', 'mass', 'impulse'], recoverable: ['spatial_presence', 'position', 'aabb', 'contact_state', 'velocity', 'mass', 'forces'], drops: ['rotation', 'joints'] }),
  step(4, 'articulated_obbb', 'OBB/OBB, rotação, juntas, corpos compostos, ragdoll, deformação suave.',
    c(0, 0, 0.045), { Qp: 1, Qf: 0.98, Qi: 0.95, caps: ['spatial_presence', 'aabb_collision', 'resting_contact', 'rigid_body', 'mass', 'impulse', 'rotation', 'obb_collision', 'joints', 'soft_deform'], recoverable: ['spatial_presence', 'position', 'aabb', 'contact_state', 'velocity', 'mass', 'forces', 'orientation', 'joint_state'] }),
  step(5, 'ccd_fluids_fracture', 'CCD, contatos persistentes com fricção, fluidos por partícula e pré-fratura por estados de matéria.',
    c(0, 0, 0.09), { Qp: 1, Qf: 1, Qi: 1, caps: ['spatial_presence', 'aabb_collision', 'resting_contact', 'rigid_body', 'mass', 'impulse', 'rotation', 'obb_collision', 'joints', 'soft_deform', 'ccd', 'fluids', 'fracture_states'], recoverable: ['spatial_presence', 'position', 'aabb', 'contact_state', 'velocity', 'mass', 'forces', 'orientation', 'joint_state', 'fluid_particles', 'fracture_tree'] },
    // CCD sem atualização por frame tunela; contato persistente com fricção exige
    // histórico por frame. É restrição da FÍSICA, não escolha de renderização.
    { prereq: { temporal: 5 } }),
];

// ——————————————————————————————— TEMPORAL (taxa de atualização) ————————
const TEMPORAL: DStep[] = [
  step(0, 'event_driven', 'Atualização puramente sob evento. Sem evento, custo zero — a maior economia do sistema e a razão de mundos grandes serem viáveis.',
    c(0), { Qp: 1, Qf: 0, Qi: 0.4, caps: [], recoverable: ['last_event_time'], operators: { Qf: 'tick_rate_supported(0)' } }),
  step(1, 'agg_0_25hz', 'Agregados a 0,25 Hz (4 s). Longe e lento.', c(0, 0, 0.0002), { Qp: 1, Qf: 0.5, Qi: 0.6, caps: ['aggregate_tick'], recoverable: ['aggregate_stats', 'last_event_time'], operators: { Qf: 'tick_rate_supported(0.25)' } }),
  step(2, 'agg_1hz', 'Agregados a 1 Hz.', c(0, 0, 0.0008), { Qp: 1, Qf: 0.6, Qi: 0.7, caps: ['aggregate_tick'], recoverable: ['aggregate_stats', 'entity_set', 'last_event_time'], operators: { Qf: 'tick_rate_supported(1)' } }),
  step(3, 'half_rate', 'Entidades a 5 Hz. Suficiente para criatura andando a 6 m/s em câmera a 10 m.', c(0, 0, 0.003), { Qp: 1, Qf: 0.8, Qi: 0.85, caps: ['aggregate_tick', 'entity_tick'], recoverable: ['aggregate_stats', 'entity_set', 'entity_state', 'last_event_time'], operators: { Qf: 'tick_rate_supported(5)' } }),
  step(4, 'full_rate', 'Entidades a 15 Hz.', c(0, 0, 0.009), { Qp: 1, Qf: 0.95, Qi: 0.95, caps: ['aggregate_tick', 'entity_tick'], recoverable: ['aggregate_stats', 'entity_set', 'entity_state', 'event_queue', 'last_event_time'], operators: { Qf: 'tick_rate_supported(15)' } }),
  step(5, 'frame_synced', 'Por frame. Só onde movimento rápido, interação ou percepção de contato exigem.', c(0, 0, 0.02), { Qp: 1, Qf: 1, Qi: 1, caps: ['aggregate_tick', 'entity_tick', 'frame_tick'], recoverable: ['aggregate_stats', 'entity_set', 'entity_state', 'event_queue', 'contact_history', 'last_event_time'], operators: { Qf: 'tick_rate_supported(frame)' } }),
];

// ————————————————————————————————————————————————————— TERRAIN ——————
// Era GÊNESIS pediu "construir a realidade": terreno não é mesh importado, é campo
// com leis. Cada degrau abaixo adiciona UMA lei de formação do relevo, e o preço é
// por volume de célula (O(células), nunca O(entidades)) — ver teste T3/M9.
const TERRAIN: DStep[] = [
  step(0, 'base_plane', 'Plano de base do bioma: altitude constante, nenhuma estrutura. Existe para "não ter relevo" ser uma opção real e cobrada.',
    c(0.5, 0, 0, 0, 0.00002), { Qp: 0.4, Qf: 0, Qi: 0.5, caps: [], recoverable: ['biome_code'], operators: { Qf: 'no_structure' } }),
  step(1, 'orogeny_fractal', 'Relevo fractal determinístico (fBm + cristas): montanha, platô, vale. Altura como informação, ainda sem água nem gravidade agindo sobre ela.',
    c(2, 0, 0, 0, 0.00008), { Qp: 0.6, Qf: 0.5, Qi: 0.7, caps: ['heightfield_fractal'], recoverable: ['biome_code', 'elevation_field'], operators: { Qf: 'field(elevation)' } }),
  step(2, 'hydro_erosion', 'Hidrologia: acúmulo de fluxo, rios que descem de verdade, lagos onde a água não tem para onde ir, e deposição que alisa o vale.',
    c(4, 0, 0, 0, 0.0002), { Qp: 0.75, Qf: 0.7, Qi: 0.8, caps: ['heightfield_fractal', 'hydrology'], recoverable: ['biome_code', 'elevation_field', 'flow_field', 'water_mask'], operators: { Qf: 'field(flow)+field(water)' } }),
  step(3, 'material_slope', 'Classes de material derivadas do relevo (rocha, solo, areia) e ângulo de repouso: encosta acima do limite materializa como instável, não como rampa.',
    c(6, 0, 0, 0, 0.0003), { Qp: 0.85, Qf: 0.85, Qi: 0.9, caps: ['heightfield_fractal', 'hydrology', 'material_class', 'angle_of_repose'], recoverable: ['biome_code', 'elevation_field', 'flow_field', 'water_mask', 'material_field'], operators: { Qf: 'field(material)+constraint(repose)' } }),
  step(4, 'climate_zones', 'Clima por altitude e latitude: temperatura, umidade, evapotranspiração e zona de vegetação como código — é isto que faz neve ficar acima da linha certa sem ninguém pintar.',
    c(8, 0, 0, 0, 0.0005), { Qp: 0.95, Qf: 0.92, Qi: 0.95, caps: ['heightfield_fractal', 'hydrology', 'material_class', 'angle_of_repose', 'climate_zones', 'vegetation_zones'], recoverable: ['biome_code', 'elevation_field', 'flow_field', 'water_mask', 'material_field', 'climate_field', 'vegetation_code'], operators: { Qf: 'field(climate)+field(vegetation)' } }),
  step(5, 'dynamic_deformation', 'Deformação contínua: tsunami assoreia e escava, detrito muda o campo, e o que o jogador fez ontem ainda está lá. Reversibilidade é o custo deste degrau.',
    c(10, 0, 0, 0, 0.0009), { Qp: 1, Qf: 1, Qi: 1, caps: ['heightfield_fractal', 'hydrology', 'material_class', 'angle_of_repose', 'climate_zones', 'vegetation_zones', 'sediment_transport', 'dynamic_deformation'], recoverable: ['biome_code', 'elevation_field', 'flow_field', 'water_mask', 'material_field', 'climate_field', 'vegetation_code', 'sediment_field', 'deformation_history'], drops: ['deformation_history'] },
    // escavar e assorear sem histórico por frame é animação, não deformação
    { prereq: { temporal: 3 } }),
];

const LADDERS: Record<Domain, Ladder> = {
  visual: { domain: 'visual', purpose: 'O que a região produz de imagem, e o quanto de fenômeno luminoso é transportado em vez de fingido.', steps: VISUAL, defaults: { QpMin: 0.9, QfMin: 0.0, QiMin: 0.0 }, hysteresis: 0.04 },
  physical: { domain: 'physical', purpose: 'Quanto do comportamento mecânico continua verdadeiro — incluindo quando NADA é simulado mas a existência permanece.', steps: PHYSICAL, defaults: { QpMin: 0.0, QfMin: 0.8, QiMin: 0.8 }, hysteresis: 0.04 },
  temporal: { domain: 'temporal', purpose: 'Com que frequência o estado é atualizado. Custo de existência não é custo por frame.', steps: TEMPORAL, defaults: { QpMin: 0.0, QfMin: 0.8, QiMin: 0.8 }, hysteresis: 0.04 },
  behavioral: { domain: 'behavioral', purpose: 'Nível de mente ativa por entidade (NMN), do agregado ao histórico completo.', steps: [], defaults: { QpMin: 0.0, QfMin: 0.0, QiMin: 0.0 }, hysteresis: 0.04 },
  social: { domain: 'social', purpose: 'Granularidade de relações e influência entre entidades.', steps: [], defaults: { QpMin: 0.0, QfMin: 0.0, QiMin: 0.0 }, hysteresis: 0.04 },
  economic: { domain: 'economic', purpose: 'Granularidade de produção, consumo e preço.', steps: [], defaults: { QpMin: 0.0, QfMin: 0.0, QiMin: 0.0 }, hysteresis: 0.04 },
  terrain: { domain: 'terrain', purpose: 'Quantas leis de formação do relevo estão ativas na região — de plano morto a terreno que registra o que aconteceu nele.', steps: TERRAIN, defaults: { QpMin: 0.0, QfMin: 0.0, QiMin: 0.0 }, hysteresis: 0.04 },
};

export function ladderFor(domain: Domain): Ladder {
  const l = LADDERS[domain];
  if (!l) throw new Error(`LADDER_UNKNOWN: ${domain}`);
  return l;
}

export function isMaterialized(domain: Domain): boolean {
  return ladderFor(domain).steps.length > 0;
}

export function allLadders(): Ladder[] {
  return DOMAINS.map((d) => LADDERS[d]);
}

// ——————————————————————————————————————— capacidades / validação ———————
/** Capacidades efetivamente disponíveis num (domínio, D) — o teto do degrau, não o pedido. */
/** Capacidades efetivamente disponíveis num (domínio, D). */
export function capsAt(domain: Domain, D: number): Set<string> {
  return new Set(stepAt(domain, D)?.caps ?? []);
}

export function stepAt(domain: Domain, D: number): DStep | undefined {
  return ladderFor(domain).steps.find((s) => s.D === D);
}

export interface ValidationIssue {
  code: string;
  domain: Domain;
  D?: number;
  message: string;
}

/**
 * Valida a escada contra o §98.1. Retorna lista vazia se ela puder entrar no
 * espaço de otimização. Qualquer item aqui significa "este D está FORA do
 * argmin e só pode ser usado por decisão humana explícita".
 */
export function validateLadder(ladder: Ladder): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const steps = ladder.steps;
  if (steps.length === 0) return issues; // slot fora de escopo: não é inválido, é não-otimizável

  if (steps[0].D !== 0) issues.push({ code: 'LADDER_BASE_NOT_ZERO', domain: ladder.domain, message: 'a escada deve começar em D0' });

  for (let i = 0; i < steps.length; i++) {
    const s = steps[i];
    if (i > 0) {
      if (s.D <= steps[i - 1].D) {
        issues.push({ code: 'LADDER_UNORDERED', domain: ladder.domain, D: s.D, message: `D ${s.D} não é maior que ${steps[i - 1].D}` });
      }
      // M2 — capacidade monotônica: subir de D não pode remover capacidade.
      for (const cap of prevCaps(steps[i - 1])) {
        if (!curCaps(s).has(cap)) {
          issues.push({ code: 'M2_CAPABILITY_LOST_ON_RISE', domain: ladder.domain, D: s.D, message: `capacidade "${cap}" desapareceu ao subir para D${s.D}` });
        }
      }
      // M2 — Q não-decrescente por componente.
      for (const k of ['Qp', 'Qf', 'Qi'] as const) {
        if (s.quality[k] + 1e-9 < steps[i - 1].quality[k]) {
          issues.push({ code: 'M2_QUALITY_REGRESSION', domain: ladder.domain, D: s.D, message: `${k} caiu de ${steps[i - 1].quality[k]} para ${s.quality[k]} ao subir de D` });
        }
      }
      // M3 — custo não-diminuente.
      const prev = steps[i - 1].cost, now = s.cost;
      for (const k of ['fixed', 'perPixel', 'perEntity'] as const) {
        if ((now[k] ?? 0) + 1e-12 < (prev[k] ?? 0)) {
          issues.push({ code: 'M3_COST_REGRESSION', domain: ladder.domain, D: s.D, message: `${k} diminuiu ao subir de D (otimizador não teria o que cortar)` });
        }
      }
      const anyBetter = (['Qp', 'Qf', 'Qi'] as const).some((k) => s.quality[k] > steps[i - 1].quality[k]);
      const anyCostlier = (['fixed', 'perPixel', 'perEntity'] as const).some((k) => (now[k] ?? 0) > (prev[k] ?? 0));
      if (!anyBetter && !anyCostlier) {
        issues.push({ code: 'LADDER_DEAD_STEP', domain: ladder.domain, D: s.D, message: 'degrau idêntico ao anterior: nem mais capaz nem mais caro — nomenclatura vazia (Tese §89)' });
      }
    }
    // §98.1 — medidor declarado por componente.
    for (const k of ['Qp', 'Qf', 'Qi'] as const) {
      if (!s.quality.operators[k] || s.quality.operators[k].length === 0) {
        issues.push({ code: 'M1_NO_MEASURER', domain: ladder.domain, D: s.D, message: `${k} sem operador de medida declarado` });
      }
    }
    // I8 — classe de qualidade declarada.
    for (const k of ['Qp', 'Qf', 'Qi'] as const) {
      if (!DOMAIN_QS.includes(s.quality.class[k])) {
        issues.push({ code: 'I8_UNCLASSIFIED_QUALITY', domain: ladder.domain, D: s.D, message: `${k}.class inválido: "${s.quality.class[k]}"` });
      }
    }
  }
  return issues;
}

function curCaps(s: DStep): Set<string> { return new Set(s.caps); }
function prevCaps(s: DStep): string[] { return [...s.caps]; }

export function validateAll(): ValidationIssue[] {
  return allLadders().flatMap(validateLadder);
}
