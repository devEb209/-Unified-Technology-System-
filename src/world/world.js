// UTS :: world — the living world: terrain + environment + entities + society.
//
// The World ORCHESTRATES subsystems but RRW remains the single source of
// truth: the spatial grid is derived, terrain caches are derived, and every
// meaningful change flows through verified events.

import { SpatialGrid } from '../spatial/grid.js';
import { Terrain } from './terrain.js';
import { RealLife } from './reallife.js';
import { Atmosphere } from './phenomena/atmosphere.js';
import { Climate } from './phenomena/climate.js';
import { FluidField } from './phenomena/fluids.js';
import { Fluid3D } from './phenomena/fluid3d.js';
import { Hydrology } from './phenomena/hydrology.js';
import { Erosion } from './erosion.js';
import { Combustion } from './phenomena/combustion.js';
import { Ecology } from './phenomena/ecology.js';
import { Acoustics } from './phenomena/acoustics.js';
import { MaterialLibrary } from '../render/materials.js';
import { LightSystem } from '../render/lighting.js';
import { StreamingSystem } from './streaming.js';
import { PhysicsWorld } from '../physics/physics.js';
import { clamp01, dist2 } from '../core/math.js';
import * as society from './society.js';

export class World {
  constructor({ rrw, rng, clock, tese = null, do15 = null, seed = 'uts-world', bus = null, genesisSeed = true }) {
    this.rrw = rrw;
    this.rng = rng;
    this.clock = clock;
    this.tese = tese;
    this.do15 = do15;
    this.bus = bus;
    this.seed = seed;

    this.terrain = new Terrain({ seed });
    this.grid = new SpatialGrid({ cellSize: 16 });
    this.grid.posLookup = (id) => rrw.get(id)?.components.get('spatial')?.pos ?? null;

    this.environment = {
      weather: 'clear', targetRain: 0, targetWind: 0.2,
      rain: 0, wetness: 0, dryness: 0.2, wind: 0.2, dust: 0,
      storm: false, flash: 0, fog: 0.12,
      sunDir: [0.5, 0.8, 0.3], sunColor: [1, 0.95, 0.8],
      ambient: 1, skyTop: [0.2, 0.4, 0.8], skyBottom: [0.7, 0.8, 0.9],
      lastWeatherEventId: null,
    };

    this.reallife = new RealLife({ world: this });
    this._lastRainEventId = null;
    // ---- REALITY PHENOMENA (ADR-019: the world models reality, not tricks)
    this.atmosphere = new Atmosphere();                       // air → sky IS scattering
    this.climate = new Climate({ world: this });              // regional weather (escalas)
    this.fluid = new FluidField({ world: this });             // água rasa que ESCORRE
    // O AR EM 3D: solver Euleriano real (advecção + empuxo + projeção) —
    // a fumaça dos incêndios é SOLUÇÃO, não fórmula. Grade segue o foco.
    this.fluid3d = new Fluid3D({ nx: 20, ny: 14, nz: 20, cell: 12, origin: [this.terrain.size / 2 - 120, 0, this.terrain.size / 2 - 120] });
    this.erosion = new Erosion({ world: this });               // a chuva ESCAVA (escada até geologia)
    this.observer = { adapt: 1, exposure: 1 };                // the eye ADAPTS to real light
    this.hydrology = new Hydrology({ world: this });          // water as substance
    this.combustion = new Combustion({ world: this, tese });  // fire as fuel process
    this.ecology = new Ecology({ world: this });              // vegetation as population
    this.acoustics = new Acoustics({ world: this });          // sound as pressure wave
    this.perf = {};                             // custo EMA por fenômeno (a plataforma se mede)
    this.materials = new MaterialLibrary();     // OUR material system
    this.lighting = new LightSystem();          // OUR lights (sun + phenomena)
    this.streaming = new StreamingSystem({ world: this, perf: null, tese }); // OUR residency
    this.physics = new PhysicsWorld({ world: this, tese }); // OUR physics
    this.terrainCache = new Map(); // legacy sampling cache (non-visual helpers)
    this.perceptionMetrics = { consulted: 0, perceived: 0, queries: 0 };
    this.settlementMaterialCap = 12;
    // restore paths pass genesisSeed:false: the forest comes from the snapshot
    // (never consume rng draws nor re-emit genesis events on load)
    if (genesisSeed) this._seedGenesisForest();
  }

