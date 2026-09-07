-- ARKHER KERNEL :: Clock / Time abstraction
-- Deterministic, platform independent time source with scaling and fixed steps.
--@arkher-module
return function(A)
	local Clock = {}
	Clock.__index = Clock

	function Clock.new(timeProvider)
		local self = setmetatable({}, Clock)
		self._provider = timeProvider or function() return 0 end
		self._start = self._provider()
		self._last = self._start
		self.now = 0
		self.delta = 0
		self.unscaledDelta = 0
		self.scale = 1
		self.frame = 0
		self.fixedStep = 1 / 60
		self._accumulator = 0
		self.maxDelta = 0.25
		self.paused = false
		self._smoothed = 1 / 60
		return self
	end

	function Clock:tick(forcedDelta)
		local t = self._provider()
		local raw = forcedDelta or (t - self._last)
		if raw < 0 then raw = 0 end
		if raw > self.maxDelta then raw = self.maxDelta end
		self._last = t
		self.unscaledDelta = raw
		self.delta = self.paused and 0 or raw * self.scale
		self.now = self.now + self.delta
		self.frame = self.frame + 1
		self._accumulator = self._accumulator + self.delta
		self._smoothed = self._smoothed * 0.9 + raw * 0.1
		return self.delta
	end

	-- consumes accumulated time in fixed steps, returns count of steps to run
	function Clock:consumeFixed(maxSteps)
		local steps = 0
		local limit = maxSteps or 8
		while self._accumulator >= self.fixedStep and steps < limit do
			self._accumulator = self._accumulator - self.fixedStep
			steps = steps + 1
		end
		if steps >= limit then self._accumulator = 0 end
		return steps
	end

	function Clock:alpha() return self._accumulator / self.fixedStep end
	function Clock:fps() if self._smoothed <= 0 then return 0 end return 1 / self._smoothed end
	function Clock:setScale(s) self.scale = math.max(0, s) end
	function Clock:pause() self.paused = true end
	function Clock:resume() self.paused = false end
	function Clock:elapsed() return self._provider() - self._start end

	return Clock

end
