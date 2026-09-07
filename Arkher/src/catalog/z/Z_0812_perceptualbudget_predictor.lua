-- ARKHER SYSTEM Z.0812 :: Perceptual Budgeting Predictive Optimization
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: predictor (forecast-driven optimization before the cost is paid)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0812"
	S.key = "arkher.origin.perceptualbudget.predictive_optimization"
	S.name = "Perceptual Budgeting Predictive Optimization"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Perceptual Budgeting"
	S.aspect = "Predictive Optimization"
	S.kit = "predictor"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.perceptualbudget.adaptive_workflow" }
	S.tags = { "z", "perceptualbudget", "predictor", "origin" }
	S.description = "Perceptual Budgeting Predictive Optimization: forecast-driven optimization before the cost is paid for the Perceptual Budgeting subsystem."
	S.params = {
		backlogLimit = 44,
		baseRadius = 480,
		baseWeight = 0.66,
		bias = 0.36,
		biasWeight = 0.21,
		ceiling = 244,
		detailWeight = 0.76,
		failureTolerance = 1,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.76,
		minThrottle = 0.23,
		regressionSlope = 0.13,
		saturation = 0.86,
		scale = 3.6
	}
	S.features = { "observe", "predict", "confidence", "verify", "accuracy", "stats", "feed", "projectHorizon", "risk", "trustworthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("predictor", { id = "arkher.origin.perceptualbudget.predictive_optimization", method = "markov", alpha = 0.46, window = 52 })
		inst.system = S
		inst.ctx = ctx

	function inst.feed(series)
		for _, v in ipairs(series) do inst.observe(v) end
		return inst.value
	end
	function inst.projectHorizon(steps)
		local out = {}
		for i = 1, (steps or 4) do out[i] = inst.predict(i) end
		return out
	end
	function inst.risk(threshold)
		local p = inst.predict(S.params.horizon)
		if type(p) ~= "number" then return 0 end
		if p <= threshold then return 0 end
		return math.min(1, (p - threshold) / math.max(threshold, 1e-6))
	end
	function inst.trustworthy() return inst.confidence() >= S.params.minConfidence end

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
				engine.bus:subscribe("arkher.origin.perceptualbudget.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		if inst.method == "markov" then
			inst.observe("calm") inst.observe("spike") inst.observe("calm") inst.observe("spike")
			return inst.predict() ~= nil
		end
		inst.feed({ 2, 4, 6, 8, 10 })
		local p = inst.predict(1)
		return type(p) == "number" and p > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
