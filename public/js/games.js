export const GAMES = [
  {
    id: "aether",
    name: "AETHER DRIFT",
    blurb: "Desvie dos fragmentos no corredor do bunker. O jogo roda no celular e projeta na TV — nada é instalado no outro aparelho.",
  },
  {
    id: "kstrike",
    name: "K-STRIKE",
    blurb: "Atire nos alvos com o gamepad virtual. Transmita a tela para o computador ou televisor emparelhado.",
  },
];

export function createGame(id, canvas, input) {
  const ctx = canvas.getContext("2d");
  let raf = 0;
  let running = false;
  let score = 0;
  let dead = false;
  const W = () => canvas.width;
  const H = () => canvas.height;

  function resize() {
    const r = canvas.getBoundingClientRect();
    canvas.width = Math.max(320, Math.floor(r.width * devicePixelRatio));
    canvas.height = Math.max(180, Math.floor(r.height * devicePixelRatio));
  }

  const aether = {
    x: 0.5,
    y: 0.78,
    shards: [],
    t: 0,
    start() {
      this.x = 0.5;
      this.y = 0.78;
      this.shards = [];
      this.t = 0;
      score = 0;
      dead = false;
    },
    tick(dt) {
      this.t += dt;
      const stick = input.left || { x: 0, y: 0 };
      this.x = clamp(this.x + stick.x * dt * 1.6, 0.06, 0.94);
      this.y = clamp(this.y + stick.y * dt * 1.2, 0.1, 0.92);
      if (Math.random() < 0.04 + this.t * 0.002) {
        this.shards.push({
          x: Math.random(),
          y: -0.08,
          s: 0.18 + Math.random() * 0.35,
          w: 0.02 + Math.random() * 0.03,
        });
      }
      for (const sh of this.shards) sh.y += sh.s * dt;
      this.shards = this.shards.filter((sh) => sh.y < 1.1);
      for (const sh of this.shards) {
        if (Math.abs(sh.x - this.x) < sh.w + 0.03 && Math.abs(sh.y - this.y) < 0.05) dead = true;
      }
      if (!dead) score += dt * 10;
    },
    draw() {
      const w = W(), h = H();
      ctx.fillStyle = "#070705";
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = "rgba(200,137,42,0.18)";
      ctx.lineWidth = 2;
      for (let i = 0; i < 8; i++) {
        ctx.beginPath();
        ctx.moveTo(w * 0.5, -20);
        ctx.lineTo(w * (i / 7), h);
        ctx.stroke();
      }
      for (const sh of this.shards) {
        ctx.fillStyle = "#c8892a";
        ctx.fillRect((sh.x - sh.w) * w, sh.y * h, sh.w * 2 * w, 10 * devicePixelRatio);
      }
      ctx.save();
      ctx.translate(this.x * w, this.y * h);
      ctx.fillStyle = dead ? "#e25b3a" : "#e2b056";
      ctx.beginPath();
      ctx.moveTo(0, -18 * devicePixelRatio);
      ctx.lineTo(14 * devicePixelRatio, 16 * devicePixelRatio);
      ctx.lineTo(0, 8 * devicePixelRatio);
      ctx.lineTo(-14 * devicePixelRatio, 16 * devicePixelRatio);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
      hud();
    },
  };

  const kstrike = {
    x: 0.5,
    y: 0.8,
    bullets: [],
    foes: [],
    cd: 0,
    start() {
      this.x = 0.5;
      this.y = 0.8;
      this.bullets = [];
      this.foes = [];
      this.cd = 0;
      score = 0;
      dead = false;
    },
    tick(dt) {
      const l = input.left || { x: 0, y: 0 };
      const r = input.right || { x: 0, y: 0 };
      this.x = clamp(this.x + l.x * dt * 1.4, 0.05, 0.95);
      this.y = clamp(this.y + l.y * dt * 1.4, 0.08, 0.92);
      this.cd -= dt;
      const shooting = input.buttons?.a || Math.hypot(r.x, r.y) > 0.35;
      if (shooting && this.cd <= 0) {
        const ang = Math.hypot(r.x, r.y) > 0.2 ? Math.atan2(r.y, r.x) : -Math.PI / 2;
        this.bullets.push({ x: this.x, y: this.y, vx: Math.cos(ang) * 1.4, vy: Math.sin(ang) * 1.4 });
        this.cd = 0.12;
      }
      if (Math.random() < 0.03) this.foes.push({ x: Math.random(), y: -0.05, hp: 2 });
      for (const b of this.bullets) {
        b.x += b.vx * dt;
        b.y += b.vy * dt;
      }
      this.bullets = this.bullets.filter((b) => b.x > -0.1 && b.x < 1.1 && b.y > -0.1 && b.y < 1.1);
      for (const f of this.foes) f.y += dt * 0.18;
      for (const f of this.foes) {
        for (const b of this.bullets) {
          if (Math.hypot(f.x - b.x, f.y - b.y) < 0.04) {
            f.hp -= 1;
            b.y = -9;
            if (f.hp <= 0) score += 25;
          }
        }
        if (Math.hypot(f.x - this.x, f.y - this.y) < 0.05) dead = true;
      }
      this.foes = this.foes.filter((f) => f.hp > 0 && f.y < 1.05);
      if (!dead) score += dt * 4;
    },
    draw() {
      const w = W(), h = H();
      ctx.fillStyle = "#05060a";
      ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = "#7dffb1";
      for (const b of this.bullets) ctx.fillRect(b.x * w - 2, b.y * h - 6, 4, 10);
      ctx.fillStyle = "#e25b3a";
      for (const f of this.foes) {
        ctx.beginPath();
        ctx.arc(f.x * w, f.y * h, 10 * devicePixelRatio, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = "#e2b056";
      ctx.fillRect(this.x * w - 12, this.y * h - 10, 24, 20);
      hud();
    },
  };

  function hud() {
    ctx.fillStyle = "#e2b056";
    ctx.font = `${14 * devicePixelRatio}px Rajdhani, sans-serif`;
    ctx.fillText(`PONTOS ${Math.floor(score)}`, 16 * devicePixelRatio, 28 * devicePixelRatio);
    if (dead) {
      ctx.textAlign = "center";
      ctx.font = `${28 * devicePixelRatio}px Cinzel, serif`;
      ctx.fillText("QUEDA", W() / 2, H() / 2);
      ctx.font = `${14 * devicePixelRatio}px Rajdhani, sans-serif`;
      ctx.fillText("toque em reiniciar", W() / 2, H() / 2 + 32 * devicePixelRatio);
      ctx.textAlign = "left";
    }
  }

  const impl = id === "kstrike" ? kstrike : aether;
  let last = 0;
  function loop(ts) {
    if (!running) return;
    const dt = Math.min(0.05, (ts - last) / 1000 || 0.016);
    last = ts;
    if (!dead) impl.tick(dt);
    impl.draw();
    raf = requestAnimationFrame(loop);
  }

  return {
    canvas,
    start() {
      resize();
      impl.start();
      running = true;
      last = performance.now();
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(loop);
    },
    stop() {
      running = false;
      cancelAnimationFrame(raf);
    },
    restart() {
      impl.start();
    },
    resize,
    isDead: () => dead,
    score: () => score,
  };
}

function clamp(v, a, b) {
  return Math.max(a, Math.min(b, v));
}
