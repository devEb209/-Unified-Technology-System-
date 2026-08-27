/**
 * UTS · D-O15 — camada de OTIMIZAÇÃO (não "reduzir qualidade").
 *
 * Princípio (versão mais recente):
 *   «Qual é a melhor maneira de representar e calcular aquilo que realmente
 *    precisa existir neste momento?»
 *
 * Otimização correta = obter o mesmo (ou praticamente o mesmo) resultado
 * necessário com representação/processamento mais eficiente — mudando
 * frequência, precisão, representação, armazenamento ou materialização.
 *
 * Componentes reais e testados:
 *  - HardwareProfile (presets + detecção heurística);
 *  - Profiler (custo por sistema, gargalo, memória);
 *  - StrategyEngine (decisão por sistema: detalhe concedido, Hz, representação);
 *  - AdaptiveScheduler (executa dentro do orçamento; defere em vez de travar).
 *
 * Regra de ouro: sistemas críticos (preservação de estado) NUNCA caem abaixo
 * do floor — otimizar não pode apagar informação importante.
 */

import os from 'node:os';
import { Logger, PerfMeter, clamp } from '../core/index.ts';
import { TeseDosD } from '../d/index.ts';

/* ------------------------------------------------------------------ */
/* Hardware                                                            */
/* ------------------------------------------------------------------ */

export interface HardwareProfile {
  id: string;
  label: string;
  /** Orçamento de CPU por tick de simulação (ms). */
  cpuBudgetMs: number;
  /** Orçamento de memória (MB de heap). */
  memoryBudgetMB: number;
  /** Ticks de simulação por segundo. */
  targetTps: number;
  quality: 'low' | 'medium' | 'high' | 'ultra';
  detected: boolean;
}

export const HARDWARE_PRESETS: Record<string, HardwareProfile> = {
  'low-end': { id: 'low-end', label: 'Baixo desempenho', cpuBudgetMs: 4, memoryBudgetMB: 1024, targetTps: 10, quality: 'low', detected: false },
  mid: { id: 'mid', label: 'Médio desempenho', cpuBudgetMs: 10, memoryBudgetMB: 4096, targetTps: 10, quality: 'medium', detected: false },
  'high-end': { id: 'high-end', label: 'Alto desempenho', cpuBudgetMs: 25, memoryBudgetMB: 16384, targetTps: 10, quality: 'high', detected: false },
  workstation: { id: 'workstation', label: 'Estação de trabalho', cpuBudgetMs: 60, memoryBudgetMB: 65536, targetTps: 10, quality: 'ultra', detected: false },
};

/** Heurística: CPUs + memória total (não é exata — é um ponto de partida). */
export function detectHardware(): HardwareProfile {
  let nCpu = 2;
  let memMB = 4096;
  try {
    nCpu = os.cpus().length || 2;
    memMB = Math.round(os.totalmem() / 1048576) || 4096;
  } catch {
    /* ambiente sem os */
  }
  let base: HardwareProfile;
  if (nCpu >= 8 && memMB >= 16384) base = HARDWARE_PRESETS['high-end'];
  else if (nCpu >= 4 && memMB >= 8192) base = HARDWARE_PRESETS.mid;
  else base = HARDWARE_PRESETS['low-end'];
  return { ...base, detected: true, label: `${base.label} (detectado: ${nCpu} cpus, ${memMB} MB)` };
}

/* ------------------------------------------------------------------ */
/* Profiler                                                            */
/* ------------------------------------------------------------------ */

export interface SystemCost {
  name: string;
  count: number;
  totalMs: number;
  avgMs: number;
  maxMs: number;
  /** Fração do total medido (0..1). */
  share: number;
}

export class Profiler {
  private window: { name: string; count: number; totalMs: number; maxMs: number }[] = [];
  private meter: PerfMeter;

  constructor(meter: PerfMeter) {
    this.meter = meter;
  }

  /** Captura a janela atual (desde o último sample ou reset). */
  sample(): SystemCost[] {
    const snap = this.meter.snapshot();
    const total = snap.reduce((a, e) => a + e.totalMs, 0);
    return snap.map((e) => ({
      name: e.name,
      count: e.count,
      totalMs: e.totalMs,
      avgMs: e.count ? e.totalMs / e.count : 0,
      maxMs: e.maxMs,
      share: total > 0 ? e.totalMs / total : 0,
    }));
  }

  top(n = 5): SystemCost[] {
    return this.sample()
      .sort((a, b) => b.totalMs - a.totalMs)
      .slice(0, n);
  }

  /** Pressão de CPU: tempo total medido na janela vs orçamento. */
  pressure(budgetMs: number): number {
    const snap = this.meter.snapshot();
    const total = snap.reduce((a, e) => a + e.totalMs, 0);
    return budgetMs > 0 ? total / budgetMs : 0;
  }

  memoryMB(): number {
    const h = process.memoryUsage?.();
    return h ? Math.round(h.heapUsed / 1048576) : 0;
  }

