/**
 * UES · NMN — Natural Mindset of NPCs.
 *
 * NPCs como princípios de realidade (Prompt 2/16): identidade, objetivos,
 * necessidades, memória, relações, conhecimento, contexto, percepção,
 * experiências e consequências — NÃO scripts rígidos.
 *
 * Arquitetura:
 *  - necessidades (fome, energia, segurança, social) evoluem no tempo;
 *  - metas por AVALIAÇÃO DE UTILIDADE (need urgency + contexto + memória
 *    + relações + custo + risco) — decisões adaptativas, reproduzíveis;
 *  - memória: episódios (ring) + fatos com confiança + relações (trust/debt);
 *  - percepção limitada: vê entidades materializadas no raio, ouve eventos
 *    com posição no raio (D-4: só com materialização);
 *  - estado vive no RRW (componente Mind + data) → sobrevive a
 *    abstração/materialização (estado nunca se perde).
 */

import { Logger, Rng, clamp, dist2d } from '../core/index.ts';
import { MATERIAL_THRESHOLD, RRW, type RrwEntity } from '../rrw/index.ts';
import { behaviorScale, type World } from './world.ts';

export interface Needs {
  hunger: number; // 0 ok → 1 crítico
  energy: number; // 1 cheio → 0 esgotado (aqui invertido: 0 = crítico)
  safety: number; // 0 crítico → 1 seguro (mantido: 1 = bem)
  social: number; // 0 ok → 1 isolado
}

export interface RelationState {
  trust: number; // 0..1
  owes: number; // quem deve (recurso)
  owed: number; // quem recebe
  kin: boolean;
}

export interface Episode {
  at: number;
  type: string;
  summary: string;
}

export interface MindState {
  needs: Needs;
  money: number;
  inventory: Record<string, number>;
  knowledge: Record<string, { value: unknown; at: number; confidence: number }>;
  relations: Record<string, RelationState>;
  episodes: Episode[];
  work: { type: string; locationId: string | null } | null;
  home: { x: number; y: number } | null;
  goal: { type: string; targetId: string | null; target: { x: number; y: number }; until: number } | null;
  state: 'idle' | 'moving' | 'working' | 'trading' | 'resting' | 'fleeing' | 'socializing';
  retargetAt: number;
  speed: number;
  traits: Record<string, number>;
}

export interface Perception {
  visible: RrwEntity[];
  heard: RrwEntity[]; // entidades envolvidas em eventos recentes audíveis
  threats: RrwEntity[];
}

const PERCEPTION_RADIUS = 6;
const HEAR_RADIUS = 10;
const EPISODE_CAP = 32;
const NPC_NAMES = ['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Fábio', 'Greta', 'Heitor', 'Inês', 'João', 'Kátia', 'Lucas', 'Marta', 'Nuno', 'Olívia', 'Pedro', 'Quésia', 'Rafael', 'Sofia', 'Tiago', 'Úrsula', 'Vitor', 'Wanda', 'Xavier', 'Yara', 'Zeca'];

export interface NpcCtx {
  dt: number;
  time: number;
  rng: Rng;
  world: World;
}

export class Npc {
  readonly id: string;
  readonly ent: RrwEntity;
  rrw: RRW;
  log: Logger;

  /** Registra componentes NMN no RRW (idempotente — chamado 1x pela UES). */
  static ensureComponents(rrw: RRW): void {
    if (!rrw.componentNames().includes('Mind')) {
      rrw.defineComponent('Mind', {
        // A mente É estado: abstração preserva o objeto inteiro (regra D-1).
        compress: (v) => v,
        restore: (_e, s) => s,
        cost: 2,
      });
    }
  }

  private constructor(ent: RrwEntity, rrw: RRW, log: Logger) {
    this.ent = ent;
    this.id = ent.id;
    this.rrw = rrw;
    this.log = log.child('npc');
  }

