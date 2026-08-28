// UTS :: singularity/platform-tools — CONNECTED SERVICES & APPS AS TOOLS.
//
// The platform AI reaches infrastructure through validated tools — never
// through free text. GitHub, research triangulation, apps and long-running
// creation projects all become tool calls the Core can plan and verify.

export function registerPlatformTools(core) {
  const platform = core.platform;
  if (!platform) throw new Error('registerPlatformTools needs core.platform');

  // ---- research (multi-model triangulated validation)
  core.tools.register('research.validate', {
    desc: 'Validate knowledge across multiple models (triangulation)',
    schema: { question: { type: 'string', required: true, maxLength: 300 } },
    fn: (p) => platform.research.validate(p.question),
  });

  // ---- github (connected service)
  core.tools.register('github.repo_info', {
    desc: 'Inspect the connected GitHub repository',
    schema: {},
    fn: async () => ({ ok: true, info: await platform.github.repoInfo() }),
  });
  core.tools.register('github.get_file', {
    desc: 'Read a file from the connected repository',
    schema: { path: { type: 'string', required: true, maxLength: 200 } },
    fn: async (p) => ({ ok: true, file: await platform.github.getFile(p.path) }),
  });
  core.tools.register('github.put_file', {
    desc: 'Write a file to the connected repository',
    schema: {
      path: { type: 'string', required: true, maxLength: 200 },
      content: { type: 'string', required: true, maxLength: 100000 },
      message: { type: 'string', maxLength: 200 },
    },
    fn: async (p) => ({ ok: true, ...(await platform.github.putFile(p.path, p.content, p.message)) }),
  });

  // ---- apps (platform applications — not everything is a world)
  core.tools.register('platform.app_install', {
    desc: 'Install a platform application',
    schema: {
      kind: { type: 'string', required: true, maxLength: 30 },
      name: { type: 'string', maxLength: 40 },
    },
    fn: async (p) => ({ ok: true, ...(await platform.apps.install(p)) }),
  });
  core.tools.register('platform.app_act', {
    desc: 'Perform an action on an installed app',
    schema: {
      appId: { type: 'string', required: true, maxLength: 20 },
      action: { type: 'string', required: true, maxLength: 30 },
      payload: { type: 'string', maxLength: 500 },
    },
    fn: async (p) => {
      let payload;
      try { payload = p.payload ? JSON.parse(p.payload) : undefined; } catch { payload = p.payload; }
      return { ok: true, view: await platform.apps.act(p.appId, p.action, payload) };
    },
  });

  // ---- long-running creation projects
  core.tools.register('projects.create', {
    desc: 'Start a durable, resumable creation project from a goal',
    schema: { goal: { type: 'string', required: true, maxLength: 300 }, name: { type: 'string', maxLength: 40 } },
    fn: (p) => platform.projects.create(p.goal, { name: p.name }),
  });
  core.tools.register('projects.run', {
    desc: 'Execute up to N steps of a creation project',
    schema: {
      projectId: { type: 'string', required: true, maxLength: 20 },
      maxSteps: { type: 'number', min: 1, max: 50, default: 10 },
    },
    fn: async (p) => {
      const { steps, summary, progress } = await platform.projects.run(p.projectId, { maxSteps: p.maxSteps });
      return { ok: true, steps, summary, progress };
    },
  });
  core.tools.register('projects.status', {
    desc: 'Inspect a creation project',
    schema: { projectId: { type: 'string', required: true, maxLength: 20 } },
    fn: (p) => ({ ok: true, project: platform.projects._get(p.projectId) }),
  });
}
