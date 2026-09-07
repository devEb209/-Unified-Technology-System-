-- ARKHER RUNTIME :: Gameplay, UI and Networking Kits
-- Round 7 machinery (kits 90-99). Attributes and modifiers, inventories and crafting,
-- objectives, combat resolution, responsive layout, input mapping, tweening, replication,
-- clock synchronization and client-side prediction. All deterministic, all testable.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Random = A:import("arkher/kernel/random")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 90. STATS
	-- Attributes with a real modifier pipeline: flat -> additive percent -> multiplicative,
	-- with sources, durations, caps and derived stats computed from a formula.
	function K.stats(cfg)
		local self = { kind = "stats", id = cfg.id, base = {}, order = {}, modifiers = {},
			derived = {}, derivedOrder = {}, dirty = {}, cache = {},
			recomputes = 0, applied = 0, expired = 0, time = 0 }

		function self.define(name, value, opts)
			opts = opts or {}
			if self.base[name] then return nil, "duplicate attribute" end
			self.base[name] = { name = name, value = value or 0, min = opts.min or 0,
				max = opts.max or math.huge }
			self.order[#self.order + 1] = name
			self.dirty[name] = true
			return self.base[name]
		end

		function self.setBase(name, value)
			local attr = self.base[name]
			if not attr then return nil end
			attr.value = value
			self.dirty[name] = true
			return attr.value
		end

		function self.addModifier(name, id, opts)
			opts = opts or {}
			if not self.base[name] then return nil, "unknown attribute" end
			self.modifiers[#self.modifiers + 1] = { attribute = name, id = id,
				flat = opts.flat or 0, percent = opts.percent or 0,
				multiplier = opts.multiplier or 1, duration = opts.duration,
				source = opts.source or "unknown", stacks = opts.stacks or 1,
				born = self.time }
			self.dirty[name] = true
			self.applied = self.applied + 1
			return #self.modifiers
		end

		function self.removeModifier(id)
			local removed = 0
			local i = 1
			while i <= #self.modifiers do
				if self.modifiers[i].id == id then
					self.dirty[self.modifiers[i].attribute] = true
					table.remove(self.modifiers, i)
					removed = removed + 1
				else
					i = i + 1
				end
			end
			return removed
		end

		function self.get(name)
			local attr = self.base[name]
			if not attr then return 0 end
			if not self.dirty[name] and self.cache[name] then return self.cache[name] end
			self.recomputes = self.recomputes + 1
			local flat, percent, mult = 0, 0, 1
			for _, m in ipairs(self.modifiers) do
				if m.attribute == name then
					flat = flat + m.flat * m.stacks
					percent = percent + m.percent * m.stacks
					mult = mult * (m.multiplier ^ m.stacks)
				end
			end
			local value = (attr.value + flat) * (1 + percent) * mult
			value = Mathx.clamp(value, attr.min, attr.max)
			self.cache[name] = value
			self.dirty[name] = false
			return value
		end

		function self.defineDerived(name, fn)
			if self.derived[name] then return nil, "duplicate derived stat" end
			self.derived[name] = fn
			self.derivedOrder[#self.derivedOrder + 1] = name
			return name
		end

		function self.getDerived(name)
			local fn = self.derived[name]
			if not fn then return 0 end
			return fn(self)
		end

		function self.tick(dt)
			self.time = self.time + dt
			local i = 1
			while i <= #self.modifiers do
				local m = self.modifiers[i]
				if m.duration and self.time - m.born >= m.duration then
					self.dirty[m.attribute] = true
					table.remove(self.modifiers, i)
					self.expired = self.expired + 1
				else
					i = i + 1
				end
			end
			return #self.modifiers
		end

		function self.modifiersFor(name)
			local out = {}
			for _, m in ipairs(self.modifiers) do
				if m.attribute == name then out[#out + 1] = m end
			end
			return out
		end

		function self.snapshot()
			local out = {}
			for _, name in ipairs(self.order) do out[name] = self.get(name) end
			return out
		end

		function self.compare(other)
			local diff = {}
			for _, name in ipairs(self.order) do
				local mine = self.get(name)
				local theirs = other[name] or 0
				if math.abs(mine - theirs) > 1e-9 then diff[name] = mine - theirs end
			end
			return diff
		end

		function self.stats() return { attributes = #self.order, modifiers = #self.modifiers,
			derived = #self.derivedOrder, recomputes = self.recomputes,
			applied = self.applied, expired = self.expired, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 91. INVENTORY
	-- Slots, stacking, weight and capacity limits, equipment slots, transfers between
	-- containers and recipe crafting that actually consumes and produces items.
	function K.inventory(cfg)
		local self = { kind = "inventory", id = cfg.id, slots = {}, slotCount = cfg.slots or 20,
			maxWeight = cfg.maxWeight or 100, defs = {}, equipment = {}, recipes = {},
			recipeOrder = {}, added = 0, removed = 0, crafted = 0, rejected = 0 }

		for i = 1, self.slotCount do self.slots[i] = nil end

		function self.defineItem(name, opts)
			opts = opts or {}
			if self.defs[name] then return nil, "duplicate item" end
			self.defs[name] = { name = name, stack = opts.stack or 1, weight = opts.weight or 0,
				slot = opts.slot, value = opts.value or 0, tags = opts.tags or {} }
			return self.defs[name]
		end

		function self.weight()
			local total = 0
			for i = 1, self.slotCount do
				local s = self.slots[i]
				if s then total = total + (self.defs[s.item].weight or 0) * s.count end
			end
			return total
		end

		function self.countOf(item)
			local total = 0
			for i = 1, self.slotCount do
				local s = self.slots[i]
				if s and s.item == item then total = total + s.count end
			end
			return total
		end

		function self.freeSlots()
			local n = 0
			for i = 1, self.slotCount do
				if not self.slots[i] then n = n + 1 end
			end
			return n
		end

		-- Add fills partial stacks first, then empty slots, and respects the weight limit.
		function self.add(item, count)
			local def = self.defs[item]
			if not def then return 0, "unknown item" end
			local want = count or 1
			local added = 0
			while added < want do
				if self.weight() + def.weight > self.maxWeight then
					self.rejected = self.rejected + 1
					return added, "overweight"
				end
				local target = nil
				for i = 1, self.slotCount do
					local s = self.slots[i]
					if s and s.item == item and s.count < def.stack then target = i break end
				end
				if not target then
					for i = 1, self.slotCount do
						if not self.slots[i] then target = i break end
					end
					if target then self.slots[target] = { item = item, count = 0 } end
				end
				if not target then
					self.rejected = self.rejected + 1
					return added, "full"
				end
				self.slots[target].count = self.slots[target].count + 1
				added = added + 1
				self.added = self.added + 1
			end
			return added
		end

		function self.remove(item, count)
			local want = count or 1
			local taken = 0
			for i = self.slotCount, 1, -1 do
				local s = self.slots[i]
				if s and s.item == item then
					local take = math.min(s.count, want - taken)
					s.count = s.count - take
					taken = taken + take
					self.removed = self.removed + take
					if s.count <= 0 then self.slots[i] = nil end
					if taken >= want then break end
				end
			end
			return taken
		end

		function self.has(item, count) return self.countOf(item) >= (count or 1) end

		function self.moveTo(other, item, count)
			local available = math.min(self.countOf(item), count or 1)
			if available <= 0 then return 0 end
			if not other.defs[item] then
				local def = self.defs[item]
				other.defineItem(item, { stack = def.stack, weight = def.weight,
					slot = def.slot, value = def.value })
			end
			local moved = other.add(item, available)
			self.remove(item, moved)
			return moved
		end

		function self.equip(item)
			local def = self.defs[item]
			if not def or not def.slot then return false, "not equippable" end
			if not self.has(item, 1) then return false, "not carried" end
			local previous = self.equipment[def.slot]
			if previous then self.add(previous, 1) end
			self.remove(item, 1)
			self.equipment[def.slot] = item
			return true, previous
		end

		function self.unequip(slot)
			local item = self.equipment[slot]
			if not item then return false end
			self.equipment[slot] = nil
			self.add(item, 1)
			return item
		end

		function self.addRecipe(name, inputs, outputs)
			if self.recipes[name] then return nil, "duplicate recipe" end
			self.recipes[name] = { name = name, inputs = inputs, outputs = outputs }
			self.recipeOrder[#self.recipeOrder + 1] = name
			return self.recipes[name]
		end

		function self.canCraft(name)
			local recipe = self.recipes[name]
			if not recipe then return false end
			for item, count in pairs(recipe.inputs) do
				if not self.has(item, count) then return false end
			end
			return true
		end

		function self.craft(name)
			if not self.canCraft(name) then return false, "missing inputs" end
			local recipe = self.recipes[name]
			for item, count in pairs(recipe.inputs) do self.remove(item, count) end
			for item, count in pairs(recipe.outputs) do self.add(item, count) end
			self.crafted = self.crafted + 1
			return true
		end

		function self.totalValue()
			local total = 0
			for i = 1, self.slotCount do
				local s = self.slots[i]
				if s then total = total + self.defs[s.item].value * s.count end
			end
			return total
		end

		function self.serialize()
			local out = { slots = {}, equipment = {} }
			for i = 1, self.slotCount do
				local s = self.slots[i]
				if s then out.slots[#out.slots + 1] = { index = i, item = s.item, count = s.count } end
			end
			for slot, item in pairs(self.equipment) do out.equipment[slot] = item end
			return out
		end

		function self.deserialize(data)
			for i = 1, self.slotCount do self.slots[i] = nil end
			self.equipment = {}
			for _, s in ipairs(data.slots or {}) do
				self.slots[s.index] = { item = s.item, count = s.count }
			end
			for slot, item in pairs(data.equipment or {}) do self.equipment[slot] = item end
			return true
		end

		function self.stats() return { slots = self.slotCount, used = self.slotCount - self.freeSlots(),
			weight = self.weight(), maxWeight = self.maxWeight, items = C.count(self.defs),
			recipes = #self.recipeOrder, added = self.added, removed = self.removed,
			crafted = self.crafted, rejected = self.rejected } end
		return self
	end

	------------------------------------------------------------------ 92. QUEST
	-- Objectives with counters, prerequisite chains, branching, rewards and a journal.
	function K.quest(cfg)
		local self = { kind = "quest", id = cfg.id, quests = {}, order = {}, journal = {},
			completed = 0, failed = 0, started = 0, events = 0 }

		function self.define(name, opts)
			opts = opts or {}
			if self.quests[name] then return nil, "duplicate quest" end
			local q = { name = name, state = "locked", objectives = {}, objectiveOrder = {},
				requires = opts.requires or {}, rewards = opts.rewards or {},
				optional = opts.optional or false, autoStart = opts.autoStart or false }
			self.quests[name] = q
			self.order[#self.order + 1] = name
			if #q.requires == 0 then q.state = "available" end
			return q
		end

		function self.addObjective(questName, objectiveName, opts)
			opts = opts or {}
			local q = self.quests[questName]
			if not q then return nil, "unknown quest" end
			q.objectives[objectiveName] = { name = objectiveName, count = 0,
				required = opts.required or 1, event = opts.event or objectiveName,
				optional = opts.optional or false, done = false }
			q.objectiveOrder[#q.objectiveOrder + 1] = objectiveName
			return q.objectives[objectiveName]
		end

		function self.start(name)
			local q = self.quests[name]
			if not q or q.state ~= "available" then return false end
			q.state = "active"
			self.started = self.started + 1
			self.journal[#self.journal + 1] = { quest = name, event = "started" }
			return true
		end

		function self.canStart(name)
			local q = self.quests[name]
			if not q then return false end
			for _, req in ipairs(q.requires) do
				local other = self.quests[req]
				if not other or other.state ~= "completed" then return false end
			end
			return q.state == "available" or q.state == "locked"
		end

		function self.unlockAvailable()
			local unlocked = 0
			for _, name in ipairs(self.order) do
				local q = self.quests[name]
				if q.state == "locked" and self.canStart(name) then
					q.state = "available"
					unlocked = unlocked + 1
					if q.autoStart then self.start(name) end
				end
			end
			return unlocked
		end

		-- A world event advances every matching objective of every active quest.
		function self.notify(event, amount)
			self.events = self.events + 1
			local advanced = 0
			for _, name in ipairs(self.order) do
				local q = self.quests[name]
				if q.state == "active" then
					for _, oname in ipairs(q.objectiveOrder) do
						local o = q.objectives[oname]
						if not o.done and o.event == event then
							o.count = o.count + (amount or 1)
							advanced = advanced + 1
							if o.count >= o.required then
								o.done = true
								self.journal[#self.journal + 1] = { quest = name,
									event = "objective", objective = oname }
							end
						end
					end
					if self.isComplete(name) then self.complete(name) end
				end
			end
			return advanced
		end

		function self.isComplete(name)
			local q = self.quests[name]
			if not q then return false end
			for _, oname in ipairs(q.objectiveOrder) do
				local o = q.objectives[oname]
				if not o.optional and not o.done then return false end
			end
			return #q.objectiveOrder > 0
		end

		function self.complete(name)
			local q = self.quests[name]
			if not q or q.state ~= "active" then return false end
			q.state = "completed"
			self.completed = self.completed + 1
			self.journal[#self.journal + 1] = { quest = name, event = "completed" }
			self.unlockAvailable()
			return true, q.rewards
		end

		function self.fail(name)
			local q = self.quests[name]
			if not q or q.state ~= "active" then return false end
			q.state = "failed"
			self.failed = self.failed + 1
			self.journal[#self.journal + 1] = { quest = name, event = "failed" }
			return true
		end

		function self.progress(name)
			local q = self.quests[name]
			if not q or #q.objectiveOrder == 0 then return 0 end
			local total, done = 0, 0
			for _, oname in ipairs(q.objectiveOrder) do
				local o = q.objectives[oname]
				total = total + o.required
				done = done + math.min(o.count, o.required)
			end
			return done / math.max(1, total)
		end

		function self.active()
			local out = {}
			for _, name in ipairs(self.order) do
				if self.quests[name].state == "active" then out[#out + 1] = name end
			end
			return out
		end

		function self.stateOf(name)
			local q = self.quests[name]
			if not q then return nil end
			return q.state
		end

		function self.recent(n)
			local out = {}
			local from = math.max(1, #self.journal - (n or 10) + 1)
			for i = from, #self.journal do out[#out + 1] = self.journal[i] end
			return out
		end

		function self.stats() return { quests = #self.order, active = #self.active(),
			completed = self.completed, failed = self.failed, started = self.started,
			events = self.events, journal = #self.journal } end
		return self
	end

	------------------------------------------------------------------ 93. COMBAT
	-- Damage resolution: attack rolls, damage types with resistances, critical hits,
	-- armour mitigation, status effects over time, cooldowns and a hit log.
	function K.combat(cfg)
		local self = { kind = "combat", id = cfg.id, actors = {}, order = {},
			cooldowns = {}, statuses = {}, log = {}, rng = Random.new(cfg.seed or 99),
			critMultiplier = cfg.critMultiplier or 2, armourK = cfg.armourK or 100,
			attacks = 0, hits = 0, misses = 0, crits = 0, kills = 0, time = 0 }

		function self.addActor(id, opts)
			opts = opts or {}
			if self.actors[id] then return nil, "duplicate actor" end
			local actor = { id = id, health = opts.health or 100, maxHealth = opts.health or 100,
				armour = opts.armour or 0, accuracy = opts.accuracy or 0.9,
				evasion = opts.evasion or 0.05, critChance = opts.critChance or 0.05,
				power = opts.power or 10, team = opts.team or "neutral",
				resistances = opts.resistances or {}, alive = true }
			self.actors[id] = actor
			self.order[#self.order + 1] = id
			self.statuses[id] = {}
			return actor
		end

		function self.hitChance(attackerId, defenderId)
			local a, d = self.actors[attackerId], self.actors[defenderId]
			if not a or not d then return 0 end
			return Mathx.clamp(a.accuracy - d.evasion, 0.05, 0.99)
		end

		function self.mitigate(amount, armour, resistance)
			local reduced = amount * (self.armourK / (self.armourK + math.max(0, armour)))
			return math.max(0, reduced * (1 - clamp01(resistance or 0)))
		end

		function self.attack(attackerId, defenderId, opts)
			opts = opts or {}
			local a, d = self.actors[attackerId], self.actors[defenderId]
			if not a or not d or not a.alive or not d.alive then return nil, "invalid actors" end
			self.attacks = self.attacks + 1
			local roll = self.rng:next()
			if roll > self.hitChance(attackerId, defenderId) then
				self.misses = self.misses + 1
				self.log[#self.log + 1] = { attacker = attackerId, defender = defenderId,
					result = "miss", time = self.time }
				return { hit = false, damage = 0 }
			end
			local damageType = opts.damageType or "physical"
			local raw = (opts.power or a.power) * (opts.scale or 1)
			local crit = self.rng:next() < (opts.critChance or a.critChance)
			if crit then
				raw = raw * self.critMultiplier
				self.crits = self.crits + 1
			end
			local final = self.mitigate(raw, damageType == "true" and 0 or d.armour,
				d.resistances[damageType])
			d.health = math.max(0, d.health - final)
			self.hits = self.hits + 1
			local killed = false
			if d.health <= 0 and d.alive then
				d.alive = false
				killed = true
				self.kills = self.kills + 1
			end
			self.log[#self.log + 1] = { attacker = attackerId, defender = defenderId,
				result = crit and "crit" or "hit", damage = final, killed = killed,
				time = self.time }
			return { hit = true, damage = final, crit = crit, killed = killed,
				remaining = d.health }
		end

		function self.heal(id, amount)
			local actor = self.actors[id]
			if not actor or not actor.alive then return 0 end
			local before = actor.health
			actor.health = math.min(actor.maxHealth, actor.health + amount)
			return actor.health - before
		end

		function self.applyStatus(id, name, opts)
			opts = opts or {}
			local actor = self.actors[id]
			if not actor then return false end
			self.statuses[id][name] = { name = name, duration = opts.duration or 3,
				tickDamage = opts.tickDamage or 0, tickHeal = opts.tickHeal or 0,
				slow = opts.slow or 0, elapsed = 0 }
			return true
		end

		function self.hasStatus(id, name)
			return self.statuses[id] ~= nil and self.statuses[id][name] ~= nil
		end

		function self.setCooldown(id, ability, seconds)
			self.cooldowns[id] = self.cooldowns[id] or {}
			self.cooldowns[id][ability] = seconds
			return seconds
		end

		function self.ready(id, ability)
			local list = self.cooldowns[id]
			if not list or not list[ability] then return true end
			return list[ability] <= 0
		end

		function self.tick(dt)
			self.time = self.time + dt
			for _, id in ipairs(self.order) do
				local list = self.cooldowns[id]
				if list then
					for ability, remaining in pairs(list) do
						list[ability] = math.max(0, remaining - dt)
					end
				end
				local actor = self.actors[id]
				for name, st in pairs(self.statuses[id]) do
					st.elapsed = st.elapsed + dt
					if actor.alive then
						if st.tickDamage > 0 then
							actor.health = math.max(0, actor.health - st.tickDamage * dt)
							if actor.health <= 0 then
								actor.alive = false
								self.kills = self.kills + 1
							end
						end
						if st.tickHeal > 0 then
							actor.health = math.min(actor.maxHealth, actor.health + st.tickHeal * dt)
						end
					end
					if st.elapsed >= st.duration then self.statuses[id][name] = nil end
				end
			end
			return self.time
		end

		function self.teamAlive(team)
			local n = 0
			for _, id in ipairs(self.order) do
				local a = self.actors[id]
				if a.alive and a.team == team then n = n + 1 end
			end
			return n
		end

		function self.recent(n)
			local out = {}
			local from = math.max(1, #self.log - (n or 10) + 1)
			for i = from, #self.log do out[#out + 1] = self.log[i] end
			return out
		end

		function self.dps(attackerId)
			local total = 0
			for _, entry in ipairs(self.log) do
				if entry.attacker == attackerId then total = total + (entry.damage or 0) end
			end
			if self.time <= 0 then return 0 end
			return total / self.time
		end

		function self.stats() return { actors = #self.order, attacks = self.attacks,
			hits = self.hits, misses = self.misses, crits = self.crits, kills = self.kills,
			log = #self.log, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 94. FLEX
	-- Responsive layout: a constraint box model with rows/columns, padding, gaps,
	-- weights, min/max sizes, safe-area insets and device breakpoints.
	function K.flex(cfg)
		local self = { kind = "flex", id = cfg.id, nodes = {}, order = {}, root = nil,
			width = cfg.width or 828, height = cfg.height or 1792,
			safeArea = cfg.safeArea or { top = 44, bottom = 34, left = 0, right = 0 },
			breakpoints = cfg.breakpoints or { phone = 600, tablet = 1000, desktop = 100000 },
			solves = 0, scale = cfg.scale or 1 }

		function self.addNode(id, opts)
			opts = opts or {}
			if self.nodes[id] then return nil, "duplicate node" end
			local node = { id = id, parent = opts.parent, children = {},
				direction = opts.direction or "column", weight = opts.weight or 1,
				fixedWidth = opts.width, fixedHeight = opts.height,
				minWidth = opts.minWidth or 0, minHeight = opts.minHeight or 0,
				padding = opts.padding or 0, gap = opts.gap or 0,
				align = opts.align or "stretch", visible = true,
				rect = { x = 0, y = 0, width = 0, height = 0 } }
			self.nodes[id] = node
			self.order[#self.order + 1] = id
			if node.parent then
				local p = self.nodes[node.parent]
				if p then p.children[#p.children + 1] = id end
			elseif not self.root then
				self.root = id
			end
			return node
		end

		function self.setVisible(id, on)
			local node = self.nodes[id]
			if not node then return false end
			node.visible = on and true or false
			return node.visible
		end

		function self.setViewport(width, height, safeArea)
			self.width = width
			self.height = height
			if safeArea then self.safeArea = safeArea end
			return self.breakpoint()
		end

		function self.breakpoint()
			local w = math.min(self.width, self.height)
			if w <= self.breakpoints.phone then return "phone" end
			if w <= self.breakpoints.tablet then return "tablet" end
			return "desktop"
		end

		local function layoutNode(node, x, y, width, height)
			node.rect = { x = x, y = y, width = width, height = height }
			local pad = node.padding
			local innerX, innerY = x + pad, y + pad
			local innerW = math.max(0, width - pad * 2)
			local innerH = math.max(0, height - pad * 2)
			local visible = {}
			for _, cid in ipairs(node.children) do
				local child = self.nodes[cid]
				if child and child.visible then visible[#visible + 1] = child end
			end
			if #visible == 0 then return end
			local horizontal = node.direction == "row"
			local totalGap = node.gap * (#visible - 1)
			local available = (horizontal and innerW or innerH) - totalGap
			local fixedTotal, weightTotal = 0, 0
			for _, child in ipairs(visible) do
				local fixed = horizontal and child.fixedWidth or child.fixedHeight
				if fixed then fixedTotal = fixedTotal + fixed else weightTotal = weightTotal + child.weight end
			end
			local flexible = math.max(0, available - fixedTotal)
			local cursor = horizontal and innerX or innerY
			for _, child in ipairs(visible) do
				local fixed = horizontal and child.fixedWidth or child.fixedHeight
				local size = fixed or (weightTotal > 0 and flexible * child.weight / weightTotal or 0)
				if horizontal then
					size = math.max(size, child.minWidth)
					layoutNode(child, cursor, innerY, size, innerH)
					cursor = cursor + size + node.gap
				else
					size = math.max(size, child.minHeight)
					layoutNode(child, innerX, cursor, innerW, size)
					cursor = cursor + size + node.gap
				end
			end
		end

		function self.solve()
			self.solves = self.solves + 1
			if not self.root then return nil end
			local sa = self.safeArea
			local root = self.nodes[self.root]
			layoutNode(root, sa.left, sa.top,
				self.width - sa.left - sa.right, self.height - sa.top - sa.bottom)
			return root.rect
		end

		function self.rectOf(id)
			local node = self.nodes[id]
			if not node then return nil end
			return node.rect
		end

		function self.hitTest(x, y)
			local hit = nil
			for _, id in ipairs(self.order) do
				local node = self.nodes[id]
				local r = node.rect
				if node.visible and x >= r.x and x <= r.x + r.width
					and y >= r.y and y <= r.y + r.height then
					hit = id
				end
			end
			return hit
		end

		-- A touch target below 44 points fails the mobile accessibility rule.
		function self.touchTargetsBelow(minSize)
			local limit = minSize or 44
			local out = {}
			for _, id in ipairs(self.order) do
				local node = self.nodes[id]
				if node.visible and #node.children == 0 then
					local r = node.rect
					if r.width > 0 and (r.width < limit or r.height < limit) then
						out[#out + 1] = id
					end
				end
			end
			return out
		end

		function self.depthOf(id)
			local depth = 0
			local node = self.nodes[id]
			while node and node.parent do
				depth = depth + 1
				node = self.nodes[node.parent]
			end
			return depth
		end

		function self.stats() return { nodes = #self.order, root = self.root,
			width = self.width, height = self.height, breakpoint = self.breakpoint(),
			solves = self.solves, scale = self.scale } end
		return self
	end

	------------------------------------------------------------------ 95. INPUTMAP
	-- Device-agnostic input: named actions bound to keys, buttons, touch zones and axes,
	-- with chords, hold/tap detection, dead zones and a virtual thumbstick.
	function K.inputmap(cfg)
		local self = { kind = "inputmap", id = cfg.id, actions = {}, order = {},
			state = {}, axes = {}, deadzone = cfg.deadzone or 0.15,
			holdTime = cfg.holdTime or 0.35, device = cfg.device or "touch",
			presses = 0, releases = 0, holds = 0, time = 0 }

		function self.bind(action, opts)
			opts = opts or {}
			if self.actions[action] then return nil, "duplicate action" end
			local a = { name = action, keys = opts.keys or {}, buttons = opts.buttons or {},
				touchZone = opts.touchZone, chord = opts.chord or {},
				repeatable = opts.repeatable or false }
			self.actions[action] = a
			self.order[#self.order + 1] = action
			self.state[action] = { down = false, downTime = 0, consumed = false,
				tapped = false, held = false }
			return a
		end

		function self.press(action)
			local st = self.state[action]
			if not st then return false end
			if st.down then return false end
			st.down = true
			st.downTime = 0
			st.consumed = false
			st.held = false
			self.presses = self.presses + 1
			return true
		end

		function self.release(action)
			local st = self.state[action]
			if not st or not st.down then return false end
			st.down = false
			st.tapped = st.downTime < self.holdTime
			self.releases = self.releases + 1
			return st.tapped
		end

		function self.isDown(action)
			local st = self.state[action]
			return st ~= nil and st.down
		end

		function self.wasTapped(action)
			local st = self.state[action]
			if not st or not st.tapped then return false end
			st.tapped = false
			return true
		end

		function self.isHeld(action)
			local st = self.state[action]
			return st ~= nil and st.held
		end

		function self.chordActive(action)
			local a = self.actions[action]
			if not a or #a.chord == 0 then return false end
			for _, other in ipairs(a.chord) do
				if not self.isDown(other) then return false end
			end
			return true
		end

		function self.setAxis(name, x, y)
			local vx, vy = x or 0, y or 0
			local mag = math.sqrt(vx * vx + vy * vy)
			if mag < self.deadzone then
				self.axes[name] = { x = 0, y = 0, magnitude = 0 }
			else
				local scaled = (mag - self.deadzone) / (1 - self.deadzone)
				local unitX, unitY = vx / mag, vy / mag
				self.axes[name] = { x = unitX * scaled, y = unitY * scaled,
					magnitude = math.min(1, scaled) }
			end
			return self.axes[name]
		end

		function self.axis(name)
			return self.axes[name] or { x = 0, y = 0, magnitude = 0 }
		end

		-- A virtual thumbstick: origin is where the finger landed, radius clamps the pull.
		function self.thumbstick(name, originX, originY, x, y, radius)
			local r = radius or 60
			return self.setAxis(name, Mathx.clamp((x - originX) / r, -1, 1),
				Mathx.clamp((y - originY) / r, -1, 1))
		end

		function self.touchAt(x, y)
			for _, name in ipairs(self.order) do
				local zone = self.actions[name].touchZone
				if zone and x >= zone.x and x <= zone.x + zone.width
					and y >= zone.y and y <= zone.y + zone.height then
					self.press(name)
					return name
				end
			end
			return nil
		end

		function self.tick(dt)
			self.time = self.time + dt
			for _, name in ipairs(self.order) do
				local st = self.state[name]
				if st.down then
					st.downTime = st.downTime + dt
					if not st.held and st.downTime >= self.holdTime then
						st.held = true
						self.holds = self.holds + 1
					end
				end
			end
			return self.time
		end

		function self.setDevice(device)
			self.device = device
			if device == "gamepad" then self.deadzone = math.max(self.deadzone, 0.2) end
			return self.device
		end

		function self.bindingsFor(device)
			local out = {}
			for _, name in ipairs(self.order) do
				local a = self.actions[name]
				if device == "touch" and a.touchZone then out[#out + 1] = name
				elseif device == "gamepad" and #a.buttons > 0 then out[#out + 1] = name
				elseif device == "keyboard" and #a.keys > 0 then out[#out + 1] = name end
			end
			return out
		end

		function self.stats() return { actions = #self.order, device = self.device,
			deadzone = self.deadzone, presses = self.presses, releases = self.releases,
			holds = self.holds, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 96. TWEEN
	-- Interpolation engine: named tweens with easing, delay, loop and ping-pong modes,
	-- sequences, and a scheduler that advances everything under one call.
	function K.tween(cfg)
		local self = { kind = "tween", id = cfg.id, tweens = {}, order = {},
			completed = 0, started = 0, time = 0, timeScale = cfg.timeScale or 1 }

		local EASINGS = {}
		EASINGS.linear = function(t) return t end
		EASINGS.quadIn = function(t) return t * t end
		EASINGS.quadOut = function(t) return 1 - (1 - t) * (1 - t) end
		EASINGS.quadInOut = function(t)
			if t < 0.5 then return 2 * t * t end
			return 1 - ((-2 * t + 2) ^ 2) / 2
		end
		EASINGS.cubicOut = function(t) return 1 - (1 - t) ^ 3 end
		EASINGS.backOut = function(t)
			local c1, c3 = 1.70158, 2.70158
			return 1 + c3 * ((t - 1) ^ 3) + c1 * ((t - 1) ^ 2)
		end
		EASINGS.elasticOut = function(t)
			if t <= 0 then return 0 end
			if t >= 1 then return 1 end
			local c4 = (2 * math.pi) / 3
			return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
		end
		EASINGS.bounceOut = function(t)
			local n1, d1 = 7.5625, 2.75
			if t < 1 / d1 then return n1 * t * t end
			if t < 2 / d1 then
				t = t - 1.5 / d1
				return n1 * t * t + 0.75
			end
			if t < 2.5 / d1 then
				t = t - 2.25 / d1
				return n1 * t * t + 0.9375
			end
			t = t - 2.625 / d1
			return n1 * t * t + 0.984375
		end
		self.easings = EASINGS

		function self.create(id, opts)
			opts = opts or {}
			if self.tweens[id] then return nil, "duplicate tween" end
			local tw = { id = id, from = opts.from or 0, to = opts.to or 1,
				duration = math.max(1e-4, opts.duration or 1), delay = opts.delay or 0,
				easing = opts.easing or "quadOut", loop = opts.loop or false,
				pingpong = opts.pingpong or false, elapsed = 0, value = opts.from or 0,
				done = false, playing = true, onComplete = opts.onComplete, laps = 0 }
			self.tweens[id] = tw
			self.order[#self.order + 1] = id
			self.started = self.started + 1
			return tw
		end

		function self.remove(id)
			if not self.tweens[id] then return false end
			self.tweens[id] = nil
			for i, name in ipairs(self.order) do
				if name == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.pause(id)
			local tw = self.tweens[id]
			if not tw then return false end
			tw.playing = false
			return true
		end

		function self.resume(id)
			local tw = self.tweens[id]
			if not tw then return false end
			tw.playing = true
			return true
		end

		function self.valueOf(id)
			local tw = self.tweens[id]
			if not tw then return nil end
			return tw.value
		end

		function self.ease(name, t)
			local fn = EASINGS[name] or EASINGS.linear
			return fn(clamp01(t))
		end

		function self.update(dt)
			local step = dt * self.timeScale
			self.time = self.time + step
			local finished = {}
			for _, id in ipairs(self.order) do
				local tw = self.tweens[id]
				if tw and tw.playing and not tw.done then
					tw.elapsed = tw.elapsed + step
					local active = tw.elapsed - tw.delay
					if active >= 0 then
						local t = clamp01(active / tw.duration)
						local eased = self.ease(tw.easing, t)
						if tw.pingpong then
							local cycle = (active / tw.duration) % 2
							local phase = cycle <= 1 and cycle or 2 - cycle
							eased = self.ease(tw.easing, phase)
						end
						tw.value = Mathx.lerp(tw.from, tw.to, eased)
						if t >= 1 and not tw.loop and not tw.pingpong then
							tw.done = true
							tw.laps = tw.laps + 1
							self.completed = self.completed + 1
							finished[#finished + 1] = id
							if tw.onComplete then tw.onComplete(tw) end
						elseif t >= 1 and tw.loop then
							tw.elapsed = tw.delay
							tw.laps = tw.laps + 1
						end
					end
				end
			end
			return finished
		end

		function self.sequence(prefix, steps)
			local delay = 0
			local created = {}
			for i, step in ipairs(steps) do
				local id = prefix .. "." .. i
				step.delay = delay
				self.create(id, step)
				created[#created + 1] = id
				delay = delay + (step.duration or 1)
			end
			return created, delay
		end

		function self.activeCount()
			local n = 0
			for _, id in ipairs(self.order) do
				local tw = self.tweens[id]
				if tw and not tw.done then n = n + 1 end
			end
			return n
		end

		function self.clear()
			local n = #self.order
			self.tweens = {}
			self.order = {}
			return n
		end

		function self.stats() return { tweens = #self.order, active = self.activeCount(),
			started = self.started, completed = self.completed, time = self.time,
			timeScale = self.timeScale } end
		return self
	end

	------------------------------------------------------------------ 97. REPLICATOR
	-- Authoritative state replication: per-entity fields, dirty tracking, delta snapshots,
	-- interest management by distance, priority accumulation and bandwidth accounting.
	function K.replicator(cfg)
		local self = { kind = "replicator", id = cfg.id, entities = {}, order = {},
			clients = {}, clientOrder = {}, tick = 0, bytesSent = 0, packetsSent = 0,
			mtu = cfg.mtu or 1200, interestRadius = cfg.interestRadius or 200,
			baselines = {}, fullEvery = cfg.fullEvery or 60 }

		function self.spawn(id, fields, position)
			if self.entities[id] then return nil, "duplicate entity" end
			local e = { id = id, fields = {}, dirty = {}, position = position or v3(),
				priority = 0, version = 0 }
			for k, v in pairs(fields or {}) do
				e.fields[k] = v
				e.dirty[k] = true
			end
			self.entities[id] = e
			self.order[#self.order + 1] = id
			return e
		end

		function self.despawn(id)
			if not self.entities[id] then return false end
			self.entities[id] = nil
			for i, name in ipairs(self.order) do
				if name == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.set(id, field, value)
			local e = self.entities[id]
			if not e then return false end
			if e.fields[field] == value then return false end
			e.fields[field] = value
			e.dirty[field] = true
			e.version = e.version + 1
			return true
		end

		function self.move(id, position)
			local e = self.entities[id]
			if not e then return false end
			e.position = position
			return self.set(id, "position", position.x .. "," .. position.y .. "," .. position.z)
		end

		function self.addClient(clientId, position)
			if self.clients[clientId] then return nil, "duplicate client" end
			local c = { id = clientId, position = position or v3(), acked = {},
				lastFull = -math.huge, received = 0 }
			self.clients[clientId] = c
			self.clientOrder[#self.clientOrder + 1] = clientId
			return c
		end

		function self.moveClient(clientId, position)
			local c = self.clients[clientId]
			if not c then return false end
			c.position = position
			return true
		end

		function self.interestSet(clientId)
			local c = self.clients[clientId]
			if not c then return {} end
			local out = {}
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				if e.position:distance(c.position) <= self.interestRadius then out[#out + 1] = id end
			end
			return out
		end

		local function fieldBytes(value)
			if type(value) == "number" then return 4 end
			if type(value) == "boolean" then return 1 end
			return #tostring(value)
		end

		-- A snapshot is a delta unless the client is due a keyframe.
		function self.snapshotFor(clientId)
			local c = self.clients[clientId]
			if not c then return nil end
			local full = (self.tick - c.lastFull) >= self.fullEvery
			local packet = { tick = self.tick, full = full, entities = {}, bytes = 4 }
			for _, id in ipairs(self.interestSet(clientId)) do
				local e = self.entities[id]
				local payload = {}
				local bytes = 0
				for field, value in pairs(e.fields) do
					if full or e.dirty[field] then
						payload[field] = value
						bytes = bytes + fieldBytes(value) + #field
					end
				end
				if next(payload) ~= nil then
					packet.entities[id] = payload
					packet.bytes = packet.bytes + bytes + #id
				end
			end
			if full then c.lastFull = self.tick end
			return packet
		end

		function self.flush()
			self.tick = self.tick + 1
			local packets = {}
			for _, clientId in ipairs(self.clientOrder) do
				local packet = self.snapshotFor(clientId)
				if packet and next(packet.entities) ~= nil then
					packets[clientId] = packet
					self.bytesSent = self.bytesSent + packet.bytes
					self.packetsSent = self.packetsSent + 1
				end
			end
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				e.dirty = {}
			end
			return packets
		end

		function self.apply(packet, target)
			local applied = 0
			for id, payload in pairs(packet.entities) do
				target[id] = target[id] or {}
				for field, value in pairs(payload) do
					target[id][field] = value
					applied = applied + 1
				end
			end
			return applied
		end

		function self.overMTU(packet) return packet.bytes > self.mtu end

		function self.split(packet)
			if not self.overMTU(packet) then return { packet } end
			local out = {}
			local current = { tick = packet.tick, full = packet.full, entities = {}, bytes = 4 }
			for id, payload in pairs(packet.entities) do
				local bytes = #id
				for field, value in pairs(payload) do bytes = bytes + fieldBytes(value) + #field end
				if current.bytes + bytes > self.mtu and next(current.entities) ~= nil then
					out[#out + 1] = current
					current = { tick = packet.tick, full = packet.full, entities = {}, bytes = 4 }
				end
				current.entities[id] = payload
				current.bytes = current.bytes + bytes
			end
			if next(current.entities) ~= nil then out[#out + 1] = current end
			return out
		end

		function self.bandwidth()
			if self.tick == 0 then return 0 end
			return self.bytesSent / self.tick
		end

		function self.applyQuality(q)
			q = clamp01(q)
			self.interestRadius = self.interestRadius * Mathx.lerp(0.4, 1, q)
			self.fullEvery = math.floor(self.fullEvery * Mathx.lerp(2, 1, q))
			return { interestRadius = self.interestRadius, fullEvery = self.fullEvery }
		end

		function self.stats() return { entities = #self.order, clients = #self.clientOrder,
			tick = self.tick, bytesSent = self.bytesSent, packetsSent = self.packetsSent,
			bandwidth = self.bandwidth(), interestRadius = self.interestRadius } end
		return self
	end

	------------------------------------------------------------------ 98. NETCLOCK
	-- Time synchronization: RTT sampling, offset estimation with outlier rejection,
	-- a jitter buffer for remote snapshots, and a fixed-tick server clock.
	function K.netclock(cfg)
		local self = { kind = "netclock", id = cfg.id, tickRate = cfg.tickRate or 30,
			samples = {}, maxSamples = cfg.maxSamples or 16, offset = 0, rtt = 0,
			jitter = 0, buffer = {}, bufferDelay = cfg.bufferDelay or 0.1,
			localTime = 0, tick = 0, accumulator = 0, corrections = 0, drops = 0 }

		function self.tickDuration() return 1 / self.tickRate end

		function self.sample(sentAt, serverTime, receivedAt)
			local rtt = receivedAt - sentAt
			local estimate = serverTime + rtt / 2 - receivedAt
			self.samples[#self.samples + 1] = { rtt = rtt, offset = estimate }
			while #self.samples > self.maxSamples do table.remove(self.samples, 1) end
			self.recompute()
			return rtt, estimate
		end

		-- Median RTT, then average the offsets whose RTT is not an outlier.
		function self.recompute()
			if #self.samples == 0 then return 0 end
			local rtts = {}
			for i, s in ipairs(self.samples) do rtts[i] = s.rtt end
			table.sort(rtts)
			local median = rtts[math.ceil(#rtts / 2)]
			local sum, n, jitterSum = 0, 0, 0
			for _, s in ipairs(self.samples) do
				if s.rtt <= median * 1.5 + 1e-6 then
					sum = sum + s.offset
					n = n + 1
				end
				jitterSum = jitterSum + math.abs(s.rtt - median)
			end
			self.rtt = median
			self.jitter = jitterSum / #self.samples
			local newOffset = n > 0 and sum / n or self.offset
			if math.abs(newOffset - self.offset) > 0.001 then self.corrections = self.corrections + 1 end
			self.offset = newOffset
			return self.offset
		end

		function self.serverTime() return self.localTime + self.offset end

		function self.advance(dt)
			self.localTime = self.localTime + dt
			self.accumulator = self.accumulator + dt
			local ticks = 0
			local step = self.tickDuration()
			while self.accumulator >= step do
				self.accumulator = self.accumulator - step
				self.tick = self.tick + 1
				ticks = ticks + 1
			end
			return ticks
		end

		function self.push(snapshot, arrivalTime)
			self.buffer[#self.buffer + 1] = { snapshot = snapshot,
				at = (arrivalTime or self.localTime) + self.bufferDelay }
			table.sort(self.buffer, function(a, b) return a.at < b.at end)
			return #self.buffer
		end

		function self.pop()
			local out = {}
			while #self.buffer > 0 and self.buffer[1].at <= self.localTime do
				out[#out + 1] = table.remove(self.buffer, 1).snapshot
			end
			return out
		end

		function self.dropStale(maxAge)
			local before = #self.buffer
			local kept = {}
			for _, entry in ipairs(self.buffer) do
				if self.localTime - entry.at <= (maxAge or 1) then kept[#kept + 1] = entry end
			end
			self.buffer = kept
			self.drops = self.drops + (before - #kept)
			return before - #kept
		end

		function self.interpolationTime() return self.serverTime() - self.bufferDelay end

		function self.setBufferDelay(seconds)
			self.bufferDelay = Mathx.clamp(seconds, 0.016, 1)
			return self.bufferDelay
		end

		function self.adaptBuffer()
			-- More jitter means a deeper buffer; less jitter lets the world feel closer.
			self.bufferDelay = Mathx.clamp(self.jitter * 2 + 0.05, 0.016, 0.5)
			return self.bufferDelay
		end

		function self.stats() return { tickRate = self.tickRate, tick = self.tick,
			rtt = self.rtt, jitter = self.jitter, offset = self.offset,
			buffered = #self.buffer, bufferDelay = self.bufferDelay,
			corrections = self.corrections, drops = self.drops, localTime = self.localTime } end
		return self
	end

	------------------------------------------------------------------ 99. PREDICTION
	-- Client-side prediction with server reconciliation: an input ring, deterministic
	-- replay of unacknowledged inputs, error thresholds and smoothed correction.
	function K.prediction(cfg)
		local self = { kind = "prediction", id = cfg.id, inputs = {}, sequence = 0,
			acked = 0, state = { position = v3(), velocity = v3() },
			serverState = { position = v3(), velocity = v3() },
			errorThreshold = cfg.errorThreshold or 0.05, smoothing = cfg.smoothing or 12,
			replays = 0, corrections = 0, mispredictions = 0, maxInputs = cfg.maxInputs or 120,
			simulate = cfg.simulate }

		-- Default motion model: a simple integrator, replaced per game by cfg.simulate.
		self.simulate = self.simulate or function(state, input, dt)
			local accel = (input.move or v3()) * (input.speed or 10)
			local velocity = (state.velocity + accel * dt) * math.max(0, 1 - 4 * dt)
			return { position = state.position + velocity * dt, velocity = velocity }
		end

		function self.pushInput(input, dt)
			self.sequence = self.sequence + 1
			local record = { sequence = self.sequence, input = input, dt = dt }
			self.inputs[#self.inputs + 1] = record
			while #self.inputs > self.maxInputs do table.remove(self.inputs, 1) end
			self.state = self.simulate(self.state, input, dt)
			return self.sequence, self.state
		end

		function self.pending()
			local n = 0
			for _, record in ipairs(self.inputs) do
				if record.sequence > self.acked then n = n + 1 end
			end
			return n
		end

		-- The server speaks: rewind to its state and replay everything it has not seen.
		function self.reconcile(serverState, ackedSequence)
			self.serverState = serverState
			self.acked = ackedSequence
			local error = serverState.position:distance(self.state.position)
			local kept = {}
			for _, record in ipairs(self.inputs) do
				if record.sequence > ackedSequence then kept[#kept + 1] = record end
			end
			self.inputs = kept
			if error <= self.errorThreshold then
				return false, error
			end
			self.mispredictions = self.mispredictions + 1
			local replayed = { position = serverState.position, velocity = serverState.velocity }
			for _, record in ipairs(self.inputs) do
				replayed = self.simulate(replayed, record.input, record.dt)
				self.replays = self.replays + 1
			end
			self.state = replayed
			self.corrections = self.corrections + 1
			return true, error
		end

		function self.smooth(renderState, dt)
			local blend = 1 - math.exp(-self.smoothing * dt)
			return { position = renderState.position:lerp(self.state.position, blend),
				velocity = self.state.velocity }
		end

		function self.predictionError()
			return self.serverState.position:distance(self.state.position)
		end

		function self.reset(state)
			self.inputs = {}
			self.state = state or { position = v3(), velocity = v3() }
			self.acked = self.sequence
			return true
		end

		function self.applyQuality(q)
			q = clamp01(q)
			self.maxInputs = math.max(15, math.floor(self.maxInputs * Mathx.lerp(0.25, 1, q)))
			self.errorThreshold = self.errorThreshold * Mathx.lerp(3, 1, q)
			return { maxInputs = self.maxInputs, errorThreshold = self.errorThreshold }
		end

		function self.stats() return { sequence = self.sequence, acked = self.acked,
			pending = self.pending(), replays = self.replays, corrections = self.corrections,
			mispredictions = self.mispredictions, errorThreshold = self.errorThreshold,
			maxInputs = self.maxInputs } end
		return self
	end

	K.NAMES = { "stats", "inventory", "quest", "combat", "flex", "inputmap", "tween",
		"replicator", "netclock", "prediction" }

	return K
end
