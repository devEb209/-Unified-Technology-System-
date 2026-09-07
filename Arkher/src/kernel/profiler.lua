-- ARKHER KERNEL :: Profiler + Diagnostics + Telemetry
-- Hierarchical scoped timing, counters, frame history, percentile analysis and
-- machine-readable reports consumed by D-O15 and the Singularity optimizer.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Profiler = {}
	Profiler.__index = Profiler

	function Profiler.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Profiler)
		self.timeFn = opts.timeFn or function() return 0 end
		self.scopes = {}
		self.stack = {}
		self.counters = {}
		self.frameHistory = C.ring(opts.history or 240)
		self.frameStart = 0
		self.enabled = true
		self.frames = 0
		self.markers = {}
		self.gpuEstimates = {}
		return self
	end

	function Profiler:beginFrame()
		if not self.enabled then return end
		self.frameStart = self.timeFn()
		self.stack = {}
		self.frames = self.frames + 1
		for _, s in pairs(self.scopes) do s.frameMs = 0 end
	end

	function Profiler:endFrame()
		if not self.enabled then return 0 end
		local ms = (self.timeFn() - self.frameStart) * 1000
		self.frameHistory:push(ms)
		return ms
	end

	function Profiler:push(name)
		if not self.enabled then return end
		self.stack[#self.stack + 1] = { name = name, t0 = self.timeFn(), parent = self.stack[#self.stack] and self.stack[#self.stack].name }
	end

	function Profiler:pop()
		if not self.enabled then return 0 end
		local entry = table.remove(self.stack)
		if not entry then return 0 end
		local ms = (self.timeFn() - entry.t0) * 1000
		local s = self.scopes[entry.name]
		if not s then
			s = { name = entry.name, calls = 0, totalMs = 0, maxMs = 0, avgMs = 0, frameMs = 0, parent = entry.parent, samples = C.ring(120) }
			self.scopes[entry.name] = s
		end
		s.calls = s.calls + 1
		s.totalMs = s.totalMs + ms
		s.frameMs = s.frameMs + ms
		if ms > s.maxMs then s.maxMs = ms end
		s.avgMs = s.totalMs / s.calls
		s.samples:push(ms)
		return ms
	end

	function Profiler:measure(name, fn, ...)
		self:push(name)
		local results = table.pack(pcall(fn, ...))
		self:pop()
		if not results[1] then error(results[2]) end
		return table.unpack(results, 2, results.n)
	end

	function Profiler:count(name, delta)
		self.counters[name] = (self.counters[name] or 0) + (delta or 1)
		return self.counters[name]
	end
	function Profiler:setCounter(name, value) self.counters[name] = value end
	function Profiler:getCounter(name) return self.counters[name] or 0 end

	function Profiler:mark(name)
		self.markers[#self.markers + 1] = { name = name, t = self.timeFn() }
		if #self.markers > 512 then table.remove(self.markers, 1) end
	end

	function Profiler:frameStats()
		local samples = self.frameHistory:toTable()
		if #samples == 0 then return { avg = 0, p50 = 0, p95 = 0, p99 = 0, max = 0, fps = 0, count = 0 } end
		local avg = Mathx.mean(samples)
		return {
			avg = avg,
			p50 = Mathx.percentile(samples, 50),
			p95 = Mathx.percentile(samples, 95),
			p99 = Mathx.percentile(samples, 99),
			max = self.frameHistory:max(),
			fps = avg > 0 and (1000 / avg) or 0,
			stability = 1 - math.min(1, Mathx.stddev(samples) / math.max(avg, 0.001)),
			count = #samples,
		}
	end

	function Profiler:topScopes(n)
		local list = {}
		for _, s in pairs(self.scopes) do
			list[#list + 1] = { name = s.name, avgMs = s.avgMs, totalMs = s.totalMs, calls = s.calls, maxMs = s.maxMs }
		end
		table.sort(list, function(a, b) return a.totalMs > b.totalMs end)
		local out = {}
		for i = 1, math.min(n or 10, #list) do out[i] = list[i] end
		return out
	end

	function Profiler:flameTree()
		local roots = {}
		local nodes = {}
		for name, s in pairs(self.scopes) do
			nodes[name] = { name = name, ms = s.totalMs, calls = s.calls, children = {} }
		end
		for name, s in pairs(self.scopes) do
			if s.parent and nodes[s.parent] then
				table.insert(nodes[s.parent].children, nodes[name])
			else
				table.insert(roots, nodes[name])
			end
		end
		table.sort(roots, function(a, b) return a.ms > b.ms end)
		return roots
	end

	function Profiler:report()
		return { frame = self:frameStats(), top = self:topScopes(15), counters = self.counters, frames = self.frames }
	end

	function Profiler:reset()
		self.scopes = {}
		self.counters = {}
		self.frameHistory:clear()
		self.frames = 0
	end

	return Profiler

end