  /** the world is born WITH vegetation (reality has no empty stages) */
  _seedGenesisForest(center = [512, 0, 512], { tries = 90 } = {}) {
    const seeded = [];
    for (let i = 0; i < tries; i++) {
      const a = this.rng.next() * Math.PI * 2, r = Math.sqrt(this.rng.next()) * 150;
      const x = center[0] + Math.cos(a) * r, z = center[2] + Math.sin(a) * r;
      const tree = this.ecology.seed(x, z, { age: this.rng.range(4, 40) });
      if (tree) seeded.push(tree.id);
    }
    return seeded;
  }

  /** the phenomena are RRW-owned state: they persist with the world */
  phenomenaSnapshot() {
    return {
      atmosphere: { state: { ...this.atmosphere.state } },
      acoustics: this.acoustics.snapshot(),
      erosion: this.erosion.snapshot(),
      hydrology: this.hydrology.snapshot(),
      combustion: this.combustion.snapshot(),
      ecology: this.ecology.snapshot(),
      // fire anchors are materialization bookkeeping: WITHOUT them a restored
      // world would re-create burning-cell entities under new ids (divergence)
      fireAnchors: this.reallife.fireAnchors ? [...this.reallife.fireAnchors] : [],
      fluid3d: this.fluid3d.snapshot(),
    };
  }

  phenomenaRestore(s) {
    if (!s) return;
    if (s.atmosphere) Object.assign(this.atmosphere.state, s.atmosphere.state ?? {});
    if (s.acoustics) this.acoustics.restore(s.acoustics);
    if (s.erosion) this.erosion.restore(s.erosion);
    if (s.hydrology) this.hydrology.restore(s.hydrology);
    if (s.combustion) this.combustion.restore(s.combustion);
    if (s.ecology) this.ecology.restore(s.ecology);
    if (s.fireAnchors) this.reallife.fireAnchors = new Map(s.fireAnchors);
    if (s.fluid3d) this.fluid3d.restore(s.fluid3d);
  }

  /** drop a dynamic rock into the reality (physics body + causal origin) */
  dropRock(pos, vel = [0, 0, 0], { causeEvent = null } = {}) {
    return this.physics.addBody({ pos, vel, causeEvent });
  }

  // ------------------------------------------------------------------ spawn

  spawnNPC({ pos, settlementId = null, fromAggregate = null, role = null } = {}) {
    const personality = {
      metabolism: this.rng.range(0.8, 1.3),
      bravery: this.rng.range(0.2, 1),
      sociability: this.rng.range(0.3, 1),
    };
    const ent = this.rrw.createEntity({
      kind: 'npc',
      materialization: 'full',
      importance: this.rng.range(0.05, 0.35),
      tags: ['npc'],
      pos: [pos[0], 0, pos[2]],
      components: {
        npc: { settlementId, fromAggregate, role: role ?? this.rng.pick(['farmer', 'gatherer', 'builder']) },
        mind: {
          needs: { hunger: this.rng.range(0.1, 0.4), energy: this.rng.range(0.6, 1), safety: 1, social: this.rng.range(0.3, 0.7) },
          memory: [],
          knowledge: [],
          fear: {},
          personality,
          perceptionRange: 24,
          lastDecision: null,
          lastPerceived: [],
          decisionCount: 0,
        },
      },
    });
    ent.bornTick = this.clock.tick;
    this.grid.update(ent.id, pos[0], pos[2]);
    return ent;
  }

