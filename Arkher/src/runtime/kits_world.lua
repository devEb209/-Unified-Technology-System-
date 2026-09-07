-- ARKHER RUNTIME :: World / Terrain / Procedural Kits
-- Round 3 machinery (kits 32-43). Same contract as runtime/kits.lua and kits_studio.lua:
-- every kit here is a complete working implementation that catalog systems specialize.
-- Nothing in this file is Roblox specific and nothing here is a stub.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Noise = A:import("arkher/kernel/noise")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3

	------------------------------------------------------------------ 32. SCENEGRAPH
	-- Hierarchical scene with lazy world transforms, dirty propagation and queries.
	function K.scenegraph(cfg)
		local self = { kind = "scenegraph", nodes = {}, roots = {}, dirty = {}, order = {},
			id = cfg.id, resolves = 0, moves = 0, onChange = Signal.new("scene.change") }

		function self.addNode(id, opts, parent)
			opts = opts or {}
			if self.nodes[id] then return nil, "duplicate node" end
			local node = { id = id, parent = nil, children = {},
				position = opts.position or v3(), rotation = opts.rotation or v3(),
				scale = opts.scale or v3(1, 1, 1), tags = opts.tags or {},
				visible = opts.visible ~= false, static = opts.static or false,
				radius = opts.radius or 1, world = nil }
			self.nodes[id] = node
			self.order[#self.order + 1] = id
			if parent and self.nodes[parent] then
				node.parent = parent
				table.insert(self.nodes[parent].children, id)
			else
				self.roots[#self.roots + 1] = id
			end
			self.dirty[id] = true
			return node
		end

		function self.get(id) return self.nodes[id] end

		function self.setParent(id, parent)
			local node = self.nodes[id]
			if not node or id == parent then return false end
			-- reject cycles
			local walker = parent
			while walker do
				if walker == id then return false, "cycle" end
				walker = self.nodes[walker] and self.nodes[walker].parent
			end
			local old = node.parent and self.nodes[node.parent]
			if old then
				for i, c in ipairs(old.children) do if c == id then table.remove(old.children, i) break end end
			else
				for i, r in ipairs(self.roots) do if r == id then table.remove(self.roots, i) break end end
			end
			node.parent = parent
			if parent and self.nodes[parent] then table.insert(self.nodes[parent].children, id)
			else self.roots[#self.roots + 1] = id end
			self.markDirty(id)
			return true
		end

		function self.markDirty(id)
			local node = self.nodes[id]
			if not node then return false end
			self.dirty[id] = true
			for _, child in ipairs(node.children) do self.markDirty(child) end
			return true
		end

		function self.setPosition(id, position)
			local node = self.nodes[id]
			if not node then return false end
			node.position = position
			self.moves = self.moves + 1
			self.markDirty(id)
			self.onChange:fire(id, "position")
			return true
		end

		function self.setScale(id, scale)
			local node = self.nodes[id]
			if not node then return false end
			node.scale = scale
			self.markDirty(id)
			return true
		end

		function self.worldPosition(id)
			local node = self.nodes[id]
			if not node then return nil end
			if not self.dirty[id] and node.world then return node.world end
			self.resolves = self.resolves + 1
			local p = node.position
			if node.parent then
				local parentWorld = self.worldPosition(node.parent)
				local ps = self.nodes[node.parent].scale
				p = parentWorld + v3(p.x * ps.x, p.y * ps.y, p.z * ps.z)
			end
			node.world = p
			self.dirty[id] = nil
			return p
		end

		function self.worldScale(id)
			local node = self.nodes[id]
			if not node then return nil end
			local s = node.scale
			local parent = node.parent
			while parent do
				local ps = self.nodes[parent].scale
				s = v3(s.x * ps.x, s.y * ps.y, s.z * ps.z)
				parent = self.nodes[parent].parent
			end
			return s
		end

		function self.traverse(fn, rootId)
			local visited = 0
			local function walk(id, depth)
				local node = self.nodes[id]
				if not node then return end
				visited = visited + 1
				fn(node, depth)
				for _, child in ipairs(node.children) do walk(child, depth + 1) end
			end
			if rootId then walk(rootId, 0) else
				for _, r in ipairs(self.roots) do walk(r, 0) end
			end
			return visited
		end

		function self.descendants(id)
			local out = {}
			self.traverse(function(node) if node.id ~= id then out[#out + 1] = node.id end end, id)
			return out
		end

		function self.withTag(tag)
			local out = {}
			for _, id in ipairs(self.order) do
				local node = self.nodes[id]
				if node then
					for _, t in ipairs(node.tags) do
						if t == tag then out[#out + 1] = id break end
					end
				end
			end
			return out
		end

		function self.remove(id)
			local node = self.nodes[id]
			if not node then return 0 end
			local removed = 0
			for _, child in ipairs({ table.unpack(node.children) }) do removed = removed + self.remove(child) end
			if node.parent and self.nodes[node.parent] then
				local siblings = self.nodes[node.parent].children
				for i, c in ipairs(siblings) do if c == id then table.remove(siblings, i) break end end
			else
				for i, r in ipairs(self.roots) do if r == id then table.remove(self.roots, i) break end end
			end
			for i, o in ipairs(self.order) do if o == id then table.remove(self.order, i) break end end
			self.nodes[id] = nil
			self.dirty[id] = nil
			return removed + 1
		end

		function self.bounds()
			local minv, maxv = nil, nil
			for _, id in ipairs(self.order) do
				local p = self.worldPosition(id)
				local r = self.nodes[id].radius
				local lo, hi = p - v3(r, r, r), p + v3(r, r, r)
				minv = minv and minv:min(lo) or lo
				maxv = maxv and maxv:max(hi) or hi
			end
			if not minv then return nil end
			return Spatial.aabb(minv, maxv)
		end

		function self.visibleFrom(origin, radius)
			local out = {}
			local r2 = radius * radius
			for _, id in ipairs(self.order) do
				local node = self.nodes[id]
				if node.visible and self.worldPosition(id):distanceSq(origin) <= r2 then out[#out + 1] = id end
			end
			return out
		end

		function self.depthOf(id)
			local d, walker = 0, self.nodes[id]
			while walker and walker.parent do
				d = d + 1
				walker = self.nodes[walker.parent]
			end
			return d
		end

		function self.stats() return { nodes = #self.order, roots = #self.roots,
			dirty = C.count(self.dirty), resolves = self.resolves, moves = self.moves } end
		return self
	end

	------------------------------------------------------------------ 33. PREFAB
	-- Template + instance system with per-instance overrides and template propagation.
	function K.prefab(cfg)
		local self = { kind = "prefab", templates = {}, instances = {}, nextId = 1,
			id = cfg.id, spawns = 0, propagations = 0 }

		function self.define(name, spec)
			self.templates[name] = { name = name, props = spec.props or {},
				children = spec.children or {}, tags = spec.tags or {}, version = 1 }
			return self.templates[name]
		end

		function self.instantiate(name, overrides)
			local tpl = self.templates[name]
			if not tpl then return nil, "unknown template: " .. tostring(name) end
			local id = self.nextId
			self.nextId = id + 1
			local props = C.deepCopy(tpl.props)
			local ov = {}
			for k, v in pairs(overrides or {}) do
				props[k] = v
				ov[k] = true
			end
			self.instances[id] = { id = id, template = name, props = props, overrides = ov,
				version = tpl.version, children = C.deepCopy(tpl.children) }
			self.spawns = self.spawns + 1
			return id
		end

		function self.override(instanceId, key, value)
			local inst = self.instances[instanceId]
			if not inst then return false end
			inst.props[key] = value
			inst.overrides[key] = true
			return true
		end

		function self.revert(instanceId, key)
			local inst = self.instances[instanceId]
			if not inst then return false end
			local tpl = self.templates[inst.template]
			inst.props[key] = tpl and C.deepCopy(tpl.props[key]) or nil
			inst.overrides[key] = nil
			return true
		end

		-- edit the template and push the change into every instance that has not overridden it
		function self.editTemplate(name, key, value)
			local tpl = self.templates[name]
			if not tpl then return 0 end
			tpl.props[key] = value
			tpl.version = tpl.version + 1
			local touched = 0
			for _, inst in pairs(self.instances) do
				if inst.template == name and not inst.overrides[key] then
					inst.props[key] = value
					inst.version = tpl.version
					touched = touched + 1
				end
			end
			self.propagations = self.propagations + 1
			return touched
		end

		function self.instancesOf(name)
			local out = {}
			for id, inst in pairs(self.instances) do if inst.template == name then out[#out + 1] = id end end
			table.sort(out)
			return out
		end

		function self.diff(instanceId)
			local inst = self.instances[instanceId]
			if not inst then return nil end
			local out = {}
			for key in pairs(inst.overrides) do out[key] = inst.props[key] end
			return out
		end

		function self.destroy(instanceId)
			if not self.instances[instanceId] then return false end
			self.instances[instanceId] = nil
			return true
		end

		function self.stats() return { templates = C.count(self.templates), instances = C.count(self.instances),
			spawns = self.spawns, propagations = self.propagations } end
		return self
	end

	------------------------------------------------------------------ 34. HEIGHTFIELD
	-- The ARKHER Terrain Framework core: a real editable heightfield with sculpt ops,
	-- erosion, bilinear sampling, normals, slope and LOD downsampling.
	function K.heightfield(cfg)
		local w = cfg.width or 64
		local h = cfg.height or 64
		local self = { kind = "heightfield", width = w, height = h, cellSize = cfg.cellSize or 4,
			data = {}, id = cfg.id, edits = 0, samples = 0, minHeight = 0, maxHeight = 0 }
		for i = 1, w * h do self.data[i] = 0 end

		local function index(x, y) return (y - 1) * self.width + x end
		self.index = index

		function self.inBounds(x, y) return x >= 1 and y >= 1 and x <= self.width and y <= self.height end
		function self.get(x, y)
			if not self.inBounds(x, y) then return 0 end
			return self.data[index(x, y)]
		end
		function self.set(x, y, value)
			if not self.inBounds(x, y) then return false end
			self.data[index(x, y)] = value
			self.edits = self.edits + 1
			if value < self.minHeight then self.minHeight = value end
			if value > self.maxHeight then self.maxHeight = value end
			return true
		end

		function self.fill(fn)
			for y = 1, self.height do
				for x = 1, self.width do self.set(x, y, fn(x, y)) end
			end
			return self
		end

		function self.applyNoise(opts)
			opts = opts or {}
			local field = Noise.field(opts.kind or "perlin")
			local freq = opts.frequency or 0.05
			local amp = opts.amplitude or 40
			local seed = opts.seed or 1337
			local octaves = opts.octaves or 4
			return self.fill(function(x, y)
				local n = Noise.fbm(field, x * freq, y * freq, { octaves = octaves, seed = seed,
					gain = opts.gain or 0.5, lacunarity = opts.lacunarity or 2 })
				return n * amp
			end)
		end

		-- bilinear sample in world units
		function self.sample(wx, wz)
			self.samples = self.samples + 1
			local fx = wx / self.cellSize + 1
			local fy = wz / self.cellSize + 1
			local x0 = math.floor(fx)
			local y0 = math.floor(fy)
			local tx = fx - x0
			local ty = fy - y0
			local h00 = self.get(x0, y0)
			local h10 = self.get(x0 + 1, y0)
			local h01 = self.get(x0, y0 + 1)
			local h11 = self.get(x0 + 1, y0 + 1)
			return Mathx.lerp(Mathx.lerp(h00, h10, tx), Mathx.lerp(h01, h11, tx), ty)
		end

		function self.normalAt(x, y)
			local l = self.get(x - 1, y)
			local r = self.get(x + 1, y)
			local d = self.get(x, y - 1)
			local u = self.get(x, y + 1)
			return v3(l - r, 2 * self.cellSize, d - u):unit()
		end

		function self.slopeAt(x, y)
			local n = self.normalAt(x, y)
			return 1 - Mathx.clamp(n.y, 0, 1)
		end

		-- brush ops -----------------------------------------------------
		local function brush(self_, cx, cy, radius, strength, fn)
			local touched = 0
			local r = math.ceil(radius)
			for y = cy - r, cy + r do
				for x = cx - r, cx + r do
					if self_.inBounds(x, y) then
						local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
						if d <= radius then
							local falloff = 1 - Mathx.smoothstep(0, 1, d / math.max(1e-6, radius))
							self_.set(x, y, fn(self_.get(x, y), falloff * strength, x, y))
							touched = touched + 1
						end
					end
				end
			end
			return touched
		end

		function self.raise(cx, cy, radius, strength)
			return brush(self, cx, cy, radius, strength or 1, function(v, s) return v + s end)
		end
		function self.lower(cx, cy, radius, strength)
			return brush(self, cx, cy, radius, strength or 1, function(v, s) return v - s end)
		end
		function self.flatten(cx, cy, radius, target, strength)
			local t = target or self.get(cx, cy)
			return brush(self, cx, cy, radius, strength or 1, function(v, s) return Mathx.lerp(v, t, Mathx.saturate(s)) end)
		end
		function self.smooth(cx, cy, radius, strength)
			local snapshot = {}
			for i = 1, #self.data do snapshot[i] = self.data[i] end
			return brush(self, cx, cy, radius, strength or 1, function(v, s, x, y)
				local sum, n = 0, 0
				for dy = -1, 1 do
					for dx = -1, 1 do
						if self.inBounds(x + dx, y + dy) then
							sum = sum + snapshot[index(x + dx, y + dy)]
							n = n + 1
						end
					end
				end
				return Mathx.lerp(v, sum / math.max(1, n), Mathx.saturate(s))
			end)
		end
		function self.terrace(steps)
			local s = steps or 6
			return self.fill(function(x, y)
				local v = self.get(x, y)
				return Mathx.round(v / math.max(1e-6, s)) * s
			end)
		end

		-- thermal erosion: material above the talus angle slides downhill
		function self.erodeThermal(iterations, talus, rate)
			local iters = iterations or 4
			local t = talus or 1.2
			local r = rate or 0.5
			local moved = 0
			for _ = 1, iters do
				for y = 1, self.height do
					for x = 1, self.width do
						local hcur = self.get(x, y)
						local lowestX, lowestY, lowest = nil, nil, hcur
						for dy = -1, 1 do
							for dx = -1, 1 do
								if dx ~= 0 or dy ~= 0 then
									if self.inBounds(x + dx, y + dy) then
										local hn = self.get(x + dx, y + dy)
										if hn < lowest then lowest, lowestX, lowestY = hn, x + dx, y + dy end
									end
								end
							end
						end
						if lowestX and (hcur - lowest) > t then
							local delta = (hcur - lowest) * r * 0.5
							self.set(x, y, hcur - delta)
							self.set(lowestX, lowestY, lowest + delta)
							moved = moved + 1
						end
					end
				end
			end
			return moved
		end

		-- hydraulic erosion: droplets carve channels and deposit sediment
		function self.erodeHydraulic(droplets, seed)
			local rng = Random.new(seed or 4242)
			local carved = 0
			for _ = 1, (droplets or 64) do
				local x = rng:int(2, math.max(2, self.width - 1))
				local y = rng:int(2, math.max(2, self.height - 1))
				local sediment = 0
				for _ = 1, 24 do
					local hcur = self.get(x, y)
					local bestX, bestY, bestH = x, y, hcur
					for dy = -1, 1 do
						for dx = -1, 1 do
							local nx, ny = x + dx, y + dy
							if self.inBounds(nx, ny) and self.get(nx, ny) < bestH then
								bestX, bestY, bestH = nx, ny, self.get(nx, ny)
							end
						end
					end
					if bestX == x and bestY == y then
						self.set(x, y, hcur + sediment)
						break
					end
					local drop = math.min(0.4, (hcur - bestH) * 0.35)
					self.set(x, y, hcur - drop)
					sediment = sediment + drop * 0.8
					carved = carved + 1
					x, y = bestX, bestY
				end
			end
			return carved
		end

		function self.range()
			local lo, hi = math.huge, -math.huge
			for i = 1, #self.data do
				local v = self.data[i]
				if v < lo then lo = v end
				if v > hi then hi = v end
			end
			if lo == math.huge then return 0, 0 end
			return lo, hi
		end

		function self.normalize(lo, hi)
			local curLo, curHi = self.range()
			local span = math.max(1e-6, curHi - curLo)
			local targetLo, targetHi = lo or 0, hi or 1
			return self.fill(function(x, y)
				return targetLo + ((self.get(x, y) - curLo) / span) * (targetHi - targetLo)
			end)
		end

		-- half-resolution LOD copy
		function self.downsample()
			local lod = K.heightfield({ width = math.max(1, math.floor(self.width / 2)),
				height = math.max(1, math.floor(self.height / 2)), cellSize = self.cellSize * 2 })
			lod.fill(function(x, y)
				local sx, sy = x * 2 - 1, y * 2 - 1
				return (self.get(sx, sy) + self.get(sx + 1, sy) + self.get(sx, sy + 1) + self.get(sx + 1, sy + 1)) / 4
			end)
			return lod
		end

		function self.checksum()
			local acc = 0
			for i = 1, #self.data do acc = (acc + math.floor(self.data[i] * 1000)) % 2147483647 end
			return acc
		end

		function self.stats()
			local lo, hi = self.range()
			return { width = self.width, height = self.height, cells = self.width * self.height,
				cellSize = self.cellSize, min = lo, max = hi, edits = self.edits, samples = self.samples }
		end
		return self
	end

	------------------------------------------------------------------ 35. VOXEL
	function K.voxel(cfg)
		local self = { kind = "voxel", cells = {}, count = 0, id = cfg.id,
			materials = cfg.materials or { "rock", "soil", "sand", "snow" }, writes = 0 }

		local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
		self.key = key

		function self.set(x, y, z, material)
			local k = key(x, y, z)
			if material == nil then
				if self.cells[k] then self.count = self.count - 1 end
				self.cells[k] = nil
			else
				if not self.cells[k] then self.count = self.count + 1 end
				self.cells[k] = material
			end
			self.writes = self.writes + 1
			return true
		end
		function self.get(x, y, z) return self.cells[key(x, y, z)] end
		function self.has(x, y, z) return self.cells[key(x, y, z)] ~= nil end

		function self.fillBox(x0, y0, z0, x1, y1, z1, material)
			local n = 0
			for z = z0, z1 do
				for y = y0, y1 do
					for x = x0, x1 do
						self.set(x, y, z, material)
						n = n + 1
					end
				end
			end
			return n
		end

		function self.fillSphere(cx, cy, cz, radius, material)
			local n = 0
			local r = math.ceil(radius)
			for z = cz - r, cz + r do
				for y = cy - r, cy + r do
					for x = cx - r, cx + r do
						if (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2 <= radius * radius then
							self.set(x, y, z, material)
							n = n + 1
						end
					end
				end
			end
			return n
		end

		function self.carveSphere(cx, cy, cz, radius)
			local n = 0
			local r = math.ceil(radius)
			for z = cz - r, cz + r do
				for y = cy - r, cy + r do
					for x = cx - r, cx + r do
						if self.has(x, y, z) and (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2 <= radius * radius then
							self.set(x, y, z, nil)
							n = n + 1
						end
					end
				end
			end
			return n
		end

		function self.neighbors(x, y, z)
			local out = {}
			local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
			for _, d in ipairs(dirs) do
				local m = self.get(x + d[1], y + d[2], z + d[3])
				if m then out[#out + 1] = { x = x + d[1], y = y + d[2], z = z + d[3], material = m } end
			end
			return out
		end

		-- only faces without a solid neighbour are ever emitted (real face culling)
		function self.surfaceFaces()
			local faces = 0
			for k in pairs(self.cells) do
				local x, y, z = string.match(k, "(-?%d+):(-?%d+):(-?%d+)")
				x, y, z = tonumber(x), tonumber(y), tonumber(z)
				faces = faces + (6 - #self.neighbors(x, y, z))
			end
			return faces
		end

		function self.floodFill(x, y, z, material)
			local start = self.get(x, y, z)
			if start == nil or start == material then return 0 end
			local stack = { { x, y, z } }
			local n = 0
			while #stack > 0 do
				local cell = table.remove(stack)
				local cx, cy, cz = cell[1], cell[2], cell[3]
				if self.get(cx, cy, cz) == start then
					self.set(cx, cy, cz, material)
					n = n + 1
					local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
					for _, d in ipairs(dirs) do stack[#stack + 1] = { cx + d[1], cy + d[2], cz + d[3] } end
				end
			end
			return n
		end

		function self.bounds()
			local minv, maxv
			for k in pairs(self.cells) do
				local x, y, z = string.match(k, "(-?%d+):(-?%d+):(-?%d+)")
				local p = v3(tonumber(x), tonumber(y), tonumber(z))
				minv = minv and minv:min(p) or p
				maxv = maxv and maxv:max(p) or p
			end
			if not minv then return nil end
			return Spatial.aabb(minv, maxv)
		end

		function self.histogram()
			local out = {}
			for _, m in pairs(self.cells) do out[m] = (out[m] or 0) + 1 end
			return out
		end

		function self.stats() return { voxels = self.count, writes = self.writes,
			materials = #self.materials } end
		return self
	end

	------------------------------------------------------------------ 36. SPLINE
	function K.spline(cfg)
		local self = { kind = "spline", points = cfg.points or {}, closed = cfg.closed or false,
			tension = cfg.tension or 0.5, id = cfg.id, lut = nil, evaluations = 0 }

		function self.addPoint(p)
			self.points[#self.points + 1] = p
			self.lut = nil
			return #self.points
		end
		function self.setPoint(i, p)
			if not self.points[i] then return false end
			self.points[i] = p
			self.lut = nil
			return true
		end
		function self.count() return #self.points end

		local function catmull(p0, p1, p2, p3, t, tension)
			local t2 = t * t
			local t3 = t2 * t
			local a = p1 * 2
			local b = (p2 - p0) * tension
			local c = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * tension
			local d = (p1 * 3 - p0 - p2 * 3 + p3) * tension
			return (a + b * t + c * t2 + d * t3) * 0.5
		end

		function self.evaluate(t)
			local n = #self.points
			if n == 0 then return v3() end
			if n == 1 then return self.points[1] end
			self.evaluations = self.evaluations + 1
			t = Mathx.saturate(t)
			local segments = self.closed and n or (n - 1)
			local ft = t * segments
			local i = math.min(segments - 1, math.floor(ft))
			local localT = ft - i
			local function at(k)
				if self.closed then return self.points[(k % n) + 1] end
				return self.points[Mathx.clamp(k + 1, 1, n)]
			end
			return catmull(at(i - 1), at(i), at(i + 1), at(i + 2), localT, self.tension * 2)
		end

		function self.tangent(t)
			local e = 1e-3
			local a = self.evaluate(math.max(0, t - e))
			local b = self.evaluate(math.min(1, t + e))
			return (b - a):unit()
		end

		function self.buildLUT(samples)
			local n = samples or 64
			local lut = { { t = 0, distance = 0, point = self.evaluate(0) } }
			local total = 0
			for i = 1, n do
				local t = i / n
				local p = self.evaluate(t)
				total = total + p:distance(lut[#lut].point)
				lut[#lut + 1] = { t = t, distance = total, point = p }
			end
			self.lut = lut
			self.length = total
			return total
		end

		function self.arcLength()
			if not self.lut then self.buildLUT(64) end
			return self.length
		end

		function self.pointAtDistance(distance)
			if not self.lut then self.buildLUT(64) end
			if distance <= 0 then return self.lut[1].point end
			if distance >= self.length then return self.lut[#self.lut].point end
			for i = 2, #self.lut do
				if self.lut[i].distance >= distance then
					local prev = self.lut[i - 1]
					local span = math.max(1e-9, self.lut[i].distance - prev.distance)
					local k = (distance - prev.distance) / span
					return prev.point:lerp(self.lut[i].point, k)
				end
			end
			return self.lut[#self.lut].point
		end

		function self.resample(count)
			local out = {}
			local total = self.arcLength()
			local n = math.max(2, count or 16)
			for i = 0, n - 1 do out[#out + 1] = self.pointAtDistance(total * i / (n - 1)) end
			return out
		end

		function self.offset(distance, samples)
			local out = {}
			local n = samples or 16
			for i = 0, n do
				local t = i / n
				local p = self.evaluate(t)
				local dir = self.tangent(t)
				local side = v3(-dir.z, 0, dir.x):unit()
				out[#out + 1] = p + side * distance
			end
			return out
		end

		function self.closestPoint(target, samples)
			local best, bestT, bestD = nil, 0, math.huge
			local n = samples or 32
			for i = 0, n do
				local t = i / n
				local p = self.evaluate(t)
				local d = p:distanceSq(target)
				if d < bestD then best, bestT, bestD = p, t, d end
			end
			return best, bestT, math.sqrt(bestD)
		end

		function self.stats() return { points = #self.points, closed = self.closed,
			length = self.lut and self.length or 0, evaluations = self.evaluations } end
		return self
	end

	------------------------------------------------------------------ 37. MESH
	function K.mesh(cfg)
		local self = { kind = "mesh", vertices = {}, triangles = {}, normals = {}, uvs = {},
			id = cfg.id, welds = 0, generated = 0 }

		function self.addVertex(p, uv)
			self.vertices[#self.vertices + 1] = p
			self.uvs[#self.vertices] = uv or { 0, 0 }
			return #self.vertices
		end
		function self.addTriangle(a, b, c)
			self.triangles[#self.triangles + 1] = { a, b, c }
			return #self.triangles
		end
		function self.addQuad(a, b, c, d)
			self.addTriangle(a, b, c)
			return self.addTriangle(a, c, d)
		end

		function self.box(center, size)
			local hx, hy, hz = size.x / 2, size.y / 2, size.z / 2
			local base = #self.vertices
			local corners = {
				v3(-hx, -hy, -hz), v3(hx, -hy, -hz), v3(hx, -hy, hz), v3(-hx, -hy, hz),
				v3(-hx, hy, -hz), v3(hx, hy, -hz), v3(hx, hy, hz), v3(-hx, hy, hz) }
			for _, c in ipairs(corners) do self.addVertex(center + c) end
			local quads = { { 1, 2, 3, 4 }, { 5, 8, 7, 6 }, { 1, 5, 6, 2 }, { 2, 6, 7, 3 },
				{ 3, 7, 8, 4 }, { 4, 8, 5, 1 } }
			for _, q in ipairs(quads) do self.addQuad(base + q[1], base + q[2], base + q[3], base + q[4]) end
			self.generated = self.generated + 1
			return self
		end

		-- extrude a closed polygon (list of Vec3 on a plane) upwards: real wall + cap generation
		function self.extrude(polygon, height)
			local base = #self.vertices
			local n = #polygon
			if n < 3 then return 0 end
			for _, p in ipairs(polygon) do self.addVertex(p) end
			for _, p in ipairs(polygon) do self.addVertex(p + v3(0, height, 0)) end
			for i = 1, n do
				local j = (i % n) + 1
				self.addQuad(base + i, base + j, base + n + j, base + n + i)
			end
			for i = 2, n - 1 do self.addTriangle(base + n + 1, base + n + i, base + n + i + 1) end
			self.generated = self.generated + 1
			return n
		end

		function self.revolve(profile, segments)
			local segs = segments or 12
			local base = #self.vertices
			for s = 0, segs - 1 do
				local angle = (s / segs) * math.pi * 2
				local cosA, sinA = math.cos(angle), math.sin(angle)
				for _, p in ipairs(profile) do
					self.addVertex(v3(p.x * cosA, p.y, p.x * sinA))
				end
			end
			local rows = #profile
			for s = 0, segs - 1 do
				local sNext = (s + 1) % segs
				for r = 1, rows - 1 do
					local a = base + s * rows + r
					local b = base + sNext * rows + r
					self.addQuad(a, b, b + 1, a + 1)
				end
			end
			self.generated = self.generated + 1
			return segs * rows
		end

		function self.computeNormals()
			self.normals = {}
			for i = 1, #self.vertices do self.normals[i] = v3() end
			for _, tri in ipairs(self.triangles) do
				local a, b, c = self.vertices[tri[1]], self.vertices[tri[2]], self.vertices[tri[3]]
				if a and b and c then
					local n = (b - a):cross(c - a)
					for _, idx in ipairs(tri) do self.normals[idx] = self.normals[idx] + n end
				end
			end
			for i = 1, #self.normals do self.normals[i] = self.normals[i]:unit() end
			return #self.normals
		end

		function self.weld(epsilon)
			local eps = epsilon or 1e-4
			local map = {}
			local unique = {}
			local remap = {}
			for i, p in ipairs(self.vertices) do
				local k = string.format("%.4f|%.4f|%.4f", p.x / eps, p.y / eps, p.z / eps)
				if map[k] then
					remap[i] = map[k]
				else
					unique[#unique + 1] = p
					map[k] = #unique
					remap[i] = #unique
				end
			end
			local welded = #self.vertices - #unique
			self.vertices = unique
			for _, tri in ipairs(self.triangles) do
				tri[1], tri[2], tri[3] = remap[tri[1]], remap[tri[2]], remap[tri[3]]
			end
			self.welds = self.welds + welded
			return welded
		end

		function self.area()
			local total = 0
			for _, tri in ipairs(self.triangles) do
				local a, b, c = self.vertices[tri[1]], self.vertices[tri[2]], self.vertices[tri[3]]
				if a and b and c then total = total + (b - a):cross(c - a):length() * 0.5 end
			end
			return total
		end

		function self.bounds()
			local minv, maxv
			for _, p in ipairs(self.vertices) do
				minv = minv and minv:min(p) or p
				maxv = maxv and maxv:max(p) or p
			end
			if not minv then return nil end
			return Spatial.aabb(minv, maxv)
		end

		-- drop degenerate/tiny triangles: a real (if simple) decimation pass
		function self.simplify(minArea)
			local limit = minArea or 1e-3
			local kept = {}
			local dropped = 0
			for _, tri in ipairs(self.triangles) do
				local a, b, c = self.vertices[tri[1]], self.vertices[tri[2]], self.vertices[tri[3]]
				local area = (a and b and c) and (b - a):cross(c - a):length() * 0.5 or 0
				if area >= limit then kept[#kept + 1] = tri else dropped = dropped + 1 end
			end
			self.triangles = kept
			return dropped
		end

		function self.stats() return { vertices = #self.vertices, triangles = #self.triangles,
			normals = #self.normals, welds = self.welds, generated = self.generated } end
		return self
	end

	------------------------------------------------------------------ 38. CHUNKER
	function K.chunker(cfg)
		local self = { kind = "chunker", size = cfg.size or 128, states = {}, loaded = 0,
			id = cfg.id, radius = cfg.radius or 512, maxPerTick = cfg.maxPerTick or 4,
			queue = {}, loads = 0, unloads = 0 }

		function self.keyOf(x, z)
			return math.floor(x / self.size) .. "," .. math.floor(z / self.size)
		end
		function self.coordOf(key)
			local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
			return tonumber(cx), tonumber(cz)
		end
		function self.center(key)
			local cx, cz = self.coordOf(key)
			return v3((cx + 0.5) * self.size, 0, (cz + 0.5) * self.size)
		end
		function self.bounds(key)
			local cx, cz = self.coordOf(key)
			return Spatial.aabb(v3(cx * self.size, -1024, cz * self.size),
				v3((cx + 1) * self.size, 1024, (cz + 1) * self.size))
		end
		function self.neighbors(key, ring)
			local cx, cz = self.coordOf(key)
			local r = ring or 1
			local out = {}
			for dz = -r, r do
				for dx = -r, r do
					if dx ~= 0 or dz ~= 0 then out[#out + 1] = (cx + dx) .. "," .. (cz + dz) end
				end
			end
			return out
		end

		function self.state(key) return self.states[key] or "unloaded" end
		function self.setState(key, state)
			local prev = self.state(key)
			if prev == state then return false end
			if state == "loaded" then self.loaded = self.loaded + 1 self.loads = self.loads + 1
			elseif prev == "loaded" then self.loaded = self.loaded - 1 self.unloads = self.unloads + 1 end
			self.states[key] = state
			return true
		end

		-- decide what to stream from a viewer position (+ velocity prefetch)
		function self.update(position, velocity)
			local ahead = velocity and (position + velocity * 1.5) or position
			local reach = math.ceil(self.radius / self.size)
			local wanted = {}
			local toLoad = {}
			local cx = math.floor(ahead.x / self.size)
			local cz = math.floor(ahead.z / self.size)
			for dz = -reach, reach do
				for dx = -reach, reach do
					local key = (cx + dx) .. "," .. (cz + dz)
					local dist = self.center(key):distance(position)
					if dist <= self.radius then
						wanted[key] = dist
						if self.state(key) == "unloaded" then
							toLoad[#toLoad + 1] = { key = key, distance = dist }
						end
					end
				end
			end
			local toUnload = {}
			for key, state in pairs(self.states) do
				if state == "loaded" and not wanted[key] then toUnload[#toUnload + 1] = key end
			end
			table.sort(toLoad, function(a, b) return a.distance < b.distance end)
			table.sort(toUnload)
			self.queue = toLoad
			return toLoad, toUnload
		end

		function self.pump()
			local processed = 0
			while #self.queue > 0 and processed < self.maxPerTick do
				local item = table.remove(self.queue, 1)
				self.setState(item.key, "loaded")
				processed = processed + 1
			end
			return processed
		end

		function self.lodOf(key, position)
			local d = self.center(key):distance(position)
			if d < self.size then return 0 end
			if d < self.size * 2 then return 1 end
			if d < self.size * 4 then return 2 end
			return 3
		end

		function self.loadedKeys()
			local out = {}
			for key, state in pairs(self.states) do if state == "loaded" then out[#out + 1] = key end end
			table.sort(out)
			return out
		end

		function self.stats() return { size = self.size, loaded = self.loaded, tracked = C.count(self.states),
			queued = #self.queue, loads = self.loads, unloads = self.unloads } end
		return self
	end

	------------------------------------------------------------------ 39. WFC (constraint tiling)
	function K.wfc(cfg)
		local self = { kind = "wfc", tiles = {}, order = {}, id = cfg.id,
			collapses = 0, contradictions = 0, backtracks = 0, grid = nil, width = 0, height = 0 }

		-- sockets: { up = "a", down = "b", left = "c", right = "d" }; tiles fit when sockets match
		function self.defineTile(id, sockets, weight)
			self.tiles[id] = { id = id, sockets = sockets, weight = weight or 1 }
			self.order[#self.order + 1] = id
			return self.tiles[id]
		end

		local OPP = { up = "down", down = "up", left = "right", right = "left" }
		local DIRS = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

		function self.compatible(aId, dir, bId)
			local a, b = self.tiles[aId], self.tiles[bId]
			if not a or not b then return false end
			return a.sockets[dir] == b.sockets[OPP[dir]]
		end

		local function cellIndex(self_, x, y) return (y - 1) * self_.width + x end

		function self.solve(width, height, seed)
			self.width, self.height = width, height
			local rng = Random.new(seed or 20260907)
			local grid = {}
			for i = 1, width * height do
				local options = {}
				for _, id in ipairs(self.order) do options[#options + 1] = id end
				grid[i] = options
			end
			self.grid = grid

			local function propagate(startX, startY)
				local stack = { { startX, startY } }
				while #stack > 0 do
					local cell = table.remove(stack)
					local x, y = cell[1], cell[2]
					local current = grid[cellIndex(self, x, y)]
					for dir, d in pairs(DIRS) do
						local nx, ny = x + d[1], y + d[2]
						if nx >= 1 and ny >= 1 and nx <= width and ny <= height then
							local ni = cellIndex(self, nx, ny)
							local neighbour = grid[ni]
							local filtered = {}
							for _, candidate in ipairs(neighbour) do
								local ok = false
								for _, mine in ipairs(current) do
									if self.compatible(mine, dir, candidate) then ok = true break end
								end
								if ok then filtered[#filtered + 1] = candidate end
							end
							if #filtered == 0 then return false end
							if #filtered < #neighbour then
								grid[ni] = filtered
								stack[#stack + 1] = { nx, ny }
							end
						end
					end
				end
				return true
			end

			for _ = 1, width * height do
				-- lowest entropy cell
				local bestI, bestCount = nil, math.huge
				for i = 1, width * height do
					local n = #grid[i]
					if n > 1 and n < bestCount then bestI, bestCount = i, n end
				end
				if not bestI then break end
				local options = grid[bestI]
				local totalWeight = 0
				for _, id in ipairs(options) do totalWeight = totalWeight + self.tiles[id].weight end
				local roll = rng:next() * totalWeight
				local chosen = options[#options]
				for _, id in ipairs(options) do
					roll = roll - self.tiles[id].weight
					if roll <= 0 then chosen = id break end
				end
				grid[bestI] = { chosen }
				self.collapses = self.collapses + 1
				local x = ((bestI - 1) % width) + 1
				local y = math.floor((bestI - 1) / width) + 1
				if not propagate(x, y) then
					self.contradictions = self.contradictions + 1
					-- relax the contradiction instead of failing the world: restore full domain
					grid[bestI] = {}
					for _, id in ipairs(self.order) do table.insert(grid[bestI], id) end
					self.backtracks = self.backtracks + 1
				end
			end

			local result = {}
			for i = 1, width * height do result[i] = grid[i][1] end
			self.result = result
			return result
		end

		function self.at(x, y)
			if not self.result then return nil end
			if x < 1 or y < 1 or x > self.width or y > self.height then return nil end
			return self.result[(y - 1) * self.width + x]
		end

		function self.histogram()
			local out = {}
			for _, id in ipairs(self.result or {}) do out[id] = (out[id] or 0) + 1 end
			return out
		end

		function self.validate()
			local bad = 0
			for y = 1, self.height do
				for x = 1, self.width do
					local a = self.at(x, y)
					for dir, d in pairs(DIRS) do
						local b = self.at(x + d[1], y + d[2])
						if a and b and not self.compatible(a, dir, b) then bad = bad + 1 end
					end
				end
			end
			return bad == 0, bad
		end

		function self.stats() return { tiles = C.count(self.tiles), collapses = self.collapses,
			contradictions = self.contradictions, backtracks = self.backtracks,
			cells = self.width * self.height } end
		return self
	end

	------------------------------------------------------------------ 40. LSYSTEM
	function K.lsystem(cfg)
		local self = { kind = "lsystem", axiom = cfg.axiom or "F", rules = cfg.rules or {},
			angle = cfg.angle or 25, step = cfg.step or 4, id = cfg.id,
			iterations = 0, current = nil, segments = {} }

		function self.addRule(symbol, replacement)
			self.rules[symbol] = replacement
			return self
		end

		function self.iterate(n)
			local s = self.current or self.axiom
			if not self.current then self.iterations = 0 end
			for _ = 1, (n or 1) do
				local out = {}
				for i = 1, #s do
					local ch = string.sub(s, i, i)
					out[#out + 1] = self.rules[ch] or ch
				end
				s = table.concat(out)
				self.iterations = self.iterations + 1
			end
			self.current = s
			return s
		end

		function self.reset()
			self.current = nil
			self.iterations = 0
			self.segments = {}
			return self
		end

		-- turtle interpretation in 3D (yaw + pitch), producing real line segments
		function self.interpret(origin)
			local s = self.current or self.axiom
			local pos = origin or v3()
			local yaw, pitch = 0, math.pi / 2
			local stack = {}
			local segments = {}
			local rad = math.rad(self.angle)
			for i = 1, #s do
				local ch = string.sub(s, i, i)
				if ch == "F" or ch == "G" then
					local dir = v3(math.sin(pitch) * math.cos(yaw), math.cos(pitch), math.sin(pitch) * math.sin(yaw))
					local nextPos = pos + dir * self.step
					segments[#segments + 1] = { from = pos, to = nextPos, depth = #stack }
					pos = nextPos
				elseif ch == "+" then yaw = yaw + rad
				elseif ch == "-" then yaw = yaw - rad
				elseif ch == "^" then pitch = math.max(0.05, pitch - rad)
				elseif ch == "&" then pitch = math.min(math.pi - 0.05, pitch + rad)
				elseif ch == "[" then stack[#stack + 1] = { pos = pos, yaw = yaw, pitch = pitch }
				elseif ch == "]" then
					local saved = table.remove(stack)
					if saved then pos, yaw, pitch = saved.pos, saved.yaw, saved.pitch end
				end
			end
			self.segments = segments
			return segments
		end

		function self.bounds()
			local minv, maxv
			for _, seg in ipairs(self.segments) do
				for _, p in ipairs({ seg.from, seg.to }) do
					minv = minv and minv:min(p) or p
					maxv = maxv and maxv:max(p) or p
				end
			end
			if not minv then return nil end
			return Spatial.aabb(minv, maxv)
		end

		function self.totalLength()
			local total = 0
			for _, seg in ipairs(self.segments) do total = total + seg.from:distance(seg.to) end
			return total
		end

		function self.stats() return { rules = C.count(self.rules), iterations = self.iterations,
			length = self.current and #self.current or #self.axiom, segments = #self.segments } end
		return self
	end

	------------------------------------------------------------------ 41. SCATTER
	function K.scatter(cfg)
		local self = { kind = "scatter", seed = cfg.seed or 7331, minDistance = cfg.minDistance or 8,
			density = cfg.density or 1, id = cfg.id, points = {}, rejected = 0, masks = {} }

		function self.addMask(name, fn)
			self.masks[name] = fn
			return self
		end

		local function passesMasks(self_, p)
			for _, fn in pairs(self_.masks) do
				if not fn(p) then return false end
			end
			return true
		end

		-- jittered-grid blue noise: deterministic, and it honours minDistance for real
		function self.generate(bounds, attempts)
			local rng = Random.new(self.seed)
			local cell = self.minDistance / math.sqrt(2)
			local grid = {}
			local out = {}
			self.rejected = 0
			local sizeX = bounds.max.x - bounds.min.x
			local sizeZ = bounds.max.z - bounds.min.z
			local tries = attempts or math.max(16, math.floor(sizeX * sizeZ * 0.02 * self.density))
			for _ = 1, tries do
				local p = v3(rng:range(bounds.min.x, bounds.max.x), 0, rng:range(bounds.min.z, bounds.max.z))
				local gx = math.floor(p.x / cell)
				local gz = math.floor(p.z / cell)
				local ok = passesMasks(self, p)
				if ok then
					for dz = -2, 2 do
						for dx = -2, 2 do
							local bucket = grid[(gx + dx) .. "," .. (gz + dz)]
							if bucket then
								for _, other in ipairs(bucket) do
									if other:distance(p) < self.minDistance then ok = false break end
								end
							end
							if not ok then break end
						end
						if not ok then break end
					end
				end
				if ok then
					local key = gx .. "," .. gz
					grid[key] = grid[key] or {}
					grid[key][#grid[key] + 1] = p
					out[#out + 1] = p
				else
					self.rejected = self.rejected + 1
				end
			end
			self.points = out
			return out
		end

		function self.filterBySlope(slopeFn, maxSlope)
			local kept = {}
			for _, p in ipairs(self.points) do
				if slopeFn(p) <= maxSlope then kept[#kept + 1] = p end
			end
			local removed = #self.points - #kept
			self.points = kept
			return removed
		end

		function self.cluster(radius)
			local clusters = {}
			local used = {}
			for i, p in ipairs(self.points) do
				if not used[i] then
					local group = { p }
					used[i] = true
					for j = i + 1, #self.points do
						if not used[j] and self.points[j]:distance(p) <= radius then
							group[#group + 1] = self.points[j]
							used[j] = true
						end
					end
					clusters[#clusters + 1] = group
				end
			end
			return clusters
		end

		function self.minimumSpacing()
			local best = math.huge
			for i = 1, #self.points do
				for j = i + 1, #self.points do
					local d = self.points[i]:distance(self.points[j])
					if d < best then best = d end
				end
			end
			if best == math.huge then return 0 end
			return best
		end

		function self.stats() return { points = #self.points, rejected = self.rejected,
			minDistance = self.minDistance, masks = C.count(self.masks) } end
		return self
	end

	------------------------------------------------------------------ 42. NETWORK (roads / rivers)
	function K.network(cfg)
		local self = { kind = "network", nodes = {}, edges = {}, adjacency = {}, id = cfg.id,
			nextId = 1, routes = 0, expansions = 0 }

		function self.addNode(position, kind)
			local id = self.nextId
			self.nextId = id + 1
			self.nodes[id] = { id = id, position = position, kind = kind or "junction", degree = 0 }
			self.adjacency[id] = {}
			return id
		end

		function self.addEdge(a, b, opts)
			opts = opts or {}
			local na, nb = self.nodes[a], self.nodes[b]
			if not na or not nb then return nil, "missing node" end
			local length = na.position:distance(nb.position)
			local edge = { a = a, b = b, length = length, width = opts.width or 8,
				class = opts.class or "street", cost = length * (opts.costFactor or 1) }
			self.edges[#self.edges + 1] = edge
			table.insert(self.adjacency[a], { node = b, edge = #self.edges })
			table.insert(self.adjacency[b], { node = a, edge = #self.edges })
			na.degree = na.degree + 1
			nb.degree = nb.degree + 1
			return #self.edges
		end

		-- A* over the network with a euclidean heuristic
		function self.route(startId, goalId)
			if not self.nodes[startId] or not self.nodes[goalId] then return nil end
			self.routes = self.routes + 1
			local open = C.priorityQueue()
			local gScore = { [startId] = 0 }
			local cameFrom = {}
			local closed = {}
			local goalPos = self.nodes[goalId].position
			open:push({ node = startId, priority = self.nodes[startId].position:distance(goalPos) })
			while not open:isEmpty() do
				local current = open:pop().node
				if current == goalId then
					local path = { goalId }
					local walker = goalId
					while cameFrom[walker] do
						walker = cameFrom[walker]
						table.insert(path, 1, walker)
					end
					return path, gScore[goalId]
				end
				closed[current] = true
				self.expansions = self.expansions + 1
				for _, link in ipairs(self.adjacency[current] or {}) do
					if not closed[link.node] then
						local tentative = gScore[current] + self.edges[link.edge].cost
						if tentative < (gScore[link.node] or math.huge) then
							gScore[link.node] = tentative
							cameFrom[link.node] = current
							open:push({ node = link.node,
								priority = tentative + self.nodes[link.node].position:distance(goalPos) })
						end
					end
				end
			end
			return nil
		end

		function self.junctions(minDegree)
			local out = {}
			for id, node in pairs(self.nodes) do
				if node.degree >= (minDegree or 3) then out[#out + 1] = id end
			end
			table.sort(out)
			return out
		end

		function self.deadEnds()
			local out = {}
			for id, node in pairs(self.nodes) do if node.degree == 1 then out[#out + 1] = id end end
			table.sort(out)
			return out
		end

		function self.totalLength()
			local total = 0
			for _, e in ipairs(self.edges) do total = total + e.length end
			return total
		end

		function self.nearestNode(position)
			local best, bestD = nil, math.huge
			for id, node in pairs(self.nodes) do
				local d = node.position:distanceSq(position)
				if d < bestD then best, bestD = id, d end
			end
			return best, math.sqrt(bestD == math.huge and 0 or bestD)
		end

		function self.connected()
			local seen = {}
			local count = 0
			local total = C.count(self.nodes)
			if total == 0 then return true end
			local startId = next(self.nodes)
			local stack = { startId }
			while #stack > 0 do
				local id = table.remove(stack)
				if not seen[id] then
					seen[id] = true
					count = count + 1
					for _, link in ipairs(self.adjacency[id] or {}) do stack[#stack + 1] = link.node end
				end
			end
			return count == total, count
		end

		function self.stats() return { nodes = C.count(self.nodes), edges = #self.edges,
			length = self.totalLength(), routes = self.routes, expansions = self.expansions } end
		return self
	end

	------------------------------------------------------------------ 43. SIMULATION ("Modo Vida Real")
	-- Tick-based world simulation with three fidelity tiers: full, reduced and statistical.
	-- Unobserved regions keep evolving statistically, then catch up when observed again.
	function K.simulation(cfg)
		local self = { kind = "simulation", entities = {}, order = {}, id = cfg.id,
			time = 0, ticks = 0, fullRadius = cfg.fullRadius or 200, reducedRadius = cfg.reducedRadius or 800,
			budget = cfg.budget or 64, processed = 0, statistical = 0, observer = v3() }

		function self.spawn(id, spec)
			self.entities[id] = { id = id, position = spec.position or v3(), state = spec.state or {},
				update = spec.update, aggregate = spec.aggregate, tier = "full", lastTick = 0, ticks = 0 }
			self.order[#self.order + 1] = id
			return self.entities[id]
		end

		function self.despawn(id)
			if not self.entities[id] then return false end
			self.entities[id] = nil
			for i, o in ipairs(self.order) do if o == id then table.remove(self.order, i) break end end
			return true
		end

		function self.setObserver(position)
			self.observer = position
			return self.classify()
		end

		function self.classify()
			local counts = { full = 0, reduced = 0, statistical = 0 }
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				local d = e.position:distance(self.observer)
				if d <= self.fullRadius then e.tier = "full"
				elseif d <= self.reducedRadius then e.tier = "reduced"
				else e.tier = "statistical" end
				counts[e.tier] = counts[e.tier] + 1
			end
			return counts
		end

		function self.tick(dt)
			dt = dt or 1 / 30
			self.time = self.time + dt
			self.ticks = self.ticks + 1
			local budget = self.budget
			local ran = 0
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				local due = false
				if e.tier == "full" then due = true
				elseif e.tier == "reduced" then due = (self.ticks % 4) == 0
				else due = (self.ticks % 30) == 0 end
				if due and budget > 0 then
					local elapsed = self.time - e.lastTick
					if e.tier == "statistical" and e.aggregate then
						e.aggregate(e.state, elapsed)
						self.statistical = self.statistical + 1
					elseif e.update then
						e.update(e.state, elapsed, e)
					end
					e.lastTick = self.time
					e.ticks = e.ticks + 1
					budget = budget - 1
					ran = ran + 1
				end
			end
			self.processed = self.processed + ran
			return ran
		end

		-- fast-forward an unobserved region without simulating every tick
		function self.catchUp(id, elapsed)
			local e = self.entities[id]
			if not e then return false end
			if e.aggregate then e.aggregate(e.state, elapsed) end
			e.lastTick = self.time
			return true
		end

		function self.query(radius)
			local out = {}
			for _, id in ipairs(self.order) do
				local e = self.entities[id]
				if e.position:distance(self.observer) <= radius then out[#out + 1] = id end
			end
			return out
		end

		function self.aggregateState(field)
			local total = 0
			for _, id in ipairs(self.order) do
				local v = self.entities[id].state[field]
				if type(v) == "number" then total = total + v end
			end
			return total
		end

		function self.stats() return { entities = #self.order, ticks = self.ticks, time = self.time,
			processed = self.processed, statistical = self.statistical, budget = self.budget } end
		return self
	end

	K.NAMES = { "scenegraph", "prefab", "heightfield", "voxel", "spline", "mesh",
		"chunker", "wfc", "lsystem", "scatter", "network", "simulation" }

	return K

end
