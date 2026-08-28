#!/usr/bin/env node
// UTS :: demos/platform — the UTS PLATFORM demo (UTS = plataforma · UES = engine).
// Shows the AI-first interface, platform apps, multi-model research,
// connected services and durable creation projects.

import { createUTS, createPlatform } from '../src/index.js';
import { TextRenderer } from '../src/index.js';

console.log('\n=== UTS PLATFORM :: plataforma geral (UES = engine dentro dela) ===\n');

// ---- 1) boot the platform and a system; the engine registers as a CONSUMER
const platform = createPlatform();
const uts = createUTS({ seed: 'uts-platform-demo', platform });
const status = await platform.status();
console.log('[1] serviços da plataforma:', status.services.map(s => s.name).join(', '));

// ---- 2) AI-first: the user just says what they want
console.log('\n[2] AI-first (o usuário descreve; a plataforma executa e verifica):');
const report = await platform.ask('criar uma pequena vila próxima a um rio chamada Aurora');
console.log(`    ask() -> intent=${report.interpretation.intent} ok=${report.ok} (${report.chosen.provider}/${report.chosen.model})`);

// ---- 3) platform APPS (nem tudo é um mundo — apps são cidadãos de primeira classe)
console.log('\n[3] apps da plataforma:');
const app = await platform.apps.install({ kind: 'tasks', name: 'Roadmap UTS' });
await platform.apps.act(app.id, 'add', { text: 'dominar a representação da realidade' });
await platform.apps.act(app.id, 'add', { text: 'engine que cria jogos AAA' });
await platform.apps.act(app.id, 'toggle', { id: 1 });
console.log('   ', JSON.stringify(platform.apps.view(app.id)));

// ---- 4) research: validação por triangulação entre modelos
console.log('\n[4] research (triangulação multi-modelo):');
platform.research.setProviders([
  { name: 'modelo-1', capabilities: () => ({ structured: true }), generate: async () => ({ json: { answer: 'o sol é uma estrela', confidence: 0.9 } }) },
  { name: 'modelo-2', capabilities: () => ({ structured: true }), generate: async () => ({ json: { answer: 'o Sol é uma estrela!', confidence: 0.8 } }) },
  { name: 'modelo-3', capabilities: () => ({ structured: true }), generate: async () => ({ json: { answer: 'planeta gasoso', confidence: 0.4 } }) },
]);
const verdict = await platform.research.validate('o que é o sol?');
console.log(`    consenso="${verdict.consensus}" acordo=${(verdict.agreement * 100).toFixed(0)}% triangulado=${verdict.triangulated} conflitos=${verdict.conflicts.length}`);

// ---- 5) durable creation project (dias/semanas — resumível em qualquer sessão)
console.log('\n[5] creation project (execução longa, durável, retomável):');
const project = await platform.projects.create('criar uma pequena vila próxima a um rio chamada Metrópole');
const r1 = await platform.projects.run(project.id, { maxSteps: 2 });
console.log(`    budget 2 passos -> ${r1.steps} executados (${r1.summary.join(' | ')})`);
const r2 = await platform.projects.run(project.id, {});
console.log(`    retomada -> concluído=${r2.progress.done_all} (${r2.steps} passos)`);
console.log(`    mundo: NPCs=${uts.rrw.count('npc')} settlements=${uts.rrw.count('settlement')}`);

// ---- 6) the UES engine inside the platform: experiences of any kind
console.log('\n[6] UES (engine): experiências declaradas por manifesto');
const { defineExperience, bootExperience } = await import('../src/ues/experience.js');
const exp = defineExperience({
  name: 'Vale dos Ventos',
  world: { settlements: [{ name: 'Vento Leste', pop: 40, nearRiver: true }], weather: 'windy' },
  ruleset: { trade: true },
});
const boot = await bootExperience(uts, exp);
uts.ues.run(200);
const frame = uts.ues.renderFrame();
const ascii = new TextRenderer({ cols: 72, rows: 18 }).render(frame);
console.log(ascii.split('\n').slice(0, 10).join('\n'));
console.log(`    experiência "${exp.name}" viva: patches=${frame.stats.patches} entidades=${frame.entities.length}`);

console.log('\n=== a plataforma continua de pé: ask(), apps, research, projects ===\n');
