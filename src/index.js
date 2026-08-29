// UTS :: index — public API and system factory.
//
//   UTS (architecture: representation of reality)
//    ├── RRW          — open, multilevel, causal representation (source of truth)
//    ├── Tese dos D   — functional layers (D-0..D-14) with observable effects
//    ├── D-O15        — optimization: measured pressure -> strategy, defer-not-discard
//    ├── Singularity AI — Core + Providers + Models + Agents + Tools + Memory
//    └── UES          — engine application: world, NMN, society, frames
//
//   Chain: UTS -> RRW -> D -> D-O15 -> UES -> Frame -> RendererBackend -> GPU

import { ScaleLadder } from './world/scales.js';
import { registerGenesisTools } from './singularity/genesis-tools.js';
import { RNG } from './core/rng.js';
import { Clock } from './core/clock.js';
import { EventBus } from './core/events.js';
import { PerfMeter } from './core/perf.js';
import { Logger } from './core/log.js';
import { RRW } from './rrw/registry.js';
import { TeseDosD } from './d/tese.js';
import { DO15 } from './d/do15.js';
import { World } from './world/world.js';
import { AsyncChunkSampler, supported as workerSupported } from './world/async-sampler.js';
import { UES } from './ues/ues.js';
import { ProviderRegistry } from './singularity/provider.js';
import { HeuristicProvider } from './singularity/heuristic.js';
import { ExternalLLMProvider } from './singularity/external.js';
import { PuterProvider } from './singularity/puter.js';
import { ModelRegistry } from './singularity/models.js';
import { SingularityCore } from './singularity/core.js';
import { processTypeRegistry } from './persistence/snapshot.js';

export const UTS_VERSION = '1.0.0';

export { RNG, Clock, EventBus, PerfMeter, Logger };
export { RRW, MATERIALIZATION, CausalityError, SnapshotError } from './rrw/registry.js';
export { TeseDosD, D_LAYERS } from './d/tese.js';
export { DO15, defaultStrategy } from './d/do15.js';
export { SpatialGrid } from './spatial/grid.js';
export { Terrain, BIOME, BIOME_NAMES } from './world/terrain.js';
export { RealLife, WEATHER_STATES } from './world/reallife.js';
export * as Society from './world/society.js';
export { World } from './world/world.js';
export * as NMN from './nmn/nmn.js';
export { Scheduler } from './ues/scheduler.js';
export { extractFrame } from './ues/frame.js';
export { UES } from './ues/ues.js';
export { ProviderRegistry, PROVIDER_CONTRACT } from './singularity/provider.js';
export { HeuristicProvider } from './singularity/heuristic.js';
export { PuterProvider } from './singularity/puter.js';
export { ExternalLLMProvider } from './singularity/external.js';
export { ModelRegistry, TIER_RANK } from './singularity/models.js';
export { AgentRegistry } from './singularity/agents.js';
export { MemorySystem } from './singularity/memory.js';
export { ToolRegistry, ToolValidationError } from './singularity/tools.js';
export { SingularityCore } from './singularity/core.js';
export { NullRenderer, TextRenderer } from './render/backends.js';
export { WebGL2Renderer } from './render/webgl2.js';
export { RendererError } from './render/rhi.js';
export * as Persistence from './persistence/snapshot.js';
export { MemoryStorage, FileStorage } from './persistence/storage.js';
export { AutosaveManager, AutosaveError, createAutosave } from './persistence/autosave.js';
export { ChunkCache } from './persistence/chunk-cache.js';
export { renderBinaural } from './audio/spatial.js';
export { MusicDirector, worldTension, MODES } from './audio/music.js';

// UTS PLATFORM (UTS = platform · UES = engine inside the platform)
export { UTSPlatform, createPlatform, MemorySearchProvider } from './platform/platform.js';
export { ServiceRegistry } from './platform/service-registry.js';
export { AppHost, AppError } from './platform/apps.js';
export { AIService } from './platform/services/ai-service.js';
export { ResearchService, ResearchError } from './platform/services/research-service.js';
export { GitHubService } from './platform/services/github-service.js';
export { CreationProjectManager, ProjectError, planProject } from './platform/projects.js';
export { defineExperience, bootExperience } from './ues/experience.js';
export { ExperienceError, ENGINE_SYSTEMS } from './ues/rules.js';
export { Comm, CommError } from './core/comm.js';
export { GPUResourceManager, ProgramCache, RHIError, RHI_DEVICE_CONTRACT } from './render/rhi.js';
export { MaterialLibrary } from './render/materials.js';
export { LightSystem } from './render/lighting.js';
export { frustumPlanes, sphereVisible, cullFrame } from './render/culling.js';
export { StreamingSystem } from './world/streaming.js';
export { PhysicsWorld, GRAVITY } from './physics/physics.js';
export { AudioDirector, encodeWav } from './audio/uts-audio.js';
export { AudioStream } from './audio/stream.js';
export { AudioDeviceError, MemoryDevice, NodePacerDevice, WebAudioDevice, createDevice, resample, AUDIO_DEVICE_CONTRACT } from './audio/backends.js';
export { Mixer } from './audio/mixer.js';
export { spatialize } from './audio/spatial.js';
export { UTSDB, UTSDBError, MemoryJournal, FileJournal } from './persistence/utsdb.js';

