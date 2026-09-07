-- ARKHER SYSTEM K.0301 :: Attention Utility Reasoning
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: utility (scored option selection with response curves)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0301"
	S.key = "arkher.npc.attention.utility_reasoning"
	S.name = "Attention Utility Reasoning"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Attention"
	S.aspect = "Utility Reasoning"
	S.kit = "utility"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.attention.reactive_behaviour" }
	S.tags = { "k", "attention", "utility", "npc" }
	S.description = "Attention Utility Reasoning: scored option selection with response curves for the Attention subsystem."
	S.params = {
		backlogLimit = 41,
		baseRadius = 520,
		baseWeight = 0.63,
		bias = 0.33,
		biasWeight = 0.18,
		ceiling = 473,
		detailWeight = 0.53,
		failureTolerance = 3,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.73,
		minThrottle = 0.115,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 1.3
	}
	S.features = { "addOption", "addConsideration", "score", "evaluate", "ranking", "stats", "buildOptions", "choose", "best", "margin", "optionNames", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("utility", { id = "arkher.npc.attention.utility_reasoning", momentum = 0.13 })
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
				engine.bus:subscribe("arkher.npc.attention.*", function(payload) inst.lastSignal = payload end)
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
