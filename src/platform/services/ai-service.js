// UTS :: platform/services/ai — THE AI-FIRST ACCESS LAYER OF THE PLATFORM.
//
// The user interacts with UTS naturally through AI: describing what they want,
// using files/services/tools as input. This service wraps the Singularity
// stack (Core + Provider/Model/Agent/Tool registries + Memory). It aggregates
// providers — including every model reachable through Puter — but the
// intelligence is the Core's orchestration, never a single vendor.

export class AIService {
  constructor() {
    this.name = 'ai';
    this.core = null;
  }

  /** wire the Singularity Core once the system is built */
  attach(core) {
    this.core = core;
    return this;
  }

  capabilities() {
    return [
      'interpretation', 'planning', 'agents', 'tools', 'memory',
      'multi-provider', 'structured-output', 'fallback-chains',
    ];
  }

  /** natural language in, verified reality mutations out */
  async processObjective(objective, opts = {}) {
    if (!this.core) throw new Error('AI service has no Singularity Core attached');
    return this.core.processObjective(objective, opts);
  }

  /** every model the platform can currently reach (across all providers) */
  models() {
    if (!this.core) return [];
    return this.core.models.list().map(m => ({
      id: m.id, tier: m.tier, provider: m.provider, context: m.context,
    }));
  }

  status() {
    return {
      attached: !!this.core,
      providers: this.core ? this.core.providers.names() : [],
      models: this.models().length,
      lastIntent: this.core?.lastReport?.interpretation?.intent ?? null,
    };
  }

  async health() {
    return this.core ? 'ok' : 'no-core';
  }
}
