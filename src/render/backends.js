// UTS :: render/backends — NullRenderer + TextRenderer.
// Null: counts what WOULD be drawn (headless validation of the Frame).
// Text: ASCII manifestation for terminals (proof the frame derives from state).

export class NullRenderer {
  constructor() {
    this.stats = { frames: 0, drawCalls: 0, entities: 0, patches: 0, aggregates: 0, audioEvents: 0 };
  }

  init() {}
  destroy() {}

  render(frame) {
    const rain = Math.max(frame.environment.rain ?? 0, frame.environment.dust ?? 0) > 0.02 ? 1 : 0;
    const drawCalls = 1 + frame.terrain.patches.length + frame.entities.length + frame.aggregates.length + rain;
    this.stats.frames++;
    this.stats.drawCalls += drawCalls;
    this.stats.entities += frame.entities.length;
    this.stats.patches += frame.terrain.patches.length;
    this.stats.aggregates += frame.aggregates.length;
    this.stats.audioEvents += frame.audio.oneShots.length;
    return { drawCalls };
  }
}

const BIOME_CHARS = ['~', '.', ',', 't', '^', '*'];
const KIND_CHARS = { npc: 'N', hazard: 'F', tree: 'Y', bush: 'u', settlement: 'H', aggregate: 'O' };

export class TextRenderer {
  constructor({ cols = 64, rows = 28 } = {}) {
    this.cols = cols;
    this.rows = rows;
  }

  init() {}
  destroy() {}

  render(frame) {
    const { cols, rows } = this.cols ? this : { cols: 64, rows: 28 };
    const cam = frame.camera;
    const span = 220;
    const grid = [];
    for (let r = 0; r < rows; r++) grid.push(new Array(cols).fill(' '));

    // terrain from represented patches
    for (const patch of frame.terrain.patches) {
      const step = patch.size / patch.res;
      for (let j = 0; j <= patch.res; j += 2) {
        for (let i = 0; i <= patch.res; i += 2) {
          const wx = patch.x0 + i * step, wz = patch.z0 + j * step;
          const c = Math.floor(((wx - cam.pos[0]) / span + 0.5) * cols);
          const rw = Math.floor(((wz - cam.pos[2]) / span + 0.5) * rows);
          if (c < 0 || c >= cols || rw < 0 || rw >= rows) continue;
          const b = patch.biomes[j * (patch.res + 1) + i];
          if (grid[rw][c] === ' ') grid[rw][c] = BIOME_CHARS[b] ?? '?';
        }
      }
    }

    // entities
    const plot = (x, z, ch) => {
      const c = Math.floor(((x - cam.pos[0]) / span + 0.5) * cols);
      const rw = Math.floor(((z - cam.pos[2]) / span + 0.5) * rows);
      if (c >= 0 && c < cols && rw >= 0 && rw < rows) grid[rw][c] = ch;
    };
    for (const e of frame.entities) plot(e.pos[0], e.pos[2], KIND_CHARS[e.kind] ?? '?');
    for (const a of frame.aggregates) plot(a.pos[0], a.pos[2], KIND_CHARS.aggregate);
    plot(cam.pos[0], cam.pos[2], '@');

    const env = frame.environment;
    const header =
      `UTS frame tick=${frame.tick} weather=${env.weather} rain=${(env.rain).toFixed(2)} wet=${(env.wetness).toFixed(2)} ` +
      `wind=${(env.wind).toFixed(2)} dust=${(env.dust).toFixed(2)} | entities=${frame.entities.length} ` +
      `aggregates=${frame.aggregates.length} patches=${frame.terrain.patches.length} ` +
      `pressure=${(frame.stats.pressure ?? 0).toFixed(2)} audio=${frame.audio.ambience}`;
    return header + '\n' + grid.map(r => r.join('')).join('\n');
  }
}
