-- ARKHER SYSTEM N.0226 :: Magic Aura Curve Authoring
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: spline (authored curves driving the effect over its life)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0226"
	S.key = "arkher.vfx.magicaura.curve_authoring"
	S.name = "Magic Aura Curve Authoring"
	S.category = "N"
	S.family = "VFX"
	S.area = "Magic Aura"
	S.aspect = "Curve Authoring"
	S.kit = "spline"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.magicaura.ribbon_and_trail" }
	S.tags = { "n", "magicaura", "spline", "vfx" }
	S.description = "Magic Aura Curve Authoring: authored curves driving the effect over its life for the Magic Aura subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 200,
		baseWeight = 0.75,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 365,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.7,
		scale = 3.5
	}
	S.features = { "addPoint", "setPoint", "count", "evaluate", "tangent", "buildLUT", "arcLength", "pointAtDistance", "resample", "offset", "closestPoint", "stats", "buildDefault", "path", "corridor", "deviation", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("spline", { id = "arkher.vfx.magicaura.curve_authoring", tension = 0.40, closed = false })
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
				engine.bus:subscribe("arkher.vfx.magicaura.*", function(payload) inst.lastSignal = payload end)
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
