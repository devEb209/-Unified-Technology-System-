-- ARKHER SYSTEM J.0329 :: Character Debug Streaming
-- Category J - CHARACTERS / DIGITAL HUMANS
-- ARKHER Digital Human capability: a body that moves, reacts, dresses, ages and scales to a crowd.
-- Kit: streamer (distance-driven residency of character data)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "J.0329"
	S.key = "arkher.character.characterdebug.streaming"
	S.name = "Character Debug Streaming"
	S.category = "J"
	S.family = "CHARACTERS / DIGITAL HUMANS"
	S.area = "Character Debug"
	S.aspect = "Streaming"
	S.kit = "streamer"
	S.version = "1.0.0"
	S.deps = { "arkher.character.characterdebug.budget_governor" }
	S.tags = { "j", "characterdebug", "streamer", "character" }
	S.description = "Character Debug Streaming: distance-driven residency of character data for the Character Debug subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 200,
		baseWeight = 0.55,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 545,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.75,
		scale = 3.5
	}
	S.features = { "chunkOf", "update", "pump", "isLoaded", "loadedCount", "setRadius", "stats", "focus", "adaptRadius", "loadedKeys", "churn", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("streamer", { id = "arkher.character.characterdebug.streaming", radius = 200, chunkSize = 64, maxPerFrame = 2 })
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
				engine.bus:subscribe("arkher.character.characterdebug.*", function(payload) inst.lastSignal = payload end)
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
