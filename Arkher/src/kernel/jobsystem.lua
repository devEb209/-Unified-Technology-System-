-- ARKHER KERNEL :: Job System
-- Cooperative coroutine worker pool with time slicing, priorities, dependencies
-- and deterministic completion order. Works with or without real threads.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local JobSystem = {}
	JobSystem.__index = JobSystem

	function JobSystem.new(opts)
		opts = opts or {}
		local self = setmetatable({}, JobSystem)
		self.workers = opts.workers or 4
		self.sliceMs = opts.sliceMs or 2.0
		self.timeFn = opts.timeFn or function() return 0 end
		self.queue = {}
		self.running = {}
		self.done = {}
		self.nextId = 1
		self.completed = 0
		self.failed = 0
		self.yields = 0
		return self
	end

	-- fn receives (yield) and may call yield() to suspend cooperatively
	function JobSystem:schedule(fn, opts)
		opts = opts or {}
		local job = {
			id = self.nextId,
			fn = fn,
			priority = opts.priority or 0,
			name = opts.name or ("job#" .. self.nextId),
			deps = opts.deps or {},
			state = "queued",
			result = nil,
			error = nil,
			progress = 0,
		}
		self.nextId = self.nextId + 1
		self.queue[#self.queue + 1] = job
		table.sort(self.queue, function(a, b) return a.priority > b.priority end)
		return job
	end

	local function depsDone(self, job)
		for _, d in ipairs(job.deps) do
			local dj = self.done[d]
			if not dj then return false end
		end
		return true
	end

	function JobSystem:_start(job)
		job.state = "running"
		job.co = coroutine.create(function()
			local setProgress = function(p) job.progress = p end
			return job.fn(coroutine.yield, setProgress)
		end)
		self.running[#self.running + 1] = job
	end

	-- advance the pool for at most sliceMs milliseconds; returns jobs completed
	function JobSystem:pump(sliceMs)
		local budget = (sliceMs or self.sliceMs) / 1000
		local t0 = self.timeFn()
		local completedNow = 0

		while #self.running < self.workers and #self.queue > 0 do
			local picked = nil
			for i, job in ipairs(self.queue) do
				if depsDone(self, job) then picked = i break end
			end
			if not picked then break end
			local job = table.remove(self.queue, picked)
			self:_start(job)
		end

		local i = 1
		while i <= #self.running do
			local job = self.running[i]
			local ok, res = coroutine.resume(job.co)
			if not ok then
				job.state = "failed"
				job.error = Errors.new(Errors.Codes.INTERNAL, tostring(res), { source = job.name })
				self.failed = self.failed + 1
				self.done[job.id] = job
				table.remove(self.running, i)
				completedNow = completedNow + 1
			elseif coroutine.status(job.co) == "dead" then
				job.state = "done"
				job.result = res
				job.progress = 1
				self.completed = self.completed + 1
				self.done[job.id] = job
				table.remove(self.running, i)
				completedNow = completedNow + 1
			else
				self.yields = self.yields + 1
				i = i + 1
			end
			if (self.timeFn() - t0) > budget then break end
		end
		return completedNow
	end

	function JobSystem:isIdle() return #self.queue == 0 and #self.running == 0 end

	function JobSystem:drain(maxPumps)
		local n = 0
		local guard = maxPumps or 100000
		while not self:isIdle() and n < guard do
			self:pump(1e9)
			n = n + 1
		end
		return n
	end

	function JobSystem:await(job, maxPumps)
		local guard = maxPumps or 100000
		local n = 0
		while job.state ~= "done" and job.state ~= "failed" and n < guard do
			self:pump(1e9)
			n = n + 1
		end
		return job.result, job.error
	end

	function JobSystem:stats()
		return { queued = #self.queue, running = #self.running, completed = self.completed,
			failed = self.failed, yields = self.yields, workers = self.workers }
	end

	-- parallelFor: split a range into chunks executed as jobs
	function JobSystem:parallelFor(from, to, chunk, fn, opts)
		local jobs = {}
		local i = from
		while i <= to do
			local lo = i
			local hi = math.min(i + chunk - 1, to)
			jobs[#jobs + 1] = self:schedule(function(yield)
				for k = lo, hi do fn(k) end
				return hi - lo + 1
			end, opts)
			i = hi + 1
		end
		return jobs
	end

	return JobSystem

end
