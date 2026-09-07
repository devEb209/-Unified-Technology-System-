-- ARKHER NPC :: Neural Mind Network (NMN)
-- One mind = perception + memory + needs + emotion + a small neural policy that learns from
-- what actually happened. This is the layer that makes an NPC behave like someone rather than
-- like a script: it senses, remembers, wants, feels, decides, and adjusts.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local Mind = {}
	Mind.__index = Mind

	-- The default drive set. Every NPC starts as a person, not as a state machine.
	Mind.DEFAULT_NEEDS = {
		{ name = "energy",  decay = 0.020, weight = 1.2, threshold = 0.40 },
		{ name = "food",    decay = 0.016, weight = 1.1, threshold = 0.35 },
		{ name = "safety",  decay = 0.004, weight = 1.6, threshold = 0.55 },
		{ name = "social",  decay = 0.010, weight = 0.8, threshold = 0.30 },
		{ name = "purpose", decay = 0.006, weight = 0.7, threshold = 0.30 },
	}

	Mind.DEFAULT_ACTIONS = { "rest", "eat", "flee", "socialize", "work", "wander" }

	function Mind.new(id, opts)
		opts = opts or {}
		local self = setmetatable({}, Mind)
		self.id = id
		self.seed = opts.seed or 1
		self.perception = Kits.create("perception", { id = id .. ".perception",
			sightRange = opts.sightRange or 42, hearingRange = opts.hearingRange or 26,
			fov = opts.fov or math.rad(115), attentionSlots = opts.attentionSlots or 4 })
		self.memory = Kits.create("memory", { id = id .. ".memory",
			capacity = opts.memoryCapacity or 48, decayRate = opts.memoryDecay or 0.04 })
		self.needs = Kits.create("need", { id = id .. ".needs" })
		self.emotion = Kits.create("emotion", { id = id .. ".emotion" })
		self.net = Kits.create("mindnet", { id = id .. ".net", inputs = 9,
			hidden = opts.hidden or 6, seed = self.seed,
			learningRate = opts.learningRate or 0.08,
			exploration = opts.exploration or 0.05 })
		for _, spec in ipairs(opts.needs or Mind.DEFAULT_NEEDS) do
			self.needs.define(spec.name, spec)
		end
		for _, action in ipairs(opts.actions or Mind.DEFAULT_ACTIONS) do
			self.net.addAction(action)
		end
		self.personality = opts.personality or { brave = 0.5, social = 0.5, curious = 0.5 }
		self.lastAction = nil
		self.lastActionTime = 0
		self.time = 0
		self.decisions = 0
		self.learnings = 0
		self.onDecision = Signal.new("mind.decision")
		self.onMemory = Signal.new("mind.memory")
		return self
	end

	-- ------------------------------------------------------------------ sensing
	function Mind:place(position, facing)
		return self.perception.place(position, facing)
	end

	function Mind:observe(id, position, opts)
		return self.perception.submit(id, position, opts)
	end

	-- One perception pass: what is around, what matters, and what is worth remembering.
	function Mind:sense(occlusionFn)
		local attention, perceived = self.perception.scan(occlusionFn)
		local threat = 0
		for _, entry in ipairs(attention) do
			if (entry.threat or 0) > threat then threat = entry.threat end
			if entry.salience > 0.6 then
				local episode = self.memory.remember(entry.kind, { id = entry.id },
					entry.salience, entry.position)
				self.onMemory:fire({ mind = self.id, episode = episode })
			end
		end
		self.threat = threat
		if threat > 0.4 then
			self.emotion.appraise(-threat, threat)
			self.needs.satisfy("safety", -threat * 0.12)
		end
		return attention, perceived
	end

	-- ------------------------------------------------------------------ deciding
	-- The input vector is what the mind actually knows about itself and the world.
	function Mind:inputVector()
		local vector = self.needs.vector()
		local inputs = {}
		for i = 1, 5 do inputs[i] = vector[i] or 0.5 end
		inputs[6] = (self.emotion.valence + 1) * 0.5
		inputs[7] = (self.emotion.arousal + 1) * 0.5
		inputs[8] = self.threat or 0
		inputs[9] = #self.perception.attention / math.max(1, self.perception.attentionSlots)
		return inputs
	end

	function Mind:decide(dt)
		self.decisions = self.decisions + 1
		local urgentNeed, urgency = self.needs.mostUrgent()
		local action, score = self.net.decide(self:inputVector())
		-- a critical drive overrides the policy: a starving NPC does not philosophise
		if urgency > 0.75 then
			local forced = ({ energy = "rest", food = "eat", safety = "flee",
				social = "socialize", purpose = "work" })[urgentNeed]
			if forced then
				action = forced
				score = urgency
				self.overrides = (self.overrides or 0) + 1
			end
		end
		self.lastAction = action
		self.lastActionTime = self.time
		self.onDecision:fire({ mind = self.id, action = action, score = score,
			need = urgentNeed, urgency = urgency })
		return action, score, urgentNeed
	end

	-- ------------------------------------------------------------------ learning
	-- Reward comes from the world, not from the script: did wellbeing go up or down?
	function Mind:reward(amount, reason)
		self.learnings = self.learnings + 1
		self.net.reinforce(amount)
		self.emotion.appraise(amount, math.min(1, math.abs(amount)))
		if reason then
			self.memory.remember("outcome", { action = self.lastAction, reason = reason,
				amount = amount }, math.min(1, math.abs(amount) + 0.3))
		end
		return amount
	end

	function Mind:act(action, world)
		local effects = {
			rest = function() self.needs.satisfy("energy", 0.25) end,
			eat = function() self.needs.satisfy("food", 0.35) end,
			flee = function() self.needs.satisfy("safety", 0.20) end,
			socialize = function() self.needs.satisfy("social", 0.30) end,
			work = function()
				self.needs.satisfy("purpose", 0.22)
				self.needs.satisfy("energy", -0.05)
			end,
			wander = function() self.needs.satisfy("purpose", 0.04) end,
		}
		local before = self.needs.wellbeing()
		local effect = effects[action or self.lastAction]
		if effect then effect() end
		if world and world.apply then world.apply(self, action) end
		local after = self.needs.wellbeing()
		local delta = after - before
		self:reward(Mathx.clamp(delta * 6, -1, 1), action)
		return delta
	end

	-- ------------------------------------------------------------------ the tick
	function Mind:update(dt, occlusionFn)
		self.time = self.time + dt
		self.needs.tick(dt)
		self.emotion.tick(dt)
		self.memory.tick(dt)
		self:sense(occlusionFn)
		local action = self:decide(dt)
		self:act(action)
		if self.memory.stats().episodes > 8 then self.memory.consolidate() end
		return action
	end

	function Mind:knows(kind) return self.memory.knows(kind) end

	function Mind:describe()
		local label = self.emotion.label()
		local urgent = self.needs.mostUrgent()
		return { id = self.id, feeling = label, wants = urgent, doing = self.lastAction,
			wellbeing = self.needs.wellbeing(), mood = self.emotion.mood(),
			knows = self.memory.factCount(), remembers = self.memory.stats().episodes }
	end

	function Mind:brainBytes()
		return self.net.memoryBytes() + self.memory.stats().episodes * 64
	end

	function Mind:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.perception.attentionSlots = math.max(1, math.floor(1 + quality * 5))
		self.perception.sightRange = Mathx.lerp(18, 60, quality)
		self.memory.capacity = math.max(8, math.floor(8 + quality * 56))
		return { attentionSlots = self.perception.attentionSlots,
			sightRange = self.perception.sightRange, memoryCapacity = self.memory.capacity }
	end

	function Mind:report()
		return { id = self.id, decisions = self.decisions, learnings = self.learnings,
			overrides = self.overrides or 0, wellbeing = self.needs.wellbeing(),
			emotion = self.emotion.stats(), memory = self.memory.stats(),
			needs = self.needs.stats(), net = self.net.stats(),
			perception = self.perception.stats(), brainBytes = self:brainBytes() }
	end

	return Mind
end
