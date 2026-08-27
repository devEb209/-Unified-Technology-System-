/**
 * UES · Graphics — camada gráfica PRÓPRIA da UES (Prompt 2/21).
 *
 * A renderização INTERPRETA a realidade representada (RRW), não é um
 * sistema isolado: materiais, iluminação, sombras, atmosfera e LOD
 * derivam do estado do mundo (Real Life = fenômenos → parâmetros visuais).
 *
 * Backends (Vulkan/DirectX/OpenGL/WebGL) vivem ABAIXO desta abstração
 * como implementações opcionais de `RendererBackend`. Nesta implementação
 * headless há dois backends reais: Null (métricas) e Text (ASCII para CLI).
 * A arquitetura não depende de nenhum backend concreto.
 */

import { clamp, lerp } from '../core/index.ts';
import type { RRW } from '../rrw/index.ts';
import type { World } from './world.ts';

/* ------------------------------------------------------------------ */
/* Real Life — fenômenos reais → parâmetros visuais                    */
/* ------------------------------------------------------------------ */

export interface RealLifeState {
  wetness: number; // superfícies molhadas
  dust: number; // poeira/suspensão no ar
  stormGlow: number; // brilho elétrico de tempestade
  haze: number; // neblina integrada
}

/**
 * Real Life: modela efeitos de fenômenos coerentes com o mundo real
 * (chuva molha → especularidade; vento + seca → poeira; tempestade → glow).
 * Função real com estado temporal (testada).
 *
 * ABERTO (regra de realidade não fechada): `addRule` permite novos fenômenos
 * em runtime (ex.: shimmer térmico, auroras, névoa de maré) sem alterar a
 * classe. Os padrões abaixo são exemplos, não o limite do sistema.
 */
export interface RealLifeEnv {
  weather: string;
  wind: number;
  humidity: number;
  timeOfDay: number;
}

type RealLifeRule = (state: Record<string, number>, env: RealLifeEnv, dt: number) => void;

export class RealLife {
  state: RealLifeState = { wetness: 0, dust: 0, stormGlow: 0, haze: 0 };
  private rules = new Map<string, RealLifeRule>();

  /** Registra um fenômeno custom (estado extensível: novas chaves em `state`). */
  addRule(name: string, rule: RealLifeRule): void {
    if (this.rules.has(name)) throw new Error(`RealLife: regra já existe: ${name}`);
    this.rules.set(name, rule);
  }

  ruleNames(): string[] {
    return [...this.rules.keys()].sort();
  }

  /** dt em segundos de simulação. */
  update(env: RealLifeEnv, dt: number): void {
    const s = this.state as Record<string, number>;
    const raining = env.weather === 'rain' || env.weather === 'storm';
    s.wetness = clamp(s.wetness + (raining ? 0.4 * dt : -0.05 * dt), 0, 1);
    const dryWind = env.wind > 0.4 && env.humidity < 0.45;
    s.dust = clamp(s.dust + (dryWind ? 0.15 * dt : -0.08 * dt), 0, 1);
    s.stormGlow = env.weather === 'storm' ? clamp(s.stormGlow + 0.8 * dt, 0, 1) : clamp(s.stormGlow - 0.5 * dt, 0, 1);
    // haze combinado: poeira + umidade alta + chuva
    const target = clamp(0.25 * s.dust + 0.3 * env.humidity * (raining ? 1 : 0) + 0.2 * (raining ? 1 : 0), 0, 1);
    s.haze = clamp(s.haze + (target - s.haze) * clamp(2 * dt, 0, 1), 0, 1);
    // fenômenos custom (extensibilidade da Real Life)
    for (const rule of this.rules.values()) rule(s, env, dt);
  }

  /** Materiais para o frame: padrões + qualquer chave de regra custom. */
  materials(): Record<string, number> {
    return { ...this.state };
  }
}

/* ------------------------------------------------------------------ */
/* Frame (o que a camada gráfica produz a partir da realidade)         */
/* ------------------------------------------------------------------ */

export interface FrameEntity {
  id: string;
  kind: string;
  x: number;
  y: number;
  /** LOD: 3 próximo (total) · 2 médio · 1 distante (coarse) · 0 agregado */
  lod: 0 | 1 | 2 | 3;
  color?: string;
  label?: string;
}

