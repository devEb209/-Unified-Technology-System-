-- ARKHER KERNEL :: Module Loader (A.4 Module System)
-- Single loader used identically in Roblox and headless. Every ARKHER source file is a
-- factory: `return function(A) ... return Module end`. The loader resolves ids like
-- "arkher/kernel/eventbus", caches instances, detects cycles and records load metrics.
--@arkher-module
return function(A)
	local Loader = {}
	Loader.__index = Loader

	function Loader.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Loader)
		self._factories = {}
		self._cache = {}
		self._loading = {}
		self._stack = {}
		self.loadOrder = {}
		self.timeFn = opts.timeFn or function() return 0 end
		self.metrics = {}
		self.version = "1.0.0"
		self.onLoad = opts.onLoad
		return self
	end

	function Loader:define(id, factory)
		if type(factory) ~= "function" then
			error("ARKHER loader: factory for '" .. tostring(id) .. "' must be a function")
		end
		self._factories[id] = factory
		return self
	end

	function Loader:has(id) return self._factories[id] ~= nil end

	function Loader:import(id)
		local cached = self._cache[id]
		if cached ~= nil then return cached end
		if self._loading[id] then
			error("ARKHER loader: dependency cycle -> " .. table.concat(self._stack, " -> ") .. " -> " .. id)
		end
		local factory = self._factories[id]
		if not factory then
			error("ARKHER loader: unknown module '" .. tostring(id) .. "'")
		end
		self._loading[id] = true
		self._stack[#self._stack + 1] = id
		local t0 = self.timeFn()
		local mod = factory(self)
		local dt = self.timeFn() - t0
		table.remove(self._stack)
		self._loading[id] = nil
		if mod == nil then mod = false end
		self._cache[id] = mod
		self.loadOrder[#self.loadOrder + 1] = id
		self.metrics[id] = { ms = dt * 1000, order = #self.loadOrder }
		if self.onLoad then pcall(self.onLoad, id, mod) end
		return mod
	end

	function Loader:ids()
		local out = {}
		for id in pairs(self._factories) do out[#out + 1] = id end
		table.sort(out)
		return out
	end

	function Loader:idsWithPrefix(prefix)
		local out = {}
		for id in pairs(self._factories) do
			if string.sub(id, 1, #prefix) == prefix then out[#out + 1] = id end
		end
		table.sort(out)
		return out
	end

	function Loader:count()
		local n = 0
		for _ in pairs(self._factories) do n = n + 1 end
		return n
	end

	function Loader:loadedCount()
		local n = 0
		for _ in pairs(self._cache) do n = n + 1 end
		return n
	end

	function Loader:unload(id)
		self._cache[id] = nil
		return true
	end

	function Loader:reload(id)
		self:unload(id)
		return self:import(id)
	end

	function Loader:slowest(n)
		local list = {}
		for id, m in pairs(self.metrics) do list[#list + 1] = { id = id, ms = m.ms } end
		table.sort(list, function(a, b) return a.ms > b.ms end)
		local out = {}
		for i = 1, math.min(n or 10, #list) do out[i] = list[i] end
		return out
	end

	return Loader

end
