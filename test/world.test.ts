import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import { World, fbm, valueNoise } from '../src/ues/world.ts';

function makeWorld(seed = 42): World {
  return new World({ seed, gridDim: 8, chunkSize: 8, activeRadiusChunks: 1, outerRadiusChunks: 2, maxLoadedChunks: 25 }, undefined, new Rng(seed));
}

test('terreno: determinístico por seed (mesma seed → mesmo mundo)', () => {
  const w1 = makeWorld(99);
  const w2 = makeWorld(99);
  const w3 = makeWorld(100);
  const pts = [
    [3, 4],
    [20, 11],
    [45, 40],
    [55.5, 12.2],
  ];
  for (const [x, y] of pts) {
    assert.ok(Math.abs(w1.heightAt(x, y) - w2.heightAt(x, y)) < 1e-12);
  }
  const diffs = pts.filter(([x, y]) => Math.abs(w1.heightAt(x, y) - w3.heightAt(x, y)) > 1e-6).length;
  assert.ok(diffs >= 3, 'seeds diferentes devem produzir terrenos diferentes');
  // ruído em [0,1)
  for (let i = 0; i < 50; i++) {
    assert.ok(valueNoise(i * 0.7, i * 1.3, 5) >= 0 && valueNoise(i * 0.7, i * 1.3, 5) < 1);
  }
  assert.ok(fbm(1.1, 2.2, 3, 4) >= 0 && fbm(1.1, 2.2, 3, 4) < 1);
});

test('streaming: load/unload com preservação de estado (D-3 ⇄ D-1)', () => {
  const w = makeWorld();
  w.setFocus(8, 8);
  const r1 = w.stream();
  assert.ok(r1.loaded >= 1);
  const near = w.chunkAt(1, 1);
  assert.equal(near.loaded, true);
  assert.ok(near.height);
  const ctxId = near.state['contextId'] as string;
  // o contexto existe e os recursos pertencem a ele
  assert.ok(w.rrw.get(ctxId)?.alive);
  const resCount = w.rrw.within(ctxId).length;
  assert.ok(resCount >= 1, 'chunk tem recursos no contexto');
  // entidades do chunk materializadas
  const matCount = w.rrw.within(ctxId).filter((e) => e.detail >= 0.5).length;
  assert.ok(matCount >= 1);

  // foco se afasta → unload: estado preservado
  w.setFocus(56, 56);
  const r2 = w.stream();
  assert.ok(r2.unloaded >= 1);
  assert.equal(near.loaded, false);
  assert.equal(near.height, null);
  // MAS o estado semântico continua lá (regra: abstração não apaga)
  const still = w.rrw.within(ctxId);
  assert.equal(still.length, resCount, 'mesmo conjunto de entidades após unload');
  const first = still[0];
  assert.equal(first.detail, 0); // abstrato
  assert.ok(first.data.kind, 'data semântica preservada');
  // posição preservada no snapshot comprimido (acessível via world.positionOf)
  assert.ok(w.positionOf(first.id), 'posição preservada (compress)');
  const posSnap = w.rrw.get(first.id)?.compressed?.get('Position');
  assert.ok(posSnap && isFinite((posSnap as { x: number }).x), 'snapshot Position existe');

  // foco volta → reload materializa de volta (mesmos ids)
  w.setFocus(8, 8);
  w.stream();
  assert.equal(near.loaded, true);
  const again = w.rrw.within(ctxId);
  assert.equal(again.length, resCount);
  const first2 = again.find((e) => e.id === first.id)!;
  assert.ok(first2.detail >= 0.5);
  assert.equal(first2.data.kind, first.data.kind);
});

test('streaming: cache LRU limita chunks carregados', () => {
  const w = makeWorld();
  w.setFocus(8, 8);
  w.stream();
  for (let i = 0; i < 30; i++) {
    w.setFocus(((i * 13) % 60) + 4, ((i * 7) % 60) + 4);
    w.stream();
  }
  assert.ok(w.loadedChunkCount() <= w.cfg.maxLoadedChunks);
});

