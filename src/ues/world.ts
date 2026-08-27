/**
 * UES · World — espaço, terreno, semântica, streaming e ambiente.
 *
 * O mundo materializa a representação RRW:
 *  - chunks com heightfield determinístico (seed → mesma geração sempre);
 *  - camadas semânticas ABERTAS (terreno, heightfield, bioma, declive,
 *    ambiente, recursos, entidades — exemplos, não limite);
 *  - streaming por foco: load = materializar (D-3), unload = abstrair
 *    preservando estado (D-1) — regra central de materialização;
 *  - ambiente (ciclo dia/noite + clima markov) com CAUSALIDADE real:
 *    tempestade → raio → fogo (cadeia verificável no RRW).
 */

import { Logger, Rng, clamp, dist2d, newId } from '../core/index.ts';
import { MATERIAL_THRESHOLD, RRW, type RrwEntity } from '../rrw/index.ts';
import type { WorldAdapter } from '../contracts.ts';

/* ------------------------------------------------------------------ */
/* Ruído determinístico (função da coordenada — independente de ordem) */
/* ------------------------------------------------------------------ */

function hash2(x: number, y: number, seed: number): number {
  let h = (seed | 0) ^ Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

function smooth(t: number): number {
  return t * t * (3 - 2 * t);
}

/** Value noise determinístico em [0,1). */
export function valueNoise(x: number, y: number, seed: number): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = x - xi;
  const yf = y - yi;
  const v00 = hash2(xi, yi, seed);
  const v10 = hash2(xi + 1, yi, seed);
  const v01 = hash2(xi, yi + 1, seed);
  const v11 = hash2(xi + 1, yi + 1, seed);
  const a = v00 + (v10 - v00) * smooth(xf);
  const b = v01 + (v11 - v01) * smooth(xf);
  return a + (b - a) * smooth(yf);
}

/** FBM (fractal) — octavas para terreno natural. */
export function fbm(x: number, y: number, seed: number, octaves = 3): number {
  let sum = 0;
  let amp = 0.5;
  let freq = 1;
  for (let i = 0; i < octaves; i++) {
    sum += amp * valueNoise(x * freq, y * freq, seed + i * 101);
    freq *= 2;
    amp *= 0.5;
  }
  return sum; // ~[0,1]
}

/* ------------------------------------------------------------------ */
/* Tipos                                                               */
/* ------------------------------------------------------------------ */

export interface WorldConfig {
  seed: number;
  gridDim: number; // chunks por lado
  chunkSize: number; // unidades de mundo por chunk
  heightRes: number; // resolução do heightfield por chunk
  maxLoadedChunks: number;
  dayLength: number; // segundos de simulação por dia completo
  activeRadiusChunks: number;
  outerRadiusChunks: number;
}

export const DEFAULT_WORLD_CONFIG: WorldConfig = {
  seed: 42,
  gridDim: 12,
  chunkSize: 8,
  heightRes: 8,
  maxLoadedChunks: 49,
  dayLength: 600,
  activeRadiusChunks: 2,
  outerRadiusChunks: 3,
};

export interface Chunk {
  key: string;
  x: number;
  y: number;
  loaded: boolean;
  height: Float32Array | null;
  moisture: number;
  dominantBiome: string;
  entityIds: Set<string>;
  /** Estado semântico do chunk — PRESERVADO ao descarregar (D-1). */
  state: Record<string, unknown>;
  lastStreamIn: number;
  lastStreamOut: number;
}

export interface SemanticLayer {
  id: string;
  name: string;
  description: string;
  /** Describe o dado desta camada para um ponto do mundo. */
  sample?: (world: World, x: number, y: number) => unknown;
}

export interface BiomeZone {
  biome: string;
  x: number;
  y: number;
  radius: number;
}

export const BIOMES = ['water', 'coastal', 'desert', 'plains', 'forest', 'mountain', 'snow'] as const;
export type Biome = (typeof BIOMES)[number];

/**
 * Escala de comportamento por nível de materialização (valores fracionários
 * da Tese dos D têm EFEITO, não são decoração):
 *  - detail < 0.5      → 0    (abstrato: sem comportamento fino)
 *  - 0.5 ≤ detail < 0.75 → 0.5 (coarse: percepção reduzida, ações básicas)
 *  - detail ≥ 0.75     → 1    (completo)
 */
