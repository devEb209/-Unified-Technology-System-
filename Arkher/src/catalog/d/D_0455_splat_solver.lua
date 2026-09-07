-- ARKHER SYSTEM D.0455 :: Texture Splat Erosion Solver
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: solver (iterative convergence of the erosion model)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0455"
	S.key = "arkher.terrain.splat.erosion_solver"
	S.name = "Texture Splat Erosion Solver"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Texture Splat"
	S.aspect = "Erosion Solver"
	S.kit = "solver"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.splat.tile_streaming" }
	S.tags = { "d", "splat", "solver", "terrain" }
	S.description = "Texture Splat Erosion Solver: iterative convergence of the erosion model for the Texture Splat subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.53,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 365,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.73,
		scale = 2.3
	}
	S.features = { "solve", "integrate", "relax", "converged", "stats", "converge", "stepPhysics", "stiffness", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("solver", { id = "arkher.terrain.splat.erosion_solver", method = "iterative", iterations = 19, tolerance = 0.00010, damping = 0.43 })
		inst.system = S
		inst.ctx = ctx

	function inst.converge(initial, targetFn, correctFn, iterations)
		local state = { value = initial }
		local constraints = { {
			evaluate = function(s) return targetFn(s.value) end,
			correct = correctFn or function(s, e) s.value = s.value + e end,
		} }
		local saved = inst.iterations
		inst.iterations = iterations or saved
		local out, iters, residual = inst.solve(constraints, state)
		inst.iterations = saved
		return out.value, iters, residual
	end
	function inst.stepPhysics(value, velocity, accel, dt) return inst.integrate(value, velocity, accel, dt, S.params.integrator) end
	function inst.stiffness() return 1 - inst.damping end

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
				engine.bus:subscribe("arkher.terrain.splat.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local value = inst.converge(0, function(v) return 100 - v end, nil, 80)
		return math.abs(value - 100) < 5 and inst.stats().solved > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
