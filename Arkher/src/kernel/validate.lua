-- ARKHER KERNEL :: Validation System
-- Declarative schema validation for assets, projects, network payloads and editor input.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local Validate = {}

	local function typeName(v)
		if type(v) == "table" and v.__class then return v.__class.__name end
		return type(v)
	end

	-- schema = { field = { type="number", required=true, min=, max=, pattern=, oneOf=, of=schema, validate=fn } }
	function Validate.check(value, schema, path)
		path = path or ""
		local issues = {}
		local function push(p, msg) issues[#issues + 1] = { path = p, message = msg } end

		for field, spec in pairs(schema) do
			local p = path == "" and field or (path .. "." .. field)
			local v = value ~= nil and value[field] or nil
			if v == nil then
				if spec.required then push(p, "required field missing")
				elseif spec.default ~= nil and value ~= nil then value[field] = spec.default end
			else
				if spec.type and typeName(v) ~= spec.type then
					push(p, "expected " .. spec.type .. ", got " .. typeName(v))
				end
				if spec.min and type(v) == "number" and v < spec.min then push(p, "must be >= " .. spec.min) end
				if spec.max and type(v) == "number" and v > spec.max then push(p, "must be <= " .. spec.max) end
				if spec.minLength and type(v) == "string" and #v < spec.minLength then push(p, "too short") end
				if spec.maxLength and type(v) == "string" and #v > spec.maxLength then push(p, "too long") end
				if spec.pattern and type(v) == "string" and not string.match(v, spec.pattern) then push(p, "pattern mismatch") end
				if spec.oneOf then
					local ok = false
					for _, a in ipairs(spec.oneOf) do if v == a then ok = true break end end
					if not ok then push(p, "value not in allowed set") end
				end
				if spec.of and type(v) == "table" then
					for i, item in ipairs(v) do
						local ok, sub = Validate.check(item, spec.of, p .. "[" .. i .. "]")
						if not ok then for _, s in ipairs(sub) do issues[#issues + 1] = s end end
					end
				end
				if spec.shape and type(v) == "table" then
					local ok, sub = Validate.check(v, spec.shape, p)
					if not ok then for _, s in ipairs(sub) do issues[#issues + 1] = s end end
				end
				if spec.validate then
					local ok, msg = spec.validate(v, value)
					if not ok then push(p, msg or "custom validation failed") end
				end
			end
		end
		return #issues == 0, issues
	end

	function Validate.assert(value, schema, source)
		local ok, issues = Validate.check(value, schema)
		if not ok then
			local msgs = {}
			for _, i in ipairs(issues) do msgs[#msgs + 1] = i.path .. ": " .. i.message end
			error(Errors.new(Errors.Codes.VALIDATION, table.concat(msgs, "; "), { source = source }))
		end
		return true
	end

	function Validate.sanitizeString(s, maxLen)
		s = tostring(s or "")
		s = string.gsub(s, "%c", "")
		if maxLen and #s > maxLen then s = string.sub(s, 1, maxLen) end
		return s
	end

	function Validate.clampNumber(v, lo, hi, fallback)
		if type(v) ~= "number" or v ~= v then return fallback or lo end
		if v < lo then return lo end
		if v > hi then return hi end
		return v
	end

	function Validate.isFiniteVector(v)
		if type(v) ~= "table" then return false end
		for _, k in ipairs({ "x", "y", "z" }) do
			local c = v[k]
			if type(c) ~= "number" or c ~= c or c == math.huge or c == -math.huge then return false end
		end
		return true
	end

	function Validate.schemaFor(name)
		local presets = {
			vector3 = { x = { type = "number", required = true }, y = { type = "number", required = true }, z = { type = "number", required = true } },
			color = { r = { type = "number", min = 0, max = 1 }, g = { type = "number", min = 0, max = 1 }, b = { type = "number", min = 0, max = 1 } },
			asset = { id = { type = "string", required = true, minLength = 1 }, kind = { type = "string", required = true }, version = { type = "number" } },
			project = { name = { type = "string", required = true }, engineVersion = { type = "string", required = true } },
		}
		return presets[name]
	end

	return Validate

end
