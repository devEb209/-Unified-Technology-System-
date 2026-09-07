-- ARKHER SYSTEM F.0518 :: Mesh LOD Fallback Recovery
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: recovery (safe frame when a pass fails or overruns)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0518"
	S.key = "arkher.render.meshlod.fallback_recovery"
	S.name = "Mesh LOD Fallback Recovery"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Mesh LOD"
	S.aspect = "Fallback Recovery"
	S.kit = "recovery"
	S.version = "1.0.0"
	S.deps = { "arkher.render.meshlod.orchestration" }
	S.tags = { "f", "meshlod", "recovery", "render" }
	S.description = "Mesh LOD Fallback Recovery: safe frame when a pass fails or overruns for the Mesh LOD subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 440,
		baseWeight = 0.95,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 143,
		detailWeight = 0.75,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.225,
		regressionSlope = 0.125,
		saturation = 0.9,
		scale = 3.5
	}
	S.features = { "snapshot", "verify", "rollback", "lastGood", "protect", "stats", "guardedApply", "checkpoint", "restoreLast", "healthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("recovery", { id = "arkher.render.meshlod.fallback_recovery", maxSnapshots = 19, strategy = "rollback" })
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
				engine.bus:subscribe("arkher.render.meshlod.*", function(payload) inst.lastSignal = payload end)
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
