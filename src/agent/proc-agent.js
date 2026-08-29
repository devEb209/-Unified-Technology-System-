// UTS :: agent/proc — the AI EXECUTES COMMANDS on the connected machine
// (the user's desktop or their own phone via the server). Denylist of
// catastrophic patterns + per-run timeout + captured output + audit trail.
// The SERVER gates this behind UTS_ALLOW_EXEC=1 (honest default: off).

import { spawn } from 'node:child_process';

const FORBIDDEN = [
  /rm\s+-rf\s+\/(?:\s|$)/,          // rm -rf /
  /mkfs/, /:\(\)\{.*\};:/,          // fork bomb
  /dd\s+if=\/dev\/(?:zero|random)\s+of=\/dev\/[sh]d/,
  />\s*\/dev\/[sh]da/,               // overwrite disk
  /shutdown|reboot|halt|poweroff/i,
];

export class ProcAgent {
  constructor({ shell = '/bin/sh', timeoutMs = 20000, allow = false } = {}) {
    this.shell = shell;
    this.timeoutMs = timeoutMs;
    this.allow = !!allow; // executor opt-in (o dono da máquina decide)
    this.history = [];
  }

  /** run a command: { cmd, args } or a shell line. Honest errors, never fake. */
  run(line, { cwd, timeoutMs = null } = {}) {
    if (!this.allow) return Promise.resolve({ ok: false, error: 'execução desabilitada (UTS_ALLOW_EXEC=1 liga)' });
    if (FORBIDDEN.some((r) => r.test(line))) {
      return Promise.resolve({ ok: false, error: 'comando proibido pelo guarda de segurança' });
    }
    return new Promise((res) => {
      const p = spawn(this.shell, ['-c', line], { cwd, env: { ...process.env } });
      let out = '', err = '';
      const timer = setTimeout(() => { p.kill('SIGKILL'); }, timeoutMs ?? this.timeoutMs);
      p.stdout.on('data', (d) => { out += d; if (out.length > 200000) out = out.slice(-100000); });
      p.stderr.on('data', (d) => { err += d; if (err.length > 100000) err = err.slice(-50000); });
      p.on('close', (code, signal) => {
        clearTimeout(timer);
        const r = { ok: code === 0 && signal !== 'SIGKILL', code, signal: signal ?? null, out, err, cmd: line };
        this.history.push({ ...r, at: Date.now() });
        if (this.history.length > 200) this.history.shift();
        res(r);
      });
      p.on('error', (e) => { clearTimeout(timer); res({ ok: false, error: e.message, cmd: line }); });
    });
  }

  tools() {
    const t = this;
    return {
      'proc.run': {
        desc: 'executa um comando na máquina conectada (com guarda e timeout)',
        schema: { cmd: { type: 'string' }, cwd: { type: 'string' } },
        fn: async (p) => t.run(String(p.cmd ?? '').slice(0, 2000), { cwd: p.cwd }),
      },
    };
  }
}
