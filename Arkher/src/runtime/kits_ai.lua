-- ARKHER RUNTIME :: Singularity AI Kits
-- Round 8 machinery (kits 100-103). The reasoning half of ARKHER: turning a human
-- instruction into a structured intent, holding what the project knows as a semantic
-- graph, executing a verified plan of engine work, and judging the result honestly.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Hash = A:import("arkher/kernel/hash")
	local Random = A:import("arkher/kernel/random")

	local K = {}
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 100. INTENT
	-- Deterministic instruction parsing: a lexicon of verbs, targets, qualifiers and
	-- constraints, scored against the tokens of a command. No model, no network - a real
	-- grammar that turns "create a realistic city with 200 buildings for weak phones"
	-- into a structured request the workflow kit can execute.
	function K.intent(cfg)
		local self = { kind = "intent", id = cfg.id, verbs = {}, targets = {},
			qualifiers = {}, constraints = {}, patterns = {}, order = {},
			parsed = 0, unmatched = 0, minConfidence = cfg.minConfidence or 0.25 }

		local NUMBER_WORDS = { one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
			seven = 7, eight = 8, nine = 9, ten = 10, dozen = 12, hundred = 100,
			thousand = 1000, million = 1000000 }

		function self.addVerb(name, aliases, action)
			if self.verbs[name] then return false end
			self.verbs[name] = { name = name, action = action or name, aliases = {} }
			self.verbs[name].aliases[name] = true
			for _, alias in ipairs(aliases or {}) do self.verbs[name].aliases[alias] = true end
			self.order[#self.order + 1] = name
			return true
		end

		function self.addTarget(name, aliases, domain)
			if self.targets[name] then return false end
			self.targets[name] = { name = name, domain = domain or "world", aliases = {} }
			self.targets[name].aliases[name] = true
			for _, alias in ipairs(aliases or {}) do self.targets[name].aliases[alias] = true end
			return true
		end

		function self.addQualifier(name, aliases, weight)
			self.qualifiers[name] = { name = name, weight = weight or 1, aliases = {} }
			self.qualifiers[name].aliases[name] = true
			for _, alias in ipairs(aliases or {}) do self.qualifiers[name].aliases[alias] = true end
			return true
		end

		function self.addConstraint(name, aliases, key, value)
			self.constraints[name] = { name = name, key = key or name, value = value,
				aliases = {} }
			self.constraints[name].aliases[name] = true
			for _, alias in ipairs(aliases or {}) do self.constraints[name].aliases[alias] = true end
			return true
		end

		-- A pattern is a bag of keywords that reinforces one interpretation.
		function self.addPattern(intentName, keywords, weight)
			self.patterns[#self.patterns + 1] = { intent = intentName, keywords = keywords,
				weight = weight or 1 }
			return #self.patterns
		end

		function self.installDefaults()
			if #self.order > 0 then return #self.order end
			self.addVerb("create", { "build", "make", "generate", "spawn", "author" }, "create")
			self.addVerb("optimize", { "optimise", "speed", "improve", "tune" }, "optimize")
			self.addVerb("analyze", { "analyse", "inspect", "profile", "measure" }, "analyze")
			self.addVerb("fix", { "repair", "resolve", "debug" }, "fix")
			self.addVerb("populate", { "fill", "inhabit" }, "populate")
			self.addTarget("city", { "town", "metropolis", "village" }, "procedural")
			self.addTarget("terrain", { "landscape", "ground", "island" }, "terrain")
			self.addTarget("map", { "level", "place", "scene" }, "world")
			self.addTarget("character", { "npc", "human", "avatar" }, "character")
			self.addTarget("lighting", { "light", "sun", "sky" }, "render")
			self.addQualifier("realistic", { "realism", "photoreal", "lifelike" }, 1)
			self.addQualifier("stylized", { "stylised", "cartoon", "toon" }, 1)
			self.addQualifier("dense", { "crowded", "busy", "packed" }, 1)
			self.addConstraint("mobile", { "phone", "phones", "android", "ios", "weak" },
				"device", "mobile")
			self.addConstraint("console", { "xbox", "playstation" }, "device", "console")
			self.addConstraint("fast", { "quick", "cheap", "lightweight" }, "budget", "low")
			self.addPattern("optimize", { "lag", "fps", "slow", "stutter" }, 2)
			self.addPattern("create", { "new", "from", "scratch" }, 1)
			return #self.order
		end

		function self.tokenize(text)
			local tokens = {}
			for word in tostring(text or ""):lower():gmatch("[%a%d%.]+") do
				tokens[#tokens + 1] = word
			end
			return tokens
		end

		function self.numberIn(tokens)
			for _, token in ipairs(tokens) do
				local n = tonumber(token)
				if n then return n end
				if NUMBER_WORDS[token] then return NUMBER_WORDS[token] end
			end
			return nil
		end

		local function matchTable(source, token)
			for name, entry in pairs(source) do
				if entry.aliases[token] then return name, entry end
			end
			return nil
		end

		function self.parse(text)
			self.installDefaults()
			local tokens = self.tokenize(text)
			local result = { text = text, tokens = tokens, action = nil, target = nil,
				domain = nil, quantity = nil, qualifiers = {}, constraints = {},
				matched = 0, confidence = 0 }
			for _, token in ipairs(tokens) do
				if not result.action then
					local verb = matchTable(self.verbs, token)
					if verb then
						result.action = self.verbs[verb].action
						result.matched = result.matched + 1
					end
				end
				if not result.target then
					local target = matchTable(self.targets, token)
					if target then
						result.target = target
						result.domain = self.targets[target].domain
						result.matched = result.matched + 1
					end
				end
				local qualifier = matchTable(self.qualifiers, token)
				if qualifier then
					result.qualifiers[#result.qualifiers + 1] = qualifier
					result.matched = result.matched + 1
				end
				local constraint = matchTable(self.constraints, token)
				if constraint then
					local c = self.constraints[constraint]
					result.constraints[c.key] = c.value or true
					result.matched = result.matched + 1
				end
			end
			result.quantity = self.numberIn(tokens)
			-- patterns break ties when no verb was spoken outright
			for _, pattern in ipairs(self.patterns) do
				local hits = 0
				for _, keyword in ipairs(pattern.keywords) do
					for _, token in ipairs(tokens) do
						if token == keyword then hits = hits + 1 end
					end
				end
				if hits > 0 then
					result.matched = result.matched + hits * pattern.weight
					if not result.action then result.action = pattern.intent end
				end
			end
			local denominator = math.max(1, #tokens)
			result.confidence = clamp01(result.matched / denominator + (result.action and 0.2 or 0)
				+ (result.target and 0.2 or 0))
			result.understood = result.action ~= nil and result.confidence >= self.minConfidence
			self.parsed = self.parsed + 1
			if not result.understood then self.unmatched = self.unmatched + 1 end
			return result
		end

		function self.explain(result)
			if not result then return "nothing to explain" end
			local parts = { (result.action or "unknown") .. " " .. (result.target or "?") }
			if result.quantity then parts[#parts + 1] = "x" .. tostring(result.quantity) end
			for _, q in ipairs(result.qualifiers) do parts[#parts + 1] = q end
			for key, value in pairs(result.constraints) do
				parts[#parts + 1] = key .. "=" .. tostring(value)
			end
			return table.concat(parts, " ")
		end

		function self.vocabulary()
			return { verbs = #self.order, targets = C.count(self.targets),
				qualifiers = C.count(self.qualifiers), constraints = C.count(self.constraints),
				patterns = #self.patterns }
		end

		function self.stats() return { parsed = self.parsed, unmatched = self.unmatched,
			verbs = #self.order, patterns = #self.patterns,
			minConfidence = self.minConfidence } end
		return self
	end

	------------------------------------------------------------------ 101. KNOWLEDGE
	-- The Semantic World Graph: typed entities, weighted relations, attribute queries,
	-- transitive inference, hashed feature vectors and similarity search. This is what
	-- lets Singularity AI answer "what is in this project and how is it connected".
	function K.knowledge(cfg)
		local self = { kind = "knowledge", id = cfg.id, entities = {}, order = {},
			relations = {}, rules = {}, dims = cfg.dims or 16, inferred = 0,
			queries = 0, edges = 0 }

		function self.addEntity(id, etype, attrs)
			if self.entities[id] then return nil, "duplicate entity" end
			local e = { id = id, type = etype or "thing", attrs = attrs or {},
				out = {}, incoming = {} }
			self.entities[id] = e
			self.order[#self.order + 1] = id
			return e
		end

		function self.setAttribute(id, key, value)
			local e = self.entities[id]
			if not e then return false end
			e.attrs[key] = value
			return true
		end

		function self.attributesOf(id)
			local e = self.entities[id]
			return e and e.attrs or nil
		end

		function self.relate(from, rel, to, weight)
			local a, b = self.entities[from], self.entities[to]
			if not a or not b then return false, "unknown entity" end
			a.out[rel] = a.out[rel] or {}
			for _, existing in ipairs(a.out[rel]) do
				if existing.to == to then return false, "duplicate relation" end
			end
			a.out[rel][#a.out[rel] + 1] = { to = to, weight = weight or 1, inferred = false }
			b.incoming[rel] = b.incoming[rel] or {}
			b.incoming[rel][#b.incoming[rel] + 1] = from
			self.relations[rel] = (self.relations[rel] or 0) + 1
			self.edges = self.edges + 1
			return true
		end

		function self.relatedTo(id, rel)
			local e = self.entities[id]
			if not e or not e.out[rel] then return {} end
			local out = {}
			for _, edge in ipairs(e.out[rel]) do out[#out + 1] = edge.to end
			return out
		end

		function self.hasRelation(from, rel, to)
			local e = self.entities[from]
			if not e or not e.out[rel] then return false end
			for _, edge in ipairs(e.out[rel]) do
				if edge.to == to then return true, edge.inferred end
			end
			return false
		end

		-- A rule closes a relation transitively (part_of, contains, depends_on...).
		function self.addRule(rel, kind)
			self.rules[#self.rules + 1] = { rel = rel, kind = kind or "transitive" }
			return #self.rules
		end

		function self.infer(maxPasses)
			local added = 0
			for _ = 1, (maxPasses or 3) do
				local passAdded = 0
				for _, rule in ipairs(self.rules) do
					if rule.kind == "transitive" then
						for _, id in ipairs(self.order) do
							for _, mid in ipairs(self.relatedTo(id, rule.rel)) do
								for _, far in ipairs(self.relatedTo(mid, rule.rel)) do
									if far ~= id and not self.hasRelation(id, rule.rel, far) then
										local e = self.entities[id]
										e.out[rule.rel][#e.out[rule.rel] + 1] =
											{ to = far, weight = 0.5, inferred = true }
										self.edges = self.edges + 1
										passAdded = passAdded + 1
									end
								end
							end
						end
					elseif rule.kind == "symmetric" then
						for _, id in ipairs(self.order) do
							for _, other in ipairs(self.relatedTo(id, rule.rel)) do
								if not self.hasRelation(other, rule.rel, id) then
									local e = self.entities[other]
									e.out[rule.rel] = e.out[rule.rel] or {}
									e.out[rule.rel][#e.out[rule.rel] + 1] =
										{ to = id, weight = 0.5, inferred = true }
									self.edges = self.edges + 1
									passAdded = passAdded + 1
								end
							end
						end
					end
				end
				added = added + passAdded
				if passAdded == 0 then break end
			end
			self.inferred = self.inferred + added
			return added
		end

		function self.query(filter)
			self.queries = self.queries + 1
			filter = filter or {}
			local out = {}
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				local ok = true
				if filter.type and e.type ~= filter.type then ok = false end
				if ok and filter.attrs then
					for key, value in pairs(filter.attrs) do
						if e.attrs[key] ~= value then ok = false break end
					end
				end
				if ok and filter.relatedBy then
					local found = false
					for _, edge in ipairs(e.out[filter.relatedBy] or {}) do
						if not filter.relatedTo or edge.to == filter.relatedTo then found = true end
					end
					if not found then ok = false end
				end
				if ok then out[#out + 1] = id end
			end
			return out
		end

		function self.path(from, to, maxDepth)
			if not self.entities[from] or not self.entities[to] then return nil end
			local queue = { { id = from, path = { from } } }
			local seen = { [from] = true }
			local head = 1
			while head <= #queue do
				local node = queue[head]
				head = head + 1
				if node.id == to then return node.path end
				if #node.path <= (maxDepth or 6) then
					local e = self.entities[node.id]
					for rel, edges in pairs(e.out) do
						for _, edge in ipairs(edges) do
							if not seen[edge.to] then
								seen[edge.to] = true
								local path = {}
								for i, step in ipairs(node.path) do path[i] = step end
								path[#path + 1] = edge.to
								queue[#queue + 1] = { id = edge.to, path = path, rel = rel }
							end
						end
					end
				end
			end
			return nil
		end

		-- A hashed feature vector: type, attributes and relations folded into fixed dims.
		function self.embed(id)
			local e = self.entities[id]
			if not e then return nil end
			local vec = {}
			for i = 1, self.dims do vec[i] = 0 end
			local function fold(text, weight)
				local slot = (Hash.fnv1a(tostring(text)) % self.dims) + 1
				vec[slot] = vec[slot] + weight
			end
			fold("type:" .. e.type, 2)
			for key, value in pairs(e.attrs) do fold(key .. "=" .. tostring(value), 1) end
			for rel, edges in pairs(e.out) do
				for _, edge in ipairs(edges) do fold(rel .. "->" .. edge.to, edge.weight) end
			end
			local length = 0
			for i = 1, self.dims do length = length + vec[i] * vec[i] end
			length = math.sqrt(length)
			if length > 0 then
				for i = 1, self.dims do vec[i] = vec[i] / length end
			end
			return vec
		end

		function self.similarity(a, b)
			local va, vb = self.embed(a), self.embed(b)
			if not va or not vb then return 0 end
			local dot = 0
			for i = 1, self.dims do dot = dot + va[i] * vb[i] end
			return clamp01(dot)
		end

		function self.nearest(id, count)
			local out = {}
			for _, other in ipairs(self.order) do
				if other ~= id then
					out[#out + 1] = { id = other, score = self.similarity(id, other) }
				end
			end
			table.sort(out, function(x, y)
				if x.score == y.score then return x.id < y.id end
				return x.score > y.score
			end)
			local top = {}
			for i = 1, math.min(count or 3, #out) do top[i] = out[i] end
			return top
		end

		function self.forget(id)
			if not self.entities[id] then return false end
			self.entities[id] = nil
			for i, other in ipairs(self.order) do
				if other == id then table.remove(self.order, i) break end
			end
			for _, otherId in ipairs(self.order) do
				local e = self.entities[otherId]
				for rel, edges in pairs(e.out) do
					for i = #edges, 1, -1 do
						if edges[i].to == id then
							table.remove(edges, i)
							self.edges = self.edges - 1
						end
					end
					if #edges == 0 then e.out[rel] = nil end
				end
			end
			return true
		end

		function self.stats() return { entities = #self.order, edges = self.edges,
			relations = C.count(self.relations), rules = #self.rules,
			inferred = self.inferred, queries = self.queries, dims = self.dims } end
		return self
	end

	------------------------------------------------------------------ 102. WORKFLOW
	-- A verified plan: steps with prerequisites, a topological schedule, execution with
	-- per-step verification, bounded retries, and rollback of everything that succeeded
	-- before a step failed for good. This is how "create a city" becomes real work.
	function K.workflow(cfg)
		local self = { kind = "workflow", id = cfg.id, steps = {}, order = {},
			results = {}, executed = 0, failures = 0, retries = 0, rollbacks = 0,
			maxRetries = cfg.maxRetries or 2, budget = cfg.budget or math.huge,
			spent = 0, running = false }

		function self.addStep(id, opts)
			opts = opts or {}
			if self.steps[id] then return nil, "duplicate step" end
			local step = { id = id, requires = opts.requires or {}, run = opts.run,
				verify = opts.verify, undo = opts.undo, cost = opts.cost or 1,
				retries = opts.retries or self.maxRetries, state = "pending",
				attempts = 0, label = opts.label or id }
			self.steps[id] = step
			self.order[#self.order + 1] = id
			return step
		end

		function self.plan()
			local visited, temp, out = {}, {}, {}
			local cycle = false
			local function visit(id)
				if cycle or visited[id] then return end
				if temp[id] then cycle = true return end
				temp[id] = true
				local step = self.steps[id]
				if step then
					for _, dep in ipairs(step.requires) do
						if self.steps[dep] then visit(dep) end
					end
				end
				temp[id] = nil
				visited[id] = true
				out[#out + 1] = id
			end
			for _, id in ipairs(self.order) do visit(id) end
			if cycle then return nil, "cycle detected" end
			return out
		end

		function self.estimate()
			local total = 0
			for _, id in ipairs(self.order) do total = total + self.steps[id].cost end
			return total
		end

		function self.criticalPath()
			local order = self.plan()
			if not order then return {} end
			local best, from = {}, {}
			local bestId, bestCost = nil, -1
			for _, id in ipairs(order) do
				local step = self.steps[id]
				local incoming = 0
				for _, dep in ipairs(step.requires) do
					if (best[dep] or 0) > incoming then
						incoming = best[dep]
						from[id] = dep
					end
				end
				best[id] = incoming + step.cost
				if best[id] > bestCost then bestCost = best[id] bestId = id end
			end
			local path = {}
			local cursor = bestId
			while cursor do
				table.insert(path, 1, cursor)
				cursor = from[cursor]
			end
			return path, bestCost
		end

		function self.run(ctx)
			local order, err = self.plan()
			if not order then return false, err end
			self.running = true
			local done = {}
			for _, id in ipairs(order) do
				local step = self.steps[id]
				local ready = true
				for _, dep in ipairs(step.requires) do
					if self.steps[dep] and self.steps[dep].state ~= "done" then ready = false end
				end
				if not ready then
					step.state = "skipped"
				else
					local ok = false
					while step.attempts <= step.retries and not ok do
						step.attempts = step.attempts + 1
						if step.attempts > 1 then self.retries = self.retries + 1 end
						local produced
						if step.run then
							local success, value = pcall(step.run, ctx, step)
							produced = success and value or nil
							ok = success
						else
							ok = true
						end
						if ok and step.verify then
							local success, verdict = pcall(step.verify, ctx, produced, step)
							ok = success and verdict and true or false
						end
						if ok then
							self.results[id] = produced
							self.spent = self.spent + step.cost
						end
					end
					step.state = ok and "done" or "failed"
					self.executed = self.executed + 1
					if ok then
						done[#done + 1] = id
					else
						self.failures = self.failures + 1
						self.running = false
						self.rollback(done, ctx)
						return false, id
					end
					if self.spent > self.budget then
						self.running = false
						return false, "budget exceeded at " .. id
					end
				end
			end
			self.running = false
			return true, #done
		end

		function self.rollback(done, ctx)
			for i = #done, 1, -1 do
				local step = self.steps[done[i]]
				if step and step.undo then pcall(step.undo, ctx, step) end
				if step then step.state = "rolled-back" end
				self.rollbacks = self.rollbacks + 1
			end
			return self.rollbacks
		end

		function self.progress()
			local done = 0
			for _, id in ipairs(self.order) do
				if self.steps[id].state == "done" then done = done + 1 end
			end
			return done / math.max(1, #self.order)
		end

		function self.failedSteps()
			local out = {}
			for _, id in ipairs(self.order) do
				if self.steps[id].state == "failed" then out[#out + 1] = id end
			end
			return out
		end

		function self.reset()
			for _, id in ipairs(self.order) do
				self.steps[id].state = "pending"
				self.steps[id].attempts = 0
			end
			self.results = {}
			self.spent = 0
			return true
		end

		function self.stats() return { steps = #self.order, executed = self.executed,
			failures = self.failures, retries = self.retries, rollbacks = self.rollbacks,
			progress = self.progress(), spent = self.spent, budget = self.budget } end
		return self
	end

	------------------------------------------------------------------ 103. CRITIC
	-- Honest evaluation: weighted criteria with targets and tolerances, a score per
	-- criterion, an overall verdict, and findings ordered by how much score they cost -
	-- so the AI knows what to fix first instead of guessing.
	function K.critic(cfg)
		local self = { kind = "critic", id = cfg.id, criteria = {}, order = {},
			history = {}, evaluations = 0, passes = 0, rejects = 0,
			passMark = cfg.passMark or 0.75, reviseMark = cfg.reviseMark or 0.5,
			rng = Random.new(cfg.seed or 77) }

		function self.addCriterion(name, opts)
			opts = opts or {}
			if self.criteria[name] then return false end
			self.criteria[name] = { name = name, weight = opts.weight or 1,
				target = opts.target, tolerance = opts.tolerance or 0.2,
				direction = opts.direction or "target", floor = opts.floor,
				ceiling = opts.ceiling }
			self.order[#self.order + 1] = name
			return true
		end

		function self.scoreOne(name, value)
			local c = self.criteria[name]
			if not c then return 0 end
			if value == nil then return 0 end
			if c.direction == "higher" then
				local target = c.target or 1
				if target <= 0 then return 1 end
				return clamp01(value / target)
			elseif c.direction == "lower" then
				local target = c.target or 1
				if value <= 0 then return 1 end
				return clamp01(target / math.max(1e-9, value))
			elseif c.direction == "range" then
				local low = c.floor or 0
				local high = c.ceiling or 1
				if value >= low and value <= high then return 1 end
				local distance = value < low and (low - value) or (value - high)
				local span = math.max(1e-9, high - low)
				return clamp01(1 - distance / span)
			end
			local target = c.target or 0
			local tolerance = math.max(1e-9, c.tolerance * math.max(1, math.abs(target)))
			return clamp01(1 - math.abs(value - target) / tolerance)
		end

		function self.evaluate(sample)
			self.evaluations = self.evaluations + 1
			local totalWeight, weighted = 0, 0
			local scores, findings = {}, {}
			for _, name in ipairs(self.order) do
				local c = self.criteria[name]
				local score = self.scoreOne(name, sample[name])
				scores[name] = score
				weighted = weighted + score * c.weight
				totalWeight = totalWeight + c.weight
				local loss = (1 - score) * c.weight
				if loss > 1e-6 then
					findings[#findings + 1] = { criterion = name, score = score, loss = loss,
						observed = sample[name], target = c.target }
				end
			end
			table.sort(findings, function(a, b)
				if a.loss == b.loss then return a.criterion < b.criterion end
				return a.loss > b.loss
			end)
			local overall = totalWeight > 0 and weighted / totalWeight or 0
			local verdict = self.verdict(overall)
			if verdict == "pass" then self.passes = self.passes + 1 end
			if verdict == "reject" then self.rejects = self.rejects + 1 end
			local record = { overall = overall, scores = scores, findings = findings,
				verdict = verdict, index = self.evaluations }
			self.history[#self.history + 1] = record
			while #self.history > 64 do table.remove(self.history, 1) end
			return record
		end

		function self.verdict(score)
			if score >= self.passMark then return "pass" end
			if score >= self.reviseMark then return "revise" end
			return "reject"
		end

		function self.worst(record)
			record = record or self.history[#self.history]
			if not record or #record.findings == 0 then return nil end
			return record.findings[1].criterion, record.findings[1].loss
		end

		function self.compare(a, b)
			local ra, rb = self.evaluate(a), self.evaluate(b)
			return ra.overall - rb.overall, ra, rb
		end

		function self.improvement()
			if #self.history < 2 then return 0 end
			return self.history[#self.history].overall - self.history[1].overall
		end

		function self.suggestions(record, limit)
			record = record or self.history[#self.history]
			if not record then return {} end
			local out = {}
			for i = 1, math.min(limit or 3, #record.findings) do
				local finding = record.findings[i]
				local c = self.criteria[finding.criterion]
				local direction = c.direction == "lower" and "reduce" or "raise"
				out[#out + 1] = direction .. " " .. finding.criterion
			end
			return out
		end

		function self.stats() return { criteria = #self.order, evaluations = self.evaluations,
			passes = self.passes, rejects = self.rejects, passMark = self.passMark,
			history = #self.history, improvement = self.improvement() } end
		return self
	end

	K.NAMES = { "intent", "knowledge", "workflow", "critic" }
	return K
end
