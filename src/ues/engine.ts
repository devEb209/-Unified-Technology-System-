/**
 * UES · Engine — laço de integração.
 *
 * Conecta: RRW (representação) + Tese dos D (níveis) + D-O15 (otimização)
 * + World (mundo) + NMN (NPCs) + Society + Graphics (Real Life).
 *
 * O engine NÃO decide tudo sozinho:
 *  - o D-O15 mede pressão e concede detalhe/Hz por sistema;
 *  - o scheduler executa dentro do orçamento do hardware;
 *  - o mundo evolui mesmo quando um sistema é downgradado
 *    (estado preservado em abstração — regra de materialização).
 */

import { Logger, PerfMeter, Rng, SimClock } from '../core/index.ts';
import { createDefaultTese, type TeseDosD } from '../d/index.ts';
import { AdaptiveScheduler, HARDWARE_PRESETS, Profiler, StrategyEngine, detectHardware, type HardwareProfile, type SystemSpec } from '../d-o15/index.ts';
import { MATERIAL_THRESHOLD, RRW } from '../rrw/index.ts';
import { GraphicsSystem, NullBackend, RealLife, TextBackend, type Frame } from './graphics.ts';
import { Npc } from './npc.ts';
import { Society } from './society.ts';
import { World, type WorldConfig } from './world.ts';

export interface EngineConfig {
  hardware?: HardwareProfile;
  world?: Partial<WorldConfig>;
  seed?: number;
  backend?: 'null' | 'text';
  log?: Logger;
  /** Intervalo (s de simulação) entre reanálises do D-O15. */
  decideEvery?: number;
}

export interface TickInfo {
  time: number;
  ran: string[];
  /** Vencidos, mas adiados por falta de orçamento. */
  deferred: string[];
  overBudget: boolean;
  usedMs: number;
}

export class Engine {
  rrw: RRW;
  world: World;
  tese: TeseDosD;
  strategy: StrategyEngine;
  scheduler: AdaptiveScheduler;
  profiler: Profiler;
  meter: PerfMeter;
  clock: SimClock;
  rng: Rng;
  society: Society;
  graphics: GraphicsSystem;
  realLife: RealLife;
  log: Logger;
  hardware: HardwareProfile;

  private npcs = new Map<string, Npc>();
  /** Última reanálise D-O15 (persistência: mantém o ciclo de decisão). */
  lastDecide = -10;
  private lastTick: TickInfo | null = null;
  lastFrame: Frame | null = null;
  private decideEvery: number;
  private dt = 0.1;
  /** Contadores acumulados (observabilidade de adaptação). */
  counters = { ticks: 0, overBudgetTicks: 0, deferredTotal: 0 };
  /** Pressão da última reanálise do D-O15 (janela fechada). */
  lastDecisionPressure = 0;

  constructor(cfg: EngineConfig = {}) {
    const seed = cfg.seed ?? 42;
    this.log = cfg.log ?? new Logger('ues');
    this.rng = new Rng(seed);
    this.clock = new SimClock();
    this.rrw = new RRW({ log: this.log });
    this.world = new World({ ...cfg.world, seed }, this.rrw, this.rng, this.log);
    this.tese = createDefaultTese();
    this.hardware = cfg.hardware ?? detectHardware();
    this.strategy = new StrategyEngine({ hardware: this.hardware, tese: this.tese, log: this.log });
    this.meter = new PerfMeter();
    this.profiler = new Profiler(this.meter);
    this.scheduler = new AdaptiveScheduler({ strategy: this.strategy, meter: this.meter, log: this.log });
    this.society = new Society(this.world, this.log);
    this.realLife = new RealLife();
    this.graphics = new GraphicsSystem({ world: this.world, realLife: this.realLife, backend: cfg.backend === 'text' ? new TextBackend() : new NullBackend() });
    this.decideEvery = cfg.decideEvery ?? 0.5;

    // NPC factory: world → NMN (inversão: world não conhece Npc).
    // A descobre o engine os NPCs pelo RRW (npcFor) — NPCs criados por
    // qualquer caminho (factory, buildVillage, restore) são simulados.
    this.world.setNpcFactory((opts) => {
      const npc = Npc.create(this.world, opts);
      this.npcs.set(npc.id, npc);
      return npc.ent;
    });
    this.society.define();
    Npc.ensureComponents(this.rrw);

    // Bridge: IA (Singularity Core) lê/aplica otimização via world
    this.world.setOptimizationBridge({
      report: () => this.strategy.report(this.profiler),
      apply: () => this.autoOptimize(),
    });

    this.registerSystems();
  }

