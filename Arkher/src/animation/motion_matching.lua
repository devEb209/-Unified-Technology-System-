-- ARKHER ANIMATION :: Motion Matching
-- Instead of a hand-built state machine, ARKHER searches a database of real motion frames
-- for the pose whose future trajectory best matches where the character is actually going.
-- Feature vectors, weighted cost, k-best search, blend-in and a search budget.
--@arkher-module
return function(A)
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Kits = A:import("arkher/runtime/kits")
	local v3 = Vec.vec3

	local MotionMatching = {}
	MotionMatching.__index = MotionMatching

	-- A feature vector is: future trajectory (3 points), current velocity, foot positions.
	-- Weights decide what "similar" means; trajectory dominates, feet keep contacts clean.
	MotionMatching.DEFAULT_WEIGHTS = {
		trajectory = 1.0, facing = 0.35, velocity = 0.75, feet = 0.5, pose = 0.25,
	}

	function MotionMatching.new(opts)
		opts = opts or {}
		local self = setmetatable({}, MotionMatching)
		self.frames = {}
		self.weights = {}
		for k, v in pairs(MotionMatching.DEFAULT_WEIGHTS) do self.weights[k] = v end
		for k, v in pairs(opts.weights or {}) do self.weights[k] = v end
		self.searchBudget = opts.searchBudget or 512
		self.blendTime = opts.blendTime or 0.22
		self.minInterval = opts.minInterval or 0.1
		self.cache = Kits.create("cache", { id = "motion.search", policy = "lru", capacity = 128 })
		self.searches = 0
		self.comparisons = 0
		self.switches = 0
		self.sinceSearch = 0
		self.current = nil
		self.blend = 1
		return self
	end

	-- ------------------------------------------------------------------ database
	function MotionMatching:addFrame(frame)
		local entry = {
			index = #self.frames + 1,
			clip = frame.clip, time = frame.time or 0,
			trajectory = frame.trajectory or { v3(), v3(), v3() },
			facing = frame.facing or v3(0, 0, 1),
			velocity = frame.velocity or v3(),
			feet = frame.feet or { v3(), v3() },
			pose = frame.pose,
			tags = frame.tags or {},
		}
		self.frames[#self.frames + 1] = entry
		return entry
	end

	-- Build a searchable database by sampling clips at a fixed rate and deriving the
	-- future trajectory from the samples that follow each frame.
	function MotionMatching:buildFromClip(clipId, clip, opts)
		opts = opts or {}
		local rate = opts.rate or 10
		local horizon = opts.horizon or 0.9
		local rootBone = opts.rootBone or "hips"
		local speed = opts.speed or 0
		local heading = opts.heading or v3(0, 0, 1)
		local count = math.max(2, math.floor(clip.duration * rate))
		local added = 0
		for i = 0, count - 1 do
			local t = (i / count) * clip.duration
			local pose = clip.sample(t)
			local root = pose[rootBone] and pose[rootBone].position or v3()
			local trajectory = {}
			for k = 1, 3 do
				local ahead = t + horizon * (k / 3)
				local aheadPose = clip.sample(ahead)
				local aheadRoot = aheadPose[rootBone] and aheadPose[rootBone].position or v3()
				trajectory[k] = (aheadRoot - root) + heading * (speed * horizon * (k / 3))
			end
			local feet = {}
			for fi, bone in ipairs({ "LFoot", "RFoot" }) do
				feet[fi] = pose[bone] and pose[bone].position or v3()
			end
			self:addFrame({ clip = clipId, time = t, trajectory = trajectory, facing = heading,
				velocity = heading * speed, feet = feet, pose = pose, tags = opts.tags })
			added = added + 1
		end
		return added
	end

	-- ------------------------------------------------------------------ cost
	function MotionMatching:cost(frame, query)
		self.comparisons = self.comparisons + 1
		local total = 0
		local w = self.weights
		for k = 1, math.min(#frame.trajectory, #(query.trajectory or {})) do
			total = total + (frame.trajectory[k] - query.trajectory[k]):length() * w.trajectory
		end
		if query.facing then
			total = total + frame.facing:angleTo(query.facing) * w.facing
		end
		if query.velocity then
			total = total + (frame.velocity - query.velocity):length() * w.velocity
		end
		if query.feet then
			for k = 1, math.min(#frame.feet, #query.feet) do
				total = total + (frame.feet[k] - query.feet[k]):length() * w.feet
			end
		end
		-- continuity bonus: staying in the current clip is cheaper than a jump
		if self.current and frame.clip == self.current.clip then
			local delta = math.abs(frame.time - self.current.time)
			total = total + math.min(delta, 1.0) * w.pose - 0.05
		end
		if query.tag and frame.tags and not frame.tags[query.tag] then
			total = total + 5
		end
		return total
	end

	-- Search the k best candidates within the budget. Stride sampling keeps the cost bounded
	-- on huge databases while still visiting the whole space over successive frames.
	function MotionMatching:search(query, k)
		self.searches = self.searches + 1
		k = k or 1
		local n = #self.frames
		if n == 0 then return {} end
		local stride = math.max(1, math.ceil(n / self.searchBudget))
		local offset = (self.searches % stride)
		local best = {}
		local i = 1 + offset
		while i <= n do
			local frame = self.frames[i]
			local c = self:cost(frame, query)
			if #best < k then
				best[#best + 1] = { frame = frame, cost = c }
				table.sort(best, function(a, b) return a.cost < b.cost end)
			elseif c < best[#best].cost then
				best[#best] = { frame = frame, cost = c }
				table.sort(best, function(a, b) return a.cost < b.cost end)
			end
			i = i + stride
		end
		return best
	end

	-- One update: search at most every `minInterval`, switch only when it is worth it.
	function MotionMatching:update(dt, query)
		self.sinceSearch = self.sinceSearch + dt
		if self.current then
			self.current = { clip = self.current.clip, time = self.current.time + dt,
				index = self.current.index }
			self.blend = math.min(1, self.blend + dt / math.max(1e-6, self.blendTime))
		end
		if self.sinceSearch < self.minInterval and self.current then
			return { searched = false, clip = self.current.clip, time = self.current.time,
				blend = self.blend }
		end
		self.sinceSearch = 0
		local best = self:search(query, 3)
		if #best == 0 then return { searched = true, clip = nil } end
		local winner = best[1]
		local switched = false
		if not self.current or winner.frame.clip ~= self.current.clip
			or math.abs(winner.frame.time - self.current.time) > 0.25 then
			-- only switch if the winner is meaningfully better than staying put
			local staying = self.current and self.frames[self.current.index] or nil
			local stayCost = staying and self:cost(staying, query) or math.huge
			if winner.cost < stayCost * 0.92 then
				self.previous = self.current
				self.current = { clip = winner.frame.clip, time = winner.frame.time,
					index = winner.frame.index }
				self.blend = 0
				self.switches = self.switches + 1
				switched = true
			end
		end
		return { searched = true, switched = switched, clip = self.current and self.current.clip,
			time = self.current and self.current.time, cost = winner.cost, blend = self.blend,
			candidates = #best }
	end

	-- Build a query from what the character controller actually knows.
	function MotionMatching:queryFromMotion(velocity, desiredDirection, horizon)
		horizon = horizon or 0.9
		local trajectory = {}
		for k = 1, 3 do
			local t = horizon * (k / 3)
			trajectory[k] = velocity * t + desiredDirection * (0.5 * t * t)
		end
		return { trajectory = trajectory, facing = desiredDirection:length() > 1e-6
			and desiredDirection:unit() or v3(0, 0, 1), velocity = velocity, feet = nil }
	end

	function MotionMatching:currentPose()
		if not self.current then return nil end
		local frame = self.frames[self.current.index]
		if not frame then return nil end
		if self.previous and self.blend < 1 then
			local prev = self.frames[self.previous.index]
			if prev and prev.pose and frame.pose then
				local out = {}
				for bone, t in pairs(prev.pose) do
					local target = frame.pose[bone]
					if target then
						out[bone] = { position = t.position:lerp(target.position, self.blend),
							rotation = t.rotation:lerp(target.rotation, self.blend),
							scale = t.scale }
					else
						out[bone] = t
					end
				end
				return out
			end
		end
		return frame.pose
	end

	function MotionMatching:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.searchBudget = math.max(48, math.floor(48 + quality * 960))
		self.minInterval = Mathx.lerp(0.24, 0.06, quality)
		return { searchBudget = self.searchBudget, minInterval = self.minInterval }
	end

	function MotionMatching:report()
		local clips = {}
		for _, frame in ipairs(self.frames) do clips[frame.clip] = (clips[frame.clip] or 0) + 1 end
		local clipCount = 0
		for _ in pairs(clips) do clipCount = clipCount + 1 end
		return { frames = #self.frames, clips = clipCount, searches = self.searches,
			comparisons = self.comparisons, switches = self.switches,
			searchBudget = self.searchBudget, current = self.current and self.current.clip,
			blend = self.blend,
			comparisonsPerSearch = self.searches > 0 and (self.comparisons / self.searches) or 0 }
	end

	return MotionMatching
end
