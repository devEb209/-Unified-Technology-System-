-- ARKHER SYSTEM X.0047 :: Script Isolation Analyzer
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: analyzer (behavioural anomaly analysis)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0047"
	S.key = "arkher.security.script.analyzer"
	S.name = "Script Isolation Analyzer"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Script Isolation"
	S.aspect = "Analyzer"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.security.script.policy_engine" }
	S.tags = { "x", "script", "analyzer", "security" }
	S.description = "Script Isolation Analyzer: behavioural anomaly analysis for the Script Isolation subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 400,
		baseWeight = 0.8,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 230,
		detailWeight = 0.5,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.1,
		regressionSlope = 0.1,
		saturation = 0.75,
		scale = 1.0
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.security.script.analyzer", window = 78, buckets = 14, threshold = 2.00 })
		inst.system = S
		inst.ctx = ctx

	function inst.feed(series)
		for _, v in ipairs(series) do inst.submit(v) end
		return inst.stats()
	end
	function inst.regression()
		local slope = inst.trend()
		if slope > S.params.regressionSlope then return "degrading", slope end
		if slope < -S.params.regressionSlope then return "improving", slope end
		return "stable", slope
	end
	function inst.budgetBreaches(limit)
		local n = 0
		for i = 1, inst.samples.size do
			local v = inst.samples:get(i)
			if v and v > limit then n = n + 1 end
		end
		return n
	end
	function inst.summary()
		local status, slope = inst.regression()
		return { mean = inst.mean(), p95 = inst.percentile(95), status = status, slope = slope,
			stability = inst.stability(), anomalies = inst.anomalies }
	end

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
				engine.bus:subscribe("arkher.security.script.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		for i = 1, 24 do inst.submit(10 + i * 0.5) end
		local status = inst.regression()
		local sum = inst.summary()
		return status == "degrading" and sum.mean > 10 and sum.p95 >= sum.mean
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