  /**
   * Adota uma entidade RRW já existente como NPC (persistência: o estado
   * vem do snapshot; o wrapper Npc é reconstituído em volta dela).
   */
  static adopt(world: World, ent: RrwEntity): Npc {
    Npc.ensureComponents(world.rrw);
    const npc = new Npc(ent, world.rrw, world.log);
    return npc;
  }

  static create(world: World, opts: { name?: string; x: number; y: number; work?: string; traits?: Record<string, number> }): Npc {
    const rrw = world.rrw;
    const log = world.log;
    const rng = world.rng;
    const c = world.chunkAt(Math.floor(opts.x / world.cfg.chunkSize), Math.floor(opts.y / world.cfg.chunkSize));
    const ctxId = c.state['contextId'] as string | undefined;
    const name = opts.name ?? NPC_NAMES[rng.int(NPC_NAMES.length)];
    const mind: MindState = {
      needs: { hunger: rng.range(0.1, 0.4), energy: rng.range(0.6, 1), safety: 1, social: rng.range(0, 0.5) },
      money: Math.round(rng.range(5, 25)),
      inventory: { food: rng.int(3) },
      knowledge: {},
      relations: {},
      episodes: [],
      work: opts.work ? { type: opts.work, locationId: null } : null,
      home: { x: opts.x, y: opts.y },
      goal: null,
      state: 'idle',
      retargetAt: 0,
      speed: rng.range(1.2, 2.2),
      traits: { bravery: rng.range(0.2, 0.8), sociability: rng.range(0.2, 0.8), workEthic: rng.range(0.3, 0.9), ...(opts.traits ?? {}) },
    };
    const ent = rrw.create({
      name,
      categories: ['organism/human', 'entity'],
      contextId: ctxId ?? undefined,
      components: {
        Position: { x: opts.x, y: opts.y },
        Mind: mind,
      },
      data: { kind: 'npc' },
      detail: 1,
      spawnedBy: ctxId ? { by: ctxId, description: 'habitante do chunk' } : null,
    });
    // conhecimento inicial: o mercado mais próximo, se existir
    const market = rrw.query({ categories: ['structure'], data: { type: 'market' } })[0];
    if (market) {
      const mp = world.positionOf(market.id)!;
      mind.knowledge['market'] = { value: { id: market.id, x: mp.x, y: mp.y }, at: rrw.time, confidence: 0.9 };
    }
    // causa raiz real para produção futura (work.produced ← work.assigned)
    if (opts.work) {
      rrw.emit('work.assigned', [ent.id], { type: opts.work });
    }
    const npc = new Npc(ent, rrw, log);
    return npc;
  }

  /* ---------------- acesso de estado ---------------- */

  get mind(): MindState {
    return this.ent.components.get('Mind') as MindState;
  }

  pos(): { x: number; y: number } {
    const p = this.rrw.componentValue(this.id, 'Position') as { x: number; y: number };
    return p;
  }

  setPos(x: number, y: number): void {
    const p = this.rrw.componentValue(this.id, 'Position') as { x: number; y: number };
    p.x = x;
    p.y = y;
  }

  relateTo(otherId: string): RelationState {
    const m = this.mind;
    if (!m.relations[otherId]) m.relations[otherId] = { trust: 0.3, owes: 0, owed: 0, kin: false };
    return m.relations[otherId];
  }

  remember(type: string, summary: string, at: number): void {
    const m = this.mind;
    m.episodes.push({ at, type, summary });
    if (m.episodes.length > EPISODE_CAP) m.episodes.splice(0, m.episodes.length - EPISODE_CAP);
  }

  know(key: string): { value: unknown; confidence: number } | null {
    const k = this.mind.knowledge[key];
    return k ? { value: k.value, confidence: k.confidence } : null;
  }

  setKnowledge(key: string, value: unknown, confidence: number, at: number): void {
    this.mind.knowledge[key] = { value, at, confidence };
  }

  /* ---------------- percepção (D-4) ---------------- */

