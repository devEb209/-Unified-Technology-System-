-- ARKHER SYSTEM E.0082 :: Normal Detail Parameter Budget
-- Category E - MATERIALS
-- ARKHER Material Framework capability: how every surface in the world is defined, layered, worn and afforded.
-- Kit: budgeter (texel and layer budget allocation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "E.0082"
	S.key = "arkher.material.normaldetail.parameter_budget"
	S.name = "Normal Detail Parameter Budget"
	S.category = "E"
	S.family = "MATERIALS"
	S.area = "Normal Detail"
	S.aspect = "Parameter Budget"
	S.kit = "budgeter"
	S.version = "1.0.0"
	S.deps = { "arkher.material.normaldetail.variant_registry" }
	S.tags = { "e", "normaldetail", "budgeter", "material" }
	S.description = "Normal Detail Parameter Budget: texel and layer budget allocation for the Normal Detail subsystem."
	S.params = {
		backlogLimit = 29,
		baseRadius = 520,
		baseWeight = 0.71,
		bias = 0.21,
		biasWeight = 0.06,
		ceiling = 293,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.61,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "claim", "release", "allocate", "grantedFor", "satisfaction", "pressure", "stats", "governFrame", "throttleFactor", "rebalance", "overSubscribed", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("budgeter", { id = "arkher.material.normaldetail.parameter_budget", total = 81, strategy = "proportional" })
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
				engine.bus:subscribe("arkher.material.normaldetail.*", function(payload) inst.lastSignal = payload end)
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
