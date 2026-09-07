-- ARKHER SYSTEM T.0458 :: Behaviour Learning Utility Selection
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: utility (scored choice between competing courses of action)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0458"
	S.key = "arkher.ai.behaviourlearning.utility_selection"
	S.name = "Behaviour Learning Utility Selection"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Behaviour Learning"
	S.aspect = "Utility Selection"
	S.kit = "utility"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.behaviourlearning.working_memory" }
	S.tags = { "t", "behaviourlearning", "utility", "ai" }
	S.description = "Behaviour Learning Utility Selection: scored choice between competing courses of action for the Behaviour Learning subsystem."
	S.params = {
		backlogLimit = 42,
		baseRadius = 240,
		baseWeight = 0.74,
		bias = 0.34,
		biasWeight = 0.19,
		ceiling = 122,
		detailWeight = 0.34,
		failureTolerance = 4,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.74,
		minThrottle = 0.17,
		regressionSlope = 0.12,
		saturation = 0.94,
		scale = 2.4
	}
	S.features = { "addOption", "addConsideration", "score", "evaluate", "ranking", "stats", "buildOptions", "choose", "best", "margin", "optionNames", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("utility", { id = "arkher.ai.behaviourlearning.utility_selection", momentum = 0.14 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildOptions()
			if #inst.order > 0 then return #inst.order end
			inst.addOption("eat")
			inst.addConsideration("eat", "hunger",
				function(ctx) return 1 - (ctx.food or 1) end, "quadratic")
			inst.addOption("rest")
			inst.addConsideration("rest", "fatigue",
				function(ctx) return 1 - (ctx.energy or 1) end, "linear")
			inst.addOption("work")
			inst.addConsideration("work", "duty", function(ctx) return ctx.duty or 0 end, "linear")
			return #inst.order
		end
		function inst.choose(ctx, dt)
			inst.buildOptions()
			return inst.evaluate(ctx or {}, dt or 0)
		end
		function inst.best(ctx)
			inst.buildOptions()
			return inst.ranking(ctx or {})[1]
		end
		function inst.margin(ctx)
			inst.buildOptions()
			local ranking = inst.ranking(ctx or {})
			if #ranking < 2 then return 1 end
			return ranking[1].score - ranking[2].score
		end
		function inst.optionNames()
			inst.buildOptions()
			return inst.order
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
				engine.bus:subscribe("arkher.ai.behaviourlearning.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildOptions() == 3
		ok = ok and inst.choose({ food = 0.02, energy = 1, duty = 0 }, 0) == "eat"
		ok = ok and inst.choose({ food = 1, energy = 0.02, duty = 0 }, 0) == "rest"
		ok = ok and inst.best({ food = 1, energy = 1, duty = 0.9 }).name == "work"
		ok = ok and inst.margin({ food = 0.1, energy = 1, duty = 0 }) > 0
		return ok and #inst.optionNames() == 3 and inst.stats().evaluations >= 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