  perceive(ctx: NpcCtx): Perception {
    const p = this.pos();
    const visible: RrwEntity[] = [];
    const threats: RrwEntity[] = [];
    // percepção limitada E proporcional ao nível de materialização (D-2/D-4):
    // abstrato não percebe; coarse percebe metade do raio; completo, o raio total.
    const scale = behaviorScale(this.ent.detail);
    if (scale === 0) return { visible: [], heard: [], threats: [] };
    const radius = PERCEPTION_RADIUS * scale;
    for (const e of ctx.world.entitiesNear(p.x, p.y, radius)) {
      if (e.id === this.id) continue;
      if (!this.rrw.isMaterial(e.id, MATERIAL_THRESHOLD * 0.5)) continue; // só vê materializado
      visible.push(e);
      if (e.categories.includes('phenomenon/fire')) threats.push(e);
    }
    const heard: RrwEntity[] = [];
    const seen = new Set<string>([this.id, ...visible.map((e) => e.id)]);
    for (const evt of this.rrw.recent(40)) {
      if (this.rrw.time - evt.at > 3) continue;
      for (const id of evt.entities) {
        if (seen.has(id)) continue;
        const pos = ctx.world.positionOf(id);
        if (pos && dist2d(pos.x, pos.y, p.x, p.y) <= HEAR_RADIUS && ['fire.starts', 'weather.storm.begins', 'society.famine.warning', 'npc.died'].includes(evt.type)) {
          const e = this.rrw.get(id);
          if (e?.alive) {
            heard.push(e);
            seen.add(id);
            if (evt.type === 'fire.starts') threats.push(this.rrw.get(id)!);
            if (evt.type === 'society.famine.warning') {
              this.setKnowledge('famine', true, 0.8, this.rrw.time);
              this.remember('heard-famine', 'ouvi alerta de fome na comunidade', this.rrw.time);
            }
          }
        }
      }
    }
    return { visible, heard, threats: [...new Map(threats.map((t) => [t.id, t])).values()] };
  }

  /* ---------------- necessidades ---------------- */

  private prevHunger = 0;

  /** dt em SEGUNDOS de simulação. */
  updateNeeds(dt: number, active: boolean): void {
    const n = this.mind.needs;
    const before = n.hunger;
    n.hunger = clamp(n.hunger + 0.012 * dt, 0, 1); // ~83 s de zero a crítico
    // cruzou o limiar → evento semântico (causa raiz de ações como 'comprar comida')
    if (before < 0.5 && n.hunger >= 0.5) {
      this.rrw.emit('npc.hunger', [this.id], { hunger: Number(n.hunger.toFixed(2)) });
      this.remember('fome', 'comecei a sentir fome', this.rrw.time);
    }
    this.prevHunger = n.hunger;
    n.social = clamp(n.social + 0.004 * dt * 10, 0, 1);
    if (active) n.energy = clamp(n.energy - 0.2 * dt, 0, 1);
    else n.energy = clamp(n.energy + 0.1 * dt, 0, 1);
  }

  /* ---------------- decisão por utilidade (não script) ---------------- */

