-- ARKHER SYSTEM VB.0300 :: Climate Continuum Emergence Continuum
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: emergence (emergence detection over the continuum)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0300"
	S.key = "arkher.conttime.climatecont.emergence_continuum"
	S.name = "Climate Continuum Emergence Continuum"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Climate Continuum"
	S.aspect = "Emergence Continuum"
	S.kit = "emergence"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.climatecont.reality_continuum" }
	S.tags = { "vb", "climatecont", "emergence", "conttime" }
	S.description = "Climate Continuum Emergence Continuum: emergence detection over the continuum for the Climate Continuum subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 240,
		baseWeight = 0.6,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 374,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.8,
		scale = 3.0
	}
	S.features = { "observe", "signal", "deviation", "lift", "detect", "novelty", "named", "forget", "stats", "watch", "trend", "detected", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("emergence", { id = "arkher.conttime.climatecont.emergence_continuum", windowSize = 6, threshold = 1.20, minCount = 2 })
		inst.system = S
		inst.ctx = ctx

		function inst.watch(event, weight) return inst.observe(event, weight) end
		function inst.trend(name, value) return inst.signal(name, value) end
		function inst.detected() return inst.detect() end

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
				engine.bus:subscribe("arkher.conttime.climatecont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		for i = 1, 6 do
			inst.watch("rain")
			inst.watch("flood")
			inst.watch("noise" .. i)
		end
		local found = inst.detected()
		local ok = #found > 0 and inst.lift("rain", "flood") > 1
		for _ = 1, 10 do inst.trend("level", 0.5) end
		ok = ok and math.abs(inst.deviation("level")) < 0.001
		inst.trend("level", 4)
		ok = ok and inst.deviation("level") > 1
		ok = ok and #inst.named() > 0
		return ok and inst.novelty("rain") < inst.novelty("unheard")
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
