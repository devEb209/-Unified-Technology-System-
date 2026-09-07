-- ARKHER SYSTEM B.0220 :: Tool Palette Preview Cache
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: cache (reuse of expensive editor previews)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0220"
	S.key = "arkher.studio.toolpalette.preview_cache"
	S.name = "Tool Palette Preview Cache"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Tool Palette"
	S.aspect = "Preview Cache"
	S.kit = "cache"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.toolpalette.tool_pipeline" }
	S.tags = { "b", "toolpalette", "cache", "studio" }
	S.description = "Tool Palette Preview Cache: reuse of expensive editor previews for the Tool Palette subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 160,
		baseWeight = 0.5,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 492,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.7,
		scale = 1.0
	}
	S.features = { "set", "get", "remove", "evict", "tick", "hitRate", "warm", "clear", "stats", "memoize", "prefetch", "pressure", "shrinkTo", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("cache", { id = "arkher.studio.toolpalette.preview_cache", policy = "lru", capacity = 364, ttl = 0 })
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
				engine.bus:subscribe("arkher.studio.toolpalette.*", function(payload) inst.lastSignal = payload end)
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
