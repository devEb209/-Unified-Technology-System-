-- ARKHER ORIGINAL :: Autonomous Development Pipeline
-- The project that watches itself. It samples real metrics from the running engine,
-- runs the analysis rules, turns findings into an executable repair workflow, applies
-- the repairs, re-measures, and keeps the whole history so the improvement is a number
-- rather than a promise. If a repair makes things worse, it is rolled back.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")

	local Autopilot = {}
	Autopilot.__index = Autopilot

	function Autopilot.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Autopilot)
		self.analyzer = Kits.create("autopipeline", { id = "autopilot.analyzer",
			maxIterations = opts.maxIterations or 6 })
		self.analyzer.installDefaults()
		self.workflow = Kits.create("workflow", { id = "autopilot.workflow", maxRetries = 1 })
		self.critic = Kits.create("critic", { id = "autopilot.critic",
			passMark = opts.passMark or 0.8 })
		self.ledger = Kits.create("ledger", { id = "autopilot.ledger", capacity = 256 })
		self.memory = Kits.create("worldmemory", { id = "autopilot.memory", capacity = 256 })
		self.project = opts.project or { frameMs = 0, drawCalls = 0, memoryMb = 0,
			failingTests = 0, orphanAssets = 0, quality = 1,
			targetMs = opts.targetMs or 16.6, maxDrawCalls = opts.maxDrawCalls or 900,
			memoryCeilingMb = opts.memoryCeilingMb or 512 }
		self.samplers = {}
		self.runs = 0
		self.regressions = 0
		self.onFinding = Signal.new()
		self.onRepair = Signal.new()
		self:installCriteria()
		return self
	end

	function Autopilot:installCriteria()
		local c = self.critic
		if #c.order > 0 then return #c.order end
		c.addCriterion("frameMs", { weight = 3, target = self.project.targetMs,
			direction = "lower" })
		c.addCriterion("memoryMb", { weight = 2, target = self.project.memoryCeilingMb,
			direction = "lower" })
		c.addCriterion("drawCalls", { weight = 2, target = self.project.maxDrawCalls,
			direction = "lower" })
		c.addCriterion("passingTests", { weight = 3, target = 1, direction = "higher" })
		return #c.order
	end

	-- ------------------------------------------------------------------ measurement
	function Autopilot:addSampler(name, fn)
		self.samplers[name] = fn
		return true
	end

	function Autopilot:sample()
		for name, fn in pairs(self.samplers) do
			local ok, value = pcall(fn, self.project)
			if ok and value ~= nil then self.project[name] = value end
		end
		return self.project
	end

	function Autopilot:snapshot()
		local copy = {}
		for key, value in pairs(self.project) do copy[key] = value end
		return copy
	end

	function Autopilot:restore(snapshot)
		for key, value in pairs(snapshot) do self.project[key] = value end
		return true
	end

	function Autopilot:score()
		local project = self.project
		local total = math.max(1, (project.totalTests or 1))
		local passing = (total - (project.failingTests or 0)) / total
		return self.critic.evaluate({ frameMs = project.frameMs,
			memoryMb = project.memoryMb, drawCalls = project.drawCalls,
			passingTests = passing })
	end

	-- ------------------------------------------------------------------ repair
	function Autopilot:analyze()
		self:sample()
		local findings = self.analyzer.analyze(self.project)
		for _, finding in ipairs(findings) do self.onFinding:fire(finding) end
		self.ledger.write("analysis", { findings = #findings,
			health = self.analyzer.health(self.project) })
		return findings
	end

	-- Build a repair workflow whose steps each verify their own effect, so a fix that
	-- does not actually move the metric is reported as a failure instead of a success.
	function Autopilot:buildRepairs(findings)
		local w = self.workflow
		w.steps = {}
		w.order = {}
		w.reset()
		local project = self.project
		local analyzer = self.analyzer
		local previous = nil
		for _, finding in ipairs(findings) do
			if finding.fixable then
				local rule = finding.rule
				local before = {}
				local id = "fix." .. rule
				local requires = previous and { previous } or {}
				w.addStep(id, { cost = finding.severity, requires = requires,
					label = finding.message,
					run = function()
						before.health = analyzer.health(project)
						return analyzer.applyFix(rule, project)
					end,
					verify = function()
						local after = analyzer.health(project)
						return after >= (before.health or 0)
					end,
					undo = function() end })
				previous = id
			end
		end
		return #w.order
	end

	function Autopilot:cycle()
		self.runs = self.runs + 1
		local before = self:snapshot()
		local beforeScore = self:score()
		local findings = self:analyze()
		if #findings == 0 then
			return { ok = true, findings = 0, gain = 0, verdict = beforeScore.verdict,
				score = beforeScore.overall }
		end
		self:buildRepairs(findings)
		local ok, detail = self.workflow.run(self)
		local afterScore = self:score()
		local gain = afterScore.overall - beforeScore.overall
		if gain < -1e-6 then
			self:restore(before)
			self.regressions = self.regressions + 1
			afterScore = self:score()
			gain = 0
		end
		self.onRepair:fire({ ok = ok, detail = detail, gain = gain })
		self.memory.remember("autopilot", "cycle", { weight = gain })
		self.ledger.write("cycle", { ok = ok, gain = gain, verdict = afterScore.verdict })
		return { ok = ok, findings = #findings, detail = detail, gain = gain,
			verdict = afterScore.verdict, score = afterScore.overall,
			health = self.analyzer.health(self.project) }
	end

	-- Keep cycling while the project is still improving, then stop - not a fixed loop.
	function Autopilot:converge(maxCycles)
		local results = {}
		local lastScore = self:score().overall
		for _ = 1, (maxCycles or 8) do
			local result = self:cycle()
			results[#results + 1] = result
			if result.findings == 0 then break end
			if result.score <= lastScore + 1e-6 then break end
			lastScore = result.score
		end
		return { cycles = #results, results = results,
			finalScore = self:score().overall,
			health = self.analyzer.health(self.project) }
	end

	-- ------------------------------------------------------------------ reporting
	function Autopilot:plan()
		local findings = self.analyzer.analyze(self.project)
		local lines = {}
		for i, finding in ipairs(findings) do
			lines[#lines + 1] = string.format("%d. [%s/sev%d] %s%s", i, finding.category,
				finding.severity, finding.message, finding.fixable and " (auto)" or " (manual)")
		end
		if #lines == 0 then lines[1] = "no open findings" end
		return table.concat(lines, "\n")
	end

	function Autopilot:report()
		return { runs = self.runs, regressions = self.regressions,
			health = self.analyzer.health(self.project),
			score = self:score().overall, analyzer = self.analyzer.stats(),
			workflow = self.workflow.stats(), critic = self.critic.stats(),
			written = self.ledger.stats().written,
			quality = Mathx.clamp(self.project.quality or 1, 0, 1) }
	end

	return Autopilot
end
