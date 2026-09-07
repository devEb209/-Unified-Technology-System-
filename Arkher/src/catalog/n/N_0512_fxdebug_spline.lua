-- ARKHER SYSTEM N.0512 :: Effect Debug Curve Authoring
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: spline (authored curves driving the effect over its life)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0512"
	S.key = "arkher.vfx.fxdebug.curve_authoring"
	S.name = "Effect Debug Curve Authoring"
	S.category = "N"
	S.family = "VFX"
	S.area = "Effect Debug"
	S.aspect = "Curve Authoring"
	S.kit = "spline"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.fxdebug.ribbon_and_trail" }
	S.tags = { "n", "fxdebug", "spline", "vfx" }
	S.description = "Effect Debug Curve Authoring: authored curves driving the effect over its life for the Effect Debug subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 240,
		baseWeight = 0.8,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 574,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.75,
		scale = 3.0
	}
	S.features = { "addPoint", "setPoint", "count", "evaluate", "tangent", "buildLUT", "arcLength", "pointAtDistance", "resample", "offset", "closestPoint", "stats", "buildDefault", "path", "corridor", "deviation", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("spline", { id = "arkher.vfx.fxdebug.curve_authoring", tension = 0.65, closed = false })
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
				engine.bus:subscribe("arkher.vfx.fxdebug.*", function(payload) inst.lastSignal = payload end)
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
