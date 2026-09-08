-- ARKHER SYSTEM VB.0615 :: Occupancy Map Sparse Residency
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: sparse (sparse page residency with eviction and compression)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0615"
	S.key = "arkher.conttime.occupancymap.sparse_residency"
	S.name = "Occupancy Map Sparse Residency"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Occupancy Map"
	S.aspect = "Sparse Residency"
	S.kit = "sparse"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.occupancymap.epoch_clock" }
	S.tags = { "vb", "occupancymap", "sparse", "conttime" }
	S.description = "Occupancy Map Sparse Residency: sparse page residency with eviction and compression for the Occupancy Map subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 440,
		baseWeight = 0.95,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 71,
		detailWeight = 0.75,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.225,
		regressionSlope = 0.125,
		saturation = 0.9,
		scale = 3.5
	}
	S.features = { "write", "read", "pin", "unpin", "isResident", "touch", "evict", "residentBytes", "compressionRatio", "stats", "store", "retrieve", "budgetUsage", "efficiency", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("sparse", { id = "arkher.conttime.occupancymap.sparse_residency", capacity = 1024, pageBytes = 9216 })
		inst.system = S
		inst.ctx = ctx

		function inst.store(key, data, pin)
			inst.write(key or S.key .. ".page", data or { v = 1 }, { bytes = 2048 })
			if pin then inst.pin(key or S.key .. ".page") end
			return inst.isResident(key or S.key .. ".page")
		end
		function inst.retrieve(key) return inst.read(key or S.key .. ".page") end
		function inst.budgetUsage() return inst.residentBytes() / math.max(1, inst.capacity * inst.pageBytes) end
		function inst.efficiency() return 1 - inst.compressionRatio() end

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
				engine.bus:subscribe("arkher.conttime.occupancymap.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local key = S.key .. ".probe"
		inst.store(key, { payload = 42 })
		local ok = inst.retrieve(key) ~= nil
		ok = ok and inst.pin(key) and inst.isResident(key)
		ok = ok and inst.budgetUsage() >= 0 and inst.efficiency() >= 0
		inst.unpin(key)
		ok = ok and inst.evict(1) >= 0
		return ok and inst.stats().pages >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
