// R22 — A GENTE COME DA TEIA + O SELO: a VILA pesca o cardume e caça o
// veado que a cadeia produziu (chuva→capim→veado→GENTE; tier abstrato e
// materializado), a rede e a flecha COBRAM do banco (pesca predatória
// colapsa o cardume e a comida SOME), a CORRENTEZA ganha física de
// acumulador (o campo anda na velocidade real do vento, sem teleporte) e
// todo artefato do build sai com SELO sha256 (o pacote que chega é o
// pacote que saiu — adulteração é DETECTADA).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { teiaPass, createSettlement } from '../src/world/society.js';
import { build, verifySelo } from '../src/agent/build-system.js';

test('r22: A TEIA ALIMENTA A GENTE — a vila pesca o cardume, caça o veado, e o banco PAGA a conta', () => {
  const uts = createUTS({ seed: 'teia-gente' });
  const w = uts.world;
  w.ues.run(2);
  // DUAS vilas no MESMO mundo: Porto com o banquete na célula, Sertão no deserto
  const v = createSettlement(w, { name: 'Porto', pos: [512, 0, 512] }).id;     // célula 8,8
  const c = createSettlement(w, { name: 'Sertão', pos: [1280, 0, 1280] }).id;  // célula 20,20
  const eco = w.ecology;
  eco.fishField.set('8,8', 0.5);
  eco.deerField.set('8,8', 0.4);
  const fv0 = w.rrw.getComponent(v, 'settlement').store.food;
  const fc0 = w.rrw.getComponent(c, 'settlement').store.food;
  let last = null, sawGame = 0, sawFish = 0;
  for (let i = 0; i < 400; i++) {
    last = teiaPass(w, v, 0.05); teiaPass(w, c, 0.05);
    sawGame = Math.max(sawGame, last.game); sawFish = Math.max(sawFish, last.fish);
  }
  const dv = w.rrw.getComponent(v, 'settlement').store.food - fv0;
  const dc = w.rrw.getComponent(c, 'settlement').store.food - fc0;
  assert.ok(dv > dc + 0.5, `Porto comeu da teia (+${dv.toFixed(2)}) e o Sertão não (+${dc.toFixed(2)})`);
  assert.ok(sawFish > 0 && sawGame > 0, `pesca E caça renderam ao longo do tempo (peixe ${sawFish.toFixed(3)}, carne ${sawGame.toFixed(3)})`);
  assert.ok(eco.fishField.get('8,8') < 0.5, 'a rede COBROU peixe do banco');
  assert.ok(eco.deerField.get('8,8') < 0.4, 'a flecha COBROU veado do rebanho');
  assert.ok(w.rrw.getComponent(v, 'settlement').teia.fishCaught > 0, 'o acumulador é honesto');
});

test('r22: PESCA PREDATÓRIA — martelar o banco Mata o cardume e a comida SOME (consequência real)', () => {
  const uts = createUTS({ seed: 'predatoria' });
  const w = uts.world;
  w.ues.run(2);
  const v = createSettlement(w, { name: 'Redinha', pos: [512, 0, 512] }).id;
  const eco = w.ecology;
  eco.fishField.set('8,8', 0.5);
  eco.deerField.set('8,8', 0.4);
  let out = null;
  for (let i = 0; i < 4000; i++) out = teiaPass(w, v, 0.05);
  assert.ok((eco.fishField.get('8,8') ?? 0) < 0.02, 'o cardume acabou');
  assert.equal(out.fish, 0, 'a pesca PARA de render (não há peixe mágico)');
  assert.equal(out.game, 0, 'a caça também parou (o rebanho foi)');
  // o rebanho volta quando a natureza se recupera (imigração da teia)
  for (let i = 0; i < 8000; i++) eco.step(0.5, { sunEl: 1, soilWet: 0.6 });
  const deerBack = [...eco.deerField.values()].reduce((a, b) => a + b, 0);
  assert.ok(deerBack > 0.05, `o veado voltou quando o mato cresceu (${deerBack.toFixed(2)})`);
});

test('r22: A CORRENTEZA TEM VELOCIDADE REAL — vento calmo NÃO teleporta o banco; vento forte leva', () => {
  const eco = createUTS({ seed: 'correnteza-r22' }).world.ecology;
  eco.planktonField.set('8,8', 0.9);
  eco.fishField.set('8,8', 0.5);
  eco.world.environment.wind = 0.2;
  for (let i = 0; i < 600; i++) eco.step(0.05, { sunEl: 1, seaSilt: 0.05 }); // 30s de brisa
  const near = [...eco.planktonField.keys()].every((k) => { const [i, j] = k.split(',').map(Number); return i < 12 && j < 12; });
  assert.ok(near, '30s de brisa NÃO espalham o banco pela grade (física, não teleporte)');
  const eco2 = createUTS({ seed: 'correnteza-r22b' }).world.ecology;
  eco2.planktonField.set('8,8', 0.9);
  eco2.world.environment.wind = 1;
  for (let i = 0; i < 2400; i++) eco2.step(0.05, { sunEl: 1, seaSilt: 0.05 }); // 120s de vento
  const maxI = Math.max(...[...eco2.planktonField.keys()].map((k) => +k.split(',')[0]));
  assert.ok(maxI > 14, `o vento forte LEVOU o bloom para leste (chegou a i=${maxI})`);
  // o cardume viajou JUNTO (a escola segue a comida)
  assert.ok(eco2.fishField.size > 0, 'o cardume sobreviveu viajando com o banco');
});

test('r22: O SELO — todo artefato sai com sha256; adulteração é DETECTADA; exe kit também', async () => {
  const web = await build({ name: 'SeloR22', target: 'web', manifest: { title: 'X' } });
  assert.equal(verifySelo(web.artifact).ok, true, 'o zip web abre com o selo conferindo');
  assert.match(web.artifact.selo.sha256, /^[0-9a-f]{64}$/);
  const bytes = [...web.artifact.data];
  bytes[20] ^= 0xff; // vira UM byte no meio
  const mentiroso = { ...web.artifact, data: new Uint8Array(bytes) };
  assert.equal(verifySelo(mentiroso).ok, false, 'UM byte alterado QUEBRA o selo');
  const kit = await build({ name: 'SeloR22', target: 'android', manifest: {} });
  assert.equal(verifySelo(kit.artifact).ok, true, 'o kit android também sai selado');
  assert.equal(verifySelo({ data: web.artifact.data }).ok, false, 'sem selo não passa (honesto)');
});
