-- ARKHER SYSTEM M.0464 :: Rock Field Constraint Solver
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: wfc (socket-constrained tiling with entropy collapse)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0464"
	S.key = "arkher.proc.rockfield.constraint_solver"
	S.name = "Rock Field Constraint Solver"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Rock Field"
	S.aspect = "Constraint Solver"
	S.kit = "wfc"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.rockfield.grammar" }
	S.tags = { "m", "rockfield", "wfc", "proc" }
	S.description = "Rock Field Constraint Solver: socket-constrained tiling with entropy collapse for the Rock Field subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 200,
		baseWeight = 0.77,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 193,
		detailWeight = 0.57,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.135,
		regressionSlope = 0.135,
		saturation = 0.72,
		scale = 1.7
	}
	S.features = { "defineTile", "compatible", "solve", "at", "histogram", "validate", "stats", "installTiles", "generate", "tileHistogram", "consistency", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("wfc", { id = "arkher.proc.rockfield.constraint_solver" })
		inst.system = S
		inst.ctx = ctx

		function inst.installTiles()
			if inst.tiles["core"] then return inst end
			inst.defineTile("core", { up = "a", down = "a", left = "a", right = "a" }, 3)
			inst.defineTile("edge", { up = "a", down = "b", left = "a", right = "a" }, 2)
			inst.defineTile("outer", { up = "b", down = "b", left = "a", right = "a" }, 1)
			return inst
		end
		function inst.generate(width, height)
			inst.installTiles()
			return inst.solve(width or 5, height or 5, S.params.horizon * 104729 + 7)
		end
		function inst.tileHistogram()
			if not inst.result then inst.generate() end
			return inst.histogram()
		end
		function inst.consistency()
			if not inst.result then inst.generate() end
			local ok, bad = inst.validate()
			return ok, bad
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
				engine.bus:subscribe("arkher.proc.rockfield.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local grid = inst.generate(5, 5)
		local ok = #grid == 25
		for i = 1, 25 do ok = ok and inst.tiles[grid[i]] ~= nil end
		local twin = Kits.create("wfc", { id = "probe" })
		twin.defineTile("core", { up = "a", down = "a", left = "a", right = "a" }, 3)
		twin.defineTile("edge", { up = "a", down = "b", left = "a", right = "a" }, 2)
		twin.defineTile("outer", { up = "b", down = "b", left = "a", right = "a" }, 1)
		local grid2 = twin.solve(5, 5, S.params.horizon * 104729 + 7)
		for i = 1, 25 do ok = ok and grid[i] == grid2[i] end
		local histogram = inst.tileHistogram()
		local total = 0
		for _, n in pairs(histogram) do total = total + n end
		ok = ok and total == 25
		local consistent = inst.consistency()
		return ok and type(consistent) == "boolean" 
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
