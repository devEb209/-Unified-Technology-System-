-- ARKHER KERNEL :: Type System + Reflection + Metadata
-- Runtime type descriptors powering the inspector, serializer, visual scripting,
-- AI tool-calling and automatic editor UI generation.
--@arkher-module
return function(A)
	local Reflection = {}
	Reflection.types = {}
	Reflection.metadata = {}

	function Reflection.defineType(name, spec)
		local t = {
			name = name,
			kind = spec.kind or "struct",
			fields = spec.fields or {},
			methods = spec.methods or {},
			base = spec.base,
			category = spec.category,
			description = spec.description,
			editor = spec.editor or {},
			serializable = spec.serializable ~= false,
		}
		Reflection.types[name] = t
		return t
	end

	function Reflection.getType(name) return Reflection.types[name] end

	function Reflection.fieldsOf(name)
		local t = Reflection.types[name]
		if not t then return {} end
		local out = {}
		if t.base then
			for _, f in ipairs(Reflection.fieldsOf(t.base)) do out[#out + 1] = f end
		end
		for fname, fspec in pairs(t.fields) do
			out[#out + 1] = { name = fname, type = fspec.type, default = fspec.default,
				min = fspec.min, max = fspec.max, editor = fspec.editor, description = fspec.description }
		end
		table.sort(out, function(a, b) return a.name < b.name end)
		return out
	end

	function Reflection.instantiate(name, overrides)
		local t = Reflection.types[name]
		if not t then return nil end
		local obj = { __type = name }
		for _, f in ipairs(Reflection.fieldsOf(name)) do
			obj[f.name] = f.default
		end
		for k, v in pairs(overrides or {}) do obj[k] = v end
		return obj
	end

	function Reflection.describe(obj)
		local tname = type(obj) == "table" and obj.__type or type(obj)
		local t = Reflection.types[tname]
		if not t then return { type = tname, fields = {} } end
		local out = { type = tname, category = t.category, description = t.description, fields = {} }
		for _, f in ipairs(Reflection.fieldsOf(tname)) do
			out.fields[#out.fields + 1] = { name = f.name, type = f.type, value = obj[f.name] }
		end
		return out
	end

	-- automatic editor descriptor: how the inspector should render this type
	function Reflection.editorLayout(name)
		local layout = { groups = {} }
		local groups = {}
		for _, f in ipairs(Reflection.fieldsOf(name)) do
			local g = (f.editor and f.editor.group) or "General"
			groups[g] = groups[g] or {}
			local widget = (f.editor and f.editor.widget) or
				(f.type == "number" and ((f.min and f.max) and "slider" or "number")) or
				(f.type == "boolean" and "toggle") or
				(f.type == "string" and "text") or
				(f.type == "vector3" and "vector") or
				(f.type == "color" and "color") or "generic"
			table.insert(groups[g], { name = f.name, widget = widget, min = f.min, max = f.max, type = f.type })
		end
		for g, fields in pairs(groups) do
			table.sort(fields, function(a, b) return a.name < b.name end)
			layout.groups[#layout.groups + 1] = { name = g, fields = fields }
		end
		table.sort(layout.groups, function(a, b) return a.name < b.name end)
		return layout
	end

	function Reflection.annotate(target, key, value)
		Reflection.metadata[target] = Reflection.metadata[target] or {}
		Reflection.metadata[target][key] = value
	end

	function Reflection.annotationsOf(target) return Reflection.metadata[target] or {} end

	function Reflection.methodsOf(obj)
		local out = {}
		local mt = getmetatable(obj)
		local src = (mt and mt.__index) or obj
		if type(src) == "table" then
			for k, v in pairs(src) do
				if type(v) == "function" and string.sub(k, 1, 1) ~= "_" then out[#out + 1] = k end
			end
		end
		table.sort(out)
		return out
	end

	function Reflection.count()
		local n = 0
		for _ in pairs(Reflection.types) do n = n + 1 end
		return n
	end

	-- convert any registered type into an AI tool schema (Singularity AI integration)
	function Reflection.toToolSchema(name)
		local t = Reflection.types[name]
		if not t then return nil end
		local props = {}
		for _, f in ipairs(Reflection.fieldsOf(name)) do
			props[f.name] = { type = f.type, description = f.description or f.name }
		end
		return { name = name, description = t.description or name, parameters = { type = "object", properties = props } }
	end

	return Reflection

end
