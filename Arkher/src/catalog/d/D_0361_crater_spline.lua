-- ARKHER SYSTEM D.0361 :: Crater Spline Feature
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: spline (curve-driven terrain features)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0361"
	S.key = "arkher.terrain.crater.spline_feature"
	S.name = "Crater Spline Feature"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Crater"
	S.aspect = "Spline Feature"
	S.kit = "spline"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.crater.noise_field" }
	S.tags = { "d", "crater", "spline", "terrain" }
	S.description = "Crater Spline Feature: curve-driven terrain features for the Crater subsystem."
	S.params = {
		backlogLimit = 8,
		baseRadius = 160,
		baseWeight = 0.6,
		bias = 0.0,
		biasWeight = 0.05,
		ceiling = 432,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.4,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.8,
		scale = 1.0
	}
	S.features = { "addPoint", "setPoint", "count", "evaluate", "tangent", "buildLUT", "arcLength", "pointAtDistance", "resample", "offset", "closestPoint", "stats", "buildDefault", "path", "corridor", "deviation", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("spline", { id = "arkher.terrain.crater.spline_feature", tension = 0.35, closed = false })
		inst.system = S
		inst.ctx = ctx

		function inst.buildDefault()
			if inst.count() > 0 then return inst.count() end
			local span = S.params.baseRadius / 2
			inst.addPoint(Vec.vec3(0, 0, 0))
			inst.addPoint(Vec.vec3(span, 0, 0))
			inst.addPoint(Vec.vec3(span * 2, 0, span))
			inst.addPoint(Vec.vec3(span * 3, 0, span))
			return inst.count()
		end
		function inst.path(samples)
			inst.buildDefault()
			return inst.resample(samples or 8)
		end
		function inst.corridor(width, samples)
			inst.buildDefault()
			return inst.offset(width or S.params.detailWeight * 10, samples or 8)
		end
		function inst.deviation(point)
			inst.buildDefault()
			local _, _, d = inst.closestPoint(point)
			return d
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
				engine.bus:subscribe("arkher.terrain.crater.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildDefault()
		local ok = inst.count() == 4
		ok = ok and inst.arcLength() > 0
		ok = ok and #inst.path(6) == 6
		ok = ok and #inst.corridor(5, 4) == 5
		local mid = inst.evaluate(0.5)
		ok = ok and type(mid.x) == "number"
		ok = ok and math.abs(inst.tangent(0.5):length() - 1) < 0.01
		ok = ok and inst.deviation(Vec.vec3(0, 0, 0)) < 1e-6
		return ok and inst.pointAtDistance(inst.arcLength() * 0.5) ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