  spawnResourceNodes(center, { radius = 120, bushes = 24, trees = 40 } = {}) {
    const out = [];
    const t = this.terrain;
    for (let i = 0; i < bushes; i++) {
      const a = this.rng.next() * Math.PI * 2, r = Math.sqrt(this.rng.next()) * radius;
      const x = center[0] + Math.cos(a) * r, z = center[2] + Math.sin(a) * r;
      if (t.height(x, z) < t.seaLevel + 0.5) continue;
      out.push(this.spawnResource('bush', [x, 0, z], { amount: 1, cap: 1, regrowDelay: 40 }));
    }
    for (let i = 0; i < trees; i++) {
      const a = this.rng.next() * Math.PI * 2, r = Math.sqrt(this.rng.next()) * radius * 1.4;
      const x = center[0] + Math.cos(a) * r, z = center[2] + Math.sin(a) * r;
      if (t.height(x, z) < t.seaLevel + 0.5) continue;
      out.push(this.spawnResource('tree', [x, 0, z], { amount: 1, cap: 1, regrowDelay: 120 }));
    }
    return out;
  }

  spawnResource(kind, pos, edible) {
    const ent = this.rrw.createEntity({
      kind, materialization: 'full', importance: kind === 'tree' ? 0.02 : 0.3,
      tags: ['resource'], pos,
      components: { resource: { ...edible, depletedAt: null } },
    });
    this.grid.update(ent.id, pos[0], pos[2]);
    return ent;
  }

  createSettlement(opts) {
    const ent = society.createSettlement(this, opts);
    return ent;
  }

  /** abstract settlement evolution, driven by its RRW process (survives abstraction) */
  evolveSettlementProcess(settlementId, dt) {
    return society.evolveSettlementAbstract(this, settlementId, dt);
  }

  setWeather(state) {
    return this.reallife.forceWeather(state);
  }

  strikeLightning(nearPos = null) {
    return this.reallife.strikeLightning(nearPos);
  }

  // -------------------------------------------------------------- perception
  // Indexed perception (D-4 + D-6): spatial query -> distance/fov filter ->
  // materialization/importance priority -> resolution cap. High-importance
  // phenomena (fires) are NEVER filtered out — resolution drops, reality not.

  perceive(pos, model = {}) {
    const range = model.range ?? 24;
    const cosHalfFov = Math.cos((((model.fovDeg ?? 360) / 2) * Math.PI) / 180);
    const facing = model.facing ?? null;
    const cap = model.cap ?? 12;
    this.perceptionMetrics.queries++;
    const tese = this.tese;

    const candidates = this.grid.queryCircle(pos[0], pos[2], range);
    const out = [];
    for (const id of candidates) {
      if (model.selfId && id === model.selfId) continue;
      const e = this.rrw.get(id);
      if (!e || !e.alive) continue;
      const sp = e.components.get('spatial');
      if (!sp) continue;
      const dx = sp.pos[0] - pos[0], dz = sp.pos[2] - pos[2];
      const d2 = dx * dx + dz * dz;
      if (d2 > range * range) continue;
      const important = e.importance >= 0.9 || e.kind === 'hazard';
      if (facing && !important) {
        const l = Math.sqrt(d2) || 1;
        if ((dx / l) * facing[0] + (dz / l) * facing[1] < cosHalfFov) continue;
      }
      out.push({ id, kind: e.kind, importance: e.importance, dist: Math.sqrt(d2), pos: sp.pos });
    }
    const consulted = candidates.length;
    out.sort((a, b) => (b.importance - a.importance) || (a.dist - b.dist) || (a.id < b.id ? -1 : 1));
    const kept = [];
    let budget = cap;
    for (const p of out) {
      if (p.importance >= 0.9) { kept.push(p); continue; } // events materialize always
      if (budget > 0) { kept.push(p); budget--; }
    }
    this.perceptionMetrics.consulted += consulted;
    this.perceptionMetrics.perceived += kept.length;
    tese?.touch('D-6', `perceive: consulted=${consulted} kept=${kept.length} res=${model.resolution ?? 'full'}`, this.clock.tick);
    return { entities: kept, consulted };
  }

