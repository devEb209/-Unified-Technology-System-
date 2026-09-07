-- ARKHER SYSTEM I.0273 :: Foot Placement IK Recovery
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: recovery (fallback pose when data or solving fails)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0273"
	S.key = "arkher.anim.footik.recovery"
	S.name = "Foot Placement IK Recovery"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Foot Placement IK"
	S.aspect = "Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.footik.analysis" }
	S.tags = { "i", "footik", "recovery", "anim" }
	S.description = "Foot Placement IK Recovery: fallback pose when data or solving fails for the Foot Placement IK subsystem."
	S.params = {
		backlogLimit = 36,
		baseRadius = 480,
		baseWeight = 0.68,
		bias = 0.28,
		biasWeight = 0.13,
		ceiling = 412,
		detailWeight = 0.28,
		failureTolerance = 3,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.68,
		minThrottle = 0.14,
		regressionSlope = 0.09,
		saturation = 0.88,
		scale = 1.8
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.anim.footik.recovery", maxSnapshots = 16, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.anim.footik.*", function(payload) inst.lastSignal = payload end)
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
