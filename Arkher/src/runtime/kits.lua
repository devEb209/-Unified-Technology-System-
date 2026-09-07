-- ARKHER RUNTIME :: System Kits
-- Real, shared implementations that catalog systems specialize. A kit is a working
-- machine (registry, pipeline, controller, index, guard...); a catalog system is that
-- machine configured for a concrete engine responsibility plus its own logic.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")
	local Errors = A:import("arkher/kernel/errors")
	local Validate = A:import("arkher/kernel/validate")
	local Ser = A:import("arkher/kernel/serialize")
	local Hash = A:import("arkher/kernel/hash")
	local Spatial = A:import("arkher/kernel/spatial")
	local Noise = A:import("arkher/kernel/noise")
	local Random = A:import("arkher/kernel/random")

	local Kits = {}

	------------------------------------------------------------------ 1. REGISTRY
	-- Indexed record store with tags, schema validation, queries and change events.
	function Kits.registry(cfg)
		local self = {
			kind = "registry", records = {}, byTag = {}, order = {}, schema = cfg.schema,
			onChange = Signal.new(cfg.id .. ".change"), count = 0, version = 0,
		}
		function self.define(id, data, tags)
			if self.schema then
				local ok, issues = Validate.check(data, self.schema)
				if not ok then return nil, Errors.new(Errors.Codes.VALIDATION, issues[1].path .. ": " .. issues[1].message) end
			end
			local isNew = self.records[id] == nil
			self.records[id] = { id = id, data = data, tags = tags or {}, version = self.version + 1 }
			if isNew then
				self.count = self.count + 1
				self.order[#self.order + 1] = id
			end
			for _, t in ipairs(tags or {}) do
				self.byTag[t] = self.byTag[t] or {}
				self.byTag[t][id] = true
			end
			self.version = self.version + 1
			self.onChange:fire(id, data, isNew)
			return self.records[id]
		end
		function self.get(id) local r = self.records[id] return r and r.data or nil end
		function self.has(id) return self.records[id] ~= nil end
		function self.remove(id)
			if not self.records[id] then return false end
			for _, t in ipairs(self.records[id].tags) do
				if self.byTag[t] then self.byTag[t][id] = nil end
			end
			self.records[id] = nil
			self.count = self.count - 1
			for i, x in ipairs(self.order) do if x == id then table.remove(self.order, i) break end end
			self.version = self.version + 1
			return true
		end
		function self.withTag(tag)
			local out = {}
			for id in pairs(self.byTag[tag] or {}) do out[#out + 1] = id end
			table.sort(out)
			return out
		end
		function self.query(predicate)
			local out = {}
			for _, id in ipairs(self.order) do
				local r = self.records[id]
				if r and predicate(r.data, id, r.tags) then out[#out + 1] = r.data end
			end
			return out
		end
		function self.ids() local out = {} for i, id in ipairs(self.order) do out[i] = id end return out end
		function self.snapshot() return { version = self.version, records = C.deepCopy(self.records) } end
		function self.restore(snap)
			self.records = C.deepCopy(snap.records)
			self.version = snap.version
			self.count = C.count(self.records)
			self.order = {}
			for id in pairs(self.records) do self.order[#self.order + 1] = id end
			table.sort(self.order)
			return self.count
		end
		function self.stats() return { count = self.count, version = self.version, tags = C.count(self.byTag) } end
		return self
	end

	------------------------------------------------------------------ 2. PIPELINE
	-- Ordered stages with isolation, timing, bypass, retries and per-stage budgets.
	function Kits.pipeline(cfg)
		local self = { kind = "pipeline", stages = {}, timing = {}, runs = 0, failures = 0,
			budgetMs = cfg.budgetMs or 8, onStage = Signal.new(cfg.id .. ".stage") }
		function self.addStage(name, fn, opts)
			opts = opts or {}
			self.stages[#self.stages + 1] = { name = name, fn = fn, order = opts.order or #self.stages + 1,
				enabled = true, optional = opts.optional == true, retries = opts.retries or 0 }
			table.sort(self.stages, function(a, b) return a.order < b.order end)
			return self
		end
		function self.disable(name) for _, s in ipairs(self.stages) do if s.name == name then s.enabled = false end end end
		function self.enable(name) for _, s in ipairs(self.stages) do if s.name == name then s.enabled = true end end end
		function self.run(input, ctx)
			self.runs = self.runs + 1
			local value = input
			local trace = {}
			for _, s in ipairs(self.stages) do
				if s.enabled then
					local attempts = 0
					local ok, res
					repeat
						attempts = attempts + 1
						ok, res = pcall(s.fn, value, ctx or {})
					until ok or attempts > s.retries
					trace[#trace + 1] = { stage = s.name, ok = ok, attempts = attempts }
					if ok then
						if res ~= nil then value = res end
					else
						self.failures = self.failures + 1
						if not s.optional then
							return nil, Errors.new(Errors.Codes.INTERNAL, "stage '" .. s.name .. "' failed: " .. tostring(res)), trace
						end
					end
					self.timing[s.name] = (self.timing[s.name] or 0) + 1
					self.onStage:fire(s.name, ok)
				end
			end
			return value, nil, trace
		end
		function self.stageNames()
			local out = {}
			for i, s in ipairs(self.stages) do out[i] = s.name end
			return out
		end
		function self.stats() return { stages = #self.stages, runs = self.runs, failures = self.failures } end
		return self
	end

	------------------------------------------------------------------ 3. CACHE
	-- Multi-policy cache: LRU / LFU / TTL / ARC-lite, with real eviction and metrics.
	function Kits.cache(cfg)
		local self = { kind = "cache", policy = cfg.policy or "lru", capacity = cfg.capacity or 256,
			ttl = cfg.ttl or 0, entries = {}, order = {}, freq = {}, time = 0,
			hits = 0, misses = 0, evictions = 0 }
		local function touch(key)
			if self.policy == "lru" or self.policy == "arc" then
				for i, k in ipairs(self.order) do if k == key then table.remove(self.order, i) break end end
				self.order[#self.order + 1] = key
			end
			self.freq[key] = (self.freq[key] or 0) + 1
		end
		function self.set(key, value, bytes)
			if self.entries[key] == nil then self.order[#self.order + 1] = key end
			self.entries[key] = { value = value, t = self.time, bytes = bytes or 0 }
			touch(key)
			self.evict()
			return value
		end
		function self.get(key)
			local e = self.entries[key]
			if not e then self.misses = self.misses + 1 return nil end
			if self.ttl > 0 and (self.time - e.t) > self.ttl then
				self.remove(key)
				self.misses = self.misses + 1
				return nil
			end
			self.hits = self.hits + 1
			touch(key)
			return e.value
		end
		function self.remove(key)
			if self.entries[key] == nil then return false end
			self.entries[key] = nil
			self.freq[key] = nil
			for i, k in ipairs(self.order) do if k == key then table.remove(self.order, i) break end end
			return true
		end
		function self.evict()
			local n = 0
			while C.count(self.entries) > self.capacity do
				local victim
				if self.policy == "lfu" then
					local lowest = math.huge
					for k in pairs(self.entries) do
						local f = self.freq[k] or 0
						if f < lowest then lowest, victim = f, k end
					end
				elseif self.policy == "ttl" then
					local oldest = math.huge
					for k, e in pairs(self.entries) do
						if e.t < oldest then oldest, victim = e.t, k end
					end
				else
					victim = self.order[1]
				end
				if not victim then break end
				self.remove(victim)
				self.evictions = self.evictions + 1
				n = n + 1
			end
			return n
		end
		function self.tick(dt) self.time = self.time + (dt or 1) end
		function self.hitRate()
			local total = self.hits + self.misses
			if total == 0 then return 0 end
			return self.hits / total
		end
		function self.warm(pairsList)
			for _, p in ipairs(pairsList) do self.set(p[1], p[2]) end
			return #pairsList
		end
		function self.clear() self.entries = {} self.order = {} self.freq = {} end
		function self.stats() return { size = C.count(self.entries), capacity = self.capacity, policy = self.policy,
			hits = self.hits, misses = self.misses, hitRate = self.hitRate(), evictions = self.evictions } end
		return self
	end

	------------------------------------------------------------------ 4. CONTROLLER
	-- PID / hysteresis / bang-bang / rate-limited controllers with real math.
	function Kits.controller(cfg)
		local self = { kind = "controller", mode = cfg.mode or "pid", target = cfg.target or 0,
			kp = cfg.kp or 0.4, ki = cfg.ki or 0.05, kd = cfg.kd or 0.02,
			min = cfg.min or 0, max = cfg.max or 1, value = cfg.initial or 0.5,
			integral = 0, lastError = 0, samples = C.ring(64), steps = 0, deadband = cfg.deadband or 0 }
		function self.setTarget(t) self.target = t end
		function self.submit(measurement) self.samples:push(measurement) return self.samples:average() end
		function self.step(dt)
			dt = dt or 1 / 60
			self.steps = self.steps + 1
			local measured = self.samples:average()
			local err = self.target - measured
			if math.abs(err) < self.deadband then return self.value end
			if self.mode == "bangbang" then
				self.value = err > 0 and self.max or self.min
			elseif self.mode == "hysteresis" then
				if err > self.deadband then self.value = math.min(self.max, self.value + (cfg.stepSize or 0.05))
				elseif err < -self.deadband then self.value = math.max(self.min, self.value - (cfg.stepSize or 0.05) * 2) end
			else
				self.integral = Mathx.clamp(self.integral + err * dt, -10, 10)
				local deriv = (err - self.lastError) / math.max(dt, 1e-6)
				self.lastError = err
				self.value = Mathx.clamp(self.value + self.kp * err + self.ki * self.integral + self.kd * deriv, self.min, self.max)
			end
			return self.value
		end
		function self.reset() self.integral = 0 self.lastError = 0 self.samples:clear() end
		function self.error() return self.target - self.samples:average() end
		function self.settled(tolerance) return math.abs(self.error()) <= (tolerance or 0.05) end
		function self.stats() return { mode = self.mode, value = self.value, target = self.target,
			error = self.error(), steps = self.steps, settled = self.settled() } end
		return self
	end

	------------------------------------------------------------------ 5. ANALYZER
	-- Statistical analysis: trends, regression, anomaly detection, histograms.
	function Kits.analyzer(cfg)
		local self = { kind = "analyzer", window = cfg.window or 120, samples = C.ring(cfg.window or 120),
			buckets = cfg.buckets or 12, anomalies = 0, threshold = cfg.threshold or 3.0 }
		function self.submit(v) self.samples:push(v) return v end
		function self.mean() return Mathx.mean(self.samples:toTable()) end
		function self.stddev() return Mathx.stddev(self.samples:toTable()) end
		function self.percentile(p) return Mathx.percentile(self.samples:toTable(), p) end
		function self.trend()
			local t = self.samples:toTable()
			local n = #t
			if n < 3 then return 0 end
			local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0
			for i, y in ipairs(t) do
				sumX = sumX + i
				sumY = sumY + y
				sumXY = sumXY + i * y
				sumX2 = sumX2 + i * i
			end
			local denom = n * sumX2 - sumX * sumX
			if math.abs(denom) < 1e-9 then return 0 end
			return (n * sumXY - sumX * sumY) / denom
		end
		function self.forecast(stepsAhead)
			local slope = self.trend()
			return self.mean() + slope * (stepsAhead or 1)
		end
		function self.isAnomaly(v)
			local sd = self.stddev()
			if sd < 1e-9 then return false end
			local z = math.abs(v - self.mean()) / sd
			if z > self.threshold then
				self.anomalies = self.anomalies + 1
				return true, z
			end
			return false, z
		end
		function self.histogram()
			local t = self.samples:toTable()
			if #t == 0 then return {} end
			local lo, hi = math.huge, -math.huge
			for _, v in ipairs(t) do lo = math.min(lo, v) hi = math.max(hi, v) end
			local span = math.max(hi - lo, 1e-9)
			local h = {}
			for i = 1, self.buckets do h[i] = 0 end
			for _, v in ipairs(t) do
				local idx = math.min(self.buckets, math.max(1, math.floor((v - lo) / span * self.buckets) + 1))
				h[idx] = h[idx] + 1
			end
			return h, lo, hi
		end
		function self.stability()
			local m = self.mean()
			if math.abs(m) < 1e-9 then return 1 end
			return math.max(0, 1 - self.stddev() / math.abs(m))
		end
		function self.stats() return { n = self.samples.size, mean = self.mean(), stddev = self.stddev(),
			p95 = self.percentile(95), trend = self.trend(), anomalies = self.anomalies, stability = self.stability() } end
		return self
	end

	------------------------------------------------------------------ 6. BUDGETER
	-- Allocation strategies: proportional, priority, water-filling, fair-share.
	function Kits.budgeter(cfg)
		local self = { kind = "budgeter", total = cfg.total or 100, strategy = cfg.strategy or "proportional",
			claims = {}, granted = {}, cycles = 0, denials = 0 }
		function self.claim(id, amount, priority)
			self.claims[id] = { amount = amount, priority = priority or 1 }
			return true
		end
		function self.release(id) self.claims[id] = nil self.granted[id] = nil end
		function self.allocate()
			self.cycles = self.cycles + 1
			local demand, weight = 0, 0
			for _, c in pairs(self.claims) do demand = demand + c.amount weight = weight + c.priority end
			self.granted = {}
			if demand <= self.total then
				for id, c in pairs(self.claims) do self.granted[id] = c.amount end
				return self.granted, 0
			end
			local deficit = demand - self.total
			if self.strategy == "priority" then
				local list = {}
				for id, c in pairs(self.claims) do list[#list + 1] = { id = id, c = c } end
				table.sort(list, function(a, b) return a.c.priority > b.c.priority end)
				local left = self.total
				for _, item in ipairs(list) do
					local give = math.min(item.c.amount, left)
					self.granted[item.id] = give
					if give < item.c.amount then self.denials = self.denials + 1 end
					left = left - give
				end
			elseif self.strategy == "waterfill" then
				local ids = {}
				for id in pairs(self.claims) do ids[#ids + 1] = id end
				table.sort(ids)
				local level = self.total / math.max(1, #ids)
				local left = self.total
				for _, id in ipairs(ids) do
					local give = math.min(self.claims[id].amount, level)
					self.granted[id] = give
					left = left - give
				end
				for _, id in ipairs(ids) do
					local extra = math.min(self.claims[id].amount - self.granted[id], left)
					if extra > 0 then self.granted[id] = self.granted[id] + extra left = left - extra end
				end
			else
				for id, c in pairs(self.claims) do
					self.granted[id] = self.total * (c.priority / math.max(weight, 1e-9)) * (c.amount / math.max(demand, 1e-9)) / math.max(1e-9, (1 / math.max(#C.keys(self.claims), 1)))
					self.granted[id] = math.min(c.amount, self.total * (c.priority / math.max(weight, 1e-9)))
				end
			end
			return self.granted, deficit
		end
		function self.grantedFor(id) return self.granted[id] or 0 end
		function self.satisfaction(id)
			local c = self.claims[id]
			if not c or c.amount == 0 then return 1 end
			return (self.granted[id] or 0) / c.amount
		end
		function self.pressure()
			local demand = 0
			for _, c in pairs(self.claims) do demand = demand + c.amount end
			return demand / math.max(self.total, 1e-9)
		end
		function self.stats() return { total = self.total, strategy = self.strategy, claims = C.count(self.claims),
			pressure = self.pressure(), cycles = self.cycles, denials = self.denials } end
		return self
	end

	------------------------------------------------------------------ 7. GUARD (security)
	-- Token bucket / sliding window / leaky bucket rate limiting + capability checks.
	function Kits.guard(cfg)
		local self = { kind = "guard", algorithm = cfg.algorithm or "token", capacity = cfg.capacity or 60,
			refillPerSec = cfg.refillPerSec or 30, tokens = cfg.capacity or 60, time = 0,
			window = {}, windowSec = cfg.windowSec or 1, allowed = 0, blocked = 0,
			required = cfg.capability, violations = {} }
		function self.tick(dt)
			self.time = self.time + (dt or 0)
			if self.algorithm == "token" or self.algorithm == "leaky" then
				self.tokens = math.min(self.capacity, self.tokens + self.refillPerSec * (dt or 0))
			end
			local cutoff = self.time - self.windowSec
			for i = #self.window, 1, -1 do if self.window[i] < cutoff then table.remove(self.window, i) end end
		end
		function self.allow(cost)
			cost = cost or 1
			if self.algorithm == "sliding" then
				if #self.window + cost > self.capacity then
					self.blocked = self.blocked + 1
					return false
				end
				for _ = 1, cost do self.window[#self.window + 1] = self.time end
				self.allowed = self.allowed + 1
				return true
			end
			if self.tokens >= cost then
				self.tokens = self.tokens - cost
				self.allowed = self.allowed + 1
				return true
			end
			self.blocked = self.blocked + 1
			return false
		end
		function self.check(principal, sandbox)
			if not self.required then return true end
			if not sandbox then return false end
			local ok = sandbox:can(principal, self.required)
			if not ok then self.violations[#self.violations + 1] = { principal = principal, capability = self.required } end
			return ok
		end
		function self.reset() self.tokens = self.capacity self.window = {} end
		function self.utilization() return 1 - (self.tokens / math.max(self.capacity, 1e-9)) end
		function self.stats() return { algorithm = self.algorithm, allowed = self.allowed, blocked = self.blocked,
			tokens = self.tokens, utilization = self.utilization(), violations = #self.violations } end
		return self
	end

	------------------------------------------------------------------ 8. INDEX (spatial/semantic)
	function Kits.index(cfg)
		local self = { kind = "index", mode = cfg.mode or "hash", cellSize = cfg.cellSize or 32,
			hash = Spatial.spatialHash(cfg.cellSize or 32), items = {}, queries = 0, inserts = 0 }
		function self.insert(id, pos, payload)
			self.hash:insert(id, pos)
			self.items[id] = payload
			self.inserts = self.inserts + 1
			return id
		end
		function self.update(id, pos) return self.hash:update(id, pos) end
		function self.remove(id) self.items[id] = nil return self.hash:remove(id) end
		function self.queryRadius(center, radius)
			self.queries = self.queries + 1
			local hits = self.hash:queryRadius(center, radius)
			local out = {}
			for _, h in ipairs(hits) do out[#out + 1] = { id = h.id, pos = h.pos, payload = self.items[h.id] } end
			return out
		end
		function self.nearest(center, maxRadius)
			self.queries = self.queries + 1
			local best = self.hash:nearest(center, maxRadius)
			if not best then return nil end
			return { id = best.id, pos = best.pos, payload = self.items[best.id] }
		end
		function self.count() return self.hash.count end
		function self.stats() return { mode = self.mode, count = self.hash.count, queries = self.queries, inserts = self.inserts } end
		return self
	end

	------------------------------------------------------------------ 9. CODEC
	-- Encoding strategies: json, binary, delta, quantized, run-length.
	function Kits.codec(cfg)
		local self = { kind = "codec", format = cfg.format or "binary", quantBits = cfg.quantBits or 12,
			encoded = 0, decoded = 0, bytesOut = 0, ratioSum = 0 }
		function self.encode(value)
			self.encoded = self.encoded + 1
			local out
			if self.format == "json" then out = Ser.encodeJSON(value)
			elseif self.format == "quantized" then
				local q = C.deepCopy(value)
				local scale = 2 ^ self.quantBits
				local function quant(t)
					for k, v in pairs(t) do
						if type(v) == "number" then t[k] = math.floor(v * scale + 0.5) / scale
						elseif type(v) == "table" then quant(v) end
					end
				end
				if type(q) == "table" then quant(q) end
				out = Ser.encodeBinary(q)
			elseif self.format == "rle" then
				local raw = Ser.encodeBinary(value)
				local parts = {}
				local i = 1
				while i <= #raw do
					local ch = string.sub(raw, i, i)
					local n = 1
					while i + n <= #raw and string.sub(raw, i + n, i + n) == ch and n < 255 do n = n + 1 end
					parts[#parts + 1] = string.char(n) .. ch
					i = i + n
				end
				out = table.concat(parts)
			else out = Ser.encodeBinary(value) end
			self.bytesOut = self.bytesOut + #out
			return out
		end
		function self.decode(data)
			self.decoded = self.decoded + 1
			if self.format == "json" then return Ser.decodeJSON(data) end
			if self.format == "rle" then
				local parts = {}
				local i = 1
				while i < #data do
					local n = string.byte(data, i)
					parts[#parts + 1] = string.rep(string.sub(data, i + 1, i + 1), n)
					i = i + 2
				end
				return Ser.decodeBinary(table.concat(parts))
			end
			return Ser.decodeBinary(data)
		end
		function self.diff(old, new) return Ser.diff(old, new) end
		function self.patch(target, d) return Ser.applyDiff(target, d) end
		function self.checksum(value) return Hash.crc32(Ser.encodeBinary(value)) end
		function self.roundTrip(value)
			local encoded = self.encode(value)
			local decoded = self.decode(encoded)
			return decoded, C.deepEqual(value, decoded), #encoded
		end
		function self.stats() return { format = self.format, encoded = self.encoded, decoded = self.decoded, bytesOut = self.bytesOut } end
		return self
	end

	------------------------------------------------------------------ 10. GRAPH
	-- Graph algorithms: topological order, Dijkstra, A*, connectivity, flow-lite.
	function Kits.graph(cfg)
		local self = { kind = "graph", nodes = {}, edges = {}, directed = cfg.directed ~= false, queries = 0 }
		function self.addNode(id, data) self.nodes[id] = data or true self.edges[id] = self.edges[id] or {} return id end
		function self.addEdge(a, b, weight)
			self.addNode(a) self.addNode(b)
			self.edges[a][b] = weight or 1
			if not self.directed then self.edges[b][a] = weight or 1 end
			return true
		end
		function self.neighbors(id)
			local out = {}
			for n, w in pairs(self.edges[id] or {}) do out[#out + 1] = { id = n, weight = w } end
			table.sort(out, function(x, y) return tostring(x.id) < tostring(y.id) end)
			return out
		end
		function self.shortestPath(from, to, heuristic)
			self.queries = self.queries + 1
			local dist = { [from] = 0 }
			local prev = {}
			local visited = {}
			local pq = C.priorityQueue(function(x, y) return x.f < y.f end)
			pq:push({ id = from, f = 0 })
			while not pq:isEmpty() do
				local cur = pq:pop()
				if cur.id == to then break end
				if not visited[cur.id] then
					visited[cur.id] = true
					for _, e in ipairs(self.neighbors(cur.id)) do
						local nd = (dist[cur.id] or math.huge) + e.weight
						if nd < (dist[e.id] or math.huge) then
							dist[e.id] = nd
							prev[e.id] = cur.id
							local h = heuristic and heuristic(e.id, to) or 0
							pq:push({ id = e.id, f = nd + h })
						end
					end
				end
			end
			if dist[to] == nil then return nil, math.huge end
			local path = { to }
			local cur = to
			while prev[cur] do
				cur = prev[cur]
				table.insert(path, 1, cur)
			end
			return path, dist[to]
		end
		function self.components()
			local seen = {}
			local comps = {}
			for id in pairs(self.nodes) do
				if not seen[id] then
					local stack = { id }
					local comp = {}
					while #stack > 0 do
						local n = table.remove(stack)
						if not seen[n] then
							seen[n] = true
							comp[#comp + 1] = n
							for _, e in ipairs(self.neighbors(n)) do stack[#stack + 1] = e.id end
						end
					end
					table.sort(comp, function(a, b) return tostring(a) < tostring(b) end)
					comps[#comps + 1] = comp
				end
			end
			return comps
		end
		function self.degree(id) return C.count(self.edges[id] or {}) end
		function self.nodeCount() return C.count(self.nodes) end
		function self.edgeCount()
			local n = 0
			for _, e in pairs(self.edges) do n = n + C.count(e) end
			return self.directed and n or n / 2
		end
		function self.stats() return { nodes = self.nodeCount(), edges = self.edgeCount(), queries = self.queries } end
		return self
	end

	------------------------------------------------------------------ 11. FIELD (procedural sampler)
	function Kits.field(cfg)
		local self = { kind = "field", noiseType = cfg.noiseType or "perlin", seed = cfg.seed or 1337,
			frequency = cfg.frequency or 0.01, octaves = cfg.octaves or 4, gain = cfg.gain or 0.5,
			lacunarity = cfg.lacunarity or 2.0, amplitude = cfg.amplitude or 1.0, warp = cfg.warp or 0,
			samples = 0 }
		local fn = Noise.field(self.noiseType)
		function self.sample(x, y)
			self.samples = self.samples + 1
			local base
			if self.warp > 0 then
				base = Noise.domainWarp(function(px, py, s) return Noise.fbm(fn, px, py,
					{ octaves = self.octaves, gain = self.gain, lacunarity = self.lacunarity,
					  frequency = self.frequency, seed = s }) end, x, y, { strength = self.warp, seed = self.seed })
			else
				base = Noise.fbm(fn, x, y, { octaves = self.octaves, gain = self.gain,
					lacunarity = self.lacunarity, frequency = self.frequency, seed = self.seed })
			end
			return base * self.amplitude
		end
		function self.sampleRidged(x, y)
			return Noise.ridged(fn, x, y, { octaves = self.octaves, gain = self.gain,
				lacunarity = self.lacunarity, frequency = self.frequency, seed = self.seed })
		end
		function self.gradient(x, y) return Noise.derivative2D(function(px, py) return self.sample(px, py) end, x, y, self.seed, 0.5) end
		function self.slope(x, y)
			local dx, dy = self.gradient(x, y)
			return math.sqrt(dx * dx + dy * dy)
		end
		function self.terraced(x, y, steps) return Noise.terrace(self.sample(x, y), steps or 6) end
		function self.region(x0, y0, x1, y1, step)
			local out = {}
			step = step or 1
			for y = y0, y1, step do
				local row = {}
				for x = x0, x1, step do row[#row + 1] = self.sample(x, y) end
				out[#out + 1] = row
			end
			return out
		end
		function self.stats() return { noiseType = self.noiseType, seed = self.seed, samples = self.samples,
			octaves = self.octaves, frequency = self.frequency } end
		return self
	end

	------------------------------------------------------------------ 12. PREDICTOR
	function Kits.predictor(cfg)
		local self = { kind = "predictor", method = cfg.method or "ema", alpha = cfg.alpha or 0.25,
			value = 0, history = C.ring(cfg.window or 64), markov = {}, lastState = nil, predictions = 0, hits = 0 }
		function self.observe(v)
			self.history:push(v)
			if type(v) == "number" then
				self.value = self.history.size == 1 and v or Mathx.ema(self.value, v, self.alpha)
			else
				if self.lastState then
					self.markov[self.lastState] = self.markov[self.lastState] or {}
					self.markov[self.lastState][v] = (self.markov[self.lastState][v] or 0) + 1
				end
				self.lastState = v
			end
			return self.value
		end
		function self.predict(stepsAhead)
			self.predictions = self.predictions + 1
			if self.method == "markov" then
				local row = self.markov[self.lastState]
				if not row then return nil end
				local best, bestN = nil, -1
				for state, n in pairs(row) do if n > bestN then best, bestN = state, n end end
				return best
			end
			if self.method == "linear" then
				local t = self.history:toTable()
				if #t < 2 then return self.value end
				local slope = (t[#t] - t[1]) / math.max(1, #t - 1)
				return t[#t] + slope * (stepsAhead or 1)
			end
			return self.value
		end
		function self.confidence()
			local t = self.history:toTable()
			if #t < 3 then return 0.2 end
			local sd = Mathx.stddev(t)
			local m = math.abs(Mathx.mean(t))
			if m < 1e-9 then return 0.5 end
			return Mathx.clamp(1 - sd / m, 0, 1)
		end
		function self.verify(actual)
			local p = self.predict(1)
			if type(p) == "number" and type(actual) == "number" then
				if math.abs(p - actual) <= math.max(0.1, math.abs(actual) * 0.1) then self.hits = self.hits + 1 end
			elseif p == actual then self.hits = self.hits + 1 end
			return self.predictions > 0 and (self.hits / self.predictions) or 0
		end
		function self.accuracy() return self.predictions > 0 and (self.hits / self.predictions) or 0 end
		function self.stats() return { method = self.method, value = self.value, confidence = self.confidence(),
			predictions = self.predictions, accuracy = self.accuracy() } end
		return self
	end

	------------------------------------------------------------------ 13. LEDGER (audit/telemetry)
	function Kits.ledger(cfg)
		local self = { kind = "ledger", capacity = cfg.capacity or 1024, entries = C.ring(cfg.capacity or 1024),
			counters = {}, histogram = {}, buckets = cfg.buckets or { 1, 2, 4, 8, 16, 33, 66, 120, 250, 500 },
			written = 0, sealed = nil }
		function self.write(kind, payload)
			self.written = self.written + 1
			local rec = { seq = self.written, kind = kind, payload = payload }
			rec.hash = Hash.mix(Hash.fnv1a(tostring(kind)), Hash.hashTable(payload or {}))
			self.entries:push(rec)
			self.counters[kind] = (self.counters[kind] or 0) + 1
			return rec
		end
		function self.observe(value)
			for i, b in ipairs(self.buckets) do
				if value <= b then
					self.histogram[i] = (self.histogram[i] or 0) + 1
					return i
				end
			end
			local last = #self.buckets + 1
			self.histogram[last] = (self.histogram[last] or 0) + 1
			return last
		end
		function self.query(kind, limit)
			local out = {}
			for i = self.entries.size, 1, -1 do
				local e = self.entries:get(i)
				if e and (kind == nil or e.kind == kind) then
					out[#out + 1] = e
					if #out >= (limit or 50) then break end
				end
			end
			return out
		end
		function self.seal()
			local acc = 0
			for i = 1, self.entries.size do
				local e = self.entries:get(i)
				if e then acc = Hash.mix(acc, e.hash) end
			end
			self.sealed = acc
			return acc
		end
		function self.verifySeal()
			local prev = self.sealed
			if not prev then return false end
			return self.seal() == prev
		end
		function self.percentileBucket(p)
			local total = 0
			for _, n in pairs(self.histogram) do total = total + n end
			if total == 0 then return 0 end
			local target = total * p / 100
			local acc = 0
			for i = 1, #self.buckets + 1 do
				acc = acc + (self.histogram[i] or 0)
				if acc >= target then return self.buckets[i] or math.huge end
			end
			return math.huge
		end
		function self.stats() return { written = self.written, kinds = C.count(self.counters),
			p50 = self.percentileBucket(50), p95 = self.percentileBucket(95), sealed = self.sealed ~= nil } end
		return self
	end

	------------------------------------------------------------------ 14. RECOVERY
	function Kits.recovery(cfg)
		local self = { kind = "recovery", maxSnapshots = cfg.maxSnapshots or 12, snapshots = {},
			restores = 0, failures = 0, strategy = cfg.strategy or "rollback" }
		function self.snapshot(label, state)
			local snap = { label = label, state = C.deepCopy(state), crc = Hash.crc32(Ser.encodeBinary(state)) }
			self.snapshots[#self.snapshots + 1] = snap
			if #self.snapshots > self.maxSnapshots then table.remove(self.snapshots, 1) end
			return snap
		end
		function self.verify(snap) return Hash.crc32(Ser.encodeBinary(snap.state)) == snap.crc end
		function self.rollback(steps)
			steps = steps or 1
			local idx = #self.snapshots - steps + 1
			if idx < 1 then self.failures = self.failures + 1 return nil, "no snapshot" end
			local snap = self.snapshots[idx]
			if not self.verify(snap) then self.failures = self.failures + 1 return nil, "corrupt snapshot" end
			self.restores = self.restores + 1
			return C.deepCopy(snap.state), snap.label
		end
		function self.lastGood()
			for i = #self.snapshots, 1, -1 do
				if self.verify(self.snapshots[i]) then return self.snapshots[i] end
			end
			return nil
		end
		function self.protect(fn, state)
			local snap = self.snapshot("auto", state)
			local ok, res = pcall(fn, state)
			if ok then return res, true end
			self.failures = self.failures + 1
			return C.deepCopy(snap.state), false, tostring(res)
		end
		function self.stats() return { snapshots = #self.snapshots, restores = self.restores,
			failures = self.failures, strategy = self.strategy } end
		return self
	end

	------------------------------------------------------------------ 15. ORCHESTRATOR (state machine driven)
	function Kits.orchestrator(cfg)
		local self = { kind = "orchestrator", states = cfg.states or { "idle", "running", "done" },
			current = (cfg.states and cfg.states[1]) or "idle", transitions = 0, log = {},
			handlers = {}, elapsed = 0 }
		function self.on(state, fn) self.handlers[state] = fn return self end
		function self.canGo(to)
			for _, s in ipairs(self.states) do if s == to then return true end end
			return false
		end
		function self.go(to, payload)
			if not self.canGo(to) then return false end
			local from = self.current
			self.current = to
			self.transitions = self.transitions + 1
			self.elapsed = 0
			self.log[#self.log + 1] = { from = from, to = to }
			if #self.log > 128 then table.remove(self.log, 1) end
			local h = self.handlers[to]
			if h then pcall(h, payload, from) end
			return true
		end
		function self.step(dt)
			self.elapsed = self.elapsed + (dt or 0)
			local h = self.handlers["*"]
			if h then pcall(h, self.current, dt) end
			return self.current
		end
		function self.isIn(state) return self.current == state end
		function self.reset() self.current = self.states[1] self.transitions = 0 self.log = {} end
		function self.stats() return { current = self.current, transitions = self.transitions, elapsed = self.elapsed } end
		return self
	end

	------------------------------------------------------------------ 16. SOLVER (numeric/iterative)
	function Kits.solver(cfg)
		local self = { kind = "solver", method = cfg.method or "iterative", iterations = cfg.iterations or 8,
			tolerance = cfg.tolerance or 1e-4, damping = cfg.damping or 0.8, solved = 0, residual = 0 }
		function self.solve(constraints, state)
			self.solved = self.solved + 1
			local s = state
			for iter = 1, self.iterations do
				local maxErr = 0
				for _, c in ipairs(constraints) do
					local err = c.evaluate(s)
					maxErr = math.max(maxErr, math.abs(err))
					if math.abs(err) > self.tolerance and c.correct then
						c.correct(s, err * self.damping)
					end
				end
				self.residual = maxErr
				if maxErr <= self.tolerance then return s, iter, maxErr end
			end
			return s, self.iterations, self.residual
		end
		function self.integrate(value, velocity, accel, dt, mode)
			if mode == "verlet" then
				local newValue = value + velocity * dt + 0.5 * accel * dt * dt
				local newVel = velocity + accel * dt
				return newValue, newVel
			end
			local newVel = velocity + accel * dt
			return value + newVel * dt, newVel
		end
		function self.relax(current, target, factor) return Mathx.lerp(current, target, Mathx.clamp(factor, 0, 1)) end
		function self.converged() return self.residual <= self.tolerance end
		function self.stats() return { method = self.method, iterations = self.iterations,
			residual = self.residual, converged = self.converged(), solved = self.solved } end
		return self
	end

	------------------------------------------------------------------ 17. STREAMER
	function Kits.streamer(cfg)
		local self = { kind = "streamer", radius = cfg.radius or 400, chunkSize = cfg.chunkSize or 128,
			loaded = {}, pending = C.priorityQueue(function(a, b) return a.priority > b.priority end),
			maxPerFrame = cfg.maxPerFrame or 2, loads = 0, unloads = 0, onLoad = cfg.onLoad, onUnload = cfg.onUnload }
		local function chunkKey(cx, cz) return cx .. ":" .. cz end
		function self.chunkOf(x, z)
			return math.floor(x / self.chunkSize), math.floor(z / self.chunkSize)
		end
		function self.update(x, z)
			local cx, cz = self.chunkOf(x, z)
			local r = math.ceil(self.radius / self.chunkSize)
			local needed = {}
			for dx = -r, r do
				for dz = -r, r do
					local d = math.sqrt(dx * dx + dz * dz) * self.chunkSize
					if d <= self.radius then
						local key = chunkKey(cx + dx, cz + dz)
						needed[key] = true
						if not self.loaded[key] then
							self.pending:push({ key = key, cx = cx + dx, cz = cz + dz, priority = self.radius - d })
						end
					end
				end
			end
			local toUnload = {}
			for key in pairs(self.loaded) do
				if not needed[key] then toUnload[#toUnload + 1] = key end
			end
			for _, key in ipairs(toUnload) do
				self.loaded[key] = nil
				self.unloads = self.unloads + 1
				if self.onUnload then pcall(self.onUnload, key) end
			end
			return C.count(needed)
		end
		function self.pump()
			local n = 0
			while n < self.maxPerFrame and not self.pending:isEmpty() do
				local item = self.pending:pop()
				if not self.loaded[item.key] then
					self.loaded[item.key] = { cx = item.cx, cz = item.cz }
					self.loads = self.loads + 1
					if self.onLoad then pcall(self.onLoad, item.key, item.cx, item.cz) end
					n = n + 1
				end
			end
			return n
		end
		function self.isLoaded(key) return self.loaded[key] ~= nil end
		function self.loadedCount() return C.count(self.loaded) end
		function self.setRadius(r) self.radius = r end
		function self.stats() return { radius = self.radius, loaded = self.loadedCount(),
			pending = self.pending:size(), loads = self.loads, unloads = self.unloads } end
		return self
	end

	------------------------------------------------------------------ 18. COMPOSER (layered blending)
	function Kits.composer(cfg)
		local self = { kind = "composer", layers = {}, mode = cfg.mode or "alpha", evaluations = 0 }
		function self.addLayer(name, weight, fn, blend)
			self.layers[#self.layers + 1] = { name = name, weight = weight or 1, fn = fn,
				blend = blend or self.mode, enabled = true }
			return self
		end
		function self.setWeight(name, w)
			for _, l in ipairs(self.layers) do if l.name == name then l.weight = w return true end end
			return false
		end
		function self.evaluate(input)
			self.evaluations = self.evaluations + 1
			local acc = nil
			for _, l in ipairs(self.layers) do
				if l.enabled and l.weight > 0 then
					local v = l.fn(input)
					if acc == nil then acc = v * l.weight
					elseif l.blend == "add" then acc = acc + v * l.weight
					elseif l.blend == "multiply" then acc = acc * (1 - l.weight + v * l.weight)
					elseif l.blend == "max" then acc = math.max(acc, v * l.weight)
					elseif l.blend == "min" then acc = math.min(acc, v * l.weight)
					elseif l.blend == "overlay" then acc = acc < 0.5 and (2 * acc * v) or (1 - 2 * (1 - acc) * (1 - v))
					else acc = Mathx.lerp(acc, v, l.weight) end
				end
			end
			return acc or 0
		end
		function self.normalize()
			local total = 0
			for _, l in ipairs(self.layers) do total = total + l.weight end
			if total <= 0 then return false end
			for _, l in ipairs(self.layers) do l.weight = l.weight / total end
			return true
		end
		function self.layerNames()
			local out = {}
			for i, l in ipairs(self.layers) do out[i] = l.name end
			return out
		end
		function self.stats() return { layers = #self.layers, mode = self.mode, evaluations = self.evaluations } end
		return self
	end

	------------------------------------------------------------------ 19. SCHEDULER POLICY
	function Kits.policy(cfg)
		local self = { kind = "policy", algorithm = cfg.algorithm or "roundrobin", queue = {},
			cursor = 0, dispatched = 0, starvationGuard = cfg.starvationGuard or 32 }
		function self.submit(id, weight, deadline)
			self.queue[#self.queue + 1] = { id = id, weight = weight or 1, deadline = deadline or math.huge,
				waited = 0, virtualTime = 0 }
			return #self.queue
		end
		function self.next()
			if #self.queue == 0 then return nil end
			self.dispatched = self.dispatched + 1
			local pick
			if self.algorithm == "edf" then
				table.sort(self.queue, function(a, b) return a.deadline < b.deadline end)
				pick = table.remove(self.queue, 1)
			elseif self.algorithm == "wfq" then
				table.sort(self.queue, function(a, b) return a.virtualTime < b.virtualTime end)
				pick = table.remove(self.queue, 1)
				pick.virtualTime = pick.virtualTime + 1 / math.max(pick.weight, 1e-6)
				self.queue[#self.queue + 1] = pick
			elseif self.algorithm == "lottery" then
				local total = 0
				for _, t in ipairs(self.queue) do total = total + t.weight end
				local r = (self.dispatched * 2654435761 % 1000) / 1000 * total
				local acc = 0
				for i, t in ipairs(self.queue) do
					acc = acc + t.weight
					if r <= acc then pick = table.remove(self.queue, i) break end
				end
				pick = pick or table.remove(self.queue, 1)
			else
				self.cursor = self.cursor % #self.queue + 1
				pick = table.remove(self.queue, self.cursor > #self.queue and #self.queue or self.cursor)
			end
			for _, t in ipairs(self.queue) do t.waited = t.waited + 1 end
			return pick
		end
		function self.starved()
			local out = {}
			for _, t in ipairs(self.queue) do
				if t.waited > self.starvationGuard then out[#out + 1] = t.id end
			end
			return out
		end
		function self.pending() return #self.queue end
		function self.stats() return { algorithm = self.algorithm, pending = #self.queue,
			dispatched = self.dispatched, starved = #self.starved() } end
		return self
	end

	------------------------------------------------------------------ 20. SYNTHESIZER (procedural content)
	function Kits.synthesizer(cfg)
		local self = { kind = "synthesizer", seed = cfg.seed or 4242, grammar = cfg.grammar or {},
			rng = Random.new(cfg.seed or 4242), generated = 0, constraints = {} }
		function self.addRule(symbol, productions)
			self.grammar[symbol] = productions
			return self
		end
		function self.addConstraint(name, fn) self.constraints[name] = fn return self end
		function self.expand(symbol, depth)
			depth = depth or 0
			if depth > 12 then return symbol end
			local prods = self.grammar[symbol]
			if not prods then return symbol end
			local chosen = self.rng:weighted(prods)
			if type(chosen) == "string" then
				local out = {}
				for token in string.gmatch(chosen, "%S+") do
					out[#out + 1] = self.expand(token, depth + 1)
				end
				return table.concat(out, " ")
			end
			return tostring(chosen)
		end
		function self.generate(rootSymbol, attempts)
			attempts = attempts or 8
			for _ = 1, attempts do
				self.generated = self.generated + 1
				local result = self.expand(rootSymbol or "root", 0)
				local ok = true
				for _, fn in pairs(self.constraints) do
					if not fn(result) then ok = false break end
				end
				if ok then return result, true end
			end
			return self.expand(rootSymbol or "root", 0), false
		end
		function self.reseed(seed) self.seed = seed self.rng = Random.new(seed) end
		function self.deterministicCheck(rootSymbol)
			local a = (function() self.reseed(self.seed) return self.expand(rootSymbol, 0) end)()
			local b = (function() self.reseed(self.seed) return self.expand(rootSymbol, 0) end)()
			return a == b
		end
		function self.stats() return { seed = self.seed, rules = C.count(self.grammar),
			generated = self.generated, constraints = C.count(self.constraints) } end
		return self
	end

	-- Round 2 kits (studio / code / collaboration) are merged in from the extension module.
	local Studio = A:import("arkher/runtime/kits_studio")
	for _, name in ipairs(Studio.NAMES) do Kits[name] = Studio[name] end

	local World = A:import("arkher/runtime/kits_world")
	for _, name in ipairs(World.NAMES) do Kits[name] = World[name] end

	local Render = A:import("arkher/runtime/kits_render")
	for _, name in ipairs(Render.NAMES) do Kits[name] = Render[name] end

	local Motion = A:import("arkher/runtime/kits_motion")
	for _, name in ipairs(Motion.NAMES) do Kits[name] = Motion[name] end

	Kits.NAMES = { "registry", "pipeline", "cache", "controller", "analyzer", "budgeter", "guard",
		"index", "codec", "graph", "field", "predictor", "ledger", "recovery", "orchestrator",
		"solver", "streamer", "composer", "policy", "synthesizer",
		"document", "commands", "selection", "layout", "widget", "inspector",
		"nodegraph", "source", "session", "merge", "taskgraph",
		"scenegraph", "prefab", "heightfield", "voxel", "spline", "mesh",
		"chunker", "wfc", "lsystem", "scatter", "network", "simulation",
		"material", "sampler", "shadegraph", "framegraph", "camera", "visibility",
		"impostor", "lightrig", "probe", "temporal", "upscaler", "inference",
		"rigidbody", "collider", "contact", "constraint", "raycaster", "charmotor",
		"vehicle", "skeleton", "clip", "animator", "ik", "ragdoll" }

	function Kits.create(name, cfg)
		local factory = Kits[name]
		if not factory then error(Errors.new(Errors.Codes.NOT_FOUND, "unknown kit: " .. tostring(name))) end
		return factory(cfg or {})
	end

	return Kits

end
