-- ARKHER SYSTEM W.0080 :: Dolly Cinematic Mix
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: mixer (bus routing and ducking for the cinematic soundtrack)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0080"
	S.key = "arkher.cine.dolly.cinematic_mix"
	S.name = "Dolly Cinematic Mix"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Dolly"
	S.aspect = "Cinematic Mix"
	S.kit = "mixer"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.dolly.motion_tween" }
	S.tags = { "w", "dolly", "mixer", "cine" }
	S.description = "Dolly Cinematic Mix: bus routing and ducking for the cinematic soundtrack for the Dolly subsystem."
	S.params = {
		backlogLimit = 36,
		baseRadius = 480,
		baseWeight = 0.98,
		bias = 0.28,
		biasWeight = 0.13,
		ceiling = 524,
		detailWeight = 0.28,
		failureTolerance = 3,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.68,
		minThrottle = 0.14,
		regressionSlope = 0.09,
		saturation = 0.93,
		scale = 1.8
	}
	S.features = { "addBus", "route", "setGain", "setMute", "setSolo", "effectiveGain", "duck", "tick", "play", "stop", "voiceGain", "snapshot", "restore", "applyQuality", "stats", "installTree", "gainOfBus", "duckFor", "playVoices", "silence", "unsilence", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("mixer", { id = "arkher.cine.dolly.cinematic_mix", maxVoices = 32 })
		inst.system = S
		inst.ctx = ctx

		function inst.installTree()
			if #inst.order > 0 then return #inst.order end
			inst.addBus("master", { gainDb = 0 })
			inst.addBus("sfx", { parent = "master", gainDb = -2 })
			inst.addBus("music", { parent = "master", gainDb = -6 })
			inst.addBus("ui", { parent = "master", gainDb = -4 })
			return #inst.order
		end
		function inst.gainOfBus(id)
			inst.installTree()
			return inst.effectiveGain(id or "sfx")
		end
		function inst.duckFor(busId, amount, seconds)
			inst.installTree()
			inst.duck(busId or "music", amount or 0.7)
			inst.tick(seconds or 0.2)
			return inst.effectiveGain(busId or "music")
		end
		function inst.playVoices(count, busId, priority)
			inst.installTree()
			local n = 0
			for i = 1, (count or 4) do
				if inst.play("voice" .. i, busId or "sfx", priority or 1) then n = n + 1 end
			end
			return n
		end
		function inst.silence()
			inst.installTree()
			for _, id in ipairs(inst.order) do inst.stop(id) end
			return inst.setMute("master", true)
		end
		function inst.unsilence()
			return inst.setMute("master", false)
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
				engine.bus:subscribe("arkher.cine.dolly.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installTree() == 4
		ok = ok and inst.gainOfBus("sfx") > 0 and inst.gainOfBus("music") > 0
		local ducked = inst.duckFor("music", 0.8, 0.3)
		ok = ok and ducked < inst.gainOfBus("sfx")
		inst.duck("music", 0)
		inst.tick(1.0)
		ok = ok and inst.playVoices(2, "sfx", 1) >= 1
		local snap = inst.snapshot()
		inst.setGain("master", -12)
		inst.restore(snap)
		ok = ok and inst.buses.master.gainDb == 0
		inst.silence()
		ok = ok and inst.effectiveGain("sfx") == 0
		inst.unsilence()
		return ok and inst.stats().buses == 4
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
