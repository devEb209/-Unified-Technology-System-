-- ARKHER SYSTEM VB.0402 :: Perception Continuum Coherence Guard
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: coherence (seam coherence and drift supervision)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0402"
	S.key = "arkher.conttime.perceptioncont.coherence_guard"
	S.name = "Perception Continuum Coherence Guard"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Perception Continuum"
	S.aspect = "Coherence Guard"
	S.kit = "coherence"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.perceptioncont.persistent_state" }
	S.tags = { "vb", "perceptioncont", "coherence", "conttime" }
	S.description = "Perception Continuum Coherence Guard: seam coherence and drift supervision for the Perception Continuum subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 440,
		baseWeight = 0.67,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 379,
		detailWeight = 0.27,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.135,
		regressionSlope = 0.085,
		saturation = 0.87,
		scale = 1.7
	}
	S.features = { "observe", "score", "isCoherent", "driftValue", "pressure", "reset", "stats", "feed", "trendValue", "healthy", "budgetMargin", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("coherence", { id = "arkher.conttime.perceptioncont.coherence_guard", window = 139, threshold = 0.15 })
		inst.system = S
		inst.ctx = ctx

		function inst.feed(sample) return inst.observe(sample or { coherence = 0.9, drift = 0.05 }) end
		function inst.trendValue() return inst.score() end
		function inst.healthy() return inst.isCoherent() end
		function inst.budgetMargin() return 1 - inst.pressure() end

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
		for i = 1, 10 do inst.feed({ coherence = 0.9 - i*0.01, drift = 0.04 }) end
		local ok = inst.trendValue() > 0 and inst.trendValue() <= 1
		ok = ok and type(inst.healthy()) == "boolean" and inst.driftValue() >= 0
		ok = ok and inst.budgetMargin() >= -1
		inst.reset()
		return ok and inst.stats().samples >= 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
