-- ARKHER KERNEL :: Spatial Acceleration
-- AABB, spatial hash, uniform grid, octree, BVH and frustum culling primitives.
-- These are the foundation of ARKHER streaming, culling, physics broadphase and AI perception.
--@arkher-module
return function(A)
	local Vec = A:import("arkher/kernel/vec")
	local S = {}

	------------------------------------------------------------------ AABB
	local AABB = {}
	AABB.__index = AABB
	function S.aabb(min, max) return setmetatable({ min = min, max = max }, AABB) end
	function S.aabbFromCenter(center, halfSize) return S.aabb(center - halfSize, center + halfSize) end
	function AABB:center() return (self.min + self.max) * 0.5 end
	function AABB:size() return self.max - self.min end
	function AABB:volume()
		local s = self:size()
		return s.x * s.y * s.z
	end
	function AABB:contains(p)
		return p.x >= self.min.x and p.x <= self.max.x and p.y >= self.min.y and p.y <= self.max.y and p.z >= self.min.z and p.z <= self.max.z
	end
	function AABB:intersects(o)
		return self.min.x <= o.max.x and self.max.x >= o.min.x and self.min.y <= o.max.y and self.max.y >= o.min.y and self.min.z <= o.max.z and self.max.z >= o.min.z
	end
	function AABB:expand(p)
		self.min = self.min:min(p)
		self.max = self.max:max(p)
		return self
	end
	function AABB:union(o) return S.aabb(self.min:min(o.min), self.max:max(o.max)) end
	function AABB:distanceTo(p)
		local dx = math.max(self.min.x - p.x, 0, p.x - self.max.x)
		local dy = math.max(self.min.y - p.y, 0, p.y - self.max.y)
		local dz = math.max(self.min.z - p.z, 0, p.z - self.max.z)
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	function AABB:surfaceArea()
		local s = self:size()
		return 2 * (s.x * s.y + s.y * s.z + s.z * s.x)
	end
	function AABB:rayHit(origin, dir, maxDist)
		local tmin, tmax = 0, maxDist or math.huge
		local o = { origin.x, origin.y, origin.z }
		local d = { dir.x, dir.y, dir.z }
		local lo = { self.min.x, self.min.y, self.min.z }
		local hi = { self.max.x, self.max.y, self.max.z }
		for i = 1, 3 do
			if math.abs(d[i]) < 1e-9 then
				if o[i] < lo[i] or o[i] > hi[i] then return nil end
			else
				local inv = 1 / d[i]
				local t1 = (lo[i] - o[i]) * inv
				local t2 = (hi[i] - o[i]) * inv
				if t1 > t2 then t1, t2 = t2, t1 end
				if t1 > tmin then tmin = t1 end
				if t2 < tmax then tmax = t2 end
				if tmin > tmax then return nil end
			end
		end
		return tmin
	end
	S.AABB = AABB

	------------------------------------------------------------------ Spatial Hash
	local Hash = {}
	Hash.__index = Hash
	function S.spatialHash(cellSize)
		return setmetatable({ cell = cellSize or 32, cells = {}, items = {}, count = 0 }, Hash)
	end
	local function keyOf(self, x, y, z)
		local c = self.cell
		return string.format("%d:%d:%d", math.floor(x / c), math.floor(y / c), math.floor(z / c))
	end
	function Hash:insert(id, pos)
		local k = keyOf(self, pos.x, pos.y, pos.z)
		self.cells[k] = self.cells[k] or {}
		self.cells[k][id] = pos
		if not self.items[id] then self.count = self.count + 1 end
		self.items[id] = k
		return k
	end
	function Hash:remove(id)
		local k = self.items[id]
		if not k then return false end
		if self.cells[k] then self.cells[k][id] = nil end
		self.items[id] = nil
		self.count = self.count - 1
		return true
	end
	function Hash:update(id, pos)
		local k = keyOf(self, pos.x, pos.y, pos.z)
		if self.items[id] == k then
			self.cells[k][id] = pos
			return false
		end
		self:remove(id)
		self:insert(id, pos)
		return true
	end
	function Hash:queryRadius(center, radius)
		local out = {}
		local c = self.cell
		local r = math.ceil(radius / c)
		local cx, cy, cz = math.floor(center.x / c), math.floor(center.y / c), math.floor(center.z / c)
		local r2 = radius * radius
		for dx = -r, r do
			for dy = -r, r do
				for dz = -r, r do
					local k = string.format("%d:%d:%d", cx + dx, cy + dy, cz + dz)
					local bucket = self.cells[k]
					if bucket then
						for id, pos in pairs(bucket) do
							if pos:distanceSq(center) <= r2 then out[#out + 1] = { id = id, pos = pos } end
						end
					end
				end
			end
		end
		return out
	end
	function Hash:nearest(center, maxRadius)
		local best, bestD = nil, math.huge
		for _, e in ipairs(self:queryRadius(center, maxRadius or self.cell * 4)) do
			local d = e.pos:distanceSq(center)
			if d < bestD then best, bestD = e, d end
		end
		return best, math.sqrt(bestD)
	end
	S.Hash = Hash

	------------------------------------------------------------------ Octree
	local Octree = {}
	Octree.__index = Octree
	function S.octree(bounds, maxDepth, maxItems)
		return setmetatable({ bounds = bounds, depth = 0, maxDepth = maxDepth or 8, maxItems = maxItems or 8,
			items = {}, children = nil, total = 0 }, Octree)
	end
	function Octree:_split()
		local c = self.bounds:center()
		local mn, mx = self.bounds.min, self.bounds.max
		self.children = {}
		local xs = { { mn.x, c.x }, { c.x, mx.x } }
		local ys = { { mn.y, c.y }, { c.y, mx.y } }
		local zs = { { mn.z, c.z }, { c.z, mx.z } }
		for i = 1, 2 do for j = 1, 2 do for k = 1, 2 do
			local child = S.octree(S.aabb(Vec.vec3(xs[i][1], ys[j][1], zs[k][1]), Vec.vec3(xs[i][2], ys[j][2], zs[k][2])), self.maxDepth, self.maxItems)
			child.depth = self.depth + 1
			self.children[#self.children + 1] = child
		end end end
		local old = self.items
		self.items = {}
		for _, it in ipairs(old) do self:insert(it.id, it.pos) end
	end
	function Octree:insert(id, pos)
		if not self.bounds:contains(pos) then return false end
		self.total = self.total + 1
		if self.children then
			for _, c in ipairs(self.children) do
				if c:insert(id, pos) then return true end
			end
			return false
		end
		self.items[#self.items + 1] = { id = id, pos = pos }
		if #self.items > self.maxItems and self.depth < self.maxDepth then self:_split() end
		return true
	end
	function Octree:query(box, out)
		out = out or {}
		if not self.bounds:intersects(box) then return out end
		if self.children then
			for _, c in ipairs(self.children) do c:query(box, out) end
		else
			for _, it in ipairs(self.items) do
				if box:contains(it.pos) then out[#out + 1] = it end
			end
		end
		return out
	end
	function Octree:nodeCount()
		if not self.children then return 1 end
		local n = 1
		for _, c in ipairs(self.children) do n = n + c:nodeCount() end
		return n
	end
	S.Octree = Octree

	------------------------------------------------------------------ BVH (surface-area heuristic, binned)
	local BVH = {}
	BVH.__index = BVH
	function S.bvh(primitives)
		local self = setmetatable({ nodes = {}, prims = primitives or {} }, BVH)
		if #self.prims > 0 then self:build() end
		return self
	end
	local function boundsOf(prims, from, to)
		local b = S.aabb(Vec.vec3(math.huge, math.huge, math.huge), Vec.vec3(-math.huge, -math.huge, -math.huge))
		for i = from, to do
			b:expand(prims[i].bounds.min)
			b:expand(prims[i].bounds.max)
		end
		return b
	end
	function BVH:build(leafSize)
		leafSize = leafSize or 4
		self.nodes = {}
		local function recurse(from, to)
			local b = boundsOf(self.prims, from, to)
			local node = { bounds = b, from = from, to = to }
			self.nodes[#self.nodes + 1] = node
			local idx = #self.nodes
			if (to - from + 1) <= leafSize then
				node.leaf = true
				return idx
			end
			local size = b:size()
			local axis = "x"
			if size.y > size.x and size.y >= size.z then axis = "y"
			elseif size.z > size.x and size.z > size.y then axis = "z" end
			local slice = {}
			for i = from, to do slice[#slice + 1] = self.prims[i] end
			table.sort(slice, function(p, q) return p.bounds:center()[axis] < q.bounds:center()[axis] end)
			for i = from, to do self.prims[i] = slice[i - from + 1] end
			local mid = (from + to) // 2
			node.left = recurse(from, mid)
			node.right = recurse(mid + 1, to)
			return idx
		end
		self.root = recurse(1, #self.prims)
		return self
	end
	function BVH:query(box, out)
		out = out or {}
		if not self.root then return out end
		local stack = { self.root }
		while #stack > 0 do
			local node = self.nodes[table.remove(stack)]
			if node.bounds:intersects(box) then
				if node.leaf then
					for i = node.from, node.to do
						if self.prims[i].bounds:intersects(box) then out[#out + 1] = self.prims[i] end
					end
				else
					stack[#stack + 1] = node.left
					stack[#stack + 1] = node.right
				end
			end
		end
		return out
	end
	function BVH:raycast(origin, dir, maxDist)
		local best, bestT = nil, maxDist or math.huge
		if not self.root then return nil end
		local stack = { self.root }
		while #stack > 0 do
			local node = self.nodes[table.remove(stack)]
			local t = node.bounds:rayHit(origin, dir, bestT)
			if t then
				if node.leaf then
					for i = node.from, node.to do
						local ht = self.prims[i].bounds:rayHit(origin, dir, bestT)
						if ht and ht < bestT then bestT = ht best = self.prims[i] end
					end
				else
					stack[#stack + 1] = node.left
					stack[#stack + 1] = node.right
				end
			end
		end
		return best, bestT
	end
	S.BVH = BVH

	------------------------------------------------------------------ Frustum
	local Frustum = {}
	Frustum.__index = Frustum
	function S.frustum(planes) return setmetatable({ planes = planes }, Frustum) end
	function S.frustumFromCamera(position, forward, up, fovY, aspect, near, far)
		local f = forward:unit()
		local r = f:cross(up):unit()
		local u = r:cross(f):unit()
		local hNear = 2 * math.tan(fovY / 2) * near
		local wNear = hNear * aspect
		local nc = position + f * near
		local fc = position + f * far
		local planes = {}
		local function plane(point, normal) return { point = point, normal = normal:unit() } end
		planes[1] = plane(nc, f)
		planes[2] = plane(fc, -f)
		local aux = ((nc + u * (hNear / 2)) - position):unit()
		planes[3] = plane(position, aux:cross(r))
		aux = ((nc - u * (hNear / 2)) - position):unit()
		planes[4] = plane(position, r:cross(aux))
		aux = ((nc - r * (wNear / 2)) - position):unit()
		planes[5] = plane(position, aux:cross(u))
		aux = ((nc + r * (wNear / 2)) - position):unit()
		planes[6] = plane(position, u:cross(aux))
		return S.frustum(planes)
	end
	function Frustum:containsPoint(p)
		for _, pl in ipairs(self.planes) do
			if (p - pl.point):dot(pl.normal) < 0 then return false end
		end
		return true
	end
	function Frustum:containsSphere(center, radius)
		for _, pl in ipairs(self.planes) do
			if (center - pl.point):dot(pl.normal) < -radius then return false end
		end
		return true
	end
	function Frustum:containsAABB(box)
		local c = box:center()
		local e = box:size() * 0.5
		local r = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z)
		return self:containsSphere(c, r)
	end
	S.Frustum = Frustum

	return S

end
