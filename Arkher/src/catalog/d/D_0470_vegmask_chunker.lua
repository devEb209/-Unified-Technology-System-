-- ARKHER SYSTEM D.0470 :: Vegetation Mask Tile Streaming
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: chunker (tile residency driven by viewer distance)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0470"
	S.key = "arkher.terrain.vegmask.tile_streaming"
	S.name = "Vegetation Mask Tile Streaming"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Vegetation Mask"
	S.aspect = "Tile Streaming"
	S.kit = "chunker"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.vegmask.mesh_builder" }
	S.tags = { "d", "vegmask", "chunker", "terrain" }
	S.description = "Vegetation Mask Tile Streaming: tile residency driven by viewer distance for the Vegetation Mask subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 560,
		baseWeight = 0.62,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 546,
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
	S.features = { "keyOf", "coordOf", "center", "bounds", "neighbors", "state", "setState", "update", "pump", "lodOf", "loadedKeys", "stats", "focus", "streamStep", "coverage", "lodProfile", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("chunker", { id = "arkher.terrain.vegmask.tile_streaming", size = 128, radius = 512, maxPerTick = 6 })
		inst.system = S
		inst.ctx = ctx

		function inst.focus(position)
			inst.lastFocus = position
			return inst.update(position)
		end
		function inst.streamStep(position)
			inst.focus(position or inst.lastFocus or Vec.vec3(0, 0, 0))
			return inst.pump()
		end
		function inst.coverage()
			local tracked = inst.stats().tracked
			if tracked == 0 then return 0 end
			return inst.loaded / tracked
		end
		function inst.lodProfile(position)
			local out = {}
			for _, key in ipairs(inst.loadedKeys()) do
				local lod = inst.lodOf(key, position)
				out[lod] = (out[lod] or 0) + 1
			end
			return out
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
				engine.bus:subscribe("arkher.terrain.vegmask.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local toLoad = inst.focus(Vec.vec3(0, 0, 0))
		local ok = #toLoad > 0
		local moved = inst.streamStep(Vec.vec3(0, 0, 0))
		ok = ok and moved > 0 and moved <= inst.maxPerTick
		ok = ok and inst.loaded == moved
		ok = ok and inst.coverage() > 0
		local profile = inst.lodProfile(Vec.vec3(0, 0, 0))
		ok = ok and profile[0] ~= nil
		local _, toUnload = inst.update(Vec.vec3(1e6, 0, 1e6))
		return ok and #toUnload == moved
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
