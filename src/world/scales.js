// UTS :: world/scales — THE REALITY LADDER (do átomo ao universo). One
// reality, many scales: each level carries its OWN causal individuals and
// its own time rate, and levels are LINKED (statistics of the lower become
// state of the upper — heat IS molecular motion, pressure IS cell work).
// D-O15 governs the granularity at each scale, never that the scale exists.

export const SCALES = Object.freeze([
  { id: 'quantum',    size: 1e-12, entity: 'campo de probabilidade', dt: 1e-6,  law: 'superposição determinística (rng semeado)' },
  { id: 'atomic',     size: 1e-10, entity: 'átomo',                  dt: 1e-9,  law: 'ligação por energia de orbital' },
  { id: 'molecular',  size: 1e-8,  entity: 'molécula',               dt: 1e-8,  law: 'colisão + ligação química' },
  { id: 'cell',       size: 2e-5,  entity: 'célula',                 dt: 1e-2,  law: 'metabolismo + divisão' },
  { id: 'tissue',     size: 1e-3,  entity: 'tecido/organismo pequeno', dt: 1e-1, law: 'crescimento + reparo' },
  { id: 'human',      size: 1.7,   entity: 'pessoa (NMN)',           dt: 1,     law: 'necessidades→percepção→decisão' },
  { id: 'street',     size: 30,    entity: 'interação local',        dt: 1,     law: 'física clássica' },
  { id: 'district',   size: 300,   entity: 'grupo/nu',               dt: 1,     law: 'percepção coletiva' },
  { id: 'city',       size: 3e3,   entity: 'assentamento',           dt: 5,     law: 'economia + sociedade' },
  { id: 'region',     size: 1e5,   entity: 'região climática',       dt: 60,    law: 'atmosfera + hidrologia' },
  { id: 'planet',     size: 1.3e7, entity: 'planeta',                dt: 3600,  law: 'clima global + geologia' },
  { id: 'star',       size: 1.4e9, entity: 'estrela',                dt: 3.15e7, law: 'fusão (energia ∝ massa)' },
  { id: 'system',     size: 9e12,  entity: 'sistema orbital',        dt: 3.15e7, law: 'gravitação (n corpos)' },
  { id: 'galaxy',     size: 1e21,  entity: 'galáxia',                dt: 3.15e13, law: 'fluxo estelar + rotação' },
  { id: 'universe',   size: 8.8e26, entity: 'universo (métrica)',    dt: 3.15e16, law: 'expansão + conservação global' },
]);

const log10 = Math.log(10);

/** which scale a phenomenon of the given size (m) belongs to */
export function scaleFor(size) {
  const s = Math.max(Math.abs(size), 1e-15);
  let best = SCALES[0];
  for (const k of SCALES) {
    if (Math.abs(Math.log10(s) - Math.log10(k.size)) < Math.abs(Math.log10(s) - Math.log10(best.size))) best = k;
  }
  return best;
}

/** how many causal levels separate two scales (0 = same) */
export function levelsBetween(aId, bId) {
  const ia = SCALES.findIndex(k => k.id === aId), ib = SCALES.findIndex(k => k.id === bId);
  if (ia < 0 || ib < 0) throw new Error(`escala desconhecida: ${aId}/${bId}`);
  return Math.abs(ia - ib);
}

/**
 * CAUSAL LINK: statistics of the lower scale become STATE of the upper.
 * Conserves the conserved quantity (energy/mass/count) — aggregation never
 * invents, it re-represents (a lei suprema nº2). events: [{ v, w? }].
 */
export function aggregate(events, fromId, toId) {
  if (levelsBetween(fromId, toId) !== 1) throw new Error('link direto = escalas vizinhas');
  let sum = 0, sum2 = 0, n = 0;
  for (const e of events ?? []) {
    const v = typeof e === 'number' ? e : e.v;
    sum += v; sum2 += v * v; n++;
  }
  if (n === 0) return { mean: 0, var: 0, n: 0, total: 0 };
  const mean = sum / n;
  return { mean, var: sum2 / n - mean * mean, n, total: sum };
}

/** time rate: how much faster a scale runs relative to the human scale */
export function timeRate(id) {
  const k = SCALES.find(s => s.id === id);
  return k ? 1 / k.dt : 1;
}

/** the full ladder as a compact report (HUD/IA) */
export function ladder() {
  return SCALES.map(k => `${k.id}(${k.size.toExponential(0)}m)`);
}

export class ScaleLadder {
  constructor({ world } = {}) {
    this.world = world;
    this.tags = new Map(); // entidade RRW -> escala id (pelo tamanho do corpo)
  }

  tag(id, size) {
    const s = scaleFor(size);
    this.tags.set(id, s.id);
    return s.id;
  }

  /** eventos de uma escala sobem UMA vizinhança por vez (a rede causal) */
  propagateUp(events, fromId) {
    const i = SCALES.findIndex(k => k.id === fromId);
    if (i < 0 || i === SCALES.length - 1) return null;
    return aggregate(events, fromId, SCALES[i + 1].id);
  }
}
