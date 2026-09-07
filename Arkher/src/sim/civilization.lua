-- ARKHER SIMULATION :: Emergent Society Framework
-- Settlements, factions, trade routes, laws and rumours: the layer where a world stops being
-- a set of props and starts having politics. Everything here is deterministic and auditable -
-- a society you cannot replay is a society you cannot debug.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")
	local Random = A:import("arkher/kernel/random")
	local v3 = Vec.vec3

	local Civilization = {}
	Civilization.__index = Civilization

	-- Laws are not flavour text: each one changes a number the simulation reads.
	Civilization.LAWS = {
		curfew        = { safety = 0.12, prosperity = -0.05, unrest = 0.06 },
		free_trade    = { prosperity = 0.14, safety = -0.03, unrest = -0.04 },
		conscription  = { safety = 0.18, prosperity = -0.10, unrest = 0.12 },
		tithe         = { prosperity = -0.06, unrest = 0.08, treasury = 0.15 },
		public_works  = { prosperity = 0.10, unrest = -0.10, treasury = -0.12 },
		open_borders  = { prosperity = 0.08, safety = -0.08, unrest = 0.02 },
	}

	function Civilization.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Civilization)
		self.settlements = {}
		self.settlementOrder = {}
		self.factions = {}
		self.factionOrder = {}
		self.routes = {}
		self.society = Kits.create("society", { id = "civ.society", gossipReach = 4 })
		self.economy = Kits.create("economy", { id = "civ.economy", elasticity = 0.3 })
		self.graph = Kits.create("graph", { id = "civ.routes", directed = false })
		self.ledger = Kits.create("ledger", { id = "civ.history", capacity = 512 })
		self.rng = Random.new(opts.seed or 4242)
		self.time = 0
		self.ticks = 0
		self.wars = 0
		self.treaties = 0
		self.migrations = 0
		self.onHistory = Signal.new("civ.history")
		self.economy.defineGood("food", { basePrice = 6 })
		self.economy.defineGood("wood", { basePrice = 4 })
		self.economy.defineGood("ore", { basePrice = 14 })
		self.economy.defineGood("tools", { basePrice = 26 })
		return self
	end

	-- ------------------------------------------------------------------ settlements
	function Civilization:found(id, opts)
		opts = opts or {}
		if self.settlements[id] then return nil, "duplicate settlement" end
		local settlement = {
			id = id, name = opts.name or id, position = opts.position or v3(),
			population = opts.population or 200, faction = opts.faction,
			prosperity = Mathx.clamp(opts.prosperity or 0.5, 0, 1),
			safety = Mathx.clamp(opts.safety or 0.7, 0, 1),
			unrest = Mathx.clamp(opts.unrest or 0.1, 0, 1),
			treasury = opts.treasury or 500,
			laws = {}, specialties = opts.specialties or { "food" },
			founded = self.ticks, history = {},
		}
		self.settlements[id] = settlement
		self.settlementOrder[#self.settlementOrder + 1] = id
		self.economy.addMarket(id, { wealth = settlement.treasury, position = settlement.position })
		for _, good in ipairs({ "food", "wood", "ore", "tools" }) do
			self.economy.setStock(id, good, 100)
			self.economy.setDemand(id, good, settlement.population * 0.004)
		end
		for _, good in ipairs(settlement.specialties) do
			self.economy.setProduction(id, good, settlement.population * 0.012)
		end
		self.graph.addNode(id)
		if opts.faction then self:joinFaction(id, opts.faction) end
		self.ledger.write("found", { settlement = id, population = settlement.population })
		return settlement
	end

	function Civilization:settlement(id) return self.settlements[id] end

	function Civilization:defineFaction(id, opts)
		opts = opts or {}
		if self.factions[id] then return self.factions[id] end
		local faction = { id = id, name = opts.name or id, settlements = {},
			aggression = Mathx.clamp(opts.aggression or 0.3, 0, 1),
			wealth = opts.wealth or 1000, atWarWith = {}, allies = {} }
		self.factions[id] = faction
		self.factionOrder[#self.factionOrder + 1] = id
		self.society.join(id, { faction = id })
		return faction
	end

	function Civilization:joinFaction(settlementId, factionId)
		local settlement = self.settlements[settlementId]
		if not settlement then return false end
		local faction = self:defineFaction(factionId)
		settlement.faction = factionId
		table.insert(faction.settlements, settlementId)
		return true
	end

	-- ------------------------------------------------------------------ trade routes
	function Civilization:connect(a, b, opts)
		opts = opts or {}
		local sa, sb = self.settlements[a], self.settlements[b]
		if not sa or not sb then return nil, "unknown settlement" end
		local distance = sa.position:distance(sb.position)
		local danger = Mathx.clamp(opts.danger or (1 - (sa.safety + sb.safety) * 0.5), 0, 1)
		local route = { a = a, b = b, distance = distance, danger = danger,
			capacity = opts.capacity or 40, volume = 0, raids = 0 }
		self.routes[#self.routes + 1] = route
		self.graph.addEdge(a, b, distance * (1 + danger))
		return route
	end

	function Civilization:routeBetween(a, b)
		for _, route in ipairs(self.routes) do
			if (route.a == a and route.b == b) or (route.a == b and route.b == a) then
				return route
			end
		end
		return nil
	end

	function Civilization:tradePath(a, b)
		return self.graph.shortestPath(a, b)
	end

	-- Trade runs along real routes: danger reduces throughput, distance costs money.
	function Civilization:runTrade(dt)
		local moved = 0
		for _, route in ipairs(self.routes) do
			local sa, sb = self.settlements[route.a], self.settlements[route.b]
			if sa and sb then
				for _, good in ipairs({ "food", "wood", "ore", "tools" }) do
					local stockA = self.economy.markets[route.a].stock[good] or 0
					local stockB = self.economy.markets[route.b].stock[good] or 0
					local diff = stockA - stockB
					if math.abs(diff) > 20 then
						local from = diff > 0 and route.a or route.b
						local to = diff > 0 and route.b or route.a
						local amount = math.min(route.capacity * dt,
							math.abs(diff) * 0.25) * (1 - route.danger * 0.6)
						local sent = self.economy.trade(from, to, good, amount)
						if sent and sent > 0 then
							route.volume = route.volume + sent
							moved = moved + sent
						end
					end
				end
				if self.rng:next() < route.danger * 0.01 then
					route.raids = route.raids + 1
					sa.safety = Mathx.clamp(sa.safety - 0.02, 0, 1)
					sb.safety = Mathx.clamp(sb.safety - 0.02, 0, 1)
					self.ledger.write("raid", { route = route.a .. "-" .. route.b })
				end
			end
		end
		return moved
	end

	-- ------------------------------------------------------------------ laws
	function Civilization:enact(settlementId, law)
		local settlement = self.settlements[settlementId]
		local effects = Civilization.LAWS[law]
		if not settlement or not effects then return nil, "unknown law" end
		if settlement.laws[law] then return nil, "already enacted" end
		settlement.laws[law] = true
		settlement.safety = Mathx.clamp(settlement.safety + (effects.safety or 0), 0, 1)
		settlement.prosperity = Mathx.clamp(settlement.prosperity + (effects.prosperity or 0), 0, 1)
		settlement.unrest = Mathx.clamp(settlement.unrest + (effects.unrest or 0), 0, 1)
		settlement.treasury = settlement.treasury * (1 + (effects.treasury or 0))
		self.ledger.write("law", { settlement = settlementId, law = law })
		self.onHistory:fire({ kind = "law", settlement = settlementId, law = law })
		return settlement
	end

	function Civilization:repeal(settlementId, law)
		local settlement = self.settlements[settlementId]
		local effects = Civilization.LAWS[law]
		if not settlement or not effects or not settlement.laws[law] then return false end
		settlement.laws[law] = nil
		settlement.safety = Mathx.clamp(settlement.safety - (effects.safety or 0), 0, 1)
		settlement.prosperity = Mathx.clamp(settlement.prosperity - (effects.prosperity or 0), 0, 1)
		settlement.unrest = Mathx.clamp(settlement.unrest - (effects.unrest or 0), 0, 1)
		return true
	end

	-- ------------------------------------------------------------------ diplomacy
	function Civilization:declareWar(a, b)
		local fa, fb = self.factions[a], self.factions[b]
		if not fa or not fb or fa.atWarWith[b] then return false end
		fa.atWarWith[b] = true
		fb.atWarWith[a] = true
		self.wars = self.wars + 1
		self.society.setFactionStanding(a, b, -1)
		self.ledger.write("war", { a = a, b = b, tick = self.ticks })
		self.onHistory:fire({ kind = "war", a = a, b = b })
		return true
	end

	function Civilization:makePeace(a, b)
		local fa, fb = self.factions[a], self.factions[b]
		if not fa or not fb or not fa.atWarWith[b] then return false end
		fa.atWarWith[b] = nil
		fb.atWarWith[a] = nil
		self.treaties = self.treaties + 1
		self.society.setFactionStanding(a, b, 0.3)
		self.ledger.write("peace", { a = a, b = b, tick = self.ticks })
		self.onHistory:fire({ kind = "peace", a = a, b = b })
		return true
	end

	function Civilization:atWar(a, b)
		return self.factions[a] ~= nil and self.factions[a].atWarWith[b] == true
	end

	-- ------------------------------------------------------------------ population
	-- People move toward prosperity and away from unrest: migration is emergent, not scripted.
	function Civilization:migrate(dt)
		if #self.settlementOrder < 2 then return 0 end
		local best, worst, bestScore, worstScore = nil, nil, -math.huge, math.huge
		for _, id in ipairs(self.settlementOrder) do
			local s = self.settlements[id]
			local score = s.prosperity * 1.2 + s.safety * 0.8 - s.unrest
			if score > bestScore then bestScore = score best = id end
			if score < worstScore then worstScore = score worst = id end
		end
		if not best or not worst or best == worst then return 0 end
		local gap = bestScore - worstScore
		if gap < 0.25 then return 0 end
		local movers = math.min(self.settlements[worst].population * 0.02,
			gap * 8) * dt
		if movers < 0.01 then return 0 end
		self.settlements[worst].population = math.max(1,
			self.settlements[worst].population - movers)
		self.settlements[best].population = self.settlements[best].population + movers
		self.migrations = self.migrations + 1
		self.ledger.write("migration", { from = worst, to = best, people = movers })
		return movers
	end

	function Civilization:tick(dt)
		self.ticks = self.ticks + 1
		self.time = self.time + dt
		self.economy.tick(dt)
		self.society.tick(dt)
		self:runTrade(dt)
		self:migrate(dt)
		for _, id in ipairs(self.settlementOrder) do
			local s = self.settlements[id]
			local food = self.economy.markets[id].stock.food or 0
			local need = s.population * 0.004
			local pressure = food / math.max(0.001, need * 100)
			s.prosperity = Mathx.clamp(s.prosperity + (pressure - 0.5) * dt * 0.05, 0, 1)
			s.unrest = Mathx.clamp(s.unrest + (0.4 - s.prosperity) * dt * 0.03, 0, 1)
			s.population = math.max(1, s.population * (1 + (s.prosperity - 0.45) * dt * 0.01))
			s.treasury = s.treasury + s.population * s.prosperity * dt * 0.05
			if s.unrest > 0.8 then
				self.ledger.write("revolt", { settlement = id, unrest = s.unrest })
				self.onHistory:fire({ kind = "revolt", settlement = id })
				s.unrest = 0.4
				s.prosperity = Mathx.clamp(s.prosperity - 0.15, 0, 1)
			end
			s.history[#s.history + 1] = { tick = self.ticks, population = s.population,
				prosperity = s.prosperity, unrest = s.unrest }
			if #s.history > 64 then table.remove(s.history, 1) end
		end
		-- factions at war bleed each other, factions at peace grow
		for _, id in ipairs(self.factionOrder) do
			local faction = self.factions[id]
			local wars = 0
			for _ in pairs(faction.atWarWith) do wars = wars + 1 end
			for _, settlementId in ipairs(faction.settlements) do
				local s = self.settlements[settlementId]
				if s then
					if wars > 0 then
						s.safety = Mathx.clamp(s.safety - 0.01 * wars * dt, 0, 1)
						s.unrest = Mathx.clamp(s.unrest + 0.008 * wars * dt, 0, 1)
					else
						s.safety = Mathx.clamp(s.safety + 0.004 * dt, 0, 1)
					end
				end
			end
		end
		return self.ticks
	end

	function Civilization:run(seconds, dt)
		dt = dt or 0.1
		for _ = 1, math.floor(seconds / dt) do self:tick(dt) end
		return self.time
	end

	-- ------------------------------------------------------------------ inspection
	function Civilization:totalPopulation()
		local total = 0
		for _, id in ipairs(self.settlementOrder) do
			total = total + self.settlements[id].population
		end
		return total
	end

	function Civilization:largest()
		local best, bestPop = nil, -1
		for _, id in ipairs(self.settlementOrder) do
			if self.settlements[id].population > bestPop then
				bestPop = self.settlements[id].population
				best = id
			end
		end
		return best, bestPop
	end

	function Civilization:chronicle(limit)
		local entries = self.ledger.query(nil, limit or 20)
		local out = {}
		for _, entry in ipairs(entries) do
			out[#out + 1] = { kind = entry.kind, payload = entry.payload }
		end
		return out
	end

	function Civilization:checksum()
		local parts = {}
		for _, id in ipairs(self.settlementOrder) do
			local s = self.settlements[id]
			parts[#parts + 1] = string.format("%s:%d:%.3f:%.3f", id,
				math.floor(s.population), s.prosperity, s.unrest)
		end
		table.sort(parts)
		return Hash.fnv1a(table.concat(parts, "|"))
	end

	function Civilization:report()
		local laws, wars = 0, 0
		for _, id in ipairs(self.settlementOrder) do
			for _ in pairs(self.settlements[id].laws) do laws = laws + 1 end
		end
		for _, id in ipairs(self.factionOrder) do
			for _ in pairs(self.factions[id].atWarWith) do wars = wars + 1 end
		end
		return { settlements = #self.settlementOrder, factions = #self.factionOrder,
			routes = #self.routes, population = self:totalPopulation(),
			largest = select(1, self:largest()), laws = laws, activeWars = wars / 2,
			warsDeclared = self.wars, treaties = self.treaties, migrations = self.migrations,
			ticks = self.ticks, economy = self.economy.stats(),
			society = self.society.stats(), checksum = self:checksum() }
	end

	return Civilization
end
