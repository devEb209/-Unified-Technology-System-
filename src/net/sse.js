// UTS :: net/sse — SERVER-SENT EVENTS parser (RFC-agnostic, minimal):
// feeds raw chunks (possibly split mid-line) and yields complete events.
// Used by the LLM proxy to know the truth about the stream (counts, done).
export function createSSEParser() {
  let buf = '';
  const events = [];
  let done = false;
  return {
    /** push a raw chunk (string or Buffer); extracts complete events */
    feed(chunk) {
      buf += typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8');
      let idx;
      while ((idx = buf.indexOf('\n\n')) >= 0) {
        const raw = buf.slice(0, idx);
        buf = buf.slice(idx + 2);
        const data = raw
          .split('\n')
          .filter((l) => l.startsWith('data:'))
          .map((l) => l.slice(5).replace(/^ /, ''))
          .join('\n');
        if (data === '[DONE]') { done = true; continue; }
        if (data) events.push(data);
      }
      return this;
    },
    events,
    get done() { return done; },
  };
}
