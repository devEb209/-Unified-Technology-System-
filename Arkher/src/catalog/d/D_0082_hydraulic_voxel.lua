-- ARKHER SYSTEM D.0082 :: Hydraulic Erosion Voxel Volume
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: voxel (sparse volumetric material data)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0082"
	S.key = "arkher.terrain.hydraulic.voxel_volume"
	S.name = "Hydraulic Erosion Voxel Volume"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Hydraulic Erosion"
	S.aspect = "Voxel Volume"
	S.kit = "voxel"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.hydraulic.heightfield" }
	S.tags = { "d", "hydraulic", "voxel", "terrain" }
	S.description = "Hydraulic Erosion Voxel Volume: sparse volumetric material data for the Hydraulic Erosion subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 400,
		baseWeight = 0.52,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 218,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.72,
		scale = 2.2
	}
	S.features = { "set", "get", "has", "fillBox", "fillSphere", "carveSphere", "neighbors", "surfaceFaces", "floodFill", "bounds", "histogram", "stats", "buildSample", "carveAt", "density", "surfaceRatio", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("voxel", { id = "arkher.terrain.hydraulic.voxel_volume" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildSample()
			if inst.count > 0 then return inst.count end
			inst.fillBox(1, 1, 1, 3, 3, 3, inst.materials[1])
			return inst.count
		end
		function inst.carveAt(x, y, z, radius) return inst.carveSphere(x, y, z, radius or 1) end
		function inst.density()
			local b = inst.bounds()
			if not b then return 0 end
			local volume = math.max(1, (b.max.x - b.min.x + 1) * (b.max.y - b.min.y + 1) * (b.max.z - b.min.z + 1))
			return inst.count / volume
		end
		function inst.surfaceRatio()
			if inst.count == 0 then return 0 end
			return inst.surfaceFaces() / (inst.count * 6)
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
				engine.bus:subscribe("arkher.terrain.hydraulic.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildSample()
		local ok = inst.count == 27
		ok = ok and inst.surfaceFaces() == 54
		ok = ok and math.abs(inst.density() - 1) < 0.001
		ok = ok and inst.surfaceRatio() > 0.3
		ok = ok and inst.carveAt(2, 2, 2, 0.9) == 1
		ok = ok and inst.count == 26
		ok = ok and inst.floodFill(1, 1, 1, inst.materials[2]) > 10
		return ok and inst.bounds() ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
