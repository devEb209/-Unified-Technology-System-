// UTS :: singularity/grammar — THE CREATION GRAMMAR (R5).
//
//   reality question first: WHAT DID THE USER ACTUALLY SAY TO BUILD?
//
// Natural language is an INTERFACE to reality creation, so it deserves a
// real grammar: composable, deterministic, auditable. This module parses
// (Portuguese-first) creation objectives into a LIST of structured commands
// with relations ("perto do rio", "ao norte de X", "em nome do anexo").
// It is NOT an LLM and does not pretend to be one: every accepted command
// cites the fragment that produced it (`source`), so the plan is checkable
// character by character. Attachments (text/csv/image) are validated and
// woven into the parse — an attachment is CONTEXT, never an excuse.

function deaccent(s) {
  return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

const ENTITY_WORDS = 'vila|cidade|povoado|aldeia|settlement|town|floresta|forest';

/** command starters: a new clause begins after "e/depois/então" + one of these */
const STARTER = "(?:cri[ae]|funde|construa|adicione|ger[ae]|incendeie|queime|mude|plante|spawne"
  + "|\\d+\\s*(?:npcs?|habitantes|moradores|arvores|trees)"
  + "|clima\\b|uma?\\s+(?:vila|cidade|povoado|aldeia|floresta)"
  + "|tempestade\\b|chuva\\b|vento\\b|poeira\\b|fogo\\b|floresta\\b|npcs?\\b)";

/** split into creation clauses ("crie X e depois Y", "… e 15 npcs" → [X, Y, …]) */
function clauses(text) {
  const t = deaccent(String(text)).toLowerCase();
  return t
    .split(new RegExp(`\\be\\s+(?:depois\\s+|ent[aã]o\\s+)?(?=${STARTER})|;|\\.\\s+`, 'u'))
    .map(c => c.trim()).filter(c => c.length > 0);
}

function countNear(t, words) {
  const m = t.match(new RegExp(`(\\d{1,4})\\s*(?:${words})`));
  return m ? Math.max(1, parseInt(m[1], 10)) : null;
}

function quotedName(t, original) {
  // 1) a DIRECT quoted name in this clause ("crie a vila \"X\"") — the
  // quotes ARE the naming; no 'chamada' needed
  const dq = t.match(/"([^"]{1,40})"/u);
  if (dq) return dq[1].trim();
  // 2) ALL "chamada X" candidates in the original (casing preserved); the name
  // ENDS at a stop word. A candidate belongs to THIS clause only if every
  // word of it appears in the clause (deaccented) — no cross-clause leaks.
  const names = [...original.matchAll(/chamad[ao]\s+"?([\p{L}\p{N}][\p{L}\p{N}\s'-]{1,30}?)"?\s*(?=\b(?:com|perto|ao|na|no|e[,\s]|,)|\s*\d|$)/giu)];
  for (const m of names) {
    const cleaned = m[1].trim().replace(/\s+(?:com|perto|ao|na|no|e)$/i, '').trim();
    if (cleaned && t.includes('chamada ' + deaccent(cleaned).toLowerCase())) return cleaned;
  }
  return null;
}

