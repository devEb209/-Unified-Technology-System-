// UTS :: platform/service-registry — the PLATFORM service layer.
//
// UTS is the PLATFORM: infrastructure, systems, services, AI, tools and
// resources. Engines (UES) and apps consume these services — they never
// re-implement them. Services advertise capabilities and health.

export class ServiceRegistry {
  constructor() {
    this.services = new Map();
  }

  register(service) {
    if (!service.name) throw new Error('service needs a name');
    if (this.services.has(service.name)) throw new Error(`service already registered: ${service.name}`);
    const entry = {
      name: service.name,
      capabilities: service.capabilities?.() ?? [],
      ref: service,
      startedAt: null,
    };
    this.services.set(service.name, entry);
    if (typeof service.start === 'function') service.start();
    entry.startedAt = 'boot';
    return service;
  }

  get(name) {
    return this.services.get(name)?.ref ?? null;
  }

  has(name) {
    return this.services.has(name);
  }

  list() {
    return [...this.services.values()].map(e => ({
      name: e.name,
      capabilities: e.capabilities,
      status: e.ref.status?.() ?? 'unknown',
    }));
  }

  async health() {
    const out = {};
    for (const e of this.services.values()) {
      out[e.name] = typeof e.ref.health === 'function' ? await e.ref.health() : 'unknown';
    }
    return out;
  }
}