  /**
   * Gargalo: apenas quando o orçamento é efetivamente estourado.
   * Com folga de orçamento, "maior fração" não é gargalo (evita falso positivo).
   */
  bottleneck(budgetMs: number): SystemCost | null {
    const costs = this.sample();
    const total = costs.reduce((a, c) => a + c.totalMs, 0);
    if (total <= budgetMs) return null; // sem estouro, sem gargalo
    for (const c of costs.sort((a, b) => b.totalMs - a.totalMs)) {
      if (c.totalMs <= 0) continue;
      if (c.share >= 0.25) return c;
    }
    return null;
  }

  clear(): void {
    this.window = [];
    this.meter.reset();
  }
}

/* ------------------------------------------------------------------ */
/* Estratégia (D-O15)                                                  */
/* ------------------------------------------------------------------ */

export type Representation = 'full' | 'coarse' | 'aggregate' | 'cached';

export interface StrategyDecision {
  system: string;
  requestedDetail: number;
  grantedDetail: number;
  updateHz: number;
  representation: Representation;
  relevance: number;
  reason: string;
}

export interface SystemSpec {
  id: string;
  /** Frequência base (ideal, hardware sem pressão). */
  baseHz: number;
  minHz: number;
  /** Detalhe pedido à Tese dos D (0..1). */
  baseDetail: number;
  /** Prioridade no orçamento (maior roda primeiro). */
  priority: number;
  /** Crítico = preservação de estado: nunca cai abaixo do floor. */
  critical: boolean;
}

export class StrategyEngine {
  private hardware: HardwareProfile;
  private tese: TeseDosD;
  private log: Logger;
  private relevance = new Map<string, number>();
  decisions: Map<string, StrategyDecision> = new Map();

  constructor(opts: { hardware: HardwareProfile; tese: TeseDosD; log?: Logger }) {
    this.hardware = opts.hardware;
    this.tese = opts.tese;
    this.log = (opts.log ?? new Logger('d-o15')).child('strategy');
  }

  get hardwareProfile(): HardwareProfile {
    return this.hardware;
  }

  setHardware(h: HardwareProfile): void {
    this.hardware = h;
  }

  setRelevance(systemId: string, v: number): void {
    this.relevance.set(systemId, clamp(v, 0, 1));
  }

  relevanceOf(systemId: string): number {
    return this.relevance.get(systemId) ?? 1;
  }

  /**
   * Recalcula decisões para todos os sistemas.
   *
   * Regras (comportamento observável, testado):
   *  - p < 0.5        → concede o pedido (folga; permite promoção/materialização);
   *  - 0.5 ≤ p < 0.9  → escala contínua: scale = 1 - ((p-0.5)/0.4)*0.55
   *                     (p=0.5 → 1.0 · p=0.9 → 0.45), com agravamento por relevância;
   *  - p ≥ 0.9        → não críticos: 'cached' (detalhe 0);
   *                     críticos: floor de estado (10% do pedido) em Hz mínimo.
   *  - Hz acompanha o detalhe concedido (proporcional, dentro de min/max).
   *  - representação: full ≥0.85 · coarse ≥0.4 · aggregate >0 · cached 0.
   */
  decide(specs: SystemSpec[], pressure: number): StrategyDecision[] {
    const out: StrategyDecision[] = [];
    for (const s of specs) {
      const rel = this.relevanceOf(s.id);
      const req = s.baseDetail;
      let granted = req;
      let reason = 'folga de orçamento';
      if (pressure >= 0.9) {
        if (s.critical) {
          granted = Math.max(0.1, req * 0.1);
          reason = `pressão ${pressure.toFixed(2)}: crítico, floor de estado (10%) em Hz mínimo`;
        } else {
          granted = 0;
          reason = `pressão ${pressure.toFixed(2)}: deslocado para representação cached`;
        }
      } else if (pressure >= 0.5) {
        const scale = 1 - ((Math.min(pressure, 0.9) - 0.5) / 0.4) * 0.55;
        granted = req * scale;
        // relevância baixa agrava o downgrade (otimização inteligente, não cega)
        if (rel < 0.5 && !s.critical) granted = Math.min(granted, req * rel * 2);
        const floor = s.critical ? 0.1 : 0;
        granted = Math.max(floor, Math.min(req, granted));
        reason = `pressão ${pressure.toFixed(2)}: escala ${scale.toFixed(2)} (relevância ${rel.toFixed(2)})`;
      }
      granted = clamp(granted, 0, 1);
      const hzScale = req > 0 ? granted / req : 1;
      const updateHz = granted === 0 ? 0 : clamp(s.baseHz * hzScale, s.minHz, s.baseHz);
      const representation: Representation =
        granted >= 0.85 ? 'full' : granted >= 0.4 ? 'coarse' : granted > 0 ? 'aggregate' : 'cached';
      const d: StrategyDecision = {
        system: s.id,
        requestedDetail: req,
        grantedDetail: Number(granted.toFixed(3)),
        updateHz: Number(updateHz.toFixed(3)),
        representation,
        relevance: Number(rel.toFixed(3)),
        reason,
      };
      this.decisions.set(s.id, d);
      out.push(d);
    }
    if (pressure >= 0.9) {
      this.log.warn(`pressão alta (${pressure.toFixed(2)}) — applying fallback strategy`, { hardware: this.hardware.id });
    }
    return out;
  }

