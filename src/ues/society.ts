/**
 * UES · Society — grupos, economia e eventos emergentes.
 *
 * Representação adaptativa (Prompt 2/17):
 *  - vilas/grupos evoluem como AGREGADOS semânticos (estoques, produção,
 *    consumo) mesmo ABSTRATOS — mundo vivo fora do foco;
 *  - indivíduos (NPCs) só raciocinam em detalhe quando materializados;
 *  - preço por oferta/demanda; alerta de fome com CAUSALIDADE
 *    (estoque baixo → society.famine.warning → urgência de fome dos NPCs).
 */

import { Logger, Rng, clamp, dist2d } from '../core/index.ts';
import type { RrwEntity } from '../rrw/index.ts';
import type { World } from './world.ts';

export interface SocietyCtx {
  dt: number;
  time: number;
  rng: Rng;
  world: World;
}

export class Society {
  world: World;
  log: Logger;
  famineCooldown = new Map<string, number>();

  constructor(world: World, log?: Logger) {
    this.world = world;
    this.log = (log ?? new Logger('ues')).child('society');
  }

  define(): void {
    const r = this.world.rrw;
    if (r.getProcess('society.production')) return;
    r.defineProcess('society.production', {
      init: () => 'active',
      // Agrupados evoluem em ABSTRAÇÃO (custo baixo) — o mundo continua vivo
      abstractTick: (ent, _s, ctx) => this.groupStep(ent, ctx.dt),
      tick: (ent, _s, ctx) => this.groupStep(ent, ctx.dt),
    });
    r.defineProcess('market.prices', {
      init: () => 'active',
      abstractTick: (ent, _s, ctx) => this.marketStep(ent, ctx.dt),
      tick: (ent, _s, ctx) => this.marketStep(ent, ctx.dt),
    });
  }

  /** (Re)registra grupos e mercados nos processos. */
  refresh(): void {
    const r = this.world.rrw;
    const groups = r.query({ categories: ['society/group'] });
    const markets = r.query({ categories: ['structure'], data: { type: 'market' } });
    if (groups.length) r.startProcess('society.production', groups.map((g) => g.id));
    if (markets.length) r.startProcess('market.prices', markets.map((m) => m.id));
  }

  private groupStep(ent: RrwEntity, dt: number): void {
    const data = ent.data;
    const stock = data.stock as Record<string, number>;
    const production = data.production as Record<string, number>;
    const population = Number(data.population ?? 1);
    const farmers = Number(data.farmers ?? 1);
    const loggers = Number(data.loggers ?? 0);
    const miners = Number(data.miners ?? 0);
    // produção (depende de ter comida para trabalhar — feedback real)
    const fed = stock.food > population * 0.5 ? 1 : 0.3;
    const produced = { food: farmers * 0.35 * fed * dt, wood: loggers * 0.25 * dt, ore: miners * 0.12 * dt };
    production.food = (production.food ?? 0) + produced.food;
    production.wood = (production.wood ?? 0) + produced.wood;
    production.ore = (production.ore ?? 0) + produced.ore;
    stock.food += produced.food;
    stock.wood += produced.wood;
    stock.ore += produced.ore;
    // consumo (dieta por habitante)
    const diet = population * 0.22 * dt;
    stock.food -= diet;
    data.consumedLast = diet;
    // famine: estoque abaixo de ~2.5 "dias" de dieta
    const reserveDays = stock.food / (population * 0.22);
    if (reserveDays < 2.5) {
      const last = this.famineCooldown.get(ent.id) ?? -Infinity;
      if (this.world.rrw.time - last > 30) {
        this.famineCooldown.set(ent.id, this.world.rrw.time);
        this.emitFamine(ent, reserveDays);
      }
    } else {
      stock.food = Math.max(0, stock.food);
    }
    // preço indexado local (escassez → carência)
    (data as Record<string, unknown>).priceIndex = clamp(1 + (5 - reserveDays) * 0.15, 1, 4);
  }

  private marketStep(ent: RrwEntity, dt: number): void {
    const data = ent.data;
    const stock = data.stock as Record<string, { qty: number; price: number }>;
    const demand = data.demand as Record<string, number>;
    void dt;
    for (const [item, entry] of Object.entries(stock)) {
      const d = demand[item] ?? 0;
      const s = entry.qty;
      // lei de oferta e demanda: demanda > estoque → preço sobe
      const pressure = (d - Math.min(s, 10) * 0.2) * 0.08;
      entry.price = clamp(entry.price * (1 + pressure), 0.5, 12);
      demand[item] = 0; // reseta a cada ciclo
    }
    // reposição lenta do mercado pela economia local
    for (const [item, entry] of Object.entries(stock)) {
      entry.qty = clamp(entry.qty + 0.2 * dt * 10 * 0.1, 0, 40);
    }
  }

  step(ctx: SocietyCtx): void {
    const r = this.world.rrw;
    const c = { ...ctx, rrw: r };
    r.stepProcess('society.production', c);
    r.stepProcess('market.prices', c);
  }

  private emitFamine(ent: RrwEntity, reserveDays: number): void {
    const r = this.world.rrw;
    r.emit('society.stock.low', [ent.id], { stock: { ...(ent.data.stock as Record<string, number>) } });
    r.emit('society.famine.warning', [ent.id], { reserveDays: Number(reserveDays.toFixed(2)) }, { by: ent.id, event: 'society.stock.low', description: `estoque de comida para ${reserveDays.toFixed(1)} dias` });
    this.log.warn(`alerta de fome em ${ent.name} (${reserveDays.toFixed(1)} dias de reserva)`);
  }

  /** Resumo da economia (para IA/demos). */
  summary(): Array<{ id: string; name: string | null; population: number; stock: Record<string, number>; priceIndex: number }> {
    return this.world.rrw.query({ categories: ['society/group'] }).map((g) => ({
      id: g.id,
      name: g.name,
      population: Number(g.data.population ?? 0),
      stock: { ...(g.data.stock as Record<string, number>) },
      priceIndex: Number(g.data.priceIndex ?? 1),
    }));
  }
}


