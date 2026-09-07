-- ARKHER SYSTEM I.0260 :: Turn In Place Recovery
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: recovery (fallback pose when data or solving fails)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0260"
	S.key = "arkher.anim.turninplace.recovery"
	S.name = "Turn In Place Recovery"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Turn In Place"
	S.aspect = "Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.turninplace.analysis" }
	S.tags = { "i", "turninplace", "recovery", "anim" }
	S.description = "Turn In Place Recovery: fallback pose when data or solving fails for the Turn In Place subsystem."
	S.params = {
		backlogLimit = 24,
		baseRadius = 480,
		baseWeight = 0.86,
		bias = 0.16,
		biasWeight = 0.21,
		ceiling = 192,
		detailWeight = 0.76,
		failureTolerance = 1,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.56,
		minThrottle = 0.23,
		regressionSlope = 0.13,
		saturation = 0.81,
		scale = 3.6
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.anim.turninplace.recovery", maxSnapshots = 4, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.anim.turninplace.*", function(payload) inst.lastSignal = payload end)
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