function nearOf(t) {
  const m = t.match(/perto\s+(?:d[aeo]|do|da)\s+(.+)$/u);
  if (!m) return null;
  const rest = m[1].trim();
  // nature anchors are known words; anything else is a NAMED anchor (the
  // rest of the clause — clauses end after their relation)
  if (/^(rio|lago|mar|praia|floresta)\b/.test(rest)) return { kind: 'nature', what: rest.split(/\s+/)[0] };
  const named = rest.replace(/["]/g, '').trim();
  if (named) return { kind: 'named', what: named };
  return null;
}

function directionOf(t) {
  const m = t.match(/(?:ao|a)\s+(norte|sul|leste|oeste)\s+d[eo]\s+(.+)$/u);
  if (!m) return null;
  const of = m[2].replace(/["]/g, '').trim();
  return of ? { dir: m[1], of } : null;
}

/**
 * Parse a creation objective (+ validated attachments) into commands.
 * Returns { commands: [{ intent, params, source }], unknown: [fragment] }.
 */
export function parseCreation(objective, { attachments = [] } = {}) {
  const original = String(objective);
  const commands = [];
  const unknown = [];

  // ---- attachments are validated CONTEXT woven into the parse
  const nameList = [];
  const csvRows = [];
  for (const att of attachments) {
    if (att.kind === 'text' && /nomes?/i.test(att.name ?? '')) {
      for (const line of String(att.content).split(/[\n,;]+/)) {
        const n = line.trim();
        if (n && n.length <= 40) nameList.push(n);
      }
    }
    if (att.kind === 'csv') {
      const lines = String(att.content).trim().split(/\n+/);
      const head = (lines[0] ?? '').toLowerCase();
      if (/x\s*,\s*z/.test(head)) {
        for (const line of lines.slice(1)) {
          const cols = line.split(',').map(c => c.trim());
          const x = Number(cols[0]), z = Number(cols[1]);
          if (Number.isFinite(x) && Number.isFinite(z)) {
            csvRows.push({ x, z, name: cols[2] ?? null, pop: Number(cols[3]) || 12 });
          }
        }
      }
    }
    // kind 'image' is honestly recorded but NOT pretended to be seen
    // (the offline providers declare vision:false — no fake perception).
  }

  // CSV rows become explicit settlements (positions are DATA, auditable)
  for (const row of csvRows.slice(0, 24)) {
    commands.push({
      intent: 'create_settlement',
      params: { name: row.name ?? `Vila CSV ${commands.length + 1}`, pop: row.pop, pos: [row.x, 0, row.z] },
      source: `csv:(${row.x},${row.z})`,
    });
  }

  for (const clause of clauses(original)) {
    const src = clause.slice(0, 60);
    // ---- settlement?
    if (new RegExp(`\\b(${ENTITY_WORDS})\\b`).test(clause) && /\b(vila|cidade|povoado|aldeia|settlement|town)\b/.test(clause)) {
      const name = quotedName(clause, original) ?? (nameList.length ? nameList.shift() : null);
      const pop = countNear(clause, 'habitantes|pessoas|moradores') ?? (/\bgrande|big\b/.test(clause) ? 120 : /\bm[eé]dia\b/.test(clause) ? 60 : 24);
      commands.push({
        intent: 'create_settlement',
        params: {
          ...(name ? { name } : {}),
          pop,
          nearRiver: /(rio|lago|mar|praia)/.test(clause),
          ...(nearOf(clause)?.kind === 'named' ? { nearName: nearOf(clause).what } : {}),
          ...(directionOf(clause) ?? {}),
        },
        source: src,
      });
      continue;
    }
    // ---- forest (REAL ecology, not a color)
    if (/\bfloresta\b/.test(clause) || (/\bplante\b/.test(clause) && /\b(arvore|árvores|trees|floresta)/.test(clause))) {
      const count = countNear(clause, 'arvores|árvores|trees') ?? 40;
      commands.push({ intent: 'plant_forest', params: { count }, source: src });
      continue;
    }
    // ---- weather
    if (/(clima|tempo|tempo\b|chov[ae]|tempestade|vento|poeira|limp[ao]|ensolarado)/.test(clause)) {
      const weather = /tempestade/.test(clause) ? 'storm'
        : /(chuva|chov)/.test(clause) ? 'rain'
        : /vento|ventania/.test(clause) ? 'windy'
        : /poeira/.test(clause) ? 'dust'
        : /(limp|ensolarad|sol\b)/.test(clause) ? 'clear' : null;
      if (weather) { commands.push({ intent: 'set_weather', params: { weather }, source: src }); continue; }
    }
    // ---- population
    const npcs = countNear(clause, 'npcs?|habitantes|pessoas|moradores');
    if (/\b(npcs?|popula[cç][aã]o|habitantes|moradores)\b/.test(clause) && npcs && !commands.some(c => c.intent === 'create_settlement' && c.source === src)) {
      const em = clause.match(/em\s+"?([\p{L}\p{N}\s'-]{1,30})"?/u);
      commands.push({ intent: 'spawn_population', params: { count: npcs, ...(em ? { settlementName: em[1].trim() } : {}) }, source: src });
      continue;
    }
    // ---- fire
    if (/\b(fogo|inc[eê]ndio|queime|incendeie)\b/.test(clause)) {
      const pos = clause.match(/\bem\s+\(?(-?\d{1,4})\s*[,;]\s*(-?\d{1,4})\)?/);
      commands.push({ intent: 'start_fire', params: pos ? { pos: [Number(pos[1]), 0, Number(pos[2])] } : {}, source: src });
      continue;
    }
    // ---- camera
    if (/\b(camer[ao]|foco|focalize|mostre)\b/.test(clause)) {
      const em = clause.match(/(?:em|na|no)\s+"?([\p{L}\p{N}\s'-]{1,30})"?/u);
      commands.push({ intent: 'focus_camera', params: em ? { settlementName: em[1].trim() } : {}, source: src });
      continue;
    }
    if (clause.length > 2) unknown.push(clause.slice(0, 80));
  }

  // remaining attachment names → one settlement each (explicitly cited)
  for (const n of nameList) {
    commands.push({ intent: 'create_settlement', params: { name: n, pop: 12 }, source: `anexo:nome "${n}"` });
  }

  return { commands, unknown };
}