  chooseGoal(ctx: NpcCtx, per: Perception): void {
    const m = this.mind;
    const time = ctx.time;
    if (m.goal && m.goal.until > time && m.goal.type !== 'flee') return; // mantém meta ativa
    if (time < m.retargetAt && !per.threats.length) return;
    // ações que exigem interação fina (mercado/social/trabalho) só em detalhe completo
    const fine = behaviorScale(this.ent.detail) === 1;

    const candidates: Array<{ type: string; utility: number; targetId: string | null; target: { x: number; y: number }; until: number }> = [];
    const p = this.pos();

    // FUGA: ameaça → utilidade dominante
    if (per.threats.length > 0) {
      const t = per.threats[0];
      const tp = ctx.world.positionOf(t.id)!;
      const away = { x: p.x + (p.x - tp.x) * 3, y: p.y + (p.y - tp.y) * 3 };
      candidates.push({ type: 'flee', utility: 5 + 3 * m.traits.bravery, targetId: t.id, target: { x: clamp(away.x, 0, ctx.world.worldSize()), y: clamp(away.y, 0, ctx.world.worldSize()) }, until: time + 2 });
    }
    // COMER (sem comida, ir ao mercado exige detalhe fino — interação de comércio)
    if (m.needs.hunger > 0.45) {
      const hasFood = (m.inventory.food ?? 0) > 0;
      if (hasFood || fine) {
        const famine = m.knowledge['famine'] ? 0.3 : 0; // fome coletiva aumenta urgência
        const marketK = m.knowledge['market'];
        const target = hasFood
          ? p
          : marketK
            ? (marketK.value as { x: number; y: number })
            : p;
        candidates.push({ type: 'eat', utility: (m.needs.hunger + famine) * 3, targetId: hasFood ? null : marketK ? (marketK.value as { id: string }).id : null, target, until: time + 4 });
      }
      // sem comida e coarse: sem candidata de comer (não compra) → explora/espera
    }
    // DESCANSAR
    if (m.needs.energy < 0.35) {
      const home = m.home ?? p;
      candidates.push({ type: 'rest', utility: (1 - m.needs.energy) * 2.2, targetId: null, target: { x: home.x, y: home.y }, until: time + 6 });
    }
    // TRABALHAR (exige detalhe fino — atividade com consequência econômica)
    if (fine && m.work && m.needs.energy > 0.25 && m.needs.hunger < 0.8) {
      const loc = m.work.locationId ? ctx.world.positionOf(m.work.locationId) : p;
      candidates.push({ type: 'work', utility: 1.4 * m.traits.workEthic + (m.money < 3 ? 0.8 : 0), targetId: m.work.locationId, target: { x: loc?.x ?? p.x, y: loc?.y ?? p.y }, until: time + 5 });
    }
    // COMER NO MERCADO / TROCAR (só em detalhe fino)
    const marketK = m.knowledge['market'] as { value: { id: string; x: number; y: number } } | undefined;
    if (fine && marketK && m.needs.hunger > 0.55 && m.money > 1 && (m.inventory.food ?? 0) === 0) {
      candidates.push({ type: 'trade', utility: m.needs.hunger * 2.4, targetId: marketK.value.id, target: { x: marketK.value.x, y: marketK.value.y }, until: time + 4 });
    }
    // SOCIALIZAR (só em detalhe fino)
    if (fine && m.needs.social > 0.5 && per.visible.length > 0) {
      const other = per.visible.find((e) => e.categories.includes('organism/human')) ?? per.visible[0];
      const op = ctx.world.positionOf(other.id)!;
      candidates.push({ type: 'socialize', utility: m.needs.social * 1.6 * m.traits.sociability + this.relateTo(other.id).trust * 0.4, targetId: other.id, target: op, until: time + 3 });
    }
    // EXPLORAR (baixa prioridade — preenche conhecimento)
    if (candidates.length === 0) {
      const a = ctx.rng.next() * Math.PI * 2;
      const d = 2 + ctx.rng.next() * 4;
      candidates.push({ type: 'explore', utility: 0.3, targetId: null, target: { x: clamp(p.x + Math.cos(a) * d, 0, ctx.world.worldSize()), y: clamp(p.y + Math.sin(a) * d, 0, ctx.world.worldSize()) }, until: time + 4 });
    }

    candidates.sort((a, b) => b.utility - a.utility);
    const best = candidates[0];
    m.goal = { type: best.type, targetId: best.targetId, target: best.target, until: best.until };
    m.state = best.type === 'rest' ? 'resting' : best.type === 'flee' ? 'fleeing' : best.type;
    m.retargetAt = time + 0.8;
    if (best.type !== 'explore') this.remember(`goal.${best.type}`, `metas: escolhi ${best.type} (utilidade ${best.utility.toFixed(2)})`, time);
  }

  /* ---------------- ação ---------------- */

