// UTS/UES GEN-1 — leitura de "frame generation" honesta: a pergunta "estar a 15 fps
// mas com suavização que parece 30" é uma CONTA, não uma opinião, e ela é POR CÉLULA.
// Reusa as decisões do plan.json (o D que o orçamento escolheu) e o unitsPerSecond do
// device.json; sem esses dois arquivos o resultado é texto decorativo, então não há
// modo de adivinhação aqui.
import { ladderFor } from '../../d-system/src/ladders.ts';
import { presentBudget, type DisocclusionPolicy } from '../../do15/src/present.ts';
import type { Region } from '../../do15/src/optimizer.ts';

export interface PresentCellReport {
  readonly cell: readonly [number, number];
  readonly verdict: 'vale' | 'não vale';
  readonly simHz: number;
  readonly dispHz: number;
  readonly simSaving: number;
  readonly savingMs: number;
  readonly addedLatencyMs: number;
  readonly presentCostPerFrameMs: number;
  readonly viewModelCostPerFrameMs: number;
  readonly why: string;
}

export interface PresentReport {
  readonly kind: 'uts.genesis.present';
  readonly schemaVersion: 1;
  readonly scene: string;
  readonly calibration: { readonly unitsPerSecond: number; readonly deviceFile: string | null };
  readonly summary: {
    readonly cells: number;
    readonly worth: number;
    readonly notWorth: number;
    readonly msSavedSum: number;
    readonly latencyTaxMs: number;
  };
  readonly headline: string;
  readonly cells: PresentCellReport[];
}

export function presentOverPlan(
  plan: any,
  scene: any,
  opts: { simHz: number; dispHz: number; unitsPerSecond: number; deviceFile?: string | null; policy?: DisocclusionPolicy },
): PresentReport {
  if (!plan || plan.kind !== 'uts.genesis.plan') throw new Error('present: o --plan não é um plan.json do uts');
  if (!(opts.unitsPerSecond > 0)) throw new Error('present: unitsPerSecond precisa vir de medição (uts measure) — sem ele a conta é ficção');
  const px = (scene?.screen?.width ?? plan.device?.screen?.width ?? 720) * (scene?.screen?.height ?? plan.device?.screen?.height ?? 1612);
  const cellsIn = scene?.cells ?? [];
  const byCell = new Map<string, any>();
  for (const r of plan.regions ?? []) byCell.set(`${r.cell[0]},${r.cell[1]}`, r);

  const cells: PresentCellReport[] = [];
  for (const c of cellsIn) {
    const decided = byCell.get(`${c.x},${c.y}`);
    if (!decided || decided.kind !== 'ok') continue; // célula infeasível não tem o que suavizar
    const decisions: Record<string, any> = {};
    for (const [dom, v] of Object.entries(decided.decisions ?? {})) {
      const D = (v as any).D;
      decisions[dom] = { domain: dom as any, D, step: ladderFor(dom as any).steps[D] };
    }
    const region: Region = {
      id: `r:${c.x},${c.y}`,
      pixels: c.pixels ?? px,
      entities: c.entities ?? 0,
      lights: c.lights ?? 0,
      volumes: c.volumes ?? 0,
      importance: c.importance ?? 0.5,
      motion: c.motion ?? 0.2,
    };
    const b = presentBudget(decisions, region, { simHz: opts.simHz, dispHz: opts.dispHz, unitsPerSecond: opts.unitsPerSecond, policy: opts.policy });
    cells.push({
      cell: [c.x, c.y],
      verdict: b.verdict,
      simHz: b.simHz,
      dispHz: b.dispHz,
      simSaving: b.simSaving,
      savingMs: b.savingMs,
      addedLatencyMs: b.addedLatencyMs,
      presentCostPerFrameMs: b.presentCostPerFrameMs,
      viewModelCostPerFrameMs: b.viewModelCostPerFrameMs,
      why: b.why,
    });
  }
  const worth = cells.filter((c) => c.verdict === 'vale');
  const msSavedSum = Number(worth.reduce((a, c) => a + c.savingMs, 0).toFixed(2));
  const summary = {
    cells: cells.length,
    worth: worth.length,
    notWorth: cells.length - worth.length,
    msSavedSum,
    latencyTaxMs: worth.length ? worth[0].addedLatencyMs : 0,
  };
  const headline = cells.length === 0
    ? 'nenhuma célula viável no plano — nada a suavizar'
    : worth.length === 0
      ? `frame generation NÃO vale em ${cells.length}/${cells.length} células: a 720p o que manda é o render, e a reprojeção custaria mais do que poupa. Suavize pelo caminho livre (câmera/arma/UI na taxa da tela) e recupere o quadro cortando trabalho materializado, não apresentando mais.`
      : `frame generation vale em ${worth.length}/${cells.length} células (${msSavedSum} ms/soma por quadro), ao preço de ${summary.latencyTaxMs} ms de latência nos corpos dos outros; nas demais, não.`;
  return {
    kind: 'uts.genesis.present',
    schemaVersion: 1,
    scene: plan.scene,
    calibration: { unitsPerSecond: opts.unitsPerSecond, deviceFile: opts.deviceFile ?? null },
    summary,
    headline,
    cells,
  };
}
