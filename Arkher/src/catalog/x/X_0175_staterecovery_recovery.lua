-- ARKHER SYSTEM X.0175 :: State Recovery Recovery
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: recovery (state protection and rollback)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0175"
	S.key = "arkher.security.staterecovery.recovery"
	S.name = "State Recovery Recovery"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "State Recovery"
	S.aspect = "Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.security.staterecovery.audit_ledger" }
	S.tags = { "x", "staterecovery", "recovery", "security" }
	S.description = "State Recovery Recovery: state protection and rollback for the State Recovery subsystem."
	S.params = {
		backlogLimit = 12,
		baseRadius = 480,
		baseWeight = 0.84,
		bias = 0.04,
		biasWeight = 0.09,
		ceiling = 172,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.44,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.79,
		scale = 2.4
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.security.staterecovery.recovery", maxSnapshots = 16, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.security.staterecovery.*", function(payload) inst.lastSignal = payload end)
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
