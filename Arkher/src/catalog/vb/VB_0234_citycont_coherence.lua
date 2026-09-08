-- ARKHER SYSTEM VB.0234 :: City Continuum Coherence Guard
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: coherence (seam coherence and drift supervision)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0234"
	S.key = "arkher.conttime.citycont.coherence_guard"
	S.name = "City Continuum Coherence Guard"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "City Continuum"
	S.aspect = "Coherence Guard"
	S.kit = "coherence"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.citycont.persistent_state" }
	S.tags = { "vb", "citycont", "coherence", "conttime" }
	S.description = "City Continuum Coherence Guard: seam coherence and drift supervision for the City Continuum subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 600,
		baseWeight = 0.99,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 507,
		detailWeight = 0.79,
		failureTolerance = 4,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.59,
		minThrottle = 0.245,
		regressionSlope = 0.145,
		saturation = 0.94,
		scale = 3.9
	}
	S.features = { "observe", "score", "isCoherent", "driftValue", "pressure", "reset", "stats", "feed", "trendValue", "healthy", "budgetMargin", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("coherence", { id = "arkher.conttime.citycont.coherence_guard", window = 107, threshold = 0.17 })
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
				engine.bus:subscribe("arkher.conttime.citycont.*", function(payload) inst.lastSignal = payload end)
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