/** construct the Singularity AI stack over a live system */
export function buildSingularity({ ues, world, rrw, memory = null, log = null, providers = null, models = null }) {
  const providerRegistry = providers ?? new ProviderRegistry();
  const modelRegistry = models ?? new ModelRegistry();
  if (providerRegistry.names().length === 0) {
    providerRegistry.register(new HeuristicProvider(), { isDefault: true });
    const puter = new PuterProvider();
    // Puter registered only when actually present (access layer, not the intelligence)
    if (puter._ai()) providerRegistry.register(puter);
    // R6: a REAL LLM joins the loop ONLY through secure configuration (env).
    // The key never enters logs/snapshots/memory (ExternalLLMProvider masks it).
    const envKey = process.env?.UTS_LLM_API_KEY ?? process.env?.OPENAI_API_KEY ?? null;
    if (envKey) {
      providerRegistry.register(new ExternalLLMProvider({
        name: 'llm-env',
        baseUrl: process.env?.UTS_LLM_BASE_URL ?? 'https://api.openai.com/v1',
        apiKey: envKey,
        model: process.env?.UTS_LLM_MODEL ?? 'gpt-4o-mini',
        costPer1k: Number(process.env?.UTS_LLM_COST ?? 0.5),
      }));
      modelRegistry.register({
        id: 'llm-env', tier: 'B', provider: 'llm-env', costPer1k: Number(process.env?.UTS_LLM_COST ?? 0.5),
        latencyMs: 900, context: 128000,
        capabilities: { text: true, reasoning: true, code: true, vision: false, structured: true, tools: false },
      });
    }
  }
  return new SingularityCore({
    ues, world, rrw,
    providers: providerRegistry,
    models: modelRegistry,
    memory: memory ?? undefined,
    log,
  });
}

/** factory: one coherent reality, wired end to end */
export function createUTS({
  seed = 'uts',
  worldSeed = null,
  now = null,
  log = null,
  schedulerBudgetMs = 0,
  rng = null,
  clock = null,
  bus = null,
  tese = null,
  do15 = null,
  perf = null,
  providers = null,
  coreMemory = null,
  platform = null,
  asyncStreaming = false,
} = {}) {
  const logger = log instanceof Logger ? log : new Logger(log ?? { level: 'warn' });
  const theRng = rng ?? new RNG(seed);
  const theClock = clock ?? new Clock();
  const theBus = bus ?? new EventBus();
  const theTese = tese ?? new TeseDosD();
  const theDo15 = do15 ?? new DO15({ tese: theTese });
  const thePerf = perf ?? new PerfMeter(now ? { now } : {});

  const rrw = new RRW({ rng: theRng, bus: theBus, tese: theTese });
  for (const [kind, def] of processTypeRegistry()) rrw.registerProcessType(kind, {
    evolveAbstract: def.evolveAbstract,
    evolveDetailed: def.evolveAbstract, // abstract stats flow even when materialized
  });

  const world = new World({
    rrw, rng: theRng, clock: theClock, tese: theTese, do15: theDo15,
    seed: worldSeed ?? `${seed}:world`, bus: theBus,
  });

  // R6: off-thread chunk sampling (worker_threads). Off by default; the
  // demo and Node hosts opt in. Browsers fall back to synchronous streaming
  // (async-sampler has no static node imports — it is browser-safe).
  if (asyncStreaming && workerSupported()) {
    world.streaming.attachSampler(new AsyncChunkSampler({ seed: world.seed, threads: 2 }));
  }

  const ues = new UES({
    world, perf: thePerf, tese: theTese, do15: theDo15, schedulerBudgetMs,
  });

  // THE REALITY LADDER: every body is TAGGED by its scale (do átomo ao universo)
  world.scales = new ScaleLadder({ world });
  world.ues = ues; // os fenômenos focam onde o OBSERVADOR está (câmera é realidade)

  const core = buildSingularity({ ues, world, rrw, memory: coreMemory ?? undefined, log: logger, providers });

  // GENESIS surface: the AI operates files, commands, builds and the media stack
  registerGenesisTools({ core, ues, world, workspace: process.env.UTS_WORKSPACE ?? null });

  // UTS platform: when provided, the engine registers as a platform consumer
  // and the platform AI (Singularity) gains services, apps and durable projects.
  if (platform) platform.attachCore(core, { ues });

  return {
    version: UTS_VERSION,
    seed,
    rng: theRng,
    clock: theClock,
    bus: theBus,
    tese: theTese,
    do15: theDo15,
    perf: thePerf,
    logger,
    rrw,
    world,
    ues,
    core,
    platform: platform ?? null,
  };
}
