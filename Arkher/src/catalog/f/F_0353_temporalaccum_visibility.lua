-- ARKHER SYSTEM F.0353 :: Temporal Accumulation Visibility Set
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: visibility (cell, portal and occluder visibility)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0353"
	S.key = "arkher.render.temporalaccum.visibility_set"
	S.name = "Temporal Accumulation Visibility Set"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Temporal Accumulation"
	S.aspect = "Visibility Set"
	S.kit = "visibility"
	S.version = "1.0.0"
	S.deps = { "arkher.render.temporalaccum.view_and_culling" }
	S.tags = { "f", "temporalaccum", "visibility", "render" }
	S.description = "Temporal Accumulation Visibility Set: cell, portal and occluder visibility for the Temporal Accumulation subsystem."
	S.params = {
		backlogLimit = 37,
		baseRadius = 200,
		baseWeight = 0.59,
		bias = 0.29,
		biasWeight = 0.14,
		ceiling = 125,
		detailWeight = 0.69,
		failureTolerance = 4,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.69,
		minThrottle = 0.195,
		regressionSlope = 0.095,
		saturation = 0.79,
		scale = 2.9
	}
	S.features = { "addCell", "addPortal", "addItem", "cellAt", "computePVS", "visibleItems", "addOccluder", "occluded", "cullList", "coverage", "stats", "buildLevel", "setFrom", "itemsFrom", "blockLine", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("visibility", { id = "arkher.render.temporalaccum.visibility_set", maxDepth = 3 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildLevel(rooms)
			if inst.cells["cell1"] then return inst end
			local Spatial = A:import("arkher/kernel/spatial")
			local n = rooms or 4
			for i = 1, n do
				inst.addCell("cell" .. i, Spatial.aabb(Vec.vec3(i * 20, 0, 0), Vec.vec3(i * 20 + 18, 10, 18)))
				inst.addItem("cell" .. i, "item" .. i)
			end
			for i = 1, n - 1 do inst.addPortal("cell" .. i, "cell" .. (i + 1)) end
			return inst
		end
		function inst.setFrom(cell, depth)
			inst.buildLevel()
			return inst.computePVS(cell or "cell1", depth)
		end
		function inst.itemsFrom(cell, depth)
			inst.buildLevel()
			return inst.visibleItems(cell or "cell1", depth)
		end
		function inst.blockLine(from, to)
			inst.buildLevel()
			return inst.occluded(from, to)
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
				engine.bus:subscribe("arkher.render.temporalaccum.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildLevel(4)
		local pvs = inst.setFrom("cell1", 1)
		local ok = #pvs == 2
		ok = ok and #inst.setFrom("cell1", 3) == 4
		ok = ok and #inst.itemsFrom("cell1", 1) == 2
		ok = ok and inst.cellAt(Vec.vec3(25, 1, 1)) == "cell1"
		local Spatial = A:import("arkher/kernel/spatial")
		inst.addOccluder(Spatial.aabb(Vec.vec3(-1, -1, 4), Vec.vec3(1, 5, 6)))
		ok = ok and inst.blockLine(Vec.vec3(0, 1, 0), Vec.vec3(0, 1, 10)) == true
		ok = ok and inst.blockLine(Vec.vec3(0, 1, 0), Vec.vec3(10, 1, 0)) == false
		return ok and inst.coverage("cell1") > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
