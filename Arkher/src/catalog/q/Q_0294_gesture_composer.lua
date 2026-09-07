-- ARKHER SYSTEM Q.0294 :: Gesture Theme Composition
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: composer (blending of theme signals into the final appearance)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0294"
	S.key = "arkher.ui.gesture.theme_composition"
	S.name = "Gesture Theme Composition"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Gesture"
	S.aspect = "Theme Composition"
	S.kit = "composer"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.gesture.navigation_graph" }
	S.tags = { "q", "gesture", "composer", "ui" }
	S.description = "Gesture Theme Composition: blending of theme signals into the final appearance for the Gesture subsystem."
	S.params = {
		backlogLimit = 8,
		baseRadius = 480,
		baseWeight = 0.5,
		bias = 0.0,
		biasWeight = 0.05,
		ceiling = 368,
		detailWeight = 0.4,
		failureTolerance = 0,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.4,
		minThrottle = 0.2,
		regressionSlope = 0.05,
		saturation = 0.7,
		scale = 3.0
	}
	S.features = { "addLayer", "setWeight", "evaluate", "normalize", "layerNames", "stats", "installDefaults", "evaluateAt", "profileCurve", "dominantLayer", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("composer", { id = "arkher.ui.gesture.theme_composition", mode = "alpha" })
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
				engine.bus:subscribe("arkher.ui.gesture.*", function(payload) inst.lastSignal = payload end)
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
