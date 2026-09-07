-- ARKHER TERRAIN FRAMEWORK
-- Tiled, editable, streamable terrain: heightfield tiles in world space, sculpt brushes
-- that cross tile borders, material/biome layers, water, erosion, quadtree LOD, mesh
-- extraction and collision sampling. Roblox Terrain is one possible output, never the model.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")
	local Mathx = A:import("arkher/kernel/mathx")
	local Spatial = A:import("arkher/kernel/spatial")
	local C = A:import("arkher/kernel/containers")
	local Ser = A:import("arkher/kernel/serialize")
	local v3 = Vec.vec3

	local Terrain = {}
	Terrain.__index = Terrain

	function Terrain.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Terrain)
		self.tileResolution = opts.tileResolution or 33      -- vertices per tile edge
		self.cellSize = opts.cellSize or 4                   -- studs between vertices
		self.tileSize = (self.tileResolution - 1) * self.cellSize
		self.tiles = {}
		self.materials = opts.materials or { "rock", "soil", "grass", "sand", "snow" }
		self.paint = {}
		self.waterLevel = opts.waterLevel or 0
		self.seed = opts.seed or 20260907
		self.stats = { tiles = 0, sculpts = 0, samples = 0, erosionPasses = 0, meshes = 0 }
		return self
	end

	------------------------------------------------------------------ tiles
	function Terrain:tileKey(wx, wz)
		return math.floor(wx / self.tileSize) .. "," .. math.floor(wz / self.tileSize)
	end

	function Terrain:tileOrigin(key)
		local tx, tz = string.match(key, "(-?%d+),(-?%d+)")
		return tonumber(tx) * self.tileSize, tonumber(tz) * self.tileSize
	end

	function Terrain:tile(key, create)
		local tile = self.tiles[key]
		if tile or not create then return tile end
		tile = { key = key, field = Kits.heightfield({ width = self.tileResolution,
			height = self.tileResolution, cellSize = self.cellSize, id = "terrain." .. key }),
			dirty = true, lod = 0 }
		self.tiles[key] = tile
		self.stats.tiles = self.stats.tiles + 1
		return tile
	end

	function Terrain:tileAt(wx, wz, create) return self:tile(self:tileKey(wx, wz), create) end

	function Terrain:tileKeys()
		local out = {}
		for key in pairs(self.tiles) do out[#out + 1] = key end
		table.sort(out)
		return out
	end

	-- world position -> (tile, local grid coordinate)
	function Terrain:localCoord(wx, wz)
		local key = self:tileKey(wx, wz)
		local ox, oz = self:tileOrigin(key)
		local gx = Mathx.round((wx - ox) / self.cellSize) + 1
		local gz = Mathx.round((wz - oz) / self.cellSize) + 1
		return key, gx, gz
	end

	------------------------------------------------------------------ generation
	function Terrain:generateRegion(bounds, opts)
		opts = opts or {}
		local generated = 0
		local x = bounds.min.x
		while x <= bounds.max.x do
			local z = bounds.min.z
			while z <= bounds.max.z do
				local key = self:tileKey(x, z)
				if not self.tiles[key] then
					local tile = self:tile(key, true)
					local ox, oz = self:tileOrigin(key)
					tile.field.fill(function(gx, gz)
						local worldX = ox + (gx - 1) * self.cellSize
						local worldZ = oz + (gz - 1) * self.cellSize
						return self:proceduralHeight(worldX, worldZ, opts)
					end)
					tile.dirty = true
					generated = generated + 1
				end
				z = z + self.tileSize
			end
			x = x + self.tileSize
		end
		return generated
	end

	function Terrain:proceduralHeight(wx, wz, opts)
		opts = opts or {}
		local Noise = A:import("arkher/kernel/noise")
		local freq = opts.frequency or 0.0025
		local amp = opts.amplitude or 120
		local continent = Noise.fbm(Noise.perlin2D, wx * freq, wz * freq,
			{ octaves = 5, seed = self.seed, gain = 0.5, lacunarity = 2.05 })
		local ridges = Noise.ridged(Noise.perlin2D, wx * freq * 3.1, wz * freq * 3.1,
			{ octaves = 4, seed = self.seed + 77, gain = 0.5 })
		local detail = Noise.perlin2D(wx * freq * 11, wz * freq * 11, self.seed + 991)
		local h = continent * amp + ridges * amp * 0.35 + detail * amp * 0.04
		if opts.terraceSteps then h = Mathx.round(h / opts.terraceSteps) * opts.terraceSteps end
		return h
	end

	------------------------------------------------------------------ sampling
	function Terrain:heightAt(wx, wz)
		self.stats.samples = self.stats.samples + 1
		local tile = self:tileAt(wx, wz, false)
		if not tile then return nil end
		local ox, oz = self:tileOrigin(tile.key)
		return tile.field.sample(wx - ox, wz - oz)
	end

	function Terrain:normalAt(wx, wz)
		local e = self.cellSize
		local h = self:heightAt(wx, wz)
		if not h then return v3(0, 1, 0) end
		local hx = self:heightAt(wx + e, wz) or h
		local hz = self:heightAt(wx, wz + e) or h
		return v3(h - hx, e, h - hz):unit()
	end

	function Terrain:slopeAt(wx, wz)
		local n = self:normalAt(wx, wz)
		return 1 - Mathx.clamp(n.y, 0, 1)
	end

	function Terrain:isUnderwater(wx, wz)
		local h = self:heightAt(wx, wz)
		return h ~= nil and h < self.waterLevel
	end

	function Terrain:project(position)
		local h = self:heightAt(position.x, position.z)
		if not h then return position end
		return v3(position.x, h, position.z)
	end

	------------------------------------------------------------------ sculpting (crosses tiles)
	function Terrain:sculpt(kind, center, radius, strength, target)
		self.stats.sculpts = self.stats.sculpts + 1
		local touched = 0
		local r = radius
		local x = center.x - r
		while x <= center.x + r do
			local z = center.z - r
			while z <= center.z + r do
				local key, gx, gz = self:localCoord(x, z)
				local tile = self:tile(key, true)
				local ox, oz = self:tileOrigin(key)
				local worldX = ox + (gx - 1) * self.cellSize
				local worldZ = oz + (gz - 1) * self.cellSize
				local d = math.sqrt((worldX - center.x) ^ 2 + (worldZ - center.z) ^ 2)
				if d <= r and tile.field.inBounds(gx, gz) then
					local falloff = (1 - Mathx.smoothstep(0, 1, d / math.max(1e-6, r))) * (strength or 1)
					local current = tile.field.get(gx, gz)
					local value = current
					if kind == "raise" then value = current + falloff
					elseif kind == "lower" then value = current - falloff
					elseif kind == "flatten" then value = Mathx.lerp(current, target or center.y, Mathx.saturate(falloff))
					elseif kind == "smooth" then
						local sum, n = 0, 0
						for dz = -1, 1 do
							for dx = -1, 1 do
								if tile.field.inBounds(gx + dx, gz + dz) then
									sum = sum + tile.field.get(gx + dx, gz + dz)
									n = n + 1
								end
							end
						end
						value = Mathx.lerp(current, sum / math.max(1, n), Mathx.saturate(falloff))
					elseif kind == "noise" then
						local Noise = A:import("arkher/kernel/noise")
						value = current + Noise.perlin2D(worldX * 0.05, worldZ * 0.05, self.seed) * falloff
					end
					tile.field.set(gx, gz, value)
					tile.dirty = true
					touched = touched + 1
				end
				z = z + self.cellSize
			end
			x = x + self.cellSize
		end
		return touched
	end

	function Terrain:raise(center, radius, strength) return self:sculpt("raise", center, radius, strength) end
	function Terrain:lower(center, radius, strength) return self:sculpt("lower", center, radius, strength) end
	function Terrain:flatten(center, radius, strength, target) return self:sculpt("flatten", center, radius, strength, target) end
	function Terrain:smooth(center, radius, strength) return self:sculpt("smooth", center, radius, strength) end

	-- carve a flat corridor along a path (roads, rivers, foundations)
	function Terrain:carvePath(points, width, depth)
		local carved = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local steps = math.max(1, math.ceil(a:distance(b) / (self.cellSize * 0.75)))
			for s = 0, steps do
				local p = a:lerp(b, s / steps)
				local h = self:heightAt(p.x, p.z) or p.y
				carved = carved + self:sculpt("flatten", v3(p.x, h - (depth or 0), p.z), width * 0.5, 1, h - (depth or 0))
			end
		end
		return carved
	end

	------------------------------------------------------------------ materials / biomes
	function Terrain:paintMaterial(center, radius, material, weight)
		local n = 0
		local r = radius
		local x = center.x - r
		while x <= center.x + r do
			local z = center.z - r
			while z <= center.z + r do
				local d = math.sqrt((x - center.x) ^ 2 + (z - center.z) ^ 2)
				if d <= r then
					local key = string.format("%d:%d", math.floor(x / self.cellSize), math.floor(z / self.cellSize))
					local cell = self.paint[key] or {}
					cell[material] = Mathx.clamp((cell[material] or 0) + (weight or 1) * (1 - d / r), 0, 1)
					self.paint[key] = cell
					n = n + 1
				end
				z = z + self.cellSize
			end
			x = x + self.cellSize
		end
		return n
	end

	function Terrain:materialAt(wx, wz)
		local key = string.format("%d:%d", math.floor(wx / self.cellSize), math.floor(wz / self.cellSize))
		local cell = self.paint[key]
		if cell then
			local best, bestW = nil, 0
			for material, w in pairs(cell) do
				if w > bestW then best, bestW = material, w end
			end
			if best then return best, bestW end
		end
		-- procedural fallback: height + slope decide the natural material
		local h = self:heightAt(wx, wz)
		if not h then return "rock", 0 end
		local slope = self:slopeAt(wx, wz)
		if h < self.waterLevel then return "sand", 1 end
		if slope > 0.55 then return "rock", slope end
		if h > 220 then return "snow", 1 end
		if h > 80 then return "soil", 1 end
		return "grass", 1
	end

	function Terrain:biomeAt(wx, wz)
		local h = self:heightAt(wx, wz) or 0
		local slope = self:slopeAt(wx, wz)
		if h < self.waterLevel then return "ocean" end
		if h < self.waterLevel + 6 then return "beach" end
		if h > 240 then return "alpine" end
		if slope > 0.5 then return "cliff" end
		if h > 120 then return "highland" end
		return "plains"
	end

	------------------------------------------------------------------ erosion + hydrology
	function Terrain:erode(passes, opts)
		opts = opts or {}
		self.stats.erosionPasses = self.stats.erosionPasses + (passes or 1)
		local moved = 0
		for _ = 1, (passes or 1) do
			for _, key in ipairs(self:tileKeys()) do
				local tile = self.tiles[key]
				moved = moved + tile.field.erodeThermal(1, opts.talus or 1.4, opts.rate or 0.5)
				if opts.hydraulic then moved = moved + tile.field.erodeHydraulic(opts.droplets or 32, self.seed) end
				tile.dirty = true
			end
		end
		return moved
	end

	-- follow steepest descent from a spring until the water level or a local minimum
	function Terrain:traceRiver(start, maxSteps)
		local path = { self:project(start) }
		local p = path[1]
		for _ = 1, (maxSteps or 200) do
			local best, bestH = nil, self:heightAt(p.x, p.z)
			if not bestH then break end
			for angle = 0, 7 do
				local a = angle * math.pi / 4
				local q = v3(p.x + math.cos(a) * self.cellSize, 0, p.z + math.sin(a) * self.cellSize)
				local h = self:heightAt(q.x, q.z)
				if h and h < bestH then
					best, bestH = q, h
				end
			end
			if not best then break end
			p = v3(best.x, bestH, best.z)
			path[#path + 1] = p
			if bestH <= self.waterLevel then break end
		end
		return path
	end

	------------------------------------------------------------------ LOD + mesh
	function Terrain:setLOD(key, lod)
		local tile = self.tiles[key]
		if not tile then return false end
		tile.lod = lod
		return true
	end

	function Terrain:updateLOD(viewer)
		local changed = 0
		for _, key in ipairs(self:tileKeys()) do
			local ox, oz = self:tileOrigin(key)
			local center = v3(ox + self.tileSize / 2, 0, oz + self.tileSize / 2)
			local d = center:distance(v3(viewer.x, 0, viewer.z))
			local lod = 0
			if d > self.tileSize * 6 then lod = 3
			elseif d > self.tileSize * 3 then lod = 2
			elseif d > self.tileSize * 1.5 then lod = 1 end
			if self.tiles[key].lod ~= lod then
				self.tiles[key].lod = lod
				changed = changed + 1
			end
		end
		return changed
	end

	-- build a real triangle mesh for a tile at its current LOD
	function Terrain:buildMesh(key)
		local tile = self.tiles[key]
		if not tile then return nil end
		self.stats.meshes = self.stats.meshes + 1
		local step = 2 ^ tile.lod
		local mesh = Kits.mesh({ id = "terrain.mesh." .. key })
		local ox, oz = self:tileOrigin(key)
		local res = tile.field.width
		local cols = {}
		local rows = 0
		local z = 1
		while z <= res do
			rows = rows + 1
			local count = 0
			local x = 1
			while x <= res do
				count = count + 1
				mesh.addVertex(v3(ox + (x - 1) * self.cellSize, tile.field.get(x, z), oz + (z - 1) * self.cellSize),
					{ (x - 1) / (res - 1), (z - 1) / (res - 1) })
				x = x + step
			end
			cols[rows] = count
			z = z + step
		end
		local perRow = cols[1] or 0
		for r = 1, rows - 1 do
			for c = 1, perRow - 1 do
				local a = (r - 1) * perRow + c
				local b = a + 1
				local cIdx = r * perRow + c
				local d = cIdx + 1
				mesh.addQuad(a, cIdx, d, b)
			end
		end
		mesh.computeNormals()
		tile.dirty = false
		tile.mesh = mesh
		return mesh
	end

	function Terrain:dirtyTiles()
		local out = {}
		for key, tile in pairs(self.tiles) do if tile.dirty then out[#out + 1] = key end end
		table.sort(out)
		return out
	end

	function Terrain:bounds()
		local minv, maxv
		for _, key in ipairs(self:tileKeys()) do
			local ox, oz = self:tileOrigin(key)
			local lo = v3(ox, 0, oz)
			local hi = v3(ox + self.tileSize, 0, oz + self.tileSize)
			minv = minv and minv:min(lo) or lo
			maxv = maxv and maxv:max(hi) or hi
		end
		if not minv then return nil end
		return Spatial.aabb(minv, maxv)
	end

	------------------------------------------------------------------ persistence
	function Terrain:save()
		local payload = { cellSize = self.cellSize, tileResolution = self.tileResolution,
			waterLevel = self.waterLevel, seed = self.seed, tiles = {}, paint = self.paint }
		for key, tile in pairs(self.tiles) do
			payload.tiles[key] = { lod = tile.lod, data = tile.field.data }
		end
		return Ser.encodeBinary(payload)
	end

	function Terrain:load(blob)
		local data = Ser.decodeBinary(blob)
		if not data or not data.tiles then return false end
		self.cellSize = data.cellSize
		self.tileResolution = data.tileResolution
		self.tileSize = (self.tileResolution - 1) * self.cellSize
		self.waterLevel = data.waterLevel
		self.seed = data.seed
		self.paint = data.paint or {}
		self.tiles = {}
		self.stats.tiles = 0
		for key, rec in pairs(data.tiles) do
			local tile = self:tile(key, true)
			for i, v in ipairs(rec.data) do tile.field.data[i] = v end
			tile.lod = rec.lod or 0
			tile.dirty = true
		end
		return true
	end

	function Terrain:report()
		local lo, hi = math.huge, -math.huge
		for _, key in ipairs(self:tileKeys()) do
			local a, b = self.tiles[key].field.range()
			lo = math.min(lo, a)
			hi = math.max(hi, b)
		end
		if lo == math.huge then lo, hi = 0, 0 end
		return { tiles = C.count(self.tiles), tileSize = self.tileSize, cellSize = self.cellSize,
			minHeight = lo, maxHeight = hi, waterLevel = self.waterLevel,
			paintedCells = C.count(self.paint), dirty = #self:dirtyTiles(), stats = self.stats }
	end

	return Terrain

end
