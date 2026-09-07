-- ARKHER RUNTIME :: Original Technology Kits
-- Round 8 machinery (kits 109-115). The technologies that exist only in ARKHER: a layered
-- reality, a complexity manager that spends the frame on purpose, a fabric that steps
-- every simulation domain under one clock, a project that analyses and repairs itself,
-- a world that remembers, a detector for emergent behaviour, and the world architect.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Hash = A:import("arkher/kernel/hash")
	local Random = A:import("arkher/kernel/random")

	local K = {}
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 109. REALITY
	-- The Reality Layer: the world is not one state but a stack of them - the authored
	-- base, what the simulation has done since, what the AI proposes, and what the player
	-- has overridden. Reads resolve top-down by priority; writes go to a named layer;
	-- proposals can be committed or discarded without touching the truth underneath.
	function K.reality(cfg)
		local self = { kind = "reality", id = cfg.id, layers = {}, order = {},
			reads = 0, writes = 0, commits = 0, discards = 0, conflicts = 0 }

		function self.addLayer(name, opts)
			opts = opts or {}
			if self.layers[name] then return false end
			self.layers[name] = { name = name, priority = opts.priority or #self.order,
				values = {}, enabled = opts.enabled ~= false, blend = opts.blend or 1,
				volatile = opts.volatile or false, writes = 0 }
			self.order[#self.order + 1] = name
			table.sort(self.order, function(a, b)
				return self.layers[a].priority < self.layers[b].priority
			end)
			return true
		end

		function self.installStack()
			if #self.order > 0 then return #self.order end
			self.addLayer("authored", { priority = 0 })
			self.addLayer("simulated", { priority = 1 })
			self.addLayer("proposed", { priority = 2, volatile = true })
			self.addLayer("player", { priority = 3 })
			return #self.order
		end

		function self.set(layer, key, value)
			local l = self.layers[layer]
			if not l then return false end
			if l.values[key] ~= nil and l.values[key] ~= value then
				self.conflicts = self.conflicts + 1
			end
			l.values[key] = value
			l.writes = l.writes + 1
			self.writes = self.writes + 1
			return true
		end

		function self.get(key)
			self.reads = self.reads + 1
			local value, from = nil, nil
			for _, name in ipairs(self.order) do
				local l = self.layers[name]
				if l.enabled and l.values[key] ~= nil then
					if value == nil or l.blend >= 1 or type(value) ~= "number" then
						value, from = l.values[key], name
					else
						value = Mathx.lerp(value, l.values[key], l.blend)
						from = name
					end
				end
			end
			return value, from
		end

		function self.setEnabled(layer, on)
			local l = self.layers[layer]
			if not l then return false end
			l.enabled = on and true or false
			return l.enabled
		end

		function self.setBlend(layer, blend)
			local l = self.layers[layer]
			if not l then return false end
			l.blend = clamp01(blend)
			return l.blend
		end

		-- Fold a volatile layer down into a durable one: this is how a proposal becomes real.
		function self.commit(fromLayer, intoLayer)
			local from, into = self.layers[fromLayer], self.layers[intoLayer]
			if not from or not into then return 0 end
			local moved = 0
			for key, value in pairs(from.values) do
				into.values[key] = value
				moved = moved + 1
			end
			from.values = {}
			self.commits = self.commits + 1
			return moved
		end

		function self.discard(layer)
			local l = self.layers[layer]
			if not l then return 0 end
			local n = C.count(l.values)
			l.values = {}
			self.discards = self.discards + 1
			return n
		end

		function self.keys()
			local seen, out = {}, {}
			for _, name in ipairs(self.order) do
				for key in pairs(self.layers[name].values) do
					if not seen[key] then seen[key] = true out[#out + 1] = key end
				end
			end
			table.sort(out)
			return out
		end

		function self.snapshot()
			local out = {}
			for _, key in ipairs(self.keys()) do out[key] = self.get(key) end
			return out
		end

		-- How far a layer has pulled reality away from the authored truth.
		function self.divergence(baseLayer)
			local base = self.layers[baseLayer or self.order[1]]
			if not base then return 0 end
			local total, counted = 0, 0
			for key, value in pairs(base.values) do
				local resolved = self.get(key)
				if type(value) == "number" and type(resolved) == "number" then
					local scale = math.max(1e-6, math.abs(value))
					total = total + math.abs(resolved - value) / scale
					counted = counted + 1
				elseif resolved ~= value then
					total = total + 1
					counted = counted + 1
				end
			end
			if counted == 0 then return 0 end
			return total / counted
		end

		function self.stats() return { layers = #self.order, keys = #self.keys(),
			reads = self.reads, writes = self.writes, commits = self.commits,
			discards = self.discards, conflicts = self.conflicts } end
		return self
	end

	------------------------------------------------------------------ 110. COMPLEXITY
	-- The Dynamic Complexity Manager: it measures what a zone actually costs (objects,
	-- agents, lights, effects, each with a measured weight), compares that to the frame
	-- the device can afford, and issues per-subsystem directives that add up to the
	-- budget instead of hoping each subsystem behaves.
	function K.complexity(cfg)
		local self = { kind = "complexity", id = cfg.id, zones = {}, order = {},
			weights = cfg.weights or { objects = 0.02, agents = 0.12, lights = 0.08,
				effects = 0.15, terrain = 0.05, ui = 0.03 },
			targetMs = cfg.targetMs or 16.6, directives = {}, evaluations = 0,
			overBudget = 0, lastCost = 0 }

		function self.addZone(id, counts)
			if self.zones[id] then return false end
			self.zones[id] = { id = id, counts = counts or {}, importance = 1, cost = 0 }
			self.order[#self.order + 1] = id
			return true
		end

		function self.setCounts(id, counts)
			local zone = self.zones[id]
			if not zone then return false end
			for key, value in pairs(counts) do zone.counts[key] = value end
			return true
		end

		function self.setImportance(id, importance)
			local zone = self.zones[id]
			if not zone then return false end
			zone.importance = math.max(0, importance)
			return zone.importance
		end

		function self.costOf(id)
			local zone = self.zones[id]
			if not zone then return 0 end
			local cost = 0
			for key, count in pairs(zone.counts) do
				cost = cost + count * (self.weights[key] or 0.01)
			end
			zone.cost = cost
			return cost
		end

		function self.totalCost()
			local total = 0
			for _, id in ipairs(self.order) do total = total + self.costOf(id) end
			self.lastCost = total
			return total
		end

		function self.pressure()
			return self.totalCost() / math.max(1e-6, self.targetMs)
		end

		function self.classify(id)
			local cost = self.costOf(id)
			local share = cost / math.max(1e-6, self.targetMs)
			if share > 0.6 then return "critical" end
			if share > 0.3 then return "heavy" end
			if share > 0.1 then return "moderate" end
			return "light"
		end

		-- Directives: how much of each subsystem's work survives this frame. Important
		-- zones lose the least; the cuts always add up to the budget.
		function self.evaluate()
			self.evaluations = self.evaluations + 1
			local total = self.totalCost()
			local pressure = total / math.max(1e-6, self.targetMs)
			self.directives = {}
			if pressure > 1 then self.overBudget = self.overBudget + 1 end
			local scale = pressure > 1 and (1 / pressure) or 1
			local importanceTotal = 0
			for _, id in ipairs(self.order) do
				importanceTotal = importanceTotal + self.zones[id].importance
			end
			for _, id in ipairs(self.order) do
				local zone = self.zones[id]
				local share = importanceTotal > 0 and zone.importance / importanceTotal or 1
				local zoneScale = clamp01(scale * (0.5 + share * #self.order * 0.5))
				local directive = { zone = id, quality = zoneScale, class = self.classify(id) }
				for key, count in pairs(zone.counts) do
					directive[key] = math.max(0, math.floor(count * zoneScale))
				end
				self.directives[id] = directive
			end
			return { pressure = pressure, cost = total, scale = scale,
				directives = self.directives }
		end

		function self.directiveFor(id)
			if not self.directives[id] then self.evaluate() end
			return self.directives[id]
		end

		function self.heaviest()
			local worst, worstCost = nil, -1
			for _, id in ipairs(self.order) do
				local cost = self.costOf(id)
				if cost > worstCost then worstCost = cost worst = id end
			end
			return worst, worstCost
		end

		function self.setTarget(ms)
			self.targetMs = math.max(1, ms)
			return self.targetMs
		end

		function self.stats() return { zones = #self.order, cost = self.lastCost,
			targetMs = self.targetMs, evaluations = self.evaluations,
			overBudget = self.overBudget, pressure = self.lastCost / math.max(1e-6, self.targetMs) } end
		return self
	end

	------------------------------------------------------------------ 111. FABRIC
	-- The Universal Simulation Fabric: every domain (physics, ecology, economy, weather,
	-- traffic...) registers its own tick rate and cost. The fabric owns one clock, steps
	-- each domain when its period elapses, spends only the frame budget it has, carries
	-- debt forward, and never lets a starved domain wait forever.
	function K.fabric(cfg)
		local self = { kind = "fabric", id = cfg.id, domains = {}, order = {},
			channels = {}, time = 0, frames = 0, budgetMs = cfg.budgetMs or 8,
			spent = 0, deferred = 0, steps = 0, starvationLimit = cfg.starvationLimit or 8,
			messages = 0 }

		function self.addDomain(id, opts)
			opts = opts or {}
			if self.domains[id] then return false end
			local domain = { id = id, hz = opts.hz or 10, cost = opts.cost or 1,
				priority = opts.priority or 1, step = opts.step, accumulator = 0,
				steps = 0, skipped = 0, lastTime = 0, enabled = true }
			domain.period = 1 / math.max(0.01, domain.hz)
			self.domains[id] = domain
			self.order[#self.order + 1] = id
			return domain
		end

		function self.setRate(id, hz)
			local domain = self.domains[id]
			if not domain then return false end
			domain.hz = math.max(0.01, hz)
			domain.period = 1 / domain.hz
			return domain.hz
		end

		function self.setEnabled(id, on)
			local domain = self.domains[id]
			if not domain then return false end
			domain.enabled = on and true or false
			return domain.enabled
		end

		function self.due()
			local out = {}
			for _, id in ipairs(self.order) do
				local domain = self.domains[id]
				if domain.enabled and domain.accumulator >= domain.period then
					out[#out + 1] = id
				end
			end
			table.sort(out, function(a, b)
				local da, db = self.domains[a], self.domains[b]
				local sa = da.priority + da.skipped / self.starvationLimit
				local sb = db.priority + db.skipped / self.starvationLimit
				if sa == sb then return a < b end
				return sa > sb
			end)
			return out
		end

		function self.tick(dt, ctx)
			self.time = self.time + dt
			self.frames = self.frames + 1
			for _, id in ipairs(self.order) do
				local domain = self.domains[id]
				if domain.enabled then domain.accumulator = domain.accumulator + dt end
			end
			local spent = 0
			local ran = {}
			for _, id in ipairs(self.due()) do
				local domain = self.domains[id]
				local starving = domain.skipped >= self.starvationLimit
				if spent + domain.cost <= self.budgetMs or starving then
					local slice = domain.accumulator
					domain.accumulator = domain.accumulator % domain.period
					if domain.step then pcall(domain.step, slice, ctx, domain) end
					domain.steps = domain.steps + 1
					domain.skipped = 0
					domain.lastTime = self.time
					spent = spent + domain.cost
					self.steps = self.steps + 1
					ran[#ran + 1] = id
				else
					domain.skipped = domain.skipped + 1
					self.deferred = self.deferred + 1
				end
			end
			self.spent = spent
			return ran, spent
		end

		function self.run(seconds, dt, ctx)
			local step = dt or 1 / 30
			local n = math.max(1, math.floor(seconds / step))
			local last
			for _ = 1, n do last = self.tick(step, ctx) end
			return last
		end

		-- Domains talk to each other through named channels instead of direct coupling.
		function self.channel(name)
			self.channels[name] = self.channels[name] or { name = name, queue = {}, sent = 0 }
			return self.channels[name]
		end

		function self.send(name, message)
			local channel = self.channel(name)
			channel.queue[#channel.queue + 1] = message
			channel.sent = channel.sent + 1
			self.messages = self.messages + 1
			return #channel.queue
		end

		function self.receive(name, limit)
			local channel = self.channel(name)
			local out = {}
			for _ = 1, math.min(limit or #channel.queue, #channel.queue) do
				out[#out + 1] = table.remove(channel.queue, 1)
			end
			return out
		end

		function self.load()
			local total = 0
			for _, id in ipairs(self.order) do
				local domain = self.domains[id]
				if domain.enabled then total = total + domain.cost * domain.hz end
			end
			return total
		end

		function self.applyQuality(q)
			q = clamp01(q)
			for _, id in ipairs(self.order) do
				local domain = self.domains[id]
				self.setRate(id, math.max(0.5, domain.hz * Mathx.lerp(0.3, 1, q)))
			end
			self.budgetMs = math.max(1, (cfg.budgetMs or 8) * Mathx.lerp(0.4, 1, q))
			return { budgetMs = self.budgetMs, load = self.load() }
		end

		function self.stats() return { domains = #self.order, frames = self.frames,
			steps = self.steps, deferred = self.deferred, budgetMs = self.budgetMs,
			spent = self.spent, load = self.load(), time = self.time,
			messages = self.messages } end
		return self
	end

	------------------------------------------------------------------ 112. AUTOPIPELINE
	-- The Self-Analyzing Project and the Autonomous Development Pipeline in one machine:
	-- rules inspect a project snapshot, findings become prioritized tasks, fixes are
	-- applied, and the project is re-analysed so the health delta is measured, not claimed.
	function K.autopipeline(cfg)
		local self = { kind = "autopipeline", id = cfg.id, rules = {}, order = {},
			fixes = {}, tasks = {}, history = {}, runs = 0, applied = 0, failed = 0,
			maxIterations = cfg.maxIterations or 4 }

		function self.addRule(id, opts)
			opts = opts or {}
			if self.rules[id] then return false end
			self.rules[id] = { id = id, check = opts.check, severity = opts.severity or 1,
				message = opts.message or id, category = opts.category or "general",
				autoFix = opts.fix }
			self.order[#self.order + 1] = id
			if opts.fix then self.fixes[id] = opts.fix end
			return true
		end

		function self.installDefaults()
			if #self.order > 0 then return #self.order end
			self.addRule("frame-budget", { severity = 3, category = "performance",
				message = "frame time is over the device budget",
				check = function(p) return (p.frameMs or 0) > (p.targetMs or 16.6) end,
				fix = function(p) p.quality = math.max(0.2, (p.quality or 1) - 0.2) 
					p.frameMs = (p.frameMs or 0) * 0.8 return true end })
			self.addRule("draw-calls", { severity = 2, category = "performance",
				message = "too many draw calls for a mobile tier",
				check = function(p) return (p.drawCalls or 0) > (p.maxDrawCalls or 900) end,
				fix = function(p) p.drawCalls = math.floor((p.drawCalls or 0) * 0.7) return true end })
			self.addRule("untested-systems", { severity = 3, category = "quality",
				message = "systems without a passing self-test",
				check = function(p) return (p.failingTests or 0) > 0 end,
				fix = function(p) p.failingTests = math.max(0, (p.failingTests or 0) - 1) return true end })
			self.addRule("orphan-assets", { severity = 1, category = "content",
				message = "assets nothing references",
				check = function(p) return (p.orphanAssets or 0) > 0 end,
				fix = function(p) p.orphanAssets = 0 return true end })
			self.addRule("memory-ceiling", { severity = 2, category = "performance",
				message = "resident memory over the ceiling",
				check = function(p) return (p.memoryMb or 0) > (p.memoryCeilingMb or 512) end,
				fix = function(p) p.memoryMb = (p.memoryMb or 0) * 0.85 return true end })
			return #self.order
		end

		function self.analyze(project)
			self.installDefaults()
			self.runs = self.runs + 1
			local findings = {}
			for _, id in ipairs(self.order) do
				local rule = self.rules[id]
				local ok, triggered = pcall(rule.check, project)
				if ok and triggered then
					findings[#findings + 1] = { rule = id, severity = rule.severity,
						message = rule.message, category = rule.category,
						fixable = self.fixes[id] ~= nil }
				end
			end
			table.sort(findings, function(a, b)
				if a.severity == b.severity then return a.rule < b.rule end
				return a.severity > b.severity
			end)
			self.tasks = findings
			return findings
		end

		-- Captured locally: a generated catalog system replaces inst.health with its own
		-- descriptor, so every internal caller must go through this closure instead.
		local function healthOf(project)
			local findings = self.analyze(project)
			local worst = 0
			for _, id in ipairs(self.order) do worst = worst + self.rules[id].severity end
			local lost = 0
			for _, finding in ipairs(findings) do lost = lost + finding.severity end
			if worst == 0 then return 1 end
			return clamp01(1 - lost / worst)
		end
		self.health = healthOf
		self.projectHealth = healthOf

		function self.applyFix(ruleId, project)
			local fix = self.fixes[ruleId]
			if not fix then return false end
			local ok, result = pcall(fix, project)
			if ok and result then
				self.applied = self.applied + 1
				return true
			end
			self.failed = self.failed + 1
			return false
		end

		-- Analyse, fix the worst thing, repeat - and stop when nothing improves.
		function self.improve(project, iterations)
			local before = healthOf(project)
			local rounds = 0
			for _ = 1, (iterations or self.maxIterations) do
				local findings = self.analyze(project)
				local fixable = nil
				for _, finding in ipairs(findings) do
					if finding.fixable then fixable = finding break end
				end
				if not fixable then break end
				if not self.applyFix(fixable.rule, project) then break end
				rounds = rounds + 1
			end
			local after = healthOf(project)
			local record = { before = before, after = after, rounds = rounds,
				gain = after - before }
			self.history[#self.history + 1] = record
			while #self.history > 32 do table.remove(self.history, 1) end
			return record
		end

		function self.report()
			local byCategory = {}
			for _, task in ipairs(self.tasks) do
				byCategory[task.category] = (byCategory[task.category] or 0) + 1
			end
			return { open = #self.tasks, byCategory = byCategory,
				lastGain = self.history[#self.history] and self.history[#self.history].gain or 0 }
		end

		function self.stats() return { rules = #self.order, runs = self.runs,
			applied = self.applied, failed = self.failed, open = #self.tasks,
			history = #self.history } end
		return self
	end

	------------------------------------------------------------------ 113. WORLDMEMORY
	-- World Memory / Persistent Reality State: an epoch-stamped record of everything the
	-- world did, queryable by time, place and subject, compacted into summaries when it
	-- grows, checkpointed and checksummed so a world can be put down and picked back up.
	function K.worldmemory(cfg)
		local self = { kind = "worldmemory", id = cfg.id, records = {}, subjects = {},
			epochs = {}, epoch = 1, time = 0, capacity = cfg.capacity or 512,
			written = 0, compacted = 0, checkpoints = {}, summaries = {} }

		function self.advanceEpoch(label)
			self.epochs[self.epoch] = self.epochs[self.epoch] or { index = self.epoch,
				label = label or ("epoch" .. self.epoch), start = self.time, records = 0 }
			self.epochs[self.epoch].finish = self.time
			self.epoch = self.epoch + 1
			self.epochs[self.epoch] = { index = self.epoch,
				label = label or ("epoch" .. self.epoch), start = self.time, records = 0 }
			return self.epoch
		end

		function self.remember(subject, event, opts)
			opts = opts or {}
			self.time = opts.time or self.time
			local record = { subject = subject, event = event, time = self.time,
				epoch = self.epoch, region = opts.region, weight = opts.weight or 1,
				data = opts.data }
			self.records[#self.records + 1] = record
			self.subjects[subject] = self.subjects[subject] or {}
			local list = self.subjects[subject]
			list[#list + 1] = record
			self.epochs[self.epoch] = self.epochs[self.epoch] or { index = self.epoch,
				label = "epoch" .. self.epoch, start = self.time, records = 0 }
			self.epochs[self.epoch].records = self.epochs[self.epoch].records + 1
			self.written = self.written + 1
			if #self.records > self.capacity then self.compact() end
			return record
		end

		function self.advance(dt)
			self.time = self.time + dt
			return self.time
		end

		function self.recall(filter)
			filter = filter or {}
			local out = {}
			for _, record in ipairs(self.records) do
				local ok = true
				if filter.subject and record.subject ~= filter.subject then ok = false end
				if ok and filter.event and record.event ~= filter.event then ok = false end
				if ok and filter.region and record.region ~= filter.region then ok = false end
				if ok and filter.since and record.time < filter.since then ok = false end
				if ok and filter.until_ and record.time > filter.until_ then ok = false end
				if ok and filter.epoch and record.epoch ~= filter.epoch then ok = false end
				if ok then out[#out + 1] = record end
			end
			return out
		end

		function self.historyOf(subject, limit)
			local list = self.subjects[subject] or {}
			local out = {}
			local from = math.max(1, #list - (limit or 10) + 1)
			for i = from, #list do out[#out + 1] = list[i] end
			return out
		end

		-- Compaction folds the oldest half into per-subject summaries: the world keeps its
		-- past without keeping every second of it.
		function self.compact()
			local half = math.floor(#self.records / 2)
			if half < 1 then return 0 end
			local folded = 0
			for i = 1, half do
				local record = self.records[i]
				local key = record.subject .. "|" .. record.event
				local summary = self.summaries[key]
				if not summary then
					summary = { subject = record.subject, event = record.event, count = 0,
						firstTime = record.time, lastTime = record.time, weight = 0 }
					self.summaries[key] = summary
				end
				summary.count = summary.count + 1
				summary.lastTime = record.time
				summary.weight = summary.weight + record.weight
				folded = folded + 1
			end
			local kept = {}
			for i = half + 1, #self.records do kept[#kept + 1] = self.records[i] end
			self.records = kept
			for subject, list in pairs(self.subjects) do
				local keptList = {}
				for _, record in ipairs(list) do
					if record.time > (self.records[1] and self.records[1].time or 0) - 1e-9 then
						keptList[#keptList + 1] = record
					end
				end
				self.subjects[subject] = keptList
			end
			self.compacted = self.compacted + folded
			return folded
		end

		function self.summaryOf(subject, event)
			return self.summaries[subject .. "|" .. event]
		end

		function self.checksum()
			local parts = {}
			for _, record in ipairs(self.records) do
				parts[#parts + 1] = string.format("%s:%s:%.3f:%d", record.subject,
					record.event, record.time, record.epoch)
			end
			for _, key in ipairs(C.keys(self.summaries)) do
				local s = self.summaries[key]
				parts[#parts + 1] = string.format("S%s:%d:%.3f", key, s.count, s.weight)
			end
			table.sort(parts)
			return Hash.fnv1a(table.concat(parts, "|"))
		end

		function self.checkpoint(label)
			local snapshot = { label = label or ("cp" .. (#self.checkpoints + 1)),
				time = self.time, epoch = self.epoch, checksum = self.checksum(),
				records = {}, summaries = {} }
			for i, record in ipairs(self.records) do
				snapshot.records[i] = { subject = record.subject, event = record.event,
					time = record.time, epoch = record.epoch, region = record.region,
					weight = record.weight, data = record.data }
			end
			for key, summary in pairs(self.summaries) do
				snapshot.summaries[key] = { subject = summary.subject, event = summary.event,
					count = summary.count, firstTime = summary.firstTime,
					lastTime = summary.lastTime, weight = summary.weight }
			end
			self.checkpoints[#self.checkpoints + 1] = snapshot
			return snapshot
		end

		function self.restore(snapshot)
			if not snapshot then return false end
			self.records = {}
			self.subjects = {}
			for _, record in ipairs(snapshot.records) do
				self.records[#self.records + 1] = record
				self.subjects[record.subject] = self.subjects[record.subject] or {}
				local list = self.subjects[record.subject]
				list[#list + 1] = record
			end
			self.summaries = {}
			for key, summary in pairs(snapshot.summaries) do self.summaries[key] = summary end
			self.time = snapshot.time
			self.epoch = snapshot.epoch
			return self.checksum() == snapshot.checksum
		end

		function self.stats() return { records = #self.records, subjects = C.count(self.subjects),
			summaries = C.count(self.summaries), epoch = self.epoch, time = self.time,
			written = self.written, compacted = self.compacted,
			checkpoints = #self.checkpoints, capacity = self.capacity } end
		return self
	end

	------------------------------------------------------------------ 114. EMERGENCE
	-- The Emergent Society detector: it watches events and signals, notices which things
	-- keep happening together, scores how surprising a co-occurrence is against chance,
	-- and names the recurring ones as phenomena the designer never scripted.
	function K.emergence(cfg)
		local self = { kind = "emergence", id = cfg.id, counts = {}, pairs_ = {},
			signals = {}, window = {}, windowSize = cfg.windowSize or 8,
			observations = 0, phenomena = {}, order = {},
			threshold = cfg.threshold or 1.5, minCount = cfg.minCount or 3 }

		function self.observe(event, weight)
			self.observations = self.observations + 1
			self.counts[event] = (self.counts[event] or 0) + (weight or 1)
			for _, other in ipairs(self.window) do
				if other ~= event then
					local key = event < other and (event .. "&" .. other) or (other .. "&" .. event)
					self.pairs_[key] = (self.pairs_[key] or 0) + 1
				end
			end
			self.window[#self.window + 1] = event
			while #self.window > self.windowSize do table.remove(self.window, 1) end
			return self.counts[event]
		end

		function self.signal(name, value)
			local s = self.signals[name]
			if not s then
				s = { name = name, samples = 0, mean = 0, m2 = 0, last = value }
				self.signals[name] = s
			end
			s.samples = s.samples + 1
			local delta = value - s.mean
			s.mean = s.mean + delta / s.samples
			s.m2 = s.m2 + delta * (value - s.mean)
			s.last = value
			return s.mean
		end

		function self.deviation(name)
			local s = self.signals[name]
			if not s or s.samples < 2 then return 0 end
			local variance = s.m2 / (s.samples - 1)
			local sd = math.sqrt(math.max(0, variance))
			if sd < 1e-9 then return 0 end
			return (s.last - s.mean) / sd
		end

		-- Lift: how much more often two events co-occur than independence predicts.
		function self.lift(a, b)
			local key = a < b and (a .. "&" .. b) or (b .. "&" .. a)
			local both = self.pairs_[key] or 0
			if both == 0 or self.observations == 0 then return 0 end
			local pa = (self.counts[a] or 0) / self.observations
			local pb = (self.counts[b] or 0) / self.observations
			if pa <= 0 or pb <= 0 then return 0 end
			local expected = pa * pb * self.observations
			if expected <= 0 then return 0 end
			return both / expected
		end

		function self.detect()
			local found = {}
			for key, count in pairs(self.pairs_) do
				if count >= self.minCount then
					local a, b = key:match("^(.-)&(.+)$")
					local lift = self.lift(a, b)
					if lift >= self.threshold then
						found[#found + 1] = { pair = key, a = a, b = b, count = count,
							lift = lift }
					end
				end
			end
			table.sort(found, function(x, y)
				if x.lift == y.lift then return x.pair < y.pair end
				return x.lift > y.lift
			end)
			for _, item in ipairs(found) do
				if not self.phenomena[item.pair] then
					self.phenomena[item.pair] = { name = item.a .. "-" .. item.b,
						pair = item.pair, discovered = self.observations, lift = item.lift,
						count = item.count }
					self.order[#self.order + 1] = item.pair
				else
					self.phenomena[item.pair].lift = item.lift
					self.phenomena[item.pair].count = item.count
				end
			end
			return found
		end

		function self.novelty(event)
			local seen = self.counts[event] or 0
			if self.observations == 0 then return 1 end
			return clamp01(1 - seen / self.observations)
		end

		function self.named()
			local out = {}
			for _, key in ipairs(self.order) do out[#out + 1] = self.phenomena[key].name end
			table.sort(out)
			return out
		end

		function self.forget()
			self.counts = {}
			self.pairs_ = {}
			self.window = {}
			self.observations = 0
			return true
		end

		function self.stats() return { observations = self.observations,
			events = C.count(self.counts), pairs = C.count(self.pairs_),
			signals = C.count(self.signals), phenomena = #self.order,
			threshold = self.threshold } end
		return self
	end

	------------------------------------------------------------------ 115. ARCHITECT
	-- The Singularity World Architect: it takes a brief and composes a whole world - a
	-- hierarchy of regions, districts and lots with budgets that actually divide, a
	-- dependency-ordered build programme, cost estimates per stage, and a coherence check
	-- that refuses a plan whose parts contradict each other.
	function K.architect(cfg)
		local self = { kind = "architect", id = cfg.id, nodes = {}, order = {},
			root = nil, stages = {}, budget = cfg.budget or 1000, rules = {},
			composed = 0, rejections = 0, rng = Random.new(cfg.seed or 1337) }

		function self.define(id, opts)
			opts = opts or {}
			if self.nodes[id] then return nil, "duplicate node" end
			local node = { id = id, kind = opts.kind or "region", parent = opts.parent,
				children = {}, weight = opts.weight or 1, budget = 0,
				requires = opts.requires or {}, tags = opts.tags or {},
				density = opts.density or 1, stage = opts.stage or "build" }
			self.nodes[id] = node
			self.order[#self.order + 1] = id
			if node.parent and self.nodes[node.parent] then
				local parent = self.nodes[node.parent]
				parent.children[#parent.children + 1] = id
			elseif not self.root then
				self.root = id
			end
			return node
		end

		-- Budget flows down the tree by weight: a child never gets more than its parent has.
		function self.allocate(total)
			if not self.root then return 0 end
			self.budget = total or self.budget
			local function walk(id, amount)
				local node = self.nodes[id]
				node.budget = amount
				local weightTotal = 0
				for _, child in ipairs(node.children) do
					weightTotal = weightTotal + self.nodes[child].weight
				end
				for _, child in ipairs(node.children) do
					local share = weightTotal > 0 and self.nodes[child].weight / weightTotal or 0
					walk(child, amount * share)
				end
			end
			walk(self.root, self.budget)
			return self.nodes[self.root].budget
		end

		function self.budgetOf(id)
			local node = self.nodes[id]
			return node and node.budget or 0
		end

		function self.addRule(name, fn)
			self.rules[#self.rules + 1] = { name = name, check = fn }
			return #self.rules
		end

		function self.installRules()
			if #self.rules > 0 then return #self.rules end
			self.addRule("budget-conserved", function(plan)
				local leafTotal = 0
				for _, id in ipairs(plan.order) do
					local node = plan.nodes[id]
					if #node.children == 0 then leafTotal = leafTotal + node.budget end
				end
				return math.abs(leafTotal - plan.budget) < math.max(1e-6, plan.budget * 1e-6)
			end)
			self.addRule("dependencies-exist", function(plan)
				for _, id in ipairs(plan.order) do
					for _, dep in ipairs(plan.nodes[id].requires) do
						if not plan.nodes[dep] then return false end
					end
				end
				return true
			end)
			self.addRule("root-single", function(plan)
				local roots = 0
				for _, id in ipairs(plan.order) do
					if not plan.nodes[id].parent then roots = roots + 1 end
				end
				return roots == 1
			end)
			return #self.rules
		end

		function self.coherent()
			self.installRules()
			local failures = {}
			for _, rule in ipairs(self.rules) do
				local ok, verdict = pcall(rule.check, self)
				if not ok or not verdict then failures[#failures + 1] = rule.name end
			end
			if #failures > 0 then self.rejections = self.rejections + 1 end
			return #failures == 0, failures
		end

		-- Build programme: dependencies first, then parents before children.
		function self.programme()
			local visited, out = {}, {}
			local cycle = false
			local function visit(id, stack)
				if cycle or visited[id] then return end
				if stack[id] then cycle = true return end
				stack[id] = true
				local node = self.nodes[id]
				for _, dep in ipairs(node.requires) do
					if self.nodes[dep] then visit(dep, stack) end
				end
				if node.parent and self.nodes[node.parent] then visit(node.parent, stack) end
				stack[id] = nil
				visited[id] = true
				out[#out + 1] = id
			end
			for _, id in ipairs(self.order) do visit(id, {}) end
			if cycle then return nil, "cyclic plan" end
			self.stages = out
			return out
		end

		function self.estimate(costPerUnit)
			local rate = costPerUnit or 1
			local total = 0
			for _, id in ipairs(self.order) do
				local node = self.nodes[id]
				total = total + node.budget * node.density * rate
			end
			return total
		end

		-- Compose a standard settlement plan from a parsed brief.
		function self.compose(brief)
			brief = brief or {}
			local name = brief.target or "world"
			local districts = math.max(1, math.min(8, math.floor((brief.quantity or 60) / 25) + 1))
			self.define(name, { kind = "region", weight = 1, density = brief.density or 1 })
			self.define(name .. ".terrain", { kind = "terrain", parent = name, weight = 2 })
			self.define(name .. ".roads", { kind = "network", parent = name, weight = 1,
				requires = { name .. ".terrain" } })
			for i = 1, districts do
				local district = string.format("%s.district%d", name, i)
				self.define(district, { kind = "district", parent = name, weight = 1.5,
					requires = { name .. ".roads" },
					density = (brief.density or 1) * (1 + (i % 3) * 0.15) })
				self.define(district .. ".buildings", { kind = "buildings", parent = district,
					weight = 3 })
				self.define(district .. ".props", { kind = "props", parent = district,
					weight = 1 })
			end
			self.define(name .. ".lighting", { kind = "render", parent = name, weight = 1,
				requires = { name .. ".roads" } })
			self.define(name .. ".population", { kind = "life", parent = name, weight = 2,
				requires = { name .. ".lighting" } })
			self.allocate(self.budget)
			self.composed = self.composed + 1
			return { root = name, districts = districts, nodes = #self.order }
		end

		function self.describe()
			local byKind = {}
			for _, id in ipairs(self.order) do
				local kind = self.nodes[id].kind
				byKind[kind] = (byKind[kind] or 0) + 1
			end
			return byKind
		end

		function self.stats() return { nodes = #self.order, root = self.root,
			budget = self.budget, stages = #self.stages, composed = self.composed,
			rejections = self.rejections, rules = #self.rules } end
		return self
	end

	K.NAMES = { "reality", "complexity", "fabric", "autopipeline", "worldmemory",
		"emergence", "architect" }
	return K
end
