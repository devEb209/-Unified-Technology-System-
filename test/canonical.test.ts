import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HeuristicProvider, ModelRegistry, ProviderRegistry } from '../src/ai/registries.ts';
import { MemorySystem } from '../src/ai/memory.ts';
import { SingularityCore, createDefaultAgents, createDefaultTools } from '../src/ai/core.ts';
import { Rng } from '../src/core/index.ts';
import { RRW } from '../src/rrw/index.ts';
import { createUes, type Engine } from '../src/ues/engine.ts';
import { buildVillage } from '../src/ues/npc.ts';
import { Npc } from '../src/ues/npc.ts';
import { behaviorScale, World } from '../src/ues/world.ts';
import { RealLife } from '../src/ues/graphics.ts';
import { HARDWARE_PRESETS } from '../src/d-o15/index.ts';
import { MATERIAL_THRESHOLD } from '../src/rrw/index.ts';

const HW = HARDWARE_PRESETS['high-end'];

/* ------------------------------------------------------------------ */
/* D: valores fracionários têm EFEITO (não são decoração)             */
/* ------------------------------------------------------------------ */

test('D fracionário: escala de comportamento é intermediária (0 < 0.5 < 1)', () => {
  assert.equal(behaviorScale(0), 0);
  assert.equal(behaviorScale(0.25), 0);
  assert.equal(behaviorScale(0.5), 0.5);
  assert.equal(behaviorScale(0.74), 0.5);
  assert.equal(behaviorScale(0.75), 1);
  assert.equal(behaviorScale(1), 1);
});

function coarseWorld(): { w: World; ctx: () => { dt: number; time: number; rng: Rng; world: World } } {
  const w = new World({ seed: 5, gridDim: 8, chunkSize: 8 }, undefined, new Rng(5));
  w.setFocus(24, 24);
  w.stream();
  return { w, ctx: () => ({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w }) };
}

test('D fracionário: percepção de NPC em coarse (0.5) é menor que em full (1)', () => {
  const { w, ctx } = coarseWorld();
  Npc.ensureComponents(w.rrw);
  const near = w.rrw.create({ name: 'perto', categories: ['entity'], components: { Position: { x: 24.5, y: 24 } }, detail: 1 });
  const far = w.rrw.create({ name: 'longe', categories: ['entity'], components: { Position: { x: 24 + 5, y: 24 } }, detail: 1 });
  const npc = Npc.create(w, { x: 24, y: 24 });
  // full: vê as duas (raio 6)
  npc.ent.detail = 1;
  const perFull = npc.perceive(ctx());
  assert.ok(perFull.visible.some((e) => e.id === near.id));
  assert.ok(perFull.visible.some((e) => e.id === far.id));
  // coarse: raio 3 → só a próxima
  npc.ent.detail = 0.5;
  const perCoarse = npc.perceive(ctx());
  assert.ok(perCoarse.visible.some((e) => e.id === near.id));
  assert.ok(!perCoarse.visible.some((e) => e.id === far.id), 'coarse não vê além do raio reduzido');
  // abstrato: não vê nada
  npc.ent.detail = 0;
  const perAbs = npc.perceive(ctx());
  assert.equal(perAbs.visible.length, 0);
  void far;
});

test('D fracionário: NPC coarse não faz trade (exige interação fina)', () => {
  const w = new World({ seed: 11, gridDim: 8, chunkSize: 8 }, undefined, new Rng(11));
  w.setFocus(24, 24);
  w.stream();
  Npc.ensureComponents(w.rrw);
  w.spawnStructure('market', 24, 24);
  const npc = Npc.create(w, { x: 24, y: 24 });
  const m = npc.mind;
  m.needs.hunger = 0.8;
  m.inventory.food = 0;
  m.money = 20;
  m.goal = null;
  m.retargetAt = 0;
  npc.ent.detail = 0.55; // coarse
  const market = w.rrw.query({ categories: ['structure'], data: { type: 'market' } })[0]!;
  const stockBefore = (market.data.stock as { food: { qty: number } }).food.qty;
  for (let i = 0; i < 40; i++) {
    w.rrw.time += 0.1;
    npc.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  }
  const stockAfter = (market.data.stock as { food: { qty: number } }).food.qty;
  assert.equal(stockAfter, stockBefore, 'coarse não compra no mercado (comportamento fracionário)');
});

