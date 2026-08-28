// UTS :: nmn — Natural Mindset of NPCs.
//
// NPCs consider: identity, objectives, needs, memory, relations, knowledge,
// context, perception, experiences, environment and consequences.
// No rigid scripts: utility decisions with EXPLAINABLE reasons, and every
// fear-driven decision traces to a verifiable causal chain in RRW.
//
// The mind is PLAIN DATA (mind component) — behavior lives here as pure
// functions over (world, id). That keeps minds serializable and the NMN
// decoupled from the spatial index (it only calls world.perceive).

import { clamp01, normalize2 } from './mathutil.js';

// ------------------------------------------------------------------ needs

export function updateNeeds(world, id, dt) {
  const mind = world.rrw.getComponent(id, 'mind');
  const n = mind.needs;
  const p = mind.personality;
  n.hunger = clamp01(n.hunger + 0.008 * p.metabolism * dt);
  n.energy = clamp01(n.energy - 0.004 * dt);
  n.social = clamp01(n.social + 0.003 * (2 - p.sociability) * dt);
  return n;
}

// -------------------------------------------------------------- perception

/** perception model adjusted by D-O15 strategy (resolution drops under pressure) */
export function perceptionModel(world, id) {
  const mind = world.rrw.getComponent(id, 'mind');
  const sp = world.rrw.getComponent(id, 'spatial');
  let model = {
    selfId: id,
    range: mind.perceptionRange,
    fovDeg: 170,
    facing: [Math.sin(sp.yaw ?? 0), Math.cos(sp.yaw ?? 0)],
    cap: 12,
  };
  if (world.do15) model = world.do15.decidePerception(model);
  return model;
}

// ---------------------------------------------------------------- decisions

const ACTIONS = ['flee', 'eat', 'rest', 'socialize', 'work', 'wander'];

/** evaluate utilities; returns ranked candidates with explanations */
export function evaluateOptions(world, id, perceived) {
  const mind = world.rrw.getComponent(id, 'mind');
  const n = mind.needs;
  const sp = world.rrw.getComponent(id, 'spatial');
  const threats = perceived.filter(p => p.kind === 'hazard');
  const foods = perceived.filter(p => p.kind === 'bush' && world.rrw.getComponent(p.id, 'resource')?.amount > 0.05);
  const others = perceived.filter(p => p.kind === 'npc');
  const settlement = findSettlement(world, id);
  const threatLevel = threats.reduce((m, t) => Math.max(m, clamp01(1 - t.dist / 25)), 0);
  if (threatLevel > 0.05) mind.needs.safety = clamp01(1 - threatLevel);
  else mind.needs.safety = Math.min(1, mind.needs.safety + 0.01);

  const options = [];
  if (threats.length > 0) {
    options.push({
      action: 'flee', score: (1 - n.safety) * 1.6 + mind.personality.bravery * 0.0,
      target: threats[0].id,
      because: [{ perceived: threats[0].id, kind: 'hazard', dist: +threats[0].dist.toFixed(1), note: 'hazard perceived' }],
    });
  }
  if (foods.length > 0) {
    options.push({
      action: 'eat', score: n.hunger * 1.15,
      target: foods[0].id,
      because: [{ perceived: foods[0].id, kind: 'bush', note: `hunger ${n.hunger.toFixed(2)}` }],
    });
  }
  options.push({ action: 'rest', score: (1 - n.energy) * 1.0 + 0.05, target: null, because: [{ note: `energy ${n.energy.toFixed(2)}` }] });
  if (others.length > 0) {
    options.push({
      action: 'socialize', score: n.social * 0.95 * mind.personality.sociability,
      target: others[0].id,
      because: [{ perceived: others[0].id, kind: 'npc', note: `loneliness ${n.social.toFixed(2)}` }],
    });
  }
  if (settlement) {
    const s = world.rrw.getComponent(settlement, 'spatial');
    const d = Math.hypot(s.pos[0] - sp.pos[0], s.pos[2] - sp.pos[2]);
    options.push({
      action: 'work', score: 0.32 + (d < 40 ? 0.18 : 0),
      target: settlement,
      because: [{ note: `settlement ${settlement} at ${d.toFixed(0)}m` }],
    });
  }
  options.push({ action: 'wander', score: 0.14, target: null, because: [{ note: 'idle' }] });
  return options.sort((a, b) => b.score - a.score);
}

function findSettlement(world, id) {
  const npc = world.rrw.getComponent(id, 'npc');
  return npc?.settlementId ?? null;
}

// ------------------------------------------------------------------ action

