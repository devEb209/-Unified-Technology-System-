// UTS :: util/zip — store-only ZIP writer + reader (zero deps, deterministic).
// Enough to package builds (apk layout, exe layout, web bundles) and to
// verify them back. CRC32 + local headers + central directory, no deflate.

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c >>> 0;
  }
  return t;
})();

export function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

/**
 * Build a ZIP from entries [{ name, data:Uint8Array|string }]. Store method
 * (no compression) — deterministic bytes for the same input.
 */
export function zipCreate(entries) {
  const chunks = [], central = [];
  let offset = 0;
  const enc = new TextEncoder();
  for (const e of entries) {
    const name = enc.encode(e.name);
    const data = typeof e.data === 'string' ? enc.encode(e.data) : e.data;
    const crc = crc32(data);
    const lh = new DataView(new ArrayBuffer(30));
    lh.setUint32(0, 0x04034b50, true);
    lh.setUint16(4, 20, true);      // version
    lh.setUint16(8, 0, true);       // store
    lh.setUint16(10, 0, true); lh.setUint16(12, 0, true); // time/date (fixed = deterministic)
    lh.setUint32(14, crc, true);
    lh.setUint32(18, data.length, true);
    lh.setUint32(22, data.length, true);
    lh.setUint16(26, name.length, true);
    lh.setUint16(28, 0, true);
    chunks.push(new Uint8Array(lh.buffer), name, data);
    const cd = new DataView(new ArrayBuffer(46));
    cd.setUint32(0, 0x02014b50, true);
    cd.setUint16(4, 20, true); cd.setUint16(6, 20, true);
    cd.setUint16(10, 0, true);
    cd.setUint32(16, crc, true);
    cd.setUint32(20, data.length, true); cd.setUint32(24, data.length, true);
    cd.setUint16(28, name.length, true);
    cd.setUint32(42, offset, true);
    central.push(new Uint8Array(cd.buffer), name);
    offset += 30 + name.length + data.length;
  }
  let cdSize = 0;
  for (const c of central) cdSize += c.length;
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, entries.length, true);
  end.setUint16(10, entries.length, true);
  end.setUint32(12, cdSize, true);
  end.setUint32(16, offset, true);
  const all = [...chunks, ...central, new Uint8Array(end.buffer)];
  let total = 0;
  for (const c of all) total += c.length;
  const out = new Uint8Array(total);
  let p = 0;
  for (const c of all) { out.set(c, p); p += c.length; }
  return out;
}

/** Read a store-only ZIP back: Map<name, Uint8Array>. Corrupt input → honest error. */
export function zipRead(buf) {
  try {
    const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    // find EOCD from the back
    let eocd = -1;
    for (let i = buf.length - 22; i >= 0 && i > buf.length - 65557; i--) {
      if (dv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) throw new Error('zip: EOCD não encontrado');
    const n = dv.getUint16(eocd + 10, true);
    let p = dv.getUint32(eocd + 16, true);
    const dec = new TextDecoder();
    const out = new Map();
    for (let i = 0; i < n; i++) {
      if (dv.getUint32(p, true) !== 0x02014b50) throw new Error('zip: central directory corrompido');
      const method = dv.getUint16(p + 10, true);
      const size = dv.getUint32(p + 24, true);
      const nameLen = dv.getUint16(p + 28, true);
      const extraLen = dv.getUint16(p + 30, true);
      const commLen = dv.getUint16(p + 32, true);
      const lho = dv.getUint32(p + 42, true);
      const name = dec.decode(buf.subarray(p + 46, p + 46 + nameLen));
      if (method !== 0) throw new Error(`zip: método ${method} não suportado (use store)`);
      const ln = dv.getUint16(lho + 26, true), le = dv.getUint16(lho + 28, true);
      const start = lho + 30 + ln + le;
      if (start + size > buf.length) throw new Error(`zip: conteúdo de ${name} fora dos limites`);
      out.set(name, buf.slice(start, start + size));
      p += 46 + nameLen + extraLen + commLen;
    }
    return out;
  } catch (e) {
    if (e instanceof RangeError || !/zip:/.test(e.message)) {
      throw new Error(`zip: arquivo corrompido ou formato não suportado (${e.message})`);
    }
    throw e;
  }
}