/* ------------------------------------------------------------------ */
/* D-O15: controla materialização/abstração (raio adaptativo)         */
/* ------------------------------------------------------------------ */

test('D-O15 + materialização: pressão extrema encolhe a zona materializada', () => {
  const e = createUes({ seed: 7, hardware: { ...HW, id: 'workstation', cpuBudgetMs: 0.05 }, backend: 'null' });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  buildVillage(w, c - 8, c + 8, { population: 4 });
  for (let i = 0; i < 60; i++) w.spawnNpc({ x: c + w.rng.range(-8, 8), y: c + w.rng.range(-8, 8) });
  const cfg = w.configuredRadius();
  for (let i = 0; i < 120; i++) e.tick();
  assert.ok(e.lastDecisionPressure > 0.9, `pressão medida alta (${e.lastDecisionPressure.toFixed(2)})`);
  assert.ok(w.focusRadius.outer < cfg.outer, `zona materializada encolheu (${cfg.outer} → ${w.focusRadius.outer})`);
  const matUnderLoad = w.rrw.stats().material;
  // folga de volta: pressão baixa → restaura o raio configurado
  e.setHardware(HW);
  e.profiler.clear();
  for (let i = 0; i < 120; i++) e.tick();
  assert.equal(w.focusRadius.outer, cfg.outer, 'raio restaurado em folga');
  assert.ok(w.rrw.stats().material >= matUnderLoad, 're-materialização ao aliviar a pressão');
});

/* ------------------------------------------------------------------ */
/* Causalidade verificável                                             */
/* ------------------------------------------------------------------ */

test('causalidade: validateCausality detecta causa fabricada e passa no fluxo real', () => {
  const r = new RRW();
  const a = r.create({ name: 'a', categories: ['entity'] });
  const b = r.create({ name: 'b', categories: ['entity'] });
  r.emit('root.event', [a.id]);
  r.emit('child.event', [b.id], {}, { by: a.id, event: 'root.event' });
  assert.equal(r.validateCausality().length, 0, 'fluxo legítimo sem violações');
  // causa FABRICADA (evento que nunca aconteceu)
  r.emit('fake.cause', [b.id], {}, { by: a.id, event: 'never.happened' });
  const v = r.validateCausality();
  assert.equal(v.length, 1);
  assert.equal(v[0].missingEvent, 'never.happened');
  // causa com entidade inexistente
  r.emit('fake.by', [b.id], {}, { by: 'ent_fantasma', event: 'root.event' });
  const v2 = r.validateCausality();
  assert.ok(v2.some((x) => x.missingBy === 'ent_fantasma'));
});

test('causalidade: invariants do mundo incluem validação causal', () => {
  const e = createUes({ seed: 3, hardware: HW, backend: 'null' });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  buildVillage(w, c - 6, c + 6, { population: 3 });
  e.society.refresh();
  e.advance(8);
  const inv = w.checkInvariants();
  assert.equal(inv.ok, true, inv.issues.join('; '));
});

/* ------------------------------------------------------------------ */
/* Processos em diferentes níveis de detalhe (continuidade)           */
/* ------------------------------------------------------------------ */

