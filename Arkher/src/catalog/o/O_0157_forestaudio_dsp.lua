-- ARKHER SYSTEM O.0157 :: Forest Audio DSP Chain
-- Category O - AUDIO
-- ARKHER Audio Framework capability: buses, DSP, spatialization and music that reacts to the world.
-- Kit: dsp (biquad filtering, delay, envelope and soft clipping)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "O.0157"
	S.key = "arkher.audio.forestaudio.dsp_chain"
	S.name = "Forest Audio DSP Chain"
	S.category = "O"
	S.family = "AUDIO"
	S.area = "Forest Audio"
	S.aspect = "DSP Chain"
	S.kit = "dsp"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "o", "forestaudio", "dsp", "audio" }
	S.description = "Forest Audio DSP Chain: biquad filtering, delay, envelope and soft clipping for the Forest Audio subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 560,
		baseWeight = 0.96,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 506,
		detailWeight = 0.66,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.18,
		regressionSlope = 0.08,
		saturation = 0.91,
		scale = 2.6
	}
	S.features = { "setFilter", "setDelay", "setGain", "processSample", "process", "rms", "peak", "tone", "reset", "stats", "configure", "renderTone", "loudness", "headroom", "bandRatio", "echo", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("dsp", { id = "arkher.audio.forestaudio.dsp_chain", sampleRate = 22050, filter = "bandpass", cutoff = 2100, q = 0.760 })
		inst.system = S
		inst.ctx = ctx

		function inst.configure(kind, cutoff)
			inst.setFilter(kind or inst.filterType, cutoff or inst.cutoff, inst.q)
			return inst.filterType
		end
		function inst.renderTone(frequency, samples)
			return inst.tone(frequency or 220, samples or 64, 0.8)
		end
		function inst.loudness(frequency, samples)
			inst.reset()
			return inst.rms(inst.process(inst.renderTone(frequency, samples)))
		end
		function inst.headroom(buffer)
			return 1 - inst.peak(buffer)
		end
		function inst.bandRatio(lowHz, highHz, samples)
			local low = inst.loudness(lowHz or 120, samples or 64)
			local high = inst.loudness(highHz or 4000, samples or 64)
			if high <= 1e-9 then return math.huge end
			return low / high
		end
		function inst.echo(seconds, feedback)
			return inst.setDelay(seconds or 0.02, feedback or 0.35, 0.4)
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
				engine.bus:subscribe("arkher.audio.forestaudio.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.configure(inst.filterType, inst.cutoff)
		local buffer = inst.renderTone(300, 48)
		local out = inst.process(buffer)
		local ok = #out == #buffer and inst.rms(out) >= 0
		ok = ok and inst.headroom(out) <= 1.0 and inst.peak(out) <= 1.01
		ok = ok and inst.bandRatio(120, 4000, 48) >= 0
		ok = ok and inst.echo(0.01, 0.3) > 0
		inst.reset()
		return ok and inst.stats().processed > 0 and inst.stats().sampleRate > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
