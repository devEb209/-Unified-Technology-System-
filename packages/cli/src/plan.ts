import { decideRegion, costOfSet, type Region, type Infeasible } from '../../do15/src/optimizer.ts';
import { ladderFor, costOf } from '../../d-system/src/ladders.ts';
import type { Domain } from '../../d-system/src/types.ts';
import type { DomainRequirements } from '../../d-system/src/requirements.ts';
import type { PersistState } from '../../dframe/src/dframe.ts';

export interface CellSpec {
  x: number;
  y: number;
  entities?: number;
  lights?: number;
  volumes?: number;
  importance?: number;
  motion?: number;
  /** pixels por célula; default: área da tela dividida pelas células */
  pixels?: number;
  /**
   * Orçamento DECLARADO para a célula, em unidades de custo. Quando presente,
   * substitui a partilha por importância: é como o autor diz "esta região tem
   * este teto". A soma pode ficar abaixo do orçamento do frame — nunca acima,
   * porque o frame é o que o aparelho cobra.
   */
  budget?: number;
  /** requisito declarado por objeto de jogo naquela célula */
  requires?: Partial<Record<Domain, DomainRequirements>>;
  persist?: Partial<Record<Domain, PersistState>>;
}

export interface SceneSpec {
  name: string;
  screen: { w: number; h: number };
  grid: { w: number; h: number; cellSize: number };
  fps: number;
  /** fração do frame reservada a outras coisas (UI, rede, áudio, compositor) */
  overhead?: number;
  thermal?: 'nominal' | 'throttling' | 'critical';
  /** requisito da REgra DO JOGO, aplicado a toda célula (o autor não declara por célula) */
  requires?: Partial<Record<Domain, DomainRequirements>>;
  headroom?: number;
  cells: CellSpec[];
}

export interface PlanRegion {
  cell: [number, number];
  kind: 'ok' | 'infeasible';
  decisions?: Record<string, { D: number; cost: number; margin: number; why: string; caps: readonly string[] }>;
  cost?: number;
  budget: number;
  error?: Infeasible;
  fallback?: { decisions: Record<string, number>; cost: number; coarse: true };
}

export interface Plan {
  readonly schemaVersion: 1;
  readonly kind: 'uts.genesis.plan';
  readonly scene: string;
  readonly generatedBy: string;
  readonly device: { screen: { w: number; h: number }; fps: number; frameBudgetMs: number; overhead: number; budgetPerCell: number[] };
  readonly regions: PlanRegion[];
  readonly totals: { budgetUnits: number; chosenUnits: number; feasibleCells: number; infeasibleCells: number; cells: number };
  readonly notice: string;
  /** de onde veio a conversão ms→unidades, e se o orçamento tem poder de decisão */
  readonly calibration: {
    source: 'measured' | 'estimated';
    unitsPerSecond: number;
    deviceFile?: string;
    /** fração do orçamento efetivamente gasta; perto de 0 significa que C é calibrado em outra escala */
    utilization: number;
    warning?: string;
  };
}

/**
 * Gera o plano D-O15 de uma cena. NÃO mede FPS: converte ms em unidades de custo
 * com uma constante que só o aparelho do usuário fornece. Rodar `measure` no
 * aparelho e recarregar o plano com `unitsPerSecond` é o que fecha o laço
 * (UTS l.2181: "não aceite 'otimizado' sem medição").
 */
export class PlanError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(`${code}: ${message}`);
    this.code = code;
    this.name = 'PlanError';
  }
}

