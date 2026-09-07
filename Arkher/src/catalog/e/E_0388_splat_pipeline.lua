-- ARKHER SYSTEM E.0388 :: Terrain Splat Authoring Pipeline
-- Category E - MATERIALS
-- ARKHER Material Framework capability: how every surface in the world is defined, layered, worn and afforded.
-- Kit: pipeline (ordered authoring and bake stages)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "E.0388"
	S.key = "arkher.material.splat.authoring_pipeline"
	S.name = "Terrain Splat Authoring Pipeline"
	S.category = "E"
	S.family = "MATERIALS"
	S.area = "Terrain Splat"
	S.aspect = "Authoring Pipeline"
	S.kit = "pipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.material.splat.analysis" }
	S.tags = { "e", "splat", "pipeline", "material" }
	S.description = "Terrain Splat Authoring Pipeline: ordered authoring and bake stages for the Terrain Splat subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 280,
		baseWeight = 0.87,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 335,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.82,
		scale = 3.7
	}
	S.features = { "addStage", "disable", "enable", "run", "stageNames", "stats", "installDefaults", "process", "benchmark", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("pipeline", { id = "arkher.material.splat.authoring_pipeline", budgetMs = 4.00 })
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
				engine.bus:subscribe("arkher.material.splat.*", function(payload) inst.lastSignal = payload end)
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
