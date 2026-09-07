-- ARKHER SYSTEM D.0033 :: Sculpting Heightfield
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: heightfield (editable height data with sculpt and erosion)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0033"
	S.key = "arkher.terrain.sculpting.heightfield"
	S.name = "Sculpting Heightfield"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Sculpting"
	S.aspect = "Heightfield"
	S.kit = "heightfield"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "d", "sculpting", "heightfield", "terrain" }
	S.description = "Sculpting Heightfield: editable height data with sculpt and erosion for the Sculpting subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 280,
		baseWeight = 0.61,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 295,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.81,
		scale = 3.1
	}
	S.features = { "inBounds", "get", "set", "fill", "applyNoise", "sample", "normalAt", "slopeAt", "raise", "lower", "flatten", "smooth", "terrace", "erodeThermal", "erodeHydraulic", "range", "normalize", "downsample", "checksum", "stats", "shape", "sculptAt", "profile", "roughness", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("heightfield", { id = "arkher.terrain.sculpting.heightfield", width = 16, height = 16, cellSize = 5 })
		inst.system = S
		inst.ctx = ctx

		function inst.shape()
			inst.applyNoise({ frequency = 0.02 + S.params.detailWeight * 0.05,
				amplitude = 20 + S.params.ceiling / 8, seed = S.params.horizon * 7919, octaves = 3 })
			return inst.range()
		end
		function inst.sculptAt(x, y, radius, strength)
			return inst.raise(x, y, radius or 3, strength or S.params.baseWeight * 10)
		end
		function inst.profile(samples)
			local out = {}
			local n = samples or 8
			for i = 0, n do
				local t = i / n
				out[#out + 1] = inst.sample(t * (inst.width - 1) * inst.cellSize, (inst.height / 2) * inst.cellSize)
			end
			return out
		end
		function inst.roughness()
			local total, n = 0, 0
			for y = 2, inst.height - 1, 2 do
				for x = 2, inst.width - 1, 2 do
					total = total + inst.slopeAt(x, y)
					n = n + 1
				end
			end
			if n == 0 then return 0 end
			return total / n
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
				engine.bus:subscribe("arkher.terrain.sculpting.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local lo, hi = inst.shape()
		local ok = hi > lo
		local before = inst.get(4, 4)
		inst.sculptAt(4, 4, 3, 15)
		ok = ok and inst.get(4, 4) > before
		inst.flatten(6, 6, 2, 0, 1)
		ok = ok and math.abs(inst.get(6, 6)) < 0.001
		ok = ok and #inst.profile(4) == 5
		ok = ok and inst.roughness() >= 0
		ok = ok and inst.erodeThermal(1, 1.0, 0.5) >= 0
		local lod = inst.downsample()
		ok = ok and lod.width == math.floor(inst.width / 2)
		inst.normalize(0, 10)
		local lo2, hi2 = inst.range()
		return ok and math.abs(lo2) < 0.001 and math.abs(hi2 - 10) < 0.001
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
