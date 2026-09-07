-- ARKHER SYSTEM I.0129 :: Playback Speed Analysis
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: analyzer (pop, drift and cost analysis of playback)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0129"
	S.key = "arkher.anim.playbackspeed.analysis"
	S.name = "Playback Speed Analysis"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Playback Speed"
	S.aspect = "Analysis"
	S.kit = "analyzer"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.playbackspeed.quality_policy" }
	S.tags = { "i", "playbackspeed", "analyzer", "anim" }
	S.description = "Playback Speed Analysis: pop, drift and cost analysis of playback for the Playback Speed subsystem."
	S.params = {
		backlogLimit = 32,
		baseRadius = 480,
		baseWeight = 0.94,
		bias = 0.24,
		biasWeight = 0.09,
		ceiling = 552,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.64,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.89,
		scale = 2.4
	}
	S.features = { "submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats", "feed", "regression", "budgetBreaches", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("analyzer", { id = "arkher.anim.playbackspeed.analysis", window = 192, buckets = 16, threshold = 3.40 })
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
				engine.bus:subscribe("arkher.anim.playbackspeed.*", function(payload) inst.lastSignal = payload end)
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
