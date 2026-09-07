-- ARKHER KERNEL :: Logging System
-- Leveled, tagged, ring-buffered logging with sinks, rate limiting and structured fields.
--@arkher-module
return function(A)
	local Log = {}
	Log.__index = Log

	Log.Level = { TRACE = 10, DEBUG = 20, INFO = 30, WARN = 40, ERROR = 50, FATAL = 60, OFF = 99 }
	local levelName = {}
	for k, v in pairs(Log.Level) do levelName[v] = k end

	function Log.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Log)
		self.level = opts.level or Log.Level.INFO
		self.capacity = opts.capacity or 2048
		self.buffer = {}
		self._head = 0
		self.sinks = {}
		self.tagLevels = {}
		self._rate = {}
		self.rateWindow = opts.rateWindow or 1.0
		self.rateLimit = opts.rateLimit or 200
		self.counts = { TRACE = 0, DEBUG = 0, INFO = 0, WARN = 0, ERROR = 0, FATAL = 0 }
		self.timeFn = opts.timeFn or function() return 0 end
		return self
	end

	function Log:addSink(name, fn) self.sinks[name] = fn return self end
	function Log:removeSink(name) self.sinks[name] = nil end
	function Log:setLevel(l) self.level = l end
	function Log:setTagLevel(tag, l) self.tagLevels[tag] = l end

	function Log:_allowed(tag, level)
		local min = self.tagLevels[tag] or self.level
		return level >= min
	end

	function Log:_rateOk(key, now)
		local slot = self._rate[key]
		if not slot or (now - slot.t) > self.rateWindow then
			self._rate[key] = { t = now, n = 1 }
			return true
		end
		slot.n = slot.n + 1
		return slot.n <= self.rateLimit
	end

	function Log:emit(level, tag, message, fields)
		if not self:_allowed(tag, level) then return false end
		local now = self.timeFn()
		if not self:_rateOk(tag .. tostring(level), now) then return false end
		local rec = {
			t = now, level = level, levelName = levelName[level] or "?",
			tag = tag, message = message, fields = fields,
		}
		self._head = self._head + 1
		self.buffer[(self._head - 1) % self.capacity + 1] = rec
		local ln = rec.levelName
		if self.counts[ln] then self.counts[ln] = self.counts[ln] + 1 end
		for _, sink in pairs(self.sinks) do pcall(sink, rec) end
		return true
	end

	function Log:trace(tag, m, f) return self:emit(Log.Level.TRACE, tag, m, f) end
	function Log:debug(tag, m, f) return self:emit(Log.Level.DEBUG, tag, m, f) end
	function Log:info(tag, m, f) return self:emit(Log.Level.INFO, tag, m, f) end
	function Log:warn(tag, m, f) return self:emit(Log.Level.WARN, tag, m, f) end
	function Log:error(tag, m, f) return self:emit(Log.Level.ERROR, tag, m, f) end
	function Log:fatal(tag, m, f) return self:emit(Log.Level.FATAL, tag, m, f) end

	function Log:tail(n)
		n = math.min(n or 50, math.min(self._head, self.capacity))
		local out = {}
		for i = self._head - n + 1, self._head do
			out[#out + 1] = self.buffer[(i - 1) % self.capacity + 1]
		end
		return out
	end

	function Log:format(rec)
		local s = string.format("%8.3f [%-5s] %-18s %s", rec.t, rec.levelName, rec.tag, rec.message)
		if rec.fields then
			local parts = {}
			for k, v in pairs(rec.fields) do parts[#parts + 1] = k .. "=" .. tostring(v) end
			table.sort(parts)
			s = s .. " {" .. table.concat(parts, " ") .. "}"
		end
		return s
	end

	return Log

end