export function behaviorScale(detail: number): 0 | 0.5 | 1 {
  if (detail < 0.5) return 0;
  if (detail < 0.75) return 0.5;
  return 1;
}

/* ------------------------------------------------------------------ */
/* World                                                               */
/* ------------------------------------------------------------------ */

export class World implements WorldAdapter {
  cfg: WorldConfig;
  rrw: RRW;
  rng: Rng;
  log: Logger;
  chunks = new Map<string, Chunk>();
  focus = { x: 0, y: 0 };
  layers = new Map<string, SemanticLayer>();
  biomeZones: BiomeZone[] = [];
  env: RrwEntity;
  created = true;
  /**
   * Raio de materialização ATUAL (em chunks) — ajustável pelo D-O15 do engine
   * (pressão alta → menor zona materializada → mais abstração, custo menor;
   * folga → volta ao raio configurado). Estado nunca se perde (D-1).
   */
  focusRadius: { active: number; outer: number };
  private optimizationBridge: { report(): Record<string, unknown>; apply(): Record<string, unknown> } | null = null;
  private npcFactory: ((opts: { name?: string; x: number; y: number; work?: string }) => RrwEntity) | null = null;

  constructor(cfg: Partial<WorldConfig> = {}, rrw?: RRW, rng?: Rng, log?: Logger) {
    this.cfg = { ...DEFAULT_WORLD_CONFIG, ...cfg };
    this.rrw = rrw ?? new RRW({ log });
    this.rng = rng ?? new Rng(this.cfg.seed);
    this.log = (log ?? new Logger('ues')).child('world');
    this.focusRadius = { active: this.cfg.activeRadiusChunks, outer: this.cfg.outerRadiusChunks };
    this.defineDefaultComponents();
    this.defineDefaultLayers();
    // Ambiente global (fenômeno único)
    this.env = this.rrw.create({
      name: 'ambiente-mundo',
      categories: ['phenomenon/environment'],
      data: { timeOfDay: 0.3, weather: 'clear', temperature: 20, wind: 0.2, humidity: 0.5, stormSince: null },
    });
    this.rrw.defineProcess('env.day-night', {
      tick: (ent) => {
        ent.data.timeOfDay = (this.rrw.time / this.cfg.dayLength) % 1;
        const t = Number(ent.data.timeOfDay);
        const weatherMod = ent.data.weather === 'rain' ? -3 : ent.data.weather === 'storm' ? -5 : 0;
        ent.data.temperature = 18 + 9 * Math.sin(2 * Math.PI * (t - 0.25)) + weatherMod;
      },
      abstractTick: (ent) => {
        ent.data.timeOfDay = (this.rrw.time / this.cfg.dayLength) % 1;
      },
    });
    this.rrw.startProcess('env.day-night', [this.env.id]);
    this.rrw.defineProcess('env.weather', {
      tick: (ent, _s, ctx) => this.weatherStep(ent, ctx.dt),
      abstractTick: (ent, _s, ctx) => this.weatherStep(ent, ctx.dt), // clima evolui sempre (mundo vivo)
    });
    this.rrw.startProcess('env.weather', [this.env.id]);
    // Fogo: processo RRW que consome/propaga/apaga (definido 1x no mundo)
    this.rrw.defineProcess('fire', {
      init: () => 'burning',
      tick: (ent) => this.fireTick(ent),
      abstractTick: (ent) => this.fireTick(ent), // fogo evolui mesmo abstrato (mundo vivo)
    });
  }

  /* ---------------- definição de base (extensível) ---------------- */

  private defineDefaultComponents(): void {
    const r = this.rrw;
    if (!r.componentNames().includes('Position')) {
      r.defineComponent('Position', {
        init: (_e, a) => ({ x: (a?.x as number) ?? 0, y: (a?.y as number) ?? 0 }),
        compress: (v) => v, // posição é estado: preservada
        restore: (_e, s) => s,
        cost: 1,
      });
    }
    if (!r.componentNames().includes('Material')) {
      r.defineComponent('Material', {
        init: (_e, a) => ({
          base: (a?.base as string) ?? 'rock',
          color: (a?.color as string) ?? '#888888',
          flammable: (a?.flammable as boolean) ?? false,
          roughness: (a?.roughness as number) ?? 0.8,
          specular: (a?.specular as number) ?? 0.1,
        }),
        compress: (v) => v,
        restore: (_e, s) => s,
        cost: 1,
      });
    }
  }

