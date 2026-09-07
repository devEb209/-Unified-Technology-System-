-- ARKHER SYSTEM D.0517 :: Collision Field Mesh Builder
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: mesh (triangle mesh extraction for the terrain surface)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0517"
	S.key = "arkher.terrain.collisionfield.mesh_builder"
	S.name = "Collision Field Mesh Builder"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Collision Field"
	S.aspect = "Mesh Builder"
	S.kit = "mesh"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.collisionfield.material_composer" }
	S.tags = { "d", "collisionfield", "mesh", "terrain" }
	S.description = "Collision Field Mesh Builder: triangle mesh extraction for the terrain surface for the Collision Field subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 560,
		baseWeight = 0.62,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 210,
		detailWeight = 0.42,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.21,
		regressionSlope = 0.06,
		saturation = 0.82,
		scale = 3.2
	}
	S.features = { "addVertex", "addTriangle", "addQuad", "box", "extrude", "revolve", "computeNormals", "weld", "area", "bounds", "simplify", "stats", "buildBox", "buildTower", "optimize", "surfaceArea", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("mesh", { id = "arkher.terrain.collisionfield.mesh_builder" })
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
				engine.bus:subscribe("arkher.terrain.collisionfield.*", function(payload) inst.lastSignal = payload end)
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
