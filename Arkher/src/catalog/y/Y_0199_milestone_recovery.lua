-- ARKHER SYSTEM Y.0199 :: Milestone Release Recovery
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: recovery (checkpoint and rollback of production state)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0199"
	S.key = "arkher.collab.milestone.release_recovery"
	S.name = "Milestone Release Recovery"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Milestone"
	S.aspect = "Release Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.milestone.working_set" }
	S.tags = { "y", "milestone", "recovery", "collab" }
	S.description = "Milestone Release Recovery: checkpoint and rollback of production state for the Milestone subsystem."
	S.params = {
		backlogLimit = 37,
		baseRadius = 360,
		baseWeight = 0.99,
		bias = 0.29,
		biasWeight = 0.14,
		ceiling = 525,
		detailWeight = 0.49,
		failureTolerance = 4,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.69,
		minThrottle = 0.245,
		regressionSlope = 0.095,
		saturation = 0.94,
		scale = 3.9
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.collab.milestone.release_recovery", maxSnapshots = 17, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.collab.milestone.*", function(payload) inst.lastSignal = payload end)
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
