-- ARKHER PROCEDURAL WORLD GENERATOR
-- One deterministic pipeline from a seed to a populated, playable world:
--   biomes -> terrain -> erosion -> hydrology -> settlement sites -> cities ->
--   inter-city roads -> vegetation -> props -> living population.
-- Same seed in, byte-identical world out. This is the machine the Singularity AI drives
-- when it is told "create a realistic city" or "build me a continent".
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Terrain = A:import("arkher/terrain/terrain")
	local City = A:import("arkher/procedural/city")
	local Scene = A:import("arkher/world/scene")
	local Vec = A:import("arkher/kernel/vec")
	local Mathx = A:import("arkher/kernel/mathx")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local Hash = A:import("arkher/kernel/hash")
	local C = A:import("arkher/kernel/containers")
	local v3 = Vec.vec3

	local WorldGen = {}
	WorldGen.__index = WorldGen

	function WorldGen.new(opts)
		opts = opts or {}
		local self = setmetatable({}, WorldGen)
		self.seed = opts.seed or 20260907
		self.rng = Random.new(self.seed)
		self.size = opts.size or 2048
		self.terrain = Terrain.new({ seed = self.seed, cellSize = opts.cellSize or 8,
			tileResolution = opts.tileResolution or 17, waterLevel = opts.waterLevel or 0 })
		self.scene = Scene.new({ name = "generated" })
		self.biomes = Kits.wfc({ id = "worldgen.biomes" })
		self.roads = Kits.network({ id = "worldgen.highways" })
		self.vegetation = Kits.scatter({ seed = self.seed + 17, minDistance = opts.treeSpacing or 22 })
		self.simulation = Kits.simulation({ fullRadius = 220, reducedRadius = 900, budget = 128 })
		self.cities = {}
		self.rivers = {}
		self.sites = {}
		self.steps = {}
		self.log = {}
		return self
	end

	function WorldGen:record(step, detail)
		self.steps[#self.steps + 1] = step
		self.log[#self.log + 1] = { step = step, detail = detail }
		return detail
	end

	function WorldGen:bounds()
		return Spatial.aabb(v3(0, 0, 0), v3(self.size, 0, self.size))
	end

	------------------------------------------------------------------ 1. biomes
	function WorldGen:generateBiomes(resolution)
		local res = resolution or 8
		self.biomes.defineTile("ocean", { up = "w", down = "w", left = "w", right = "w" }, 2)
		self.biomes.defineTile("coast", { up = "w", down = "l", left = "c", right = "c" }, 2)
		self.biomes.defineTile("plains", { up = "l", down = "l", left = "l", right = "l" }, 4)
		self.biomes.defineTile("forest", { up = "l", down = "l", left = "l", right = "l" }, 3)
		self.biomes.defineTile("highland", { up = "l", down = "l", left = "l", right = "l" }, 2)
		local grid = self.biomes.solve(res, res, self.seed)
		self.biomeRes = res
		return self:record("biomes", { cells = #grid, histogram = self.biomes.histogram() })
	end

	function WorldGen:biomeAt(wx, wz)
		if not self.biomeRes then return "plains" end
		local cell = self.size / self.biomeRes
		local x = Mathx.clamp(math.floor(wx / cell) + 1, 1, self.biomeRes)
		local z = Mathx.clamp(math.floor(wz / cell) + 1, 1, self.biomeRes)
		return self.biomes.at(x, z) or "plains"
	end

	------------------------------------------------------------------ 2. terrain
	function WorldGen:generateTerrain(opts)
		opts = opts or {}
		local generated = self.terrain:generateRegion(self:bounds(),
			{ frequency = opts.frequency or 0.0016, amplitude = opts.amplitude or 160 })
		local eroded = self.terrain:erode(opts.erosionPasses or 1, { talus = 1.6, rate = 0.5 })
		return self:record("terrain", { tiles = generated, erosionMoves = eroded,
			bounds = self.terrain:report() })
	end

	------------------------------------------------------------------ 3. hydrology
	function WorldGen:generateRivers(count)
		local n = count or 3
		self.rivers = {}
		local carved = 0
		for _ = 1, n do
			local start = v3(self.rng:range(0, self.size), 0, self.rng:range(0, self.size))
			local best = start
			local bestH = self.terrain:heightAt(start.x, start.z) or 0
			-- springs start high: sample a few candidates and keep the highest
			for _ = 1, 6 do
				local candidate = v3(self.rng:range(0, self.size), 0, self.rng:range(0, self.size))
				local h = self.terrain:heightAt(candidate.x, candidate.z) or -1e9
				if h > bestH then best, bestH = candidate, h end
			end
			local path = self.terrain:traceRiver(best, 120)
			if #path > 4 then
				self.rivers[#self.rivers + 1] = path
				carved = carved + self.terrain:carvePath(path, 14, 3)
			end
		end
		return self:record("rivers", { rivers = #self.rivers, carvedCells = carved })
	end

	------------------------------------------------------------------ 4. settlement sites
	function WorldGen:findSettlementSites(count)
		local candidates = {}
		local samples = math.max(24, (count or 3) * 24)
		for _ = 1, samples do
			local p = v3(self.rng:range(0, self.size), 0, self.rng:range(0, self.size))
			local h = self.terrain:heightAt(p.x, p.z)
			if h and h > self.terrain.waterLevel + 2 then
				local slope = self.terrain:slopeAt(p.x, p.z)
				local nearWater = 0
				for _, river in ipairs(self.rivers) do
					for i = 1, #river, 8 do
						if river[i]:distance(p) < 260 then nearWater = 1 break end
					end
					if nearWater == 1 then break end
				end
				local score = (1 - slope) * 3 + nearWater * 1.5 - math.abs(h - 40) / 120
				candidates[#candidates + 1] = { position = v3(p.x, h, p.z), score = score, slope = slope }
			end
		end
		table.sort(candidates, function(a, b) return a.score > b.score end)
		self.sites = {}
		for _, cand in ipairs(candidates) do
			local far = true
			for _, chosen in ipairs(self.sites) do
				if chosen.position:distance(cand.position) < self.size * 0.22 then far = false break end
			end
			if far then
				self.sites[#self.sites + 1] = cand
				if #self.sites >= (count or 3) then break end
			end
		end
		return self:record("sites", { sites = #self.sites })
	end

	------------------------------------------------------------------ 5. cities
	function WorldGen:generateCities(extent)
		self.cities = {}
		local ext = extent or 520
		for i, site in ipairs(self.sites) do
			local city = City.new({ seed = self.seed + i * 7919, blockSize = 110,
				center = site.position })
			local bounds = Spatial.aabb(
				v3(math.max(0, site.position.x - ext / 2), 0, math.max(0, site.position.z - ext / 2)),
				v3(math.min(self.size, site.position.x + ext / 2), 0, math.min(self.size, site.position.z + ext / 2)))
			-- level the ground the city sits on before laying it out
			self.terrain:flatten(site.position, ext * 0.55, 0.8, site.position.y)
			city:generate(bounds, function(x, z) return self.terrain:heightAt(x, z) or site.position.y end)
			for _, road in ipairs(city:roadPolylines()) do
				self.terrain:carvePath({ road.from, road.to }, road.width, 0)
			end
			self.cities[#self.cities + 1] = city
		end
		local buildings, population = 0, 0
		for _, city in ipairs(self.cities) do
			buildings = buildings + #city.buildings
			population = population + city:population()
		end
		return self:record("cities", { cities = #self.cities, buildings = buildings, population = population })
	end

	------------------------------------------------------------------ 6. highways between cities
	function WorldGen:connectCities()
		if #self.cities < 2 then return self:record("highways", { edges = 0 }) end
		local ids = {}
		for i, city in ipairs(self.cities) do
			ids[i] = self.roads.addNode(self.sites[i].position, "city")
		end
		local edges = 0
		for i = 1, #ids do
			for j = i + 1, #ids do
				local a = self.sites[i].position
				local b = self.sites[j].position
				-- terrain-aware cost: climbing is expensive
				local climb = math.abs(a.y - b.y)
				self.roads.addEdge(ids[i], ids[j], { class = "highway", width = 24,
					costFactor = 1 + climb / 100 })
				edges = edges + 1
			end
		end
		local path, cost = nil, 0
		if #ids >= 2 then path, cost = self.roads.route(ids[1], ids[#ids]) end
		for i = 1, #ids - 1 do
			self.terrain:carvePath({ self.sites[i].position, self.sites[i + 1].position }, 22, 1)
		end
		return self:record("highways", { edges = edges, routeLength = cost or 0,
			hops = path and #path or 0 })
	end

	------------------------------------------------------------------ 7. vegetation and props
	function WorldGen:generateVegetation(density)
		self.vegetation.density = density or 1
		self.vegetation.addMask("above-water", function(p)
			local h = self.terrain:heightAt(p.x, p.z)
			return h ~= nil and h > self.terrain.waterLevel + 1
		end)
		self.vegetation.addMask("not-cliff", function(p)
			return self.terrain:slopeAt(p.x, p.z) < 0.45
		end)
		self.vegetation.addMask("outside-cities", function(p)
			for _, site in ipairs(self.sites) do
				if site.position:distance(p) < 300 then return false end
			end
			return true
		end)
		local points = self.vegetation.generate(self:bounds(), 1200)
		local planted = 0
		for i, p in ipairs(points) do
			local biome = self:biomeAt(p.x, p.z)
			local kind = (biome == "forest" and "tree.pine") or (biome == "highland" and "tree.spruce")
				or (biome == "coast" and "tree.palm") or "tree.oak"
			local h = self.terrain:heightAt(p.x, p.z) or 0
			self.scene:spawn("veg." .. i, { position = v3(p.x, h, p.z), tags = { "vegetation", biome },
				radius = 6, props = { kind = kind, scale = 0.8 + (i % 5) * 0.1 } })
			planted = planted + 1
		end
		return self:record("vegetation", { planted = planted, rejected = self.vegetation.stats().rejected })
	end

	------------------------------------------------------------------ 8. population ("Modo Vida Real")
	function WorldGen:populate(perCity)
		local n = perCity or 40
		local spawned = 0
		for ci, city in ipairs(self.cities) do
			local site = self.sites[ci]
			for i = 1, n do
				local angle = self.rng:next() * math.pi * 2
				local radius = self.rng:range(20, 260)
				local p = v3(site.position.x + math.cos(angle) * radius, site.position.y,
					site.position.z + math.sin(angle) * radius)
				self.simulation.spawn(string.format("npc.%d.%d", ci, i), {
					position = p,
					state = { wealth = 10 + self.rng:int(0, 40), mood = 0.5, home = ci },
					update = function(st, dt)
						st.wealth = st.wealth + dt * 0.6
						st.mood = Mathx.clamp(st.mood + (st.wealth > 40 and 0.01 or -0.005) * dt * 10, 0, 1)
					end,
					aggregate = function(st, elapsed)
						st.wealth = st.wealth + elapsed * 0.35
						st.mood = Mathx.clamp(st.mood + elapsed * 0.001, 0, 1)
					end,
				})
				spawned = spawned + 1
			end
		end
		return self:record("population", { agents = spawned })
	end

	------------------------------------------------------------------ pipeline
	function WorldGen:generate(opts)
		opts = opts or {}
		self.rng = Random.new(self.seed)
		self:generateBiomes(opts.biomeResolution or 8)
		self:generateTerrain(opts)
		self:generateRivers(opts.rivers or 3)
		self:findSettlementSites(opts.cities or 2)
		self:generateCities(opts.cityExtent or 480)
		self:connectCities()
		self:generateVegetation(opts.vegetationDensity or 1)
		self:populate(opts.populationPerCity or 30)
		return self:report()
	end

	-- deterministic fingerprint of the produced world
	function WorldGen:checksum()
		local acc = 0
		for _, key in ipairs(self.terrain:tileKeys()) do
			acc = (acc + self.terrain.tiles[key].field.checksum()) % 2147483647
		end
		for _, city in ipairs(self.cities) do
			acc = (acc + #city.buildings * 131 + math.floor(city:population())) % 2147483647
		end
		acc = (acc + #self.rivers * 7717 + C.count(self.scene.objects) * 31) % 2147483647
		return acc
	end

	function WorldGen:report()
		local buildings, population = 0, 0
		for _, city in ipairs(self.cities) do
			buildings = buildings + #city.buildings
			population = population + city:population()
		end
		return {
			seed = self.seed, size = self.size, steps = self.steps,
			terrain = self.terrain:report(), cities = #self.cities, buildings = buildings,
			urbanPopulation = population, rivers = #self.rivers,
			vegetation = C.count(self.scene.objects), agents = self.simulation.stats().entities,
			highways = self.roads.stats(), checksum = self:checksum(),
		}
	end

	-- run the world forward: this is what keeps the world alive when nobody is looking
	function WorldGen:simulate(seconds, observer)
		self.simulation.setObserver(observer or v3())
		local ticks = math.max(1, math.floor(seconds * 30))
		local processed = 0
		for _ = 1, ticks do processed = processed + self.simulation.tick(1 / 30) end
		return { ticks = ticks, processed = processed,
			wealth = self.simulation.aggregateState("wealth"), stats = self.simulation.stats() }
	end

	return WorldGen

end
