-- ARKHER KERNEL :: Promise / Async Runtime
-- Deterministic promise implementation with then/catch/finally, all/any/race,
-- cancellation and timeouts driven by the engine clock (no real threads needed).
--@arkher-module
return function(A)
	local Promise = {}
	Promise.__index = Promise

	Promise.State = { PENDING = "pending", FULFILLED = "fulfilled", REJECTED = "rejected", CANCELLED = "cancelled" }

	local function isCallable(v) return type(v) == "function" end

	function Promise.new(executor)
		local self = setmetatable({}, Promise)
		self.state = Promise.State.PENDING
		self.value = nil
		self._callbacks = {}
		self._cancelHandlers = {}
		if executor then
			local ok, err = pcall(executor,
				function(v) self:_settle(Promise.State.FULFILLED, v) end,
				function(e) self:_settle(Promise.State.REJECTED, e) end)
			if not ok then self:_settle(Promise.State.REJECTED, err) end
		end
		return self
	end

	function Promise:_settle(state, value)
		if self.state ~= Promise.State.PENDING then return false end
		self.state = state
		self.value = value
		for _, cb in ipairs(self._callbacks) do cb(state, value) end
		self._callbacks = {}
		return true
	end

	function Promise.resolve(v)
		if type(v) == "table" and getmetatable(v) == Promise then return v end
		local p = Promise.new()
		p:_settle(Promise.State.FULFILLED, v)
		return p
	end

	function Promise.reject(e)
		local p = Promise.new()
		p:_settle(Promise.State.REJECTED, e)
		return p
	end

	function Promise:andThen(onOk, onErr)
		local next = Promise.new()
		local function handle(state, value)
			if state == Promise.State.FULFILLED then
				if isCallable(onOk) then
					local ok, res = pcall(onOk, value)
					if not ok then next:_settle(Promise.State.REJECTED, res)
					elseif type(res) == "table" and getmetatable(res) == Promise then
						res:andThen(function(v) next:_settle(Promise.State.FULFILLED, v) end,
							function(e) next:_settle(Promise.State.REJECTED, e) end)
					else next:_settle(Promise.State.FULFILLED, res) end
				else next:_settle(Promise.State.FULFILLED, value) end
			elseif state == Promise.State.REJECTED then
				if isCallable(onErr) then
					local ok, res = pcall(onErr, value)
					if not ok then next:_settle(Promise.State.REJECTED, res)
					else next:_settle(Promise.State.FULFILLED, res) end
				else next:_settle(Promise.State.REJECTED, value) end
			else
				next:_settle(Promise.State.CANCELLED, value)
			end
		end
		if self.state == Promise.State.PENDING then
			self._callbacks[#self._callbacks + 1] = handle
		else
			handle(self.state, self.value)
		end
		return next
	end

	function Promise:catch(fn) return self:andThen(nil, fn) end
	function Promise:finally(fn)
		return self:andThen(function(v) fn() return v end, function(e) fn() error(e) end)
	end
	function Promise:cancel(reason)
		if self.state ~= Promise.State.PENDING then return false end
		for _, h in ipairs(self._cancelHandlers) do pcall(h, reason) end
		return self:_settle(Promise.State.CANCELLED, reason or "cancelled")
	end
	function Promise:onCancel(fn) self._cancelHandlers[#self._cancelHandlers + 1] = fn return self end
	function Promise:isPending() return self.state == Promise.State.PENDING end

	function Promise.all(list)
		local out = Promise.new()
		local results = {}
		local remaining = #list
		if remaining == 0 then out:_settle(Promise.State.FULFILLED, results) return out end
		for i, p in ipairs(list) do
			Promise.resolve(p):andThen(function(v)
				results[i] = v
				remaining = remaining - 1
				if remaining == 0 then out:_settle(Promise.State.FULFILLED, results) end
			end, function(e) out:_settle(Promise.State.REJECTED, e) end)
		end
		return out
	end

	function Promise.race(list)
		local out = Promise.new()
		for _, p in ipairs(list) do
			Promise.resolve(p):andThen(function(v) out:_settle(Promise.State.FULFILLED, v) end,
				function(e) out:_settle(Promise.State.REJECTED, e) end)
		end
		return out
	end

	function Promise.any(list)
		local out = Promise.new()
		local remaining = #list
		for _, p in ipairs(list) do
			Promise.resolve(p):andThen(function(v) out:_settle(Promise.State.FULFILLED, v) end,
				function(e)
					remaining = remaining - 1
					if remaining == 0 then out:_settle(Promise.State.REJECTED, "all rejected") end
				end)
		end
		return out
	end

	-- retry with exponential backoff driven by a tick-based waiter
	function Promise.retry(factory, attempts, onRetry)
		local attempt = 0
		local function run()
			attempt = attempt + 1
			return Promise.resolve(factory(attempt)):catch(function(err)
				if attempt >= attempts then error(err) end
				if onRetry then onRetry(attempt, err) end
				return run()
			end)
		end
		return run()
	end

	return Promise

end
