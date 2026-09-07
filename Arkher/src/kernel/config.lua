-- ARKHER KERNEL :: Configuration + Feature Flags + Environment
-- Layered configuration (defaults < platform < project < user < runtime) with
-- schema validation, change signals, presets and device-conditional overrides.
--@arkher-module
return function(A)
	local Signal = A:import("arkher/kernel/signal")
	local C = A:import("arkher/kernel/containers")
	local Config = {}
	Config.__index = Config

	local LAYERS = { "default", "platform", "project", "user", "runtime" }

	function Config.new(defaults)
		local self = setmetatable({}, Config)
		self.layers = {}
		for _, l in ipairs(LAYERS) do self.layers[l] = {} end
		self.layers.default = defaults or {}
		self._resolved = nil
		self.onChange = Signal.new("config.change")
		self.schema = {}
		self.locked = {}
		return self
	end

	local function getPath(tbl, path)
		local node = tbl
		for part in string.gmatch(path, "[^%.]+") do
			if type(node) ~= "table" then return nil end
			node = node[part]
		end
		return node
	end

	local function setPath(tbl, path, value)
		local node = tbl
		local parts = {}
		for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = part end
		for i = 1, #parts - 1 do
			node[parts[i]] = node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = value
	end

	function Config:resolve()
		if self._resolved then return self._resolved end
		local merged = {}
		for _, l in ipairs(LAYERS) do merged = C.merge(merged, self.layers[l]) end
		self._resolved = merged
		return merged
	end

	function Config:get(path, fallback)
		local v = getPath(self:resolve(), path)
		if v == nil then return fallback end
		return v
	end

	function Config:set(path, value, layer)
		if self.locked[path] then return false end
		layer = layer or "runtime"
		local old = self:get(path)
		setPath(self.layers[layer], path, value)
		self._resolved = nil
		if old ~= value then self.onChange:fire(path, value, old) end
		return true
	end

	function Config:lock(path) self.locked[path] = true end
	function Config:unlock(path) self.locked[path] = nil end

	function Config:defineSchema(path, spec) self.schema[path] = spec end

	function Config:validate()
		local issues = {}
		for path, spec in pairs(self.schema) do
			local v = self:get(path)
			if v == nil and spec.required then
				issues[#issues + 1] = { path = path, issue = "missing required value" }
			elseif v ~= nil then
				if spec.type and type(v) ~= spec.type then
					issues[#issues + 1] = { path = path, issue = "expected " .. spec.type .. " got " .. type(v) }
				end
				if spec.min and type(v) == "number" and v < spec.min then
					issues[#issues + 1] = { path = path, issue = "below min " .. spec.min }
				end
				if spec.max and type(v) == "number" and v > spec.max then
					issues[#issues + 1] = { path = path, issue = "above max " .. spec.max }
				end
				if spec.oneOf then
					local ok = false
					for _, allowed in ipairs(spec.oneOf) do if v == allowed then ok = true break end end
					if not ok then issues[#issues + 1] = { path = path, issue = "value not allowed" } end
				end
			end
		end
		return #issues == 0, issues
	end

	function Config:applyPreset(name, table_)
		self.layers.project = C.merge(self.layers.project, table_)
		self._resolved = nil
		self.onChange:fire("preset:" .. name, table_, nil)
		return true
	end

	function Config:snapshot() return C.deepCopy(self:resolve()) end
	function Config:diffFrom(snapshot)
		local out = {}
		local cur = self:resolve()
		local function walk(a, b, prefix)
			for k, v in pairs(b) do
				local p = prefix == "" and tostring(k) or (prefix .. "." .. tostring(k))
				if type(v) == "table" then walk(type(a[k]) == "table" and a[k] or {}, v, p)
				elseif a[k] ~= v then out[p] = { from = a[k], to = v } end
			end
		end
		walk(snapshot, cur, "")
		return out
	end

	------------------------------------------------------------------ Feature flags
	local Flags = {}
	Flags.__index = Flags
	function Config.flags(initial)
		local self = setmetatable({}, Flags)
		self.values = initial or {}
		self.rules = {}
		self.onChange = Signal.new("flags.change")
		self.evaluations = 0
		return self
	end
	function Flags:define(name, default, rule)
		self.values[name] = default
		if rule then self.rules[name] = rule end
		return self
	end
	function Flags:enabled(name, ctx)
		self.evaluations = self.evaluations + 1
		local rule = self.rules[name]
		if rule then
			local ok, res = pcall(rule, ctx or {})
			if ok then return res == true end
		end
		return self.values[name] == true
	end
	function Flags:set(name, value)
		local old = self.values[name]
		self.values[name] = value
		if old ~= value then self.onChange:fire(name, value, old) end
	end
	function Flags:all()
		local out = {}
		for k, v in pairs(self.values) do out[k] = v end
		return out
	end
	function Flags:count()
		local n = 0
		for _ in pairs(self.values) do n = n + 1 end
		return n
	end

	return Config

end
