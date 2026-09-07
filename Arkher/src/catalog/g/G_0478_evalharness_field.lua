-- ARKHER SYSTEM G.0478 :: Evaluation Harness Feature Extraction
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: field (signal features feeding the model)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0478"
	S.key = "arkher.neural.evalharness.feature_extraction"
	S.name = "Evaluation Harness Feature Extraction"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Evaluation Harness"
	S.aspect = "Feature Extraction"
	S.kit = "field"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.evalharness.inference_core" }
	S.tags = { "g", "evalharness", "field", "neural" }
	S.description = "Evaluation Harness Feature Extraction: signal features feeding the model for the Evaluation Harness subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 280,
		baseWeight = 0.71,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 127,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "sample", "sampleRidged", "gradient", "slope", "terraced", "region", "stats", "height", "ridgeHeight", "patch", "steepness", "banded", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("field", { id = "arkher.neural.evalharness.feature_extraction", seed = 4671, frequency = 0.0118, octaves = 6, gain = 0.5, lacunarity = 2.0 })
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
				engine.bus:subscribe("arkher.neural.evalharness.*", function(payload) inst.lastSignal = payload end)
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