  act(ctx: NpcCtx, per: Perception): void {
    const m = this.mind;
    const goal = m.goal;
    if (!goal) return;
    const p = this.pos();
    const d = dist2d(p.x, p.y, goal.target.x, goal.target.y);
    const arrived = d < 0.6;

    if (goal.type === 'flee') {
      // afasta da ameaça enquanto ela persistir
      if (per.threats.length === 0 || d > 12) {
        m.goal = null;
        m.state = 'idle';
        m.needs.safety = clamp(m.needs.safety + 0.3, 0, 1);
        return;
      }
      this.moveToward(goal.target, ctx);
      m.needs.safety = clamp(m.needs.safety - 0.4 * ctx.dt, 0, 1);
      return;
    }

    if (!arrived) {
      this.moveToward(goal.target, ctx);
      m.state = 'moving';
      return;
    }

    // chegada → efeito
    switch (goal.type) {
      case 'eat': {
        if ((m.inventory.food ?? 0) > 0) {
          m.inventory.food -= 1;
          m.needs.hunger = clamp(m.needs.hunger - 0.55, 0, 1);
          this.remember('ate', 'comi e a fome aliviou', ctx.time);
          this.rrw.emit('npc.eat', [this.id], { food: 1 }, null);
        } else if (goal.targetId) {
          this.tryTradeFood(ctx, goal.targetId);
        }
        m.goal = null;
        m.state = 'idle';
        break;
      }
      case 'rest': {
        m.needs.energy = clamp(m.needs.energy + 0.25, 0, 1);
        if (m.needs.energy < 0.9) {
          goal.until = ctx.time + 2; // continua descansando
          m.state = 'resting';
        } else {
          m.goal = null;
          m.state = 'idle';
        }
        break;
      }
      case 'work': {
        const out = this.workProduce(ctx);
        m.goal = null;
        m.state = 'idle';
        this.remember('trabalhei', `produzi ${out.item} (${out.qty})`, ctx.time);
        break;
      }
      case 'trade': {
        this.tryTradeFood(ctx, goal.targetId!);
        m.goal = null;
        m.state = 'idle';
        break;
      }
      case 'socialize': {
        if (goal.targetId) {
          const other = this.rrw.get(goal.targetId);
          if (other?.alive) {
            const rel = this.relateTo(other.id);
            rel.trust = clamp(rel.trust + 0.08, 0, 1);
            m.needs.social = clamp(m.needs.social - 0.4, 0, 1);
            this.rrw.emit('npc.socialize', [this.id, other.id], { trust: rel.trust });
          }
        }
        m.goal = null;
        m.state = 'idle';
        break;
      }
      case 'explore': {
        // conhecimento: o que este lugar tem
        const here = ctx.world.biomeAt(p.x, p.y);
        this.setKnowledge(`biome.${Math.floor(p.x / 4)},${Math.floor(p.y / 4)}`, here, 0.9, ctx.time);
        m.goal = null;
        m.state = 'idle';
        break;
      }
    }
  }

  private moveToward(target: { x: number; y: number }, ctx: NpcCtx): void {
    const p = this.pos();
    const d = dist2d(p.x, p.y, target.x, target.y);
    if (d < 0.05) return;
    // speed = unidades de mundo por segundo de simulação
    const step = Math.min(d, this.mind.speed * ctx.dt);
    this.setPos(p.x + ((target.x - p.x) / d) * step, p.y + ((target.y - p.y) / d) * step);
  }

  private workProduce(ctx: NpcCtx): { item: string; qty: number } {
    const m = this.mind;
    const work = m.work;
    if (!work) return { item: 'nothing', qty: 0 };
    const item = work.type === 'farmer' ? 'food' : work.type === 'lumberjack' ? 'wood' : work.type === 'miner' ? 'ore' : 'goods';
    const qty = 1;
    m.inventory[item] = (m.inventory[item] ?? 0) + qty;
    m.money += work.type === 'merchant' ? 0 : 0; // salário vem da sociedade
    this.rrw.emit('work.produced', [this.id], { item, qty }, { by: this.id, event: 'work.assigned', description: 'produção pelo trabalho' });
    return { item, qty };
  }