  private defineDefaultLayers(): void {
    // Camadas semânticas de exemplo (a lista é ABERTA — addLayer expande).
    const defs: Array<[string, string, string]> = [
      ['terrain', 'Terreno', 'Topologia geral do terreno (bioma dominante + altitude).'],
      ['heightfield', 'Heightfield', 'Grade de alturas por chunk (dados brutos).'],
      ['biome', 'Bioma', 'Classificação semântica por ponto (clima/altitude).'],
      ['slope', 'Declive', 'Inclinação local derivada do heightfield.'],
      ['environment', 'Ambiente', 'Clima, temperatura, vento e umidade globais.'],
      ['resources', 'Recursos', 'Recursos extraíveis posicionados (árvores, minério, água).'],
      ['entities', 'Entidades', 'Entidades dinâmicas presentes (NPCs, estruturas, fenômenos).'],
    ];
    for (const [id, name, description] of defs) {
      if (!this.layers.has(id)) this.layers.set(id, { id, name, description });
    }
    this.defineLayerSamples();
  }

  addLayer(layer: SemanticLayer): void {
    if (this.layers.has(layer.id)) throw new Error(`World: camada já existe: ${layer.id}`);
    this.layers.set(layer.id, layer);
  }

  layer(id: string): SemanticLayer | undefined {
    return this.layers.get(id);
  }

  layerIds(): string[] {
    return [...this.layers.keys()];
  }

  private defineLayerSamples(): void {
    const L = this.layers;
    L.get('terrain')!.sample = (w, x, y) => ({ biome: w.biomeAt(x, y), height: Number(w.heightAt(x, y).toFixed(3)) });
    L.get('heightfield')!.sample = (w, x, y) => {
      const c = w.chunkAt(Math.floor(x / w.cfg.chunkSize), Math.floor(y / w.cfg.chunkSize));
      return c.loaded ? [...c.height!] : null;
    };
    L.get('biome')!.sample = (w, x, y) => w.biomeAt(x, y);
    L.get('slope')!.sample = (w, x, y) => w.slopeAt(x, y);
    L.get('environment')!.sample = () => ({ ...this.rrw.get(this.env.id)?.data });
    L.get('resources')!.sample = (w, x, y) => w.resourcesNear(x, y, 2).map((e) => e.name);
    L.get('entities')!.sample = (w, x, y) => w.entitiesNear(x, y, 3).map((e) => e.name ?? e.id);
  }

