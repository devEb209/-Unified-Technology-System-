-- ARKHER SYSTEM B.0443 :: Log Viewer Tool Pipeline
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: pipeline (staged tool execution with isolation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0443"
	S.key = "arkher.studio.logviewer.tool_pipeline"
	S.name = "Log Viewer Tool Pipeline"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Log Viewer"
	S.aspect = "Tool Pipeline"
	S.kit = "pipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.logviewer.registry" }
	S.tags = { "b", "logviewer", "pipeline", "studio" }
	S.description = "Log Viewer Tool Pipeline: staged tool execution with isolation for the Log Viewer subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 240,
		baseWeight = 0.96,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 374,
		detailWeight = 0.46,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.23,
		regressionSlope = 0.08,
		saturation = 0.91,
		scale = 3.6
	}
	S.features = { "addStage", "disable", "enable", "run", "stageNames", "stats", "installDefaults", "process", "benchmark", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("pipeline", { id = "arkher.studio.logviewer.tool_pipeline", budgetMs = 8.00 })
		inst.system = S
		inst.ctx = ctx

	function inst.installDefaults()
		inst.addStage("normalize", function(v) 
			if type(v) == "number" then return math.max(0, v) end
			return v
		end)
		inst.addStage("scale", function(v)
			if type(v) == "number" then return v * S.params.scale end
			return v
		end)
		inst.addStage("clamp", function(v)
			if type(v) == "number" then return math.min(v, S.params.ceiling) end
			return v
		end)
		return inst
	end
	function inst.process(value, ctx) return inst.run(value, ctx) end
	function inst.benchmark(iterations)
		local total = 0
		for i = 1, (iterations or 32) do
			local v = inst.run(i)
			if type(v) == "number" then total = total + v end
		end
		return total / math.max(1, iterations or 32)
	end

		function inst.describe()
			return { id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return { system = S.key, status = status, stats = st }
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("arkher.studio.logviewer.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local out = inst.run(-4)
		local ok = out == 0
		local out2 = inst.run(2)
		ok = ok and out2 == math.min(2 * S.params.scale, S.params.ceiling)
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
