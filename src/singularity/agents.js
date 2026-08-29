// UTS :: singularity/agents — specialized agents coordinated by the Core.

export class AgentRegistry {
  constructor() {
    this.agents = new Map();
  }

  register(agent) {
    if (!agent.name || !Array.isArray(agent.capabilities) || typeof agent.execute !== 'function') {
      throw new Error('agent needs name, capabilities[], execute()');
    }
    this.agents.set(agent.name, agent);
    return agent;
  }

  get(name) { return this.agents.get(name) ?? null; }
  list() { return [...this.agents.values()]; }

  /** pick the agent whose capabilities cover the required ones (best coverage first) */
  select(required = []) {
    const req = new Set(required);
    const candidates = this.list().filter(a => [...req].every(r => a.capabilities.includes(r) || a.capabilities.includes('general')));
    if (candidates.length === 0) return null;
    candidates.sort((a, b) => {
      const covA = [...req].filter(r => a.capabilities.includes(r)).length;
      const covB = [...req].filter(r => b.capabilities.includes(r)).length;
      return covB - covA;
    });
    return candidates[0];
  }
}

// ------------------------------------------------------------- built-ins

export function builtinAgents({ core }) {
  return [
    {
      name: 'interpreter',
      capabilities: ['interpretation', 'general'],
      async execute(task, ctx) {
        // calls the selected provider through the core (structured interpretation)
        return ctx.core.interpretObjective(task.objective, task.chosen);
      },
    },
    {
      name: 'world-builder',
      capabilities: ['world', 'general'],
      async execute(task, ctx) {
        return ctx.tools.execute(task.tool, task.params);
      },
    },
    {
      name: 'architect',
      capabilities: ['architecture'],
      async execute(task, ctx) {
        // produces a validated task list from an interpretation
        return ctx.core.planFromInterpretation(task.interpretation);
      },
    },
    {
      name: 'verifier',
      capabilities: ['verification', 'general'],
      async execute(task, ctx) {
        return ctx.core.verifyPlan(task.plan);
      },
    },
    {
      // CODER: generates REAL code in the UTS creation grammar from a
      // structured brief, PARSES it (the parser is the validator), executes
      // and VERIFIES the world state. Self-repairs by simplifying (max 3).
      name: 'coder',
      capabilities: ['code', 'coder', 'world'],
      async execute(task, ctx) {
        const { parseCreation } = await import('./grammar.js');
        const b = task.brief ?? {};
        const gen = (x) => {
          const L = [];
          if (x.settlement) L.push(`crie a vila "${x.settlement.name ?? 'Vila Nova'}" com ${x.settlement.pop ?? 20} moradores`);
          if (x.forest) L.push(`plante uma floresta com ${x.forest} árvores`);
          if (x.weather) L.push(`mude o clima para ${x.weather}`);
          if (x.fire) L.push(`incendeie fogo em ${x.fire[0]}, ${x.fire[1]}`);
          if (x.population) L.push(`spawne ${x.population} npcs`);
          return L.join(' e depois ');
        };
        const TOOL = {
          create_settlement: 'ues.create_settlement',
          plant_forest: 'world.plant_forest',
          set_weather: 'world.set_weather',
          start_fire: 'world.start_fire',
          spawn_population: 'ues.spawn_npcs',
        };
        let code = gen(b);
        let parsed = null, attempts = 0;
        while (attempts < 3) {
          attempts++;
          parsed = parseCreation(code, {});
          if (parsed.commands.length > 0) break;
          code = gen({ settlement: b.settlement, forest: b.forest }); // simplify & retry
        }
        if (!parsed || parsed.commands.length === 0) return { ok: false, attempts, code, error: 'grammar rejected the generated program' };
        const executed = [];
        let anchor = null;
        for (const cmd of parsed.commands) {
          const tool = TOOL[cmd.intent];
          if (!tool) continue;
          const params = { ...cmd.params };
          if (cmd.intent === 'plant_forest' && anchor) params.pos = [anchor[0] + 30, 0, anchor[2]]; // terra firme do assentamento
          const r = await ctx.tools.execute(tool, params);
          if (cmd.intent === 'create_settlement' && r?.pos) anchor = r.pos; // o coder ancora a floresta na TERRA da vila
          executed.push({ tool, result: r?.ok !== false, detail: r?.seeded ?? r?.pop ?? null });
        }
        // VERIFICATION against the world (never trust the return alone)
        const rrw = ctx.ues.world.rrw;
        const verified = {
          settlements: rrw.count ? rrw.count('settlement') : [...rrw.query({ kind: 'settlement' })].length,
          trees: ctx.ues.world.ecology?.trees?.size ?? 0,
          weather: ctx.ues.world.environment.weather,
          burning: [...(ctx.ues.world.combustion?.cells ?? [])].filter(([, c]) => c.burning).length,
        };
        return { ok: true, attempts, code, commands: parsed.commands.length, executed, verified };
      },
    },
    {
      name: 'graphics',
      capabilities: ['graphics'],
      async execute(task, ctx) {
        // tuning of visual quality via D-O15 budgets (measured, never random)
        const do15 = ctx.ues.do15;
        if (task.params?.budget) Object.assign(do15.budget, task.params.budget);
        do15.recomputeStrategy({});
        return { ok: true, strategy: do15.strategy };
      },
    },
    {
      name: 'tester',
      capabilities: ['test'],
      async execute(task, ctx) {
        const before = ctx.ues.world.clock.tick;
        ctx.ues.run(task.params?.ticks ?? 20);
        return { ok: true, ticksRun: ctx.ues.world.clock.tick - before, stats: ctx.ues.getStats().counts };
      },
    },
  ];
}
