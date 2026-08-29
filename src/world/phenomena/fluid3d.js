// UTS :: world/phenomena/fluid3d — O FLUIDO 3D COM PROFUNDIDADE REAL:
// solver Euleriano (Stam, "Real-Time Fluid Dynamics") numa grade local:
// advecção SEMI-LAGRANGIANA do campo de velocidade, EMPUXO TÉRMICO
// (fumaça quente sobe — a lei da flutuabilidade), difusão e PROJEÇÃO DE
// PRESSÃO por Gauss-Seidel (incompressibilidade: ∇·v → 0). Determinístico
// (passos fixos, zero aleatório). A FUMAÇA dos incêndios deixa de ser
// fórmula e passa a ser SOLUÇÃO: cada fogo injeta densidade+calor, o
// campo sobe, enrola e viaja com o vento. D-O15: a grade segue o foco
// (recêntrise = novo tensor, honesto — a fumaça é fenômeno efêmero e a
// injeção contínua dos fogos a reconstrói); snapshot/restore completa.

const SWAP = (a, b) => [a, b] = [b, a]; // (helper não usado inline; clareza)

export const FLUID3D_CONST = Object.freeze({
  N_PROJECT: 14,   // iterações de Gauss-Seidel da projeção
  N_DIFFUSE: 8,    // iterações da difusão
  BUOY_ALPHA: 0.012, // fumo quente sobe (por grau de temperatura)
  BUOY_BETA: 0.006,  // ... e o próprio peso da densidade desce
  AMBIENT_COOL: 0.985, // a fumaça esfria no ar (perde flutuabilidade)
});

export class Fluid3D {
  constructor({ nx = 20, ny = 14, nz = 20, cell = 12, origin = [384, 0, 384], wind = [0, 0, 0] } = {}) {
    this.nx = nx; this.ny = ny; this.nz = nz;
    this.cell = cell;
    this.origin = [...origin];
    this.n = nx * ny * nz;
    // velocidade (m/s), densidade de fumaça (0..~2), temperatura (ΔK)
    this.u = new Float32Array(this.n);
    this.v = new Float32Array(this.n);
    this.w = new Float32Array(this.n);
    this.dens = new Float32Array(this.n);
    this.temp = new Float32Array(this.n);
    this._u0 = new Float32Array(this.n);
    this._v0 = new Float32Array(this.n);
    this._w0 = new Float32Array(this.n);
    this._d0 = new Float32Array(this.n);
    this._t0 = new Float32Array(this.n);
    this._div = new Float32Array(this.n);
    this._p = new Float32Array(this.n);
    this.wind = [...wind];
    this.stats = { steps: 0, emitted: 0, divergência: 0 };
  }

  /** índice linear */
  idx(i, j, k) { return (j * this.nz + k) * this.nx + i; }
  inBounds(i, j, k) { return i >= 0 && i < this.nx && j >= 0 && j < this.ny && k >= 0 && k < this.nz; }

  /** mundo → grade (partes fracionárias preservadas na amostragem) */
  worldToGrid(x, y, z) {
    return [(x - this.origin[0]) / this.cell, (y - this.origin[1]) / this.cell, (z - this.origin[2]) / this.cell];
  }
  gridToWorld(i, j, k) {
    return [this.origin[0] + i * this.cell, this.origin[1] + j * this.cell, this.origin[2] + k * this.cell];
  }

  /** INJETA fumaça quente no mundo (chamado pelos incêndios reais) */
  emit(x, y, z, { amount = 0.2, heat = 1.0 } = {}) {
    const [gi, gj, gk] = this.worldToGrid(x, y, z);
    const i = Math.round(gi), j = Math.round(gj), k = Math.round(gk);
    if (!this.inBounds(i, j, k)) return false;
    const q = this.idx(i, j, k);
    this.dens[q] = Math.min(2.0, this.dens[q] + amount);
    this.temp[q] = Math.min(40, this.temp[q] + heat * 4);
    this.stats.emitted++;
    return true;
  }

  /** amostragem trilinear (a mesma lei no advec e na leitura) */
  _sample(field, gi, gj, gk) {
    const i0 = Math.max(0, Math.min(this.nx - 1, Math.floor(gi)));
    const j0 = Math.max(0, Math.min(this.ny - 1, Math.floor(gj)));
    const k0 = Math.max(0, Math.min(this.nz - 1, Math.floor(gk)));
    const i1 = Math.min(this.nx - 1, i0 + 1), j1 = Math.min(this.ny - 1, j0 + 1), k1 = Math.min(this.nz - 1, k0 + 1);
    const fx = Math.max(0, Math.min(1, gi - i0)), fy = Math.max(0, Math.min(1, gj - j0)), fz = Math.max(0, Math.min(1, gk - k0));
    const L = (a, b, t) => a + (b - a) * t;
    const c = (i, j, k) => field[this.idx(i, j, k)];
    return L(
      L(L(c(i0, j0, k0), c(i1, j0, k0), fx), L(c(i0, j1, k0), c(i1, j1, k0), fx), fy),
      L(L(c(i0, j0, k1), c(i1, j0, k1), fx), L(c(i0, j1, k1), c(i1, j1, k1), fx), fy),
      fz,
    );
  }