  // ----------------------------------------------------------------- systems

  updateWeather(dt) {
    const t0 = performance.now();
    this.reallife.update(dt);
    const tRl = performance.now();
    // ---- THE REALITY CHAIN (ADR-019), in causal order:
    // air → sky, rain → soil+film, fuel+moisture+wind → fire, water+fire+sun → life
    const env = this.environment;
    const sunEl = this.clock.sunElevation;
    env.sunEl = sunEl; // the air knows where the sun is (fog build/burn)
    this.climate.step(dt, { wind: env.wind });
    const tCl = performance.now();
    // BIOLOGIA → ATMOSFERA: a floresta madura transpira (evapotranspiração)
    const focus = this.ues?.camera?.pos ?? [512, 0, 512];
    env.bioHumidity = this.ecology.canopyNear(focus[0], focus[2], 100);
    // OCEANO → ATMOSFERA: o mar evapora; e mede o SILT que chega à costa
    // (o adubo do rio no mar — a cadeia que alimenta o plâncton)
    let seaN = 0, siltSum = 0;
    for (let k = 0; k < 8; k++) {
      const a2 = (k / 8) * Math.PI * 2;
      const sx = focus[0] + Math.cos(a2) * 180, sz = focus[2] + Math.sin(a2) * 180;
      if (this.terrain.height(sx, sz) < this.terrain.seaLevel) { seaN++; siltSum += this.erosion.siltAt(sx, sz); }
    }
    env.seaHumidity = seaN / 8;
    env.seaSilt = seaN ? siltSum / seaN : 0;
    this.atmosphere.step(dt, env);
    const tAt = performance.now();
    // rain that LANDS flows (shallow water) around the focus
    if (env.rain > 0.02) {
      const focus = this.ues?.camera?.pos ?? [512, 0, 512];
      const cells = Math.round(env.rain * dt * 3);
      for (let k = 0; k < cells; k++) {
        const a = this.rng.next() * Math.PI * 2, r = this.rng.next() * 80;
        this.fluid.pour(focus[0] + Math.cos(a) * r, focus[2] + Math.sin(a) * r, 0.06 * dt);
      }
    }
    this.fluid.step(dt);
    const tFl = performance.now();
    // the water that LANDED carves the ground (the ladder feels it)
    this.erosion.step(dt);
    const tEr = performance.now();
    const air = this.atmosphere.sky({ sunEl, ambient: env.ambient });
    env.skyTop = air.skyTop; env.skyBottom = air.skyBottom;
    env.fog = air.fog; env.haze = air.haze; env.sunVisible = air.sunVisible;
    env.sunColor = air.sunColor;
    // ---- PERCEPTION (physical, not artistic): exposure is the eye's gain —
    // constricts FAST under a flash, dilates SLOWLY in the dark (Weber-like
    // target on ambient+flash luminance; asymmetric time constants)
    const L = (env.ambient ?? 1) + (env.flash ?? 0) * 2.5;
    const targetExp = Math.min(3.4, Math.max(0.5, 0.9 / Math.pow(Math.max(L, 0.05), 0.75)));
    const tauExp = targetExp < this.observer.adapt ? 0.35 : 11;
    this.observer.adapt += (targetExp - this.observer.adapt) * (1 - Math.exp(-dt / tauExp));
    this.observer.exposure = this.observer.adapt;
    this.hydrology.step(dt, {
      focus: this.ues?.camera?.pos ?? this.cameraFocusFallback?.() ?? [512, 0, 512],
      radius: 160, rain: env.rain, sunEl,
    });
    env.wetness = this.hydrology.soil.wetness; // the water table IS the wetness (single source)
    if (this.combustionStepEnabled !== false) {
      const spreadRate = (this.do15?.strategy?.perceptionResolution ?? 'full') === 'full' ? 1 : 0.5;
      env.windDir = [Math.cos(this.clock.timeOfDay * 6.28), Math.sin(this.clock.timeOfDay * 6.28)]; // ONE direction: sea, trees, fire, clouds
      this.combustion.step(dt, {
        rain: env.rain, wind: env.wind, windDir: env.windDir,
        hydrology: this.hydrology, spreadRate,
        rainAt: (x, z) => this.climate.rainAt(x, z, env.rain), // o fogo vê a chuva da SUA região
      });
    }
    if (this.ecologyStepEnabled !== false) {
      this.ecology.step(dt, {
        sunEl, soilWet: env.wetness,
        combustion: this.combustionStepEnabled === false ? null : this.combustion,
        // GEOLOGIA ALIMENTA A VIDA: sedimento erosionado aduba o crescimento
        siltAt: (x, z) => this.erosion.siltAt(x, z),
        seaSilt: env.seaSilt ?? 0, // nutrientes no mar (a mesma cadeia até o plâncton)
      });
    }
    // BIOLUMINESCÊNCIA: densidade de plâncton × presença de mar (o shader
    // soma o brilho ONDE a água é perturbada e NO ESCURO)
    env.bioGlow = this.ecology.plankton * (env.seaHumidity ?? 0);
    // A TEIA sobe pelo ar (aves) e corre o chão (veado/lobo)
    env.seabirds = this.ecology.seabirds ?? 0;
    let deerTotal = 0;
    for (const v of this.ecology.deerField.values()) deerTotal += v;
    env.deer = +deerTotal.toFixed(2);
    env.wolves = +(this.ecology.wolves ?? 0).toFixed(2);
    // PERF HONESTO: EMA do custo de cada fenômeno (a plataforma se mede)
    const ema = (k, v) => { this.perf[k] = (this.perf[k] ?? v) * 0.9 + v * 0.1; };
    ema('reallife', tRl - t0); ema('climate', tCl - tRl); ema('atmosphere', tAt - tCl);
    ema('fluid', tFl - tAt); ema('erosion', tEr - tFl);
    this.reallife.updateFires(dt); // materialize fire anchors FROM the field
    this.tese?.touch('D-5', `weather=${this.environment.weather} wet=${this.environment.wetness.toFixed(2)}`, this.clock.tick);
  }

