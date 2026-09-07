-- ARKHER SYSTEM G.0240 :: Behaviour Prediction Feature Extraction
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: field (signal features feeding the model)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0240"
	S.key = "arkher.neural.behaviorpredict.feature_extraction"
	S.name = "Behaviour Prediction Feature Extraction"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Behaviour Prediction"
	S.aspect = "Feature Extraction"
	S.kit = "field"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.behaviorpredict.inference_core" }
	S.tags = { "g", "behaviorpredict", "field", "neural" }
	S.description = "Behaviour Prediction Feature Extraction: signal features feeding the model for the Behaviour Prediction subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 600,
		baseWeight = 0.73,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 471,
		detailWeight = 0.43,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.215,
		regressionSlope = 0.065,
		saturation = 0.93,
		scale = 3.3
	}
	S.features = { "sample", "sampleRidged", "gradient", "slope", "terraced", "region", "stats", "height", "ridgeHeight", "patch", "steepness", "banded", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("field", { id = "arkher.neural.behaviorpredict.feature_extraction", seed = 86423, frequency = 0.0097, octaves = 6, gain = 0.5, lacunarity = 2.0 })
		inst.system = S
		inst.ctx = ctx

		function inst.height(x, y)
			return inst.sample(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.ridgeHeight(x, y)
			return inst.sampleRidged(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.patch(size, step)
			local n = size or 8
			return inst.region(0, 0, n, n, step or 2)
		end
		function inst.steepness(x, y)
			return inst.slope(x, y)
		end
		function inst.banded(x, y, steps)
			return inst.terraced(x, y, steps or (4 + S.params.horizon % 6))
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
				engine.bus:subscribe("arkher.neural.behaviorpredict.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local a = inst.sample(12.5, -7.25)
		local b = inst.sample(12.5, -7.25)
		local ok = a == b and type(a) == "number"
		ok = ok and inst.height(3, 3) == inst.sample(3, 3) * (20 + S.params.ceiling / 10)
		ok = ok and type(inst.ridgeHeight(3, 3)) == "number"
		local rows = inst.patch(8, 2)
		ok = ok and #rows == 5 and #rows[1] == 5
		ok = ok and inst.steepness(4, 4) >= 0
		local terr = inst.banded(4, 4, 5)
		ok = ok and type(terr) == "number"
		return ok and inst.stats().samples > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