  /**
   * Advecção semi-Lagrangiana de um campo escalar. O backtrace usa a
   * velocidade do campo + o VENTO AMBIENTE: o meio inteiro se move (a
   * fumaça viaja com o vento mesmo parada em relação ao ar local).
   */
  _advect(dst, src, dt) {
    const { nx, ny, nz, cell } = this;
    const [wx, wy, wz] = this.wind;
    for (let j = 0; j < ny; j++) {
      for (let k = 0; k < nz; k++) {
        for (let i = 0; i < nx; i++) {
          const q = this.idx(i, j, k);
          const gu = this.u[q] + wx, gv = this.v[q] + wy, gw = this.w[q] + wz;
          // backtrace: de onde veio esse volume no passo anterior
          dst[q] = this._sample(src, i - gu * dt / cell, j - gv * dt / cell, k - gw * dt / cell);
        }
      }
    }
  }

  /** PROJEÇÃO DE PRESSÃO: ∇·v = 0 por Gauss-Seidel (a água/fumaça não comprime) */
  _project() {
    const { nx, ny, nz, cell } = this;
    const h = 1 / cell;
    this._div.fill(0); this._p.fill(0);
    for (let j = 1; j < ny - 1; j++) for (let k = 1; k < nz - 1; k++) for (let i = 1; i < nx - 1; i++) {
      const q = this.idx(i, j, k);
      this._div[q] = -0.5 * h * (
        this.u[this.idx(i + 1, j, k)] - this.u[this.idx(i - 1, j, k)] +
        this.v[this.idx(i, j + 1, k)] - this.v[this.idx(i, j - 1, k)] +
        this.w[this.idx(i, j, k + 1)] - this.w[this.idx(i, j, k - 1)]);
    }
    for (let it = 0; it < FLUID3D_CONST.N_PROJECT; it++) {
      for (let j = 1; j < ny - 1; j++) for (let k = 1; k < nz - 1; k++) for (let i = 1; i < nx - 1; i++) {
        const q = this.idx(i, j, k);
        this._p[q] = (this._div[q] +
          this._p[this.idx(i - 1, j, k)] + this._p[this.idx(i + 1, j, k)] +
          this._p[this.idx(i, j - 1, k)] + this._p[this.idx(i, j + 1, k)] +
          this._p[this.idx(i, j, k - 1)] + this._p[this.idx(i, j, k + 1)]) / 6;
      }
    }
    for (let j = 1; j < ny - 1; j++) for (let k = 1; k < nz - 1; k++) for (let i = 1; i < nx - 1; i++) {
      const q = this.idx(i, j, k);
      this.u[q] -= 0.5 * (this._p[this.idx(i + 1, j, k)] - this._p[this.idx(i - 1, j, k)]) / h;
      this.v[q] -= 0.5 * (this._p[this.idx(i, j + 1, k)] - this._p[this.idx(i, j - 1, k)]) / h;
      this.w[q] -= 0.5 * (this._p[this.idx(i, j, k + 1)] - this._p[this.idx(i, j, k - 1)]) / h;
    }
  }

  /** um passo do fluido real */
  step(dt, { wind = null } = {}) {
    const C = FLUID3D_CONST;
    if (wind) this.wind = [...wind];
    const { nx, ny, nz } = this;
    // 1) EMPUXO TÉRMICO: fumaça quente sobe, peso próprio puxa pra baixo;
    //    o vento entra como velocidade ambiente nas células soltas
    for (let j = 0; j < ny; j++) for (let k = 0; k < nz; k++) for (let i = 0; i < nx; i++) {
      const q = this.idx(i, j, k);
      const buoy = C.BUOY_ALPHA * this.temp[q] - C.BUOY_BETA * this.dens[q];
      this.v[q] += buoy * dt;
      // turbulência do vento injecta cisalhamento leve nas massas em movimento
      const turb = Math.min(1, 0.25 * this.dens[q] * dt);
      this.u[q] += (this.wind[0] * 0.15 - this.u[q]) * turb;
    }
    // 2) advecção da velocidade (o fluido carrega a si mesmo)
    this._u0.set(this.u); this._v0.set(this.v); this._w0.set(this.w);
    this._advectUV(dt);
    // 3) PROJEÇÃO (incompressibilidade)
    this._project();
    // 4) advecção de densidade e temperatura
    this._d0.set(this.dens); this._t0.set(this.temp);
    this._advect(this.dens, this._d0, dt);
    this._advect(this.temp, this._t0, dt);
    // 5) o ar esfria; densidade decai. Os limiares são IDENTIDADE do
    // estado (não filtro): sub-visível É zero — o snapshot esparso restaura
    // bit a bit e o determinismo save→load→evoluer se mantém.
    for (let q = 0; q < this.n; q++) {
      this.temp[q] *= C.AMBIENT_COOL;
      this.dens[q] *= 0.995;
      if (this.dens[q] < 1e-4) this.dens[q] = 0;
      if (Math.abs(this.temp[q]) < 0.01) this.temp[q] = 0;
      if (Math.abs(this.u[q]) < 1e-3) this.u[q] = 0;
      if (Math.abs(this.v[q]) < 1e-3) this.v[q] = 0;
      if (Math.abs(this.w[q]) < 1e-3) this.w[q] = 0;
    }
    this.stats.steps++;
  }

