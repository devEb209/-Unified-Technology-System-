-- ARKHER SYSTEM VC.0193 :: Architect District Infinite Grid
-- Category VC - CONTINUUM — NEURAL
-- Continuum Neural capability: neural fields, temporal upscaling and coherence over the continuum.
-- Kit: continuum (seamless paging of the infinite world grid)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VC.0193"
	S.key = "arkher.contneural.architectdistrict.infinite_grid"
	S.name = "Architect District Infinite Grid"
	S.category = "VC"
	S.family = "CONTINUUM — NEURAL"
	S.area = "Architect District"
	S.aspect = "Infinite Grid"
	S.kit = "continuum"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "vc", "architectdistrict", "continuum", "contneural" }
	S.description = "Architect District Infinite Grid: seamless paging of the infinite world grid for the Architect District subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 200,
		baseWeight = 0.65,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 125,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.85,
		scale = 3.5
	}
	S.features = { "cellOf", "update", "pump", "isLoaded", "isLoadedKey", "loadedCount", "pendingCount", "neighbors", "checksum", "stats", "centerAt", "streamAt", "coverage", "seamScore", "neighborsAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("continuum", { id = "arkher.contneural.architectdistrict.infinite_grid", cellSize = 96, radius = 800, horizon = 2112 })
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
				engine.bus:subscribe("arkher.contneural.architectdistrict.*", function(payload) inst.lastSignal = payload end)
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
