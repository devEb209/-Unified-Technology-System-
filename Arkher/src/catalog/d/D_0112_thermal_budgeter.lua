-- ARKHER SYSTEM D.0112 :: Thermal Erosion Budget Governor
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: budgeter (terrain work allocation under a hard budget)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0112"
	S.key = "arkher.terrain.thermal.budget_governor"
	S.name = "Thermal Erosion Budget Governor"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Thermal Erosion"
	S.aspect = "Budget Governor"
	S.kit = "budgeter"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.thermal.recovery" }
	S.tags = { "d", "thermal", "budgeter", "terrain" }
	S.description = "Thermal Erosion Budget Governor: terrain work allocation under a hard budget for the Thermal Erosion subsystem."
	S.params = {
		backlogLimit = 47,
		baseRadius = 440,
		baseWeight = 0.79,
		bias = 0.39,
		biasWeight = 0.24,
		ceiling = 263,
		detailWeight = 0.39,
		failureTolerance = 4,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.79,
		minThrottle = 0.195,
		regressionSlope = 0.145,
		saturation = 0.74,
		scale = 2.9
	}
	S.features = { "claim", "release", "allocate", "grantedFor", "satisfaction", "pressure", "stats", "governFrame", "throttleFactor", "rebalance", "overSubscribed", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("budgeter", { id = "arkher.terrain.thermal.budget_governor", total = 339, strategy = "priority" })
		inst.system = S
		inst.ctx = ctx

	function inst.governFrame(consumers)
		for _, c in ipairs(consumers) do inst.claim(c.id, c.amount, c.priority) end
		local granted, deficit = inst.allocate()
		return granted, deficit
	end
	function inst.throttleFactor(id)
		local s = inst.satisfaction(id)
		if s >= 1 then return 1 end
		return math.max(S.params.minThrottle, s)
	end
	function inst.rebalance(newTotal)
		inst.total = newTotal
		return inst.allocate()
	end
	function inst.overSubscribed() return inst.pressure() > 1.0 end

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
				engine.bus:subscribe("arkher.terrain.thermal.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.claim("probe.hi", inst.total * 0.8, 3)
		inst.claim("probe.lo", inst.total * 0.6, 1)
		local granted = inst.allocate()
		local ok = granted["probe.hi"] ~= nil and inst.overSubscribed()
		inst.release("probe.hi") inst.release("probe.lo")
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
