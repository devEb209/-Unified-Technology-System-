/**
 * UTS — Unified Technology System · API pública.
 *
 * Hierarquia (versão mais recente das decisões):
 *   UTS (arquitetura maior) ⊃ RRW (representação) + Tese dos D + D-O15 +
 *                             Singularity AI (Core/registries/memória)
 *   UES (aplicação principal) = Engine + World + NMN + Sociedade + Gráficos
 */

// núcleo
export * from './core/index.ts';
// representação da realidade
export * from './rrw/index.ts';
// tese dos D
export * from './d/index.ts';
// otimização
export * from './d-o15/index.ts';
// contratos (IA ↔ mundo)
export type * from './contracts.ts';
// singularity ai
export * from './ai/memory.ts';
export * from './ai/registries.ts';
export * from './ai/core.ts';
// ues
export * from './ues/world.ts';
export * from './ues/npc.ts';
export * from './ues/society.ts';
export * from './ues/graphics.ts';
export * from './ues/engine.ts';
