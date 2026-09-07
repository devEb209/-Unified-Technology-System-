-- ARKHER SYSTEM S.0538 :: Thermal Numeric Solver
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: solver (iterative convergence of the subsystem model)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0538"
	S.key = "arkher.do15.thermal.numeric_solver"
	S.name = "Thermal Numeric Solver"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Thermal"
	S.aspect = "Numeric Solver"
	S.kit = "solver"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.thermal.cost_graph" }
	S.tags = { "s", "thermal", "solver", "do15" }
	S.description = "Thermal Numeric Solver: iterative convergence of the subsystem model for the Thermal subsystem."
	S.params = {
		backlogLimit = 47,
		baseRadius = 440,
		baseWeight = 0.69,
		bias = 0.39,
		biasWeight = 0.24,
		ceiling = 183,
		detailWeight = 0.39,
		failureTolerance = 4,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.79,
		minThrottle = 0.195,
		regressionSlope = 0.145,
		saturation = 0.89,
		scale = 2.9
	}
	S.features = { "solve", "integrate", "relax", "converged", "stats", "converge", "stepPhysics", "stiffness", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("solver", { id = "arkher.do15.thermal.numeric_solver", method = "iterative", iterations = 13, tolerance = 0.00010, damping = 0.59 })
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
				engine.bus:subscribe("arkher.do15.thermal.*", function(payload) inst.lastSignal = payload end)
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
