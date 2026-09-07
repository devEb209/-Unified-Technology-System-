-- ARKHER CITY GENERATOR
-- Deterministic urban synthesis: arterial network -> blocks -> lots -> footprints ->
-- massing -> zoning -> parks. Every output is data the rest of ARKHER can consume
-- (network kit for roads, mesh kit for buildings, scatter kit for street furniture).
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")
	local Mathx = A:import("arkher/kernel/mathx")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local C = A:import("arkher/kernel/containers")
	local v3 = Vec.vec3

	local City = {}
	City.__index = City

	function City.new(opts)
		opts = opts or {}
		local self = setmetatable({}, City)
		self.seed = opts.seed or 1234567
		self.rng = Random.new(self.seed)
		self.blockSize = opts.blockSize or 120
		self.roadWidth = opts.roadWidth or 16
		self.jitter = opts.jitter or 0.18
		self.maxFloors = opts.maxFloors or 40
		self.floorHeight = opts.floorHeight or 4
		self.network = Kits.network({ id = "city.roads" })
		self.blocks = {}
		self.lots = {}
		self.buildings = {}
		self.parks = {}
		self.nodes = {}
		self.center = opts.center or v3()
		self.stats = { blocks = 0, lots = 0, buildings = 0, parks = 0, floors = 0 }
		return self
	end

	------------------------------------------------------------------ roads
	function City:generateRoads(bounds)
		self.center = (bounds.min + bounds.max) * 0.5
		local step = self.blockSize
		local cols = math.max(2, math.floor((bounds.max.x - bounds.min.x) / step))
		local rows = math.max(2, math.floor((bounds.max.z - bounds.min.z) / step))
		local grid = {}
		for r = 0, rows do
			grid[r] = {}
			for c = 0, cols do
				local jx = (self.rng:next() - 0.5) * step * self.jitter
				local jz = (self.rng:next() - 0.5) * step * self.jitter
				local edge = (r == 0 or c == 0 or r == rows or c == cols)
				if edge then jx, jz = 0, 0 end
				local p = v3(bounds.min.x + c * step + jx, 0, bounds.min.z + r * step + jz)
				grid[r][c] = self.network.addNode(p, edge and "boundary" or "junction")
				self.nodes[grid[r][c]] = p
			end
		end
		for r = 0, rows do
			for c = 0, cols do
				local isArterial = (r % 3 == 0) or (c % 3 == 0)
				local class = isArterial and "arterial" or "street"
				local width = isArterial and self.roadWidth * 1.75 or self.roadWidth
				if c < cols then self.network.addEdge(grid[r][c], grid[r][c + 1], { class = class, width = width }) end
				if r < rows then self.network.addEdge(grid[r][c], grid[r + 1][c], { class = class, width = width }) end
			end
		end
		self.grid = grid
		self.rows, self.cols = rows, cols
		return self.network.stats()
	end

	function City:roadPolylines()
		local out = {}
		for _, edge in ipairs(self.network.edges) do
			out[#out + 1] = { from = self.network.nodes[edge.a].position,
				to = self.network.nodes[edge.b].position, width = edge.width, class = edge.class }
		end
		return out
	end

	------------------------------------------------------------------ blocks and lots
	function City:generateBlocks()
		if not self.grid then return 0 end
		self.blocks = {}
		for r = 0, self.rows - 1 do
			for c = 0, self.cols - 1 do
				local a = self.nodes[self.grid[r][c]]
				local b = self.nodes[self.grid[r][c + 1]]
				local d = self.nodes[self.grid[r + 1][c]]
				local e = self.nodes[self.grid[r + 1][c + 1]]
				local inset = self.roadWidth * 0.5
				local minx = math.max(a.x, d.x) + inset
				local maxx = math.min(b.x, e.x) - inset
				local minz = math.max(a.z, b.z) + inset
				local maxz = math.min(d.z, e.z) - inset
				if maxx - minx > 12 and maxz - minz > 12 then
					local center = v3((minx + maxx) / 2, 0, (minz + maxz) / 2)
					local distance = center:distance(self.center)
					self.blocks[#self.blocks + 1] = { id = #self.blocks + 1, row = r, col = c,
						bounds = Spatial.aabb(v3(minx, 0, minz), v3(maxx, 0, maxz)),
						center = center, distanceToCenter = distance,
						zone = self:zoneFor(distance) }
				end
			end
		end
		self.stats.blocks = #self.blocks
		return #self.blocks
	end

	function City:zoneFor(distance)
		local extent = math.max(1, self.blockSize * math.max(self.rows or 4, self.cols or 4) * 0.5)
		local t = Mathx.saturate(distance / extent)
		if t < 0.18 then return "downtown" end
		if t < 0.38 then return "commercial" end
		if t < 0.62 then return "mixed" end
		if t < 0.85 then return "residential" end
		return "industrial"
	end

	local LOT_DEPTH = { downtown = 40, commercial = 34, mixed = 28, residential = 24, industrial = 48 }

	function City:generateLots()
		self.lots = {}
		for _, block in ipairs(self.blocks) do
			if self.rng:next() < 0.08 then
				self.parks[#self.parks + 1] = { block = block.id, bounds = block.bounds, kind = "park" }
			else
				local depth = LOT_DEPTH[block.zone] or 28
				local width = block.bounds.max.x - block.bounds.min.x
				local height = block.bounds.max.z - block.bounds.min.z
				local cols = math.max(1, math.floor(width / depth))
				local rows = math.max(1, math.floor(height / depth))
				local lw = width / cols
				local lh = height / rows
				for lr = 0, rows - 1 do
					for lc = 0, cols - 1 do
						local minx = block.bounds.min.x + lc * lw
						local minz = block.bounds.min.z + lr * lh
						self.lots[#self.lots + 1] = { id = #self.lots + 1, block = block.id, zone = block.zone,
							bounds = Spatial.aabb(v3(minx, 0, minz), v3(minx + lw, 0, minz + lh)),
							corner = (lr == 0 or lc == 0 or lr == rows - 1 or lc == cols - 1) }
					end
				end
			end
		end
		self.stats.lots = #self.lots
		self.stats.parks = #self.parks
		return #self.lots
	end

	------------------------------------------------------------------ buildings
	local ZONE_FLOORS = {
		downtown = { 12, 1.0 }, commercial = { 7, 0.7 }, mixed = { 5, 0.5 },
		residential = { 3, 0.3 }, industrial = { 2, 0.2 },
	}

	function City:generateBuildings(heightFn)
		self.buildings = {}
		local totalFloors = 0
		for _, lot in ipairs(self.lots) do
			local margin = 2 + self.rng:next() * 3
			local minx = lot.bounds.min.x + margin
			local minz = lot.bounds.min.z + margin
			local maxx = lot.bounds.max.x - margin
			local maxz = lot.bounds.max.z - margin
			if maxx - minx > 6 and maxz - minz > 6 then
				local zone = ZONE_FLOORS[lot.zone] or ZONE_FLOORS.mixed
				local base = zone[1]
				local variance = zone[2]
				local floors = math.max(1, math.floor(base * (0.55 + self.rng:next() * variance * 2)))
				floors = math.min(floors, self.maxFloors)
				local ground = heightFn and heightFn((minx + maxx) / 2, (minz + maxz) / 2) or 0
				local footprint = {
					v3(minx, ground, minz), v3(maxx, ground, minz),
					v3(maxx, ground, maxz), v3(minx, ground, maxz),
				}
				totalFloors = totalFloors + floors
				self.buildings[#self.buildings + 1] = {
					id = #self.buildings + 1, lot = lot.id, zone = lot.zone,
					footprint = footprint, floors = floors,
					height = floors * self.floorHeight, ground = ground,
					area = (maxx - minx) * (maxz - minz),
					setback = floors > 14 and true or false,
				}
			end
		end
		self.stats.buildings = #self.buildings
		self.stats.floors = totalFloors
		return #self.buildings
	end

	-- turn the footprints into a real triangle mesh (with setbacks for tall towers)
	function City:buildMesh(limit)
		local mesh = Kits.mesh({ id = "city.mesh" })
		local built = 0
		for _, b in ipairs(self.buildings) do
			if limit and built >= limit then break end
			mesh.extrude(b.footprint, b.height)
			if b.setback then
				local inset = 3
				local poly = {}
				local center = v3(0, 0, 0)
				for _, p in ipairs(b.footprint) do center = center + p end
				center = center / #b.footprint
				for _, p in ipairs(b.footprint) do
					local dir = (center - p):unit() * inset
					poly[#poly + 1] = v3(p.x + dir.x, b.ground + b.height, p.z + dir.z)
				end
				mesh.extrude(poly, b.height * 0.35)
			end
			built = built + 1
		end
		mesh.computeNormals()
		return mesh, built
	end

	function City:population()
		local people = 0
		for _, b in ipairs(self.buildings) do
			local density = (b.zone == "residential" and 0.045) or (b.zone == "mixed" and 0.03)
				or (b.zone == "downtown" and 0.02) or 0.01
			people = people + math.floor(b.area * b.floors * density)
		end
		return people
	end

	function City:zoneHistogram()
		local out = {}
		for _, b in ipairs(self.buildings) do out[b.zone] = (out[b.zone] or 0) + 1 end
		return out
	end

	function City:tallest()
		local best = nil
		for _, b in ipairs(self.buildings) do
			if not best or b.height > best.height then best = b end
		end
		return best
	end

	function City:generate(bounds, heightFn)
		self:generateRoads(bounds)
		self:generateBlocks()
		self:generateLots()
		self:generateBuildings(heightFn)
		return self:report()
	end

	function City:report()
		return { seed = self.seed, roads = self.network.stats(), blocks = #self.blocks,
			lots = #self.lots, buildings = #self.buildings, parks = #self.parks,
			floors = self.stats.floors, population = self:population(),
			zones = self:zoneHistogram(), roadLength = self.network.totalLength() }
	end

	return City

end
