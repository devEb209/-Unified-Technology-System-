-- ARKHER SYSTEM O.0052 :: Explosion Sound Music Sequencer
-- Category O - AUDIO
-- ARKHER Audio Framework capability: buses, DSP, spatialization and music that reacts to the world.
-- Kit: sequencer (musical time, sections, stems, cues and quantized transitions)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "O.0052"
	S.key = "arkher.audio.explosionsound.music_sequencer"
	S.name = "Explosion Sound Music Sequencer"
	S.category = "O"
	S.family = "AUDIO"
	S.area = "Explosion Sound"
	S.aspect = "Music Sequencer"
	S.kit = "sequencer"
	S.version = "1.0.0"
	S.deps = { "arkher.audio.explosionsound.spatialization" }
	S.tags = { "o", "explosionsound", "sequencer", "audio" }
	S.description = "Explosion Sound Music Sequencer: musical time, sections, stems, cues and quantized transitions for the Explosion Sound subsystem."
	S.params = {
		backlogLimit = 29,
		baseRadius = 520,
		baseWeight = 0.51,
		bias = 0.21,
		biasWeight = 0.06,
		ceiling = 245,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.61,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.71,
		scale = 3.1
	}
	S.features = { "setTempo", "beatDuration", "addSection", "addCue", "addLayer", "setIntensity", "play", "stop", "bar", "beatInBar", "quantize", "transitionTo", "advance", "layerGain", "activeLayers", "reset", "stats", "installScore", "runBeats", "intensityTo", "stemMix", "switchTo", "position", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("sequencer", { id = "arkher.audio.explosionsound.music_sequencer", bpm = 140, beatsPerBar = 4, intensity = 0.51 })
		inst.system = S
		inst.ctx = ctx

		function inst.installScore()
			if #inst.sectionOrder > 0 then return #inst.sectionOrder end
			inst.addSection("calm", 4)
			inst.addSection("tense", 4)
			inst.addLayer("pad", { threshold = 0, fade = 0.25 })
			inst.addLayer("drums", { threshold = 0.55, fade = 0.25 })
			inst.addCue("downbeat", 1)
			inst.addCue("swell", 3)
			return #inst.sectionOrder
		end
		function inst.runBeats(beats)
			inst.installScore()
			inst.play()
			local fired = inst.advance(inst.beatDuration() * (beats or 4))
			return #fired
		end
		function inst.intensityTo(value)
			inst.installScore()
			inst.setIntensity(value or 0.8)
			return inst.intensity
		end
		function inst.stemMix()
			inst.installScore()
			local out = {}
			for _, name in ipairs(inst.layerOrder) do out[name] = inst.layerGain(name) end
			return out
		end
		function inst.switchTo(section, grid)
			inst.installScore()
			return inst.transitionTo(section or "tense", grid or 4)
		end
		function inst.position()
			return inst.bar(), inst.beatInBar()
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
				engine.bus:subscribe("arkher.audio.explosionsound.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installScore() == 2
		local fired = inst.runBeats(4)
		ok = ok and fired >= 1 and inst.stats().current ~= nil
		ok = ok and inst.intensityTo(0.9) == 0.9
		local mix = inst.stemMix()
		ok = ok and mix.pad ~= nil and mix.drums ~= nil
		ok = ok and inst.switchTo("tense", 4) >= 0
		inst.advance(inst.beatDuration() * 8)
		local bar, beat = inst.position()
		ok = ok and bar >= 1 and beat >= 0
		ok = ok and inst.quantize(1.3, 1) >= 1
		inst.stop()
		return ok and inst.stats().fired >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
