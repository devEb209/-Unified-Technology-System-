// UTS :: world/chunk-worker — the streaming WORKER entry (Node worker_threads).
// A worker owns a Terrain for the seed it was given and samples chunks
// OFF-THREAD. Sampling is PURE (deterministic fbm from the seed), so a
// worker's result is BYTE-IDENTICAL to the main thread's — the worker is a
// scheduling optimization, never a different reality.

import { parentPort, workerData } from 'node:worker_threads';
import { Terrain } from './terrain.js';

const terrains = new Map(); // seed -> Terrain (workers are few; seeds are few)

function terrainFor(seed) {
  let t = terrains.get(seed);
  if (!t) { t = new Terrain({ seed }); terrains.set(seed, t); }
  return t;
}

if (parentPort) {
  parentPort.on('message', (job) => {
    try {
      const t = terrainFor(job.seed);
      const patch = t.sampleChunk(job.cx, job.cz, job.res);
      // transfer the buffers (zero-copy handoff)
      parentPort.postMessage({
        id: job.id, cx: job.cx, cz: job.cz, res: job.res,
        heights: patch.heights, biomes: patch.biomes, step: patch.step,
      }, [patch.heights.buffer, patch.biomes.buffer]);
    } catch (err) {
      parentPort.postMessage({ id: job.id, error: String(err?.message ?? err) });
    }
  });
}

export { terrainFor, workerData };