export function applyAction(world, id, decision, dt) {
  const rrw = world.rrw;
  const sp = rrw.getComponent(id, 'spatial');
  const mind = rrw.getComponent(id, 'mind');
  const tick = world.clock.tick;

  switch (decision.action) {
    case 'flee': {
      const tsp = rrw.getComponent(decision.target, 'spatial');
      if (tsp) {
        const away = normalize2([sp.pos[0] - tsp.pos[0], sp.pos[2] - tsp.pos[2]]);
        rrw.addComponent(id, 'intent', { target: [sp.pos[0] + away[0] * 24, 0, sp.pos[2] + away[1] * 24], speed: 5.5 });
      }
      // causal fear: first sight of a hazard creates a chained event
      const hz = rrw.getComponent(decision.target, 'hazard');
      if (hz && mind.fear[decision.target] == null) {
        const sightedId = rrw.emitEvent({
          type: 'npc.hazard.sighted', subject: id,
          cause: hz.startedEvent ?? null,
          data: { hazard: decision.target, pos: [...sp.pos] },
          tick,
        });
        mind.fear[decision.target] = sightedId;
        remember(mind, { tick, kind: 'event', type: 'hazard.sighted', ref: sightedId });
      }
      rrw.emitEvent({
        type: 'npc.fled', subject: id,
        cause: mind.fear[decision.target] ?? null,
        data: { from: decision.target },
        tick,
      });
      world.tese?.touch('D-7', `${id} flees (score ${decision.score.toFixed(2)})`, tick);
      break;
    }
    case 'eat': {
      const food = rrw.getComponent(decision.target, 'resource');
      const fsp = rrw.getComponent(decision.target, 'spatial');
      if (food && fsp && food.amount > 0.05) {
        const d = Math.hypot(fsp.pos[0] - sp.pos[0], fsp.pos[2] - sp.pos[2]);
        if (d < 2) {
          food.amount = Math.max(0, food.amount - 0.5);
          food.depletedAt = tick;
          mind.needs.hunger = clamp01(mind.needs.hunger - 0.55);
          know(mind, decision.target);
          rrw.emitEvent({ type: 'npc.ate', subject: id, cause: null, data: { food: decision.target }, tick });
        } else {
          rrw.addComponent(id, 'intent', { target: [fsp.pos[0], 0, fsp.pos[2]], speed: 3.4 });
          know(mind, decision.target);
        }
      }
      break;
    }
    case 'rest': {
      mind.needs.energy = clamp01(mind.needs.energy + 0.05 * dt);
      rrw.removeComponent(id, 'intent');
      break;
    }
    case 'socialize': {
      const osp = rrw.getComponent(decision.target, 'spatial');
      if (osp) {
        const d = Math.hypot(osp.pos[0] - sp.pos[0], osp.pos[2] - sp.pos[2]);
        if (d < 3.5) {
          mind.needs.social = clamp01(mind.needs.social - 0.5);
          const other = rrw.getComponent(decision.target, 'mind');
          if (other) {
            const w = 0.1;
            const a = id < decision.target ? id : decision.target;
            const b = id < decision.target ? decision.target : id;
            const rel = rrw.getRelation(a, b, 'knows');
            rrw.addRelation(a, b, 'knows', { weight: clamp01((rel?.weight ?? 0.2) + w) });
            // gossip: knowledge spreads relationally — ONLY while D-13 is active
            const d13 = world.tese ? world.tese.isEnabled('D-13') : true;
            if (d13) {
              const shared = gossip(mind, other);
              if (shared.length > 0) world.tese?.touch('D-13', `${id} shared ${shared.length} knowledge -> ${decision.target}`, tick);
            }
          }
          rrw.emitEvent({ type: 'npc.socialized', subject: id, cause: null, data: { with: decision.target }, tick });
        } else {
          rrw.addComponent(id, 'intent', { target: [osp.pos[0], 0, osp.pos[2]], speed: 3 });
        }
      }
      break;
    }
    case 'work': {
      const ssp = rrw.getComponent(decision.target, 'spatial');
      const s = rrw.getComponent(decision.target, 'settlement');
      if (ssp && s) {
        const d = Math.hypot(ssp.pos[0] - sp.pos[0], ssp.pos[2] - sp.pos[2]);
        if (d < 30) {
          s.store.food += 0.02 * dt;
          rrw.removeComponent(id, 'intent');
        } else {
          rrw.addComponent(id, 'intent', { target: [ssp.pos[0], 0, ssp.pos[2]], speed: 3 });
        }
      }
      break;
    }
    case 'wander': {
      if (!rrw.getComponent(id, 'intent')) {
        const a = world.rng.next() * Math.PI * 2;
        const r = 6 + world.rng.range(0, 20);
        rrw.addComponent(id, 'intent', { target: [sp.pos[0] + Math.cos(a) * r, 0, sp.pos[2] + Math.sin(a) * r], speed: 2 });
      }
      break;
    }
  }
}

// ------------------------------------------------------------------ memory

function remember(mind, item) {
  mind.memory.push(item);
  if (mind.memory.length > 24) mind.memory.shift();
}

function know(mind, entityId) {
  if (!mind.knowledge.includes(entityId)) {
    mind.knowledge.push(entityId);
    if (mind.knowledge.length > 64) mind.knowledge.shift();
  }
}

/** share knowledge the other mind lacks; returns shared ids */
function gossip(mind, otherMind) {
  const shared = [];
  for (const k of mind.knowledge) {
    if (!otherMind.knowledge.includes(k)) {
      otherMind.knowledge.push(k);
      shared.push(k);
      if (shared.length >= 2) break;
    }
  }
  return shared;
}

// ------------------------------------------------------------------- entry

/** full mind update for one NPC at its scheduled tick */
export function updateMind(world, id, dt) {
  const rrw = world.rrw;
  if (!rrw.get(id)?.alive) return;
  const mind = rrw.getComponent(id, 'mind');
  if (!mind) return;
  updateNeeds(world, id, dt);
  const model = perceptionModel(world, id);
  const { entities: perceived } = world.perceive(
    rrw.getComponent(id, 'spatial').pos, model,
  );
  mind.lastPerceived = perceived.map(p => p.id);
  const options = evaluateOptions(world, id, perceived);
  const decision = options[0];
  decision.scores = options.map(o => ({ action: o.action, score: +o.score.toFixed(3) }));
  decision.tick = world.clock.tick;
  mind.lastDecision = decision;
  mind.decisionCount++;
  remember(mind, { tick: decision.tick, kind: 'decision', action: decision.action, because: decision.because });
  world.tese?.touch('D-7', `${id} decided ${decision.action}`, decision.tick);
  applyAction(world, id, decision, dt);
}

/** wire NMN into a world (keeps world decoupled from nmn module) */
export function attachToWorld(world) {
  world._mindUpdater = (id, dt) => updateMind(world, id, dt);
}
