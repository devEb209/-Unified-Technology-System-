-- ARKHER SYSTEM R.0095 :: Property Replication Latency Analysis
-- Category R - NETWORKING
-- ARKHER Networking Framework capability: authoritative replication, prediction and bandwidth discipline.
-- Kit: analyzer (round trip, jitter and loss analysis)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "R.0095"
	S.key = "arkher.net.propertyreplication.latency_analysis"
	S.name = "Property Replication Latency Analysis"
	S.category = "R"
	S.family = "NETWORKING"
	S.area = "Property Replication"
	S.aspect = "Latency Analysis"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.net.propertyreplication.audit_ledger" }
	S.tags = { "r", "propertyreplication", "analyzer", "net" }
	S.description = "Property Replication Latency Analysis: round trip, jitter and loss analysis for the Property Replication subsystem."
	S.params = {
		backlogLimit = 8,
		baseRadius = 320,
		baseWeight = 0.5,
		bias = 0.0,
		biasWeight = 0.05,
		ceiling = 408,
		detailWeight = 0.6,
		failureTolerance = 0,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.4,
		minThrottle = 0.15,
		regressionSlope = 0.05,
		saturation = 0.7,
		scale = 2.0
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.net.propertyreplication.latency_analysis", window = 48, buckets = 12, threshold = 3.00 })
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
				engine.bus:subscribe("arkher.net.propertyreplication.*", function(payload) inst.lastSignal = payload end)
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
