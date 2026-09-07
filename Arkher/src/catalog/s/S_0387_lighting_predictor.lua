-- ARKHER SYSTEM S.0387 :: Lighting Predictive Optimizer
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: predictor (ahead-of-time optimization from forecasts)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0387"
	S.key = "arkher.do15.lighting.predictive_optimizer"
	S.name = "Lighting Predictive Optimizer"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Lighting"
	S.aspect = "Predictive Optimizer"
	S.kit = "predictor"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.lighting.dynamic_scaler" }
	S.tags = { "s", "lighting", "predictor", "do15" }
	S.description = "Lighting Predictive Optimizer: ahead-of-time optimization from forecasts for the Lighting subsystem."
	S.params = {
		backlogLimit = 11,
		baseRadius = 280,
		baseWeight = 0.63,
		bias = 0.03,
		biasWeight = 0.08,
		ceiling = 251,
		detailWeight = 0.23,
		failureTolerance = 3,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.43,
		minThrottle = 0.115,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 1.3
	}
	S.features = { "observe", "predict", "confidence", "verify", "accuracy", "stats", "feed", "projectHorizon", "risk", "trustworthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("predictor", { id = "arkher.do15.lighting.predictive_optimizer", method = "ema", alpha = 0.13, window = 59 })
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
				engine.bus:subscribe("arkher.do15.lighting.*", function(payload) inst.lastSignal = payload end)
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