  private tryTradeFood(ctx: NpcCtx, marketId: string): void {
    const m = this.mind;
    // só compra por causa real: sem fome relevante não há transação
    if (m.needs.hunger < 0.5) return;
    const market = this.rrw.get(marketId);
    if (!market?.alive) return;
    const stock = market.data.stock as { food?: { qty: number; price: number } };
    const entry = stock.food;
    if (!entry || entry.qty <= 0) {
      this.remember('mercado-sem-comida', 'o mercado estava sem comida', ctx.time);
      return;
    }
    const price = Math.max(1, Math.round(entry.price));
    if (m.money < price) {
      this.remember('sem-dinheiro', 'queria comprar comida, mas sem dinheiro', ctx.time);
      return;
    }
    m.money -= price;
    m.inventory.food = (m.inventory.food ?? 0) + 1;
    entry.qty -= 1;
    (market.data.demand as Record<string, number>).food = ((market.data.demand as Record<string, number>).food ?? 0) + 1;
    m.needs.hunger = clamp(m.needs.hunger - 0.55, 0, 1);
    this.rrw.emit('npc.trade', [this.id, market.id], { item: 'food', qty: 1, price }, { by: this.id, event: 'npc.hunger', description: 'comprei comida por causa da fome' });
    this.remember('comprei-comida', `comprei 1 comida por ${price} moedas`, ctx.time);
  }

  /* ---------------- avanço completo (um tick do NMN) ---------------- */

  step(ctx: NpcCtx): void {
    if (!this.rrw.isMaterial(this.id, MATERIAL_THRESHOLD)) return; // D-2: abstrato não raciocina fino
    const active = this.mind.state === 'moving' || this.mind.state === 'working';
    this.updateNeeds(ctx.dt, active);
    const per = this.perceive(ctx);
    this.chooseGoal(ctx, per);
    this.act(ctx, per);
  }
}

/* ------------------------------------------------------------------ */
/* Fábrica de vilas (grupo social + casas + habitantes)                */
/* ------------------------------------------------------------------ */

export function buildVillage(world: World, x: number, y: number, opts: { name?: string; population?: number } = {}): RrwEntity {
  const rrw = world.rrw;
  Npc.ensureComponents(rrw);
  const name = opts.name ?? 'vila';
  const population = opts.population ?? 4;
  const group = rrw.create({
    name,
    categories: ['society/group'],
    components: { Position: { x, y } },
    data: {
      population,
      farmers: Math.max(1, Math.floor(population * 0.5)),
      loggers: Math.max(1, Math.floor(population * 0.3)),
      miners: Math.max(0, Math.floor(population * 0.2)),
      stock: { food: population * 6, wood: population * 4, ore: 0 },
      production: { food: 0, wood: 0, ore: 0 },
      priceIndex: 1,
    },
    detail: 1,
  });
  const c = world.chunkAt(Math.floor(x / world.cfg.chunkSize), Math.floor(y / world.cfg.chunkSize));
  const ctxId = c.state['contextId'] as string | undefined;
  // casas
  for (let i = 0; i < 2; i++) {
    world.spawnStructure('house', x + (i % 2) * 2, y + Math.floor(i / 2) * 2);
  }
  // habitantes
  const jobs = ['farmer', 'farmer', 'lumberjack', 'miner', 'merchant'];
  for (let i = 0; i < population; i++) {
    const a = world.rng.next() * Math.PI * 2;
    const r = world.rng.next() * 2;
    const npc = Npc.create(world, {
      x: x + Math.cos(a) * r,
      y: y + Math.sin(a) * r,
      work: jobs[i % jobs.length],
    });
    npc.ent.contextId = ctxId ?? npc.ent.contextId;
    rrw.relate(npc.id, group.id, 'member-of', { weight: 1 });
    npc.setKnowledge('village', { id: group.id, name }, 0.9, rrw.time);
  }
  rrw.emit('society.village.founded', [group.id], { population }, { by: group.id, description: 'vila fundada' });
  return group;
}
