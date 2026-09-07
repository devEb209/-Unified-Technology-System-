-- ARKHER AUDIO :: Audio Engine
-- The ARKHER Audio Framework: a bus tree with DSP inserts, 3D voices with attenuation,
-- panning, Doppler and occlusion, an adaptive music system with stems, and a voice
-- budget that a phone can actually pay.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local Audio = {}
	Audio.__index = Audio

	function Audio.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Audio)
		self.mixer = Kits.create("mixer", { id = "audio.mixer",
			maxVoices = opts.maxVoices or 24 })
		self.space = Kits.create("spatialaudio", { id = "audio.space",
			maxVoices = opts.maxVoices or 24, maxDistance = opts.maxDistance or 140 })
		self.music = Kits.create("sequencer", { id = "audio.music", bpm = opts.bpm or 110 })
		self.inserts = {}
		self.sounds = {}
		self.playing = {}
		self.playOrder = {}
		self.nextVoice = 1
		self.time = 0
		self.played = 0
		self.rejected = 0
		self.stopped = 0
		self.onCue = Signal.new()
		self:buildBuses()
		return self
	end

	function Audio:buildBuses()
		self.mixer.addBus("master", { gainDb = 0 })
		self.mixer.addBus("sfx", { parent = "master", gainDb = -2 })
		self.mixer.addBus("music", { parent = "master", gainDb = -6 })
		self.mixer.addBus("voice", { parent = "master", gainDb = 0 })
		self.mixer.addBus("ambience", { parent = "master", gainDb = -9 })
		self.mixer.addBus("ui", { parent = "master", gainDb = -4 })
		return 6
	end

	-- ------------------------------------------------------------------ assets
	function Audio:define(name, opts)
		opts = opts or {}
		if self.sounds[name] then return nil, "duplicate sound" end
		self.sounds[name] = { name = name, bus = opts.bus or "sfx",
			volume = opts.volume or 1, priority = opts.priority or 1,
			length = opts.length or 1, loop = opts.loop or false,
			pitchVariance = opts.pitchVariance or 0, spatial = opts.spatial ~= false }
		return self.sounds[name]
	end

	function Audio:addInsert(busId, cfg)
		cfg = cfg or {}
		cfg.id = "audio.insert." .. busId
		local dsp = Kits.create("dsp", cfg)
		self.inserts[busId] = dsp
		return dsp
	end

	function Audio:insertFor(busId) return self.inserts[busId] end

	-- ------------------------------------------------------------------ playback
	function Audio:play(name, position, opts)
		local sound = self.sounds[name]
		if not sound then return nil, "unknown sound" end
		opts = opts or {}
		local voiceId = opts.id or (name .. "#" .. self.nextVoice)
		self.nextVoice = self.nextVoice + 1
		local priority = opts.priority or sound.priority
		if not self.mixer.play(voiceId, sound.bus, priority) then
			self.rejected = self.rejected + 1
			return nil, "no voice"
		end
		if sound.spatial then
			self.space.addSource(voiceId, position or v3(),
				{ volume = opts.volume or sound.volume, priority = priority,
				  occlusion = opts.occlusion or 0, loop = sound.loop })
		end
		self.playing[voiceId] = { id = voiceId, sound = name, age = 0,
			length = opts.length or sound.length, loop = sound.loop,
			bus = sound.bus, spatial = sound.spatial }
		self.playOrder[#self.playOrder + 1] = voiceId
		self.played = self.played + 1
		return voiceId
	end

	function Audio:stop(voiceId)
		local voice = self.playing[voiceId]
		if not voice then return false end
		self.mixer.stop(voiceId)
		if voice.spatial then self.space.removeSource(voiceId) end
		self.playing[voiceId] = nil
		for i, id in ipairs(self.playOrder) do
			if id == voiceId then table.remove(self.playOrder, i) break end
		end
		self.stopped = self.stopped + 1
		return true
	end

	function Audio:isPlaying(voiceId) return self.playing[voiceId] ~= nil end

	function Audio:moveVoice(voiceId, position, velocity)
		local voice = self.playing[voiceId]
		if not voice or not voice.spatial then return false end
		return self.space.moveSource(voiceId, position, velocity)
	end

	function Audio:setListener(position, forward, up, velocity)
		return self.space.setListener(position, forward, up, velocity)
	end

	-- Final gain of a voice = mixer chain x distance attenuation x occlusion.
	function Audio:gainOf(voiceId)
		local voice = self.playing[voiceId]
		if not voice then return 0 end
		local busGain = self.mixer.voiceGain(voiceId)
		if not voice.spatial then return busGain end
		return busGain * self.space.gainOf(voiceId)
	end

	function Audio:panOf(voiceId)
		local voice = self.playing[voiceId]
		if not voice or not voice.spatial then return 0 end
		local src = self.space.sources[voiceId]
		if not src then return 0 end
		return self.space.pan(src.position)
	end

	-- ------------------------------------------------------------------ music
	function Audio:setupMusic(sections, layers)
		for _, s in ipairs(sections or { { name = "explore", bars = 8 },
			{ name = "combat", bars = 8 } }) do
			self.music.addSection(s.name, s.bars)
		end
		for _, l in ipairs(layers or { { name = "pad", threshold = 0 },
			{ name = "percussion", threshold = 0.35 }, { name = "brass", threshold = 0.7 } }) do
			self.music.addLayer(l.name, { threshold = l.threshold, fade = l.fade or 1.5 })
		end
		self.music.setIntensity(0.2)
		self.music.play()
		return true
	end

	function Audio:setIntensity(value) return self.music.setIntensity(value) end

	function Audio:transition(section, grid) return self.music.transitionTo(section, grid) end

	function Audio:scheduleCue(name, beat, payload) return self.music.addCue(name, beat, payload) end

	-- Ducking: when dialogue plays, everything else steps back automatically.
	function Audio:duckFor(busId, amount, seconds)
		self.mixer.duck(busId, amount)
		self.duckRelease = { bus = busId, at = self.time + (seconds or 1) }
		return true
	end

	-- ------------------------------------------------------------------ frame
	function Audio:update(dt)
		self.time = self.time + dt
		self.mixer.tick(dt)
		if self.duckRelease and self.time >= self.duckRelease.at then
			self.mixer.duck(self.duckRelease.bus, 0)
			self.duckRelease = nil
		end
		local finished = {}
		for _, id in ipairs(self.playOrder) do
			local voice = self.playing[id]
			voice.age = voice.age + dt
			if not voice.loop and voice.age >= voice.length then finished[#finished + 1] = id end
		end
		for _, id in ipairs(finished) do self:stop(id) end
		local cues = self.music.advance(dt)
		for _, cue in ipairs(cues) do self.onCue:fire(cue) end
		local audible = self.space.cullVoices()
		return { voices = #self.playOrder, audible = #audible, cues = #cues,
			finished = #finished }
	end

	function Audio:run(seconds, dt)
		local step = dt or 1 / 30
		local n = math.max(1, math.floor(seconds / step))
		local last
		for _ = 1, n do last = self:update(step) end
		return last
	end

	function Audio:audibleVoices() return self.space.cullVoices() end

	function Audio:loudest()
		local best, bestGain = nil, -1
		for _, id in ipairs(self.playOrder) do
			local g = self:gainOf(id)
			if g > bestGain then bestGain = g best = id end
		end
		return best, bestGain
	end

	function Audio:applyQuality(q)
		q = Mathx.clamp(q, 0, 1)
		local mixer = self.mixer.applyQuality(q)
		local space = self.space.applyQuality(q)
		while #self.playOrder > mixer.maxVoices do
			self:stop(self.playOrder[#self.playOrder])
		end
		return { maxVoices = mixer.maxVoices, maxDistance = space.maxDistance }
	end

	function Audio:report()
		return { voices = #self.playOrder, played = self.played, stopped = self.stopped,
			rejected = self.rejected, buses = self.mixer.stats().buses,
			maxVoices = self.mixer.stats().maxVoices, music = self.music.stats(),
			sources = self.space.stats().sources, time = self.time }
	end

	return Audio
end