  /** ecology: resource regrowth (D-9) — FOOD IS CLIMATE: bushes regrow from
   *  SOIL WATER (hydrology), and drought kills them. Hunger now has a sky. */
  updateEcology(dt) {
    if (!this.tese?.isEnabled('D-9')) return;
    const soilWet = this.hydrology?.soil.wetness ?? this.environment.wetness;
    for (const id of this.rrw.query({ kind: 'bush' }).concat(this.rrw.query({ kind: 'tree' }))) {
      const r = this.rrw.getComponent(id, 'resource');
      if (!r) continue;
      // ---- drought kills food (persistent, causal, eventful)
      if (r.amount > 0 && soilWet < 0.06) {
        r.amount = Math.max(0, r.amount - 0.004 * dt * 10);
        if (r.amount === 0) {
          this.rrw.emitEvent({
            type: 'ecology.food.withered', subject: id, cause: env_lastRainEvent(this) ?? null,
            data: { pos: this.rrw.getComponent(id, 'spatial')?.pos ?? null, soilWet: +soilWet.toFixed(2) },
            tick: this.clock.tick,
          });
          this.tese?.touch('D-9', `food ${id} withered (soil ${soilWet.toFixed(2)})`, this.clock.tick);
        }
        continue;
      }
      if (r.amount >= r.cap) continue;
      if (r.depletedAt == null) r.depletedAt = this.clock.tick;
      if (this.clock.tick - r.depletedAt > r.regrowDelay) {
        // wet soil = fast regrowth; dry soil = the bush struggles
        const rate = 0.02 * (0.15 + 0.85 * soilWet);
        r.amount = Math.min(r.cap, r.amount + rate * dt * 10);
        if (r.amount >= r.cap) { r.amount = r.cap; r.depletedAt = null; }
        this.tese?.touch('D-9', `resource ${id} regrew to ${r.amount.toFixed(2)}`, this.clock.tick);
      }
    }
  }

