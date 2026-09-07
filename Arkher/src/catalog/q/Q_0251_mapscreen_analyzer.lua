-- ARKHER SYSTEM Q.0251 :: Map Screen Usability Analysis
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: analyzer (reachability, latency and abandonment analysis)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0251"
	S.key = "arkher.ui.mapscreen.usability_analysis"
	S.name = "Map Screen Usability Analysis"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Map Screen"
	S.aspect = "Usability Analysis"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.mapscreen.frame_budget" }
	S.tags = { "q", "mapscreen", "analyzer", "ui" }
	S.description = "Map Screen Usability Analysis: reachability, latency and abandonment analysis for the Map Screen subsystem."
	S.params = {
		backlogLimit = 22,
		baseRadius = 240,
		baseWeight = 0.94,
		bias = 0.14,
		biasWeight = 0.19,
		ceiling = 414,
		detailWeight = 0.34,
		failureTolerance = 4,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.54,
		minThrottle = 0.17,
		regressionSlope = 0.12,
		saturation = 0.89,
		scale = 2.4
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.ui.mapscreen.usability_analysis", window = 142, buckets = 10, threshold = 3.40 })
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
				engine.bus:subscribe("arkher.ui.mapscreen.*", function(payload) inst.lastSignal = payload end)
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
