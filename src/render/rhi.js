// UTS :: render/rhi — UTS RHI (Render Hardware Interface) — OUR OWN.
//
// Native graphics abstraction: the UTS owns its resource model, program
// cache and device contract. Backends (WebGL2 device today, Vulkan later)
// implement the contract; nothing above the RHI touches a graphics API.
//
//   UTS Renderer  → UTS materials/lighting/culling/streaming
//                 → UTS RHI (device contract + GPU resource manager)
//                 → backend device (hardware layer — the inevitable part)
//                 → GPU

export class RHIError extends Error {}

/** backwards-compatible alias (the RHI now owns the renderer error type) */
export class RendererError extends RHIError {}

/** OWN GPU resource model: every GPU object is tracked, sized and owned. */
export class GPUResourceManager {
  constructor() {
    this.resources = new Map();
    this.nextId = 1;
    this.stats = { created: 0, destroyed: 0, bytes: 0, peakBytes: 0 };
  }

  create(type, bytes, meta = {}, destroyFn = null) {
    const handle = {
      id: 'r' + this.nextId++, type, bytes, meta,
      alive: true,
      destroy: destroyFn, // backend-specific teardown (injected at creation)
    };
    this.resources.set(handle.id, handle);
    this.stats.created++;
    this.stats.bytes += bytes;
    if (this.stats.bytes > this.stats.peakBytes) this.stats.peakBytes = this.stats.bytes;
    return handle;
  }

  destroy(handle) {
    if (!handle || !handle.alive) return false;
    handle.alive = false;
    if (typeof handle.destroy === 'function') handle.destroy();
    this.resources.delete(handle.id);
    this.stats.destroyed++;
    this.stats.bytes -= handle.bytes;
    return true;
  }

  count(type = null) {
    let n = 0;
    for (const r of this.resources.values()) if (!type || r.type === type) n++;
    return n;
  }

  liveBytes() { return this.stats.bytes; }

  /** audit: every live resource must be reachable — used by destroy()/tests */
  leakReport() {
    return [...this.resources.values()].map(r => ({ id: r.id, type: r.type, bytes: r.bytes }));
  }

  destroyAll() {
    for (const r of [...this.resources.values()]) this.destroy(r);
  }
}

/** compiled-program cache (per device) — programs are static resources */
export class ProgramCache {
  constructor(device) {
    this.device = device;
    this.programs = new Map();
    this.stats = { compiles: 0, hits: 0 };
  }

  get(key, vsSrc, fsSrc) {
    if (this.programs.has(key)) {
      this.stats.hits++;
      return this.programs.get(key);
    }
    const prog = this.device.compileProgram(vsSrc, fsSrc, key);
    this.programs.set(key, prog);
    this.stats.compiles++;
    return prog;
  }
}

/**
 * Device CONTRACT (a backend must implement):
 *   compileProgram(vs, fs, label) -> {prog, u(lookup), a(attrib lookup)}
 *   createBuffer(data, {dynamic}) -> handle (tracked)
 *   uploadBuffer(handle, data)
 *   deleteBuffer(handle)
 *   caps() -> {instanced, fbo, maxTextureSize}
 * Native rule: the device is the ONLY place a graphics API is touched.
 */
export const RHI_DEVICE_CONTRACT = Object.freeze([
  'compileProgram', 'createBuffer', 'uploadBuffer', 'deleteBuffer', 'caps',
]);