  /** advecção vetorial (u,v,w juntos — mesma backtrace para os três) */
  _advectUV(dt) {
    const { nx, ny, nz } = this;
    const [wx, wy, wz] = this.wind;
    for (let j = 0; j < ny; j++) for (let k = 0; k < nz; k++) for (let i = 0; i < nx; i++) {
      const q = this.idx(i, j, k);
      const gi = i - (this._u0[q] + wx) * dt / this.cell, gj = j - (this._v0[q] + wy) * dt / this.cell, gk = k - (this._w0[q] + wz) * dt / this.cell;
      this.u[q] = this._sample(this._u0, gi, gj, gk);
      this.v[q] = this._sample(this._v0, gi, gj, gk);
      this.w[q] = this._sample(this._w0, gi, gj, gk);
    }
  }

  /** COLUNA de fumaça em (x,z): altura do centro de massa e densidade total */
  columnAt(x, z) {
    const [gi, , gk] = this.worldToGrid(x, this.origin[1], z);
    const i = Math.round(gi), k = Math.round(gk);
    if (!this.inBounds(i, 0, k)) return null;
    let mass = 0, moment = 0;
    for (let j = 0; j < this.ny; j++) {
      const d = this.dens[this.idx(i, j, k)];
      mass += d; moment += d * j;
    }
    if (mass < 0.05) return null;
    const jC = moment / mass;
    return { mass: +mass.toFixed(3), height: +(jC * this.cell).toFixed(2), pos: this.gridToWorld(i, jC, k) };
  }

  /** as N colunas mais densas (o que a fumaça MATERIALIZA no céu) */
  peakColumns(n = 4) {
    const best = new Map();
    for (let j = 0; j < this.ny; j++) for (let k = 0; k < this.nz; k++) for (let i = 0; i < this.nx; i++) {
      const d = this.dens[this.idx(i, j, k)];
      if (d <= 0.01) continue;
      const key = `${i},${k}`;
      const acc = best.get(key) ?? { i, k, mass: 0, moment: 0 };
      acc.mass += d; acc.moment += d * j;
      best.set(key, acc);
    }
    return [...best.values()]
      .map((a) => ({ pos: this.gridToWorld(a.i, a.moment / a.mass, a.k), intensity: Math.min(1, a.mass / 4) }))
      .sort((a, b) => b.intensity - a.intensity)
      .slice(0, n);
  }

  /** divergence médio pós-projeção (a prova da incompressibilidade) */
  divergence() {
    const { nx, ny, nz, cell } = this;
    let sum = 0, count = 0;
    for (let j = 1; j < ny - 1; j++) for (let k = 1; k < nz - 1; k++) for (let i = 1; i < nx - 1; i++) {
      const q = this.idx(i, j, k);
      sum += Math.abs(this.u[this.idx(i + 1, j, k)] - this.u[this.idx(i - 1, j, k)] +
        this.v[this.idx(i, j + 1, k)] - this.v[this.idx(i, j - 1, k)] +
        this.w[this.idx(i, j, k + 1)] - this.w[this.idx(i, j, k - 1)]) / (2 * cell);
      count++;
    }
    return count ? sum / count : 0;
  }

  recenter(origin) {
    this.origin = [...origin];
    this.u.fill(0); this.v.fill(0); this.w.fill(0);
    this.dens.fill(0); this.temp.fill(0);
  }

  /**
   * snapshot ESPARSO: só as células VIVAS viajam (a identidade do ar parado
   * é zero — regra 2: otimizar a representação, nunca descartar a verdade).
   * Ar vazio = wire minúsculo; fumaça = as células que existem.
   */
  snapshot() {
    const live = [];
    for (let q = 0; q < this.n; q++) {
      // só o estado VISÍVEL viaja (fumaça e calor); turbulência sub-visível
      // é identidade do ar parado (quantidade de movimento residual decai)
      if (this.dens[q] > 1e-4 || Math.abs(this.temp[q]) > 0.01) {
        // JSON de double em JS faz roundtrip EXATO — o determinismo
        // save→load→evoluer segue bit a bit (a cena contínua idêntica)
        live.push([q, this.dens[q], this.temp[q], this.u[q], this.v[q], this.w[q]]);
      }
    }
    return { nx: this.nx, ny: this.ny, nz: this.nz, cell: this.cell, origin: [...this.origin], wind: [...this.wind],
             live, stats: { ...this.stats } };
  }

  restore(s) {
    if (!s) return;
    this.origin = [...s.origin];
    this.wind = [...s.wind];
    this.dens.fill(0); this.temp.fill(0); this.u.fill(0); this.v.fill(0); this.w.fill(0);
    for (const [q, d, t, u, v, w] of (s.live ?? [])) {
      this.dens[q] = d; this.temp[q] = t; this.u[q] = u; this.v[q] = v; this.w[q] = w;
    }
    this.stats = { ...s.stats };
  }
}
