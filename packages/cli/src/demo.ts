// UTS/UES GEN-1 — `uts demo`: o elo MATERIALIZAÇÃO → EXPERIÊNCIA rodando num
// servidor de ~90 dólares (ou no navegador do próprio aparelho, via Termux).
//
// O que isto prova e o que NÃO prova:
//   PROVA: a mesma cena materializada nos seis degraus, com Qp medido por
//          degrau contra o D5, e o corte que o piso permite (ou recusa) à vista.
//          É isto que "não existe dial de reduzir gráficos" significa — e aqui
//          se vê em vez de se ler.
//   NÃO PROVA: raster/GPU. Não há mesh, texture nem draw call aqui, e portanto
//          nenhum número desta página pode ser usado como "quantos fps o A70 faz".
//          Número de desempenho continua saindo só de `uts measure` no aparelho.
import { createServer } from 'node:http';
import { writeFileSync } from 'node:fs';
import { materializeVisual } from '../../rrw-mat/src/materialize.ts';
import { measureQp } from '../../rrw-mat/src/quality.ts';
import { visualFrameAtD, encodePNG, frameToRGBA } from '../../rrw-mat/src/render.ts';
import { ladderFor } from '../../d-system/src/ladders.ts';
import { interpolate, presentBudget } from '../../do15/src/present.ts';

const args = process.argv.slice(3); // depois de `run.js demo`
const flag = (n: string, d: string) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : d;
};
const port = Number(flag('port', '8080'));
const host = flag('host', '0.0.0.0');
const gridSize = Number(flag('grid', '24'));
const simHz = Number(flag('sim-hz', '15'));
const dispHz = Number(flag('disp-hz', '30'));
const unitsPerSecond = Number(flag('units', '870000'));
const entities = Number(flag('entities', '20'));
const QpMin = Number(flag('qpmin', '0.9'));
const Ds = ladderFor('visual').steps.map((s) => s.D);

function buildFrame(D: number, tick: number) {
  return visualFrameAtD(D, { entities, tick, regionId: 'r:0,0' });
}

/** as 6 amostras + Qp medido contra D5 + veredito do floor */
function sheet(tick: number, mode: 'step' | 'interp') {
  // `tick` avança na taxa da TELA. Em `step` o mundo é amostrado a cada quadro —
  // é o judder que se vê. Em `interp` o mundo só anda a cada dispHz/simHz quadros
  // e o quadro intermediário é materializado do MESMO estado: não é filtro, é o
  // tempo de decisão desacoplado do tempo de apresentação.
  const ratio = dispHz / simHz;
  const frames = Ds.map((D) => buildFrame(D, mode === 'step' ? tick : Math.floor(tick / ratio)));
  const mat = frames.map((f) => materializeVisual(f, { gridSize }));
  const ref = mat[Ds.length - 1].field;
  const rows = Ds.map((D, i) => {
    const q = i === Ds.length - 1 ? { Qp: 1, violations: 0, worst: null } : measureQp(ref, mat[i].field);
    return { D, Qp: Number(q.Qp.toFixed(3)), violations: q.violations, aceita: q.Qp >= QpMin, cost: Number((mat[i].cells * (1 + D)).toFixed(0)) };
  });
  const size = 256;
  const w = size * Ds.length, h = size;
  const data = new Uint8Array(w * h * 4);
  for (let i = 0; i < mat.length; i++) {
    const img = frameToRGBA(mat[i], { size, grid: true });
    for (let y = 0; y < size; y++) data.set(img.data.subarray(y * size * 4, (y + 1) * size * 4), (y * w + i * size) * 4);
  }
  return { png: encodePNG({ w, h, data }), rows };
}

function presentRow() {
  const decisions = Object.fromEntries(
    ['visual', 'physical', 'temporal'].map((dom) => [dom, { domain: dom, D: dom === 'visual' ? 2 : 5, step: ladderFor(dom as never).steps[dom === 'visual' ? 2 : 5] }]),
  );
  const b = presentBudget(decisions as never, { id: 'r:0,0', pixels: 720 * 1612, entities: 12000, lights: 0, volumes: 0, importance: 1, motion: 0.5 } as never, { simHz, dispHz, unitsPerSecond });
  const t = interpolate(
    { tick: 0, tMs: 0, pos: { a: [0, 0] }, vel: { a: [1, 0] } },
    { tick: 1, tMs: 1000 / simHz, pos: { a: [1, 0] }, vel: { a: [1, 0] } },
    dispHz > simHz ? 0.5 : 1,
  );
  return { budget: b, interp: t };
}

