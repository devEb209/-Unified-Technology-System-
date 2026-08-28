// UTS :: world/society — settlements, population aggregates and economy.
//
// A society is represented by individuals, groups, relations, resources,
// institutions, economy, culture, rules and happenings — with detail that
// follows relevance. Distant settlements evolve as AGGREGATES (statistical
// processes in RRW); near ones materialize into individuals.
// Merging back preserves state in both directions (D-14 + D-8 + D-12).

import { RNG } from '../core/rng.js';

export const GOOD_NAMES = ['food', 'wood', 'stone'];

export function createSettlement(world, { name, pos, pop = 24, culture = 'generic' }) {
  const rrw = world.rrw;
  const ent = rrw.createEntity({
    kind: 'settlement',
    materialization: 'abstract',
    importance: 0.75,
    tags: ['settlement'],
    name,
    pos: [pos[0], 0, pos[2]],
    components: {
      settlement: {
        name, culture,
        pop,
        store: { food: 40, wood: 20, stone: 10 },
        rates: { food: 0.5, wood: 0.2, stone: 0.1 },
        birthAcc: 0, deathAcc: 0,
      },
    },
  });
  rrw.createProcess('settlement-life', { attachedTo: ent.id, level: 'abstract', state: { settlementId: ent.id } });
  world.rrw.bus?.emit('society.settlement.founded', { id: ent.id, name, pos });
  return ent;
}

/** materialize k individuals out of an aggregate settlement (state-preserving) */
export function materializeSettlement(world, settlementId, k) {
  const rrw = world.rrw;
  const s = rrw.getComponent(settlementId, 'settlement');
  const sp = rrw.getComponent(settlementId, 'spatial');
  if (!s || !sp) throw new Error(`settlement ${settlementId} malformed`);
  const n = Math.min(k, s.pop);
  const created = [];
  for (let i = 0; i < n; i++) {
    const a = world.rng.next() * Math.PI * 2;
    const r = 3 + world.rng.range(0, 18);
    const px = sp.pos[0] + Math.cos(a) * r;
    const pz = sp.pos[2] + Math.sin(a) * r;
    const npc = world.spawnNPC({ pos: [px, 0, pz], settlementId, fromAggregate: settlementId });
    rrw.addRelation(npc.id, settlementId, 'member-of', { weight: 1, data: { role: npc.components.get('npc')?.role } });
    created.push(npc.id);
  }
  s.pop -= n;
  s.materialized = (s.materialized ?? 0) + n;
  rrw.setMaterialization(settlementId, 'partial', { reason: `materialized ${n} individuals`, tick: world.clock.tick });
  return created;
}

/** absorb materialized individuals back into the aggregate (state-preserving merge) */
export function abstractSettlement(world, settlementId) {
  const rrw = world.rrw;
  const s = rrw.getComponent(settlementId, 'settlement');
  if (!s) return 0;
  const members = rrw.query({ kind: 'npc', predicate: e => e.components.get('npc')?.settlementId === settlementId });
  let merged = 0;
  for (const id of members) {
    const mind = rrw.getComponent(id, 'mind');
    // aggregate keeps a distillate of the individuals' state (D-14: no information destroyed)
    if (mind?.knowledge) s.cultureKnowledge = (s.cultureKnowledge ?? 0) + Math.min(3, mind.knowledge.size);
    rrw.destroy(id);
    merged++;
  }
  s.pop += merged;
  s.materialized = 0;
  rrw.setMaterialization(settlementId, 'abstract', { reason: `absorbed ${merged} individuals`, tick: world.clock.tick });
  return merged;
}

/** abstract evolution of a settlement (runs via RRW process when far from focus) */
export function evolveSettlementAbstract(world, settlementId, dt) {
  const rrw = world.rrw;
  const s = rrw.getComponent(settlementId, 'settlement');
  if (!s) return;
  // production/consumption at population scale
  s.store.food += s.rates.food * s.pop * dt * 0.05 - s.pop * dt * 0.05;
  s.store.wood += s.rates.wood * s.pop * dt * 0.03;
  s.store.stone += s.rates.stone * s.pop * dt * 0.015;
  // births/deaths as statistical flow
  if (s.store.food > 30 && s.pop < 800) {
    s.birthAcc += dt * 0.06 * s.pop;
    if (s.birthAcc >= 1) {
      s.birthAcc -= 1;
      s.pop += 1;
      rrw.emitEvent({
        type: 'society.birth', subject: settlementId, cause: null,
        data: { pop: s.pop }, tick: world.clock.tick,
      });
    }
  }
  if (s.store.food <= 0) {
    s.deathAcc += dt * 0.08 * s.pop;
    if (s.deathAcc >= 1) {
      s.deathAcc -= 1;
      s.pop -= 1;
      rrw.emitEvent({
        type: 'society.starvation', subject: settlementId, cause: null,
        data: { pop: s.pop }, tick: world.clock.tick,
      });
    }
    s.store.food = 0;
  }
}

/** detailed economy tick — only for settlements with materialized individuals */
export function updateSettlementEconomy(world, settlementId, dt) {
  const rrw = world.rrw;
  const s = rrw.getComponent(settlementId, 'settlement');
  if (!s) return;
  // individual labor at detailed resolution (aggregate flow already ran via process)
  const laborers = rrw.query({ kind: 'npc', predicate: e => e.components.get('npc')?.settlementId === settlementId }).length;
  s.store.food += laborers * 0.012 * dt;
  s.store.wood += laborers * 0.004 * dt;
  const tese = world.tese;
  tese?.touch('D-12', `${settlementId}: laborers=${laborers} food=${s.store.food.toFixed(1)}`, world.clock.tick);
}

/** trade between settlements: surplus -> deficit (D-12) */
export function tradePass(world, { maxPairs = 6 } = {}) {
  const rrw = world.rrw;
  const settlements = rrw.query({ kind: 'settlement' }).map(id => ({ id, s: rrw.getComponent(id, 'settlement'), sp: rrw.getComponent(id, 'spatial') }));
  let trades = 0;
  for (let i = 0; i < settlements.length && trades < maxPairs; i++) {
    for (let j = 0; j < settlements.length && trades < maxPairs; j++) {
      if (i === j) continue;
      const A = settlements[i], B = settlements[j];
      const dx = A.sp.pos[0] - B.sp.pos[0], dz = A.sp.pos[2] - B.sp.pos[2];
      if (dx * dx + dz * dz > 300 * 300) continue;
      for (const good of GOOD_NAMES) {
        if (A.s.store[good] > 60 && B.s.store[good] < 15) {
          const qty = Math.min(20, Math.floor(A.s.store[good] - 40));
          A.s.store[good] -= qty;
          B.s.store[good] += qty;
          rrw.emitEvent({
            type: 'economy.trade.executed',
            subject: A.id,
            cause: null,
            data: { from: A.id, to: B.id, good, qty },
            tick: world.clock.tick,
          });
          world.tese?.touch('D-12', `trade ${good}:${qty} ${A.id}->${B.id}`, world.clock.tick);
          trades++;
          break;
        }
      }
    }
  }
  return trades;
}
