-- ARKHER SYSTEM VB.0401 :: Perception Continuum Persistent State
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: persistent (epoch-stamped persistent history and rollback)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0401"
	S.key = "arkher.conttime.perceptioncont.persistent_state"
	S.name = "Perception Continuum Persistent State"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Perception Continuum"
	S.aspect = "Persistent State"
	S.kit = "persistent"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.perceptioncont.multi-scale_fidelity" }
	S.tags = { "vb", "perceptioncont", "persistent", "conttime" }
	S.description = "Perception Continuum Persistent State: epoch-stamped persistent history and rollback for the Perception Continuum subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 240,
		baseWeight = 0.92,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 98,
		detailWeight = 0.22,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.11,
		regressionSlope = 0.06,
		saturation = 0.87,
		scale = 1.2
	}
	S.features = { "commit", "read", "diff", "rollback", "checkpoint", "restore", "verify", "stats", "saveState", "loadCurrent", "integrity", "rollbackTo", "historySize", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("persistent", { id = "arkher.conttime.perceptioncont.persistent_state", capacity = 128 })
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
				engine.bus:subscribe("arkher.conttime.perceptioncont.*", function(payload) inst.lastSignal = payload end)
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