  updateEconomy(dt) {
    // abstract settlements evolve via their RRW process (survives abstraction, D-2/D-14)
    this.rrw.evolveProcesses(dt, { world: this, tick: this.clock.tick });
    for (const id of this.rrw.query({ kind: 'settlement' })) {
      const s = this.rrw.getComponent(id, 'settlement');
      if ((s.materialized ?? 0) > 0) society.updateSettlementEconomy(this, id, dt);
    }
    this.tese?.touch('D-8', `settlements=${this.rrw.count('settlement')}`, this.clock.tick);
  }

  updateTrade() {
    return society.tradePass(this);
  }

  updateNPCs(dt) {
    const every = this.do15?.strategy.updateEveryTicks ?? { full: 1, partial: 4, abstract: 0 };
    const tick = this.clock.tick;
    // IMPACTO DERRUBA: energia cinética de perto põe o NPC no chão — a
    // mente continua existindo, o CORPO obedece à física (levanta depois).
    for (const im of this.physics.recentImpacts ?? []) {
      // a física roda DEPOIS das mentes neste tick: o impacto do tick T
      // é visto na janela T..T+1 (nunca perdido, nunca dobrado)
      if ((im.tick !== tick && im.tick !== tick - 1) || im.energy < 12) continue;
      for (const id of this.rrw.query({ kind: 'npc' })) {
        const sp = this.rrw.getComponent(id, 'spatial');
        const d2 = (sp.pos[0] - im.pos[0]) ** 2 + (sp.pos[2] - im.pos[2]) ** 2;
        if (d2 < 2.5 * 2.5) {
          const npc = this.rrw.getComponent(id, 'npc');
          if (tick >= (npc.downedUntil ?? 0)) {
            npc.downedUntil = tick + 120;
            this.rrw.emitEvent({ type: 'npc.downed', subject: id, cause: null,
                                 data: { energy: +im.energy.toFixed(1) }, tick });
          }
        }
      }
    }
    for (const id of this.rrw.query({ kind: 'npc' })) {
      const e = this.rrw.get(id);
      const mat = e.materialization;
      const step = every[mat] ?? 0;
      if (!step) continue;                       // abstract minds are handled by aggregates
      if ((tick + (e.importance * 97 | 0)) % step !== 0) continue; // tiered, deterministic stagger
      this.updateMind(id, dt);
    }
  }

  updateMind(id, dt) {
    // implemented in nmn.js to keep minds decoupled from world internals
    this._mindUpdater?.(id, dt);
  }

  updateMovement(dt) {
    for (const id of this.rrw.query({ kind: 'npc', hasComponent: 'intent' })) {
      const sp = this.rrw.getComponent(id, 'spatial');
      const intent = this.rrw.getComponent(id, 'intent');
      const npcC = this.rrw.getComponent(id, 'npc');
      if (npcC?.downedUntil != null && this.clock.tick < npcC.downedUntil) continue; // caído não anda
      if (!intent.target) { this.rrw.removeComponent(id, 'intent'); continue; }
      const dx = intent.target[0] - sp.pos[0], dz = intent.target[2] - sp.pos[2];
      const d = Math.hypot(dx, dz);
      if (d < 1.2) {
        this.rrw.removeComponent(id, 'intent');
        continue;
      }
      const speed = (intent.speed ?? 3) * dt;
      const stepLen = Math.min(speed, d);
      sp.pos[0] += (dx / d) * stepLen;
      sp.pos[2] += (dz / d) * stepLen;
      sp.__v = this.clock.tick; // per-entity delta stamp (streaming)
      sp.yaw = Math.atan2(dx, dz);
      this.grid.update(id, sp.pos[0], sp.pos[2]);   // index stays synchronized (D-4)
      this.tese?.touch('D-4', `moved ${id} -> (${sp.pos[0].toFixed(1)},${sp.pos[2].toFixed(1)})`, this.clock.tick);
    }
  }

