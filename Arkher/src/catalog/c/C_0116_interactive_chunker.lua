-- ARKHER SYSTEM C.0116 :: Interactive Object Streaming
-- Category C - SCENE / WORLD
-- World capability: what exists, where it is, who owns it, and how it keeps living.
-- Kit: chunker (chunked residency driven by viewer distance)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "C.0116"
	S.key = "arkher.world.interactive.streaming"
	S.name = "Interactive Object Streaming"
	S.category = "C"
	S.family = "SCENE / WORLD"
	S.area = "Interactive Object"
	S.aspect = "Streaming"
	S.kit = "chunker"
	S.version = "1.0.0"
	S.deps = { "arkher.world.interactive.spatial_index" }
	S.tags = { "c", "interactive", "chunker", "world" }
	S.description = "Interactive Object Streaming: chunked residency driven by viewer distance for the Interactive Object subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 560,
		baseWeight = 0.8,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 394,
		detailWeight = 0.3,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.15,
		regressionSlope = 0.1,
		saturation = 0.75,
		scale = 2.0
	}
	S.features = { "keyOf", "coordOf", "center", "bounds", "neighbors", "state", "setState", "update", "pump", "lodOf", "loadedKeys", "stats", "focus", "streamStep", "coverage", "lodProfile", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("chunker", { id = "arkher.world.interactive.streaming", size = 128, radius = 512, maxPerTick = 6 })
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
				engine.bus:subscribe("arkher.world.interactive.*", function(payload) inst.lastSignal = payload end)
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
