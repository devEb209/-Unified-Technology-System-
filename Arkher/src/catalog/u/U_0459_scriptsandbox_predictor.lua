-- ARKHER SYSTEM U.0459 :: Script Sandbox Completion Predictor
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: predictor (ranking of the next likely symbol)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0459"
	S.key = "arkher.code.scriptsandbox.completion_predictor"
	S.name = "Script Sandbox Completion Predictor"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Script Sandbox"
	S.aspect = "Completion Predictor"
	S.kit = "predictor"
	S.version = "1.0.0"
	S.deps = { "arkher.code.scriptsandbox.refactor_commands" }
	S.tags = { "u", "scriptsandbox", "predictor", "code" }
	S.description = "Script Sandbox Completion Predictor: ranking of the next likely symbol for the Script Sandbox subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 440,
		baseWeight = 0.51,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 107,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.71,
		scale = 1.1
	}
	S.features = { "observe", "predict", "confidence", "verify", "accuracy", "stats", "feed", "projectHorizon", "risk", "trustworthy", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("predictor", { id = "arkher.code.scriptsandbox.completion_predictor", method = "linear", alpha = 0.21, window = 75 })
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
				engine.bus:subscribe("arkher.code.scriptsandbox.*", function(payload) inst.lastSignal = payload end)
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