  decision(systemId: string): StrategyDecision | undefined {
    return this.decisions.get(systemId);
  }

  /** Relatório D-O15 (alimenta Singularity AI e o relatório final). */
  report(profiler: Profiler): {
    hardware: HardwareProfile;
    pressure: number;
    bottleneck: SystemCost | null;
    memoryMB: number;
    decisions: StrategyDecision[];
  } {
    return {
      hardware: this.hardware,
      pressure: Number(profiler.pressure(this.hardware.cpuBudgetMs).toFixed(3)),
      bottleneck: profiler.bottleneck(this.hardware.cpuBudgetMs),
      memoryMB: profiler.memoryMB(),
      decisions: [...this.decisions.values()].map((d) => ({ ...d })),
    };
  }
}

/* ------------------------------------------------------------------ */
/* Scheduler adaptativo                                                */
/* ------------------------------------------------------------------ */

export interface TickReport {
  ran: string[];
  /** Vencidos, mas adiados por falta de orçamento (adaptação real). */
  deferred: string[];
  /** Ainda não vencidos neste tick (não é adaptação, é agendamento). */
  notDue: string[];
  budgetMs: number;
  usedMs: number;
  overBudget: boolean;
}

export class AdaptiveScheduler {
  private strategy: StrategyEngine;
  private meter: PerfMeter;
  private log: Logger;
  private specs = new Map<string, SystemSpec & { fn: (ctx: Record<string, unknown>) => void; nextDue: number; hz: number }>();

  constructor(opts: { strategy: StrategyEngine; meter: PerfMeter; log?: Logger }) {
    this.strategy = opts.strategy;
    this.meter = opts.meter;
    this.log = (opts.log ?? new Logger('d-o15')).child('scheduler');
  }

  register(spec: SystemSpec, fn: (ctx: Record<string, unknown>) => void): void {
    this.specs.set(spec.id, { ...spec, fn, nextDue: 0, hz: spec.baseHz });
  }

  unregister(id: string): void {
    this.specs.delete(id);
  }

  specsList(): SystemSpec[] {
    return [...this.specs.values()].map((s) => ({ id: s.id, baseHz: s.baseHz, minHz: s.minHz, baseDetail: s.baseDetail, priority: s.priority, critical: s.critical }));
  }

  /** Estado de agendamento (persistência determinística). */
  scheduleState(): Record<string, { nextDue: number; hz: number }> {
    const out: Record<string, { nextDue: number; hz: number }> = {};
    for (const [id, s] of this.specs) out[id] = { nextDue: s.nextDue, hz: s.hz };
    return out;
  }

  restoreScheduleState(state: Record<string, { nextDue: number; hz: number }>): void {
    for (const [id, s] of this.specs) {
      const st = state[id];
      if (st) {
        s.nextDue = st.nextDue;
        s.hz = st.hz;
      }
    }
  }

  /**
   * Um passo do scheduler (chamado a cada tick de simulação).
   * Roda sistemas vencidos em ordem de prioridade, dentro do orçamento.
   * O que não cabe é DEFERIDO (continua agendado) — nunca é descartado.
   */
  step(nowS: number, ctx: Record<string, unknown> = {}): TickReport {
    const budget = this.strategy.hardwareProfile.cpuBudgetMs;
    // atualiza Hz a partir das decisões (o engine chama strategy.decide periodicamente)
    for (const s of this.specs.values()) {
      const d = this.strategy.decision(s.id);
      if (d) s.hz = Math.max(d.updateHz, s.minHz);
    }
    const order = [...this.specs.values()].sort((a, b) => b.priority - a.priority);
    const ran: string[] = [];
    const deferred: string[] = [];
    const notDue: string[] = [];
    let used = 0;
    for (const s of order) {
      if (s.hz <= 0) {
        notDue.push(s.id);
        continue;
      }
      if (nowS >= s.nextDue) {
        if (used >= budget) {
          deferred.push(s.id); // vencido, mas o orçamento acabou
          continue;
        }
        // A execução REAL é medida (o Profiler lê de fato o custo por sistema).
        this.meter.measure(`sys:${s.id}`, () => s.fn(ctx));
        const e = this.meter.get(`sys:${s.id}`);
        used += e?.lastMs ?? 0;
        ran.push(s.id);
        // próximo vencimento: pelo Hz concedido (catch-up: nunca adia mais de 2 ciclos)
        const period = 1 / Math.max(s.hz, 0.001);
        s.nextDue = Math.min(nowS + period, nowS + period * 2);
      } else {
        notDue.push(s.id);
      }
    }
    return { ran, deferred, notDue, budgetMs: budget, usedMs: used, overBudget: used > budget };
  }
}
