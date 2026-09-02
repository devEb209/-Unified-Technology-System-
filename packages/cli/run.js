#!/usr/bin/env node
// UTS/UES GEN-1 — CLI fino. Toda a lógica está em src/*.ts (testada); aqui só
// leitura de args, escrita de arquivo e código de saída.
import { readFileSync, writeFileSync } from 'node:fs';
import { planScene } from './src/plan.ts';
import { measureDevice } from './src/measure.ts';
import { presentOverPlan } from './src/present.ts';

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

if (cmd === 'demo') {
  // servidor fino: nenhuma lógica aqui, tudo em src/demo.ts
  const { spawn } = await import('node:child_process');
  const child = spawn(process.execPath, [...process.execArgv, new URL('./src/demo.ts', import.meta.url).pathname, 'demo', ...rest], { stdio: 'inherit', cwd: process.cwd() });
  // o filho É o processo de longa duração; o pai só repassa o código de saída.
  child.on('exit', (code, signal) => process.exit(signal ? 128 : (code ?? 1)));
  await new Promise(() => {}); // nunca cai no uso: fica vivo enquanto o filho serve
}

if (cmd === 'present') {
  const planPath = flag('plan', 'plan.json');
  const scenePath = flag('scene', 'scene.json');
  const devPath = flag('device', 'device.json');
  let plan, scene, ups, deviceFile = null;
  try {
    plan = JSON.parse(readFileSync(planPath, 'utf8'));
    scene = JSON.parse(readFileSync(scenePath, 'utf8'));
  } catch (e) {
    die(`present: não li ${planPath} / ${scenePath}: ${e.message}`);
  }
  try {
    const d = JSON.parse(readFileSync(devPath, 'utf8'));
    if (d.kind !== 'uts.genesis.device') die(`present: ${devPath} não é device.json do uts — rode: node bin/uts.mjs measure --out ${devPath}`);
    ups = d.unitsPerSecond;
    deviceFile = devPath;
  } catch (e) {
    die(`present: sem device.json medido não há conta a fazer (${e.message}).\n         rode no aparelho: node bin/uts.mjs measure --out ${devPath}`);
  }
  let report;
  try {
    report = presentOverPlan(plan, scene, {
      // simHz NÃO é o fps do plano: é a taxa a que o MUNDO avança. O plano fala do
      // quadro-alvo; aqui a pergunta é outra, e exigir o flag explícito evita a
      // leitura equivocada que faria "sim a 30, tela a 30" parecer suavização.
      simHz: Number(flag('sim-hz', 15)),
      dispHz: Number(flag('disp-hz', 30)),
      unitsPerSecond: ups,
      deviceFile,
      policy: flag('policy', 'repeat'),
    });
  } catch (e) {
    die(`present: ${e.message}`);
  }
  if (!(report.summary.cells > 0)) die('present: a cena não tem células viáveis no plano — rode plan primeiro com cells[] preenchidos');
  const out = flag('out', 'present.json');
  writeFileSync(out, JSON.stringify(report, null, 2) + '\n');
  const lines = [`cena "${report.scene}" — ${report.summary.cells} células: ${report.summary.worth} valem frame generation, ${report.summary.notWorth} não`];
  lines.push(`calibração: ${report.calibration.unitsPerSecond} un/s (${report.calibration.deviceFile})`);
  for (const c of report.cells) lines.push(`  [${c.verdict === 'vale' ? 'VALE    ' : 'NÃO VALE'}] célula ${c.cell.join(',')} — ${c.savingMs >= 0 ? '+' : ''}${c.savingMs} ms, latência +${c.addedLatencyMs} ms, reprojeção ${c.presentCostPerFrameMs} ms, view-model ${c.viewModelCostPerFrameMs} ms`);
  lines.push(`  → ${report.headline}`);
  process.stdout.write(lines.join('\n') + '\n');
  process.stdout.write(`gravado em ${out}\n`);
  process.exit(report.summary.worth > 0 ? 0 : 5);
}

die(`uso:\n  node packages/cli/run.js measure [--iterations N] [--grid G] [--out device.json]\n  node packages/cli/run.js plan --scene cena.json [--device device.json] [--out plan.json]\n  node packages/cli/run.js present --plan plan.json --scene cena.json --device device.json [--sim-hz 15] [--disp-hz 30] [--out present.json]\n\nmedir antes de planejar: sem device.json o plano usa um chute de engenharia declarado (unitsPerSecond=3000).`);