test('processos: fogo continua queimando através de abstração → materialização', () => {
  const w = new World({ seed: 8, gridDim: 8, chunkSize: 8 }, undefined, new Rng(8));
  w.setFocus(24, 24);
  w.stream();
  const fire = w.rrw.create({ name: 'fogo', categories: ['phenomenon/fire'], components: { Position: { x: 24, y: 24 } }, data: { fuel: 3 }, detail: 1 });
  w.rrw.startProcess('fire', [fire.id]);
  const ctx = { dt: 0.1, time: w.rrw.time, rng: w.rng, rrw: w.rrw };
  const fuel0 = Number(fire.data.fuel);
  for (let i = 0; i < 5; i++) {
    w.rrw.time += 0.1;
    w.rrw.stepProcess('fire', ctx);
  }
  const fuelMaterial = Number(fire.data.fuel);
  assert.ok(fuelMaterial < fuel0, 'fogo evolui materializado');
  // abstraí (saiu do foco)
  w.rrw.abstractize(fire.id, 'teste');
  assert.equal(w.rrw.get(fire.id)?.detail, 0);
  const stateAtAbstract = w.rrw.processStateOf('fire', fire.id);
  for (let i = 0; i < 5; i++) {
    w.rrw.time += 0.1;
    w.rrw.stepProcess('fire', ctx);
  }
  const fuelAbstract = Number(fire.data.fuel);
  assert.ok(fuelAbstract < fuelMaterial, 'processo evolui em abstração (tick abstrato)');
  assert.equal(w.rrw.processStateOf('fire', fire.id), stateAtAbstract, 'estado do processo preservado');
  // re-materializa: continua de onde parou (sem reinício)
  w.rrw.materialize(fire.id, 1, 'teste');
  const before = Number(fire.data.fuel);
  w.rrw.time += 0.1;
  w.rrw.stepProcess('fire', ctx);
  assert.ok(Number(fire.data.fuel) < before, 'continuidade após re-materialização');
});

/* ------------------------------------------------------------------ */
/* RRW não é limitado a mapas (realidade é aberta)                    */
/* ------------------------------------------------------------------ */

test('RRW fora do espaço: propagação de informação (sem posição, sem mapa)', () => {
  const r = new RRW();
  // população ABSTRATA (D-1): só estado semântico, sem Position
  const people: string[] = [];
  for (let i = 0; i < 12; i++) {
    people.push(r.create({ name: `pessoa-${i}`, categories: ['organism/human', 'information/bearer'], data: { knows: false }, detail: 0 }).id);
  }
  // rede de contato (relações — não espaciais)
  for (let i = 0; i < people.length; i++) {
    const j = (i + 1) % people.length;
    r.relate(people[i], people[j], 'contacts', { weight: 1 });
  }
  // processo abstrato de propagação (rumor)
  r.defineProcess('rumor', {
    init: () => 'idle',
    abstractTick: (ent) => {
      if (ent.data.knows) return;
      const neighbor = r.neighbors(ent.id, 'contacts').find((n) => n.data.knows);
      if (neighbor) {
        ent.data.knows = true;
        r.emit('info.spread', [ent.id], { via: neighbor.id }, { by: neighbor.id, event: 'info.knows', description: 'aprendeu de um contato' });
        r.emit('info.knows', [neighbor.id], {});
      }
    },
  });
  r.startProcess('rumor', people);
  const source = people[0];
  r.get(source)!.data.knows = true;
  r.emit('info.knows', [source]);
  let rounds = 0;
  while (people.filter((p) => r.get(p)!.data.knows).length < people.length && rounds < 50) {
    r.time += 0.1;
    r.stepProcess('rumor', { dt: 0.1, time: r.time, rng: new Rng(1), rrw: r });
    rounds++;
  }
  assert.equal(people.filter((p) => r.get(p)!.data.knows).length, people.length, 'rumor propagou pela rede');
  assert.ok(rounds < people.length, 'propagação em rede é O(grafo), não por força bruta');
  // causalidade verificável também fora do espaço
  assert.equal(r.validateCausality().length, 0);
  // todas abstratas — zero custo de detalhe (D-1)
  assert.ok(people.every((p) => r.get(p)!.detail === 0));
});

