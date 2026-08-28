// UTS :: ues/rules — experience rulesets. Genres/experience kinds are
// CONFIGURATIONS of engine systems, not new engines.

export class ExperienceError extends Error {}

export const ENGINE_SYSTEMS = Object.freeze([
  'weather', 'ecology', 'economy', 'trade', 'nmn', 'movement', 'physics',
  'materializer', 'streaming', 'deferred',
]);
