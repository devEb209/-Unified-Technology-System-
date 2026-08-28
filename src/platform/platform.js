// UTS :: platform — THE UTS PLATFORM.
//
//   UTS = plataforma geral (infraestrutura, serviços, IA-first, ferramentas)
//   UES = engine que roda DENTRO da plataforma usando essa infraestrutura
//
// The platform is engine-agnostic: it hosts services (storage, AI, research,
// github, apps, projects) that ANY engine or app consumes. The UES is just
// one registered consumer — the platform is strictly larger.

import { ServiceRegistry } from './service-registry.js';
import { AppHost } from './apps.js';
import { AIService } from './services/ai-service.js';
import { ResearchService, MemorySearchProvider } from './services/research-service.js';
import { GitHubService } from './services/github-service.js';
import { CreationProjectManager } from './projects.js';
import { Comm } from '../core/comm.js';
import { EventBus } from '../core/events.js';
import { MemoryStorage } from '../persistence/storage.js';
import { registerPlatformTools } from '../singularity/platform-tools.js';

export class UTSPlatform {
  constructor({ storage = null, search = null } = {}) {
    this.services = new ServiceRegistry();
    this.bus = new EventBus();
    this.comm = new Comm();          // OUR inter-module communication
    this.storage = storage ?? new MemoryStorage();

    this.ai = new AIService();
    this.research = new ResearchService({ search });
    this.github = new GitHubService();
    this.apps = new AppHost({ storage: this.storage, bus: this.bus });
    this.projects = null; // wired at attachCore (needs the Singularity Core)

    this.services.register(this.ai);
    this.services.register(this.research);
    this.services.register(this.github);
    this.services.register(this.apps);
    this.services.register({
      name: 'storage',
      capabilities: () => ['kv', 'durable'],
      status: () => ({ backend: this.storage.constructor.name }),
    });
    this.services.register({
      name: 'events',
      capabilities: () => ['pubsub'],
      status: () => ({ ok: true }),
    });
    this.services.register({
      name: 'comm',
      capabilities: () => ['request-response', 'events'],
      status: () => this.comm.report(),
    });
    this._wireComm();
  }

  /** module communication routes (native, typed, timeout-protected) */
  _wireComm() {
    this.comm.route('ask', async ({ objective, opts }) => this.ai.processObjective(objective, opts ?? {}));
    this.comm.route('research.validate', async ({ question }) => this.research.validate(question));
    this.comm.route('system.status', async () => this.status());
  }

  /**
   * Wire a built system (Core + UES + World + RRW) into the platform:
   * the AI-first service gains its brain, projects become durable, and the
   * engine registers itself as a platform consumer (UES ⊂ UTS).
   */
  attachCore(core, { ues = null } = {}) {
    this.ai.attach(core);
    core.platform = this;
    // research triangulates across every structured provider the platform has
    this.research.setProviders(core.providers.list().filter(p => p.capabilities?.().structured));
    // durable creation projects
    this.projects = new CreationProjectManager({ core, storage: this.storage });
    // platform tools become available to the AI (services as tools)
    registerPlatformTools(core);
    // the engine is a CONSUMER of the platform, never the platform itself
    if (ues) {
      this.services.register({
        name: 'ues',
        capabilities: () => ['engine', 'world-sim', 'frames', 'render-backends'],
        status: () => {
          const s = ues.getStats();
          return { tick: s.tick, npcs: s.counts.npcs, settlements: s.counts.settlements };
        },
      });
      this.ues = ues;
    }
    return this;
  }

  /** AI-first entry: the user just says what they want */
  ask(objective, opts = {}) {
    return this.ai.processObjective(objective, opts);
  }

  async status() {
    return {
      platform: 'UTS',
      services: this.services.list(),
      health: await this.services.health(),
      apps: this.apps.status(),
      projects: this.projects?.status() ?? { active: 0, cached: 0 },
      research: this.research.status(),
    };
  }
}

/** factory with sensible defaults */
export function createPlatform({ storage = null, search = null } = {}) {
  return new UTSPlatform({ storage: storage ?? new MemoryStorage(), search });
}

export { MemorySearchProvider };
