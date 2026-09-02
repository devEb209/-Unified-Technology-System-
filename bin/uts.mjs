#!/usr/bin/env node
// Entrada única do GEN-1. Existe porque `npm run <script>` é a parte frágil do
// fluxo num aparelho fraco (npm quebrado, prefix esquisito, cache cheio), e
// porque o --experimental-strip-types só é necessário em Node 22.x: em 23.6+ o
// type-stripping é nativo e silencioso. Detectar aqui poupa o usuário de lembrar
// flag — e o impede de rodar benchmark com flag errada e comparar nada com nada.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const [major, minor] = process.versions.node.split('.').map(Number);

if (major < 22 || (major === 22 && minor < 6)) {
  process.stderr.write(
    `uts: Node ${process.versions.node} não serve.\n` +
    `     precisa de >= 22.6 para executar TypeScript sem build.\n` +
    `     Termux: pkg install nodejs-lts  (ou pkg install nodejs)\n`,
  );
  process.exit(78);
}

const flags = major === 22 ? ['--disable-warning=ExperimentalWarning', '--experimental-strip-types'] : ['--disable-warning=ExperimentalWarning'];
const args = process.argv.slice(2);
const cmd = args[0];

const targets = {
  measure: { file: 'packages/cli/run.js', rest: ['measure'] },
  plan: { file: 'packages/cli/run.js', rest: ['plan'] },
  present: { file: 'packages/cli/run.js', rest: ['present'] },
  demo: { file: 'packages/cli/run.js', rest: ['demo'] },
  validate: { eval: "import('./packages/d-system/src/ladders.ts').then(m=>{const e=m.validateAll();console.log(e.length?JSON.stringify(e,null,2):'escadas válidas');process.exit(e.length?1:0)})" },
  test: { testDir: 'packages' },
};

if (!cmd || cmd === 'help' || cmd === '--help' || !targets[cmd]) {
  process.stdout.write(
    `uso: node bin/uts.mjs <comando> [args]\n\n` +
    `  measure --out device.json     calibra unidades de custo NESTE aparelho (CPU)\n` +
    `  plan --scene c.json [--device device.json] [--out plan.json]\n` +
    `  present --sim-hz 15 --disp-hz 60   o que a interpolação de apresentação compra e custa\n` +
    `  demo [--port 8080] [--grid 24]  materialização visível: os 6 Ds + Qp medido + veredito de FG\n` +
    `  validate                       escadas válidas?\n` +
    `  test                           suíte completa\n` +
    (cmd && !targets[cmd] ? `\ncomando desconhecido: ${cmd}\n` : ''),
  );
  process.exit(cmd && !targets[cmd] ? 64 : 0);
}

const t = targets[cmd];
if (!existsSync(join(root, t.file ?? 'bin/uts.mjs'))) {
  process.stderr.write(
    [
      `uts: este diretório não é o branch do kernel (falta ${t.file}).`,
      '     provável causa: clone antigo do main, que nunca teve packages/. Rode:',
      '       git fetch origin',
      '       git checkout -B gen arena/01a05f95-unified-technology-system',
      '       git reset --hard origin/arena/01a05f95-unified-technology-system',
      '     se der "not our ref", o remoto não é este repo: git remote set-url origin https://github.com/devEb209/-Unified-Technology-System-.git',
    ].join('\n') + '\n',
  );
  process.exit(66);
}

const child = t.eval
  ? spawn(process.execPath, [...flags, '-e', t.eval], { stdio: 'inherit', cwd: root })
  : t.testDir
    ? (() => {
        // O pai expande o glob e o filho recebe ARGUMENTOS, não string de shell: o
        // padrão antigo (shell: true + args) gerava DeprecationWarning DEP0190 no
        // Node 26 do aparelho e ainda por cima engolia um spawn — 15 s de suíte
        // começando com um processo a mais. Sem shell, sem aviso, sem susto.
        const found = spawnSync('sh', ['-c', `ls ${join(root, 'packages', '*', 'test', '*.test.ts').replace(/'/g, "")}`], { encoding: 'utf8' });
        const files = (found.stdout || '').trim().split('\n').filter((f) => f.endsWith('.ts'));
        if (files.length === 0) {
          process.stderr.write('uts: nenhum teste encontrado em packages/*/test — checkout certo?\n');
          process.exit(66);
        }
        return spawn(process.execPath, [...flags, '--test', ...files], { stdio: 'inherit', cwd: root });
      })()
    : (() => {
        const file = join(root, t.file);
        if (!existsSync(file)) {
          process.stderr.write(`uts: ${t.file} não existe. Você está no branch certo?  git status -sb\n`);
          process.exit(66);
        }
        return spawn(process.execPath, [...flags, file, ...t.rest, ...args.slice(1)], { stdio: 'inherit', cwd: root });
      })();

child.on('exit', (code, signal) => process.exit(signal ? 128 : (code ?? 1)));
