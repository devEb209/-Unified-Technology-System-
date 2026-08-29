// UTS :: net/transport — REAL network transport, zero deps: a minimal
// RFC 6455 WebSocket endpoint + frame codec. The world's deltas cross the
// wire as the SAME bytes (one truth). Handshake (SHA-1 accept key),
// masked client frames, extended lengths, ping/pong, honest close.
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/** the RFC 6455 handshake answer key for a client's Sec-WebSocket-Key */
export function wsAcceptKey(key) {
  return createHash('sha1').update(String(key) + GUID).digest('base64');
}

/** encode one server→client frame (unmasked, as the RFC demands) */
export function encodeFrame(payload, { opcode = 0x1 } = {}) {
  const data = typeof payload === 'string' ? Buffer.from(payload, 'utf8') : payload;
  const len = data.length;
  let head;
  if (len < 126) {
    head = Buffer.from([0x80 | opcode, len]);
  } else if (len < 65536) {
    head = Buffer.alloc(4);
    head[0] = 0x80 | opcode; head[1] = 126; head.writeUInt16BE(len, 2);
  } else {
    head = Buffer.alloc(10);
    head[0] = 0x80 | opcode; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([head, data]);
}

/** decode client frames (they MUST be masked); returns [{opcode, payload}] */
export function decodeFrames(buf) {
  const out = [];
  let p = 0;
  while (p + 2 <= buf.length) {
    const opcode = buf[p] & 0x0f;
    const masked = (buf[p + 1] & 0x80) !== 0;
    let len = buf[p + 1] & 0x7f;
    let q = p + 2;
    if (len === 126) { len = buf.readUInt16BE(q); q += 2; }
    else if (len === 127) { len = Number(buf.readBigUInt64BE(q)); q += 8; }
    let mask = null;
    if (masked) { mask = buf.subarray(q, q + 4); q += 4; }
    if (q + len > buf.length) break; // frame incompleto: espera mais bytes
    const payload = Buffer.from(buf.subarray(q, q + len));
    if (masked) {
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
    }
    out.push({ opcode, masked, payload });
    p = q + len;
  }
  return out;
}

/** build a masked client frame (what a browser sends — for tests/clients) */
export function encodeClientFrame(payload, { opcode = 0x1 } = {}) {
  const data = typeof payload === 'string' ? Buffer.from(payload, 'utf8') : payload;
  const mask = randomBytes(4);
  const body = Buffer.from(data);
  for (let i = 0; i < body.length; i++) body[i] ^= mask[i & 3];
  let head;
  if (data.length < 126) head = Buffer.from([0x80 | opcode, 0x80 | data.length]);
  else { head = Buffer.alloc(4); head[0] = 0x80 | opcode; head[1] = 0x80 | 126; head.writeUInt16BE(data.length, 2); }
  return Buffer.concat([head, mask, body]);
}

/**
 * The HUB: attaches to an http server via the `upgrade` event, keeps the
 * live sockets, broadcasts the same bytes to everyone. Honest counts.
 */
export class WSHub {
  constructor() {
    this.sockets = new Set();
    this.sent = 0;
    this.received = 0;
    this.log = [];
  }

  attach(httpServer) {
    httpServer.on('upgrade', (req, socket) => {
      const key = req.headers['sec-websocket-key'];
      if (!key || req.headers.upgrade?.toLowerCase() !== 'websocket') {
        socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
        socket.destroy();
        return;
      }
      socket.write(
        'HTTP/1.1 101 Switching Protocols\r\n' +
        'Upgrade: websocket\r\n' +
        'Connection: Upgrade\r\n' +
        `Sec-WebSocket-Accept: ${wsAcceptKey(key)}\r\n\r\n`,
      );
      socket.setNoDelay(true);
      this.sockets.add(socket);
      let acc = Buffer.alloc(0);
      socket.on('data', (chunk) => {
        acc = Buffer.concat([acc, chunk]);
        for (const f of decodeFrames(acc)) {
          acc = Buffer.alloc(0);
          if (f.opcode === 0x8) { // close
            this.sockets.delete(socket);
            socket.end(encodeFrame(Buffer.alloc(0), { opcode: 0x8 }));
          } else if (f.opcode === 0x9) { // ping → pong
            socket.write(encodeFrame(f.payload, { opcode: 0xa }));
          } else {
            this.received += 1;
            this.log.push({ at: Date.now(), bytes: f.payload.length });
            if (this.log.length > 100) this.log.shift();
          }
        }
      });
      socket.on('close', () => this.sockets.delete(socket));
      socket.on('error', () => this.sockets.delete(socket));
    });
    return this;
  }

  /** the SAME bytes to every live socket (o mundo sai por aqui inteiro) */
  broadcast(data) {
    const frame = encodeFrame(typeof data === 'string' ? data : JSON.stringify(data));
    for (const s of this.sockets) {
      try { s.write(frame); this.sent += 1; } catch { this.sockets.delete(s); }
    }
    return this.sockets.size;
  }

  /** deterministic close-all (tests) */
  close() {
    for (const s of this.sockets) { try { s.end(); } catch {} }
    this.sockets.clear();
  }
}
