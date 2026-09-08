-- ARKHER SYSTEM VD.0542 :: World Fabric Epoch Clock
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: epoch (deterministic epoch timeline with catch-up)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0542"
	S.key = "arkher.contsim.worldfabric.epoch_clock"
	S.name = "World Fabric Epoch Clock"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "World Fabric"
	S.aspect = "Epoch Clock"
	S.kit = "epoch"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.worldfabric.infinite_grid" }
	S.tags = { "vd", "worldfabric", "epoch", "contsim" }
	S.description = "World Fabric Epoch Clock: deterministic epoch timeline with catch-up for the World Fabric subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 520,
		baseWeight = 0.65,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 285,
		detailWeight = 0.65,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.175,
		regressionSlope = 0.075,
		saturation = 0.85,
		scale = 2.5
	}
	S.features = { "advance", "epochNow", "elapsedSince", "catchUp", "seek", "drift", "checkpoint", "restore", "setDilation", "stats", "tickFor", "rewindTo", "burstCatch", "health", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("epoch", { id = "arkher.contsim.worldfabric.epoch_clock", tickRate = 20, budget = 9, capacity = 224 })
		inst.system = S
		inst.ctx = ctx

		function inst.tickFor(seconds)
			local ticks = 0
			for _ = 1, math.max(1, math.floor((seconds or 1) * inst.tickRate)) do ticks = ticks + inst.advance(1/inst.tickRate) end
			return ticks
		end
		function inst.rewindTo(epoch) return inst.seek(epoch or 0) end
		function inst.burstCatch(target) return inst.catchUp(target or inst.epoch + 4) end
		function inst.health() return 1 - math.min(1, inst.drift()) end

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
				engine.bus:subscribe("arkher.contsim.worldfabric.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local before = inst.epoch
		inst.advance(0.2)
		local ok = inst.epoch > before and inst.health() >= 0
		ok = ok and inst.elapsedSince(before) == inst.epoch - before
		local cp = inst.checkpoint()
		inst.seek(before)
		ok = ok and inst.epoch == before
		inst.restore(cp)
		ok = ok and inst.catchUp(inst.epoch + 2) == 2
		return ok and inst.stats().epoch == inst.epoch
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
