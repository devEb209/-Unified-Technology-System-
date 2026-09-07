-- ARKHER SYSTEM M.0426 :: Forest Mesh Synthesis
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: mesh (procedural triangle mesh construction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0426"
	S.key = "arkher.proc.forest.mesh_synthesis"
	S.name = "Forest Mesh Synthesis"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Forest"
	S.aspect = "Mesh Synthesis"
	S.kit = "mesh"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.forest.spline_layout" }
	S.tags = { "m", "forest", "mesh", "proc" }
	S.description = "Forest Mesh Synthesis: procedural triangle mesh construction for the Forest subsystem."
	S.params = {
		backlogLimit = 17,
		baseRadius = 200,
		baseWeight = 0.89,
		bias = 0.09,
		biasWeight = 0.14,
		ceiling = 505,
		detailWeight = 0.69,
		failureTolerance = 4,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.49,
		minThrottle = 0.195,
		regressionSlope = 0.095,
		saturation = 0.84,
		scale = 2.9
	}
	S.features = { "addVertex", "addTriangle", "addQuad", "box", "extrude", "revolve", "computeNormals", "weld", "area", "bounds", "simplify", "stats", "buildBox", "buildTower", "optimize", "surfaceArea", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("mesh", { id = "arkher.proc.forest.mesh_synthesis" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildBox(size)
			local s = size or (4 + S.params.detailWeight * 8)
			inst.box(Vec.vec3(0, 0, 0), Vec.vec3(s, s, s))
			return inst.stats().triangles
		end
		function inst.buildTower(footprint, height)
			local f = footprint or 8
			local poly = { Vec.vec3(0, 0, 0), Vec.vec3(f, 0, 0), Vec.vec3(f, 0, f), Vec.vec3(0, 0, f) }
			return inst.extrude(poly, height or (10 + S.params.ceiling / 20))
		end
		function inst.optimize()
			local welded = inst.weld()
			local dropped = inst.simplify(1e-6)
			inst.computeNormals()
			return welded, dropped
		end
		function inst.surfaceArea() return inst.area() end

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
				engine.bus:subscribe("arkher.proc.forest.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local tris = inst.buildBox(10)
		local ok = tris == 12 and inst.stats().vertices == 8
		ok = ok and math.abs(inst.surfaceArea() - 600) < 1
		ok = ok and inst.buildTower(8, 20) == 4
		ok = ok and inst.stats().triangles > 12
		local welded, dropped = inst.optimize()
		ok = ok and welded >= 0 and dropped >= 0
		ok = ok and inst.stats().normals == inst.stats().vertices
		return ok and inst.bounds() ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