/* ------------------------------------------------------------------ */
/* Real Life extensível (fenômenos novos em runtime)                  */
/* ------------------------------------------------------------------ */

test('Real Life: regras custom entram em runtime (sistema aberto)', () => {
  const rl = new RealLife();
  rl.addRule('thermal-shimmer', (state, env, dt) => {
    state.shimmer = Math.min(1, (state.shimmer ?? 0) + (env.weather === 'clear' && env.timeOfDay > 0.6 ? 0.1 * dt : -0.1 * dt));
  });
  const env = { weather: 'clear', wind: 0.2, humidity: 0.4, timeOfDay: 0.7 };
  for (let i = 0; i < 30; i++) rl.update(env, 0.5);
  assert.ok((rl.state as Record<string, number>).shimmer > 0.3, `shimmer custom evolui (${(rl.state as Record<string, number>).shimmer.toFixed(2)})`);
  assert.ok(rl.ruleNames().includes('thermal-shimmer'));
  // padrões intactos (chuva ainda molha)
  for (let i = 0; i < 20; i++) rl.update({ weather: 'rain', wind: 0.2, humidity: 0.8, timeOfDay: 0.5 }, 0.5);
  assert.ok(rl.state.wetness > 0.5);
});

/* ------------------------------------------------------------------ */
/* Singularity AI: pronta para provider real (sem reescrever o core)  */
/* ------------------------------------------------------------------ */

test('AI: um provider EXTERNO pluga no core sem alterar a orquestração', () => {
  // Provider externo simulado (determinístico) — representa um LLM real
  // chegando via ProviderRegistry (mesmo contrato do PuterProvider).
  // Um LLM real responderia com JSON; este provider simula exatamente isso.
  class SimulatedLlmProvider implements Provider {
    readonly id = 'sim-llm';
    readonly label = 'Simulated LLM (provider externo)';
    isAvailable(): boolean {
      return true;
    }
    call(req: ProviderRequest): ProviderResult {
      const p = req.payload ?? {};
      if (p.kind === 'plan') {
        // "o LLM" devolve o plano estruturado do objetivo
        const steps: Array<{ id: string; agent: string; action: string; args: Record<string, unknown>; verify: Record<string, unknown> | null }> = [
          { id: 'x1', agent: 'world-builder', action: 'create-biome', args: { biome: p.biome, x: p.x, y: p.y }, verify: { biome: p.biome } },
        ];
        if (Array.isArray(p.structures) && (p.structures as string[]).length) {
          steps.push({ id: 'x2', agent: 'world-builder', action: 'build-structures', args: { structures: p.structures, x: p.x, y: p.y }, verify: { structures: (p.structures as string[]).length } });
        }
        if (Number(p.npcs) > 0) {
          steps.push({ id: 'x3', agent: 'npc-designer', action: 'spawn-npcs', args: { count: Number(p.npcs), x: p.x, y: p.y }, verify: { npcs: Number(p.npcs) } });
        }
        steps.push({ id: 'x4', agent: 'verifier', action: 'check-invariants', args: {}, verify: { invariants: true } });
        return { ok: true, content: 'plano gerado', structured: { objective: p.objective, steps } };
      }
      if (p.kind === 'verify') return { ok: true, content: 'ok', structured: { ok: true, issues: [] } };
      return { ok: true, content: `ok:${String(p.kind)}`, structured: null };
    }
  }
  const providers = new ProviderRegistry();
  providers.define(new HeuristicProvider());
  providers.define(new SimulatedLlmProvider());
  const models = new ModelRegistry();
  models.define({ id: 'ext-architect', providerId: 'sim-llm', tier: 'S++', capabilities: ['planning', 'decomposition'], cost: 2.0 });
  models.define({ id: 'heuristic-coder', providerId: 'heuristic', tier: 'S', capabilities: ['code', 'specification'], cost: 0.6 });
  models.define({ id: 'heuristic-critic', providerId: 'heuristic', tier: 'A', capabilities: ['verification', 'critique'], cost: 0.3 });
  // seleção por capacidade deve escolher o modelo do provider externo p/ planning
  const pick = models.select({ capabilities: ['planning'], complexity: 0.9 });
  assert.equal(pick.model.id, 'ext-architect', 'planning complexo → provider externo (mais capaz)');
  // e a orquestração funciona com ele (core inalterado): o PLANO veio do provider externo
  const engine = createUes({ seed: 13, hardware: HW, backend: 'null' });
  const w = engine.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  const core = new SingularityCore({
    models,
    providers,
    tools: createDefaultTools(() => ({ world: w })),
    agents: createDefaultAgents(),
    memory: new MemorySystem(),
  });
  const report = core.run(`construir bioma forest com 3 NPCs e uma casa em x ${Math.round(c)} y ${Math.round(c)}`, { world: w, rng: engine.rng, now: 0 });
  assert.equal(report.status, 'success', report.summary);
  assert.ok(report.modelsUsed.includes('ext-architect'), 'Main Model do provider externo planejou');
  assert.equal(w.npcCount(), 3, 'mundo construído a partir do plano do provider externo');
});

