-- ARKHER SCENE FRAMEWORK
-- The authoritative world representation: hierarchy, instancing, spatial acceleration,
-- tags, layers, visibility, LOD selection, queries and persistence. Platform neutral -
-- the Roblox adapter only mirrors what this module decides.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local C = A:import("arkher/kernel/containers")
	local Ser = A:import("arkher/kernel/serialize")
	local v3 = Vec.vec3

	local Scene = {}
	Scene.__index = Scene

	function Scene.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Scene)
		self.name = opts.name or "ARKHER Scene"
		self.graph = Kits.scenegraph({ id = self.name })
		self.prefabs = Kits.prefab({ id = self.name .. ".prefabs" })
		self.index = Spatial.spatialHash(opts.cellSize or 64)
		self.layers = { default = { name = "default", visible = true, locked = false } }
		self.objects = {}
		self.lodBands = opts.lodBands or { 120, 320, 900 }
		self.stats = { spawned = 0, destroyed = 0, queries = 0, lodSwitches = 0 }
		self.graph.addNode("root", { position = v3() })
		return self
	end

	------------------------------------------------------------------ authoring
	function Scene:definePrefab(name, spec) return self.prefabs.define(name, spec) end

	function Scene:spawn(id, spec)
		spec = spec or {}
		if self.objects[id] then return nil, "duplicate object" end
		local position = spec.position or v3()
		local node = self.graph.addNode(id, {
			position = position, scale = spec.scale, tags = spec.tags,
			radius = spec.radius or 4, visible = spec.visible ~= false,
			static = spec.static or false,
		}, spec.parent or "root")
		if not node then return nil, "graph rejected the node" end
		local obj = { id = id, layer = spec.layer or "default", prefab = nil,
			props = spec.props or {}, lod = 0, visible = spec.visible ~= false }
		if spec.prefab then
			obj.prefab = self.prefabs.instantiate(spec.prefab, spec.overrides)
			local inst = self.prefabs.instances[obj.prefab]
			if inst then
				for k, v in pairs(inst.props) do
					if obj.props[k] == nil then obj.props[k] = v end
				end
			end
		end
		self.objects[id] = obj
		self.index:insert(id, self.graph.worldPosition(id))
		self.stats.spawned = self.stats.spawned + 1
		return id
	end

	function Scene:destroy(id)
		if not self.objects[id] then return 0 end
		local removedIds = self.graph.descendants(id)
		removedIds[#removedIds + 1] = id
		for _, rid in ipairs(removedIds) do
			if self.objects[rid] then
				if self.objects[rid].prefab then self.prefabs.destroy(self.objects[rid].prefab) end
				self.index:remove(rid)
				self.objects[rid] = nil
				self.stats.destroyed = self.stats.destroyed + 1
			end
		end
		self.graph.remove(id)
		return #removedIds
	end

	function Scene:move(id, position)
		if not self.objects[id] then return false end
		self.graph.setPosition(id, position)
		self.index:update(id, self.graph.worldPosition(id))
		for _, child in ipairs(self.graph.descendants(id)) do
			self.index:update(child, self.graph.worldPosition(child))
		end
		return true
	end

	function Scene:reparent(id, parent)
		local ok = self.graph.setParent(id, parent)
		if ok then self.index:update(id, self.graph.worldPosition(id)) end
		return ok
	end

	function Scene:setProp(id, key, value)
		local obj = self.objects[id]
		if not obj then return false end
		obj.props[key] = value
		return true
	end

	------------------------------------------------------------------ layers
	function Scene:addLayer(name, opts)
		opts = opts or {}
		self.layers[name] = { name = name, visible = opts.visible ~= false, locked = opts.locked or false }
		return self.layers[name]
	end

	function Scene:setLayerVisible(name, visible)
		local layer = self.layers[name]
		if not layer then return 0 end
		layer.visible = visible
		local n = 0
		for id, obj in pairs(self.objects) do
			if obj.layer == name then
				obj.visible = visible
				local node = self.graph.get(id)
				if node then node.visible = visible end
				n = n + 1
			end
		end
		return n
	end

	function Scene:objectsInLayer(name)
		local out = {}
		for id, obj in pairs(self.objects) do if obj.layer == name then out[#out + 1] = id end end
		table.sort(out)
		return out
	end

	------------------------------------------------------------------ queries
	function Scene:queryRadius(position, radius)
		self.stats.queries = self.stats.queries + 1
		local out = {}
		for _, entry in ipairs(self.index:queryRadius(position, radius)) do out[#out + 1] = entry.id end
		table.sort(out)
		return out
	end

	function Scene:queryRadiusDetailed(position, radius)
		self.stats.queries = self.stats.queries + 1
		return self.index:queryRadius(position, radius)
	end

	function Scene:queryBox(bounds)
		self.stats.queries = self.stats.queries + 1
		local center = (bounds.min + bounds.max) * 0.5
		local radius = (bounds.max - bounds.min):length() * 0.5
		local out = {}
		for _, entry in ipairs(self.index:queryRadius(center, radius)) do
			local id = entry.id
			local p = self.graph.worldPosition(id)
			if p.x >= bounds.min.x and p.x <= bounds.max.x and p.y >= bounds.min.y and p.y <= bounds.max.y
				and p.z >= bounds.min.z and p.z <= bounds.max.z then
				out[#out + 1] = id
			end
		end
		table.sort(out)
		return out
	end

	function Scene:queryTag(tag) return self.graph.withTag(tag) end

	function Scene:nearest(position, maxDistance)
		self.stats.queries = self.stats.queries + 1
		local entry, distance = self.index:nearest(position, maxDistance or 1e9)
		if not entry then return nil end
		return entry.id, distance
	end

	function Scene:raycast(origin, direction, maxDistance)
		local prims = {}
		for id in pairs(self.objects) do
			local node = self.graph.get(id)
			local p = self.graph.worldPosition(id)
			local r = node.radius
			prims[#prims + 1] = { id = id, bounds = Spatial.aabb(p - v3(r, r, r), p + v3(r, r, r)) }
		end
		if #prims == 0 then return nil end
		local bvh = Spatial.bvh(prims)
		return bvh:raycast(origin, direction:unit(), maxDistance or 4096)
	end

	------------------------------------------------------------------ LOD + visibility
	function Scene:updateLOD(viewer)
		local switches = 0
		for id, obj in pairs(self.objects) do
			local d = self.graph.worldPosition(id):distance(viewer)
			local band = #self.lodBands + 1
			for i, limit in ipairs(self.lodBands) do
				if d <= limit then band = i break end
			end
			local lod = band - 1
			if obj.lod ~= lod then
				obj.lod = lod
				switches = switches + 1
			end
		end
		self.stats.lodSwitches = self.stats.lodSwitches + switches
		return switches
	end

	function Scene:visibleSet(viewer, radius)
		local out = {}
		for _, id in ipairs(self:queryRadius(viewer, radius)) do
			local obj = self.objects[id]
			if obj and obj.visible and self.layers[obj.layer] and self.layers[obj.layer].visible then
				out[#out + 1] = id
			end
		end
		table.sort(out)
		return out
	end

	function Scene:lodHistogram()
		local out = {}
		for _, obj in pairs(self.objects) do out[obj.lod] = (out[obj.lod] or 0) + 1 end
		return out
	end

	------------------------------------------------------------------ persistence
	function Scene:save()
		local payload = { name = self.name, objects = {}, layers = self.layers }
		for id, obj in pairs(self.objects) do
			local node = self.graph.get(id)
			payload.objects[id] = { position = { node.position.x, node.position.y, node.position.z },
				parent = node.parent, tags = node.tags, layer = obj.layer, props = obj.props,
				radius = node.radius }
		end
		return Ser.encodeBinary(payload)
	end

	function Scene:load(blob)
		local data = Ser.decodeBinary(blob)
		if not data or not data.objects then return false end
		self.graph = Kits.scenegraph({ id = self.name })
		self.graph.addNode("root", { position = v3() })
		self.index = Spatial.spatialHash(64)
		self.objects = {}
		self.layers = data.layers or { default = { name = "default", visible = true } }
		local pending = {}
		for id, rec in pairs(data.objects) do pending[#pending + 1] = { id = id, rec = rec } end
		table.sort(pending, function(a, b) return a.id < b.id end)
		-- parents first: repeat until nothing else can be attached
		local remaining = #pending
		while remaining > 0 do
			local progress = false
			for _, item in ipairs(pending) do
				if item.rec and (not item.rec.parent or item.rec.parent == "root" or self.objects[item.rec.parent]) then
					self:spawn(item.id, { position = v3(item.rec.position[1], item.rec.position[2], item.rec.position[3]),
						parent = item.rec.parent, tags = item.rec.tags, layer = item.rec.layer,
						props = item.rec.props, radius = item.rec.radius })
					item.rec = nil
					remaining = remaining - 1
					progress = true
				end
			end
			if not progress then break end
		end
		return true
	end

	function Scene:report()
		return { name = self.name, objects = C.count(self.objects), graph = self.graph.stats(),
			prefabs = self.prefabs.stats(), layers = C.count(self.layers), stats = self.stats,
			bounds = self.graph.bounds(), lod = self:lodHistogram() }
	end

	return Scene

end
