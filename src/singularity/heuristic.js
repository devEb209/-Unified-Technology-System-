// UTS :: singularity/heuristic — HeuristicProvider.
// NOT an LLM (honest by design). Deterministic offline interpretation used
// for tests, offline operation and as the FINAL fallback of the Core.

function deaccent(s) {
  return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export class HeuristicProvider {
  constructor() {
    this.name = 'heuristic';
    this.counter = 0;
  }

  capabilities() {
    return { text: true, reasoning: false, code: false, vision: false, structured: true, tools: false, context: 8000 };
  }

  cost() { return 0; }
  async availability() { return true; }

  async generate({ messages }) {
    const objective = [...messages].reverse().find(m => m.role === 'user')?.content ?? '';
    const text = deaccent(String(objective)).toLowerCase();
    this.counter++;
    const interpretation = this.interpret(text, String(objective));
    return { text: JSON.stringify(interpretation), json: interpretation };
  }

  interpret(text, original = text) {
    // settlement? (name extracted from the ORIGINAL objective, preserving case)
    const nameMatch = original.match(/chamad[ao]\s+"?([\p{L}\p{N}][\p{L}\p{N}\s'-]{1,30})"?/iu);
    if (/\b(vila|village|cidade|city|town|povoado|settlement|povoacao)\b/.test(text)) {
      const nearRiver = /(rio|river|agua|lago|lake|praia)/.test(text);
      let pop = 24;
      const digit = text.match(/(\d{1,4})\s*(habitantes|pessoas|npcs?|moradores)/);
      if (digit) pop = Math.max(1, parseInt(digit[1], 10));
      else if (/\bgrande|large|big\b/.test(text)) pop = 120;
      else if (/\bmedia|m[eé]dia|medium\b/.test(text)) pop = 60;
      return { intent: 'create_settlement', params: { name: nameMatch ? nameMatch[1].trim() : `Nova Aurora ${this.counter}`, pop, nearRiver } };
    }
    // weather?
    if (/(tempestade|storm)/.test(text)) return { intent: 'set_weather', params: { weather: 'storm' } };
    if (/(chuva|rain|chover)/.test(text)) return { intent: 'set_weather', params: { weather: 'rain' } };
    if (/(vento|windy|ventania)/.test(text)) return { intent: 'set_weather', params: { weather: 'windy' } };
    if (/(poeira|dust|poeiral)/.test(text)) return { intent: 'set_weather', params: { weather: 'dust' } };
    if (/(limp[ao]|ensolarad|clear|sun)/.test(text)) return { intent: 'set_weather', params: { weather: 'clear' } };
    // population?
    const npcs = text.match(/(\d{1,4})\s*(npcs?|habitantes|pessoas)/);
    if (/(spawn|criar|adicionar|gerar)/.test(text) && npcs) {
      return { intent: 'spawn_population', params: { count: parseInt(npcs[1], 10) } };
    }
    // fire?
    if (/(fogo|fire|incendio)/.test(text)) return { intent: 'start_fire', params: {} };
    // camera?
    if (/(camer[ao]|camera|foco|focus|olhar)/.test(text)) return { intent: 'focus_camera', params: {} };
    return { intent: 'unknown', params: { objective: text.slice(0, 200) } };
  }

  toString() { return 'HeuristicProvider(deterministic-offline)'; }
}
