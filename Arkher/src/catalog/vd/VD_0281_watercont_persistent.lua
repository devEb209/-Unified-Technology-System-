-- ARKHER SYSTEM VD.0281 :: Water Continuum Persistent State
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: persistent (epoch-stamped persistent history and rollback)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0281"
	S.key = "arkher.contsim.watercont.persistent_state"
	S.name = "Water Continuum Persistent State"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "Water Continuum"
	S.aspect = "Persistent State"
	S.kit = "persistent"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.watercont.multi-scale_fidelity" }
	S.tags = { "vd", "watercont", "persistent", "contsim" }
	S.description = "Water Continuum Persistent State: epoch-stamped persistent history and rollback for the Water Continuum subsystem."
	S.params = {
		backlogLimit = 45,
		baseRadius = 520,
		baseWeight = 0.57,
		bias = 0.37,
		biasWeight = 0.22,
		ceiling = 509,
		detailWeight = 0.77,
		failureTolerance = 2,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.77,
		minThrottle = 0.235,
		regressionSlope = 0.135,
		saturation = 0.77,
		scale = 3.7
	}
	S.features = { "commit", "read", "diff", "rollback", "checkpoint", "restore", "verify", "stats", "saveState", "loadCurrent", "integrity", "rollbackTo", "historySize", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("persistent", { id = "arkher.contsim.watercont.persistent_state", capacity = 224 })
		inst.system = S
		inst.ctx = ctx

		function inst.saveState(state, tag)
			return inst.commit(nil, state or { tick = 1 }, { tag = tag or "test" })
		end
		function inst.loadCurrent() return inst.read() end
		function inst.integrity() return inst.verify() end
		function inst.rollbackTo(target) return inst.rollback(target) end
		function inst.historySize() return inst.checkpoint() and 1 or 0 end

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
				engine.bus:subscribe("arkher.contsim.watercont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local cp = inst.saveState({ tick = 1 }, "probe")
		local ok = cp ~= nil and inst.loadCurrent() ~= nil
		ok = ok and inst.integrity()
		local cp2 = inst.saveState({ tick = 2 }, "probe2")
		ok = ok and inst.diff(cp.sequence, cp2.sequence) >= 0
		ok = ok and inst.rollbackTo(cp.sequence)
		return ok and inst.stats().commits >= 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
