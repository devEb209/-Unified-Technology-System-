-- ARKHER SYSTEM H.0135 :: Torque Budget Governor
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: budgeter (simulation time budget allocation across islands)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0135"
	S.key = "arkher.physics.torque.budget_governor"
	S.name = "Torque Budget Governor"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Torque"
	S.aspect = "Budget Governor"
	S.kit = "budgeter"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.torque.broadphase_index" }
	S.tags = { "h", "torque", "budgeter", "physics" }
	S.description = "Torque Budget Governor: simulation time budget allocation across islands for the Torque subsystem."
	S.params = {
		backlogLimit = 43,
		baseRadius = 600,
		baseWeight = 0.95,
		bias = 0.35,
		biasWeight = 0.2,
		ceiling = 299,
		detailWeight = 0.55,
		failureTolerance = 0,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.75,
		minThrottle = 0.125,
		regressionSlope = 0.125,
		saturation = 0.9,
		scale = 1.5
	}
	S.features = { "claim", "release", "allocate", "grantedFor", "satisfaction", "pressure", "stats", "governFrame", "throttleFactor", "rebalance", "overSubscribed", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("budgeter", { id = "arkher.physics.torque.budget_governor", total = 455, strategy = "waterfill" })
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
				engine.bus:subscribe("arkher.physics.torque.*", function(payload) inst.lastSignal = payload end)
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
