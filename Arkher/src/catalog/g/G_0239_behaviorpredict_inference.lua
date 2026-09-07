-- ARKHER SYSTEM G.0239 :: Behaviour Prediction Inference Core
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: inference (dense network forward pass and training)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0239"
	S.key = "arkher.neural.behaviorpredict.inference_core"
	S.name = "Behaviour Prediction Inference Core"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Behaviour Prediction"
	S.aspect = "Inference Core"
	S.kit = "inference"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "g", "behaviorpredict", "inference", "neural" }
	S.description = "Behaviour Prediction Inference Core: dense network forward pass and training for the Behaviour Prediction subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.67,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 75,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.87,
		scale = 3.7
	}
	S.features = { "addLayer", "forward", "loss", "train", "parameters", "flops", "quantize", "exportWeights", "importWeights", "memoryBytes", "stats", "buildModel", "predict", "fit", "compress", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("inference", { id = "arkher.neural.behaviorpredict.inference_core", seed = 57867 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildModel(hidden)
			if #inst.layers > 0 then return inst end
			inst.addLayer(3, hidden or 4, "tanh")
			inst.addLayer(hidden or 4, 1, "sigmoid")
			return inst
		end
		function inst.predict(features)
			inst.buildModel()
			return inst.forward(features or { 0.5, 0.5, 0.5 })[1]
		end
		function inst.fit(samples, epochs, lr)
			inst.buildModel()
			return inst.train(samples, epochs or 4, lr or 0.2)
		end
		function inst.compress(bits)
			inst.buildModel()
			return inst.quantize(bits or 8)
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
		inst.buildModel(4)
		local ok = inst.parameters() == 3 * 4 + 4 + 4 + 1
		local first = inst.predict({ 0.5, 0.25, 0.75 })
		local second = inst.predict({ 0.5, 0.25, 0.75 })
		ok = ok and first == second and first > 0 and first < 1
		ok = ok and inst.flops() > 0
		local weights = inst.exportWeights()
		ok = ok and #weights == inst.parameters()
		ok = ok and inst.importWeights(weights) == inst.parameters()
		local err = inst.compress(8)
		ok = ok and err >= 0 and err < 0.1
		ok = ok and inst.memoryBytes() < inst.parameters() * 4
		return ok and inst.stats().forwards >= 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