  /** materialization pass (D-14 + D-10 + D-O15) driven by camera/focus */
  updateMaterialization(cameraPos) {
    const strategy = this.do15?.strategy;
    const radius = strategy?.materializationRadius ?? 90;
    let materializedCount = this.rrw.query({ kind: 'npc', materialization: 'full' }).length
      + this.rrw.query({ kind: 'npc', materialization: 'partial' }).length;
    const maxMat = strategy?.maxMaterialized ?? 400;

    for (const id of this.rrw.query({ kind: 'npc' })) {
      const e = this.rrw.get(id);
      const sp = e.components.get('spatial');
      if (!sp) continue;
      const d = Math.sqrt(dist2(sp.pos[0], sp.pos[2], cameraPos[0], cameraPos[2]));
      const want = this.do15 ? this.do15.decideMaterialization(d, e.importance) : (d < radius ? 'full' : 'abstract');
      if (want !== e.materialization) {
        this.rrw.setMaterialization(id, want, { reason: `dist ${d.toFixed(0)}m imp ${e.importance.toFixed(2)}`, tick: this.clock.tick });
        materializedCount += want === 'abstract' ? -1 : 1;
      }
      if (want === 'abstract' && e.components.has('intent')) this.rrw.removeComponent(id, 'intent');
    }

    // enforce the materialization budget — defer beyond, never lose entities
    if (materializedCount > maxMat) {
      const over = materializedCount - maxMat;
      const far = this.rrw.query({ kind: 'npc' })
        .map(id => {
          const sp = this.rrw.getComponent(id, 'spatial');
          return {
            id, mat: this.rrw.get(id).materialization,
            d: sp ? dist2(sp.pos[0], sp.pos[2], cameraPos[0], cameraPos[2]) : Infinity,
          };
        })
        .filter(x => x.mat === 'partial' || x.mat === 'full')
        .sort((a, b) => (b.d - a.d) || (a.id < b.id ? -1 : 1))
        .slice(0, over);
      for (const f of far) {
        this.rrw.setMaterialization(f.id, 'abstract', { reason: 'materialization budget', tick: this.clock.tick });
        materializedCount--;
      }
    }

    // settlements: aggregate <-> individuals with state preservation
    for (const id of this.rrw.query({ kind: 'settlement' })) {
      const sp = this.rrw.getComponent(id, 'spatial');
      const s = this.rrw.getComponent(id, 'settlement');
      const d = Math.sqrt(dist2(sp.pos[0], sp.pos[2], cameraPos[0], cameraPos[2]));
      if (d < radius * 1.2 && s.pop > 0 && (s.materialized ?? 0) < this.settlementMaterialCap) {
        society.materializeSettlement(this, id, Math.min(this.settlementMaterialCap - (s.materialized ?? 0), s.pop));
      } else if (d > radius * 1.6 && (s.materialized ?? 0) > 0) {
        society.abstractSettlement(this, id);
      }
    }
  }

  // ------------------------------------------------------- terrain for frames

  getTerrainPatch(cx, cz, res) {
    const key = `${cx}:${cz}:${res}`;
    let patch = this.terrainCache.get(key);
    if (!patch) {
      patch = { ...this.terrain.sampleChunk(cx, cz, res), version: 1 };
      this.terrainCache.set(key, patch);
      if (this.terrainCache.size > 96) {
        const first = this.terrainCache.keys().next().value;
        this.terrainCache.delete(first);
      }
    }
    return patch;
  }
}

/** causal link for food withering: the CURRENT weather regime is the cause */
function env_lastRainEvent(world) {
  const w = world.environment.weather;
  return (w === 'rain' || w === 'storm') ? null : (world.environment.lastWeatherEventId ?? null);
}
