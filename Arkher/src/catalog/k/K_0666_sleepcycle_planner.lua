-- ARKHER SYSTEM K.0666 :: Sleep Cycle Goal Planner
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: planner (backward GOAP planning to reach a goal state)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0666"
	S.key = "arkher.npc.sleepcycle.goal_planner"
	S.name = "Sleep Cycle Goal Planner"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Sleep Cycle"
	S.aspect = "Goal Planner"
	S.kit = "planner"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.sleepcycle.utility_reasoning" }
	S.tags = { "k", "sleepcycle", "planner", "npc" }
	S.description = "Sleep Cycle Goal Planner: backward GOAP planning to reach a goal state for the Sleep Cycle subsystem."
	S.params = {
		backlogLimit = 32,
		baseRadius = 320,
		baseWeight = 0.54,
		bias = 0.24,
		biasWeight = 0.09,
		ceiling = 80,
		detailWeight = 0.24,
		failureTolerance = 4,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.64,
		minThrottle = 0.12,
		regressionSlope = 0.07,
		saturation = 0.74,
		scale = 1.4
	}
	S.features = { "addAction", "plan", "planCost", "simulate", "stats", "buildDomain", "startState", "planFor", "canReach", "stepNames", "replanCost", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("planner", { id = "arkher.npc.sleepcycle.goal_planner", maxDepth = 10 })
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
				engine.bus:subscribe("arkher.npc.sleepcycle.*", function(payload) inst.lastSignal = payload end)
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
