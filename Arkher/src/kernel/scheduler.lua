-- ARKHER KERNEL :: System Scheduler
-- Frame-budgeted, priority-ordered, phase-based execution with time slicing and
-- automatic degradation hooks consumed by D-O15.
--@arkher-module
return function(A)
	local Scheduler = {}
	Scheduler.__index = Scheduler

	Scheduler.Phase = { PRE = 1, INPUT = 2, SIMULATION = 3, PHYSICS = 4, ANIMATION = 5,
		AI = 6, WORLD = 7, RENDER = 8, UI = 9, NETWORK = 10, POST = 11 }

	function Scheduler.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Scheduler)
		self.tasks = {}
		self.byPhase = {}
		for _, p in pairs(Scheduler.Phase) do self.byPhase[p] = {} end
		self.frameBudgetMs = opts.frameBudgetMs or 8.0
		self.timeFn = opts.timeFn or function() return 0 end
		self.overruns = 0
		self.frames = 0
		self.deferred = {}
		self.stats = {}
		self.enabled = true
		return self
	end

	function Scheduler:add(spec)
		local task = {
			id = spec.id,
			fn = spec.fn,
			phase = spec.phase or Scheduler.Phase.SIMULATION,
			priority = spec.priority or 0,
			interval = spec.interval or 0,
			budgetMs = spec.budgetMs or 0,
			enabled = spec.enabled ~= false,
			accumulated = 0,
			lastRun = -1,
			cost = 0,
			runs = 0,
			importance = spec.importance or 1.0,
		}
		self.tasks[task.id] = task
		local bucket = self.byPhase[task.phase]
		bucket[#bucket + 1] = task
		table.sort(bucket, function(a, b) return a.priority > b.priority end)
		self.stats[task.id] = { avgMs = 0, maxMs = 0, skips = 0, runs = 0 }
		return task
	end

	function Scheduler:remove(id)
		local t = self.tasks[id]
		if not t then return false end
		self.tasks[id] = nil
		local bucket = self.byPhase[t.phase]
		for i, x in ipairs(bucket) do if x == t then table.remove(bucket, i) break end end
		return true
	end

	function Scheduler:setEnabled(id, on)
		local t = self.tasks[id]
		if t then t.enabled = on return true end
		return false
	end

	function Scheduler:defer(fn) self.deferred[#self.deferred + 1] = fn end

	function Scheduler:runPhase(phase, dt, ctx)
		local bucket = self.byPhase[phase]
		if not bucket then return 0 end
		local start = self.timeFn()
		local ran = 0
		for _, task in ipairs(bucket) do
			if task.enabled and self.enabled then
				local due = true
				if task.interval > 0 then
					task.accumulated = task.accumulated + dt
					if task.accumulated < task.interval then due = false
					else task.accumulated = task.accumulated - task.interval end
				end
				if due then
					local t0 = self.timeFn()
					local ok, err = pcall(task.fn, dt, ctx)
					local ms = (self.timeFn() - t0) * 1000
					local s = self.stats[task.id]
					s.runs = s.runs + 1
					s.avgMs = s.avgMs * 0.9 + ms * 0.1
					if ms > s.maxMs then s.maxMs = ms end
					task.cost = ms
					task.runs = task.runs + 1
					if not ok then s.error = tostring(err) end
					ran = ran + 1
					local elapsedMs = (self.timeFn() - start) * 1000
					if self.frameBudgetMs > 0 and elapsedMs > self.frameBudgetMs then
						self.overruns = self.overruns + 1
						break
					end
				else
					self.stats[task.id].skips = self.stats[task.id].skips + 1
				end
			end
		end
		return ran
	end

	function Scheduler:frame(dt, ctx)
		self.frames = self.frames + 1
		local total = 0
		for _, phase in ipairs({ 1,2,3,4,5,6,7,8,9,10,11 }) do
			total = total + self:runPhase(phase, dt, ctx)
		end
		local d = self.deferred
		self.deferred = {}
		for _, fn in ipairs(d) do pcall(fn) end
		return total
	end

	-- returns tasks sorted by measured cost (used by D-O15 bottleneck detection)
	function Scheduler:hotTasks(n)
		local list = {}
		for id, s in pairs(self.stats) do list[#list + 1] = { id = id, avgMs = s.avgMs, runs = s.runs } end
		table.sort(list, function(a, b) return a.avgMs > b.avgMs end)
		local out = {}
		for i = 1, math.min(n or 10, #list) do out[i] = list[i] end
		return out
	end

	function Scheduler:totalCostMs()
		local sum = 0
		for _, s in pairs(self.stats) do sum = sum + s.avgMs end
		return sum
	end

	-- degrade: disable lowest-importance tasks until the projected cost fits the budget
	function Scheduler:degradeToBudget(budgetMs)
		local list = {}
		for id, t in pairs(self.tasks) do list[#list + 1] = t end
		table.sort(list, function(a, b) return a.importance < b.importance end)
		local cost = self:totalCostMs()
		local disabled = {}
		for _, t in ipairs(list) do
			if cost <= budgetMs then break end
			if t.enabled and t.importance < 1.0 then
				t.enabled = false
				cost = cost - (self.stats[t.id].avgMs or 0)
				disabled[#disabled + 1] = t.id
			end
		end
		return disabled, cost
	end

	return Scheduler

end
