-- ARKHER SYSTEM S.0469 :: Occlusion Streaming Governor
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: streamer (distance-driven load/unload of work)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0469"
	S.key = "arkher.do15.occlusion.streaming_governor"
	S.name = "Occlusion Streaming Governor"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Occlusion"
	S.aspect = "Streaming Governor"
	S.kit = "streamer"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.occlusion.result_cache" }
	S.tags = { "s", "occlusion", "streamer", "do15" }
	S.description = "Occlusion Streaming Governor: distance-driven load/unload of work for the Occlusion subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 600,
		baseWeight = 0.67,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 295,
		detailWeight = 0.67,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.185,
		regressionSlope = 0.085,
		saturation = 0.87,
		scale = 2.7
	}
	S.features = { "chunkOf", "update", "pump", "isLoaded", "loadedCount", "setRadius", "stats", "focus", "adaptRadius", "loadedKeys", "churn", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("streamer", { id = "arkher.do15.occlusion.streaming_governor", radius = 600, chunkSize = 128, maxPerFrame = 4 })
		inst.system = S
		inst.ctx = ctx

	function inst.focus(x, z)
		local needed = inst.update(x, z)
		inst.pump()
		return needed
	end
	function inst.adaptRadius(qualityLevel)
		inst.setRadius(math.max(64, S.params.baseRadius * math.max(0.25, qualityLevel)))
		return inst.radius
	end
	function inst.loadedKeys()
		local out = {}
		for k in pairs(inst.loaded) do out[#out + 1] = k end
		table.sort(out)
		return out
	end
	function inst.churn() return inst.stats().unloads / math.max(1, inst.stats().loads) end

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
				engine.bus:subscribe("arkher.do15.occlusion.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.focus(0, 0)
		local loadedNear = inst.loadedCount()
		inst.focus(100000, 100000)
		local ok = loadedNear > 0 and inst.stats().unloads > 0
		inst.adaptRadius(0.5)
		return ok and inst.radius >= 64
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