export function planScene(scene: SceneSpec, opts: { unitsPerSecond?: number; deviceFile?: string } = {}): Plan {
  if (!Number.isFinite(scene.fps) || scene.fps < 1) throw new PlanError('SCENE_FPS', `fps=${scene.fps} — sem taxa de quadro não há orçamento de frame`);
  if (!Number.isInteger(scene.screen.w) || !Number.isInteger(scene.screen.h) || scene.screen.w < 1 || scene.screen.h < 1) {
    throw new PlanError('SCENE_SCREEN', `tela ${scene.screen.w}×${scene.screen.h} inválida`);
  }
  if (scene.cells.length === 0) throw new PlanError('SCENE_CELLS', 'cena sem células: o otimizador não tem o que decidir');
  if (scene.grid.w * scene.grid.h < scene.cells.length) {
    throw new PlanError('SCENE_GRID_TOO_SMALL', `${scene.cells.length} células não cabem numa grade ${scene.grid.w}×${scene.grid.h}`);
  }
  for (const c of scene.cells) {
    if (!Number.isInteger(c.x) || !Number.isInteger(c.y) || c.x < 0 || c.y < 0) throw new PlanError('CELL_COORDS', `célula (${c.x},${c.y}) com coordenada inválida`);
    if (c.x >= scene.grid.w || c.y >= scene.grid.h) throw new PlanError('CELL_OUT_OF_GRID', `célula (${c.x},${c.y}) fora da grade`);
    if (c.importance !== undefined && (c.importance < 0 || c.importance > 1)) throw new PlanError('CELL_IMPORTANCE', `célula (${c.x},${c.y}) importance=${c.importance} fora de [0,1]`);
    if (c.budget !== undefined && (!Number.isFinite(c.budget) || c.budget <= 0)) throw new PlanError('CELL_BUDGET', `célula (${c.x},${c.y}) budget=${c.budget}: orçamento declarado precisa ser positivo`);
  }
  if (scene.overhead !== undefined && (scene.overhead < 0 || scene.overhead > 0.9)) throw new PlanError('SCENE_OVERHEAD', `overhead=${scene.overhead} — não se reserva mais de 90% do frame`);
  const declared = scene.cells.reduce((a, c) => a + (c.budget ?? 0), 0);
  if (scene.cells.some((c) => c.budget !== undefined) && declared > totalUnitsFor(scene)) {
    throw new PlanError('DECLARED_BUDGET_EXCEEDS_FRAME', `orçamentos declarados somam ${declared.toFixed(1)} acima do orçamento do frame (${totalUnitsFor(scene).toFixed(1)}): a partilha por importância é o teto, não uma sugestão`);
  }
  const measured = opts.unitsPerSecond !== undefined;
  const ups = opts.unitsPerSecond ?? DEFAULT_UNITS_PER_SECOND;
  if (!Number.isFinite(ups) || ups <= 0) throw new PlanError('UNITS_PER_SECOND', `unitsPerSecond=${ups} deve ser um número positivo (é a constante que a medição no aparelho fornece)`);
  const frameBudgetMs = 1000 / scene.fps;
  const overhead = scene.overhead ?? 0.25;
  const usable = Math.max(0.05, 1 - overhead);
  const totalUnitsRaw = frameBudgetMs * usable * ups;
  const totalUnits = totalUnitsRaw;
  const cells = scene.cells;
  const px = Math.floor((scene.screen.w * scene.screen.h) / Math.max(1, cells.length));
  const totalImportance = cells.reduce((a, c) => a + (c.importance ?? 0.5), 0) || 1;

  const regions: PlanRegion[] = [];
  const chosen: number[] = [];
  let infeasibleCells = 0;
  const rawShares: number[] = [];
  for (const c of cells) {
    const share = c.budget ?? ((c.importance ?? 0.5) / totalImportance) * totalUnits;
    rawShares.push(share);
    const region: Region = {
      id: `r:${c.x},${c.y}`,
      pixels: c.pixels ?? px,
      entities: c.entities ?? 0,
      lights: c.lights ?? 0,
      volumes: c.volumes ?? 0,
      importance: c.importance ?? 0.5,
      motion: c.motion ?? 0.2,
    };
    const d = decideRegion({
      region,
      resources: { frameBudget: share, headroom: scene.headroom ?? 0.1, thermal: scene.thermal ?? 'nominal' },
      requirements: { ...scene.requires, ...c.requires },
      persist: c.persist,
    });
    if (d.kind === 'ok') {
      regions.push({
        cell: [c.x, c.y],
        kind: 'ok',
        budget: round(share),
        cost: round(d.regions.totalCost),
        decisions: Object.fromEntries(
          Object.entries(d.regions.decisions).map(([dom, v]) => [dom, { D: v.D, cost: round(v.cost), margin: round(v.margin, 3), why: v.why, caps: [...ladderFor(dom as Domain).steps[v.D].caps] }]),
        ),
      });
      chosen.push(d.regions.totalCost);
    } else {
      infeasibleCells++;
      regions.push({
        cell: [c.x, c.y],
        kind: 'infeasible',
        budget: round(share),
        error: d.error,
        fallback: { decisions: Object.fromEntries(Object.entries(d.fallback.decisions).map(([k, v]) => [k, v.D])), cost: round(d.fallback.totalCost), coarse: true },
      });
      chosen.push(0);
    }
  }
  return {
    schemaVersion: 1,
    kind: 'uts.genesis.plan',
    scene: scene.name,
    generatedBy: 'uts/cli plan (GEN-1)',
    device: {
      screen: scene.screen,
      fps: scene.fps,
      frameBudgetMs, // sem arredondamento: 1000/fps entra cru, senão as contas do orçamento não fecham
      overhead,
      budgetPerCell: regions.map((r) => r.budget),
    },
    regions,
    totals: {
      budgetUnits: totalUnitsRaw,
      chosenUnits: round(chosen.reduce((a, b) => a + b, 0), 3),
      feasibleCells: cells.length - infeasibleCells,
      infeasibleCells,
      cells: cells.length,
    },
    calibration: (() => {
      const util = totalUnits > 0 ? chosen.reduce((a, b) => a + b, 0) / totalUnits : 0;
      return {
        source: measured ? ('measured' as const) : ('estimated' as const),
        unitsPerSecond: ups,
        deviceFile: opts.deviceFile,
        utilization: Number(util.toPrecision(4)),
        warning:
          util < 0.02
            ? `ORÇAMENTO SEM PODER DE DECISÃO: o plano gasta ${(util * 100).toFixed(3)}% do quadro. Ou a cena é trivial, ou os coeficientes da escada e a calibração estão em escalas incompatíveis — e nesse caso o ` +
              '`argmin C` está sendo decidido só pelos pisos de qualidade, o que significa que nada foi orçado de fato. Recalibrar `cost` contra tempo medido antes de confiar em qualquer conclusão de otimização.'
            : undefined,
      };
    })(),
    notice: measured
      ? `unidades de custo são TRABALHO, não FPS. Conversão vinda de medição no aparelho (${ups} un/s${opts.deviceFile ? ` via ${opts.deviceFile}` : ''}); cobre o trabalho de CPU materializado, não raster/GPU.`
      : `unidades de custo são TRABALHO, não FPS. A conversão usada aqui (unitsPerSecond=${ups}) é um chute de engenharia — rode \`uts measure\` no aparelho e passe --device. Nada neste plano está orçado de verdade até isso acontecer (UTS l.2181).`,
  };
}

export const DEFAULT_UNITS_PER_SECOND = 3000;

function totalUnitsFor(scene: SceneSpec): number {
  return (1000 / scene.fps) * Math.max(0.05, 1 - (scene.overhead ?? 0.25)) * DEFAULT_UNITS_PER_SECOND;
}

function round(v: number, digits = 3): number {
  const p = 10 ** digits;
  return Math.round(v * p) / p;
}

/** Custo máximo possível da cena, para a decisão humana ver o que está em jogo. */
export function naiveMaxCost(scene: SceneSpec): number {
  let t = 0;
  const px = Math.floor((scene.screen.w * scene.screen.h) / Math.max(1, scene.cells.length));
  for (const c of scene.cells) {
    const region: Region = { id: 'x', pixels: c.pixels ?? px, entities: c.entities ?? 0, lights: c.lights ?? 0, volumes: c.volumes ?? 0, importance: 1, motion: 1 };
    for (const dom of ['visual', 'physical', 'temporal'] as Domain[]) {
      t += costOf(ladderFor(dom).steps[ladderFor(dom).steps.length - 1], region);
    }
  }
  return round(t, 2);
}
