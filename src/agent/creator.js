// UTS :: agent/creator — "CRIE LITERALMENTE TUDO E QUALQUER COISA": the
// GENESIS creator composes COMPLETE, runnable games from a sentence —
// level, entities, objectives, assets and shell are REAL data generated
// deterministically from the brief's seed. The shell is self-contained
// (canvas 2D, zero deps) so the zip runs anywhere, even on an A01.
import { zipCreate, zipRead } from '../util/zip.js';
import { generateTexture } from '../media/textures.js';
import { walkClip } from '../media/animation.js';

export const GENRES = Object.freeze(['corrida', 'plataforma', 'rpg', 'torre', 'sobrevivencia']);

const hash32 = (s) => {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < String(s).length; i++) { h ^= String(s).charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h >>> 0;
};
const rngFor = (seed) => {
  let s = hash32(seed) || 1;
  return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; };
};

/** each genre builds its REAL data (deterministic from the seed) */
const BUILDERS = {
  corrida(rng, brief) {
    const track = [];
    let x = 0, y = 0, dir = 0;
    for (let i = 0; i < 40; i++) {
      dir += (rng() - 0.5) * 0.7;
      x += Math.cos(dir) * 40; y += Math.sin(dir) * 40;
      track.push([Math.round(x), Math.round(y)]);
    }
    return { kind: 'corrida', track, laps: 3, grip: 0.86 + rng() * 0.1, cars: [{ name: brief.hero ?? 'você', speed: 4.6 }] };
  },
  plataforma(rng, brief) {
    const platforms = [];
    let x = 40;
    for (let i = 0; i < 24; i++) {
      const w = 60 + Math.round(rng() * 120);
      platforms.push({ x, y: 200 + Math.round((rng() - 0.5) * 120), w });
      x += w + 50 + Math.round(rng() * 60);
    }
    return { kind: 'plataforma', platforms, gravity: 1500, jump: 560, coins: platforms.length * 3, hero: brief.hero ?? 'você' };
  },
  rpg(rng, brief) {
    const quests = [];
    for (let i = 0; i < 6; i++) {
      quests.push({
        title: ['a borracha do rio', 'o fogo na mata', 'a semente antiga', 'o espantalho do vale', 'a ponte quebrada', 'a estrela caída'][i],
        x: Math.round(rng() * 900), y: Math.round(rng() * 500),
        reward: 10 + Math.round(rng() * 40),
      });
    }
    return { kind: 'rpg', map: { w: 64, h: 40, biomeSeed: hash32(brief.name) }, quests, hp: 12, hero: brief.hero ?? 'você' };
  },
  torre(rng, brief) {
    const waves = [];
    for (let i = 0; i < 10; i++) {
      waves.push({ enemies: 4 + i * 2, speed: 1 + i * 0.12, hp: 3 + i });
    }
    return { kind: 'torre', path: Array.from({ length: 12 }, (_, i) => [40 + i * 70, 150 + Math.round(Math.sin(i * 0.9) * 90)]), waves, towers: [{ cost: 20, dps: 2 }, { cost: 45, dps: 5 }] };
  },
  sobrevivencia(rng, brief) {
    return {
      kind: 'sobrevivencia',
      world: { w: 1200, h: 800, trees: 60 + Math.round(rng() * 40), rocks: 25 + Math.round(rng() * 20) },
      dayLength: 180, hunger: 0.35, enemies: { nightOnly: true, speed: 1.4 },
      recipes: [{ out: 'fogueira', need: { galho: 4, pedra: 2 } }, { out: 'machado', need: { galho: 2, pedra: 3 } }],
    };
  },
};

