-- ARKHER GAMEPLAY :: Gameplay Framework
-- Characters made of real numbers: attributes with modifiers, inventories with weight and
-- crafting, quests that react to what happens, combat that resolves with mitigation and
-- status effects, plus progression and a save/load codec over the whole thing.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")

	local Gameplay = {}
	Gameplay.__index = Gameplay

	function Gameplay.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Gameplay)
		self.entities = {}
		self.order = {}
		self.combat = Kits.create("combat", { id = "play.combat", seed = opts.seed or 7 })
		self.quests = Kits.create("quest", { id = "play.quests" })
		self.ledger = Kits.create("ledger", { id = "play.ledger", capacity = 512 })
		self.difficulty = Kits.create("controller", { id = "play.difficulty", mode = "pid",
			target = 0.55, kp = 0.4, ki = 0.05, kd = 0.02, min = 0.25, max = 2.0, initial = 1 })
		self.codec = Kits.create("codec", { id = "play.save", format = "json" })
		self.time = 0
		self.xpCurve = opts.xpCurve or function(level) return 100 * level * level end
		self.onLevel = Signal.new()
		self.onDeath = Signal.new()
		self.onReward = Signal.new()
		return self
	end

	-- ------------------------------------------------------------------ entities
	function Gameplay:createEntity(id, opts)
		if self.entities[id] then return nil, "duplicate entity" end
		opts = opts or {}
		local stats = Kits.create("stats", { id = id .. ".stats" })
		stats.define("vitality", opts.vitality or 10, { min = 1, max = 999 })
		stats.define("strength", opts.strength or 10, { min = 1, max = 999 })
		stats.define("agility", opts.agility or 10, { min = 1, max = 999 })
		stats.define("intellect", opts.intellect or 10, { min = 1, max = 999 })
		stats.define("armour", opts.armour or 5, { min = 0, max = 500 })
		stats.defineDerived("maxHealth", function(s) return 20 + s.get("vitality") * 8 end)
		stats.defineDerived("power", function(s) return s.get("strength") * 1.5 + s.get("agility") * 0.5 end)
		stats.defineDerived("critChance", function(s) return Mathx.clamp(0.02 + s.get("agility") * 0.004, 0, 0.6) end)

		local inventory = Kits.create("inventory", { id = id .. ".inventory",
			slots = opts.slots or 20, maxWeight = opts.maxWeight or 80 })

		local entity = { id = id, stats = stats, inventory = inventory,
			level = opts.level or 1, xp = 0, team = opts.team or "player",
			alive = true, gold = opts.gold or 0 }
		self.entities[id] = entity
		self.order[#self.order + 1] = id

		self.combat.addActor(id, { health = stats.getDerived("maxHealth"),
			armour = stats.get("armour"), power = stats.getDerived("power"),
			critChance = stats.getDerived("critChance"),
			accuracy = 0.85 + stats.get("agility") * 0.005, team = entity.team })
		return entity
	end

	function Gameplay:get(id) return self.entities[id] end

	function Gameplay:actor(id) return self.combat.actors[id] end

	-- Stats feed combat: change an attribute and the fighter changes with it.
	function Gameplay:syncActor(id)
		local entity = self.entities[id]
		local actor = self.combat.actors[id]
		if not entity or not actor then return false end
		local maxHealth = entity.stats.getDerived("maxHealth")
		local ratio = actor.maxHealth > 0 and actor.health / actor.maxHealth or 1
		actor.maxHealth = maxHealth
		actor.health = math.min(maxHealth, maxHealth * ratio)
		actor.armour = entity.stats.get("armour")
		actor.power = entity.stats.getDerived("power")
		actor.critChance = entity.stats.getDerived("critChance")
		return true
	end

	function Gameplay:equip(id, item)
		local entity = self.entities[id]
		if not entity then return false end
		local ok, previous = entity.inventory.equip(item)
		if not ok then return false end
		local def = entity.inventory.defs[item]
		if def and def.tags then
			for stat, amount in pairs(def.tags) do
				entity.stats.addModifier(stat, "equip." .. item, { flat = amount, source = item })
			end
		end
		if previous then entity.stats.removeModifier("equip." .. previous) end
		self:syncActor(id)
		return true, previous
	end

	function Gameplay:unequip(id, slot)
		local entity = self.entities[id]
		if not entity then return false end
		local item = entity.inventory.unequip(slot)
		if not item then return false end
		entity.stats.removeModifier("equip." .. item)
		self:syncActor(id)
		return item
	end

	-- ------------------------------------------------------------------ progression
	function Gameplay:grantXp(id, amount)
		local entity = self.entities[id]
		if not entity then return 0 end
		entity.xp = entity.xp + amount
		local levelled = 0
		while entity.xp >= self.xpCurve(entity.level) do
			entity.xp = entity.xp - self.xpCurve(entity.level)
			entity.level = entity.level + 1
			levelled = levelled + 1
			entity.stats.setBase("vitality", entity.stats.base.vitality.value + 2)
			entity.stats.setBase("strength", entity.stats.base.strength.value + 1)
			self:syncActor(id)
			local actor = self.combat.actors[id]
			if actor then actor.health = actor.maxHealth end
			self.onLevel:fire({ id = id, level = entity.level })
			self.ledger.write("level", { id = id, level = entity.level })
		end
		return levelled, entity.level
	end

	function Gameplay:xpToNext(id)
		local entity = self.entities[id]
		if not entity then return 0 end
		return self.xpCurve(entity.level) - entity.xp
	end

	-- ------------------------------------------------------------------ combat flow
	function Gameplay:attack(attackerId, defenderId, opts)
		local result = self.combat.attack(attackerId, defenderId, opts)
		if not result then return nil end
		self.ledger.write("attack", { attacker = attackerId, defender = defenderId,
			damage = result.damage or 0, hit = result.hit })
		if result.killed then
			local victim = self.entities[defenderId]
			if victim then victim.alive = false end
			self.onDeath:fire({ id = defenderId, by = attackerId })
			self.quests.notify("kill." .. defenderId, 1)
			self.quests.notify("kill", 1)
			self:grantXp(attackerId, 25 + (victim and victim.level or 1) * 10)
		end
		return result
	end

	function Gameplay:useAbility(id, ability, targetId, opts)
		opts = opts or {}
		if not self.combat.ready(id, ability) then return nil, "on cooldown" end
		self.combat.setCooldown(id, ability, opts.cooldown or 3)
		if opts.status then
			self.combat.applyStatus(targetId, opts.status, opts)
		end
		if opts.damage ~= false then
			return self:attack(id, targetId, { power = opts.power, scale = opts.scale or 1,
				damageType = opts.damageType })
		end
		return { hit = true, damage = 0, status = opts.status }
	end

	function Gameplay:loot(killerId, item, count)
		local entity = self.entities[killerId]
		if not entity then return 0 end
		local added = entity.inventory.add(item, count or 1)
		if added > 0 then
			self.quests.notify("collect." .. item, added)
			self.quests.notify("collect", added)
			self.onReward:fire({ id = killerId, item = item, count = added })
		end
		return added
	end

	-- ------------------------------------------------------------------ frame
	function Gameplay:update(dt)
		self.time = self.time + dt
		self.combat.tick(dt)
		for _, id in ipairs(self.order) do
			local entity = self.entities[id]
			entity.stats.tick(dt)
			local actor = self.combat.actors[id]
			if actor and not actor.alive and entity.alive then
				entity.alive = false
				self.onDeath:fire({ id = id })
			end
		end
		return self.time
	end

	function Gameplay:run(seconds, dt)
		local step = dt or 1 / 20
		local n = math.max(1, math.floor(seconds / step))
		for _ = 1, n do self:update(step) end
		return self.time
	end

	-- Difficulty adapts to the player's actual win rate, not to a menu setting.
	function Gameplay:tuneDifficulty(playerWinRate, dt)
		self.difficulty.submit(playerWinRate)
		return self.difficulty.step(dt or 1)
	end

	-- ------------------------------------------------------------------ persistence
	function Gameplay:save()
		local payload = { time = self.time, entities = {} }
		for _, id in ipairs(self.order) do
			local e = self.entities[id]
			local actor = self.combat.actors[id]
			payload.entities[#payload.entities + 1] = {
				id = id, level = e.level, xp = e.xp, gold = e.gold, team = e.team,
				alive = e.alive, health = actor and actor.health or 0,
				stats = e.stats.snapshot(), inventory = e.inventory.serialize() }
		end
		return self.codec.encode(payload)
	end

	function Gameplay:load(blob)
		local payload = self.codec.decode(blob)
		if not payload then return false end
		self.time = payload.time or 0
		local restored = 0
		for _, saved in ipairs(payload.entities or {}) do
			local entity = self.entities[saved.id]
			if entity then
				entity.level = saved.level
				entity.xp = saved.xp
				entity.gold = saved.gold
				entity.alive = saved.alive
				entity.inventory.deserialize(saved.inventory)
				local actor = self.combat.actors[saved.id]
				if actor then
					actor.health = saved.health
					actor.alive = saved.alive
				end
				restored = restored + 1
			end
		end
		return restored
	end

	function Gameplay:checksum()
		local acc = 0
		for _, id in ipairs(self.order) do
			local e = self.entities[id]
			local actor = self.combat.actors[id]
			acc = acc + e.level * 31 + e.xp * 7 + math.floor((actor and actor.health or 0) * 100)
				+ e.inventory.totalValue() * 3
		end
		return math.floor(acc)
	end

	function Gameplay:report()
		return { entities = #self.order, alive = self.combat.teamAlive("player"),
			combat = self.combat.stats(), quests = self.quests.stats(),
			time = self.time, difficulty = self.difficulty.stats().value,
			events = self.ledger.stats().written }
	end

	return Gameplay
end
