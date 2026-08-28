#!/usr/bin/env node
// UTS :: demos/genesis — THE BIRTH: every native system alive at once.
// RHI/culling/shadows/instancing/materials/lighting/streaming/physics/audio
// (WAV rendered by OUR synth) / UTS-DB persistence / comm — all UTS-native.

import { createUTS, createPlatform, AudioDirector, encodeWav, MemoryDevice, UTSDB, MemoryJournal } from '../src/index.js';
import { NullRenderer, TextRenderer } from '../src/index.js';
import { mkdir, writeFile } from 'node:fs/promises';

console.log('\n=== UTS/UES GÊNESIS — todas as definições dos PROMPTS, nativas ===\n');

// ---- UTS-DB: OUR database backs the platform
const db = new UTSDB({ journal: new MemoryJournal(), name: 'genesis' });
await db.open();
const platform = createPlatform({ storage: db.asStorage('platform') });
const uts = createUTS({ seed: 'genesis', platform });
const { world, ues: engine, core, rrw } = uts;

console.log('[boot] serviços:', platform.services.list().map(s => s.name).join(', '));

// ---- world born through the AI-first interface
const report = await platform.comm.request('ask', { objective: 'criar uma pequena vila próxima a um rio chamada Gênesis' });
console.log(`[comm] ask() via Comm: intent=${report.interpretation.intent} ok=${report.ok}`);

// ---- fire near the village: causal chain + OUR lights + shadows + audio
const villagePos = rrw.getComponent(rrw.query({ kind: 'settlement' })[0], 'spatial').pos;
engine.moveCamera([villagePos[0] + 40, 26, villagePos[2] + 40]);
world.reallife.igniteChance = 1.0;
world.strikeLightning([villagePos[0] + 8, 0, villagePos[2] + 8]);
console.log('[reallife] raio → fogo; luz pontual derivada do RRW:', JSON.stringify(world.lighting.collect(world, engine.camera.pos, engine.do15.strategy).stats));

// ---- OUR physics: rocks fall, collide, impact events cite their cause
const rock1 = world.dropRock([villagePos[0] + 10, 26, villagePos[2] + 10], [1.5, 0, 0], { causeEvent: world.environment.lastWeatherEventId });
const rock2 = world.dropRock([villagePos[0] + 11.5, 26, villagePos[2] + 10], [-1.5, 0, 0], { causeEvent: world.environment.lastWeatherEventId });
engine.run(160);
console.log('[physics]', JSON.stringify(world.physics.report()));
const impact = [...rrw.events.values()].find(e => e.type === 'physics.impact');
if (impact) console.log('[physics] cadeia do impacto:', JSON.stringify(rrw.verifyCausalChain(impact.id)), 'profundidade', rrw.causalityChain(impact.id).length);

// ---- raycast (OUR physics query API)
const hit = world.physics.raycast([villagePos[0], 30, villagePos[2]], [0, -1, 0], 100);
console.log('[physics] raycast down:', hit ? `${hit.kind} @ ${hit.dist.toFixed(1)}m` : 'miss');

// ---- OUR streaming + frame
engine.run(20);
const frame = engine.renderFrame();
console.log('[streaming]', JSON.stringify(frame.stats.streaming));
console.log('[lod] malha:', frame.stats.terrain.meshes, '· impostores:', frame.stats.terrain.impostors, '· limiar D-O15:', uts.do15.strategy.terrainImpostorAfter, 'u');
console.log('[frame] patches:', frame.stats.patches, 'entidades:', frame.stats.entities, 'lights:', JSON.stringify(frame.lights.stats));

// ---- renderer backends manifest the SAME frame
const nullR = new NullRenderer();
nullR.render(frame);
console.log('[render:null]', JSON.stringify(nullR.stats));
console.log('\n' + new TextRenderer({ cols: 72, rows: 16 }).render(frame).split('\n').slice(0, 12).join('\n'));

// ---- OUR audio: synthesize the frame into a WAV (no external library)
const audio = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
const rendered = audio.renderFrameAudio(frame, { seconds: 2.5 });
const wav = encodeWav(rendered);
await mkdir('demos/out', { recursive: true });
await writeFile('demos/out/genesis.wav', wav);
console.log(`[audio] ${rendered.voices} vozes @${rendered.sr}Hz -> demos/out/genesis.wav (${(wav.length / 1024).toFixed(0)}KB)`);
const peak = Math.max(...rendered.left.slice(0, 2000).map(Math.abs));
console.log('[audio] energia presente:', peak > 0.001 ? 'sim' : 'NÃO (falha!)');

// ---- OUR live audio stream: continuous timeline -> device (real-time path)
const liveDev = new MemoryDevice().open({ sr: uts.do15.strategy.audioSr });
audio.openStream({ seed: 'uts-genesis' });
let seamJump = 0, prevLast = null;
for (let i = 0; i < 20; i++) { // 2.0s contínuos em chunks de 0.1s
  const chunk = audio.pumpStream(frame, { seconds: 0.1, device: liveDev });
  if (prevLast != null) seamJump = Math.max(seamJump, Math.abs(chunk.left[0] - prevLast));
  prevLast = chunk.left[chunk.left.length - 1];
}
const live = liveDev.concat();
const liveWav = encodeWav(live);
await writeFile('demos/out/genesis-live.wav', liveWav);
console.log(`[audio-stream] 20 chunks contínuos -> demos/out/genesis-live.wav (${(liveWav.length / 1024).toFixed(0)}KB) · pior emenda |Δ|=${seamJump.toFixed(4)} (clique se >0.1) · vozes=${audio.stream.stats.voices}`);

// ---- D-O15 adaptation visible
for (let i = 0; i < 6; i++) engine.do15.report({ frameMs: 30, simMs: 30, tick: engine.world.clock.tick });
console.log('[D-O15] sob pressão:', JSON.stringify({ radius: engine.do15.strategy.materializationRadius, perception: engine.do15.strategy.perceptionResolution, shadows: engine.do15.strategy.shadows }));
for (let i = 0; i < 10; i++) engine.do15.report({ frameMs: 1, simMs: 1, tick: engine.world.clock.tick });
console.log('[D-O15] relaxado:', JSON.stringify({ radius: engine.do15.strategy.materializationRadius, perception: engine.do15.strategy.perceptionResolution }));

// ---- persistence on OUR database + compact
const { save } = await import('../src/persistence/snapshot.js');
await save(platform.storage, 'genesis-slot', uts);
await db.compact();
console.log('[uts-db]', JSON.stringify(db.report()));

// ---- the frame survives tese audit: every D with observable effect
const withoutEffect = uts.tese.list().map(l => l.id).filter(id => !uts.tese.effect(id));
console.log('[tese] camadas sem efeito observado nesta cena:', withoutEffect.length ? withoutEffect.join(',') : '(nenhuma)');
console.log('\n=== GÊNESIS COMPLETO: a realidade representada é a única verdade ===\n');
