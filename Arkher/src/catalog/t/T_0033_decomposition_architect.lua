-- ARKHER SYSTEM T.0033 :: Task Decomposition World Architect
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: architect (composition of a whole world plan with conserved budgets)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0033"
	S.key = "arkher.ai.decomposition.world_architect"
	S.name = "Task Decomposition World Architect"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Task Decomposition"
	S.aspect = "World Architect"
	S.kit = "architect"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.decomposition.self_critique" }
	S.tags = { "t", "decomposition", "architect", "ai" }
	S.description = "Task Decomposition World Architect: composition of a whole world plan with conserved budgets for the Task Decomposition subsystem."
	S.params = {
		backlogLimit = 22,
		baseRadius = 400,
		baseWeight = 0.54,
		bias = 0.14,
		biasWeight = 0.19,
		ceiling = 494,
		detailWeight = 0.74,
		failureTolerance = 4,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.54,
		minThrottle = 0.22,
		regressionSlope = 0.12,
		saturation = 0.74,
		scale = 3.4
	}
	S.features = { "define", "allocate", "budgetOf", "addRule", "installRules", "coherent", "programme", "estimate", "compose", "stats", "composeWorld", "buildOrder", "check", "cost", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("architect", { id = "arkher.ai.decomposition.world_architect", budget = 1000, seed = 27054 })
		inst.system = S
		inst.ctx = ctx

		function inst.composeWorld(target, quantity)
			return inst.compose({ target = target or S.key, quantity = quantity or 60,
				density = 1 })
		end
		function inst.buildOrder() return inst.programme() end
		function inst.check() return inst.coherent() end
		function inst.cost(rate) return inst.estimate(rate or 1) end

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
				engine.bus:subscribe("arkher.ai.decomposition.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local composed = inst.composeWorld(S.key, 80)
		local ok = composed.nodes > 8 and composed.districts >= 1
		ok = ok and inst.check()
		local programme = inst.buildOrder()
		ok = ok and programme ~= nil and #programme == #inst.order
		local index = {}
		for i, id in ipairs(programme) do index[id] = i end
		ok = ok and index[S.key .. ".terrain"] < index[S.key .. ".roads"]
		return ok and inst.cost(1) > 0 and inst.stats().composed == 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
