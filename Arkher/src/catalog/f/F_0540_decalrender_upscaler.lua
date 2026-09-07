-- ARKHER SYSTEM F.0540 :: Decal Rendering Adaptive Resolution
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: upscaler (render-scale ladder and edge-aware reconstruction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0540"
	S.key = "arkher.render.decalrender.adaptive_resolution"
	S.name = "Decal Rendering Adaptive Resolution"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Decal Rendering"
	S.aspect = "Adaptive Resolution"
	S.kit = "upscaler"
	S.version = "1.0.0"
	S.deps = { "arkher.render.decalrender.temporal_resolve" }
	S.tags = { "f", "decalrender", "upscaler", "render" }
	S.description = "Decal Rendering Adaptive Resolution: render-scale ladder and edge-aware reconstruction for the Decal Rendering subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 600,
		baseWeight = 0.91,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 279,
		detailWeight = 0.31,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.155,
		regressionSlope = 0.105,
		saturation = 0.86,
		scale = 2.1
	}
	S.features = { "scale", "evaluate", "pixelsFor", "savings", "reconstruct", "sharpen", "quality", "describe", "stats", "adapt", "settle", "resolveLine", "crispen", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("upscaler", { id = "arkher.render.decalrender.adaptive_resolution", targetMs = 16.10, index = 5, sharpness = 0.51 })
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
				engine.bus:subscribe("arkher.render.decalrender.*", function(payload) inst.lastSignal = payload end)
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
