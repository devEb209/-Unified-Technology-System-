-- ARKHER SYSTEM VB.0301 :: Weather Continuum Infinite Grid
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: continuum (seamless paging of the infinite world grid)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0301"
	S.key = "arkher.conttime.weathercont.infinite_grid"
	S.name = "Weather Continuum Infinite Grid"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Weather Continuum"
	S.aspect = "Infinite Grid"
	S.kit = "continuum"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "vb", "weathercont", "continuum", "conttime" }
	S.description = "Weather Continuum Infinite Grid: seamless paging of the infinite world grid for the Weather Continuum subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 200,
		baseWeight = 0.95,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 217,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.9,
		scale = 3.5
	}
	S.features = { "cellOf", "update", "pump", "isLoaded", "isLoadedKey", "loadedCount", "pendingCount", "neighbors", "checksum", "stats", "centerAt", "streamAt", "coverage", "seamScore", "neighborsAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("continuum", { id = "arkher.conttime.weathercont.infinite_grid", cellSize = 96, radius = 480, horizon = 2112 })
		inst.system = S
		inst.ctx = ctx

		function inst.centerAt(x, z)
			return inst.update(x or 0, z or 0)
		end
		function inst.streamAt(x, z, budget)
			inst.update(x, z)
			return inst.pump(budget or 4)
		end
		function inst.coverage() return inst.loadedCount() / math.max(1, inst.loadedCount() + inst.pendingCount()) end
		function inst.seamScore() return inst.seams end
		function inst.neighborsAt(x, z) return inst.neighbors(inst.cellOf(x, z).key) end

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
				engine.bus:subscribe("arkher.conttime.weathercont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.update(0, 0)
		local before = inst.loadedCount()
		inst.pump(8)
		local after = inst.loadedCount()
		local ok = after > 0 and after >= before
		ok = ok and inst.coverage() > 0 and inst.seamScore() >= 0
		local key = inst.cellOf(0, 0).key
		ok = ok and inst.isLoadedKey(key) == true
		ok = ok and #inst.neighbors(key) >= 0
		return ok and inst.stats().loads >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
