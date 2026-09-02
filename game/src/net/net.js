import * as THREE from 'three';

/* Cliente de rede: relay autoritativo leve para escaramuças 8v8.
   O protocolo é binário-ish (JSON compacto) a 20 Hz com interpolação local. */
export class Net {
  constructor(scene, world, mats) {
    this.scene = scene; this.world = world; this.mats = mats;
    this.peers = new Map();
    this.ws = null; this.acc = 0; this.jitter = 0; this.id = null;
  }
  connect(player) {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    try { this.ws = new WebSocket(`${proto}://${location.host}/ws`); } catch { return; }
    this.ws.onmessage = (e) => this._msg(JSON.parse(e.data));
    this.ws.onclose = () => { this.ws = null; };
    this.player = player;
  }
  _msg(m) {
    if (m.t === 'hello') { this.id = m.id; return; }
    if (m.t === 'state') {
      for (const p of m.players) {
        if (p.id === this.id) continue;
        let peer = this.peers.get(p.id);
        if (!peer) {
          const g = new THREE.Group();
          const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.3, 1.1, 4, 10), this.mats.fabric);
          body.position.y = 1.0; body.castShadow = true;
          const head = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.24, 0.22), this.mats.fabric);
          head.position.y = 1.72; head.castShadow = true;
          g.add(body, head); this.scene.add(g);
          peer = { g, target: new THREE.Vector3(), yaw: 0 };
          this.peers.set(p.id, peer);
        }
        peer.target.set(p.x, p.y, p.z); peer.yaw = p.yaw;
      }
      for (const [id, peer] of this.peers)
        if (!m.players.find(p => p.id === id)) { this.scene.remove(peer.g); this.peers.delete(id); }
    }
    if (m.t === 'shot' && m.id !== this.id) {
      // eco de disparo remoto tratado como evento sonoro
      this.onRemoteShot?.(new THREE.Vector3(m.x, m.y, m.z));
    }
  }
  update(dt, player) {
    for (const peer of this.peers.values()) {
      peer.g.position.lerp(peer.target, 1 - Math.exp(-14 * dt));
      peer.g.rotation.y = peer.yaw;
    }
    if (!this.ws || this.ws.readyState !== 1) return;
    this.acc += dt;
    if (this.acc >= 0.05) {
      this.acc = 0;
      this.ws.send(JSON.stringify({
        t: 'move', x: +player.pos.x.toFixed(2), y: +player.pos.y.toFixed(2),
        z: +player.pos.z.toFixed(2), yaw: +player.yaw.toFixed(3), st: player.stance
      }));
    }
  }
}
