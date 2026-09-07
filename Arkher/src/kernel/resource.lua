-- ARKHER KERNEL :: Resource System (pools, handles, lifetimes, streaming)
-- Reference-counted resources with async loading, priority streaming, memory budgets
-- and automatic eviction driven by D-O15 memory pressure.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Signal = A:import("arkher/kernel/signal")
	local Resource = {}
	Resource.__index = Resource

	function Resource.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Resource)
		self.entries = {}
		self.loaders = {}
		self.budgetBytes = opts.budgetBytes or (256 * 1024 * 1024)
		self.usedBytes = 0
		self.queue = C.priorityQueue(function(a, b) return a.priority > b.priority end)
		self.cache = C.lru(opts.cacheSize or 512)
		self.onLoaded = Signal.new("resource.loaded")
		self.onEvicted = Signal.new("resource.evicted")
		self.stats = { loads = 0, hits = 0, misses = 0, evictions = 0, bytesPeak = 0, failures = 0 }
		return self
	end

	function Resource:registerLoader(kind, fn) self.loaders[kind] = fn return self end

	function Resource:declare(id, kind, meta)
		self.entries[id] = { id = id, kind = kind, meta = meta or {}, state = "declared",
			refs = 0, bytes = (meta and meta.bytes) or 0, value = nil, lastUse = 0 }
		return self.entries[id]
	end

	function Resource:request(id, priority)
		local e = self.entries[id]
		if not e then return nil, "unknown resource: " .. tostring(id) end
		e.refs = e.refs + 1
		if e.state == "loaded" then
			self.stats.hits = self.stats.hits + 1
			self.cache:set(id, e.value)
			return e.value
		end
		self.stats.misses = self.stats.misses + 1
		if e.state == "declared" then
			e.state = "queued"
			self.queue:push({ id = id, priority = priority or 0 })
		end
		return nil
	end

	function Resource:release(id)
		local e = self.entries[id]
		if not e then return false end
		e.refs = math.max(0, e.refs - 1)
		return true
	end

	-- process the streaming queue with a bounded budget (called every frame)
	function Resource:pump(maxLoads)
		local n = 0
		while n < (maxLoads or 4) and not self.queue:isEmpty() do
			local item = self.queue:pop()
			local e = self.entries[item.id]
			if e and e.state == "queued" then
				local loader = self.loaders[e.kind]
				if loader then
					local ok, value, bytes = pcall(loader, e.id, e.meta)
					if ok then
						e.value = value
						e.bytes = bytes or e.bytes
						e.state = "loaded"
						self.usedBytes = self.usedBytes + e.bytes
						if self.usedBytes > self.stats.bytesPeak then self.stats.bytesPeak = self.usedBytes end
						self.stats.loads = self.stats.loads + 1
						self.cache:set(e.id, value)
						self.onLoaded:fire(e.id, value)
					else
						e.state = "failed"
						e.error = tostring(value)
						self.stats.failures = self.stats.failures + 1
					end
				else
					e.state = "failed"
					e.error = "no loader for kind " .. tostring(e.kind)
					self.stats.failures = self.stats.failures + 1
				end
				n = n + 1
			end
		end
		self:enforceBudget()
		return n
	end

	function Resource:enforceBudget()
		if self.usedBytes <= self.budgetBytes then return 0 end
		local candidates = {}
		for id, e in pairs(self.entries) do
			if e.state == "loaded" and e.refs == 0 then candidates[#candidates + 1] = e end
		end
		table.sort(candidates, function(a, b) return a.lastUse < b.lastUse end)
		local freed = 0
		for _, e in ipairs(candidates) do
			if self.usedBytes <= self.budgetBytes then break end
			self.usedBytes = self.usedBytes - e.bytes
			freed = freed + e.bytes
			e.value = nil
			e.state = "declared"
			self.cache:remove(e.id)
			self.stats.evictions = self.stats.evictions + 1
			self.onEvicted:fire(e.id)
		end
		return freed
	end

	function Resource:touch(id, time)
		local e = self.entries[id]
		if e then e.lastUse = time or 0 end
	end

	function Resource:get(id)
		local e = self.entries[id]
		if e and e.state == "loaded" then return e.value end
		return nil
	end

	function Resource:state(id)
		local e = self.entries[id]
		return e and e.state or "unknown"
	end

	function Resource:memoryPressure() return self.usedBytes / math.max(1, self.budgetBytes) end

	function Resource:report()
		local byKind = {}
		for _, e in pairs(self.entries) do
			byKind[e.kind] = byKind[e.kind] or { count = 0, bytes = 0, loaded = 0 }
			byKind[e.kind].count = byKind[e.kind].count + 1
			byKind[e.kind].bytes = byKind[e.kind].bytes + e.bytes
			if e.state == "loaded" then byKind[e.kind].loaded = byKind[e.kind].loaded + 1 end
		end
		return { used = self.usedBytes, budget = self.budgetBytes, pressure = self:memoryPressure(),
			stats = self.stats, byKind = byKind, cacheHitRate = self.cache:hitRate() }
	end

	------------------------------------------------------------------ Object pool
	local Pool = {}
	Pool.__index = Pool
	function Resource.pool(factory, reset, initial)
		local self = setmetatable({ factory = factory, reset = reset, free = {}, live = 0,
			created = 0, acquired = 0, released = 0 }, Pool)
		for _ = 1, (initial or 0) do
			self.free[#self.free + 1] = factory()
			self.created = self.created + 1
		end
		return self
	end
	function Pool:acquire(...)
		self.acquired = self.acquired + 1
		local obj = table.remove(self.free)
		if not obj then
			obj = self.factory(...)
			self.created = self.created + 1
		end
		self.live = self.live + 1
		return obj
	end
	function Pool:release(obj)
		if self.reset then self.reset(obj) end
		self.free[#self.free + 1] = obj
		self.live = math.max(0, self.live - 1)
		self.released = self.released + 1
	end
	function Pool:prewarm(n)
		for _ = 1, n do
			self.free[#self.free + 1] = self.factory()
			self.created = self.created + 1
		end
	end
	function Pool:stats() return { free = #self.free, live = self.live, created = self.created,
		acquired = self.acquired, released = self.released, reuseRate = self.acquired > 0 and (1 - self.created / self.acquired) or 0 } end
	Resource.Pool = Pool

	return Resource

end
