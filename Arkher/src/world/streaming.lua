-- ARKHER WORLD STREAMING DIRECTOR
-- Decides what part of the world exists at any instant, under a hard D-O15 budget.
-- Chunked load/unload with velocity prefetch, priority queues, hysteresis (so chunks do
-- not thrash on a boundary), memory accounting and per-frame work limits.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local v3 = Vec.vec3

	local Streaming = {}
	Streaming.__index = Streaming

	function Streaming.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Streaming)
		self.chunker = Kits.chunker({ size = opts.chunkSize or 128, radius = opts.radius or 640,
			maxPerTick = opts.maxPerTick or 3 })
		self.hysteresis = opts.hysteresis or 1.25
		self.memoryBudgetMB = opts.memoryBudgetMB or 512
		self.costPerChunkMB = opts.costPerChunkMB or 1.5
		self.viewers = {}
		self.contents = {}
		self.pinned = {}
		self.stats = { loaded = 0, unloaded = 0, deferred = 0, evicted = 0, frames = 0, thrash = 0 }
		self.lastWanted = {}
		return self
	end

	function Streaming:addViewer(id, position, velocity)
		self.viewers[id] = { id = id, position = position or v3(), velocity = velocity or v3() }
		return self.viewers[id]
	end

	function Streaming:updateViewer(id, position, velocity)
		local viewer = self.viewers[id]
		if not viewer then return false end
		viewer.velocity = velocity or ((position - viewer.position) * 10)
		viewer.position = position
		return true
	end

	function Streaming:removeViewer(id)
		if not self.viewers[id] then return false end
		self.viewers[id] = nil
		return true
	end

	function Streaming:pin(key, pinned)
		self.pinned[key] = pinned and true or nil
		return true
	end

	function Streaming:memoryUsedMB()
		return self.chunker.loaded * self.costPerChunkMB
	end

	function Streaming:capacity()
		return math.floor(self.memoryBudgetMB / math.max(0.01, self.costPerChunkMB))
	end

	-- one streaming decision pass; returns what was loaded and unloaded this frame
	function Streaming:tick(quality)
		self.stats.frames = self.stats.frames + 1
		local q = Mathx.clamp(quality or 1, 0.25, 1)
		self.chunker.radius = (self.chunker.radius or 640)
		local wanted = {}
		local candidates = {}
		for _, viewer in pairs(self.viewers) do
			local toLoad = self.chunker.update(viewer.position, viewer.velocity)
			local reach = self.chunker.radius * q
			for _, item in ipairs(toLoad) do
				if item.distance <= reach then
					wanted[item.key] = math.min(wanted[item.key] or math.huge, item.distance)
				end
			end
			-- everything currently inside the retain radius stays wanted
			for _, key in ipairs(self.chunker.loadedKeys()) do
				local d = self.chunker.center(key):distance(viewer.position)
				if d <= reach * self.hysteresis then
					wanted[key] = math.min(wanted[key] or math.huge, d)
				end
			end
		end
		for key, distance in pairs(wanted) do
			if self.chunker.state(key) == "unloaded" then
				candidates[#candidates + 1] = { key = key, distance = distance }
			end
		end
		table.sort(candidates, function(a, b) return a.distance < b.distance end)

		-- unload first so the budget frees up before we load
		local unloaded = {}
		for _, key in ipairs(self.chunker.loadedKeys()) do
			if not wanted[key] and not self.pinned[key] then
				self.chunker.setState(key, "unloaded")
				self.contents[key] = nil
				unloaded[#unloaded + 1] = key
				self.stats.unloaded = self.stats.unloaded + 1
			end
		end

		local loaded = {}
		local budget = self.chunker.maxPerTick
		local capacity = self:capacity()
		for _, item in ipairs(candidates) do
			if budget <= 0 then
				self.stats.deferred = self.stats.deferred + 1
			elseif self.chunker.loaded >= capacity then
				self.stats.evicted = self.stats.evicted + 1
				break
			else
				self.chunker.setState(item.key, "loaded")
				self.contents[item.key] = { key = item.key, lod = 0, loadedAt = self.stats.frames }
				loaded[#loaded + 1] = item.key
				self.stats.loaded = self.stats.loaded + 1
				budget = budget - 1
			end
		end

		for _, key in ipairs(loaded) do
			if self.lastWanted[key] == false then self.stats.thrash = self.stats.thrash + 1 end
		end
		self.lastWanted = {}
		for key in pairs(wanted) do self.lastWanted[key] = true end
		for _, key in ipairs(unloaded) do self.lastWanted[key] = false end

		return loaded, unloaded
	end

	function Streaming:updateLOD()
		local changed = 0
		for key, content in pairs(self.contents) do
			local best = 3
			for _, viewer in pairs(self.viewers) do
				local lod = self.chunker.lodOf(key, viewer.position)
				if lod < best then best = lod end
			end
			if content.lod ~= best then
				content.lod = best
				changed = changed + 1
			end
		end
		return changed
	end

	function Streaming:loadedChunks() return self.chunker.loadedKeys() end

	function Streaming:contentOf(key) return self.contents[key] end

	function Streaming:pressure()
		return self:memoryUsedMB() / math.max(1, self.memoryBudgetMB)
	end

	function Streaming:report()
		return { chunks = self.chunker.stats(), viewers = C.count(self.viewers),
			memoryMB = self:memoryUsedMB(), capacity = self:capacity(), pressure = self:pressure(),
			pinned = C.count(self.pinned), stats = self.stats }
	end

	return Streaming

end
