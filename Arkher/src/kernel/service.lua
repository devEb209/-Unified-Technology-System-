-- ARKHER KERNEL :: Service Container (dependency injection + lifecycle)
--@arkher-module
return function(A)
	local DepGraph = A:import("arkher/kernel/depgraph")
	local Errors = A:import("arkher/kernel/errors")
	local Service = {}
	Service.__index = Service

	function Service.new(ctx)
		local self = setmetatable({}, Service)
		self.definitions = {}
		self.instances = {}
		self.graph = DepGraph.new()
		self.ctx = ctx or {}
		self.started = {}
		self.order = nil
		return self
	end

	function Service:register(spec)
		if self.definitions[spec.id] then
			return false, Errors.new(Errors.Codes.ALREADY_EXISTS, "service already registered: " .. spec.id)
		end
		self.definitions[spec.id] = {
			id = spec.id,
			factory = spec.factory,
			deps = spec.deps or {},
			singleton = spec.singleton ~= false,
			lazy = spec.lazy == true,
			tags = spec.tags or {},
			priority = spec.priority or 0,
		}
		self.graph:addNode(spec.id)
		for _, d in ipairs(spec.deps or {}) do self.graph:addEdge(spec.id, d) end
		self.order = nil
		return true
	end

	function Service:resolve(id)
		local def = self.definitions[id]
		if not def then error(Errors.new(Errors.Codes.NOT_FOUND, "unknown service: " .. tostring(id))) end
		if def.singleton and self.instances[id] then return self.instances[id] end
		local args = {}
		for i, d in ipairs(def.deps) do args[i] = self:resolve(d) end
		local inst = def.factory(self.ctx, table.unpack(args))
		if def.singleton then self.instances[id] = inst end
		return inst
	end

	function Service:tryResolve(id)
		return Errors.try(function() return self:resolve(id) end)
	end

	function Service:has(id) return self.definitions[id] ~= nil end

	function Service:startupOrder()
		if self.order then return self.order end
		local order, err = self.graph:topoSort()
		if not order then error(err) end
		self.order = order
		return order
	end

	function Service:startAll()
		local started = {}
		for _, id in ipairs(self:startupOrder()) do
			local def = self.definitions[id]
			if def and not def.lazy then
				local inst = self:resolve(id)
				if type(inst) == "table" and type(inst.start) == "function" then
					local ok, err = pcall(inst.start, inst, self.ctx)
					if not ok then return nil, Errors.wrap(err, Errors.Codes.INTERNAL, "service start failed: " .. id) end
				end
				self.started[id] = true
				started[#started + 1] = id
			end
		end
		return started
	end

	function Service:stopAll()
		local order = self:startupOrder()
		local stopped = {}
		for i = #order, 1, -1 do
			local id = order[i]
			local inst = self.instances[id]
			if inst and type(inst) == "table" and type(inst.stop) == "function" then pcall(inst.stop, inst) end
			self.started[id] = nil
			stopped[#stopped + 1] = id
		end
		return stopped
	end

	function Service:byTag(tag)
		local out = {}
		for id, def in pairs(self.definitions) do
			for _, t in ipairs(def.tags) do
				if t == tag then out[#out + 1] = id break end
			end
		end
		table.sort(out)
		return out
	end

	function Service:count()
		local n = 0
		for _ in pairs(self.definitions) do n = n + 1 end
		return n
	end

	return Service

end
