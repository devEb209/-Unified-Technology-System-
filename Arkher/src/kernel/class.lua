-- ARKHER KERNEL :: Class / Object Model
-- Real prototype-based OOP with mixins, interfaces and runtime type identity.
-- Luau + Lua 5.3 compatible (no type annotations, no continue, no compound assign).
--@arkher-module
return function(A)
	local Class = {}

	local function shallowMerge(dst, src)
		for k, v in pairs(src) do
			if dst[k] == nil then dst[k] = v end
		end
		return dst
	end

	-- Class.new(name, base) -> class table
	function Class.new(name, base)
		local c = {}
		c.__name = name
		c.__base = base
		c.__interfaces = {}
		c.__index = c
		if base then
			setmetatable(c, { __index = base })
		end
		c.__isClass = true

		function c.isSubclassOf(other)
			local cur = c
			while cur do
				if cur == other then return true end
				cur = cur.__base
			end
			return false
		end

		-- constructor
		setmetatable(c, {
			__index = base,
			__call = function(_, ...)
				local obj = setmetatable({}, c)
				obj.__class = c
				if c.constructor then c.constructor(obj, ...) end
				return obj
			end,
		})
		return c
	end

	function Class.mixin(c, tbl)
		shallowMerge(c, tbl)
		return c
	end

	function Class.implements(c, interfaceName, methodNames)
		local missing = {}
		for _, m in ipairs(methodNames) do
			if type(c[m]) ~= "function" then missing[#missing + 1] = m end
		end
		if #missing > 0 then
			return false, "class " .. tostring(c.__name) .. " missing: " .. table.concat(missing, ", ")
		end
		c.__interfaces[interfaceName] = true
		return true
	end

	function Class.isA(obj, c)
		if type(obj) ~= "table" then return false end
		local cur = obj.__class
		while cur do
			if cur == c then return true end
			cur = cur.__base
		end
		return false
	end

	function Class.typeOf(v)
		local t = type(v)
		if t == "table" and v.__class then return v.__class.__name end
		return t
	end

	return Class

end
