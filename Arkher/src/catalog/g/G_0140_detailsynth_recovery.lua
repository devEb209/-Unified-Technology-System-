-- ARKHER SYSTEM G.0140 :: Detail Synthesis Fallback Recovery
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: recovery (deterministic fallback when inference fails)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0140"
	S.key = "arkher.neural.detailsynth.fallback_recovery"
	S.name = "Detail Synthesis Fallback Recovery"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Detail Synthesis"
	S.aspect = "Fallback Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.detailsynth.sampling_graph" }
	S.tags = { "g", "detailsynth", "recovery", "neural" }
	S.description = "Detail Synthesis Fallback Recovery: deterministic fallback when inference fails for the Detail Synthesis subsystem."
	S.params = {
		backlogLimit = 26,
		baseRadius = 400,
		baseWeight = 0.58,
		bias = 0.18,
		biasWeight = 0.23,
		ceiling = 410,
		detailWeight = 0.38,
		failureTolerance = 3,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.58,
		minThrottle = 0.19,
		regressionSlope = 0.14,
		saturation = 0.78,
		scale = 2.8
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.neural.detailsynth.fallback_recovery", maxSnapshots = 14, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.neural.detailsynth.*", function(payload) inst.lastSignal = payload end)
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
