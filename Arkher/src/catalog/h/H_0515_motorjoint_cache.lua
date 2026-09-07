-- ARKHER SYSTEM H.0515 :: Motorized Joint Result Cache
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: cache (reuse of expensive simulation and query results)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0515"
	S.key = "arkher.physics.motorjoint.result_cache"
	S.name = "Motorized Joint Result Cache"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Motorized Joint"
	S.aspect = "Result Cache"
	S.kit = "cache"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.motorjoint.simulation_policy" }
	S.tags = { "h", "motorjoint", "cache", "physics" }
	S.description = "Motorized Joint Result Cache: reuse of expensive simulation and query results for the Motorized Joint subsystem."
	S.params = {
		backlogLimit = 47,
		baseRadius = 280,
		baseWeight = 0.79,
		bias = 0.39,
		biasWeight = 0.24,
		ceiling = 375,
		detailWeight = 0.59,
		failureTolerance = 4,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.79,
		minThrottle = 0.145,
		regressionSlope = 0.145,
		saturation = 0.74,
		scale = 1.9
	}
	S.features = { "set", "get", "remove", "evict", "tick", "hitRate", "warm", "clear", "stats", "memoize", "prefetch", "pressure", "shrinkTo", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("cache", { id = "arkher.physics.motorjoint.result_cache", policy = "lru", capacity = 119, ttl = 4 })
		inst.system = S
		inst.ctx = ctx

	function inst.memoize(fn)
		return function(key, ...)
			local hit = inst.get(key)
			if hit ~= nil then return hit, true end
			local value = fn(key, ...)
			inst.set(key, value)
			return value, false
		end
	end
	function inst.prefetch(keys, producer)
		local n = 0
		for _, k in ipairs(keys) do
			if inst.get(k) == nil then inst.set(k, producer(k)) n = n + 1 end
		end
		return n
	end
	function inst.pressure() return inst.stats().size / math.max(1, inst.capacity) end
	function inst.shrinkTo(capacity)
		inst.capacity = math.max(1, capacity)
		return inst.evict()
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
				engine.bus:subscribe("arkher.physics.motorjoint.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local calls = 0
		local memo = inst.memoize(function(k) calls = calls + 1 return k * 2 end)
		local v1 = memo(21)
		local v2, cached = memo(21)
		inst.clear()
		return v1 == 42 and v2 == 42 and cached == true and calls == 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
