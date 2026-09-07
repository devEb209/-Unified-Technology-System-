-- ARKHER SYSTEM Y.0280 :: Build Pipeline Progress Analyzer
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: analyzer (throughput, trend and risk analysis)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0280"
	S.key = "arkher.collab.buildpipeline.progress_analyzer"
	S.name = "Build Pipeline Progress Analyzer"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Build Pipeline"
	S.aspect = "Progress Analyzer"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.buildpipeline.release_recovery" }
	S.tags = { "y", "buildpipeline", "analyzer", "collab" }
	S.description = "Build Pipeline Progress Analyzer: throughput, trend and risk analysis for the Build Pipeline subsystem."
	S.params = {
		backlogLimit = 11,
		baseRadius = 600,
		baseWeight = 0.63,
		bias = 0.03,
		biasWeight = 0.08,
		ceiling = 323,
		detailWeight = 0.43,
		failureTolerance = 3,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.43,
		minThrottle = 0.215,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 3.3
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.collab.buildpipeline.progress_analyzer", window = 211, buckets = 19, threshold = 4.30 })
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
				engine.bus:subscribe("arkher.collab.buildpipeline.*", function(payload) inst.lastSignal = payload end)
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
