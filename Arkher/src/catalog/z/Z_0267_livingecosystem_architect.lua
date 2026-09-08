-- ARKHER SYSTEM Z.0267 :: Living Ecosystem Engine World Architect
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: architect (hierarchical world composition with conserved budgets)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0267"
	S.key = "arkher.origin.livingecosystem.world_architect"
	S.name = "Living Ecosystem Engine World Architect"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Living Ecosystem Engine"
	S.aspect = "World Architect"
	S.kit = "architect"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.livingecosystem.emergence_detection" }
	S.tags = { "z", "livingecosystem", "architect", "origin" }
	S.description = "Living Ecosystem Engine World Architect: hierarchical world composition with conserved budgets for the Living Ecosystem Engine subsystem."
	S.params = {
		backlogLimit = 12,
		baseRadius = 480,
		baseWeight = 0.84,
		bias = 0.04,
		biasWeight = 0.09,
		ceiling = 308,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.44,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.79,
		scale = 2.4
	}
	S.features = { "define", "allocate", "budgetOf", "addRule", "installRules", "coherent", "programme", "estimate", "compose", "stats", "composeWorld", "buildOrder", "check", "cost", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("architect", { id = "arkher.origin.livingecosystem.world_architect", budget = 1000, seed = 48884 })
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
				engine.bus:subscribe("arkher.origin.livingecosystem.*", function(payload) inst.lastSignal = payload end)
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
