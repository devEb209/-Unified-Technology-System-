// UTS :: ues — Unified Engine System.
//
// UES ⊂ UTS. It executes the represented reality: it orchestrates systems
// under a D-O15 budget, drives materialization from the camera/focus, and
// extracts Frames for any RendererBackend. UES never owns truth — RRW does.

import { Scheduler } from './scheduler.js';
import { extractFrame } from './frame.js';
import { attachToWorld } from '../nmn/nmn.js';

export class UES {
  constructor({ world, perf = null, tese = null, do15 = null, camera = null, schedulerBudgetMs = 0 } = {}) {
    this.world = world;
    this.perf = perf;
    this.tese = tese;
    this.do15 = do15;
    this.frame = null;
    this.tickN = 0;
    this.camera = {
      pos: camera?.pos ?? [world.terrain.size / 2, 40, world.terrain.size / 2 + 120],
      yaw: camera?.yaw ?? 0.5,
      pitch: camera?.pitch ?? 0.45,
      fovDeg: camera?.fovDeg ?? 60,
      far: camera?.far ?? 600,
    };

    this.scheduler = new Scheduler({ globalBudgetMs: schedulerBudgetMs, perf });

    // ---- canonical system order (D-3 temporal ordering of reality)
    this.scheduler.add({ name: 'weather', priority: 10, fn: dt => world.updateWeather(dt) });
    this.scheduler.add({ name: 'ecology', priority: 20, fn: dt => world.updateEcology(dt) });
    this.scheduler.add({ name: 'economy', priority: 30, fn: dt => world.updateEconomy(dt) });
    this.scheduler.add({ name: 'trade', priority: 40, fn: dt => { if (world.clock.tick % 50 === 0) world.updateTrade(); } });
    this.scheduler.add({ name: 'nmn', priority: 50, fn: dt => world.updateNPCs(dt) });
    this.scheduler.add({ name: 'movement', priority: 60, fn: dt => world.updateMovement(dt) });
    this.scheduler.add({ name: 'materializer', priority: 70, fn: () => world.updateMaterialization(this.camera.pos) });
    this.scheduler.add({
      name: 'deferred', priority: 80,
      fn: () => { if (do15 && do15.deferred.length > 0) do15.runDeferred(1.5); },
    });

    // NMN behavior is attached decoupled from world internals (perceive interface)
    attachToWorld(world);
  }

  /** experience rulesets: enable/disable engine systems without removing them */
  setSystemEnabled(name, enabled) {
    this.scheduler.setEnabled(name, enabled);
    return this;
  }

  moveCamera(pos, yaw = this.camera.yaw, pitch = this.camera.pitch) {
    this.camera.pos = [pos[0], pos[1] ?? this.camera.pos[1], pos[2] ?? this.camera.pos[2]];
    this.camera.yaw = yaw;
    this.camera.pitch = pitch;
  }

  /** one step of the executed reality */
  tick(dt = this.world.clock.dt) {
    const tk = this.perf?.start('ues.tick') ?? null;
    this.world.clock.advance(dt);
    this.tese?.touch('D-3', `tick ${this.world.clock.tick} time ${this.world.clock.time.toFixed(1)}s`, this.world.clock.tick);
    const run = this.scheduler.tick(dt);
    this.perf?.end(tk);
    this.tickN++;

    // feed D-O15 with measured evidence (never guesses).
    // frameMs = cost accumulated SINCE the last report (interval delta), so
    // hosts that never render are not penalized by stale averages and
    // save/load determinism is preserved across machines.
    if (this.do15 && this.tickN % 10 === 0) {
      let memoryMB = 0;
      if (typeof process !== 'undefined' && process.memoryUsage) memoryMB = process.memoryUsage().rss / (1024 * 1024);
      const span = this.perf?.get('frame.extract');
      const frameDelta = span ? span.total - (this._lastFrameTotal ?? 0) : 0;
      this._lastFrameTotal = span ? span.total : (this._lastFrameTotal ?? 0);
      this.do15.report({
        simMs: run.totalMs,
        frameMs: frameDelta,
        npcs: this.world.rrw.count('npc'),
        materialized: this.world.rrw.query({ kind: 'npc', materialization: 'full' }).length,
        memoryMB,
        tick: this.world.clock.tick,
      });
    }
    return run;
  }

  run(ticks, dt = this.world.clock.dt) {
    for (let i = 0; i < ticks; i++) this.tick(dt);
    return this.tickN;
  }

  /** extract the current Frame (representation -> visual description) */
  renderFrame() {
    this.frame = extractFrame(this, this.perf);
    return this.frame;
  }

  getStats() {
    return {
      tick: this.world.clock.tick,
      uesTicks: this.tickN,
      scheduler: this.scheduler.stats(),
      lastRun: this.scheduler.last,
      do15: this.do15?.stats() ?? null,
      counts: {
        npcs: this.world.rrw.count('npc'),
        settlements: this.world.rrw.count('settlement'),
        hazards: this.world.rrw.count('hazard'),
        events: this.world.rrw.stats.events,
      },
    };
  }
}
