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
    this.scheduler.add({ name: 'cutscene', priority: 5, fn: dt => this._stepCutscene(dt) });
    this.scheduler.add({ name: 'fluid3d', priority: 8, fn: dt => {
      const f3 = world.fluid3d;
      if (!f3) return;
      // D-O15: a grade segue o FOCO (recêntrise é honesto: fumaça é efêmera
      // e a injeção contínua dos fogos reconstrói o campo)
      const f = this.camera.pos;
      const half = f3.nx * f3.cell / 2;
      if (Math.abs(f[0] - (f3.origin[0] + half)) > half * 0.8 || Math.abs(f[2] - (f3.origin[2] + half)) > half * 0.8) {
        f3.recenter([f[0] - half, 0, f[2] - half]);
      }
      const env = world.environment;
      f3.step(dt, { wind: [ (env.windDir?.[0] ?? 1) * (env.wind ?? 0.2) * 6, 0.6, (env.windDir?.[1] ?? 0) * (env.wind ?? 0.2) * 6 ] });
    } });
    this.scheduler.add({ name: 'weather', priority: 10, fn: dt => world.updateWeather(dt) });
    this.scheduler.add({ name: 'ecology', priority: 20, fn: dt => world.updateEcology(dt) });
    this.scheduler.add({ name: 'economy', priority: 30, fn: dt => world.updateEconomy(dt) });
    this.scheduler.add({ name: 'trade', priority: 40, fn: dt => { if (world.clock.tick % 50 === 0) world.updateTrade(); } });
    this.scheduler.add({ name: 'nmn', priority: 50, fn: dt => world.updateNPCs(dt) });
    this.scheduler.add({ name: 'movement', priority: 60, fn: dt => world.updateMovement(dt) });
    this.scheduler.add({
      name: 'physics', priority: 65,
      fn: dt => {
        // D-O15: coarse pressure halves the physics rate (adaptation, not removal)
        const coarse = do15?.strategy?.perceptionResolution === 'coarse';
        if (coarse && world.clock.tick % 2 === 0) return;
        const sub = world.physics.substeps;
        for (let i = 0; i < sub; i++) world.physics.step(dt / sub, { tick: world.clock.tick });
      },
    });
    this.scheduler.add({ name: 'materializer', priority: 70, fn: () => world.updateMaterialization(this.camera.pos) });
    this.scheduler.add({
      name: 'streaming', priority: 75,
      fn: () => world.streaming.update(this.camera.pos, {
        radius: do15?.strategy?.terrainRadius ?? 220,
        budgetMs: (do15?.pressure ?? 0) > 0.7 ? 1 : 3,
      }),
    });
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

  /**
   * O DIRETOR assume a câmera: a cutscene rola por cima da live cam
   * (letterbox no frame) e, no fim, DEVOLVE o enquadramento do jogo.
   */
  playCutscene(cs, { restore = true } = {}) {
    if (!cs || !Array.isArray(cs.shots) || cs.shots.length === 0) throw new Error('playCutscene precisa de uma Cutscene com planos');
    this._camSaved = restore ? { ...this.camera } : null;
    cs.t = null; // começa no primeiro update (o mesmo contrato da classe)
    this.cutscene = cs;
    return { playing: cs.name ?? 'cena', duration: cs.duration };
  }

  _stepCutscene(dt) {
    if (!this.cutscene) return null;
    const r = this.cutscene.update(dt);
    if (r.ended) {
      if (this._camSaved) Object.assign(this.camera, this._camSaved);
      if (this.frame) this.frame.letterbox = false;
      this.cutscene = null;
      return { ended: true };
    }
    const pose = this.cutscene.pose(this.cutscene.t);
    this.camera.pos = pose.pos;
    this.camera.yaw = pose.yaw;
    this.camera.pitch = pose.pitch;
    if (this.frame) this.frame.letterbox = true;
    return { time: r.time ?? pose.time, shot: pose.shot };
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
