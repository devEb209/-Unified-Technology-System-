-- ARKHER SYSTEM O.0123 :: Wind Audio Spatialization
-- Category O - AUDIO
-- ARKHER Audio Framework capability: buses, DSP, spatialization and music that reacts to the world.
-- Kit: spatialaudio (distance attenuation, panning, occlusion and doppler)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "O.0123"
	S.key = "arkher.audio.windaudio.spatialization"
	S.name = "Wind Audio Spatialization"
	S.category = "O"
	S.family = "AUDIO"
	S.area = "Wind Audio"
	S.aspect = "Spatialization"
	S.kit = "spatialaudio"
	S.version = "1.0.0"
	S.deps = { "arkher.audio.windaudio.mixer_bus" }
	S.tags = { "o", "windaudio", "spatialaudio", "audio" }
	S.description = "Wind Audio Spatialization: distance attenuation, panning, occlusion and doppler for the Wind Audio subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.53,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 253,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.73,
		scale = 2.3
	}
	S.features = { "setListener", "addSource", "removeSource", "moveSource", "attenuation", "pan", "doppler", "setOcclusion", "gainOf", "audible", "cullVoices", "mixSnapshot", "applyQuality", "stats", "installField", "moveListener", "loudestSource", "audibleCount", "occludeAll", "panField", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("spatialaudio", { id = "arkher.audio.windaudio.spatialization", model = "linear", refDistance = 4, maxDistance = 140, rolloff = 0.93, maxVoices = 16 })
		inst.system = S
		inst.ctx = ctx

		function inst.installField(count)
			if #inst.order > 0 then return #inst.order end
			local n = count or 4
			for i = 1, n do
				inst.addSource("src" .. i,
					Vec.vec3(math.cos(i) * 8 * i, 0, math.sin(i) * 8 * i),
					{ volume = 1, priority = i })
			end
			return #inst.order
		end
		function inst.moveListener(position, forward)
			return inst.setListener(position or Vec.vec3(),
				forward or Vec.vec3(0, 0, -1), Vec.vec3(0, 1, 0))
		end
		function inst.loudestSource()
			local best, bestGain = nil, -1
			for _, id in ipairs(inst.order) do
				local g = inst.gainOf(id)
				if g > bestGain then bestGain = g best = id end
			end
			return best, bestGain
		end
		function inst.audibleCount(threshold)
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.audible(id, threshold or 0.01) then n = n + 1 end
			end
			return n
		end
		function inst.occludeAll(amount)
			for _, id in ipairs(inst.order) do inst.setOcclusion(id, amount or 1) end
			return #inst.order
		end
		function inst.panField()
			local out = {}
			for _, id in ipairs(inst.order) do
				out[id] = inst.pan(inst.sources[id].position)
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
				engine.bus:subscribe("arkher.audio.windaudio.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installField(4) == 4
		inst.moveListener(Vec.vec3(), Vec.vec3(0, 0, -1))
		local loudest, gain = inst.loudestSource()
		ok = ok and loudest ~= nil and gain > 0
		ok = ok and inst.audibleCount(0.001) >= 1
		local pans = inst.panField()
		ok = ok and pans[loudest] ~= nil and math.abs(pans[loudest]) <= 1.0001
		ok = ok and inst.attenuation(inst.maxDistance * 2) == 0
		inst.occludeAll(1)
		ok = ok and inst.gainOf(loudest) < gain
		inst.occludeAll(0)
		ok = ok and #inst.cullVoices() <= inst.maxVoices
		return ok and #inst.mixSnapshot() >= 1 and inst.stats().sources == 4
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