/* ------------------------------------------------------------------ */
/* Materialização ⇄ abstração: preservação completa (item 10)         */
/* ------------------------------------------------------------------ */

test('materialização: round-trip preserva identidade, posição, memória, relações, causalidade, processos', () => {
  const w = new World({ seed: 21, gridDim: 8, chunkSize: 8 }, undefined, new Rng(21));
  w.setFocus(24, 24);
  w.stream();
  Npc.ensureComponents(w.rrw);
  w.spawnStructure('market', 24, 24);
  const npc = Npc.create(w, { x: 24, y: 24, work: 'farmer' });
  const market = w.rrw.query({ categories: ['structure'], data: { type: 'market' } })[0]!;
  w.rrw.relate(npc.id, market.id, 'works-at', { weight: 1 });
  npc.relateTo(market.id).trust = 0.6;
  w.rrw.emit('npc.hunger', [npc.id], { hunger: 0.6 });
  w.rrw.emit('npc.trade', [npc.id, market.id], { item: 'food', qty: 1, price: 2 }, { by: npc.id, event: 'npc.hunger', description: 'comi por fome' });
  const idBefore = npc.id;
  const posBefore = w.positionOf(npc.id)!;
  const moneyBefore = npc.mind.money;
  // abstrai
  w.rrw.abstractize(npc.id, 'foco-afastou');
  assert.equal(w.rrw.get(npc.id)?.detail, 0);
  // materializa de volta
  w.rrw.materialize(npc.id, 1, 'foco-voltou');
  const ent = w.rrw.get(npc.id)!;
  assert.equal(ent.id, idBefore, 'identidade preservada');
  const posAfter = w.positionOf(npc.id)!;
  assert.equal(posAfter.x, posBefore.x, 'posição preservada');
  assert.equal(npc.mind.money, moneyBefore, 'memória/estado preservado');
  assert.equal(npc.mind.relations[market.id]?.trust, 0.6, 'relações de confiança preservadas');
  assert.equal(w.rrw.neighbors(npc.id, 'works-at', 'out').length, 1, 'relações estruturais preservadas');
  const trade = w.rrw.eventsOf(npc.id).find((e) => e.type === 'npc.trade');
  assert.ok(trade, 'eventos (causalidade) preservados');
  assert.equal(trade.cause?.event, 'npc.hunger', 'cadeia causal preservada');
  assert.ok(w.rrw.eventsOf(npc.id).some((e) => e.type === 'npc.hunger'), 'evento causa preservado');
  assert.equal(w.rrw.validateCausality().length, 0);
  void MATERIAL_THRESHOLD;
});
