-- ARKHER RUNTIME :: NPC / Neural Mind Network / World Simulation Kits
-- Round 6 machinery (kits 68-81). Same contract as the other kit modules: complete working
-- implementations that catalog systems specialize. Everything here is deterministic and
-- budgeted - a mind that cannot be measured cannot be shipped to a phone.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 68. MINDNET
	-- ARKHER Neural Mind Network: a small deterministic network with a persistent hidden
	-- state (the "mood memory" of the agent), reward-driven online learning and a decision
	-- head that scores actions. It is intentionally tiny: it must run for hundreds of NPCs.
	function K.mindnet(cfg)
		local self = { kind = "mindnet", id = cfg.id, inputs = cfg.inputs or 6,
			hidden = cfg.hidden or 5, actions = {}, actionOrder = {},
			wih = {}, whh = {}, who = {}, bh = {}, bo = {}, state = {},
			learningRate = cfg.learningRate or 0.08, decay = cfg.decay or 0.9,
			rng = Random.new(cfg.seed or 1337), forwards = 0, updates = 0,
			reward = 0, rewardTotal = 0, exploration = cfg.exploration or 0.05 }

		local function initMatrix(rows, cols, rng)
			local m = {}
			for r = 1, rows do
				m[r] = {}
				for c = 1, cols do m[r][c] = (rng:next() - 0.5) * 0.8 end
			end
			return m
		end

		function self.addAction(name, bias)
			if self.actions[name] then return false end
			self.actions[name] = { name = name, bias = bias or 0, chosen = 0, value = 0 }
			self.actionOrder[#self.actionOrder + 1] = name
			self.who[#self.actionOrder] = {}
			for h = 1, self.hidden do self.who[#self.actionOrder][h] = (self.rng:next() - 0.5) * 0.8 end
			self.bo[#self.actionOrder] = bias or 0
			return true
		end

		function self.build()
			if #self.wih > 0 then return self end
			self.wih = initMatrix(self.hidden, self.inputs, self.rng)
			self.whh = initMatrix(self.hidden, self.hidden, self.rng)
			for h = 1, self.hidden do
				self.bh[h] = 0
				self.state[h] = 0
			end
			return self
		end

		-- One forward pass: inputs + previous hidden state -> hidden -> action scores.
		function self.forward(inputs)
			self.build()
			self.forwards = self.forwards + 1
			local nextState = {}
			for h = 1, self.hidden do
				local sum = self.bh[h]
				for i = 1, self.inputs do
					sum = sum + (self.wih[h][i] or 0) * (inputs[i] or 0)
				end
				for k = 1, self.hidden do
					sum = sum + (self.whh[h][k] or 0) * self.state[k] * self.decay
				end
				nextState[h] = Mathx.tanh(sum)
			end
			self.state = nextState
			local scores = {}
			for a = 1, #self.actionOrder do
				local sum = self.bo[a] or 0
				for h = 1, self.hidden do sum = sum + (self.who[a][h] or 0) * self.state[h] end
				local name = self.actionOrder[a]
				scores[name] = sum
				self.actions[name].value = sum
			end
			return scores, self.state
		end

		function self.decide(inputs)
			local scores = self.forward(inputs)
			local bestName, bestScore = nil, -math.huge
			for _, name in ipairs(self.actionOrder) do
				local jitter = (self.rng:next() - 0.5) * 2 * self.exploration
				local score = scores[name] + jitter
				if score > bestScore then bestScore = score bestName = name end
			end
			if bestName then
				self.actions[bestName].chosen = self.actions[bestName].chosen + 1
				self.lastAction = bestName
			end
			return bestName, bestScore, scores
		end

		-- Reward learning: reinforce the weights that produced the last decision.
		function self.reinforce(reward)
			if not self.lastAction then return 0 end
			self.updates = self.updates + 1
			self.reward = reward
			self.rewardTotal = self.rewardTotal + reward
			local index = nil
			for a, name in ipairs(self.actionOrder) do
				if name == self.lastAction then index = a break end
			end
			if not index then return 0 end
			local delta = self.learningRate * reward
			for h = 1, self.hidden do
				self.who[index][h] = Mathx.clamp(self.who[index][h] + delta * self.state[h], -4, 4)
			end
			self.bo[index] = Mathx.clamp((self.bo[index] or 0) + delta * 0.25, -4, 4)
			return delta
		end

		function self.resetState()
			for h = 1, self.hidden do self.state[h] = 0 end
			return self.hidden
		end

		function self.parameters()
			return self.hidden * self.inputs + self.hidden * self.hidden + self.hidden
				+ #self.actionOrder * (self.hidden + 1)
		end

		function self.exportWeights()
			self.build()
			local out = {}
			for h = 1, self.hidden do
				for i = 1, self.inputs do out[#out + 1] = self.wih[h][i] end
			end
			for h = 1, self.hidden do
				for k = 1, self.hidden do out[#out + 1] = self.whh[h][k] end
			end
			for h = 1, self.hidden do out[#out + 1] = self.bh[h] end
			for a = 1, #self.actionOrder do
				for h = 1, self.hidden do out[#out + 1] = self.who[a][h] end
				out[#out + 1] = self.bo[a]
			end
			return out
		end

		function self.importWeights(list)
			self.build()
			local n = 0
			for h = 1, self.hidden do
				for i = 1, self.inputs do n = n + 1 self.wih[h][i] = list[n] or self.wih[h][i] end
			end
			for h = 1, self.hidden do
				for k = 1, self.hidden do n = n + 1 self.whh[h][k] = list[n] or self.whh[h][k] end
			end
			for h = 1, self.hidden do n = n + 1 self.bh[h] = list[n] or self.bh[h] end
			for a = 1, #self.actionOrder do
				for h = 1, self.hidden do n = n + 1 self.who[a][h] = list[n] or self.who[a][h] end
				n = n + 1
				self.bo[a] = list[n] or self.bo[a]
			end
			return n
		end

		function self.memoryBytes() return self.parameters() * 4 + self.hidden * 8 end

		function self.stats() return { actions = #self.actionOrder, hidden = self.hidden,
			forwards = self.forwards, updates = self.updates, parameters = self.parameters(),
			rewardTotal = self.rewardTotal, lastAction = self.lastAction } end
		return self
	end

	------------------------------------------------------------------ 69. MEMORY
	-- Episodic memory with salience, decay, recall and consolidation into semantic facts.
	function K.memory(cfg)
		local self = { kind = "memory", id = cfg.id, episodes = {}, facts = {},
			capacity = cfg.capacity or 64, decayRate = cfg.decayRate or 0.05,
			consolidateAt = cfg.consolidateAt or 3, time = 0, written = 0,
			recalls = 0, forgotten = 0, consolidated = 0 }

		function self.remember(kind, payload, salience, position)
			self.written = self.written + 1
			local episode = { id = self.written, kind = kind, payload = payload or {},
				salience = clamp01(salience or 0.5), time = self.time,
				position = position, recalls = 0 }
			self.episodes[#self.episodes + 1] = episode
			if #self.episodes > self.capacity then
				-- forget the weakest memory, not the oldest: salience is what survives
				local weakest, index = math.huge, 1
				for i, e in ipairs(self.episodes) do
					if e.salience < weakest then weakest = e.salience index = i end
				end
				table.remove(self.episodes, index)
				self.forgotten = self.forgotten + 1
			end
			return episode
		end

		function self.tick(dt)
			self.time = self.time + dt
			for _, e in ipairs(self.episodes) do
				e.salience = math.max(0, e.salience - self.decayRate * dt * (1 / (1 + e.recalls)))
			end
			return #self.episodes
		end

		function self.recall(kind, minSalience)
			self.recalls = self.recalls + 1
			local out = {}
			for _, e in ipairs(self.episodes) do
				if (not kind or e.kind == kind) and e.salience >= (minSalience or 0) then
					e.recalls = e.recalls + 1
					e.salience = clamp01(e.salience + 0.05)
					out[#out + 1] = e
				end
			end
			table.sort(out, function(a, b) return a.salience > b.salience end)
			return out
		end

		function self.recallNear(position, radius)
			self.recalls = self.recalls + 1
			local out = {}
			for _, e in ipairs(self.episodes) do
				if e.position and e.position:distance(position) <= radius then out[#out + 1] = e end
			end
			return out
		end

		function self.strongest(kind)
			local list = self.recall(kind, 0)
			return list[1]
		end

		-- Consolidation: repeated episodes of the same kind become a durable fact.
		function self.consolidate()
			local counts = {}
			for _, e in ipairs(self.episodes) do counts[e.kind] = (counts[e.kind] or 0) + 1 end
			local made = 0
			for kind, count in pairs(counts) do
				if count >= self.consolidateAt and not self.facts[kind] then
					self.facts[kind] = { kind = kind, confidence = clamp01(count / self.capacity + 0.3),
						learnedAt = self.time, evidence = count }
					self.consolidated = self.consolidated + 1
					made = made + 1
				end
			end
			return made
		end

		function self.knows(kind) return self.facts[kind] ~= nil end
		function self.factCount() return C.count(self.facts) end

		function self.forget(kind)
			local removed = 0
			for i = #self.episodes, 1, -1 do
				if self.episodes[i].kind == kind then
					table.remove(self.episodes, i)
					removed = removed + 1
					self.forgotten = self.forgotten + 1
				end
			end
			return removed
		end

		function self.stats() return { episodes = #self.episodes, facts = self.factCount(),
			written = self.written, recalls = self.recalls, forgotten = self.forgotten,
			consolidated = self.consolidated, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 70. NEED
	-- Drives that decay over time and generate urgency: the reason an NPC does anything.
	function K.need(cfg)
		local self = { kind = "need", id = cfg.id, needs = {}, order = {}, time = 0,
			ticks = 0, satisfactions = 0, criticals = 0 }

		function self.define(name, opts)
			opts = opts or {}
			if self.needs[name] then return nil, "duplicate need" end
			local need = { name = name, value = clamp01(opts.value or 0.5),
				decay = opts.decay or 0.02, weight = opts.weight or 1,
				threshold = opts.threshold or 0.35, critical = opts.critical or 0.12,
				satisfied = 0 }
			self.needs[name] = need
			self.order[#self.order + 1] = name
			return need
		end

		function self.tick(dt)
			self.ticks = self.ticks + 1
			self.time = self.time + dt
			local critical = 0
			for _, name in ipairs(self.order) do
				local need = self.needs[name]
				need.value = clamp01(need.value - need.decay * dt)
				if need.value <= need.critical then critical = critical + 1 end
			end
			self.criticals = self.criticals + critical
			return critical
		end

		function self.satisfy(name, amount)
			local need = self.needs[name]
			if not need then return nil, "unknown need" end
			need.value = clamp01(need.value + (amount or 0.3))
			need.satisfied = need.satisfied + 1
			self.satisfactions = self.satisfactions + 1
			return need.value
		end

		function self.urgency(name)
			local need = self.needs[name]
			if not need then return 0 end
			if need.value >= need.threshold then return 0 end
			return clamp01((need.threshold - need.value) / math.max(1e-6, need.threshold)) * need.weight
		end

		function self.mostUrgent()
			local bestName, best = nil, 0
			for _, name in ipairs(self.order) do
				local u = self.urgency(name)
				if u > best then best = u bestName = name end
			end
			return bestName, best
		end

		function self.vector()
			local out = {}
			for i, name in ipairs(self.order) do out[i] = self.needs[name].value end
			return out
		end

		function self.wellbeing()
			if #self.order == 0 then return 1 end
			local total = 0
			for _, name in ipairs(self.order) do total = total + self.needs[name].value end
			return total / #self.order
		end

		function self.stats() return { needs = #self.order, wellbeing = self.wellbeing(),
			ticks = self.ticks, satisfactions = self.satisfactions, criticals = self.criticals,
			urgent = select(1, self.mostUrgent()) } end
		return self
	end

	------------------------------------------------------------------ 71. EMOTION
	-- Valence/arousal affect with appraisal, mood inertia and decay toward baseline.
	function K.emotion(cfg)
		local self = { kind = "emotion", id = cfg.id, valence = 0, arousal = 0,
			baselineValence = cfg.baselineValence or 0, baselineArousal = cfg.baselineArousal or 0.2,
			inertia = cfg.inertia or 0.85, decayRate = cfg.decayRate or 0.35,
			appraisals = 0, ticks = 0, peakArousal = 0, history = {} }

		local LABELS = {
			{ name = "joy",      valence = 0.7,  arousal = 0.6 },
			{ name = "content",  valence = 0.5,  arousal = -0.2 },
			{ name = "calm",     valence = 0.05, arousal = -0.25 },
			{ name = "bored",    valence = -0.2, arousal = -0.7 },
			{ name = "sad",      valence = -0.6, arousal = -0.3 },
			{ name = "fear",     valence = -0.6, arousal = 0.7 },
			{ name = "anger",    valence = -0.5, arousal = 0.8 },
			{ name = "surprise", valence = 0.1,  arousal = 0.9 },
		}

		-- Appraisal: an event with a desirability and an intensity moves the affect state.
		function self.appraise(desirability, intensity)
			self.appraisals = self.appraisals + 1
			local strength = clamp01(intensity or 0.5)
			self.valence = Mathx.clamp(self.valence * self.inertia
				+ (desirability or 0) * strength, -1, 1)
			self.arousal = Mathx.clamp(self.arousal * self.inertia
				+ math.abs(desirability or 0) * strength, -1, 1)
			if self.arousal > self.peakArousal then self.peakArousal = self.arousal end
			self.history[#self.history + 1] = { valence = self.valence, arousal = self.arousal }
			if #self.history > 32 then table.remove(self.history, 1) end
			return self.valence, self.arousal
		end

		function self.tick(dt)
			self.ticks = self.ticks + 1
			self.valence = self.valence + (self.baselineValence - self.valence) * self.decayRate * dt
			self.arousal = self.arousal + (self.baselineArousal - self.arousal) * self.decayRate * dt
			return self.valence, self.arousal
		end

		function self.label()
			local bestName, bestDistance = "calm", math.huge
			for _, entry in ipairs(LABELS) do
				local dv = entry.valence - self.valence
				local da = entry.arousal - self.arousal
				local d = dv * dv + da * da
				if d < bestDistance then bestDistance = d bestName = entry.name end
			end
			return bestName, math.sqrt(bestDistance)
		end

		function self.intensity() return math.sqrt(self.valence * self.valence + self.arousal * self.arousal) end

		function self.mood()
			if #self.history == 0 then return self.valence end
			local total = 0
			for _, h in ipairs(self.history) do total = total + h.valence end
			return total / #self.history
		end

		function self.influence(baseValue)
			-- positive affect makes an NPC bolder, negative makes it cautious
			return baseValue * (1 + self.valence * 0.35 + self.arousal * 0.15)
		end

		function self.reset()
			self.valence = self.baselineValence
			self.arousal = self.baselineArousal
			self.history = {}
			return true
		end

		function self.stats() return { valence = self.valence, arousal = self.arousal,
			label = select(1, self.label()), mood = self.mood(), intensity = self.intensity(),
			appraisals = self.appraisals, ticks = self.ticks, peakArousal = self.peakArousal } end
		return self
	end

	------------------------------------------------------------------ 72. PERCEPTION
	-- Sight cone, hearing radius, salience and a bounded attention list.
	function K.perception(cfg)
		local self = { kind = "perception", id = cfg.id, position = cfg.position or v3(),
			facing = cfg.facing or v3(0, 0, 1), sightRange = cfg.sightRange or 40,
			fov = cfg.fov or math.rad(110), hearingRange = cfg.hearingRange or 25,
			attentionSlots = cfg.attentionSlots or 4, stimuli = {}, attention = {},
			scans = 0, seen = 0, heard = 0, ignored = 0 }

		function self.place(position, facing)
			self.position = position or self.position
			self.facing = facing or self.facing
			return self.position
		end

		function self.canSee(target, occluded)
			local delta = target - self.position
			local distance = delta:length()
			if distance > self.sightRange then return false, distance end
			if occluded then return false, distance end
			if distance < 1e-6 then return true, 0 end
			local angle = self.facing:unit():angleTo(delta:unit())
			return angle <= self.fov * 0.5, distance, angle
		end

		function self.canHear(source, loudness)
			local distance = source:distance(self.position)
			local range = self.hearingRange * (0.5 + clamp01(loudness or 0.5))
			return distance <= range, distance
		end

		-- Salience: near, loud, moving and emotionally charged things win attention.
		function self.salience(entry)
			local distance = entry.position:distance(self.position)
			local proximity = 1 - clamp01(distance / math.max(1e-6, self.sightRange))
			return clamp01(proximity * 0.5 + (entry.intensity or 0.5) * 0.3
				+ (entry.threat or 0) * 0.2)
		end

		function self.submit(id, position, opts)
			opts = opts or {}
			local entry = { id = id, position = position, intensity = opts.intensity or 0.5,
				threat = opts.threat or 0, kind = opts.kind or "object", loudness = opts.loudness }
			self.stimuli[#self.stimuli + 1] = entry
			return entry
		end

		function self.scan(occlusionFn)
			self.scans = self.scans + 1
			local perceived = {}
			for _, entry in ipairs(self.stimuli) do
				local occluded = occlusionFn and occlusionFn(entry) or false
				local visible, distance = self.canSee(entry.position, occluded)
				local audible = select(1, self.canHear(entry.position, entry.loudness))
				if visible or audible then
					if visible then self.seen = self.seen + 1 else self.heard = self.heard + 1 end
					entry.distance = distance
					entry.visible = visible
					entry.audible = audible
					entry.salience = self.salience(entry)
					perceived[#perceived + 1] = entry
				else
					self.ignored = self.ignored + 1
				end
			end
			table.sort(perceived, function(a, b) return a.salience > b.salience end)
			self.attention = {}
			for i = 1, math.min(self.attentionSlots, #perceived) do
				self.attention[i] = perceived[i]
			end
			return self.attention, #perceived
		end

		function self.focus()
			return self.attention[1]
		end

		function self.clear()
			local n = #self.stimuli
			self.stimuli = {}
			self.attention = {}
			return n
		end

		function self.stats() return { stimuli = #self.stimuli, attention = #self.attention,
			scans = self.scans, seen = self.seen, heard = self.heard, ignored = self.ignored,
			focus = self.attention[1] and self.attention[1].id or nil } end
		return self
	end

	------------------------------------------------------------------ 73. BEHAVIORTREE
	-- Selector / sequence / parallel / decorator / action with running state and a blackboard.
	function K.behaviortree(cfg)
		local self = { kind = "behaviortree", id = cfg.id, nodes = {}, order = {},
			root = nil, blackboard = {}, ticks = 0, successes = 0, failures = 0,
			running = 0, lastStatus = "idle" }

		function self.addNode(id, nodeType, opts)
			opts = opts or {}
			if self.nodes[id] then return nil, "duplicate node" end
			local node = { id = id, type = nodeType, children = {}, action = opts.action,
				condition = opts.condition, invert = opts.invert or false,
				repeatCount = opts.repeatCount, cooldown = opts.cooldown or 0,
				timer = 0, runs = 0, lastStatus = "idle" }
			self.nodes[id] = node
			self.order[#self.order + 1] = id
			if not self.root then self.root = id end
			return node
		end

		function self.attach(parentId, childId)
			local parent = self.nodes[parentId]
			local child = self.nodes[childId]
			if not parent or not child then return false end
			parent.children[#parent.children + 1] = childId
			child.parent = parentId
			return true
		end

		function self.setRoot(id)
			if not self.nodes[id] then return false end
			self.root = id
			return true
		end

		function self.set(key, value) self.blackboard[key] = value return value end
		function self.get(key) return self.blackboard[key] end

		local function tickNode(node, dt, tree)
			node.runs = node.runs + 1
			local status
			if node.type == "action" then
				status = node.action and node.action(tree.blackboard, dt) or "success"
			elseif node.type == "condition" then
				local ok = node.condition and node.condition(tree.blackboard) or false
				status = ok and "success" or "failure"
			elseif node.type == "inverter" then
				local child = tree.nodes[node.children[1]]
				local inner = child and tickNode(child, dt, tree) or "failure"
				if inner == "success" then status = "failure"
				elseif inner == "failure" then status = "success"
				else status = inner end
			elseif node.type == "cooldown" then
				node.timer = math.max(0, node.timer - dt)
				if node.timer > 0 then
					status = "failure"
				else
					local child = tree.nodes[node.children[1]]
					status = child and tickNode(child, dt, tree) or "failure"
					if status == "success" then node.timer = node.cooldown end
				end
			elseif node.type == "sequence" then
				status = "success"
				for _, childId in ipairs(node.children) do
					local child = tree.nodes[childId]
					local inner = child and tickNode(child, dt, tree) or "failure"
					if inner ~= "success" then status = inner break end
				end
			elseif node.type == "selector" then
				status = "failure"
				for _, childId in ipairs(node.children) do
					local child = tree.nodes[childId]
					local inner = child and tickNode(child, dt, tree) or "failure"
					if inner ~= "failure" then status = inner break end
				end
			elseif node.type == "parallel" then
				local succeeded, running = 0, 0
				for _, childId in ipairs(node.children) do
					local child = tree.nodes[childId]
					local inner = child and tickNode(child, dt, tree) or "failure"
					if inner == "success" then succeeded = succeeded + 1 end
					if inner == "running" then running = running + 1 end
				end
				if succeeded == #node.children then status = "success"
				elseif running > 0 then status = "running"
				else status = "failure" end
			else
				status = "failure"
			end
			node.lastStatus = status
			return status
		end

		function self.tick(dt)
			self.ticks = self.ticks + 1
			if not self.root then return "failure" end
			local status = tickNode(self.nodes[self.root], dt or (1 / 30), self)
			self.lastStatus = status
			if status == "success" then self.successes = self.successes + 1
			elseif status == "failure" then self.failures = self.failures + 1
			else self.running = self.running + 1 end
			return status
		end

		function self.depth(id)
			local node = self.nodes[id or self.root]
			if not node then return 0 end
			local best = 0
			for _, childId in ipairs(node.children) do
				local d = self.depth(childId)
				if d > best then best = d end
			end
			return best + 1
		end

		function self.reset()
			for _, id in ipairs(self.order) do
				self.nodes[id].timer = 0
				self.nodes[id].lastStatus = "idle"
			end
			return #self.order
		end

		function self.stats() return { nodes = #self.order, depth = self.depth(),
			ticks = self.ticks, successes = self.successes, failures = self.failures,
			running = self.running, lastStatus = self.lastStatus } end
		return self
	end

	------------------------------------------------------------------ 74. UTILITY
	-- Utility AI: considerations with response curves, combined into one score per option.
	function K.utility(cfg)
		local self = { kind = "utility", id = cfg.id, options = {}, order = {},
			evaluations = 0, selections = 0, momentum = cfg.momentum or 0.1, last = nil }

		local function curve(shape, x, exponent)
			x = clamp01(x)
			if shape == "linear" then return x end
			if shape == "quadratic" then return x ^ (exponent or 2) end
			if shape == "inverse" then return 1 - x end
			if shape == "logistic" then return 1 / (1 + math.exp(-12 * (x - 0.5))) end
			if shape == "threshold" then return x >= (exponent or 0.5) and 1 or 0 end
			return x
		end

		function self.addOption(name, opts)
			opts = opts or {}
			if self.options[name] then return nil, "duplicate option" end
			local option = { name = name, considerations = {}, weight = opts.weight or 1,
				cooldown = opts.cooldown or 0, timer = 0, score = 0, chosen = 0 }
			self.options[name] = option
			self.order[#self.order + 1] = name
			return option
		end

		function self.addConsideration(optionName, name, getter, shape, exponent)
			local option = self.options[optionName]
			if not option then return nil, "unknown option" end
			option.considerations[#option.considerations + 1] = { name = name, get = getter,
				shape = shape or "linear", exponent = exponent }
			return option
		end

		-- Score with compensation: many considerations must not always beat few.
		function self.score(optionName, ctx)
			local option = self.options[optionName]
			if not option then return 0 end
			local n = #option.considerations
			if n == 0 then return option.weight end
			local product = 1
			for _, cons in ipairs(option.considerations) do
				local raw = cons.get and cons.get(ctx) or 0
				product = product * curve(cons.shape, raw, cons.exponent)
			end
			local modification = (1 - 1 / n) * (1 - product)
			local final = (product + modification * product) * option.weight
			if self.last == optionName then final = final * (1 + self.momentum) end
			option.score = final
			return final
		end

		function self.evaluate(ctx, dt)
			self.evaluations = self.evaluations + 1
			local bestName, bestScore = nil, -1
			for _, name in ipairs(self.order) do
				local option = self.options[name]
				option.timer = math.max(0, option.timer - (dt or 0))
				if option.timer <= 0 then
					local s = self.score(name, ctx)
					if s > bestScore then bestScore = s bestName = name end
				end
			end
			if bestName then
				self.selections = self.selections + 1
				self.options[bestName].chosen = self.options[bestName].chosen + 1
				self.options[bestName].timer = self.options[bestName].cooldown
				self.last = bestName
			end
			return bestName, bestScore
		end

		function self.ranking(ctx)
			local list = {}
			for _, name in ipairs(self.order) do
				list[#list + 1] = { name = name, score = self.score(name, ctx) }
			end
			table.sort(list, function(a, b) return a.score > b.score end)
			return list
		end

		function self.stats() return { options = #self.order, evaluations = self.evaluations,
			selections = self.selections, last = self.last } end
		return self
	end

	------------------------------------------------------------------ 75. PLANNER
	-- GOAP: symbolic actions with preconditions and effects, planned with A* over states.
	function K.planner(cfg)
		local self = { kind = "planner", id = cfg.id, actions = {}, order = {},
			maxDepth = cfg.maxDepth or 8, plans = 0, expansions = 0, failures = 0,
			lastPlan = {} }

		function self.addAction(name, opts)
			opts = opts or {}
			if self.actions[name] then return nil, "duplicate action" end
			local action = { name = name, pre = opts.pre or {}, effects = opts.effects or {},
				cost = opts.cost or 1, used = 0 }
			self.actions[name] = action
			self.order[#self.order + 1] = name
			return action
		end

		local function satisfies(state, requirements)
			for key, value in pairs(requirements) do
				if state[key] ~= value then return false end
			end
			return true
		end

		local function applyEffects(state, effects)
			local out = {}
			for k, v in pairs(state) do out[k] = v end
			for k, v in pairs(effects) do out[k] = v end
			return out
		end

		local function stateKey(state)
			local parts = {}
			for k, v in pairs(state) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
			table.sort(parts)
			return table.concat(parts, ",")
		end

		local function heuristic(state, goal)
			local missing = 0
			for key, value in pairs(goal) do
				if state[key] ~= value then missing = missing + 1 end
			end
			return missing
		end

		-- Best-first search over symbolic world states.
		function self.plan(initial, goal)
			self.plans = self.plans + 1
			local startKey = stateKey(initial)
			local open = { { state = initial, key = startKey, cost = 0, path = {} } }
			local visited = { [startKey] = 0 }
			local best = nil
			local guard = 0
			while #open > 0 and guard < 400 do
				guard = guard + 1
				table.sort(open, function(a, b)
					return (a.cost + heuristic(a.state, goal)) < (b.cost + heuristic(b.state, goal))
				end)
				local current = table.remove(open, 1)
				if satisfies(current.state, goal) then
					best = current
					break
				end
				if #current.path < self.maxDepth then
					for _, name in ipairs(self.order) do
						local action = self.actions[name]
						if satisfies(current.state, action.pre) then
							self.expansions = self.expansions + 1
							local nextState = applyEffects(current.state, action.effects)
							local key = stateKey(nextState)
							local nextCost = current.cost + action.cost
							if visited[key] == nil or nextCost < visited[key] then
								visited[key] = nextCost
								local path = {}
								for i, step in ipairs(current.path) do path[i] = step end
								path[#path + 1] = name
								open[#open + 1] = { state = nextState, key = key,
									cost = nextCost, path = path }
							end
						end
					end
				end
			end
			if not best then
				self.failures = self.failures + 1
				self.lastPlan = {}
				return nil, "no plan"
			end
			for _, name in ipairs(best.path) do self.actions[name].used = self.actions[name].used + 1 end
			self.lastPlan = best.path
			return best.path, best.cost
		end

		function self.planCost(path)
			local total = 0
			for _, name in ipairs(path or self.lastPlan) do
				total = total + (self.actions[name] and self.actions[name].cost or 0)
			end
			return total
		end

		function self.simulate(initial, path)
			local state = initial
			for _, name in ipairs(path or self.lastPlan) do
				local action = self.actions[name]
				if not action or not satisfies(state, action.pre) then return state, false end
				state = applyEffects(state, action.effects)
			end
			return state, true
		end

		function self.stats() return { actions = #self.order, plans = self.plans,
			expansions = self.expansions, failures = self.failures,
			lastPlanLength = #self.lastPlan } end
		return self
	end

	------------------------------------------------------------------ 76. NAVGRAPH
	-- Grid navigation: costs, A* with octile heuristic, line-of-sight smoothing, flow fields.
	function K.navgraph(cfg)
		local self = { kind = "navgraph", id = cfg.id, width = cfg.width or 32,
			height = cfg.height or 32, cellSize = cfg.cellSize or 4, cells = {},
			searches = 0, expansions = 0, failures = 0, smoothings = 0 }

		local function index(x, z) return z * self.width + x end

		function self.inBounds(x, z)
			return x >= 0 and z >= 0 and x < self.width and z < self.height
		end

		function self.setCost(x, z, cost)
			if not self.inBounds(x, z) then return false end
			self.cells[index(x, z)] = cost
			return true
		end

		function self.block(x, z) return self.setCost(x, z, -1) end

		function self.costAt(x, z)
			if not self.inBounds(x, z) then return -1 end
			local c = self.cells[index(x, z)]
			if c == nil then return 1 end
			return c
		end

		function self.walkable(x, z) return self.costAt(x, z) >= 0 end

		function self.toWorld(x, z)
			return v3((x + 0.5) * self.cellSize, 0, (z + 0.5) * self.cellSize)
		end

		function self.toCell(position)
			return math.floor(position.x / self.cellSize), math.floor(position.z / self.cellSize)
		end

		function self.blockRect(x0, z0, x1, z1)
			local n = 0
			for z = z0, z1 do
				for x = x0, x1 do
					if self.block(x, z) then n = n + 1 end
				end
			end
			return n
		end

		local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
			{ 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

		local function octile(ax, az, bx, bz)
			local dx = math.abs(ax - bx)
			local dz = math.abs(az - bz)
			return (dx + dz) + (1.41421356 - 2) * math.min(dx, dz)
		end

		function self.findPath(sx, sz, tx, tz)
			self.searches = self.searches + 1
			if not self.walkable(sx, sz) or not self.walkable(tx, tz) then
				self.failures = self.failures + 1
				return nil, "blocked endpoint"
			end
			local startKey = index(sx, sz)
			local goalKey = index(tx, tz)
			local open = { [startKey] = true }
			local openList = { { key = startKey, x = sx, z = sz, g = 0,
				f = octile(sx, sz, tx, tz) } }
			local cameFrom = {}
			local gScore = { [startKey] = 0 }
			local closed = {}
			local guard = 0
			while #openList > 0 and guard < 6000 do
				guard = guard + 1
				table.sort(openList, function(a, b) return a.f < b.f end)
				local current = table.remove(openList, 1)
				open[current.key] = nil
				if current.key == goalKey then
					local path = { { x = current.x, z = current.z } }
					local key = current.key
					while cameFrom[key] do
						local prev = cameFrom[key]
						table.insert(path, 1, { x = prev.x, z = prev.z })
						key = prev.key
					end
					return path, current.g
				end
				closed[current.key] = true
				for _, offset in ipairs(NEIGHBORS) do
					local nx, nz = current.x + offset[1], current.z + offset[2]
					local cost = self.costAt(nx, nz)
					if cost >= 0 and not closed[index(nx, nz)] then
						self.expansions = self.expansions + 1
						local step = (offset[1] ~= 0 and offset[2] ~= 0) and 1.41421356 or 1
						local tentative = current.g + step * (1 + cost)
						local key = index(nx, nz)
						if gScore[key] == nil or tentative < gScore[key] then
							gScore[key] = tentative
							cameFrom[key] = { key = current.key, x = current.x, z = current.z }
							if not open[key] then
								open[key] = true
								openList[#openList + 1] = { key = key, x = nx, z = nz,
									g = tentative, f = tentative + octile(nx, nz, tx, tz) }
							end
						end
					end
				end
			end
			self.failures = self.failures + 1
			return nil, "unreachable"
		end

		function self.lineOfSight(ax, az, bx, bz)
			local steps = math.max(math.abs(bx - ax), math.abs(bz - az))
			if steps == 0 then return true end
			for i = 0, steps do
				local t = i / steps
				local x = math.floor(ax + (bx - ax) * t + 0.5)
				local z = math.floor(az + (bz - az) * t + 0.5)
				if not self.walkable(x, z) then return false end
			end
			return true
		end

		-- String pulling: remove waypoints the agent can walk straight past.
		function self.smooth(path)
			if not path or #path < 3 then return path end
			self.smoothings = self.smoothings + 1
			local out = { path[1] }
			local anchor = 1
			local i = 2
			while i <= #path do
				if i == #path then
					out[#out + 1] = path[i]
					i = i + 1
				elseif not self.lineOfSight(path[anchor].x, path[anchor].z, path[i + 1].x, path[i + 1].z) then
					out[#out + 1] = path[i]
					anchor = i
					i = i + 1
				else
					i = i + 1
				end
			end
			return out
		end

		function self.worldPath(path)
			local out = {}
			for i, node in ipairs(path or {}) do out[i] = self.toWorld(node.x, node.z) end
			return out
		end

		function self.pathLength(path)
			local total = 0
			for i = 2, #(path or {}) do
				local a, b = path[i - 1], path[i]
				total = total + math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			end
			return total
		end

		-- Flow field: one Dijkstra pass gives every cell a direction toward the goal.
		function self.flowField(tx, tz)
			local dist = {}
			local queue = { { x = tx, z = tz, d = 0 } }
			dist[index(tx, tz)] = 0
			local head = 1
			while head <= #queue do
				local current = queue[head]
				head = head + 1
				for _, offset in ipairs(NEIGHBORS) do
					local nx, nz = current.x + offset[1], current.z + offset[2]
					local cost = self.costAt(nx, nz)
					if cost >= 0 then
						local key = index(nx, nz)
						local nd = current.d + 1 + cost
						if dist[key] == nil or nd < dist[key] then
							dist[key] = nd
							queue[#queue + 1] = { x = nx, z = nz, d = nd }
						end
					end
				end
			end
			return { distance = dist, goal = { x = tx, z = tz },
				direction = function(x, z)
					local best, bx, bz = dist[index(x, z)] or math.huge, x, z
					for _, offset in ipairs(NEIGHBORS) do
						local nx, nz = x + offset[1], z + offset[2]
						local d = dist[index(nx, nz)]
						if d and d < best then best = d bx = nx bz = nz end
					end
					return v3(bx - x, 0, bz - z), best
				end }
		end

		function self.stats() return { width = self.width, height = self.height,
			searches = self.searches, expansions = self.expansions, failures = self.failures,
			smoothings = self.smoothings, blocked = C.count(self.cells) } end
		return self
	end

	------------------------------------------------------------------ 77. CROWD
	-- Steering behaviours with neighbour avoidance over a spatial hash: crowds that flow.
	function K.crowd(cfg)
		local self = { kind = "crowd", id = cfg.id, agents = {}, order = {},
			hash = Spatial.spatialHash(cfg.cellSize or 8), radius = cfg.radius or 0.5,
			maxSpeed = cfg.maxSpeed or 4, maxForce = cfg.maxForce or 12,
			separationWeight = cfg.separationWeight or 1.6,
			cohesionWeight = cfg.cohesionWeight or 0.25,
			alignmentWeight = cfg.alignmentWeight or 0.4,
			steps = 0, neighborChecks = 0, collisionsAvoided = 0 }

		function self.add(id, position, opts)
			opts = opts or {}
			if self.agents[id] then return nil, "duplicate agent" end
			local agent = { id = id, position = position or v3(), velocity = v3(),
				target = opts.target, radius = opts.radius or self.radius,
				maxSpeed = opts.maxSpeed or self.maxSpeed, arrived = false, group = opts.group }
			self.agents[id] = agent
			self.order[#self.order + 1] = id
			self.hash:insert(id, agent.position)
			return agent
		end

		function self.remove(id)
			if not self.agents[id] then return false end
			self.hash:remove(id)
			self.agents[id] = nil
			for i, k in ipairs(self.order) do
				if k == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.setTarget(id, target)
			local agent = self.agents[id]
			if not agent then return false end
			agent.target = target
			agent.arrived = false
			return true
		end

		function self.seek(agent, target)
			local desired = target - agent.position
			local distance = desired:length()
			if distance < 1e-6 then return v3() end
			local speed = agent.maxSpeed
			if distance < 3 then speed = agent.maxSpeed * (distance / 3) end
			return (desired * (1 / distance) * speed - agent.velocity):clampMagnitude(self.maxForce)
		end

		function self.neighbors(agent, radius)
			local out = {}
			for _, entry in ipairs(self.hash:queryRadius(agent.position, radius or 4)) do
				local id = entry.id or entry
				if id ~= agent.id and self.agents[id] then out[#out + 1] = self.agents[id] end
			end
			self.neighborChecks = self.neighborChecks + #out
			return out
		end

		function self.separation(agent, neighbors)
			local force = v3()
			for _, other in ipairs(neighbors) do
				local delta = agent.position - other.position
				local distance = delta:length()
				local minDistance = agent.radius + other.radius
				if distance < minDistance and distance > 1e-6 then
					force = force + delta * (1 / distance) * ((minDistance - distance) / minDistance)
					self.collisionsAvoided = self.collisionsAvoided + 1
				end
			end
			return force:clampMagnitude(self.maxForce)
		end

		function self.cohesion(agent, neighbors)
			if #neighbors == 0 then return v3() end
			local center = v3()
			for _, other in ipairs(neighbors) do center = center + other.position end
			center = center * (1 / #neighbors)
			return self.seek(agent, center) * 0.2
		end

		function self.alignment(agent, neighbors)
			if #neighbors == 0 then return v3() end
			local sum = v3()
			for _, other in ipairs(neighbors) do sum = sum + other.velocity end
			return ((sum * (1 / #neighbors)) - agent.velocity):clampMagnitude(self.maxForce) * 0.5
		end

		function self.step(dt)
			self.steps = self.steps + 1
			for _, id in ipairs(self.order) do
				local agent = self.agents[id]
				local force = v3()
				if agent.target then
					force = force + self.seek(agent, agent.target)
					if agent.position:distance(agent.target) < agent.radius * 1.5 then
						agent.arrived = true
					end
				end
				local neighbors = self.neighbors(agent, agent.radius * 6)
				force = force + self.separation(agent, neighbors) * self.separationWeight
				force = force + self.cohesion(agent, neighbors) * self.cohesionWeight
				force = force + self.alignment(agent, neighbors) * self.alignmentWeight
				agent.velocity = (agent.velocity + force * dt):clampMagnitude(agent.maxSpeed)
				agent.position = agent.position + agent.velocity * dt
				self.hash:update(id, agent.position)
			end
			return #self.order
		end

		function self.arrivedCount()
			local n = 0
			for _, id in ipairs(self.order) do
				if self.agents[id].arrived then n = n + 1 end
			end
			return n
		end

		function self.averageSpeed()
			if #self.order == 0 then return 0 end
			local total = 0
			for _, id in ipairs(self.order) do total = total + self.agents[id].velocity:length() end
			return total / #self.order
		end

		function self.stats() return { agents = #self.order, steps = self.steps,
			arrived = self.arrivedCount(), averageSpeed = self.averageSpeed(),
			neighborChecks = self.neighborChecks, collisionsAvoided = self.collisionsAvoided } end
		return self
	end

	------------------------------------------------------------------ 78. SOCIETY
	-- Relationships, factions, reputation and gossip: the social graph of a living world.
	function K.society(cfg)
		local self = { kind = "society", id = cfg.id, members = {}, memberOrder = {},
			factions = {}, relations = {}, interactions = 0, gossips = 0,
			decayRate = cfg.decayRate or 0.01, gossipReach = cfg.gossipReach or 3 }

		local function key(a, b)
			if a < b then return a .. "|" .. b end
			return b .. "|" .. a
		end

		function self.join(id, opts)
			opts = opts or {}
			if self.members[id] then return nil, "duplicate member" end
			local member = { id = id, faction = opts.faction, reputation = opts.reputation or 0,
				traits = opts.traits or {}, interactions = 0 }
			self.members[id] = member
			self.memberOrder[#self.memberOrder + 1] = id
			if opts.faction then
				self.factions[opts.faction] = self.factions[opts.faction] or { name = opts.faction,
					members = {}, standing = {} }
				table.insert(self.factions[opts.faction].members, id)
			end
			return member
		end

		function self.leave(id)
			if not self.members[id] then return false end
			self.members[id] = nil
			for i, k in ipairs(self.memberOrder) do
				if k == id then table.remove(self.memberOrder, i) break end
			end
			return true
		end

		function self.affinity(a, b)
			local rel = self.relations[key(a, b)]
			if not rel then return 0 end
			return rel.affinity
		end

		function self.interact(a, b, valence, weight)
			if not self.members[a] or not self.members[b] then return nil, "unknown member" end
			self.interactions = self.interactions + 1
			local k = key(a, b)
			local rel = self.relations[k]
			if not rel then
				rel = { a = a, b = b, affinity = 0, trust = 0, count = 0 }
				self.relations[k] = rel
			end
			rel.count = rel.count + 1
			rel.affinity = Mathx.clamp(rel.affinity + (valence or 0) * (weight or 0.15), -1, 1)
			rel.trust = Mathx.clamp(rel.trust + (valence or 0) * (weight or 0.15) * 0.6, -1, 1)
			self.members[a].interactions = self.members[a].interactions + 1
			self.members[b].interactions = self.members[b].interactions + 1
			return rel
		end

		function self.setFactionStanding(a, b, value)
			self.factions[a] = self.factions[a] or { name = a, members = {}, standing = {} }
			self.factions[b] = self.factions[b] or { name = b, members = {}, standing = {} }
			self.factions[a].standing[b] = Mathx.clamp(value, -1, 1)
			self.factions[b].standing[a] = Mathx.clamp(value, -1, 1)
			return value
		end

		function self.disposition(a, b)
			local personal = self.affinity(a, b)
			local ma, mb = self.members[a], self.members[b]
			local factional = 0
			if ma and mb and ma.faction and mb.faction then
				if ma.faction == mb.faction then
					factional = 0.4
				else
					local f = self.factions[ma.faction]
					factional = (f and f.standing[mb.faction]) or 0
				end
			end
			local reputation = mb and Mathx.clamp(mb.reputation, -1, 1) * 0.25 or 0
			return Mathx.clamp(personal * 0.6 + factional * 0.3 + reputation, -1, 1)
		end

		-- Gossip: an opinion propagates through the relationship graph, weakening as it goes.
		function self.gossip(source, about, valence)
			self.gossips = self.gossips + 1
			local reached = {}
			local frontier = { { id = source, strength = 1, depth = 0 } }
			local head = 1
			while head <= #frontier do
				local node = frontier[head]
				head = head + 1
				if node.depth < self.gossipReach and node.strength > 0.05 then
					for _, otherId in ipairs(self.memberOrder) do
						if otherId ~= node.id and otherId ~= about and not reached[otherId] then
							local bond = self.affinity(node.id, otherId)
							if bond > 0.1 then
								reached[otherId] = true
								local member = self.members[about]
								if member then
									member.reputation = Mathx.clamp(member.reputation
										+ valence * node.strength * bond * 0.2, -1, 1)
								end
								frontier[#frontier + 1] = { id = otherId,
									strength = node.strength * bond * 0.6, depth = node.depth + 1 }
							end
						end
					end
				end
			end
			return C.count(reached)
		end

		function self.tick(dt)
			for _, rel in pairs(self.relations) do
				rel.affinity = rel.affinity * (1 - self.decayRate * dt)
				rel.trust = rel.trust * (1 - self.decayRate * dt)
			end
			return C.count(self.relations)
		end

		function self.friendsOf(id, threshold)
			local out = {}
			for _, otherId in ipairs(self.memberOrder) do
				if otherId ~= id and self.affinity(id, otherId) >= (threshold or 0.3) then
					out[#out + 1] = otherId
				end
			end
			table.sort(out)
			return out
		end

		function self.cohesion()
			local total, n = 0, 0
			for _, rel in pairs(self.relations) do
				total = total + rel.affinity
				n = n + 1
			end
			if n == 0 then return 0 end
			return total / n
		end

		function self.stats() return { members = #self.memberOrder,
			factions = C.count(self.factions), relations = C.count(self.relations),
			interactions = self.interactions, gossips = self.gossips,
			cohesion = self.cohesion() } end
		return self
	end

	------------------------------------------------------------------ 79. ECONOMY
	-- Goods, stock, production and prices that move with supply and demand.
	function K.economy(cfg)
		local self = { kind = "economy", id = cfg.id, goods = {}, goodOrder = {},
			markets = {}, marketOrder = {}, elasticity = cfg.elasticity or 0.25,
			ticks = 0, trades = 0, produced = 0, consumed = 0, volume = 0 }

		function self.defineGood(name, opts)
			opts = opts or {}
			if self.goods[name] then return nil, "duplicate good" end
			local good = { name = name, basePrice = opts.basePrice or 10,
				price = opts.basePrice or 10, decay = opts.decay or 0,
				weight = opts.weight or 1 }
			self.goods[name] = good
			self.goodOrder[#self.goodOrder + 1] = name
			return good
		end

		function self.addMarket(id, opts)
			opts = opts or {}
			if self.markets[id] then return nil, "duplicate market" end
			local market = { id = id, stock = {}, demand = {}, production = {},
				wealth = opts.wealth or 1000, position = opts.position or v3() }
			self.markets[id] = market
			self.marketOrder[#self.marketOrder + 1] = id
			return market
		end

		function self.setStock(marketId, good, amount)
			local market = self.markets[marketId]
			if not market then return nil, "unknown market" end
			market.stock[good] = math.max(0, amount)
			return market.stock[good]
		end

		function self.setProduction(marketId, good, rate)
			local market = self.markets[marketId]
			if not market then return nil, "unknown market" end
			market.production[good] = rate
			return rate
		end

		function self.setDemand(marketId, good, rate)
			local market = self.markets[marketId]
			if not market then return nil, "unknown market" end
			market.demand[good] = rate
			return rate
		end

		function self.totalStock(good)
			local total = 0
			for _, id in ipairs(self.marketOrder) do
				total = total + (self.markets[id].stock[good] or 0)
			end
			return total
		end

		function self.totalDemand(good)
			local total = 0
			for _, id in ipairs(self.marketOrder) do
				total = total + (self.markets[id].demand[good] or 0)
			end
			return total
		end

		-- Price discovery: scarcity raises price, surplus lowers it, elasticity damps both.
		function self.updatePrices()
			for _, name in ipairs(self.goodOrder) do
				local good = self.goods[name]
				local supply = self.totalStock(name)
				local demand = math.max(0.001, self.totalDemand(name) * 10)
				local ratio = demand / math.max(0.001, supply + demand * 0.5)
				local target = good.basePrice * (0.5 + ratio)
				good.price = good.price + (target - good.price) * self.elasticity
				good.price = math.max(0.1, good.price)
			end
			return #self.goodOrder
		end

		function self.priceOf(good)
			return self.goods[good] and self.goods[good].price or 0
		end

		function self.tick(dt)
			self.ticks = self.ticks + 1
			for _, id in ipairs(self.marketOrder) do
				local market = self.markets[id]
				for good, rate in pairs(market.production) do
					market.stock[good] = (market.stock[good] or 0) + rate * dt
					self.produced = self.produced + rate * dt
				end
				for good, rate in pairs(market.demand) do
					local available = market.stock[good] or 0
					local wanted = rate * dt
					local taken = math.min(available, wanted)
					market.stock[good] = available - taken
					self.consumed = self.consumed + taken
					market.unmet = market.unmet or {}
					market.unmet[good] = wanted - taken
				end
			end
			self.updatePrices()
			return self.ticks
		end

		-- Trade: goods flow from the surplus market to the deficit market, for money.
		function self.trade(fromId, toId, good, amount)
			local from, to = self.markets[fromId], self.markets[toId]
			if not from or not to then return nil, "unknown market" end
			local available = from.stock[good] or 0
			local moved = math.min(available, amount)
			if moved <= 0 then return 0 end
			local price = self.priceOf(good) * moved
			if to.wealth < price then
				moved = moved * (to.wealth / math.max(0.001, price))
				price = to.wealth
			end
			from.stock[good] = (from.stock[good] or 0) - moved
			to.stock[good] = (to.stock[good] or 0) + moved
			from.wealth = from.wealth + price
			to.wealth = to.wealth - price
			self.trades = self.trades + 1
			self.volume = self.volume + price
			return moved, price
		end

		-- Autonomous balancing: every deficit market buys from the nearest surplus market.
		function self.balance()
			local moves = 0
			for _, good in ipairs(self.goodOrder) do
				local surplus, deficit = nil, nil
				local best, worst = -math.huge, math.huge
				for _, id in ipairs(self.marketOrder) do
					local market = self.markets[id]
					local net = (market.stock[good] or 0) - (market.demand[good] or 0) * 10
					if net > best then best = net surplus = id end
					if net < worst then worst = net deficit = id end
				end
				if surplus and deficit and surplus ~= deficit and best > 0 and worst < 0 then
					local moved = self.trade(surplus, deficit, good, math.min(best, -worst) * 0.5)
					if moved and moved > 0 then moves = moves + 1 end
				end
			end
			return moves
		end

		function self.stats() return { goods = #self.goodOrder, markets = #self.marketOrder,
			ticks = self.ticks, trades = self.trades, volume = self.volume,
			produced = self.produced, consumed = self.consumed } end
		return self
	end

	------------------------------------------------------------------ 80. SCHEDULE
	-- Daily routines: what an NPC should be doing at this hour, and what overrides it.
	function K.schedule(cfg)
		local self = { kind = "schedule", id = cfg.id, slots = {}, overrides = {},
			dayLength = cfg.dayLength or 24, time = cfg.startHour or 8, day = 1,
			ticks = 0, changes = 0, current = nil, interruptions = 0 }

		function self.addSlot(activity, fromHour, toHour, opts)
			opts = opts or {}
			local slot = { activity = activity, from = fromHour % self.dayLength,
				to = toHour % self.dayLength, priority = opts.priority or 1,
				location = opts.location, days = opts.days, runs = 0 }
			self.slots[#self.slots + 1] = slot
			return slot
		end

		function self.activeAt(hour, day)
			hour = hour % self.dayLength
			local best, bestPriority = nil, -math.huge
			for _, slot in ipairs(self.slots) do
				local inWindow
				if slot.from <= slot.to then
					inWindow = hour >= slot.from and hour < slot.to
				else
					inWindow = hour >= slot.from or hour < slot.to
				end
				local dayOk = true
				if slot.days then
					dayOk = false
					for _, d in ipairs(slot.days) do
						if d == ((day or self.day) % 7) then dayOk = true break end
					end
				end
				if inWindow and dayOk and slot.priority > bestPriority then
					best = slot
					bestPriority = slot.priority
				end
			end
			return best
		end

		function self.interrupt(activity, hours, priority)
			self.interruptions = self.interruptions + 1
			self.overrides[#self.overrides + 1] = { activity = activity,
				remaining = hours or 1, priority = priority or 10 }
			return #self.overrides
		end

		function self.advance(hours)
			self.ticks = self.ticks + 1
			self.time = self.time + hours
			while self.time >= self.dayLength do
				self.time = self.time - self.dayLength
				self.day = self.day + 1
			end
			for i = #self.overrides, 1, -1 do
				self.overrides[i].remaining = self.overrides[i].remaining - hours
				if self.overrides[i].remaining <= 0 then table.remove(self.overrides, i) end
			end
			local previous = self.current
			local override = nil
			for _, o in ipairs(self.overrides) do
				if not override or o.priority > override.priority then override = o end
			end
			if override then
				self.current = override.activity
			else
				local slot = self.activeAt(self.time, self.day)
				self.current = slot and slot.activity or nil
				if slot then slot.runs = slot.runs + 1 end
			end
			if self.current ~= previous then self.changes = self.changes + 1 end
			return self.current, self.time, self.day
		end

		function self.isNight()
			return self.time < 6 or self.time >= 20
		end

		function self.nextActivity()
			local hour = self.time
			for step = 1, self.dayLength do
				local slot = self.activeAt(hour + step, self.day)
				if slot and slot.activity ~= self.current then
					return slot.activity, (hour + step) % self.dayLength
				end
			end
			return nil
		end

		function self.locationFor(activity)
			for _, slot in ipairs(self.slots) do
				if slot.activity == activity then return slot.location end
			end
			return nil
		end

		function self.stats() return { slots = #self.slots, current = self.current,
			hour = self.time, day = self.day, changes = self.changes,
			overrides = #self.overrides, interruptions = self.interruptions,
			night = self.isNight() } end
		return self
	end

	------------------------------------------------------------------ 81. ECOLOGY
	-- Populations with logistic growth, predator-prey coupling and harvesting.
	function K.ecology(cfg)
		local self = { kind = "ecology", id = cfg.id, species = {}, order = {},
			links = {}, ticks = 0, extinctions = 0, harvested = 0, time = 0 }

		function self.addSpecies(name, opts)
			opts = opts or {}
			if self.species[name] then return nil, "duplicate species" end
			local sp = { name = name, population = opts.population or 100,
				growth = opts.growth or 0.15, capacity = opts.capacity or 1000,
				minimum = opts.minimum or 1, extinct = false, history = {} }
			self.species[name] = sp
			self.order[#self.order + 1] = name
			return sp
		end

		function self.link(predator, prey, opts)
			opts = opts or {}
			if not self.species[predator] or not self.species[prey] then
				return nil, "unknown species"
			end
			local link = { predator = predator, prey = prey,
				predation = opts.predation or 0.0006, efficiency = opts.efficiency or 0.4 }
			self.links[#self.links + 1] = link
			return link
		end

		function self.populationOf(name)
			local sp = self.species[name]
			if not sp then return 0 end
			return sp.population
		end

		-- One step of a discrete Lotka-Volterra system with a carrying capacity.
		function self.step(dt)
			self.ticks = self.ticks + 1
			self.time = self.time + dt
			local delta = {}
			for _, name in ipairs(self.order) do
				local sp = self.species[name]
				-- species with a negative intrinsic rate simply decay: a carrying
				-- capacity must never turn starvation into growth.
				local logistic
				if sp.growth >= 0 then
					logistic = sp.growth * sp.population * (1 - sp.population / sp.capacity)
				else
					logistic = sp.growth * sp.population
				end
				delta[name] = logistic
			end
			for _, link in ipairs(self.links) do
				local predator = self.species[link.predator]
				local prey = self.species[link.prey]
				local kills = link.predation * predator.population * prey.population
				delta[link.prey] = (delta[link.prey] or 0) - kills
				delta[link.predator] = (delta[link.predator] or 0) + kills * link.efficiency
			end
			for _, name in ipairs(self.order) do
				local sp = self.species[name]
				sp.population = math.max(0, sp.population + delta[name] * dt)
				-- the habitat itself is a hard ceiling, even for a well fed predator
				if sp.population > sp.capacity then sp.population = sp.capacity end
				if sp.population < sp.minimum and not sp.extinct then
					sp.extinct = true
					sp.population = 0
					self.extinctions = self.extinctions + 1
				end
				sp.history[#sp.history + 1] = sp.population
				if #sp.history > 64 then table.remove(sp.history, 1) end
			end
			return self.ticks
		end

		function self.harvest(name, amount)
			local sp = self.species[name]
			if not sp then return 0 end
			local taken = math.min(sp.population, amount)
			sp.population = sp.population - taken
			self.harvested = self.harvested + taken
			return taken
		end

		function self.seed(name, amount)
			local sp = self.species[name]
			if not sp then return 0 end
			sp.population = sp.population + amount
			sp.extinct = false
			return sp.population
		end

		function self.biomass()
			local total = 0
			for _, name in ipairs(self.order) do total = total + self.species[name].population end
			return total
		end

		function self.stable(name, tolerance)
			local sp = self.species[name]
			if not sp or #sp.history < 8 then return false end
			local recent = {}
			for i = #sp.history - 7, #sp.history do recent[#recent + 1] = sp.history[i] end
			local min, max = math.huge, -math.huge
			for _, v in ipairs(recent) do
				if v < min then min = v end
				if v > max then max = v end
			end
			return (max - min) <= (tolerance or 0.05) * math.max(1, max)
		end

		function self.stats() return { species = #self.order, links = #self.links,
			biomass = self.biomass(), ticks = self.ticks, extinctions = self.extinctions,
			harvested = self.harvested, time = self.time } end
		return self
	end

	K.NAMES = { "mindnet", "memory", "need", "emotion", "perception", "behaviortree",
		"utility", "planner", "navgraph", "crowd", "society", "economy", "schedule", "ecology" }

	return K
end
