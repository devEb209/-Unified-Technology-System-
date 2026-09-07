-- ARKHER SYSTEM Z.1030 :: Autonomous Balancing Self Critique
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: critic (weighted judgement of the technology's own output)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.1030"
	S.key = "arkher.origin.autobalancing.self_critique"
	S.name = "Autonomous Balancing Self Critique"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Autonomous Balancing"
	S.aspect = "Self Critique"
	S.kit = "critic"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.autobalancing.intent_bridge" }
	S.tags = { "z", "autobalancing", "critic", "origin" }
	S.description = "Autonomous Balancing Self Critique: weighted judgement of the technology's own output for the Autonomous Balancing subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.57,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 563,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.77,
		scale = 3.7
	}
	S.features = { "addCriterion", "scoreOne", "evaluate", "verdict", "worst", "compare", "improvement", "suggestions", "stats", "installCriteria", "judge", "advice", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("critic", { id = "arkher.origin.autobalancing.self_critique", passMark = 0.82, reviseMark = 0.47, seed = 17907 })
		inst.system = S
		inst.ctx = ctx

		function inst.installCriteria()
			inst.addCriterion("quality", { weight = 3, target = 1, direction = "higher" })
			inst.addCriterion("cost", { weight = 2, target = 10, direction = "lower" })
			inst.addCriterion("balance", { weight = 1, floor = 0.4, ceiling = 0.6,
				direction = "range" })
			return #inst.order
		end
		function inst.judge(quality, cost, balance)
			return inst.evaluate({ quality = quality, cost = cost, balance = balance })
		end
		function inst.advice(record)
			return inst.suggestions(record, 3)
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
				engine.bus:subscribe("arkher.origin.autobalancing.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installCriteria() == 3
		local good = inst.judge(1, 5, 0.5)
		ok = ok and good.verdict == "pass" and good.overall > 0.9
		local bad = inst.judge(0.1, 100, 5)
		ok = ok and bad.overall < good.overall
		ok = ok and #inst.advice(bad) > 0
		ok = ok and inst.worst(bad) ~= nil
		return ok and inst.stats().evaluations == 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