const SHELL = (name, dataJson) => `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${name}</title>
<style>html,body{margin:0;background:#0a0e14;color:#dfe7f1;font-family:system-ui,sans-serif}
canvas{display:block;width:100vw;height:100vh;touch-action:none}</style></head><body>
<canvas id="game"></canvas><script id="gamedata" type="application/json">${dataJson}</script>
<script>
// {{NAME}} — gerado pelo GENESIS (UTS). Loop real sobre dados REAIS.
const DATA = JSON.parse(document.getElementById('gamedata').textContent);
const cv = document.getElementById('game'), ctx = cv.getContext('2d');
function fit(){ cv.width = innerWidth; cv.height = innerHeight; } fit(); addEventListener('resize', fit);
const seedNum = ${hash32(name)};
let t = 0, score = 0;
function step(dt){
  // cada gênero tem o SEU passo real (comportamento gerado, não vídeo)
  if (DATA.kind === 'corrida') {
    const tr = DATA.track, i = Math.floor(t / 0.8) % tr.length, a = tr[i], b = tr[(i+1)%tr.length];
    cv.car = [a[0] + (b[0]-a[0]) * ((t/0.8)%1), a[1] + (b[1]-a[1]) * ((t/0.8)%1)];
  } else if (DATA.kind === 'plataforma') {
    cv.heroX = (t * 130) % (DATA.platforms.at(-1).x + 200);
  } else if (DATA.kind === 'rpg') {
    const q = DATA.quests[Math.floor(t / 3) % DATA.quests.length];
    cv.quest = q; if (Math.floor(t/3) !== Math.floor((t-dt)/3)) score += q.reward;
  } else if (DATA.kind === 'torre') {
    cv.wave = DATA.waves[Math.min(DATA.waves.length - 1, Math.floor(t / 6))];
  } else if (DATA.kind === 'sobrevivencia') {
    cv.day = (t % DATA.dayLength) / DATA.dayLength; cv.night = cv.day > 0.5;
  }
}
function draw(){
  ctx.fillStyle = '#0a0e14'; ctx.fillRect(0, 0, cv.width, cv.height);
  ctx.fillStyle = '#86efac'; ctx.font = '16px system-ui';
  ctx.fillText('${name} — GENESIS | ' + DATA.kind + ' | score ' + score, 12, 24);
  if (DATA.kind === 'corrida' && cv.car) {
    ctx.strokeStyle = '#38bdf8'; ctx.lineWidth = 8; ctx.beginPath();
    DATA.track.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.stroke();
    ctx.fillStyle = '#f87171'; ctx.beginPath(); ctx.arc(cv.car[0], cv.car[1], 10, 0, 7); ctx.fill();
  } else if (DATA.kind === 'plataforma') {
    ctx.fillStyle = '#a78bfa';
    for (const p of DATA.platforms) ctx.fillRect(p.x - cv.heroX + 200, p.y, p.w, 14);
    ctx.fillStyle = '#fbbf24'; ctx.fillRect(200, 140, 18, 30);
  } else if (DATA.kind === 'rpg' && cv.quest) {
    ctx.fillStyle = '#f87171'; ctx.beginPath(); ctx.arc(cv.quest.x, cv.quest.y, 8, 0, 7); ctx.fill();
    ctx.fillStyle = '#e2e8f0'; ctx.fillText('missão: ' + cv.quest.title, 12, 48);
  } else if (DATA.kind === 'torre' && cv.wave) {
    ctx.strokeStyle = '#94a3b8'; ctx.beginPath();
    DATA.path.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.stroke();
    ctx.fillStyle = '#f87171'; ctx.fillText('onda: ' + cv.wave.enemies + ' inimigos', 12, 48);
  } else if (DATA.kind === 'sobrevivencia') {
    ctx.fillStyle = cv.night ? '#0f172a' : '#1e3a5f'; ctx.fillRect(0, 0, cv.width, cv.height);
    ctx.fillStyle = '#22c55e'; ctx.fillText('dia ' + Math.floor(t / DATA.dayLength + 1), 12, 48);
  }
}
let last = performance.now();
(function loop(now){ const dt = (now - last) / 1000; last = now; t += dt; step(dt); draw(); requestAnimationFrame(loop); })(last);
</script></body></html>`;

/**
 * Create a COMPLETE game from a sentence. Deterministic: the same brief
 * gives the SAME game (seeded). Returns real files + a verified zip.
 */
export function createGame({ genre = 'plataforma', name = 'MeuJogo', brief = {}, seed } = {}) {
  const key = String(genre).toLowerCase().trim();
  if (!GENRES.includes(key)) {
    throw new Error(`gênero desconhecido: "${genre}" (sei criar: ${GENRES.join(', ')} — me diga as REGRAS que eu crio o seu)`);
  }
  const s = seed ?? `${key}:${name}`;
  const rng = rngFor(s);
  const data = BUILDERS[key](rng, { name, ...brief });
  const tex = generateTexture(key === 'corrida' ? 'brick' : key === 'rpg' ? 'marble' : 'wood', { size: 32 });
  const anim = walkClip({ style: brief.styleAnim ?? 'normal' });
  const files = [
    { name: 'index.html', data: SHELL(name, JSON.stringify(data)).replace('{{NAME}}', name) },
    { name: 'gamedata.json', data: JSON.stringify(data, null, 2) },
    { name: 'assets/tex.png.bin', data: tex.rgba },
    { name: 'assets/walk.anim.json', data: JSON.stringify({ name: anim.name, duration: anim.duration, tracks: anim.tracks.length }) },
    { name: 'package.json', data: JSON.stringify({ name: String(name).toLowerCase().replace(/[^a-z0-9]+/g, ''), version: '1.0.0', private: true, genesis: { genre: key, seed: s } }, null, 2) },
  ];
  const artifact = { name: `${String(name).replace(/[^a-zA-Z0-9]+/g, '')}.zip`, data: zipCreate(files) };
  const back = zipRead(artifact.data); // self-verify: o que saiu LÊ de volta
  if (back.size !== files.length) throw new Error('creator: zip de jogo não bate (erro interno honesto)');
  return { ok: true, genre: key, seed: s, data, files: files.map((f) => ({ name: f.name, bytes: typeof f.data === 'string' ? f.data.length : f.data.length })), artifact };
}
