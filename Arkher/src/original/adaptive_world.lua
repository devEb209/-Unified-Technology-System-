-- ARKHER ORIGINAL :: Adaptive World Intelligence
-- The world keeps living when nobody is watching, but it does not keep costing. Regions
-- carry an observation level; the fabric steps each domain at the rate that level earns;
-- unobserved regions run in coarse statistical mode and are reconciled on return; the
-- complexity manager holds the frame budget; world memory keeps the past; and the
-- emergence detector names the behaviour nobody scripted.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")

	local World = {}
	World.__index = World

	local TIERS = {
		{ name = "observed", radius = 180, hz = 30, fidelity = 1 },
		{ name = "near", radius = 500, hz = 8, fidelity = 0.6 },
		{ name = "far", radius = 1400, hz = 2, fidelity = 0.3 },
		{ name = "dormant", radius = math.huge, hz = 0.25, fidelity = 0.1 },
	}

	function World.new(opts)
		opts = opts or {}
		local self = setmetatable({}, World)
		self.reality = Kits.create("reality", { id = "adaptive.reality" })
		self.reality.installStack()
		self.complexity = Kits.create("complexity", { id = "adaptive.complexity",
			targetMs = opts.targetMs or 16.6 })
		self.fabric = Kits.create("fabric", { id = "adaptive.fabric",
			budgetMs = opts.budgetMs or 6 })
		self.memory = Kits.create("worldmemory", { id = "adaptive.memory",
			capacity = opts.memoryCapacity or 512 })
		self.emergence = Kits.create("emergence", { id = "adaptive.emergence",
			windowSize = 6, threshold = 1.3, minCount = 2 })
		self.regions = {}
		self.order = {}
		self.observers = {}
		self.time = 0
		self.ticks = 0
		self.reconciliations = 0
		self.onTierChange = Signal.new()
		self.onPhenomenon = Signal.new()
		self:installDomains()
		return self
	end

	function World:installDomains()
		local this = self
		self.fabric.addDomain("ecology", { hz = 4, cost = 1, priority = 1,
			step = function(dt) this:stepEcology(dt) end })
		self.fabric.addDomain("economy", { hz = 2, cost = 1.5, priority = 2,
			step = function(dt) this:stepEconomy(dt) end })
		self.fabric.addDomain("society", { hz = 3, cost = 2, priority = 3,
			step = function(dt) this:stepSociety(dt) end })
		self.fabric.addDomain("weather", { hz = 1, cost = 0.5, priority = 1,
			step = function(dt) this:stepWeather(dt) end })
		return #self.fabric.order
	end

	-- ------------------------------------------------------------------ regions
	function World:addRegion(id, opts)
		opts = opts or {}
		if self.regions[id] then return nil, "duplicate region" end
		local region = { id = id, position = opts.position or Vec.vec3(),
			population = opts.population or 0, resources = opts.resources or 100,
			wealth = opts.wealth or 50, unrest = opts.unrest or 0,
			weather = opts.weather or 0.5, tier = "dormant", fidelity = 0.1,
			counts = { objects = opts.objects or 0, agents = opts.population or 0,
				lights = opts.lights or 0, effects = 0 },
			lastSimulated = 0, debt = 0, events = 0 }
		self.regions[id] = region
		self.order[#self.order + 1] = id
		self.complexity.addZone(id, region.counts)
		self.reality.set("authored", id .. ".population", region.population)
		self.reality.set("authored", id .. ".wealth", region.wealth)
		return region
	end

	function World:addObserver(id, position)
		self.observers[id] = position or Vec.vec3()
		return true
	end

	function World:moveObserver(id, position)
		if not self.observers[id] then return false end
		self.observers[id] = position
		return true
	end

	function World:removeObserver(id)
		self.observers[id] = nil
		return true
	end

	function World:distanceToNearestObserver(region)
		local best = math.huge
		for _, position in pairs(self.observers) do
			local d = region.position:distance(position)
			if d < best then best = d end
		end
		return best
	end

	function World:classify()
		local changes = 0
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local distance = self:distanceToNearestObserver(region)
			local tier = TIERS[#TIERS]
			for _, candidate in ipairs(TIERS) do
				if distance <= candidate.radius then tier = candidate break end
			end
			if region.tier ~= tier.name then
				local previous = region.tier
				region.tier = tier.name
				region.fidelity = tier.fidelity
				self.complexity.setImportance(id, tier.fidelity * 2)
				changes = changes + 1
				self.onTierChange:fire({ region = id, from = previous, to = tier.name })
				if previous ~= "observed" and tier.name == "observed" then
					self:reconcile(id)
				end
			end
		end
		return changes
	end

	-- ------------------------------------------------------------------ simulation
	-- Coarse mode: instead of stepping every agent, a region accumulates statistical debt
	-- that is resolved in one pass the moment somebody looks at it again.
	function World:stepEcology(dt)
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local rate = dt * region.fidelity
			local regrowth = (1 - region.resources / 200) * 4 * rate
			region.resources = Mathx.clamp(region.resources + regrowth
				- region.population * 0.002 * rate * 60, 0, 200)
			if region.fidelity < 1 then region.debt = region.debt + rate * 0.25 end
		end
	end

	function World:stepEconomy(dt)
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local rate = dt * region.fidelity
			local production = region.population * 0.01 * (region.resources / 100)
			region.wealth = math.max(0, region.wealth + (production - region.population * 0.004) * rate * 10)
			self.reality.set("simulated", id .. ".wealth", region.wealth)
			if region.wealth > 120 then self.emergence.observe("boom." .. id) end
			if region.wealth < 10 then self.emergence.observe("bust." .. id) end
		end
	end

	function World:stepSociety(dt)
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local rate = dt * region.fidelity
			local scarcity = 1 - Mathx.clamp(region.resources / 120, 0, 1)
			region.unrest = Mathx.clamp(region.unrest + (scarcity * 0.4 - 0.1) * rate, 0, 1)
			local growth = (region.wealth > 40 and 0.02 or -0.01) * rate * region.population
			region.population = math.max(0, region.population + growth)
			region.counts.agents = math.floor(region.population)
			self.complexity.setCounts(id, { agents = region.counts.agents })
			self.reality.set("simulated", id .. ".population", region.population)
			if region.unrest > 0.7 then
				self.emergence.observe("unrest." .. id)
				self.memory.remember(id, "unrest", { weight = region.unrest, region = id })
				region.events = region.events + 1
			end
			self.emergence.signal("unrest", region.unrest)
		end
	end

	function World:stepWeather(dt)
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			region.weather = Mathx.clamp(region.weather
				+ math.sin(self.time * 0.3 + #id) * dt * 0.15, 0, 1)
			if region.weather > 0.9 then self.emergence.observe("storm." .. id) end
		end
	end

	-- Resolve everything a dormant region owes: one catch-up pass, not a rewind.
	function World:reconcile(id)
		local region = self.regions[id]
		if not region or region.debt <= 0 then return 0 end
		local debt = region.debt
		region.resources = Mathx.clamp(region.resources + debt * 2, 0, 200)
		region.wealth = math.max(0, region.wealth + debt * region.population * 0.01)
		region.debt = 0
		self.reconciliations = self.reconciliations + 1
		self.memory.remember(id, "reconciled", { weight = debt, region = id })
		return debt
	end

	function World:tick(dt)
		self.time = self.time + dt
		self.ticks = self.ticks + 1
		self.memory.advance(dt)
		self:classify()
		local ran = self.fabric.tick(dt)
		local evaluation = self.complexity.evaluate()
		if evaluation.pressure > 1 then
			self.fabric.applyQuality(Mathx.clamp(1 / evaluation.pressure, 0.2, 1))
		end
		local phenomena = self.emergence.detect()
		for _, item in ipairs(phenomena) do
			self.onPhenomenon:fire(item)
		end
		return { ran = ran, pressure = evaluation.pressure, phenomena = #phenomena }
	end

	function World:run(seconds, dt)
		local step = dt or 1 / 15
		local n = math.max(1, math.floor(seconds / step))
		local last
		for _ = 1, n do last = self:tick(step) end
		return last
	end

	-- ------------------------------------------------------------------ state
	function World:snapshot()
		local snapshot = { time = self.time, regions = {},
			memory = self.memory.checkpoint("adaptive"), reality = self.reality.snapshot() }
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			snapshot.regions[id] = { population = region.population,
				resources = region.resources, wealth = region.wealth,
				unrest = region.unrest, weather = region.weather, debt = region.debt,
				tier = region.tier, events = region.events }
		end
		return snapshot
	end

	function World:restore(snapshot)
		if not snapshot then return false end
		self.time = snapshot.time
		for id, state in pairs(snapshot.regions) do
			local region = self.regions[id]
			if region then
				for key, value in pairs(state) do region[key] = value end
				region.counts.agents = math.floor(region.population)
			end
		end
		self.memory.restore(snapshot.memory)
		return true
	end

	function World:tierOf(id)
		local region = self.regions[id]
		return region and region.tier or nil
	end

	function World:report()
		local byTier = {}
		local population = 0
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			byTier[region.tier] = (byTier[region.tier] or 0) + 1
			population = population + region.population
		end
		return { regions = #self.order, byTier = byTier, population = population,
			ticks = self.ticks, reconciliations = self.reconciliations,
			fabric = self.fabric.stats(), complexity = self.complexity.stats(),
			memory = self.memory.stats(), emergence = self.emergence.stats(),
			reality = self.reality.stats(), phenomena = self.emergence.named() }
	end

	World.TIERS = TIERS
	return World
end