test('camadas semânticas: abertas (novas camadas entram em runtime)', () => {
  const w = makeWorld();
  const base = w.layerIds();
  for (const l of ['terrain', 'heightfield', 'biome', 'slope', 'environment', 'resources', 'entities']) {
    assert.ok(base.includes(l), `camada de exemplo ausente: ${l}`);
  }
  // novo aspecto da realidade: camada 'magic/ley-lines'
  w.addLayer({
    id: 'magic/ley-lines',
    name: 'Ley Lines',
    description: 'Linhas de energia mágica (exemplo de extensão aberta).',
    sample: (ww, x, y) => ({ active: valueNoise(x * 0.05, y * 0.05, ww.cfg.seed + 999) > 0.8 }),
  });
  const sample = w.sampleLayers(10, 10);
  assert.ok(sample['magic/ley-lines'], 'nova camada aparece no sample');
  assert.ok(sample['biome']);
  assert.equal(typeof (sample['magic/ley-lines'] as { active: boolean }).active, 'boolean');
});

test('biomas: zona criada pela IA tem prioridade sobre o ruído', () => {
  const w = makeWorld();
  w.createBiome('desert', 30, 30);
  assert.equal(w.biomeAt(30, 30), 'desert');
  assert.equal(w.biomeAt(32, 31), 'desert'); // dentro do raio
  // longe da zona, volta a ser classificado por ruído
  const far = w.biomeAt(2, 2);
  assert.ok(['water', 'coastal', 'desert', 'plains', 'forest', 'mountain', 'snow'].includes(far));
});

test('ambiente: cadeia causal tempestade → raio → fogo', () => {
  const w = makeWorld(1234);
  w.setFocus(24, 24);
  w.stream();
  const env = w.rrw.get(w.env.id)!;
  // força tempestade (determinístico para o teste)
  env.data.weather = 'storm';
  env.data.stormSince = 0;
  env.data.humidity = 0.9;
  w.rrw.emit('weather.storm.begins', [env.id], { from: 'clear', to: 'storm' });
  // avança clima até ocorrer um raio (seed fixa → reproduzível)
  let fired = false;
  for (let i = 0; i < 500 && !fired; i++) {
    w.rrw.time += 0.1;
    w.rrw.stepProcess('env.weather', { dt: 0.1, time: w.rrw.time, rng: w.rng, rrw: w.rrw });
    fired = w.rrw.query({ categories: ['phenomenon/fire'] }).length > 0;
  }
  assert.ok(fired, 'tempestade deveria ter gerado um raio/fogo (seed 1234)');
  const fire = w.rrw.query({ categories: ['phenomenon/fire'] })[0];
  const fires = w.rrw.eventsOf(fire.id).filter((e) => e.type === 'fire.starts');
  assert.equal(fires.length, 1);
  assert.equal(fires[0].cause?.event, 'weather.lightning');
  // origem registrada (spawnedBy)
  assert.equal(fire.spawnedBy?.event, 'weather.lightning');
  // o alvo do raio perdeu combustível
  const source = w.rrw.get(fire.data.source as string);
  assert.equal(source?.data.fuel, 0);
});

test('invariants: mundo coerente após operação mista', () => {
  const w = makeWorld(5);
  w.setFocus(24, 24);
  w.stream();
  w.spawnStructure('market', 24, 24);
  w.spawnStructure('house', 26, 24);
  const inv = w.checkInvariants();
  assert.equal(inv.ok, true, inv.issues.join('; '));
});

test('WorldAdapter: createBiome + buildStructures + spawnNpcs (via IA)', () => {
  const w = makeWorld();
  w.setFocus(20, 20);
  w.stream();
  const b = w.createBiome('forest', 20, 20);
  assert.equal(b.ok, true);
  const s = w.buildStructures(['market', 'house', 'temple'], 20, 20);
  assert.equal(s.count, 3);
  assert.equal(w.rrw.query({ categories: ['structure'] }).length, 3);
  // spawnNpcs sem factory registrado → 0 (comportamento definido, sem crash)
  const n = w.spawnNpcs(4, 20, 20);
  assert.equal(n.count, 0);
  assert.equal(w.worldExists(), true);
  const desc = w.describe();
  assert.equal(desc['structures'], 3);
});
