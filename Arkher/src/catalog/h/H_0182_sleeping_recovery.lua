-- ARKHER SYSTEM H.0182 :: Sleeping Recovery
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: recovery (checkpointing and rollback when the solver diverges)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0182"
	S.key = "arkher.physics.sleeping.recovery"
	S.name = "Sleeping Recovery"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Sleeping"
	S.aspect = "Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.sleeping.determinism_ledger" }
	S.tags = { "h", "sleeping", "recovery", "physics" }
	S.description = "Sleeping Recovery: checkpointing and rollback when the solver diverges for the Sleeping subsystem."
	S.params = {
		backlogLimit = 41,
		baseRadius = 520,
		baseWeight = 0.63,
		bias = 0.33,
		biasWeight = 0.18,
		ceiling = 433,
		detailWeight = 0.53,
		failureTolerance = 3,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.73,
		minThrottle = 0.115,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 1.3
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.physics.sleeping.recovery", maxSnapshots = 5, strategy = "rollback" })
		inst.system = S
		inst.ctx = ctx

	function inst.guardedApply(state, mutate)
		return inst.protect(mutate, state)
	end
	function inst.checkpoint(label, state) return inst.snapshot(label, state) end
	function inst.restoreLast()
		local snap = inst.lastGood()
		if not snap then return nil end
		return snap.state, snap.label
	end
	function inst.healthy() return inst.stats().failures <= S.params.failureTolerance end

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
				engine.bus:subscribe("arkher.physics.sleeping.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local state = { hp = 10 }
		inst.checkpoint("probe", state)
		local result, ok = inst.guardedApply(state, function() error("probe failure") end)
		local restored = inst.restoreLast()
		return ok == false and result.hp == 10 and restored ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
