// UTS :: audio/spatial — OUR spatializer.
// Listener-centric attenuation + stereo pan from world positions.
// Pure math; the Frame/camera feed the listener; RRW positions feed emitters.

export function spatialize({ emitterPos, listener, refDist = 12, rolloff = 1.2, maxDist = 160 }) {
  const dx = emitterPos[0] - listener.pos[0];
  const dz = emitterPos[2] - listener.pos[2];
  const dy = (emitterPos[1] ?? 0) - (listener.pos[1] ?? 0);
  const d = Math.hypot(dx, dy, dz);
  if (d > maxDist) return { gain: 0, pan: 0, dist: d, audible: false };
  const gain = Math.min(1, refDist / (refDist + Math.max(0, d - refDist) * rolloff));
  // pan from the listener's yaw: right vector = (cos yaw, -sin yaw) on (x, z)
  const rx = Math.cos(listener.yaw ?? 0);
  const rz = -Math.sin(listener.yaw ?? 0);
  const lateral = d > 0.001 ? (dx * rx + dz * rz) / d : 0;
  return { gain, pan: Math.max(-1, Math.min(1, lateral)), dist: d, audible: gain > 0.01 };
}