  /** Sample de todas as camadas em um ponto (introspecção/IA). */
  sampleLayers(x: number, y: number): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const l of this.layers.values()) out[l.id] = l.sample ? l.sample(this, x, y) : null;
    return out;
  }

  /* ---------------- espaço ---------------- */

  worldSize(): number {
    return this.cfg.gridDim * this.cfg.chunkSize;
  }

  key(cx: number, cy: number): string {
    return `${cx}:${cy}`;
  }

  inBounds(cx: number, cy: number): boolean {
    return cx >= 0 && cy >= 0 && cx < this.cfg.gridDim && cy < this.cfg.gridDim;
  }

  chunkAt(cx: number, cy: number): Chunk {
    const k = this.key(cx, cy);
    let c = this.chunks.get(k);
    if (!c) {
      c = { key: k, x: cx, y: cy, loaded: false, height: null, moisture: 0, dominantBiome: 'plains', entityIds: new Set(), state: {}, lastStreamIn: -1, lastStreamOut: -1 };
      this.chunks.set(k, c);
    }
    return c;
  }

  chunkCenter(c: Chunk): { x: number; y: number } {
    return { x: c.x * this.cfg.chunkSize + this.cfg.chunkSize / 2, y: c.y * this.cfg.chunkSize + this.cfg.chunkSize / 2 };
  }

  inBoundsPos(x: number, y: number): boolean {
    return x >= 0 && y >= 0 && x < this.worldSize() && y < this.worldSize();
  }

  /* ---------------- terreno (determinístico) ---------------- */

  /** Zone de bioma definida (ex.: pela Singularity AI) tem prioridade. */
  biomeAt(x: number, y: number): string {
    for (const z of this.biomeZones) {
      if (dist2d(x, y, z.x, z.y) <= z.radius) return z.biome;
    }
    const h = this.heightAt(x, y);
    const m = this.moistureAt(x, y);
    if (h < 0.18) return 'water';
    if (h < 0.24) return 'coastal';
    if (h > 0.86) return 'snow';
    if (h > 0.7) return 'mountain';
    if (m < 0.32) return 'desert';
    if (m > 0.6) return 'forest';
    return 'plains';
  }

  heightAt(x: number, y: number): number {
    const s = this.cfg.seed;
    const h = fbm(x * 0.06, y * 0.06, s, 3);
    return clamp(h, 0, 1);
  }

  moistureAt(x: number, y: number): number {
    return clamp(fbm(x * 0.045 + 100, y * 0.045 + 100, this.cfg.seed + 777, 2), 0, 1);
  }

  slopeAt(x: number, y: number): number {
    const e = 0.5;
    const dx = this.heightAt(x + e, y) - this.heightAt(x - e, y);
    const dy = this.heightAt(x, y + e) - this.heightAt(x, y - e);
    return clamp(Math.sqrt(dx * dx + dy * dy) / (2 * e) * 2, 0, 1);
  }

  /* ---------------- streaming (materialização espacial) ---------------- */

  /**
   * Carrega chunks dentro do raio ativo do foco e descarrega os distantes.
   * Load: gera heightfield + contexto + recursos (D-3 materializado).
   * Unload: abstrai entidades preservando estado (D-1); chunk.state fica.
   */
  stream(): { loaded: number; unloaded: number } {
    const cs = this.cfg.chunkSize;
    let loaded = 0;
    let unloaded = 0;
    const focusC = { x: this.focus.x / cs, y: this.focus.y / cs };
    const maxLoaded = this.cfg.maxLoadedChunks;
    // 1) carrega próximos
    for (let cy = 0; cy < this.cfg.gridDim; cy++) {
      for (let cx = 0; cx < this.cfg.gridDim; cx++) {
        const c = this.chunkAt(cx, cy);
        const d = dist2d(cx, cy, focusC.x, focusC.y);
        if (d <= this.focusRadius.active) {
          if (!c.loaded) {
            this.loadChunk(c);
            loaded += 1;
          }
        } else if (c.loaded && d > this.focusRadius.outer) {
          this.unloadChunk(c);
          unloaded += 1;
        }
      }
    }
    // 2) limite de cache LRU: evicta os mais distantes
    const loadedList = [...this.chunks.values()].filter((c) => c.loaded);
    if (loadedList.length > maxLoaded) {
      loadedList.sort((a, b) => dist2d(b.x, b.y, focusC.x, focusC.y) - dist2d(a.x, a.y, focusC.x, focusC.y));
      for (const c of loadedList.slice(maxLoaded)) {
        this.unloadChunk(c);
        unloaded += 1;
      }
    }
    // 3) materialização por relevância espacial das entidades do mundo
    this.rrw.materializeForFocus({
      x: this.focus.x,
      y: this.focus.y,
      innerRadius: this.focusRadius.active * cs,
      outerRadius: this.focusRadius.outer * cs,
      positionOf: (id) => this.positionOf(id),
    });
    return { loaded, unloaded };
  }

  private loadChunk(c: Chunk): void {
    const res = this.cfg.heightRes;
    const h = new Float32Array(res * res);
    for (let j = 0; j < res; j++) {
      for (let i = 0; i < res; i++) {
        const wx = c.x * this.cfg.chunkSize + (i + 0.5) * (this.cfg.chunkSize / res);
        const wy = c.y * this.cfg.chunkSize + (j + 0.5) * (this.cfg.chunkSize / res);
        h[j * res + i] = this.heightAt(wx, wy);
      }
    }
    c.height = h;
    c.loaded = true;
    c.lastStreamIn = this.rrw.time;
    const center = this.chunkCenter(c);
    c.moisture = this.moistureAt(center.x, center.y);
    c.dominantBiome = this.biomeAt(center.x, center.y);
    // contexto RRW do chunk (scope para entidades internas)
    const k = this.key(c.x, c.y);
    if (!c.state['contextId']) {
      const ctxEnt = this.rrw.create({
        name: `chunk ${k}`,
        categories: ['world/chunk'],
        data: { x: c.x, y: c.y, biome: c.dominantBiome },
        detail: 1,
      });
      c.state['contextId'] = ctxEnt.id;
    }
    // recursos base (apenas uma vez por chunk — o estado registra)
    if (!c.state['resourcesSpawned']) {
      this.spawnChunkResources(c);
      c.state['resourcesSpawned'] = true;
    }
  }

  private unloadChunk(c: Chunk): void {
    const ctxId = c.state['contextId'] as string | undefined;
    // abstrai entidades do chunk (estado preservado no RRW)
    if (ctxId) {
      for (const e of this.rrw.within(ctxId)) {
        if (e.id === this.env.id) continue;
        this.rrw.abstractize(e.id, 'chunk-unload');
      }
    }
    c.height = null;
    c.loaded = false;
    c.lastStreamOut = this.rrw.time;
    // c.state permanece (D-1): bioma, contexto, recursos gerados
  }

  private spawnChunkResources(c: Chunk): void {
    const res = this.cfg.heightRes;
    const ctxId = c.state['contextId'] as string;
    const count = 3 + this.rng.int(4);
    for (let i = 0; i < count; i++) {
      const ix = this.rng.int(res);
      const iy = this.rng.int(res);
      const wx = c.x * this.cfg.chunkSize + (ix + 0.5) * (this.cfg.chunkSize / res);
      const wy = c.y * this.cfg.chunkSize + (iy + 0.5) * (this.cfg.chunkSize / res);
      const h = this.heightAt(wx, wy);
      if (h < 0.2) continue; // embaixo d'água
      const biome = this.biomeAt(wx, wy);
      let kind = 'bush';
      let flammable = true;
      let color = '#5a8a3a';
      if (biome === 'forest') {
        kind = 'tree';
        color = '#2e6b2e';
      } else if (biome === 'desert') {
        kind = 'cactus';
        flammable = true;
        color = '#6f8f3f';
      } else if (biome === 'mountain' || biome === 'snow') {
        kind = 'ore';
        flammable = false;
        color = '#8a8a9a';
      } else if (biome === 'coastal') {
        kind = 'rock';
        flammable = false;
        color = '#7a7a72';
      }
      const ent = this.rrw.create({
        name: `${kind}`,
        categories: ['terrain/resource'],
        contextId: ctxId,
        components: { Position: { x: wx, y: wy }, Material: { base: kind, color, flammable, roughness: 0.9, specular: 0.05 } },
        data: { kind, biome, height: h, fuel: flammable ? 3 : 0 },
        detail: 1,
      });
      // relação: recurso pertence ao chunk
      this.rrw.relate(ent.id, ctxId, 'part-of', { weight: 1 });
    }
  }

  loadedChunkCount(): number {
    let n = 0;
    for (const c of this.chunks.values()) if (c.loaded) n += 1;
    return n;
  }

  /* ---------------- entidades ---------------- */

  /**
   * Posição de uma entidade — funciona até em estado ABSTRATO (le do
   * snapshot comprimido). Isso permite que o foco re-materialize entidades
   * que saíram do alcance (estado preservado é estado utilizável).
   */
  positionOf(id: string): { x: number; y: number } | null {
    const p = this.rrw.componentValue(id, 'Position') as { x: number; y: number } | undefined;
    if (p) return { x: p.x, y: p.y };
    const snap = this.rrw.get(id)?.compressed?.get('Position') as { x: number; y: number } | undefined;
    return snap ? { x: snap.x, y: snap.y } : null;
  }

  entitiesNear(x: number, y: number, radius: number): RrwEntity[] {
    const out: RrwEntity[] = [];
    for (const e of this.rrw.query({ categories: ['entity', 'organism', 'structure', 'phenomenon'] })) {
      const p = this.positionOf(e.id);
      if (p && dist2d(p.x, p.y, x, y) <= radius) out.push(e);
    }
    return out;
  }

  resourcesNear(x: number, y: number, radius: number): RrwEntity[] {
    const out: RrwEntity[] = [];
    for (const e of this.rrw.query({ categories: ['terrain/resource'] })) {
      const p = this.positionOf(e.id);
      if (p && dist2d(p.x, p.y, x, y) <= radius) out.push(e);
    }
    return out;
  }

  setFocus(x: number, y: number): void {
    this.focus = { x: clamp(x, 0, this.worldSize()), y: clamp(y, 0, this.worldSize()) };
  }

  /** Ajusta o raio de materialização (D-O15 usa para abstrair/materializar sob pressão). */
  setFocusRadius(active: number, outer: number): void {
    const a = Math.max(1, Math.min(active, Math.floor(this.cfg.gridDim / 2)));
    const o = Math.max(a, Math.min(outer, this.cfg.gridDim));
    this.focusRadius = { active: a, outer: o };
  }

  /** Raio configurado de origem (para o D-O15 restaurar em folga). */
  configuredRadius(): { active: number; outer: number } {
    return { active: this.cfg.activeRadiusChunks, outer: this.cfg.outerRadiusChunks };
  }

  /* ---------------- estruturas e NPCs ---------------- */

  spawnStructure(type: string, x: number, y: number, opts: Record<string, unknown> = {}): RrwEntity {
    const c = this.chunkAt(Math.floor(x / this.cfg.chunkSize), Math.floor(y / this.cfg.chunkSize));
    const ctxId = c.state['contextId'] as string | undefined;
    const colors: Record<string, string> = { market: '#b08a3e', house: '#8a6b4a', temple: '#c8c8d0', workshop: '#7a5a3a', wall: '#9a9a9a', village: '#8a6b4a' };
    const ent = this.rrw.create({
      name: `${type}`,
      categories: ['structure'],
      contextId: ctxId ?? undefined,
      components: { Position: { x, y }, Material: { base: type, color: colors[type] ?? '#888', flammable: type !== 'wall', roughness: 0.7, specular: 0.15 } },
      data: {
        type,
        ...this.structureData(type),
      },
      detail: 1,
    });
    if (ctxId) this.rrw.relate(ent.id, ctxId, 'located-in', { weight: 1 });
    this.rrw.emit('structure.built', [ent.id], { type }, { by: ent.id, description: `estrutura ${type} construída` });
    return ent;
  }

  private structureData(type: string): Record<string, unknown> {
    switch (type) {
      case 'market':
        return { stock: { food: { qty: 20, price: 1 }, wood: { qty: 10, price: 1 }, ore: { qty: 5, price: 2 } }, demand: { food: 0, wood: 0, ore: 0 } };
      default:
        return {};
    }
  }

  setNpcFactory(factory: (opts: { name?: string; x: number; y: number; work?: string }) => RrwEntity): void {
    this.npcFactory = factory;
  }

  spawnNpc(opts: { name?: string; x: number; y: number; work?: string }): RrwEntity | null {
    if (!this.npcFactory) {
      this.log.warn('spawnNpc chamado sem NPC factory registrado');
      return null;
    }
    return this.npcFactory(opts);
  }

  /* ---------------- clima (markov) + causalidade ---------------- */

  private weatherStep(ent: RrwEntity, dt: number): void {
    const w = ent.data.weather as string;
    const r = this.rng;
    let next = w;
    if (w === 'clear' && r.chance(0.01 * dt * 10)) next = 'rain';
    else if (w === 'rain' && r.chance(0.03 * dt * 10)) next = r.chance(0.3) ? 'storm' : 'clear';
    else if (w === 'storm' && r.chance(0.08 * dt * 10)) next = 'rain';
    if (next !== w) {
      const prev = w;
      ent.data.weather = next;
      ent.data.humidity = next === 'clear' ? 0.45 : next === 'rain' ? 0.75 : 0.9;
      ent.data.wind = next === 'storm' ? 0.9 : next === 'rain' ? 0.5 : 0.2;
      this.rrw.emit(`weather.${next}.begins`, [ent.id], { from: prev, to: next });
      if (next === 'storm') ent.data.stormSince = this.rrw.time;
    }
    // raio durante tempestade → pode causar fogo (cadeia causal)
    if (ent.data.weather === 'storm' && this.rng.chance(0.06 * dt * 10)) {
      this.lightning(ent);
    }
  }

  private lightning(ent: RrwEntity): void {
    // alvos inflamáveis com combustível (presença no mundo ativo)
    const flammables = this.rrw.query({ categories: ['terrain/resource', 'structure'] }).filter((e) => {
      const p = this.positionOf(e.id);
      if (!p) return false;
      return Number(e.data.fuel ?? 0) > 0 && dist2d(p.x, p.y, this.focus.x, this.focus.y) <= this.focusRadius.outer * this.cfg.chunkSize;
    });
    if (flammables.length === 0) return;
    const target = flammables[this.rng.int(flammables.length)];
    const at = this.positionOf(target.id) ?? { x: this.focus.x, y: this.focus.y };
    this.rrw.emit('weather.lightning', [this.env.id, target.id], { at });
    const fire = this.rrw.create({
      name: 'fogo',
      categories: ['phenomenon/fire'],
      contextId: target.contextId,
      components: { Position: { x: at.x, y: at.y } },
      data: { fuel: 6, source: target.id, intensity: 1 },
      detail: 1,
      spawnedBy: { by: this.env.id, event: 'weather.lightning', description: 'raio causou incêndio' },
    });
    this.rrw.relate(fire.id, target.id, 'causes', { weight: 1, causal: true, data: { kind: 'ignition' } });
    target.data.fuel = 0; // combustível consumido na ignição
    this.rrw.emit('fire.starts', [fire.id], { at }, { by: this.env.id, event: 'weather.lightning', description: 'fogo iniciado por raio' });
    this.rrw.startProcess('fire', [fire.id]);
    this.log.info(`raio atingiu ${target.name} → fogo (causalidade: storm→lightning→fire)`);
  }

  /** Fogo consome combustível, propaga e apaga (processo RRW). */
  private fireTick(ent: RrwEntity): void {
    const fuel = Number(ent.data.fuel ?? 0) - 0.15;
    ent.data.fuel = fuel;
    if (fuel <= 0) {
      this.rrw.emit('fire.extinguished', [ent.id], {});
      this.rrw.destroy(ent.id, 'combustível esgotado');
      return;
    }
    // propagação para inflamável próximo (probabilística, determinística por seed)
    // — escala com o nível de detalhe do fogo (comportamento fracionário)
    if (this.rng.chance(0.02 * behaviorScale(ent.detail))) {
      const p = this.positionOf(ent.id);
      if (p) {
        const near = this.resourcesNear(p.x, p.y, 2).filter((e) => Number(e.data.fuel ?? 0) > 0);
        if (near.length > 0) {
          const t = near[this.rng.int(near.length)];
          const tp = this.positionOf(t.id)!;
          const fire = this.rrw.create({
            name: 'fogo',
            categories: ['phenomenon/fire'],
            contextId: t.contextId,
            components: { Position: { x: tp.x, y: tp.y } },
            data: { fuel: 4, source: ent.id, intensity: 0.8 },
            detail: 1,
            spawnedBy: { by: ent.id, event: 'fire.spreads', description: 'propagação de fogo' },
          });
          t.data.fuel = 0;
          this.rrw.emit('fire.spreads', [fire.id], {}, { by: ent.id, event: 'fire.starts', description: 'fogo se propagou' });
          this.rrw.startProcess('fire', [fire.id]);
        }
      }
    }
  }

  /* ---------------- WorldAdapter (IA orquestra o mundo) ---------------- */

  setOptimizationBridge(bridge: { report(): Record<string, unknown>; apply(): Record<string, unknown> }): void {
    this.optimizationBridge = bridge;
  }

  createWorld(opts: { size: number; biomes: string[]; seed: number }): { ok: boolean; id: string } {
    // O mundo já existe (engine o criou); aqui registramos intenção de (re)configuração.
    this.log.info(`createWorld: size=${opts.size} biomes=[${opts.biomes.join(',')}] seed=${opts.seed}`);
    return { ok: true, id: 'world-0' };
  }

  worldExists(): boolean {
    return this.created;
  }

  createBiome(biome: string, x: number, y: number): { ok: boolean; id: string } {
    if (!BIOMES.includes(biome as Biome)) {
      this.log.warn(`bioma desconhecido "${biome}" — registrado como zona personalizada (RRW é aberto)`);
    }
    const zone: BiomeZone = { biome, x, y, radius: this.cfg.chunkSize * 2 };
    this.biomeZones.push(zone);
    this.rrw.create({
      name: `zona ${biome}`,
      categories: ['world/biome-zone'],
      components: { Position: { x, y } },
      data: { biome, radius: zone.radius },
      detail: 1,
    });
    this.rrw.emit('biome.zone.created', [this.env.id], { biome, x, y });
    return { ok: true, id: `biome-zone-${this.biomeZones.length - 1}` };
  }

  buildStructures(structures: string[], x: number, y: number): { ok: boolean; count: number } {
    let n = 0;
    structures.forEach((s, i) => {
      const ox = (i % 3) * 2;
      const oy = Math.floor(i / 3) * 2;
      this.spawnStructure(s, x + ox, y + oy);
      n += 1;
    });
    return { ok: true, count: n };
  }

  spawnNpcs(count: number, x: number, y: number, opts: Record<string, unknown> = {}): { ok: boolean; count: number; ids: string[] } {
    const ids: string[] = [];
    for (let i = 0; i < count; i++) {
      const a = this.rng.next() * Math.PI * 2;
      const r = this.rng.next() * (Number(opts.spread ?? 1) * 3);
      const nx = clamp(x + Math.cos(a) * r, 0, this.worldSize());
      const ny = clamp(y + Math.sin(a) * r, 0, this.worldSize());
      const ent = this.spawnNpc({ x: nx, y: ny });
      if (ent) ids.push(ent.id);
    }
    return { ok: true, count: ids.length, ids };
  }

  entityCount(): number {
    return this.rrw.stats().entities;
  }

  npcCount(): number {
    return this.rrw.query({ categories: ['organism/human'] }).length;
  }

  describe(): Record<string, unknown> {
    const s = this.rrw.stats();
    return {
      entities: s.entities,
      material: s.material,
      abstract: s.abstract,
      npcs: this.npcCount(),
      structures: this.rrw.query({ categories: ['structure'] }).length,
      fires: this.rrw.query({ categories: ['phenomenon/fire'] }).length,
      loadedChunks: this.loadedChunkCount(),
      weather: this.rrw.get(this.env.id)?.data.weather,
      timeOfDay: Number((this.rrw.get(this.env.id)?.data.timeOfDay as number)?.toFixed(3)),
      focus: { ...this.focus },
    };
  }

  checkInvariants(): { ok: boolean; issues: string[] } {
    const issues: string[] = [];
    const r = this.rrw;
    for (const e of r.query({ categories: ['organism/human'] })) {
      const p = this.positionOf(e.id);
      if (!p) issues.push(`NPC ${e.id} sem Position`);
      else if (!this.inBoundsPos(p.x, p.y)) issues.push(`NPC ${e.id} fora do mundo`);
    }
    for (const e of r.query({ categories: ['society/group'] })) {
      const stock = e.data.stock as Record<string, number> | undefined;
      if (stock) {
        for (const [k, v] of Object.entries(stock)) if (typeof v !== 'number' || v < 0) issues.push(`grupo ${e.id}: estoque ${k} inválido (${String(v)})`);
      }
    }
    for (const e of r.query({ categories: ['phenomenon/fire'] })) {
      if (Number(e.data.fuel ?? 0) < 0) issues.push(`fogo ${e.id} com combustível negativo`);
    }
    if (r.stats().entities === 0) issues.push('mundo sem entidades');
    return { ok: issues.length === 0, issues };
  }

  optimizationReport(): Record<string, unknown> {
    return this.optimizationBridge?.report() ?? { note: 'sem bridge de otimização' };
  }

  applyOptimization(): { ok: boolean; before: Record<string, unknown>; after: Record<string, unknown> } {
    const before = this.optimizationBridge ? this.optimizationBridge.report() : {};
    const applied = this.optimizationBridge?.apply() ?? { applied: false };
    const after = this.optimizationBridge ? this.optimizationBridge.report() : { ...applied };
    return { ok: Boolean(applied.applied ?? false), before, after };
  }
}
