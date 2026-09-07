-- ARKHER KERNEL :: Event Bus
-- Typed, wildcard-capable, deferred/immediate publish-subscribe with backpressure.
--@arkher-module
return function(A)
	local Signal = A:import("arkher/kernel/signal")
	local EventBus = {}
	EventBus.__index = EventBus

	function EventBus.new(opts)
		opts = opts or {}
		local self = setmetatable({}, EventBus)
		self._topics = {}
		self._wildcards = {}
		self._queue = {}
		self._queueHead = 1
		self._queueTail = 0
		self.maxQueue = opts.maxQueue or 8192
		self.dropped = 0
		self.published = 0
		self.delivered = 0
		self._recording = false
		self._record = {}
		return self
	end

	local function topicMatches(pattern, topic)
		if pattern == topic then return true end
		local star = string.find(pattern, "*", 1, true)
		if not star then return false end
		local prefix = string.sub(pattern, 1, star - 1)
		return string.sub(topic, 1, #prefix) == prefix
	end

	function EventBus:subscribe(topic, fn, priority)
		if string.find(topic, "*", 1, true) then
			local entry = { pattern = topic, fn = fn, priority = priority or 0, connected = true }
			self._wildcards[#self._wildcards + 1] = entry
			table.sort(self._wildcards, function(a, b) return a.priority > b.priority end)
			return { disconnect = function() entry.connected = false end }
		end
		local sig = self._topics[topic]
		if not sig then sig = Signal.new(topic); self._topics[topic] = sig end
		return sig:connect(fn, priority)
	end

	function EventBus:once(topic, fn, priority)
		local sig = self._topics[topic]
		if not sig then sig = Signal.new(topic); self._topics[topic] = sig end
		return sig:once(fn, priority)
	end

	function EventBus:publish(topic, payload)
		self.published = self.published + 1
		if self._recording then self._record[#self._record + 1] = { topic = topic, payload = payload } end
		local sig = self._topics[topic]
		local hit = 0
		if sig then sig:fire(payload, topic); hit = hit + sig:count() end
		for _, w in ipairs(self._wildcards) do
			if w.connected and topicMatches(w.pattern, topic) then
				pcall(w.fn, payload, topic)
				hit = hit + 1
			end
		end
		self.delivered = self.delivered + hit
		return hit
	end

	function EventBus:post(topic, payload)
		local size = self._queueTail - self._queueHead + 1
		if size >= self.maxQueue then self.dropped = self.dropped + 1 return false end
		self._queueTail = self._queueTail + 1
		self._queue[self._queueTail] = { topic = topic, payload = payload }
		return true
	end

	function EventBus:flush(maxEvents)
		local budget = maxEvents or math.huge
		local n = 0
		while self._queueHead <= self._queueTail and n < budget do
			local ev = self._queue[self._queueHead]
			self._queue[self._queueHead] = nil
			self._queueHead = self._queueHead + 1
			self:publish(ev.topic, ev.payload)
			n = n + 1
		end
		if self._queueHead > self._queueTail then self._queueHead = 1 self._queueTail = 0 end
		return n
	end

	function EventBus:pending() return math.max(0, self._queueTail - self._queueHead + 1) end
	function EventBus:startRecording() self._recording = true self._record = {} end
	function EventBus:stopRecording() self._recording = false return self._record end
	function EventBus:replay(records)
		for _, r in ipairs(records) do self:publish(r.topic, r.payload) end
		return #records
	end
	function EventBus:topics()
		local out = {}
		for k in pairs(self._topics) do out[#out + 1] = k end
		table.sort(out)
		return out
	end
	function EventBus:stats()
		return { published = self.published, delivered = self.delivered, dropped = self.dropped, pending = self:pending() }
	end

	return EventBus

end
