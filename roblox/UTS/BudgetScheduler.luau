-- Cooperative, bounded work queue. A callback MUST NOT yield or perform unbounded work.
-- This is a time-budget scheduler, not a physics engine or a hard real-time guarantee.
local Scheduler = {}
Scheduler.__index = Scheduler

local function positive(value, label)
	assert(type(value) == "number" and value == value and value > 0 and value < math.huge, label)
	return value
end

function Scheduler.new(options)
	options = options or {}
	local self = setmetatable({}, Scheduler)
	self.budget = positive(options.budgetSeconds or 0.002, "invalid budget")
	self.capacity = positive(options.capacity or 1024, "invalid capacity")
	self.maxPerStep = positive(options.maxPerStep or math.min(64, self.capacity), "invalid step limit")
	assert(self.capacity % 1 == 0 and self.capacity <= 65536, "invalid capacity")
	assert(self.maxPerStep % 1 == 0 and self.maxPerStep <= self.capacity, "invalid step limit")
	self.clock = options.clock or os.clock
	assert(type(self.clock) == "function", "clock must be a function")
	self.queue, self.jobs = {}, {}
	self.stepping = false
	return self
end

function Scheduler:Add(id, callback)
	assert(type(id) == "string" and #id > 0, "id must be a non-empty string")
	assert(type(callback) == "function", "callback must be a function")
	assert(not self.jobs[id], "duplicate task: " .. id)
	assert(self:Count() < self.capacity, "scheduler capacity reached")
	local job = { id = id, callback = callback }
	self.jobs[id] = job
	table.insert(self.queue, job)
	return id
end

function Scheduler:Count()
	local count = 0
	for _ in pairs(self.jobs) do count += 1 end
	return count
end

function Scheduler:Cancel(id)
	local job = self.jobs[id]
	if not job then return false end
	self.jobs[id] = nil
	for index = #self.queue, 1, -1 do
		if self.queue[index] == job then table.remove(self.queue, index) end
	end
	return true
end

function Scheduler:Clear()
	table.clear(self.jobs)
	table.clear(self.queue)
end

function Scheduler:Step()
	assert(not self.stepping, "Step is not reentrant")
	local started = self.clock()
	local report = { processed = 0, completed = 0, errors = {}, elapsed = 0 }
	local batch = table.clone(self.queue)
	self.stepping = true
	for _, job in ipairs(batch) do
		if report.processed >= self.maxPerStep or self.clock() - started >= self.budget then break end
		if self.jobs[job.id] == job then
			for index, queued in ipairs(self.queue) do
				if queued == job then table.remove(self.queue, index); break end
			end
			local ok, finished = pcall(job.callback)
			report.processed += 1
			if self.jobs[job.id] == job then
				if not ok or finished == true then
					self.jobs[job.id] = nil
					if ok then report.completed += 1 end
				else
					table.insert(self.queue, job)
				end
			end
			if not ok then table.insert(report.errors, { id = job.id, message = tostring(finished) }) end
		end
	end
	self.stepping = false
	report.elapsed = self.clock() - started
	report.remaining = self:Count()
	return report
end

return Scheduler
