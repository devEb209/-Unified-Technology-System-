// Servidor de escaramuça (relay + tick 20 Hz). node server/server.js
import { WebSocketServer } from 'ws';

const PORT = process.env.MP_PORT || 8787;
const wss = new WebSocketServer({ port: PORT, host: '0.0.0.0' });
const players = new Map();
let nextId = 1;

wss.on('connection', (ws) => {
  const id = nextId++;
  players.set(id, { id, x: 0, y: 0, z: 90, yaw: 0, st: 'stand', ws });
  ws.send(JSON.stringify({ t: 'hello', id }));
  ws.on('message', (raw) => {
    let m; try { m = JSON.parse(raw); } catch { return; }
    const p = players.get(id); if (!p) return;
    if (m.t === 'move') Object.assign(p, { x: m.x, y: m.y, z: m.z, yaw: m.yaw, st: m.st });
    if (m.t === 'shot') broadcast({ ...m, id });
  });
  ws.on('close', () => players.delete(id));
});

function broadcast(obj) {
  const s = JSON.stringify(obj);
  for (const p of players.values()) if (p.ws.readyState === 1) p.ws.send(s);
}

setInterval(() => {
  const list = [...players.values()].map(({ id, x, y, z, yaw, st }) => ({ id, x, y, z, yaw, st }));
  broadcast({ t: 'state', players: list });
}, 50);

console.log(`[THEATRE ZERO] servidor de escaramuça em ws://0.0.0.0:${PORT}`);
