import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import { World } from '../src/ues/world.ts';
import { GraphicsSystem, NullBackend, RealLife, TextBackend } from '../src/ues/graphics.ts';

function setup(): { w: World; g: GraphicsSystem; rl: RealLife } {
  const w = new World({ seed: 33, gridDim: 8, chunkSize: 8 }, undefined, new Rng(33));
  w.setFocus(24, 24);
  w.stream();
  const rl = new RealLife();
  const g = new GraphicsSystem({ world: w, realLife: rl, backend: new NullBackend() });
  return { w, g, rl };
}

test('iluminação: derivada do ciclo dia/noite (não hardcoded)', () => {
  const { w, g } = setup();
  const env = w.rrw.get(w.env.id)!;
  // meio-dia (pico do sol: t=0.75 no modelo)
  env.data.timeOfDay = 0.75;
  env.data.weather = 'clear';
  const day = g.run({ dt: 0.1, time: 10 })!;
  assert.ok(day.lighting.intensity > 0.8, `dia claro: intensidade ${day.lighting.intensity}`);
  assert.ok(day.lighting.colorTempK > 5500);
  assert.equal(day.lighting.night, false);
  // noite
  env.data.timeOfDay = 0.25;
  const night = g.run({ dt: 0.1, time: 11 })!;
  assert.ok(night.lighting.intensity < 0.1);
  assert.equal(night.lighting.night, true);
  assert.ok(night.lighting.colorTempK < 3500);
});

test('iluminação: tempestade reduz intensidade (fenômeno coerente)', () => {
  const { w, g } = setup();
  const env = w.rrw.get(w.env.id)!;
  env.data.timeOfDay = 0.75;
  env.data.weather = 'clear';
  const clear = g.run({ dt: 0.1, time: 10 })!;
  env.data.weather = 'storm';
  const storm = g.run({ dt: 0.1, time: 11 })!;
  assert.ok(storm.lighting.intensity < clear.lighting.intensity, 'tempestade escurece o dia');
  assert.ok(storm.atmosphere.stormGlow >= 0);
});

test('Real Life: chuva → superfícies molhadas (especularidade) + decaimento', () => {
  const rl = new RealLife();
  const env = { weather: 'rain', wind: 0.2, humidity: 0.8, timeOfDay: 0.7 };
  for (let i = 0; i < 20; i++) rl.update(env, 0.5);
  assert.ok(rl.state.wetness > 0.5, `chuva molha (wetness=${rl.state.wetness.toFixed(2)})`);
  // sol: seca
  for (let i = 0; i < 40; i++) rl.update({ weather: 'clear', wind: 0.2, humidity: 0.5, timeOfDay: 0.7 }, 0.5);
  assert.ok(rl.state.wetness < 0.2, 'secou');
  // vento + seca → poeira
  for (let i = 0; i < 30; i++) rl.update({ weather: 'clear', wind: 0.9, humidity: 0.3, timeOfDay: 0.7 }, 0.5);
  assert.ok(rl.state.dust > 0.3, `vento+seca levanta poeira (dust=${rl.state.dust.toFixed(2)})`);
});

test('frame: LOD por distância ao foco + agregados', () => {
  const { w, g } = setup();
  // entidade próxima vs distante
  const near = w.rrw.create({ name: 'perto', categories: ['entity'], components: { Position: { x: 24, y: 24 } }, detail: 1 });
  const far = w.rrw.create({ name: 'longe', categories: ['entity'], components: { Position: { x: 50, y: 50 } }, detail: 1 });
  w.rrw.create({ name: 'vila-agregada', categories: ['society/group'], components: { Position: { x: 26, y: 26 } }, detail: 0.2 });
  const frame = g.run({ dt: 0.1, time: 10 })!;
  const en = frame.entities.find((e) => e.id === near.id)!;
  const ef = frame.entities.find((e) => e.id === far.id)!;
  const ev = frame.entities.find((e) => e.name === 'vila-agregada' || e.id === 'vila-agregada') ?? frame.entities.find((e) => e.kind === 'society/group');
  assert.equal(en.lod, 3);
  assert.ok(ef.lod <= 1, `distante: lod ${ef.lod}`);
  assert.ok(ev, 'agregado aparece como marcador');
  assert.equal(ev?.lod, 0);
});

test('frame: sombras derivam de oclusores materializados + sol', () => {
  const { w, g } = setup();
  const env = w.rrw.get(w.env.id)!;
  env.data.timeOfDay = 0.75;
  env.data.weather = 'clear';
  // árvore próxima do foco
  w.rrw.create({ name: 'tree', categories: ['terrain/resource'], components: { Position: { x: 25, y: 25 }, Material: { base: 'tree', color: '#2e6b2e', flammable: true, roughness: 0.9, specular: 0.05 } }, data: { kind: 'tree' }, detail: 1 });
  const frame = g.run({ dt: 0.1, time: 10 })!;
  assert.equal(frame.shadows.enabled, true);
  assert.ok(frame.shadows.occluders >= 1);
  // à noite: sem sombras de sol
  env.data.timeOfDay = 0.25;
  const night = g.run({ dt: 0.1, time: 11 })!;
  assert.equal(night.shadows.enabled, false);
});

test('backends: Null contabiliza; Text renderiza ASCII com entidades', () => {
  const w = new World({ seed: 44, gridDim: 8, chunkSize: 8 }, undefined, new Rng(44));
  w.setFocus(24, 24);
  w.stream();
  const gNull = new GraphicsSystem({ world: w, backend: new NullBackend() });
  const fNull = gNull.run({ dt: 0.1, time: 10 })!;
  assert.ok(fNull.drawCalls >= 1);
  assert.equal(fNull.backend, 'null');

  const gText = new GraphicsSystem({ world: w, backend: new TextBackend() });
  // NPC visível
  w.rrw.create({ name: 'npc-teste', categories: ['organism/human', 'entity'], components: { Position: { x: 24, y: 24 } }, detail: 1 });
  const fText = gText.run({ dt: 0.1, time: 11 })!;
  const stats = (gText as never as { backend: TextBackend }).backend.render(fText, w);
  assert.ok(stats.output?.includes('N'), 'NPC renderizado como N no ASCII');
  assert.ok(stats.output?.includes('frame='), 'cabeçalho com métricas');
  // terreno no ASCII
  assert.ok(stats.output?.includes('~') || stats.output?.includes('^') || stats.output?.includes('"'));
});

test('frame reflete estado (não é estático): chuva muda materiais', () => {
  const { w, g } = setup();
  const env = w.rrw.get(w.env.id)!;
  env.data.weather = 'clear';
  for (let i = 0; i < 10; i++) g.run({ dt: 0.5, time: 10 + i });
  const dry = g.run({ dt: 0.1, time: 20 })!;
  env.data.weather = 'rain';
  for (let i = 0; i < 10; i++) g.run({ dt: 0.5, time: 21 + i });
  const wet = g.run({ dt: 0.1, time: 30 })!;
  assert.ok(wet.materials.wetness > dry.materials.wetness, 'chuva aumentou wetness no frame');
});
