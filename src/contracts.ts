/**
 * Contratos compartilhados entre subsistemas (inversão de dependência).
 * A Singularity AI depende APENAS desta interface — nunca da UES concreta.
 * A UES implementa `WorldAdapter`; assim a IA orquestra qualquer "mundo"
 * sem acoplamento (Prompt 1/6 e 3/20: baixo acoplamento, integração coerente).
 */

export interface WorldAdapter {
  createWorld(opts: { size: number; biomes: string[]; seed: number }): { ok: boolean; id: string };
  worldExists(): boolean;
  createBiome(biome: string, x: number, y: number): { ok: boolean; id: string };
  buildStructures(structures: string[], x: number, y: number): { ok: boolean; count: number };
  spawnNpcs(count: number, x: number, y: number, opts?: Record<string, unknown>): { ok: boolean; count: number; ids: string[] };
  entityCount(): number;
  npcCount(): number;
  describe(): Record<string, unknown>;
  checkInvariants(): { ok: boolean; issues: string[] };
  /** Relatório D-O15 / profiling do mundo (alimenta o optimizer). */
  optimizationReport(): Record<string, unknown>;
  /** Aplica estratégia de otimização (hardware/pressão) e retorna o efeito. */
  applyOptimization(): { ok: boolean; before: Record<string, unknown>; after: Record<string, unknown> };
}