  private registerSystems(): void {
    const s = this.scheduler;
    s.register(
      { id: 'environment', baseHz: 10, minHz: 2, baseDetail: 1, priority: 95, critical: true },
      () => {
        const ctx = { dt: this.dt, time: this.rrw.time, rng: this.rng, rrw: this.rrw };
        this.rrw.stepProcess('env.day-night', ctx);
        this.rrw.stepProcess('env.weather', ctx);
        this.rrw.stepProcess('fire', ctx);
      },
    );
    s.register(
      { id: 'streaming', baseHz: 5, minHz: 1, baseDetail: 1, priority: 90, critical: true },
      () => {
        this.world.stream();
      },
    );
    s.register(
      { id: 'npc-mind', baseHz: 5, minHz: 1, baseDetail: 1, priority: 80, critical: true },
      () => {
        const ctx = { dt: this.dt, time: this.rrw.time, rng: this.rng, world: this.world };
        // descobre NPCs pelo RRW (aberto a qualquer origem)
        for (const ent of this.rrw.query({ categories: ['organism/human'] })) {
          const npc = this.npcFor(ent);
          if (!this.rrw.isMaterial(npc.id, MATERIAL_THRESHOLD)) continue; // D-2/D-4: só materializado raciocina fino
          npc.step(ctx);
        }
      },
    );
    s.register(
      { id: 'society', baseHz: 1, minHz: 0.2, baseDetail: 1, priority: 40, critical: true },
      () => {
        this.society.step({ dt: this.dt, time: this.rrw.time, rng: this.rng, world: this.world });
      },
    );
    s.register(
      { id: 'graphics', baseHz: 10, minHz: 0, baseDetail: 1, priority: 10, critical: false },
      () => {
        this.lastFrame = this.graphics.run({ dt: this.dt, time: this.rrw.time });
      },
    );
  }

  /** Wrapper Npc para uma entidade (cache de adoção — idempotente). */
  npcFor(ent: { id: string }): Npc {
    let npc = this.npcs.get(ent.id);
    if (!npc) {
      npc = Npc.adopt(this.world, this.rrw.get(ent.id)!);
      this.npcs.set(ent.id, npc);
    }
    return npc;
  }

  npcList(): Npc[] {
    return [...this.npcs.values()];
  }

  npcById(id: string): Npc | undefined {
    return this.npcs.get(id);
  }

  /**
   * Reconstitui os wrappers Npc a partir das entidades RRW existentes
   * (usado após `restore` — o estado vive no RRW, os wrappers são recriados).
   */
  adoptNpcs(): number {
    this.npcs.clear();
    let n = 0;
    for (const ent of this.rrw.query({ categories: ['organism/human'] })) {
      this.npcs.set(ent.id, Npc.adopt(this.world, ent));
      n += 1;
    }
    return n;
  }

  /** Um passo de simulação (fixed timestep). */
  tick(): TickInfo {
    this.clock.tick(this.dt);
    this.rrw.time = this.clock.time;

    // D-O15: reanálise periódica com profiling real (janela desde a última análise)
    if (this.rrw.time - this.lastDecide >= this.decideEvery) {
      const pressure = this.profiler.pressure(this.hardware.cpuBudgetMs);
      // relevância: NPCs materializados no foco = mais relevante
      const total = this.npcs.size;
      const mat = [...this.npcs.values()].filter((n) => this.rrw.isMaterial(n.id, MATERIAL_THRESHOLD)).length;
      this.strategy.setRelevance('npc-mind', total > 0 ? 0.4 + 0.6 * (mat / total) : 1);
      this.strategy.setRelevance('graphics', 1);
      this.strategy.setRelevance('society', 1);
      this.strategy.decide(this.scheduler.specsList(), pressure);
      this.lastDecisionPressure = pressure;
      this.applyAdaptiveRadius(); // D-O15 controla materialização/abstração (D-1/D-3)
      this.profiler.clear(); // nova janela de profiling
      this.lastDecide = this.rrw.time;
    }

    const info = this.scheduler.step(this.rrw.time, { dt: this.dt, time: this.rrw.time });
    this.lastTick = { time: this.rrw.time, ran: info.ran, deferred: info.deferred, overBudget: info.overBudget, usedMs: info.usedMs };
    if (info.overBudget) this.counters.overBudgetTicks += 1;
    this.counters.deferredTotal += info.deferred.length;
    this.counters.ticks += 1;
    return this.lastTick;
  }

