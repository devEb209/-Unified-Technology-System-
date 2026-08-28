// UTS :: singularity/models — ModelRegistry with conceptual tiers.
// Selection is task-driven: the CHEAPEST capable model wins — never
// "always the most powerful". Tiers: C < B < A < A+ < S < S+ < S++ (Main).

export const TIER_RANK = Object.freeze({ 'C': 0, 'B': 1, 'A': 2, 'A+': 3, 'S': 4, 'S+': 5, 'S++': 6 });

export function defaultModels() {
  return [
    { id: 'heuristic-core', tier: 'C', provider: 'heuristic', costPer1k: 0, latencyMs: 0.1, context: 8000, capabilities: { text: true, reasoning: false, code: false, vision: false, structured: true, tools: false } },
    { id: 'puter-auto', tier: 'A', provider: 'puter', costPer1k: 0, latencyMs: 900, context: 32000, capabilities: { text: true, reasoning: true, code: true, vision: false, structured: true, tools: false } },
    { id: 'gpt-main', tier: 'S++', provider: 'openai', costPer1k: 10, latencyMs: 1200, context: 128000, capabilities: { text: true, reasoning: true, code: true, vision: true, structured: true, tools: true } },
  ];
}

export class ModelRegistry {
  constructor(models = null) {
    this.models = new Map();
    for (const m of models ?? defaultModels()) this.register(m);
  }

  register(model) {
    if (!TIER_RANK.hasOwnProperty(model.tier)) throw new Error(`unknown tier ${model.tier}`);
    this.models.set(model.id, model);
    return model;
  }

  get(id) { return this.models.get(id) ?? null; }
  list() { return [...this.models.values()]; }

  /**
   * Select the cheapest model that satisfies the needs.
   * needs: {reasoning?, code?, vision?, tools?, structured?, maxCost?, maxLatency?, context?}
   * Returns sorted candidates (best first) — caller walks availability.
   */
  select(needs = {}) {
    const capable = this.list().filter(m => {
      const c = m.capabilities;
      if (needs.reasoning && !c.reasoning) return false;
      if (needs.code && !c.code) return false;
      if (needs.vision && !c.vision) return false;
      if (needs.tools && !c.tools) return false;
      if (needs.structured && !c.structured) return false;
      if (needs.maxCost != null && m.costPer1k > needs.maxCost) return false;
      if (needs.maxLatency != null && m.latencyMs > needs.maxLatency) return false;
      if (needs.context != null && (m.context ?? 0) < needs.context) return false;
      return true;
    });
    // cheapest sufficient: tier asc, then cost asc, then latency asc
    capable.sort((a, b) =>
      (TIER_RANK[a.tier] - TIER_RANK[b.tier]) ||
      (a.costPer1k - b.costPer1k) ||
      (a.latencyMs - b.latencyMs));
    return capable;
  }
}
