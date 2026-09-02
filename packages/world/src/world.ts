import { parseDFrame, serializeDFrame, type DFrame } from '../../dframe/src/dframe.ts';
import { SCHEMA_VERSION } from '../../dframe/src/schema.ts';

/**
 * ESTADO PERSISTENTE DO MUNDO (REAL UES l.305: mundo não-persistente é "apenas
 * demonstração"). Este pacote não guarda "cenas": guarda, por célula do Spatial
 * Grid, o DFrame vigente + o estado agregado que os NPCs dormindo preservam
 * (Tese §52: abstrair sem destruir).
 */
export interface AggregateLife {
  /** contagem viva — o que existe mesmo quando ninguém é simulado individualmente */
  population: number;
  /** sumário ocupacional/econômico agregado (Tese §64/§65): quem trabalha, quanto produz */
  roles: Readonly<Record<string, number>>;
  /** última vez que o agregado foi atualizado (0.1 Hz em células dormentes) */
  lastUpdateTick: number;
  /** memória preservada da célula: fatos que continuam valendo entre ticks */
  memory: readonly string[];
}

export interface RegionRecord {
  readonly cell: readonly [number, number];
  readonly frames: Readonly<Record<string, DFrame>>;
  readonly life: AggregateLife;
  /** histórico curto de D por domínio: é o que a histerese lê entre sessões */
  readonly dHistory: Readonly<Record<string, number[]>>;
}

export interface WorldState {
  readonly schemaVersion: number;
  readonly tick: number;
  readonly grid: { readonly cellSize: number; readonly w: number; readonly h: number };
  readonly records: Readonly<Record<string, RegionRecord>>;
}

export class WorldError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(`${code}: ${message}`);
    this.code = code;
    this.name = 'WorldError';
  }
}

export const cellKey = (x: number, y: number) => `${x},${y}`;

export function createWorld(grid: WorldState['grid']): WorldState {
  if (!Number.isInteger(grid.cellSize) || grid.cellSize < 4) {
    throw new WorldError('GRID_CELL_SIZE', `cellSize=${grid.cellSize}: célula menor que 4 unidades não é decisão, é entidade`);
  }
  if (!Number.isInteger(grid.w) || !Number.isInteger(grid.h) || grid.w < 1 || grid.h < 1) {
    throw new WorldError('GRID_SIZE', `grade ${grid.w}×${grid.h} inválida`);
  }
  return { schemaVersion: SCHEMA_VERSION, tick: 0, grid, records: {} };
}

/** Grava o DFrame vigente de (célula, domínio). O frame é validado AO ENTRAR. */
export function putFrame(world: WorldState, cell: readonly [number, number], frame: DFrame): WorldState {
  const key = cellKey(cell[0], cell[1]);
  const prev = world.records[key];
  const [x, y] = cell;
  if (x < 0 || y < 0 || x >= world.grid.w || y >= world.grid.h) {
    throw new WorldError('CELL_OUT_OF_BOUNDS', `célula (${x},${y}) fora da grade ${world.grid.w}×${world.grid.h}`);
  }
  if (frame.regionId !== `r:${x},${y}`) {
    throw new WorldError('CELL_MISMATCH', `frame de ${frame.regionId} gravado na célula (${x},${y}) — região e célula têm de coincidir`);
  }
  const frames = { ...(prev?.frames ?? {}), [frame.domain]: frame };
  const hist = prev?.dHistory?.[frame.domain] ?? [];
  const dHistory = { ...(prev?.dHistory ?? {}), [frame.domain]: [...hist, frame.DCurrent].slice(-8) };
  return {
    ...world,
    records: {
      ...world.records,
      [key]: {
        cell,
        frames,
        dHistory,
        life: prev?.life ?? emptyLife(world.tick),
      },
    },
  };
}

/** Atualiza o agregado de uma célula. NPCs dormentes NÃO perdem estado (I10). */
export function updateLife(world: WorldState, cell: readonly [number, number], patch: Partial<AggregateLife>): WorldState {
  const key = cellKey(cell[0], cell[1]);
  const prev = world.records[key];
  if (!prev) throw new WorldError('NO_RECORD', `célula (${cell[0]},${cell[1]}) não existe; criar vida sem região é cena, não mundo`);
  const life: AggregateLife = { ...prev.life, ...patch, roles: { ...prev.life.roles, ...(patch.roles ?? {}) }, lastUpdateTick: world.tick };
  return { ...world, records: { ...world.records, [key]: { ...prev, life } } };
}

/** Ticks por domínio: o que está dormindo NÃO é atualizado, e continua verdadeiro. */
export function advance(world: WorldState, dt = 1): WorldState {
  return { ...world, tick: world.tick + dt };
}

/** Custo real por tick, medido em células ATUALIZÁVEIS (não em entidades). */
export function tickCost(world: WorldState, opts: { dormantHz?: number; now?: number } = {}): { cellsUpdated: number; cellsDormant: number; entitiesTouched: number } {
  const hz = opts.dormantHz ?? 0.1;
  const now = opts.now ?? world.tick;
  let cellsUpdated = 0;
  let cellsDormant = 0;
  for (const rec of Object.values(world.records)) {
    const dormant = rec.frames.physical?.DCurrent === 0 || rec.frames.behavioral?.DCurrent === 0;
    const due = now - rec.life.lastUpdateTick >= 1 / hz;
    if (dormant && !due) cellsDormant++;
    else cellsUpdated++;
  }
  return { cellsUpdated, cellsDormant, entitiesTouched: 0 };
}

function emptyLife(tick: number): AggregateLife {
  return { population: 0, roles: {}, lastUpdateTick: tick, memory: [] };
}

/** Persistência local-first (REAL UES l.500): arquivo, não serviço. */
export function serializeWorld(world: WorldState): string {
  return JSON.stringify({ ...world, records: mapRecords(world, (f) => JSON.parse(serializeDFrame(f)) as DFrame) });
}

export function loadWorld(raw: string): WorldState {
  const parsed = JSON.parse(raw) as { schemaVersion?: number };
  if (parsed.schemaVersion === undefined) {
    throw new WorldError('SNAPSHOT_SCHEMA_MISSING', 'snapshot sem schemaVersion: erro explícito, não inicializar vazio (UTS l.2797-2818)');
  }
  if (parsed.schemaVersion !== SCHEMA_VERSION) {
    throw new WorldError('SNAPSHOT_SCHEMA_VERSION', `snapshot em v${parsed.schemaVersion}, engine em v${SCHEMA_VERSION}; migração é obrigatória antes de carregar`);
  }
  const w = parsed as WorldState;
  const records: Record<string, RegionRecord> = {};
  for (const [key, rec] of Object.entries(w.records ?? {})) {
    const frames: Record<string, DFrame> = {};
    for (const [dom, raw] of Object.entries(rec.frames ?? {})) {
      const f = parseDFrame(raw);
      if (f.domain !== dom) throw new WorldError('FRAME_DOMAIN_MISMATCH', `snapshot declara "${dom}" mas o frame é "${f.domain}"`);
      frames[dom] = f;
    }
    records[key] = { ...rec, frames };
  }
  return { ...w, records };
}

function mapRecords(world: WorldState, fn: (f: DFrame) => DFrame) {
  const out: Record<string, unknown> = {};
  for (const [k, rec] of Object.entries(world.records)) {
    const frames: Record<string, DFrame> = {};
    for (const [d, f] of Object.entries(rec.frames)) frames[d] = fn(f);
    out[k] = { ...rec, frames };
  }
  return out;
}
