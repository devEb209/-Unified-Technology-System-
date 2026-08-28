// UTS :: core/log — leveled logger. Never logs secrets (providers mask themselves).

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

export class Logger {
  constructor({ level = 'info', sink = null } = {}) {
    this.level = LEVELS[level] ?? LEVELS.info;
    this.sink = sink ?? ((lvl, msg, data) => {
      const fn = lvl === 'error' ? console.error : lvl === 'warn' ? console.warn : console.log;
      if (data !== undefined) fn(`[uts:${lvl}] ${msg}`, data);
      else fn(`[uts:${lvl}] ${msg}`);
    });
    this.children = [];
  }

  child(prefix) {
    const c = new Logger({ level: Object.keys(LEVELS).find(k => LEVELS[k] === this.level), sink: this.sink });
    c.prefix = (this.prefix ?? '') + prefix;
    return c;
  }

  setLevel(level) { this.level = LEVELS[level] ?? this.level; }

  log(lvl, msg, data) {
    if ((LEVELS[lvl] ?? 0) < this.level) return;
    this.sink(lvl, (this.prefix ?? '') + msg, data);
  }

  debug(msg, data) { this.log('debug', msg, data); }
  info(msg, data) { this.log('info', msg, data); }
  warn(msg, data) { this.log('warn', msg, data); }
  error(msg, data) { this.log('error', msg, data); }
}
