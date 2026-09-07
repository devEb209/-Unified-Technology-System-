-- ARKHER SYSTEM A.0328 :: Environment Pipeline
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: pipeline (staged processing with isolation and retries)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0328"
	S.key = "arkher.core.environment.pipeline"
	S.name = "Environment Pipeline"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Environment"
	S.aspect = "Pipeline"
	S.kit = "pipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.core.environment.registry" }
	S.tags = { "a", "environment", "pipeline", "core" }
	S.description = "Environment Pipeline: staged processing with isolation and retries for the Environment subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 400,
		baseWeight = 0.5,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 474,
		detailWeight = 0.5,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.1,
		regressionSlope = 0.1,
		saturation = 0.7,
		scale = 1.0
	}
	S.features = { "addStage", "disable", "enable", "run", "stageNames", "stats", "installDefaults", "process", "benchmark", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("pipeline", { id = "arkher.core.environment.pipeline", budgetMs = 5.00 })
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
				engine.bus:subscribe("arkher.core.environment.*", function(payload) inst.lastSignal = payload end)
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
