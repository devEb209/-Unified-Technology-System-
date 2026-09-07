-- ARKHER COLLABORATION :: Build & Continuous Validation
-- Incremental build graph for ARKHER projects: validation, codegen, packaging, tests and
-- release gates. Every build is content-hashed, so unchanged work is never redone.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local C = A:import("arkher/kernel/containers")
	local Build = {}
	Build.__index = Build

	function Build.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Build)
		self.graph = Kits.taskgraph({ incremental = opts.incremental ~= false })
		self.pipelines = {}
		self.gates = {}
		self.reports = {}
		self.stats = { builds = 0, passed = 0, failed = 0, gateBlocks = 0 }
		return self
	end

	function Build:task(id, spec) return self.graph.addTask(id, spec) end

	function Build:standardPipeline(project)
		local p = project or {}
		self:task("validate.project", { inputs = { p.name, p.version }, fn = function()
			if not p.name then error("project has no name") end
			return { ok = true, name = p.name }
		end })
		self:task("validate.assets", { deps = { "validate.project" }, inputs = { p.assetCount or 0 }, fn = function()
			return { checked = p.assetCount or 0, invalid = 0 }
		end })
		self:task("analyze.code", { deps = { "validate.project" }, inputs = { p.codeHash or 0 }, fn = function()
			return { files = p.fileCount or 0, diagnostics = p.diagnostics or 0 }
		end })
		self:task("run.tests", { deps = { "analyze.code" }, inputs = { p.testHash or 0 }, fn = function()
			local passed = p.testsPassed or 0
			local failed = p.testsFailed or 0
			if failed > 0 then error(failed .. " tests failed") end
			return { passed = passed, failed = failed }
		end })
		self:task("optimize.assets", { deps = { "validate.assets" }, inputs = { p.optimizeLevel or 1 }, fn = function()
			return { savedBytes = (p.assetBytes or 0) * 0.34 }
		end })
		self:task("package", { deps = { "run.tests", "optimize.assets" }, inputs = { p.version }, fn = function(artifacts)
			return { bundle = (p.name or "project") .. "-" .. (p.version or "1.0.0"),
				tests = artifacts["run.tests"] and artifacts["run.tests"].value or nil }
		end })
		self:task("publish", { deps = { "package" }, inputs = { p.channel or "dev" }, fn = function(artifacts)
			local pkg = artifacts["package"].value
			return { published = pkg.bundle, channel = p.channel or "dev" }
		end })
		self.pipelines.standard = { "validate.project", "validate.assets", "analyze.code", "run.tests",
			"optimize.assets", "package", "publish" }
		return self.pipelines.standard
	end

	function Build:addGate(id, fn, description)
		self.gates[id] = { fn = fn, description = description }
		return self
	end

	function Build:checkGates(context)
		local blocked = {}
		for id, gate in pairs(self.gates) do
			local ok, reason = gate.fn(context or {})
			if not ok then blocked[#blocked + 1] = { gate = id, reason = reason or gate.description } end
		end
		if #blocked > 0 then self.stats.gateBlocks = self.stats.gateBlocks + 1 end
		return #blocked == 0, blocked
	end

	function Build:run(only)
		self.stats.builds = self.stats.builds + 1
		local executed, err = self.graph.run(only)
		local report = { build = self.stats.builds, executed = executed, error = err,
			cacheHits = self.graph.stats().cacheHits }
		self.reports[#self.reports + 1] = report
		if err then self.stats.failed = self.stats.failed + 1 else self.stats.passed = self.stats.passed + 1 end
		return report
	end

	function Build:invalidate(taskId) return self.graph.invalidate(taskId) end
	function Build:artifact(taskId) return self.graph.artifact(taskId) end

	function Build:incrementalRatio()
		local s = self.graph.stats()
		local total = s.cacheHits + C.count(self.graph.tasks)
		if total == 0 then return 0 end
		return s.cacheHits / total
	end

	function Build:report()
		return { tasks = C.count(self.graph.tasks), pipelines = C.count(self.pipelines),
			gates = C.count(self.gates), stats = self.stats, graph = self.graph.stats(),
			incrementalRatio = self:incrementalRatio() }
	end

	return Build

end