export interface Frame {
  frame: number;
  time: number;
  lighting: {
    sunElevation: number; // -1..1
    intensity: number; // 0..1
    colorTempK: number;
    night: boolean;
  };
  atmosphere: { fog: number; haze: number; stormGlow: number };
  /** Parâmetros de materiais: padrões (wetness/dust/stormGlow/haze) + regras custom. */
  materials: RealLifeState & Record<string, number>;
  shadows: { enabled: boolean; occluders: number };
  entities: FrameEntity[];
  drawCalls: number;
  triangles: number;
  backend: string;
}

/* ------------------------------------------------------------------ */
/* Backends (abaixo da abstração — opcionais, intercambiáveis)         */
/* ------------------------------------------------------------------ */

export interface BackendStats {
  drawCalls: number;
  triangles: number;
}

export interface RendererBackend {
  readonly id: string;
  readonly name: string;
  /** `world` é opcional para backends puramente métricos. */
  render(frame: Frame, world?: World): BackendStats & { output?: string };
}

/** Backend sem visual: só contabiliza (métricas headless). */
export class NullBackend implements RendererBackend {
  readonly id = 'null';
  readonly name = 'Null (métricas)';
  render(frame: Frame): BackendStats {
    return { drawCalls: frame.entities.length + 1, triangles: frame.entities.length * 4 };
  }
}

/** Backend ASCII: renderiza o mundo para texto (demos CLI). */
export class TextBackend implements RendererBackend {
  readonly id = 'text';
  readonly name = 'Text (ASCII)';
  render(frame: Frame, world?: World): BackendStats & { output?: string } {
    if (!world) return { drawCalls: 0, triangles: 0 };
    const W = 56;
    const H = 22;
    const size = world.worldSize();
    const grid: string[] = new Array(W * H).fill('.');
    // terreno (amostrado)
    for (let j = 0; j < H; j++) {
      for (let i = 0; i < W; i++) {
        const wx = ((i + 0.5) / W) * size;
        const wy = ((j + 0.5) / H) * size;
        const biome = world.biomeAt(wx, wy);
        grid[j * W + i] = biomeChar(biome);
      }
    }
    // entidades (LOD ≥ 1); agregados (LOD 0) em caixa
    for (const e of frame.entities) {
      const i = Math.floor((e.x / size) * W);
      const j = Math.floor((e.y / size) * H);
      if (i < 0 || j < 0 || i >= W || j >= H) continue;
      const ch =
        e.kind === 'npc' ? (e.lod === 0 ? 'v' : 'N') :
        e.kind === 'fire' ? 'F' :
        e.kind === 'market' ? 'M' :
        e.kind.startsWith('structure') ? 'S' :
        e.lod >= 2 ? '#' : '.';
      grid[j * W + i] = ch;
    }
    // neblina: atenua caracteres distantes do foco
    const lines: string[] = [];
    for (let j = 0; j < H; j++) {
      let line = '';
      for (let i = 0; i < W; i++) {
        const ch = grid[j * W + i];
        const wx = ((i + 0.5) / W) * size;
        const wy = ((j + 0.5) / H) * size;
        const d = Math.hypot(wx - world.focus.x, wy - world.focus.y);
        const fade = clamp(d / (size * 0.5), 0, 1) * clamp(frame.atmosphere.haze + 0.2, 0, 1);
        line += fade > 0.8 ? '·' : fade > 0.5 ? ',' : ch;
      }
      lines.push(line);
    }
    const sun = frame.lighting.night ? '☾' : '☀';
    const head = `frame=${frame.frame} t=${frame.time.toFixed(1)}s ${sun} lux=${frame.lighting.intensity.toFixed(2)} fog=${frame.atmosphere.fog.toFixed(2)} wet=${frame.materials.wetness.toFixed(2)} dust=${frame.materials.dust.toFixed(2)} draws=${frame.drawCalls}`;
    return { drawCalls: frame.entities.length + 1, triangles: frame.entities.length * 4, output: `${head}\n${lines.join('\n')}` };
  }
}

function biomeChar(b: string): string {
  switch (b) {
    case 'water':
      return '~';
    case 'coastal':
      return ':';
    case 'desert':
      return '.';
    case 'forest':
      return '"';
    case 'mountain':
      return '^';
    case 'snow':
      return 'o';
    default:
      return ' ';
  }
}

