#!/usr/bin/env node
// UTS/UES GEN-1 — CLI fino. Toda a lógica está em src/*.ts (testada); aqui só
// leitura de args, escrita de arquivo e código de saída.
import { readFileSync, writeFileSync } from 'node:fs';
import { planScene } from './src/plan.ts';
import { measureDevice } from './src/measure.ts';

const [cmd, ...rest] = process.argv.slice(2);
const flag = (name, dflt) => {
  const i = rest.indexOf(`--${name}`);
  return i >= 0 ? rest[i + 1] : dflt;
};

function die(msg, code = 2) {
  process.stderr.write(`${msg}\n`);
  process.exit(code);
}

if (cmd === 'measure') {
  const profile = measureDevice({
    iterations: Number(flag('iterations', 200)),
    gridSize: Number(flag('grid', 32)),
  }, { userAgent: process.env.USER_AGENT });
  const out = flag('out', 'device.json');
  writeFileSync(out, JSON.stringify(profile, null, 2) + '\n');
  process.stdout.write(`[medido] ${profile.unitsPerSecond} unidades de custo/s  (${profile.calibrationBand.low}→${profile.calibrationBand.high}: ${profile.msPerIteration} ms em ${profile.gridSize}×${profile.gridSize}, Δ ${profile.workloadUnits} unidades)\n`);
  process.stdout.write(`[aviso ] ${profile.note}\n`);
  if (profile.unitsPerSecond <= 0) { process.stderr.write('measure: calibração sem diferença mensurável — não gravei device.json\n'); process.exit(4); }
  process.stdout.write(`        gravado em ${out} — use: node packages/cli/run.js plan --scene cena.json --device ${out}\n`);
  process.exit(0);
}

if (cmd === 'plan') {
  const scenePath = flag('scene', 'scene.json');
  let scene;
  try {
    scene = JSON.parse(readFileSync(scenePath, 'utf8'));
  } catch (e) {
    die(`plan: não li a cena em ${scenePath}: ${e.message}`);
  }
  let unitsPerSecond;
  const devicePath = flag('device', undefined);
  if (devicePath) {
    const d = JSON.parse(readFileSync(devicePath, 'utf8'));
    if (d.kind !== 'uts.genesis.device') die(`plan: ${devicePath} não é um device.json do uts (kind="${d.kind}")`);
    unitsPerSecond = d.unitsPerSecond;
  }
  let plan;
  try {
    plan = planScene(scene, unitsPerSecond ? { unitsPerSecond, deviceFile: devicePath } : {});
  } catch (e) {
    die(`plan: ${e.message}`);
  }
  const out = flag('out', 'plan.json');
  writeFileSync(out, JSON.stringify(plan, null, 2) + '\n');
  const lines = [];
  lines.push(`cena "${plan.scene}" — ${plan.totals.cells} células, ${plan.totals.feasibleCells} viáveis, ${plan.totals.infeasibleCells} infeasíveis`);
  lines.push(`orçamento do frame: ${plan.device.frameBudgetMs.toFixed(2)} ms × ${(1 - plan.device.overhead).toFixed(2)} = ${plan.totals.budgetUnits.toFixed(0)} unidades; escolhido ${plan.totals.chosenUnits.toFixed(0)}`);
  const worst = plan.regions.filter((r) => r.kind === 'infeasible').slice(0, 5);
  for (const r of worst) lines.push(`  [infeasível] célula ${r.cell.join(',')} — ${r.error.message}`);
  const hot = [...plan.regions].filter((r) => r.kind === 'ok').sort((a, b) => (b.decisions?.visual?.D ?? 0) - (a.decisions?.visual?.D ?? 0))[0];
  if (hot) lines.push(`  [mais rica ] célula ${hot.cell.join(',')} → visual D${hot.decisions.visual.D}, físico D${hot.decisions.physical.D}, temporal D${hot.decisions.temporal.D} (${hot.cost}/${hot.budget})`);
  if (plan.calibration.warning) lines.push(`  [ALERTA] ${plan.calibration.warning}`);
  lines.push(`calibração: ${plan.calibration.source} (${plan.calibration.unitsPerSecond} un/s), utilização ${plan.calibration.utilization}`);
  lines.push(`aviso: ${plan.notice}`);
  process.stdout.write(lines.join('\n') + '\n');
  process.stdout.write(`gravado em ${out}\n`);
  // infeasível não é sucesso silencioso: sai com código próprio
  process.exit(plan.totals.infeasibleCells > 0 ? 3 : 0);
}

die(`uso:\n  node packages/cli/run.js measure [--iterations N] [--grid G] [--out device.json]\n  node packages/cli/run.js plan --scene cena.json [--device device.json] [--out plan.json]\n\nmedir antes de planejar: sem device.json o plano usa um chute de engenharia declarado (unitsPerSecond=3000).`);
