-- ARKHER SYSTEM G.0256 :: Performance Prediction Reconstruction
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: upscaler (resolution ladder and image reconstruction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0256"
	S.key = "arkher.neural.perfpredict.reconstruction"
	S.name = "Performance Prediction Reconstruction"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Performance Prediction"
	S.aspect = "Reconstruction"
	S.kit = "upscaler"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.perfpredict.temporal_history" }
	S.tags = { "g", "perfpredict", "upscaler", "neural" }
	S.description = "Performance Prediction Reconstruction: resolution ladder and image reconstruction for the Performance Prediction subsystem."
	S.params = {
		backlogLimit = 8,
		baseRadius = 160,
		baseWeight = 0.9,
		bias = 0.0,
		biasWeight = 0.05,
		ceiling = 512,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.4,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.85,
		scale = 1.0
	}
	S.features = { "scale", "evaluate", "pixelsFor", "savings", "reconstruct", "sharpen", "quality", "describe", "stats", "adapt", "settle", "resolveLine", "crispen", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("upscaler", { id = "arkher.neural.perfpredict.reconstruction", targetMs = 11.10, index = 3, sharpness = 0.20 })
		inst.system = S
		inst.ctx = ctx

		function inst.adapt(frameMs)
			return inst.evaluate(frameMs or inst.targetMs)
		end
		function inst.settle(frameMs, iterations)
			for _ = 1, (iterations or 6) do inst.evaluate(frameMs) end
			return inst.scale()
		end
		function inst.resolveLine(samples, target)
			return inst.reconstruct(samples or { 0, 0.5, 1 }, target or 6)
		end
		function inst.crispen(samples, amount)
			return inst.sharpen(samples or { 0.2, 0.5, 0.2 }, amount)
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
				engine.bus:subscribe("arkher.neural.perfpredict.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local heavy = inst.settle(60, 8)
		local ok = heavy <= inst.ladder[1] + 1e-9
		local light = inst.settle(1, 12)
		ok = ok and light >= inst.ladder[#inst.ladder] - 1e-9
		local line = inst.resolveLine({ 0, 0, 1, 1 }, 8)
		ok = ok and #line == 8 and line[1] <= 0.05 and line[8] >= 0.95
		local crisp = inst.crispen({ 0.2, 0.5, 0.2 }, 0.4)
		ok = ok and #crisp == 3
		ok = ok and inst.quality() > 0 and inst.quality() <= 1
		ok = ok and inst.savings(1000, 1000) >= 0
		return ok and inst.stats().evaluations > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
