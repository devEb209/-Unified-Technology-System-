-- ARKHER SYSTEM Z.0407 :: Battery Aware Pipeline World Architect
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: architect (hierarchical world composition with conserved budgets)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0407"
	S.key = "arkher.origin.batteryaware.world_architect"
	S.name = "Battery Aware Pipeline World Architect"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Battery Aware Pipeline"
	S.aspect = "World Architect"
	S.kit = "architect"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.batteryaware.emergence_detection" }
	S.tags = { "z", "batteryaware", "architect", "origin" }
	S.description = "Battery Aware Pipeline World Architect: hierarchical world composition with conserved budgets for the Battery Aware Pipeline subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 280,
		baseWeight = 0.53,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 359,
		detailWeight = 0.23,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.115,
		regressionSlope = 0.065,
		saturation = 0.73,
		scale = 1.3
	}
	S.features = { "define", "allocate", "budgetOf", "addRule", "installRules", "coherent", "programme", "estimate", "compose", "stats", "composeWorld", "buildOrder", "check", "cost", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("architect", { id = "arkher.origin.batteryaware.world_architect", budget = 900, seed = 94503 })
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
				engine.bus:subscribe("arkher.origin.batteryaware.*", function(payload) inst.lastSignal = payload end)
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
