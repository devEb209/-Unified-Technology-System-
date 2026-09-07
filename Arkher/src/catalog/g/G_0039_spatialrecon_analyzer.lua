-- ARKHER SYSTEM G.0039 :: Spatial Reconstruction Error Analysis
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: analyzer (residual and drift analysis)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0039"
	S.key = "arkher.neural.spatialrecon.error_analysis"
	S.name = "Spatial Reconstruction Error Analysis"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Spatial Reconstruction"
	S.aspect = "Error Analysis"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.spatialrecon.heuristic_policy" }
	S.tags = { "g", "spatialrecon", "analyzer", "neural" }
	S.description = "Spatial Reconstruction Error Analysis: residual and drift analysis for the Spatial Reconstruction subsystem."
	S.params = {
		backlogLimit = 36,
		baseRadius = 160,
		baseWeight = 0.88,
		bias = 0.28,
		biasWeight = 0.13,
		ceiling = 236,
		detailWeight = 0.68,
		failureTolerance = 3,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.68,
		minThrottle = 0.19,
		regressionSlope = 0.09,
		saturation = 0.83,
		scale = 2.8
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.neural.spatialrecon.error_analysis", window = 236, buckets = 8, threshold = 3.80 })
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
				engine.bus:subscribe("arkher.neural.spatialrecon.*", function(payload) inst.lastSignal = payload end)
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
