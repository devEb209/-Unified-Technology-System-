-- ARKHER KERNEL :: Entity Component System
-- Archetype-free sparse-set ECS with queries, change detection, tags, hierarchy,
-- deferred command buffer and per-system profiling. Backbone of the ARKHER scene graph.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local ECS = {}
	ECS.__index = ECS

	function ECS.new(opts)
		opts = opts or {}
		local self = setmetatable({}, ECS)
		self.nextEntity = 1
		self.alive = {}
		self.components = {}     -- name -> SparseSet
		self.tags = {}           -- name -> { [entity]=true }
		self.parents = {}
		self.children = {}
		self.systems = {}
		self.commandBuffer = {}
		self.changed = {}        -- name -> { [entity]=frame }
		self.frame = 0
		self.entityCount = 0
		self.names = {}
		return self
	end

	function ECS:create(name)
		local e = self.nextEntity
		self.nextEntity = self.nextEntity + 1
		self.alive[e] = true
		self.entityCount = self.entityCount + 1
		if name then self.names[e] = name end
		return e
	end

	function ECS:destroy(e)
		if not self.alive[e] then return false end
		for _, set in pairs(self.components) do set:remove(e) end
		for _, t in pairs(self.tags) do t[e] = nil end
		for _, child in ipairs(self.children[e] or {}) do self:destroy(child) end
		self.children[e] = nil
		local p = self.parents[e]
		if p and self.children[p] then
			for i, c in ipairs(self.children[p]) do if c == e then table.remove(self.children[p], i) break end end
		end
		self.parents[e] = nil
		self.names[e] = nil
		self.alive[e] = nil
		self.entityCount = self.entityCount - 1
		return true
	end

	function ECS:isAlive(e) return self.alive[e] == true end

	function ECS:set(e, component, data)
		local set = self.components[component]
		if not set then set = C.sparseSet() self.components[component] = set end
		set:add(e, data)
		self.changed[component] = self.changed[component] or {}
		self.changed[component][e] = self.frame
		return data
	end

	function ECS:get(e, component)
		local set = self.components[component]
		if not set then return nil end
		return set:get(e)
	end

	function ECS:has(e, component)
		local set = self.components[component]
		return set ~= nil and set:has(e)
	end

	function ECS:removeComponent(e, component)
		local set = self.components[component]
		if not set then return false end
		return set:remove(e)
	end

	function ECS:addTag(e, tag)
		self.tags[tag] = self.tags[tag] or {}
		self.tags[tag][e] = true
	end
	function ECS:hasTag(e, tag) return self.tags[tag] ~= nil and self.tags[tag][e] == true end
	function ECS:removeTag(e, tag) if self.tags[tag] then self.tags[tag][e] = nil end end
	function ECS:withTag(tag)
		local out = {}
		for e in pairs(self.tags[tag] or {}) do out[#out + 1] = e end
		table.sort(out)
		return out
	end

	function ECS:setParent(child, parent)
		local old = self.parents[child]
		if old and self.children[old] then
			for i, c in ipairs(self.children[old]) do if c == child then table.remove(self.children[old], i) break end end
		end
		self.parents[child] = parent
		if parent then
			self.children[parent] = self.children[parent] or {}
			table.insert(self.children[parent], child)
		end
	end
	function ECS:getChildren(e) return self.children[e] or {} end
	function ECS:getParent(e) return self.parents[e] end
	function ECS:descendants(e, out)
		out = out or {}
		for _, c in ipairs(self:getChildren(e)) do
			out[#out + 1] = c
			self:descendants(c, out)
		end
		return out
	end

	-- query: entities holding every listed component (smallest set drives iteration)
	function ECS:query(componentList)
		local sets = {}
		for _, name in ipairs(componentList) do
			local s = self.components[name]
			if not s then return {} end
			sets[#sets + 1] = { name = name, set = s }
		end
		table.sort(sets, function(a, b) return a.set:count() < b.set:count() end)
		local out = {}
		for e in sets[1].set:iterate() do
			local ok = true
			for i = 2, #sets do
				if not sets[i].set:has(e) then ok = false break end
			end
			if ok then out[#out + 1] = e end
		end
		return out
	end

	function ECS:each(componentList, fn)
		local entities = self:query(componentList)
		for _, e in ipairs(entities) do
			local args = {}
			for i, name in ipairs(componentList) do args[i] = self.components[name]:get(e) end
			fn(e, table.unpack(args))
		end
		return #entities
	end

	function ECS:changedSince(component, frame)
		local out = {}
		for e, f in pairs(self.changed[component] or {}) do
			if f >= frame then out[#out + 1] = e end
		end
		return out
	end

	-- deferred structural changes (safe during iteration)
	function ECS:defer(fn) self.commandBuffer[#self.commandBuffer + 1] = fn end
	function ECS:flush()
		local cmds = self.commandBuffer
		self.commandBuffer = {}
		for _, fn in ipairs(cmds) do fn(self) end
		return #cmds
	end

	function ECS:addSystem(spec)
		self.systems[#self.systems + 1] = {
			name = spec.name, fn = spec.fn, query = spec.query or {},
			priority = spec.priority or 0, enabled = true, ms = 0,
		}
		table.sort(self.systems, function(a, b) return a.priority > b.priority end)
	end

	function ECS:update(dt, timeFn)
		self.frame = self.frame + 1
		timeFn = timeFn or function() return 0 end
		for _, sys in ipairs(self.systems) do
			if sys.enabled then
				local t0 = timeFn()
				sys.fn(self, dt)
				sys.ms = sys.ms * 0.9 + (timeFn() - t0) * 1000 * 0.1
			end
		end
		self:flush()
		return self.frame
	end

	function ECS:snapshot()
		local snap = { entities = {}, frame = self.frame }
		for e in pairs(self.alive) do
			local rec = { id = e, components = {}, tags = {}, parent = self.parents[e], name = self.names[e] }
			for name, set in pairs(self.components) do
				if set:has(e) then rec.components[name] = set:get(e) end
			end
			for tag, t in pairs(self.tags) do if t[e] then rec.tags[#rec.tags + 1] = tag end end
			snap.entities[#snap.entities + 1] = rec
		end
		table.sort(snap.entities, function(a, b) return a.id < b.id end)
		return snap
	end

	function ECS:restore(snap)
		self.alive = {} self.components = {} self.tags = {} self.parents = {} self.children = {}
		self.entityCount = 0
		local maxId = 0
		for _, rec in ipairs(snap.entities) do
			self.alive[rec.id] = true
			self.entityCount = self.entityCount + 1
			if rec.id > maxId then maxId = rec.id end
			for name, data in pairs(rec.components) do self:set(rec.id, name, data) end
			for _, tag in ipairs(rec.tags) do self:addTag(rec.id, tag) end
			if rec.name then self.names[rec.id] = rec.name end
		end
		for _, rec in ipairs(snap.entities) do
			if rec.parent then self:setParent(rec.id, rec.parent) end
		end
		self.nextEntity = maxId + 1
		self.frame = snap.frame or 0
		return self.entityCount
	end

	function ECS:stats()
		local comps = 0
		for _ in pairs(self.components) do comps = comps + 1 end
		return { entities = self.entityCount, componentTypes = comps, systems = #self.systems, frame = self.frame }
	end

	return ECS

end