/* ------------------------------------------------------------------ */
/* GraphicsSystem — interpreta o mundo em Frame                        */
/* ------------------------------------------------------------------ */

export class GraphicsSystem {
  private world: World;
  private rrw: RRW;
  private realLife: RealLife;
  private backend: RendererBackend;
  frameCounter = 0;

  constructor(opts: { world: World; realLife?: RealLife; backend?: RendererBackend }) {
    this.world = opts.world;
    this.rrw = opts.world.rrw;
    this.realLife = opts.realLife ?? new RealLife();
    this.backend = opts.backend ?? new NullBackend();
  }

  get backendId(): string {
    return this.backend.id;
  }

  /**
   * Constrói o frame interpretando o estado RRW/mundo.
   * Representação e LOD seguem D-O15 (entidades abstratas viram marcador).
   */
  run(ctx: { dt: number; time: number }): Frame | null {
    const envEnt = this.world.rrw.get(this.world.env.id)!;
    const env = {
      weather: envEnt.data.weather as string,
      wind: Number(envEnt.data.wind ?? 0.2),
      humidity: Number(envEnt.data.humidity ?? 0.5),
      timeOfDay: Number(envEnt.data.timeOfDay ?? 0),
    };
    this.realLife.update(env, ctx.dt);
    this.frameCounter += 1;

    // iluminação derivada do ciclo dia/noite (não hardcoded)
    const sunElevation = Math.sin(2 * Math.PI * (env.timeOfDay - 0.5));
    const intensity = clamp(Math.max(0, sunElevation) * (env.weather === 'clear' ? 1 : 0.55), 0, 1);
    const colorTempK = Math.round(lerp(2800, 6500, intensity) - (env.weather === 'storm' ? 1200 : 0));
    const night = sunElevation < 0.05;

    // entidades visíveis + LOD por distância ao foco
    const entities: FrameEntity[] = [];
    const focus = this.world.focus;
    for (const e of this.rrw.query({ categories: ['entity', 'organism', 'structure', 'terrain/resource', 'phenomenon/fire', 'society/group'] })) {
      const p = this.world.positionOf(e.id);
      if (!p) continue;
      const d = Math.hypot(p.x - focus.x, p.y - focus.y);
      let lod: 0 | 1 | 2 | 3;
      if (e.categories.includes('society/group')) lod = 0; // agregado
      else if (e.detail < 0.5) lod = 0; // abstrato → marcador
      else if (d <= 6) lod = 3;
      else if (d <= 16) lod = 2;
      else lod = 1;
      const mat = this.rrw.componentValue(e.id, 'Material') as { color?: string } | undefined;
      entities.push({
        id: e.id,
        kind: e.categories.includes('organism/human') ? 'npc' : e.data.type ? String(e.data.type) : e.data.kind ? String(e.data.kind) : e.categories[0] ?? 'entity',
        x: p.x,
        y: p.y,
        lod,
        color: mat?.color,
        label: e.name ?? undefined,
      });
    }

    // sombras: oclusores = estruturas e árvores materializadas próximas
    const occluders = entities.filter((e) => (e.kind === 'house' || e.kind === 'tree' || e.kind === 'market' || e.kind.startsWith('structure')) && e.lod >= 2).length;

    const frame: Frame = {
      frame: this.frameCounter,
      time: ctx.time,
      lighting: { sunElevation: Number(sunElevation.toFixed(3)), intensity: Number(intensity.toFixed(3)), colorTempK: Math.max(2000, colorTempK), night },
      atmosphere: { fog: Number(this.realLife.state.haze.toFixed(3)), haze: Number(this.realLife.state.haze.toFixed(3)), stormGlow: Number(this.realLife.state.stormGlow.toFixed(3)) },
      materials: this.realLife.materials(),
      shadows: { enabled: intensity > 0.3 && occluders > 0, occluders },
      entities,
      drawCalls: 0,
      triangles: 0,
      backend: this.backend.id,
    };
    const stats = this.backend.render(frame, this.world);
    frame.drawCalls = stats.drawCalls;
    frame.triangles = stats.triangles;
    return frame;
  }
}
