-- ARKHER SYSTEM M.0469 :: Rock Field Noise Field
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: field (coherent noise driving the generator)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0469"
	S.key = "arkher.proc.rockfield.noise_field"
	S.name = "Rock Field Noise Field"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Rock Field"
	S.aspect = "Noise Field"
	S.kit = "field"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.rockfield.mesh_synthesis" }
	S.tags = { "m", "rockfield", "field", "proc" }
	S.description = "Rock Field Noise Field: coherent noise driving the generator for the Rock Field subsystem."
	S.params = {
		backlogLimit = 42,
		baseRadius = 400,
		baseWeight = 0.64,
		bias = 0.34,
		biasWeight = 0.19,
		ceiling = 538,
		detailWeight = 0.74,
		failureTolerance = 4,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.74,
		minThrottle = 0.22,
		regressionSlope = 0.12,
		saturation = 0.84,
		scale = 3.4
	}
	S.features = { "sample", "sampleRidged", "gradient", "slope", "terraced", "region", "stats", "height", "ridgeHeight", "patch", "steepness", "banded", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("field", { id = "arkher.proc.rockfield.noise_field", seed = 23514, frequency = 0.0125, octaves = 5, gain = 0.5, lacunarity = 2.0 })
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
				engine.bus:subscribe("arkher.proc.rockfield.*", function(payload) inst.lastSignal = payload end)
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
