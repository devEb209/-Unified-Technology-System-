-- ARKHER SYSTEM I.0308 :: Aim Offset Playback Pipeline
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: pipeline (ordered sample, blend, ik and output stages)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0308"
	S.key = "arkher.anim.aimoffset.playback_pipeline"
	S.name = "Aim Offset Playback Pipeline"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Aim Offset"
	S.aspect = "Playback Pipeline"
	S.kit = "pipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.aimoffset.event_ledger" }
	S.tags = { "i", "aimoffset", "pipeline", "anim" }
	S.description = "Aim Offset Playback Pipeline: ordered sample, blend, ik and output stages for the Aim Offset subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 280,
		baseWeight = 0.71,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 211,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "addStage", "disable", "enable", "run", "stageNames", "stats", "installDefaults", "process", "benchmark", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("pipeline", { id = "arkher.anim.aimoffset.playback_pipeline", budgetMs = 8.00 })
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
				engine.bus:subscribe("arkher.anim.aimoffset.*", function(payload) inst.lastSignal = payload end)
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
