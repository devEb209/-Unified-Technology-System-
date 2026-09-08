-- ARKHER SYSTEM VA.0186 :: Simulation Domain Coherence Guard
-- Category VA - CONTINUUM — WORLD
-- Continuum World capability: infinite, seamless world built on continuum, sparse and multiscale.
-- Kit: coherence (seam coherence and drift supervision)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VA.0186"
	S.key = "arkher.contworld.simdomain.coherence_guard"
	S.name = "Simulation Domain Coherence Guard"
	S.category = "VA"
	S.family = "CONTINUUM — WORLD"
	S.area = "Simulation Domain"
	S.aspect = "Coherence Guard"
	S.kit = "coherence"
	S.version = "1.0.0"
	S.deps = { "arkher.contworld.simdomain.persistent_state" }
	S.tags = { "va", "simdomain", "coherence", "contworld" }
	S.description = "Simulation Domain Coherence Guard: seam coherence and drift supervision for the Simulation Domain subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 360,
		baseWeight = 0.97,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 377,
		detailWeight = 0.37,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.185,
		regressionSlope = 0.135,
		saturation = 0.92,
		scale = 2.7
	}
	S.features = { "observe", "score", "isCoherent", "driftValue", "pressure", "reset", "stats", "feed", "trendValue", "healthy", "budgetMargin", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("coherence", { id = "arkher.contworld.simdomain.coherence_guard", window = 137, threshold = 0.15 })
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
				engine.bus:subscribe("arkher.contworld.simdomain.*", function(payload) inst.lastSignal = payload end)
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
