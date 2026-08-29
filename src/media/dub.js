// UTS :: media/dub — AUTO-DUBBING: a script becomes per-language cue lists
// with real speech timing (chars per second per language), ready for the
// speech engine. Honest: the phrasebook covers core lines; unknown lines
// pass through untranslated (marked), never fake-translated.
export const LANGS = Object.freeze({
  'pt-BR': { rate: 14, name: 'Português (Brasil)' },
  'en': { rate: 15, name: 'English' },
  'es': { rate: 15, name: 'Español' },
  'ja': { rate: 7.5, name: '日本語' },
});

const BOOK = {
  'olá': { en: 'hello', es: 'hola', ja: 'こんにちは' },
  'mundo': { en: 'world', es: 'mundo', ja: '世界' },
  'fogo': { en: 'fire', es: 'fuego', ja: '火' },
  'água': { en: 'water', es: 'agua', ja: '水' },
  'vamos': { en: "let's go", es: 'vamos', ja: '行こう' },
  'perigo': { en: 'danger', es: 'peligro', ja: '危険' },
};

export function translateLine(line, lang) {
  if (lang === 'pt-BR' || !LANGS[lang]) return { text: line, translated: lang === 'pt-BR' };
  let out = line, hits = 0;
  for (const [pt, to] of Object.entries(BOOK)) {
    // \b é ASCII: 'á' não é word char e quebra a borda. Usar borda Unicode real.
    const re = new RegExp(`(?<![\\p{L}\\p{N}_])${pt}(?![\\p{L}\\p{N}_])`, 'giu');
    if (re.test(out)) { out = out.replace(re, to[lang] ?? pt); hits++; }
  }
  return { text: out, translated: hits > 0, untranslated: hits === 0 };
}

/**
 * Script (array of { who, line, at }) → per-language dub cues with timing
 * (duration = chars / language rate, min 0.6s), deterministic.
 */
export function dubScript(script, langs = Object.keys(LANGS)) {
  const cues = {};
  for (const lang of langs) {
    if (!LANGS[lang]) throw new Error(`idioma desconhecido: ${lang}`);
    cues[lang] = script.map((s) => {
      const tr = translateLine(s.line, lang);
      const dur = Math.max(0.6, tr.text.length / LANGS[lang].rate);
      return { who: s.who ?? 'narrator', at: s.at ?? 0, dur, text: tr.text, translated: tr.translated };
    });
  }
  return { langs, cues };
}
