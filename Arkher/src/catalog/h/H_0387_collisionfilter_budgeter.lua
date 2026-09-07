-- ARKHER SYSTEM H.0387 :: Collision Filter Budget Governor
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: budgeter (simulation time budget allocation across islands)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0387"
	S.key = "arkher.physics.collisionfilter.budget_governor"
	S.name = "Collision Filter Budget Governor"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Collision Filter"
	S.aspect = "Budget Governor"
	S.kit = "budgeter"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.collisionfilter.broadphase_index" }
	S.tags = { "h", "collisionfilter", "budgeter", "physics" }
	S.description = "Collision Filter Budget Governor: simulation time budget allocation across islands for the Collision Filter subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 400,
		baseWeight = 0.72,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 330,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.92,
		scale = 2.2
	}
	S.features = { "claim", "release", "allocate", "grantedFor", "satisfaction", "pressure", "stats", "governFrame", "throttleFactor", "rebalance", "overSubscribed", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("budgeter", { id = "arkher.physics.collisionfilter.budget_governor", total = 182, strategy = "proportional" })
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
				engine.bus:subscribe("arkher.physics.collisionfilter.*", function(payload) inst.lastSignal = payload end)
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
