-- ARKHER KERNEL :: Signal
-- Allocation-light observer with priorities, once-connections and safe disconnect during fire.
--@arkher-module
return function(A)
	local Signal = {}
	Signal.__index = Signal

	function Signal.new(name)
		local self = setmetatable({}, Signal)
		self.name = name or "signal"
		self._slots = {}
		self._firing = false
		self._pendingRemoval = nil
		self.fireCount = 0
		return self
	end

	local Connection = {}
	Connection.__index = Connection
	function Connection:disconnect()
		if not self.connected then return end
		self.connected = false
		local sig = self._signal
		if sig._firing then
			sig._pendingRemoval = sig._pendingRemoval or {}
			sig._pendingRemoval[#sig._pendingRemoval + 1] = self
		else
			for i, s in ipairs(sig._slots) do
				if s == self then table.remove(sig._slots, i) break end
			end
		end
	end

	function Signal:connect(fn, priority)
		local c = setmetatable({}, Connection)
		c.fn = fn
		c.priority = priority or 0
		c.connected = true
		c.once = false
		c._signal = self
		self._slots[#self._slots + 1] = c
		table.sort(self._slots, function(a, b) return a.priority > b.priority end)
		return c
	end

	function Signal:once(fn, priority)
		local c = self:connect(fn, priority)
		c.once = true
		return c
	end

	function Signal:fire(...)
		self._firing = true
		self.fireCount = self.fireCount + 1
		local errs = nil
		for _, c in ipairs(self._slots) do
			if c.connected then
				local ok, err = pcall(c.fn, ...)
				if not ok then
					errs = errs or {}
					errs[#errs + 1] = err
				end
				if c.once then c.connected = false; self._pendingRemoval = self._pendingRemoval or {}; self._pendingRemoval[#self._pendingRemoval + 1] = c end
			end
		end
		self._firing = false
		if self._pendingRemoval then
			for _, dead in ipairs(self._pendingRemoval) do
				for i, s in ipairs(self._slots) do
					if s == dead then table.remove(self._slots, i) break end
				end
			end
			self._pendingRemoval = nil
		end
		return errs
	end

	function Signal:count()
		local n = 0
		for _, c in ipairs(self._slots) do if c.connected then n = n + 1 end end
		return n
	end

	function Signal:clear() self._slots = {} end

	return Signal

end
