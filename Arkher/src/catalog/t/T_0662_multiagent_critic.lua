-- ARKHER SYSTEM T.0662 :: Multi Agent Coordination Self Critique
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: critic (weighted evaluation of the result against declared criteria)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0662"
	S.key = "arkher.ai.multiagent.self_critique"
	S.name = "Multi Agent Coordination Self Critique"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Multi Agent Coordination"
	S.aspect = "Self Critique"
	S.kit = "critic"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.multiagent.plan_workflow" }
	S.tags = { "t", "multiagent", "critic", "ai" }
	S.description = "Multi Agent Coordination Self Critique: weighted evaluation of the result against declared criteria for the Multi Agent Coordination subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 440,
		baseWeight = 0.81,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 199,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.76,
		scale = 1.1
	}
	S.features = { "addCriterion", "scoreOne", "evaluate", "verdict", "worst", "compare", "improvement", "suggestions", "stats", "installCriteria", "judge", "advice", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("critic", { id = "arkher.ai.multiagent.self_critique", passMark = 0.71, reviseMark = 0.41, seed = 4231 })
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
				engine.bus:subscribe("arkher.ai.multiagent.*", function(payload) inst.lastSignal = payload end)
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
