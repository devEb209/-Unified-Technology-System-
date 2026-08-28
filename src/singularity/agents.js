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
