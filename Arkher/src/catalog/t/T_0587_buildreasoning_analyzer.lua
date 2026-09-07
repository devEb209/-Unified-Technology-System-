-- ARKHER SYSTEM T.0587 :: Build Reasoning Learning Analysis
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: analyzer (trend, anomaly and improvement analysis of the agent)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0587"
	S.key = "arkher.ai.buildreasoning.learning_analysis"
	S.name = "Build Reasoning Learning Analysis"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Build Reasoning"
	S.aspect = "Learning Analysis"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.buildreasoning.model_inference" }
	S.tags = { "t", "buildreasoning", "analyzer", "ai" }
	S.description = "Build Reasoning Learning Analysis: trend, anomaly and improvement analysis of the agent for the Build Reasoning subsystem."
	S.params = {
		backlogLimit = 16,
		baseRadius = 320,
		baseWeight = 0.78,
		bias = 0.08,
		biasWeight = 0.13,
		ceiling = 520,
		detailWeight = 0.48,
		failureTolerance = 3,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.48,
		minThrottle = 0.24,
		regressionSlope = 0.09,
		saturation = 0.73,
		scale = 3.8
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.ai.buildreasoning.learning_analysis", window = 176, buckets = 12, threshold = 4.80 })
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
				engine.bus:subscribe("arkher.ai.buildreasoning.*", function(payload) inst.lastSignal = payload end)
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
