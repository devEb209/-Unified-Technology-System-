-- ARKHER SYSTEM W.0109 :: Orbit Sequence Timeline
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: timeline (keyframed tracks, clips and events on a scrubable playhead)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0109"
	S.key = "arkher.cine.orbit.sequence_timeline"
	S.name = "Orbit Sequence Timeline"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Orbit"
	S.aspect = "Sequence Timeline"
	S.kit = "timeline"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "w", "orbit", "timeline", "cine" }
	S.description = "Orbit Sequence Timeline: keyframed tracks, clips and events on a scrubable playhead for the Orbit subsystem."
	S.params = {
		backlogLimit = 44,
		baseRadius = 320,
		baseWeight = 0.56,
		bias = 0.36,
		biasWeight = 0.21,
		ceiling = 268,
		detailWeight = 0.36,
		failureTolerance = 1,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.76,
		minThrottle = 0.18,
		regressionSlope = 0.13,
		saturation = 0.76,
		scale = 2.6
	}
	S.features = { "addTrack", "addKey", "valueAt", "addClip", "activeClips", "addEvent", "play", "pause", "seek", "advance", "sampleAll", "trim", "stats", "installShot", "scrub", "frameAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("timeline", { id = "arkher.cine.orbit.sequence_timeline", duration = 8.0, rate = 1.16 })
		inst.system = S
		inst.ctx = ctx

		function inst.installShot()
			inst.addTrack("fov", { default = 1 })
			inst.addKey("fov", 0, 1)
			inst.addKey("fov", 2, 1.6, "easeInOut")
			inst.addClip("main", 0, 2)
			inst.addEvent("beat", 1)
			return inst.duration
		end
		function inst.scrub(time) return inst.seek(time) end
		function inst.frameAt(time) return inst.sampleAll(time or inst.time) end

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
				engine.bus:subscribe("arkher.cine.orbit.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installShot() >= 2
		ok = ok and inst.valueAt("fov", 0) == 1
		local mid = inst.valueAt("fov", 1)
		ok = ok and mid > 1 and mid < 1.6
		ok = ok and #inst.activeClips(1) == 1
		inst.play()
		local fired = inst.advance(1.5)
		ok = ok and #fired == 1 and fired[1].name == "beat"
		ok = ok and #inst.advance(0.2) == 0
		ok = ok and inst.scrub(0.5) == 0.5
		return ok and inst.frameAt(0.5).fov ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
