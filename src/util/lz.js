// UTS :: util/lz — zero-dep LZ77+Huffman-free byte packer (LZW, canonical):
// compress() and decompress() are exact inverses, deterministic, and the
// format is self-describing (magic + original length). The wire uses it
// ONLY when it actually shrinks (honest: the smaller of the two travels).
// LZ78-style dictionary (no bit packing) for clarity and safety.
const MAGIC = 0x55535a; // 'USZ'

export function compress(bytes) {
  const src = bytes instanceof Uint8Array ? bytes : new TextEncoder().encode(String(bytes));
  // dictionary of byte sequences → code
  let dictSize = 256;
  let dict = new Map();
  for (let i = 0; i < 256; i++) dict.set(String.fromCharCode(i), i);
  const out = [];
  let phrase = '';
  for (const byte of src) {
    const ch = String.fromCharCode(byte);
    const next = phrase + ch;
    if (dict.has(next)) {
      phrase = next;
    } else {
      out.push(dict.get(phrase));
      dict.set(next, dictSize++);
      phrase = ch;
    }
  }
  if (phrase) out.push(dict.get(phrase));
  // pack codes as 32-bit LE + header (magic, origLen, count)
  const head = new Uint8Array(12);
  const hv = new DataView(head.buffer);
  hv.setUint32(0, MAGIC, true);
  hv.setUint32(4, src.length, true);
  hv.setUint32(8, out.length, true);
  const body = new Uint8Array(out.length * 4);
  const bv = new DataView(body.buffer);
  for (let i = 0; i < out.length; i++) bv.setUint32(i * 4, out[i], true);
  const result = new Uint8Array(12 + body.length);
  result.set(head, 0);
  result.set(body, 12);
  return result;
}

export function decompress(packed) {
  const dv = new DataView(packed.buffer, packed.byteOffset, packed.byteLength);
  if (packed.length < 12 || dv.getUint32(0, true) !== MAGIC) throw new Error('lz: pacote sem assinatura USZ');
  const origLen = dv.getUint32(4, true);
  const count = dv.getUint32(8, true);
  const codes = [];
  for (let i = 0; i < count; i++) codes.push(dv.getUint32(12 + i * 4, true));
  let dictSize = 256;
  let dict = new Map();
  for (let i = 0; i < 256; i++) dict.set(i, String.fromCharCode(i));
  let phrase = '';
  const parts = [];
  for (const code of codes) {
    let entry;
    if (code < dictSize) {
      entry = dict.get(code);
    } else if (code === dictSize) {
      entry = phrase + phrase[0]; // the Kω case
    } else {
      throw new Error(`lz: código ${code} fora do dicionário (${dictSize})`);
    }
    parts.push(entry);
    if (phrase) dict.set(dictSize++, phrase + entry[0]);
    phrase = entry;
  }
  const text = parts.join('');
  // byte-faithful: rebuild the ORIGINAL bytes (UTF-8 bytes were stored as latin1 codes)
  const out = new Uint8Array(origLen);
  for (let i = 0; i < origLen; i++) out[i] = text.charCodeAt(i) & 0xFF;
  return out;
}

/** true when packing actually shrinks (the wire sends the smaller, never lies) */
export function shrinks(bytes) {
  return compress(bytes).length < bytes.length;
}
