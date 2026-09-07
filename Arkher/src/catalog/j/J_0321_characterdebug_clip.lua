-- ARKHER SYSTEM J.0321 :: Character Debug Motion Set
-- Category J - CHARACTERS / DIGITAL HUMANS
-- ARKHER Digital Human capability: a body that moves, reacts, dresses, ages and scales to a crowd.
-- Kit: clip (the clips a character owns and how they sample)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "J.0321"
	S.key = "arkher.character.characterdebug.motion_set"
	S.name = "Character Debug Motion Set"
	S.category = "J"
	S.family = "CHARACTERS / DIGITAL HUMANS"
	S.area = "Character Debug"
	S.aspect = "Motion Set"
	S.kit = "clip"
	S.version = "1.0.0"
	S.deps = { "arkher.character.characterdebug.rig_definition" }
	S.tags = { "j", "characterdebug", "clip", "character" }
	S.description = "Character Debug Motion Set: the clips a character owns and how they sample for the Character Debug subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 560,
		baseWeight = 0.9,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 362,
		detailWeight = 0.3,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.15,
		regressionSlope = 0.1,
		saturation = 0.85,
		scale = 2.0
	}
	S.features = { "addTrack", "addKey", "addEvent", "normalizeTime", "sampleTrack", "sample", "eventsBetween", "retime", "compress", "keyCount", "stats", "authorWave", "poseAt", "valueAt", "eventCount", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("clip", { id = "arkher.character.characterdebug.motion_set", duration = 1.00, loop = true })
		inst.system = S
		inst.ctx = ctx

		function inst.authorWave(bone, amplitude, keys)
			if inst.keyCount() > 0 then return inst.keyCount() end
			local n = keys or 4
			for i = 0, n do
				local t = (i / n) * inst.duration
				local wave = math.sin((i / n) * math.pi * 2) * (amplitude or 0.5)
				inst.addKey(bone or "root", "position", t, Vec.vec3(0, wave, 0))
			end
			inst.addEvent(inst.duration * 0.5, "midpoint", { clip = S.key })
			return inst.keyCount()
		end
		function inst.poseAt(time)
			inst.authorWave("root", 0.5, 4)
			return inst.sample(time or 0)
		end
		function inst.valueAt(time)
			local pose = inst.poseAt(time)
			if not pose.root then return 0 end
			return pose.root.position.y
		end
		function inst.eventCount(from, to)
			inst.authorWave("root", 0.5, 4)
			return #inst.eventsBetween(from or (inst.duration * 0.25), to or (inst.duration * 0.75))
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
				engine.bus:subscribe("arkher.character.characterdebug.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.authorWave("root", 0.5, 4) == 5
		local mid = inst.valueAt(inst.duration * 0.25)
		ok = ok and mid > 0.4
		ok = ok and math.abs(inst.valueAt(0)) < 0.001
		ok = ok and inst.eventCount(inst.duration * 0.25, inst.duration * 0.75) == 1
		local before = inst.duration
		inst.retime(0.5)
		ok = ok and math.abs(inst.duration - before * 0.5) < 0.001
		inst.retime(2.0)
		return ok and inst.stats().keys == 5
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