const html = () => `<!doctype html><html lang="pt-br"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UES GEN-1 — materialização visível</title>
<style>
body{margin:0;background:#0a0a0a;color:#d7d7d7;font:13px/1.45 ui-monospace,Menlo,monospace}
header{padding:.8rem 1rem;border-bottom:1px solid #232323}
h1{font-size:1rem;margin:0 0 .25rem;letter-spacing:.06em}
.mut{color:#8b8b8b}
img{display:block;width:100%;image-rendering:pixelated;border-bottom:1px solid #232323}
table{border-collapse:collapse;width:100%}
td,th{padding:.3rem .5rem;border-bottom:1px solid #1c1c1c;text-align:right}
th{color:#8b8b8b;font-weight:500}
.ok{color:#7dd47d}.no{color:#e07a7a}
section{padding:.7rem 1rem;border-bottom:1px solid #1c1c1c}
pre{white-space:pre-wrap;color:#a9a9a9}
a{color:#9ecbff}
</style>
<header>
  <h1>UES GEN-1 · mesma cena nos seis degraus <span class="mut">tick <b id="tk">0</b> · grade ${gridSize}×${gridSize} · Qp exigido ${QpMin}</span></h1>
  <div class="mut">cada quadrado é a célula materializada num D. As linhas verticais são a granularidade da decisão — pixelado é o contrato, não defeito.</div>
  <div class="mut">auto-atualização: <a href="#" id="tog">ligada</a> · <a href="/sheet.png?tick=0&mode=step">imagem</a> · <a href="/sheet.json?tick=0&mode=step">json</a></div>
</header>
<img id="sheet" src="/sheet.png?tick=0&mode=step" alt="contato dos seis Ds">
<section>
  <table id="qp"><thead><tr><th>D</th><th>Qp vs D5</th><th>violações</th><th>aceita no piso ${QpMin}?</th></tr></thead><tbody></tbody></table>
  <div class="mut">“aceita” = o corte não é percebido sob o mapa de limiar local; “recusa” = o motor devolve a decisão ao humano, não desliga um preset.</div>
</section>
<section>
  <h1>frame generation: a conta desta cena</h1>
  <pre id="pr"></pre>
  <div class="mut">sim ${simHz} Hz · tela ${dispHz} Hz · ${unitsPerSecond} un/s <span class="no">(escala de placeholder — troque por device.json medido)</span></div>
</section>
<section>
  <h1>o que isto ainda não é</h1>
  <pre>não é raster nem GPU: não há mesh, textura, shader nem draw call — então nenhum
fps desta página descreve o seu A70. Para isso: node bin/uts.mjs measure --out device.json
e depois uts plan / uts present com o device.json medido no lugar dos ${unitsPerSecond} un/s.</pre>
</section>
<script>
let tick=0,on=true,timer=null;
async function refresh(){
  const mode=new URLSearchParams(location.search).get('mode')||'step';
  document.getElementById('sheet').src='/sheet.png?tick='+tick+'&mode='+mode+'&_='+Math.random();
  const j=await (await fetch('/sheet.json?tick='+tick+'&mode='+mode)).json();
  document.getElementById('tk').textContent=tick;
  document.querySelector('#qp tbody').innerHTML=j.rows.map(r=>'<tr><td>D'+r.D+'</td><td>'+r.Qp.toFixed(3)+'</td><td>'+r.violations+'</td><td class="'+(r.aceita?'ok':'no')+'">'+(r.aceita?'sim':'NÃO')+'</td></tr>').join('');
  tick++;
}
async function pr(){
  const j=await (await fetch('/present.json')).json();
  document.getElementById('pr').textContent=j.text;
}
document.getElementById('tog').onclick=e=>{e.preventDefault();on=!on;clearInterval(timer);timer=on?setInterval(refresh,1000):null;e.target.textContent=on?'ligada':'desligada';};
refresh();pr();timer=setInterval(refresh,1000);
</script></html>`;

function png(res: any, buf: Uint8Array) {
  res.writeHead(200, { 'content-type': 'image/png', 'cache-control': 'no-store', 'content-length': buf.length });
  res.end(Buffer.from(buf));
}
function json(res: any, o: unknown) {
  const s = JSON.stringify(o, null, 2);
  res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  res.end(s);
}

if (!(dispHz >= simHz)) {
  process.stderr.write(`demo: simHz (${simHz}) não pode exceder dispHz (${dispHz}) — acima da taxa da tela não há suavização a fazer, use --sim-hz menor\n`);
  process.exit(64);
}

const server = createServer((req, res) => {
  const u = new URL(req.url ?? '/', `http://${req.headers.host}`);
  const tick = Number(u.searchParams.get('tick') ?? '0');
  const mode = (u.searchParams.get('mode') === 'interp' ? 'interp' : 'step') as 'step' | 'interp';
  if (u.pathname === '/' || u.pathname === '/index.html') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    return res.end(html());
  }
  if (u.pathname === '/sheet.png') return png(res, sheet(tick, mode).png);
  if (u.pathname === '/sheet.json') {
    const { rows } = sheet(tick, mode);
    return json(res, { rows, tick, mode, grid: gridSize, QpMin, simHz, dispHz });
  }
  if (u.pathname === '/present.json') {
    const { budget, interp } = presentRow();
    return json(res, { text: `${budget.why}\n\ninterpolação: t=${interp.t} pos=${JSON.stringify(interp.pos)} delta=${JSON.stringify(interp.delta)} prevista=${interp.predicted} surpresas=${interp.surprises.join(',') || 'nenhuma'}`, budget, interp });
  }
  res.writeHead(404, { 'content-type': 'text/plain' });
  res.end('rode: node packages/cli/run.js demo --port 8080\n');
});

if (args.includes('--once')) {
  const { png: buf, rows } = sheet(0, 'step');
  const out = flag('out', 'demo-sheet.png');
  writeFileSync(out, Buffer.from(buf));
  console.log(`gravado ${out}`);
  console.table(rows);
  const { budget } = presentRow();
  console.log(budget.verdict, '·', budget.why);
  process.exit(0);
}

server.listen(port, host, () => {
  process.stdout.write(`demo UES GEN-1 em http://${host}:${port} — grade ${gridSize}×${gridSize}, sim ${simHz} Hz / tela ${dispHz} Hz\n`);
  process.stdout.write(`aviso: ${unitsPerSecond} un/s é escala de placeholder; desempenho real só com uts measure no aparelho\n`);
});
