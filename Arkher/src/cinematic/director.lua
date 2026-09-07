-- ARKHER CINEMATIC :: Director
-- Shots, sequences, cuts and coverage. A sequence owns a timeline; each shot owns a
-- camera rig, a grade and its own events. The director cuts between shots on real time
-- boundaries, blends grades across a transition, honours a letterbox and a play rate,
-- and can render a beat sheet a human can read before a single frame exists.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")

	local Director = {}
	Director.__index = Director
	local v3 = Vec.vec3

	function Director.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Director)
		self.timeline = Kits.create("timeline", { id = "cinematic.timeline",
			duration = opts.duration or 0, rate = opts.rate or 1, loop = opts.loop or false })
		self.grade = Kits.create("grade", { id = "cinematic.grade" })
		self.grade.installLooks()
		self.shots = {}
		self.order = {}
		self.current = nil
		self.time = 0
		self.playing = false
		self.letterbox = opts.letterbox or 2.39
		self.transitions = {}
		self.onCut = Signal.new()
		self.onEvent = Signal.new()
		self.cuts = 0
		self.frames = 0
		return self
	end

	-- ------------------------------------------------------------------ authoring
	function Director:addShot(id, opts)
		opts = opts or {}
		if self.shots[id] then return nil, "duplicate shot" end
		local start = opts.startTime
		if start == nil then
			start = 0
			for _, other in ipairs(self.order) do
				local shot = self.shots[other]
				start = math.max(start, shot.startTime + shot.length)
			end
		end
		local shot = { id = id, startTime = start, length = opts.length or 4,
			rig = Kits.create("camerarig", { id = "shot." .. id,
				mode = opts.mode or "free", fov = opts.fov or 1.2,
				position = opts.position or v3(0, 4, -8), distance = opts.distance or 10,
				height = opts.height or 3, smoothing = opts.smoothing or 8 }),
			look = opts.look or "neutral", subject = opts.subject,
			focusTarget = opts.focusTarget, notes = opts.notes or "",
			transition = opts.transition or "cut", transitionTime = opts.transitionTime or 0.5 }
		self.shots[id] = shot
		self.order[#self.order + 1] = id
		self.timeline.addClip(id, shot.startTime, shot.length, { shot = id })
		if shot.length + shot.startTime > self.timeline.duration then
			self.timeline.duration = shot.length + shot.startTime
		end
		return shot
	end

	function Director:shotAt(time)
		time = time or self.time
		for _, id in ipairs(self.order) do
			local shot = self.shots[id]
			if time >= shot.startTime and time < shot.startTime + shot.length then return id end
		end
		if #self.order > 0 then
			local last = self.shots[self.order[#self.order]]
			if time >= last.startTime then return last.id end
		end
		return nil
	end

	function Director:addPath(shotId, points)
		local shot = self.shots[shotId]
		if not shot then return 0 end
		for _, point in ipairs(points) do shot.rig.addPathPoint(point) end
		shot.rig.setMode("dolly")
		return #shot.rig.path
	end

	function Director:addTrack(name, opts)
		return self.timeline.addTrack(name, opts)
	end

	function Director:key(track, time, value, easing)
		return self.timeline.addKey(track, time, value, easing)
	end

	function Director:cue(name, time, payload)
		return self.timeline.addEvent(name, time, payload)
	end

	function Director:setLook(shotId, look, weight)
		local shot = self.shots[shotId]
		if not shot then return false end
		shot.look = look
		shot.lookWeight = weight == nil and 1 or weight
		return true
	end

	-- ------------------------------------------------------------------ playback
	function Director:play()
		self.playing = true
		self.timeline.play()
		self.current = self:shotAt(self.time)
		return self.current
	end

	function Director:pause()
		self.playing = false
		self.timeline.pause()
		return true
	end

	function Director:seek(time)
		self.time = self.timeline.seek(time)
		local shot = self:shotAt(self.time)
		if shot ~= self.current then
			self.current = shot
			self.cuts = self.cuts + 1
			self.onCut:fire({ shot = shot, time = self.time, scrub = true })
		end
		return self.time
	end

	-- Blend weight of the outgoing shot while a transition is still in progress.
	function Director:transitionWeight(time)
		local id = self:shotAt(time)
		if not id then return 0 end
		local shot = self.shots[id]
		if shot.transition == "cut" then return 0 end
		local elapsed = time - shot.startTime
		if elapsed >= shot.transitionTime then return 0 end
		return Mathx.clamp(1 - elapsed / math.max(1e-6, shot.transitionTime), 0, 1)
	end

	function Director:update(dt, subjects)
		if not self.playing then return self:frame() end
		self.frames = self.frames + 1
		local fired = self.timeline.advance(dt)
		for _, event in ipairs(fired) do self.onEvent:fire(event) end
		self.time = self.timeline.time
		local id = self:shotAt(self.time)
		if id ~= self.current then
			self.current = id
			self.cuts = self.cuts + 1
			self.onCut:fire({ shot = id, time = self.time, scrub = false })
		end
		if id then
			local shot = self.shots[id]
			local subject = subjects and shot.subject and subjects[shot.subject] or nil
			shot.rig.update(dt, subject)
			if shot.look then
				local weight = 1 - self:transitionWeight(self.time)
				self.grade.applyLook(shot.look, weight * (shot.lookWeight or 1) * math.min(1, dt * 6))
			end
		end
		if not self.timeline.playing then self.playing = false end
		return self:frame()
	end

	function Director:frame()
		local id = self.current or self:shotAt(self.time)
		local shot = id and self.shots[id]
		return { time = self.time, shot = id,
			camera = shot and shot.rig.state() or nil,
			blend = self:transitionWeight(self.time),
			letterbox = self.letterbox,
			grade = { exposure = self.grade.exposure, contrast = self.grade.contrast,
				saturation = self.grade.saturation, temperature = self.grade.temperature },
			tracks = self.timeline.sampleAll(self.time) }
	end

	function Director:render(colours)
		return self.grade.applyMany(colours or {})
	end

	-- ------------------------------------------------------------------ production
	function Director:duration()
		return self.timeline.trim()
	end

	function Director:beatSheet()
		local sheet = {}
		local ordered = {}
		for i, id in ipairs(self.order) do ordered[i] = id end
		table.sort(ordered, function(a, b)
			return self.shots[a].startTime < self.shots[b].startTime
		end)
		for _, id in ipairs(ordered) do
			local shot = self.shots[id]
			sheet[#sheet + 1] = string.format("%05.1fs  %-12s %-8s %-9s %s",
				shot.startTime, id, shot.rig.mode, shot.look, shot.notes)
		end
		return table.concat(sheet, "\n")
	end

	-- Coverage: which fraction of the sequence has a shot on it. Gaps are dead air.
	function Director:coverage()
		local duration = self:duration()
		if duration <= 0 then return 0, {} end
		local marks = {}
		for _, id in ipairs(self.order) do
			local shot = self.shots[id]
			marks[#marks + 1] = { from = shot.startTime, to = shot.startTime + shot.length }
		end
		table.sort(marks, function(a, b) return a.from < b.from end)
		local covered, cursor, gaps = 0, 0, {}
		for _, mark in ipairs(marks) do
			if mark.from > cursor then
				gaps[#gaps + 1] = { from = cursor, to = mark.from }
				cursor = mark.from
			end
			if mark.to > cursor then
				covered = covered + (mark.to - cursor)
				cursor = mark.to
			end
		end
		if cursor < duration then gaps[#gaps + 1] = { from = cursor, to = duration } end
		return covered / duration, gaps
	end

	function Director:report()
		local coverage, gaps = self:coverage()
		return { shots = #self.order, duration = self:duration(), cuts = self.cuts,
			frames = self.frames, coverage = coverage, gaps = #gaps,
			timeline = self.timeline.stats(), grade = self.grade.stats() }
	end

	return Director
end