  /** Avança `seconds` de simulação (headless). */
  advance(seconds: number, maxTicks = 100000): TickInfo | null {
    const ticks = Math.min(maxTicks, Math.round(seconds / this.dt));
    let info: TickInfo | null = null;
    for (let i = 0; i < ticks; i++) info = this.tick();
    return info;
  }

  /**
   * Otimização autônoma: degrada/promove o perfil de hardware conforme a
   * pressão medida (Prompt 2/12 — hardware adaptativo).
   */
  autoOptimize(): { applied: boolean; from: string; to: string; reason: string } {
    // usa a última janela FECHADA de profiling (decisão estável, não parcial)
    const pressure = Math.max(this.lastDecisionPressure, this.profiler.pressure(this.hardware.cpuBudgetMs) * 0.5);
    const ladder = ['low-end', 'mid', 'high-end', 'workstation'];
    const idx = ladder.indexOf(this.hardware.id);
    if (idx < 0) return { applied: false, from: this.hardware.id, to: this.hardware.id, reason: 'perfil desconhecido' };
    if (pressure > 0.85 && idx > 0) {
      const to = ladder[idx - 1];
      this.setHardware(HARDWARE_PRESETS[to]);
      return { applied: true, from: this.hardware.id, to, reason: `pressão ${pressure.toFixed(2)} > 0.85` };
    }
    if (pressure < 0.3 && idx < ladder.length - 1) {
      const to = ladder[idx + 1];
      this.setHardware(HARDWARE_PRESETS[to]);
      return { applied: true, from: this.hardware.id, to, reason: `pressão ${pressure.toFixed(2)} < 0.3 (folga)` };
    }
    return { applied: false, from: this.hardware.id, to: this.hardware.id, reason: `pressão ${pressure.toFixed(2)} dentro da faixa do perfil` };
  }

  setHardware(h: HardwareProfile): void {
    this.hardware = h;
    this.strategy.setHardware(h);
    this.log.info(`hardware → ${h.id} (budget ${h.cpuBudgetMs}ms/tick, ${h.memoryBudgetMB}MB)`);
  }

  /** Renderiza um frame sob demanda (ex.: demo). */
  renderFrame(): Frame | null {
    this.lastFrame = this.graphics.run({ dt: this.dt, time: this.rrw.time });
    return this.lastFrame;
  }

  /**
   * D-O15 → materialização: a decisão do sistema 'streaming' ajusta o raio de
   * materialização do mundo. Com pressão, a zona materializada encolhe (mais
   * entidades em abstração, tick mais barato — MESMO resultado, menos custo);
   * com folga, volta ao raio configurado. Estado nunca se perde (D-1).
   */
  private applyAdaptiveRadius(): void {
    const d = this.strategy.decisions.get('streaming');
    if (!d) return;
    const cfg = this.world.configuredRadius();
    if (d.representation === 'full') {
      this.world.setFocusRadius(cfg.active, cfg.outer);
    } else if (d.representation === 'coarse') {
      this.world.setFocusRadius(cfg.active, Math.max(cfg.active, cfg.outer - 1));
    } else {
      // aggregate/cached: zona materializada = só o raio ativo mínimo
      this.world.setFocusRadius(1, Math.max(1, cfg.active));
    }
  }

  stats(): Record<string, unknown> {
    const rep = this.strategy.report(this.profiler);
    return {
      time: Number(this.rrw.time.toFixed(2)),
      frames: this.graphics ? this.lastFrame?.frame ?? 0 : 0,
      hardware: this.hardware.id,
      pressure: rep.pressure,
      bottleneck: rep.bottleneck?.name ?? null,
      memoryMB: rep.memoryMB,
      decisions: rep.decisions.map((d) => `${d.system}=${d.representation}@${d.updateHz}Hz`),
      world: this.world.describe(),
      society: this.society.summary().map((s) => `${s.name}: pop=${s.population} food=${s.stock.food?.toFixed(1)} idx=${s.priceIndex.toFixed(2)}`),
      lastTick: this.lastTick,
    };
  }
}

/** Fábrica padrão da UES (ponto de entrada da aplicação). */
export function createUes(cfg: EngineConfig = {}): Engine {
  return new Engine(cfg);
}
