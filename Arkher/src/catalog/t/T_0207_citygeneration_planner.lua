-- ARKHER SYSTEM T.0207 :: City Generation Action Planner
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: planner (goal-oriented action planning over preconditions)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0207"
	S.key = "arkher.ai.citygeneration.action_planner"
	S.name = "City Generation Action Planner"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "City Generation"
	S.aspect = "Action Planner"
	S.kit = "planner"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.citygeneration.utility_selection" }
	S.tags = { "t", "citygeneration", "planner", "ai" }
	S.description = "City Generation Action Planner: goal-oriented action planning over preconditions for the City Generation subsystem."
	S.params = {
		backlogLimit = 11,
		baseRadius = 600,
		baseWeight = 0.63,
		bias = 0.03,
		biasWeight = 0.08,
		ceiling = 283,
		detailWeight = 0.43,
		failureTolerance = 3,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.43,
		minThrottle = 0.215,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 3.3
	}
	S.features = { "addAction", "plan", "planCost", "simulate", "stats", "buildDomain", "startState", "planFor", "canReach", "stepNames", "replanCost", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("planner", { id = "arkher.ai.citygeneration.action_planner", maxDepth = 11 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildDomain()
			if #inst.order > 0 then return #inst.order end
			inst.addAction("makeTool", { pre = { hasTool = false },
				effects = { hasTool = true }, cost = 1 })
			inst.addAction("gather", { pre = { hasTool = true },
				effects = { hasFood = true }, cost = 2 })
			inst.addAction("cook", { pre = { hasFood = true },
				effects = { fed = true }, cost = 2 })
			return #inst.order
		end
		function inst.startState()
			return { hasTool = false, hasFood = false, fed = false }
		end
		function inst.planFor(goal, initial)
			inst.buildDomain()
			return inst.plan(initial or inst.startState(), goal or { fed = true })
		end
		function inst.canReach(goal, initial)
			return inst.planFor(goal, initial) ~= nil
		end
		function inst.stepNames()
			local out = {}
			for _, name in ipairs(inst.lastPlan or {}) do out[#out + 1] = name end
			return out
		end
		function inst.replanCost(goal, initial)
			local plan, cost = inst.planFor(goal, initial)
			if not plan then return math.huge end
			return cost
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
				engine.bus:subscribe("arkher.ai.citygeneration.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildDomain() == 3
		local plan, cost = inst.planFor()
		ok = ok and plan ~= nil and #plan == 3 and cost == 5
		local final, done = inst.simulate(inst.startState(), plan)
		ok = ok and done and final.fed == true
		ok = ok and inst.canReach({ hasTool = true })
		ok = ok and not inst.canReach({ impossible = true })
		return ok and inst.replanCost() == 5 and #inst.stepNames() >= 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
