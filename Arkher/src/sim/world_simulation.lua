-- ARKHER SIMULATION :: World Simulation ("Modo Vida Real")
-- The world keeps living when nobody is looking. Regions are simulated at three fidelities -
-- full agents, aggregated cohorts, statistical drift - and D-O15 decides which is which.
-- When a player arrives, statistics are reified back into agents with a consistent history.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")
	local Random = A:import("arkher/kernel/random")
	local v3 = Vec.vec3

	local WorldSim = {}
	WorldSim.__index = WorldSim

	WorldSim.FIDELITY = { full = 1, cohort = 2, statistical = 3 }

	function WorldSim.new(opts)
		opts = opts or {}
		local self = setmetatable({}, WorldSim)
		self.regions = {}
		self.order = {}
		self.simulation = Kits.create("simulation", { id = "world.sim",
			fullRadius = opts.fullRadius or 250, reducedRadius = opts.reducedRadius or 900,
			budget = opts.budget or 48 })
		self.ledger = Kits.create("ledger", { id = "world.ledger", capacity = 512 })
		self.analyzer = Kits.create("analyzer", { id = "world.analyzer", window = 120 })
		self.budgeter = Kits.create("budgeter", { id = "world.budget",
			total = opts.tickBudget or 240, strategy = "priority" })
		self.rng = Random.new(opts.seed or 20260907)
		self.clock = { hour = opts.startHour or 8, day = 1, season = 1, year = 1 }
		self.dayLength = opts.dayLength or 24
		self.seasonLength = opts.seasonLength or 30
        self.timeScale = opts.timeScale or 60      -- game minutes per real second
		self.ticks = 0
		self.elapsed = 0
		self.reifications = 0
		self.demotions = 0
		self.observers = {}
		self.onEvent = Signal.new("world.event")
		self.onFidelity = Signal.new("world.fidelity")
		self.eventTypes = opts.eventTypes or {
			{ name = "market_day", weight = 3, valence = 0.4 },
			{ name = "storm", weight = 2, valence = -0.5 },
			{ name = "festival", weight = 1, valence = 0.8 },
			{ name = "bandit_raid", weight = 1, valence = -0.8 },
			{ name = "good_harvest", weight = 2, valence = 0.6 },
		}
		return self
	end

	-- ------------------------------------------------------------------ regions
	function WorldSim:addRegion(id, opts)
		opts = opts or {}
		if self.regions[id] then return nil, "duplicate region" end
		local region = {
			id = id, position = opts.position or v3(), radius = opts.radius or 200,
			fidelity = WorldSim.FIDELITY.statistical,
			population = opts.population or 100,
			prosperity = Mathx.clamp(opts.prosperity or 0.5, 0, 1),
			safety = Mathx.clamp(opts.safety or 0.7, 0, 1),
			resources = opts.resources or { food = 500, wood = 300, ore = 120 },
			ecology = Kits.create("ecology", { id = id .. ".ecology" }),
			economy = Kits.create("economy", { id = id .. ".economy" }),
			society = Kits.create("society", { id = id .. ".society" }),
			agents = {}, cohorts = {}, history = {}, events = {},
			lastTick = 0, ticks = 0, drift = 0,
		}
		region.ecology.addSpecies("game", { population = opts.game or 400, growth = 0.2, capacity = 900 })
		region.ecology.addSpecies("predator", { population = opts.predators or 40, growth = -0.08, capacity = 120 })
		region.ecology.link("predator", "game", { predation = 0.0007, efficiency = 0.35 })
		region.economy.defineGood("food", { basePrice = 6 })
		region.economy.defineGood("wood", { basePrice = 4 })
		region.economy.defineGood("ore", { basePrice = 14 })
		region.economy.addMarket(id, { wealth = 400 + region.population * 4 })
		region.economy.setStock(id, "food", region.resources.food)
		region.economy.setStock(id, "wood", region.resources.wood)
		region.economy.setStock(id, "ore", region.resources.ore)
		region.economy.setProduction(id, "food", region.population * 0.02)
		region.economy.setDemand(id, "food", region.population * 0.018)
		region.economy.setProduction(id, "wood", region.population * 0.008)
		region.economy.setDemand(id, "wood", region.population * 0.006)
		self.regions[id] = region
		self.order[#self.order + 1] = id
		return region
	end

	function WorldSim:region(id) return self.regions[id] end

	function WorldSim:setObserver(id, position)
		self.observers[id] = position
		return self:classify()
	end

	function WorldSim:removeObserver(id)
		self.observers[id] = nil
		return self:classify()
	end

	-- Fidelity assignment: the closest observer decides how real a region has to be.
	function WorldSim:classify()
		local counts = { full = 0, cohort = 0, statistical = 0 }
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local nearest = math.huge
			for _, position in pairs(self.observers) do
				local d = region.position:distance(position)
				if d < nearest then nearest = d end
			end
			local fidelity
			if nearest <= self.simulation.fullRadius then
				fidelity = WorldSim.FIDELITY.full
			elseif nearest <= self.simulation.reducedRadius then
				fidelity = WorldSim.FIDELITY.cohort
			else
				fidelity = WorldSim.FIDELITY.statistical
			end
			if fidelity ~= region.fidelity then
				local from = region.fidelity
				region.fidelity = fidelity
				if fidelity < from then
					self:reify(id)
				else
					self.demotions = self.demotions + 1
					self:aggregate(id)
				end
				self.onFidelity:fire({ region = id, from = from, to = fidelity })
			end
			if fidelity == WorldSim.FIDELITY.full then counts.full = counts.full + 1
			elseif fidelity == WorldSim.FIDELITY.cohort then counts.cohort = counts.cohort + 1
			else counts.statistical = counts.statistical + 1 end
		end
		return counts
	end

	-- ------------------------------------------------------------------ fidelity moves
	-- Aggregation: individuals collapse into cohorts, keeping the totals honest.
	function WorldSim:aggregate(id)
		local region = self.regions[id]
		if not region then return 0 end
		local cohorts = {}
		for agentId, agent in pairs(region.agents) do
			local key = agent.role or "citizen"
			cohorts[key] = cohorts[key] or { role = key, count = 0, wellbeing = 0 }
			cohorts[key].count = cohorts[key].count + 1
			cohorts[key].wellbeing = cohorts[key].wellbeing + (agent.wellbeing or 0.5)
		end
		for _, cohort in pairs(cohorts) do
			cohort.wellbeing = cohort.wellbeing / math.max(1, cohort.count)
		end
		region.cohorts = cohorts
		region.agents = {}
		return Hash.fnv1a(id .. tostring(region.population))
	end

	-- Reification: statistics become individuals again, deterministically, with a past.
	function WorldSim:reify(id)
		local region = self.regions[id]
		if not region then return 0 end
		self.reifications = self.reifications + 1
		local rng = Random.new(Hash.fnv1a(id) + self.ticks)
		local made = 0
		local roles = { "farmer", "trader", "guard", "artisan", "elder" }
		local target = math.min(24, math.max(1, math.floor(region.population * 0.08)))
		for i = 1, target do
			local role = roles[(i % #roles) + 1]
			local cohort = region.cohorts[role]
			local wellbeing = cohort and cohort.wellbeing or Mathx.clamp(region.prosperity, 0.2, 0.9)
			local agentId = id .. ".npc" .. i
			region.agents[agentId] = {
				id = agentId, role = role, wellbeing = wellbeing,
				position = region.position + v3((rng:next() - 0.5) * region.radius, 0,
					(rng:next() - 0.5) * region.radius),
				-- a reified NPC remembers the region's history, so it is never "new"
				memories = math.min(#region.events, 6),
				age = 18 + math.floor(rng:next() * 50),
			}
			made = made + 1
		end
		region.cohorts = {}
		self.ledger.write("reify", { region = id, agents = made, tick = self.ticks })
		return made
	end

	-- ------------------------------------------------------------------ the clock
	function WorldSim:advanceClock(dt)
		local minutes = dt * self.timeScale
		self.clock.hour = self.clock.hour + minutes / 60
		while self.clock.hour >= self.dayLength do
			self.clock.hour = self.clock.hour - self.dayLength
			self.clock.day = self.clock.day + 1
			if self.clock.day > self.seasonLength then
				self.clock.day = 1
				self.clock.season = self.clock.season + 1
				if self.clock.season > 4 then
					self.clock.season = 1
					self.clock.year = self.clock.year + 1
				end
			end
		end
		return self.clock
	end

	function WorldSim:isNight() return self.clock.hour < 6 or self.clock.hour >= 20 end

	function WorldSim:seasonName()
		return ({ "spring", "summer", "autumn", "winter" })[self.clock.season] or "spring"
	end

	function WorldSim:seasonModifier()
		return ({ 1.15, 1.3, 1.0, 0.65 })[self.clock.season] or 1
	end

	-- ------------------------------------------------------------------ ticks
	-- A full-fidelity region simulates everything; a cohort region simulates aggregates;
	-- a statistical region drifts on closed-form maths and still writes real history.
	function WorldSim:tickRegion(id, dt)
		local region = self.regions[id]
		if not region then return nil end
		region.ticks = region.ticks + 1
		local season = self:seasonModifier()
		if region.fidelity == WorldSim.FIDELITY.full then
			region.ecology.step(dt)
			region.economy.tick(dt)
			region.economy.setProduction(id, "food", region.population * 0.02 * season)
			region.society.tick(dt)
			for _, agent in pairs(region.agents) do
				agent.wellbeing = Mathx.clamp(agent.wellbeing
					+ (region.prosperity - 0.5) * dt * 0.05, 0, 1)
			end
		elseif region.fidelity == WorldSim.FIDELITY.cohort then
			region.ecology.step(dt * 2)
			region.economy.tick(dt * 2)
			for _, cohort in pairs(region.cohorts) do
				cohort.wellbeing = Mathx.clamp(cohort.wellbeing
					+ (region.prosperity - 0.5) * dt * 0.04, 0, 1)
			end
		else
			-- statistical drift: cheap, deterministic, and still moves the world forward
			region.drift = region.drift + dt
			if region.drift >= 1 then
				local steps = math.floor(region.drift)
				region.drift = region.drift - steps
				region.ecology.step(steps * 3)
				region.economy.tick(steps * 3)
				local food = region.economy.markets[id].stock.food or 0
				local pressure = food / math.max(1, region.population * 6)
				region.population = math.max(1, region.population
					* (1 + (pressure - 0.5) * 0.004 * steps))
				region.prosperity = Mathx.clamp(region.prosperity
					+ (pressure - 0.5) * 0.01 * steps, 0, 1)
			end
		end
		local foodStock = region.economy.markets[id].stock.food or 0
		region.resources.food = foodStock
		region.history[#region.history + 1] = {
			tick = self.ticks, population = region.population,
			prosperity = region.prosperity, food = foodStock }
		if #region.history > 128 then table.remove(region.history, 1) end
		return region
	end

	-- Random world events, deterministic given the seed, with real consequences.
	function WorldSim:rollEvent(id)
		local region = self.regions[id]
		if not region then return nil end
		local totalWeight = 0
		for _, e in ipairs(self.eventTypes) do totalWeight = totalWeight + e.weight end
		local roll = self.rng:next() * totalWeight
		local chosen = self.eventTypes[1]
		for _, e in ipairs(self.eventTypes) do
			roll = roll - e.weight
			if roll <= 0 then chosen = e break end
		end
		local event = { name = chosen.name, region = id, day = self.clock.day,
			season = self:seasonName(), valence = chosen.valence }
		region.events[#region.events + 1] = event
		if #region.events > 32 then table.remove(region.events, 1) end
		if chosen.name == "storm" then
			region.economy.setStock(id, "food",
				(region.economy.markets[id].stock.food or 0) * 0.85)
			region.safety = Mathx.clamp(region.safety - 0.1, 0, 1)
		elseif chosen.name == "good_harvest" then
			region.economy.setStock(id, "food",
				(region.economy.markets[id].stock.food or 0) + region.population * 2)
			region.prosperity = Mathx.clamp(region.prosperity + 0.05, 0, 1)
		elseif chosen.name == "bandit_raid" then
			region.safety = Mathx.clamp(region.safety - 0.2, 0, 1)
			region.population = math.max(1, region.population * 0.98)
		elseif chosen.name == "festival" then
			region.prosperity = Mathx.clamp(region.prosperity + 0.03, 0, 1)
		elseif chosen.name == "market_day" then
			region.economy.balance()
		end
		self.ledger.write("event", event)
		self.onEvent:fire(event)
		return event
	end

	function WorldSim:step(dt)
		self.ticks = self.ticks + 1
		self.elapsed = self.elapsed + dt
		local previousDay = self.clock.day
		self:advanceClock(dt)
		local ranked = {}
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			ranked[#ranked + 1] = { id = id, priority = 4 - region.fidelity }
		end
		table.sort(ranked, function(a, b) return a.priority > b.priority end)
		-- claim -> allocate -> spend: the D-O15 budgeter decides who gets simulated this tick
		local costs = {}
		for _, entry in ipairs(ranked) do
			local region = self.regions[entry.id]
			local cost = ({ 6, 3, 1 })[region.fidelity]
			costs[entry.id] = cost
			self.budgeter.claim(entry.id, cost, entry.priority)
		end
		local granted = self.budgeter.allocate()
		local simulated, starved = 0, 0
		for _, entry in ipairs(ranked) do
			local allowance = granted[entry.id] or 0
			if allowance >= costs[entry.id] * 0.5 then
				self:tickRegion(entry.id, dt)
				simulated = simulated + 1
			else
				starved = starved + 1
				self.regions[entry.id].drift = self.regions[entry.id].drift + dt
			end
			self.budgeter.release(entry.id)
		end
		self.starved = (self.starved or 0) + starved
		if self.clock.day ~= previousDay then
			for _, id in ipairs(self.order) do self:rollEvent(id) end
		end
		self.analyzer.submit(simulated)
		return { simulated = simulated, starved = starved, regions = #self.order,
			day = self.clock.day, hour = self.clock.hour }
	end

	function WorldSim:run(seconds, dt)
		dt = dt or (1 / 30)
		for _ = 1, math.floor(seconds / dt) do self:step(dt) end
		return self.elapsed
	end

	-- ------------------------------------------------------------------ inspection
	function WorldSim:totalPopulation()
		local total = 0
		for _, id in ipairs(self.order) do total = total + self.regions[id].population end
		return total
	end

	function WorldSim:worldState()
		local prosperity, safety = 0, 0
		for _, id in ipairs(self.order) do
			prosperity = prosperity + self.regions[id].prosperity
			safety = safety + self.regions[id].safety
		end
		local n = math.max(1, #self.order)
		return { population = self:totalPopulation(), prosperity = prosperity / n,
			safety = safety / n, season = self:seasonName(), day = self.clock.day,
			year = self.clock.year, night = self:isNight() }
	end

	function WorldSim:checksum()
		local parts = {}
		for _, id in ipairs(self.order) do
			local r = self.regions[id]
			parts[#parts + 1] = string.format("%s:%d:%.3f", id,
				math.floor(r.population), r.prosperity)
		end
		table.sort(parts)
		return Hash.fnv1a(table.concat(parts, "|"))
	end

	function WorldSim:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.budgeter.total = math.max(20, math.floor(20 + quality * 400))
		self.simulation.fullRadius = Mathx.lerp(90, 350, quality)
		self.simulation.reducedRadius = Mathx.lerp(350, 1400, quality)
		return { tickBudget = self.budgeter.total, fullRadius = self.simulation.fullRadius }
	end

	function WorldSim:report()
		local byFidelity = { full = 0, cohort = 0, statistical = 0 }
		local agents, events = 0, 0
		for _, id in ipairs(self.order) do
			local region = self.regions[id]
			local name = ({ "full", "cohort", "statistical" })[region.fidelity]
			byFidelity[name] = byFidelity[name] + 1
			for _ in pairs(region.agents) do agents = agents + 1 end
			events = events + #region.events
		end
		return { regions = #self.order, byFidelity = byFidelity, liveAgents = agents,
			events = events, ticks = self.ticks, reifications = self.reifications,
			demotions = self.demotions, starved = self.starved or 0,
			clock = self.clock, world = self:worldState(),
			checksum = self:checksum(), ledger = self.ledger.stats() }
	end

	return WorldSim
end
