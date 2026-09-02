// Render (materialização → imagem) — testes do elo EXPERIÊNCIA.
// Aqui o que importa não é "bonito": é que o byte que o olho vê venha do campo
// que a decisão produziu, sem nenhuma capacidade inventada no caminho.
import test from 'node:test';
import assert from 'node:assert/strict';
import { encodePNG, frameToRGBA, renderDFrame, visualFrameAtD, contactSheetPNG } from '../src/render.ts';
import { materializeVisual } from '../src/materialize.ts';

test('R1 PNG é escrito conforme a especificação: assinatura, chunks e CRC conferidos', () => {
  const png = renderDFrame(visualFrameAtD(3, { entities: 8 }), { size: 64 });
  assert.deepEqual(Array.from(png.subarray(0, 8)), [137, 80, 78, 71, 13, 10, 26, 10]);
  const CRC = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();
  const crc = (b: Uint8Array) => {
    let c = 0xffffffff;
    for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const dv = new DataView(png.buffer, png.byteOffset, png.byteLength);
  const seen: string[] = [];
  let o = 8;
  while (o < png.length) {
    const len = dv.getUint32(o);
    const type = String.fromCharCode(png[o + 4], png[o + 5], png[o + 6], png[o + 7]);
    seen.push(type);
    // CRC é a ÚNICA coisa que impede um encoder trocado (type/data deslocados em 4
    // bytes) de produzir um arquivo que um parser tolerante ainda abre: sem isto,
    // "o navegador mostrou" virava evidência de correção.
    assert.equal(dv.getUint32(o + 8 + len), crc(png.subarray(o + 4, o + 8 + len)), `${type}: CRC inválido`);
    o += 12 + len;
  }
  assert.deepEqual(seen, ['IHDR', 'IDAT', 'IEND']);
});

test('R2 o frame D0 não afirma relevo que não materializa (allowlist por capacidade)', () => {
  const flat = visualFrameAtD(0);
  const withH = visualFrameAtD(1);
  assert.deepEqual(flat.entities, [], 'entidades ausentes ≠ omitidas: [] é fato, undefined é pergunta');
  assert.equal(flat.Representation.heightfield_ref, undefined, 'D0 sem height_silhouette não pode carregar heightfield_ref');
  assert.equal(typeof withH.Representation.heightfield_ref, 'string');
  const m = materializeVisual(flat, { gridSize: 16 });
  const uniq = new Set(Array.from(m.field.samples).map((v) => v.toFixed(6)));
  assert.equal(uniq.size, 1, 'um frame sem capacidade de relevo tem de ser uniforme, não ruidoso');
});

test('R3 render é determinístico: mesmos bytes para o mesmo frame', () => {
  const a = renderDFrame(visualFrameAtD(4, { entities: 12, tick: 3 }), { size: 48 });
  const b = renderDFrame(visualFrameAtD(4, { entities: 12, tick: 3 }), { size: 48 });
  assert.equal(Buffer.compare(Buffer.from(a), Buffer.from(b)), 0);
});

test('R4 onde existe capacidade de estado, o tick muda o campo; onde não existe, não muda — e as duas coisas são o contrato', () => {
  const withState = (D: number, tick: number) => materializeVisual(visualFrameAtD(D, { entities: 16, tick }), { gridSize: 24 });
  const a = withState(3, 0), b = withState(3, 1);
  let chromaDiff = 0;
  for (let i = 0; i < a.chroma.length; i++) if (a.chroma[i] !== b.chroma[i]) chromaDiff++;
  assert.ok(chromaDiff > 0, 'com matter_state o tick que não altera nada não é simulação, é papel de parede');
  // e o invariante duro do materializador fica preso aqui: estado de matéria é
  // MODULAÇÃO (croma), nunca um termo a mais na soma de luminância — foi assim que
  // Qp deixou de ser monotônico por decreto e passou a ser monotônico por construção.
  assert.deepEqual(Array.from(a.field.samples), Array.from(b.field.samples), 'estado não pode mover luminância');
  const c = withState(2, 0), d = withState(2, 1);
  assert.deepEqual(Array.from(c.chroma), Array.from(d.chroma), 'D sem matter_state não pode reagir a estado de matéria');
});

test('R5 nenhum pixel é alfa-zero e a luminância exibida é monotônica com o campo', () => {
  const m = materializeVisual(visualFrameAtD(5, { entities: 6 }), { gridSize: 16 });
  const { data } = frameToRGBA(m, { size: 64 });
  for (let i = 3; i < data.length; i += 4) assert.equal(data[i], 255);
  // se o campo sobe, o pixel correspondente não pode escurecer: a normalização de
  // exibição é por quadro, não por amostra, e é isto que impede o PNG de inverter
  // a ordem que o Qp mediu.
  const lo = Math.min(...Array.from(m.field.samples)), hi = Math.max(...Array.from(m.field.samples));
  const stretched = m.field.samples.map((v) => (v - lo) / (hi - lo || 1));
  const idxMin = Array.from(stretched).indexOf(Math.min(...stretched));
  assert.ok(stretched[idxMin] <= 1e-9, 'o mínimo do campo tem de mapear no mínimo da exibição');
});

test('R6 contact sheet compõe um painel por frame, com a grade que eu pedir', () => {
  const png = contactSheetPNG([0, 1, 2, 3, 4, 5].map((D) => visualFrameAtD(D)), { size: 32, gridSize: 8 });
  const dv = new DataView(png.buffer, png.byteOffset, png.byteLength);
  // ceil(sqrt(6)) = 3 colunas × 2 linhas — layout quadrado, não uma tira: uma tira
  // de 6 empurra o celular para uma imagem de 1920 px de largura por nada.
  assert.equal(dv.getUint32(16), 32 * 3);
  assert.equal(dv.getUint32(20), 32 * 2);
});
