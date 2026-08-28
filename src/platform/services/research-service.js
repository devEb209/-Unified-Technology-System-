// UTS :: platform/services/research — TRIANGULATED RESEARCH SERVICE.
//
// Architecture requirement: the platform validates knowledge through
// MULTIPLE models (target: 3) over web/search results, comparing answers
// and keeping consensus — never trusting a single source.
//
//   question → search(query) → [model1, model2, …modelN] → normalize →
//   group → consensus + agreement + conflicts → verdict
//
// Search backends are pluggable (SearchProvider interface); tests use a
// deterministic in-memory corpus. No fabricated sources: when models are
// missing the verdict says `triangulated: false`.

export class ResearchError extends Error {}

function normalize(text) {
  return String(text ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** deterministic in-memory search backend (tests / offline) */
export class MemorySearchProvider {
  constructor(corpus = []) {
    this.corpus = corpus; // [{title, snippet, url}]
  }
  async search(query) {
    const terms = normalize(query).split(' ').filter(t => t.length > 2);
    return this.corpus
      .map(doc => ({
        doc,
        score: terms.filter(t => normalize(doc.title + ' ' + doc.snippet).includes(t)).length,
      }))
      .filter(x => x.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)
      .map(x => x.doc);
  }
}

export class ResearchService {
  constructor({ providers = [], search = null, minModels = 3, minAgreement = 0.66 } = {}) {
    this.name = 'research';
    this.providers = providers;      // [{name, generate(), capabilities()}]
    this.search = search;            // SearchProvider | null
    this.minModels = minModels;
    this.minAgreement = minAgreement;
    this.history = [];
  }

  setProviders(providers) { this.providers = providers; }
  setSearch(search) { this.search = search; }

  capabilities() { return ['multi-model-validation', 'search', 'consensus']; }

  status() {
    return {
      models: this.providers.length,
      search: this.search ? 'attached' : 'none',
      validations: this.history.length,
    };
  }

  _researchMessages(question, snippets) {
    const sys = {
      role: 'system',
      content:
        'You are one of several independent research models of the UTS platform. ' +
        'Answer the question strictly as JSON: {"answer": "<concise factual answer>", "confidence": <0..1>}. ' +
        'Base yourself ONLY on the question and the provided search snippets. JSON only.',
    };
    const msgs = [sys, { role: 'user', content: snippets.length > 0
      ? `Search snippets:\n${snippets.map(s => `- ${s.title}: ${s.snippet}`).join('\n')}\n\nQuestion: ${question}`
      : `Question: ${question}` }];
    return msgs;
  }

  /**
   * Ask every available structured model, group answers, return consensus.
   * Deterministic given deterministic providers (heuristic/tests).
   */
  async validate(question) {
    if (!question || typeof question !== 'string') throw new ResearchError('question required');
    const snippets = this.search ? await this.search.search(question) : [];
    const answers = [];
    for (const provider of this.providers) {
      try {
        const res = await provider.generate({ messages: this._researchMessages(question, snippets), json: true });
        if (res.json?.answer != null) {
          answers.push({
            model: provider.name,
            answer: String(res.json.answer).slice(0, 300),
            confidence: Number(res.json.confidence ?? 0.5),
          });
        }
      } catch {
        answers.push({ model: provider.name, answer: null, error: 'provider failed' });
      }
    }
    const valid = answers.filter(a => a.answer != null);
    const groups = new Map();
    for (const a of valid) {
      const key = normalize(a.answer);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(a);
    }
    const sorted = [...groups.values()].sort((x, y) => y.length - x.length);
    const top = sorted[0] ?? [];
    const consensus = top[0]?.answer ?? null;
    const agreement = valid.length > 0 ? top.length / valid.length : 0;
    const conflicts = sorted.slice(1).map(g => ({ answer: g[0].answer, models: g.map(m => m.model) }));
    const verdict = {
      question,
      snippets: snippets.length,
      modelsAsked: this.providers.length,
      modelsAnswered: valid.length,
      answers,
      consensus,
      agreement: Number(agreement.toFixed(3)),
      conflicts,
      triangulated: valid.length >= this.minModels && agreement >= this.minAgreement,
    };
    this.history.push({ question, consensus, agreement: verdict.agreement, triangulated: verdict.triangulated });
    if (this.history.length > 64) this.history.shift();
    return verdict;
  }

  async health() {
    return this.providers.length > 0 ? 'ok' : 'no-providers';
  }
}
