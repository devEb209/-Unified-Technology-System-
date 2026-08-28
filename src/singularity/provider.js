// UTS :: singularity/provider — Provider contract + registry.
//
// Providers are ACCESS LAYERS to models. Puter is one provider — it is NOT
// the intelligence of UTS. The Core never knows which company/model is used;
// architecture stays vendor-independent with real fallback chains.

export class ProviderRegistry {
  constructor() {
    this.providers = new Map();
    this.defaultName = null;
  }

  register(provider, { isDefault = false } = {}) {
    if (!provider.name) throw new Error('provider needs a name');
    if (typeof provider.generate !== 'function') throw new Error(`provider ${provider.name} needs generate()`);
    this.providers.set(provider.name, provider);
    if (isDefault || !this.defaultName) this.defaultName = provider.name;
    return provider;
  }

  get(name) {
    return this.providers.get(name) ?? null;
  }

  list() {
    return [...this.providers.values()];
  }

  names() {
    return [...this.providers.keys()];
  }
}

/** Capability contract every provider documents (used by ModelRegistry selection):
 *  generate({messages, model, json}) -> Promise<{text, json|null}>
 *  stream({messages, model})         -> async iterator of text deltas (optional)
 *  capabilities() -> {text, reasoning, code, vision, structured, tools, context}
 *  cost(modelId, tokens) -> number
 *  availability() -> Promise<boolean>
 */
export const PROVIDER_CONTRACT = Object.freeze([
  'generate', 'capabilities', 'cost', 'availability',
]);
