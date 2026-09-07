-- ARKHER SYSTEM W.0064 :: Tracking Shot Shot Composition
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: composer (blending of the signals that make up the final shot)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0064"
	S.key = "arkher.cine.tracking.shot_composition"
	S.name = "Tracking Shot Shot Composition"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Tracking Shot"
	S.aspect = "Shot Composition"
	S.kit = "composer"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.tracking.colour_grade" }
	S.tags = { "w", "tracking", "composer", "cine" }
	S.description = "Tracking Shot Shot Composition: blending of the signals that make up the final shot for the Tracking Shot subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.97,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 491,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.92,
		scale = 3.7
	}
	S.features = { "addLayer", "setWeight", "evaluate", "normalize", "layerNames", "stats", "installDefaults", "evaluateAt", "profileCurve", "dominantLayer", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("composer", { id = "arkher.cine.tracking.shot_composition", mode = "overlay" })
		inst.system = S
		inst.ctx = ctx

	function inst.installDefaults()
		inst.addLayer("base", S.params.baseWeight, function(x) return math.min(1, math.max(0, x)) end, inst.mode)
		inst.addLayer("detail", S.params.detailWeight, function(x) return math.min(1, math.max(0, x * 0.5)) end, inst.mode)
		inst.addLayer("bias", S.params.biasWeight, function() return S.params.bias end, inst.mode)
		return inst
	end
	function inst.evaluateAt(x) return inst.evaluate(x) end
	function inst.profileCurve(steps)
		local out = {}
		for i = 0, (steps or 8) do out[#out + 1] = inst.evaluate(i / (steps or 8)) end
		return out
	end
	function inst.dominantLayer()
		local best, bestW = nil, -1
		for _, l in ipairs(inst.layers) do if l.weight > bestW then best, bestW = l.name, l.weight end end
		return best
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
				engine.bus:subscribe("arkher.cine.tracking.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local curve = inst.profileCurve(4)
		return #curve == 5 and type(inst.evaluateAt(0.5)) == "number" and inst.dominantLayer() ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
