-- ARKHER SYSTEM M.0259 :: Furniture Noise Field
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: field (coherent noise driving the generator)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0259"
	S.key = "arkher.proc.furniture.noise_field"
	S.name = "Furniture Noise Field"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Furniture"
	S.aspect = "Noise Field"
	S.kit = "field"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.furniture.mesh_synthesis" }
	S.tags = { "m", "furniture", "field", "proc" }
	S.description = "Furniture Noise Field: coherent noise driving the generator for the Furniture subsystem."
	S.params = {
		backlogLimit = 9,
		baseRadius = 360,
		baseWeight = 0.81,
		bias = 0.01,
		biasWeight = 0.06,
		ceiling = 297,
		detailWeight = 0.61,
		failureTolerance = 1,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.41,
		minThrottle = 0.155,
		regressionSlope = 0.055,
		saturation = 0.76,
		scale = 2.1
	}
	S.features = { "sample", "sampleRidged", "gradient", "slope", "terraced", "region", "stats", "height", "ridgeHeight", "patch", "steepness", "banded", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("field", { id = "arkher.proc.furniture.noise_field", seed = 66281, frequency = 0.0043, octaves = 4, gain = 0.5, lacunarity = 2.0 })
		inst.system = S
		inst.ctx = ctx

		function inst.height(x, y)
			return inst.sample(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.ridgeHeight(x, y)
			return inst.sampleRidged(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.patch(size, step)
			local n = size or 8
			return inst.region(0, 0, n, n, step or 2)
		end
		function inst.steepness(x, y)
			return inst.slope(x, y)
		end
		function inst.banded(x, y, steps)
			return inst.terraced(x, y, steps or (4 + S.params.horizon % 6))
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
				engine.bus:subscribe("arkher.proc.furniture.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local a = inst.sample(12.5, -7.25)
		local b = inst.sample(12.5, -7.25)
		local ok = a == b and type(a) == "number"
		ok = ok and inst.height(3, 3) == inst.sample(3, 3) * (20 + S.params.ceiling / 10)
		ok = ok and type(inst.ridgeHeight(3, 3)) == "number"
		local rows = inst.patch(8, 2)
		ok = ok and #rows == 5 and #rows[1] == 5
		ok = ok and inst.steepness(4, 4) >= 0
		local terr = inst.banded(4, 4, 5)
		ok = ok and type(terr) == "number"
		return ok and inst.stats().samples > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
