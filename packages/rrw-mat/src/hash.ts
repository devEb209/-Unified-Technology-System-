/** PRNG determinístico: a materialização precisa ser reproduzível (contrato §2.4 / I6). */
export function h32(x: number, y: number, salt: number): number {
  let h = (Math.trunc(x) * 374761393 + Math.trunc(y) * 668265263 + Math.trunc(salt) * 2246822519) | 0;
  h = (h ^ (h >>> 13)) | 0;
  h = Math.imul(h, 1274126177);
  h = (h ^ (h >>> 16)) >>> 0;
  return h / 4294967296;
}

/** Ruído de valor bilinear em grade unitária. É a única "textura" do GEN-1. */
export function vnoise(x: number, y: number, salt: number): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const sx = x - xi;
  const sy = y - yi;
  const w = (t: number) => t * t * (3 - 2 * t);
  const a = h32(xi, yi, salt);
  const b = h32(xi + 1, yi, salt);
  const c = h32(xi, yi + 1, salt);
  const d = h32(xi + 1, yi + 1, salt);
  return a + (b - a) * w(sx) + (c - a) * w(sy) + (a - b - c + d) * w(sx) * w(sy);
}

/** Hash estável de um código semântico (`'wet_sand'` → número em [0,1)). */
export function codeValue(code: string | number | undefined): number {
  if (code === undefined) return 0;
  if (typeof code === 'number') return h32(Math.trunc(code * 1e6), 1, 7);
  let x = 2166136261;
  for (let i = 0; i < code.length; i++) {
    x ^= code.charCodeAt(i);
    x = Math.imul(x, 16777619);
  }
  return (x >>> 0) / 4294967296;
}

/** Frequência derivada do código do bioma: o bioma escolhe o padrão, não um seed solto. */
export function freqOf(code: string | number | undefined, base: number): number {
  return base + 2 * codeValue(code);
}

/** Altura normalizada [0,1] do heightfield, amostrada na célula (x,y). */
export function heightAt(x: number, y: number, biome: string | number | undefined, ref: number): number {
  const f = freqOf(biome, 3);
  const coarse = vnoise(x * f, y * f, ref);
  const fine = vnoise(x * f * 2.7, y * f * 2.7, ref + 1);
  return 0.72 * coarse + 0.28 * fine;
}
