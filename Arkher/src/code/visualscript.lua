-- ARKHER CODE :: Visual Scripting
-- A typed node graph that both EXECUTES directly and COMPILES to real Luau source.
-- Ships a standard node library; games and the Singularity AI extend it at runtime.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local VisualScript = {}
	VisualScript.__index = VisualScript

	local function port(name, type_, required) return { name = name, type = type_, required = required } end

	function VisualScript.new(opts)
		opts = opts or {}
		local self = setmetatable({}, VisualScript)
		self.graph = Kits.nodegraph({})
		self.compiled = nil
		self:installLibrary()
		return self
	end

	function VisualScript:installLibrary()
		local g = self.graph
		g.defineType("Number", {
			inputs = {}, outputs = { port("out", "number") },
			fn = function(_, props) return { out = props.value or 0 } end,
			emit = function(id, _, props) return string.format("local v%d_out = %s", id, tostring(props.value or 0)) end,
		})
		g.defineType("String", {
			inputs = {}, outputs = { port("out", "string") },
			fn = function(_, props) return { out = props.value or "" } end,
			emit = function(id, _, props) return string.format("local v%d_out = %q", id, tostring(props.value or "")) end,
		})
		g.defineType("Add", {
			inputs = { port("a", "number", true), port("b", "number", true) }, outputs = { port("out", "number") },
			fn = function(inp) return { out = (inp.a or 0) + (inp.b or 0) } end,
			emit = function(id, args) return string.format("local v%d_out = (%s)", id, VisualScript.argExpr(args, "a", "0") .. " + " .. VisualScript.argExpr(args, "b", "0")) end,
		})
		g.defineType("Multiply", {
			inputs = { port("a", "number", true), port("b", "number", true) }, outputs = { port("out", "number") },
			fn = function(inp) return { out = (inp.a or 0) * (inp.b or 1) } end,
			emit = function(id, args) return string.format("local v%d_out = (%s)", id, VisualScript.argExpr(args, "a", "0") .. " * " .. VisualScript.argExpr(args, "b", "1")) end,
		})
		g.defineType("Clamp", {
			inputs = { port("value", "number", true), port("min", "number"), port("max", "number") },
			outputs = { port("out", "number") },
			fn = function(inp, props)
				local lo = inp.min or props.min or 0
				local hi = inp.max or props.max or 1
				return { out = math.max(lo, math.min(hi, inp.value or 0)) }
			end,
			emit = function(id, args, props) return string.format("local v%d_out = math.clamp and math.clamp(%s, %s, %s) or math.max(%s, math.min(%s, %s))",
				id, VisualScript.argExpr(args, "value", "0"), tostring(props.min or 0), tostring(props.max or 1),
				tostring(props.min or 0), tostring(props.max or 1), VisualScript.argExpr(args, "value", "0")) end,
		})
		g.defineType("Compare", {
			inputs = { port("a", "number", true), port("b", "number", true) }, outputs = { port("out", "boolean") },
			fn = function(inp, props)
				local op = props.op or ">"
				if op == ">" then return { out = (inp.a or 0) > (inp.b or 0) } end
				if op == "<" then return { out = (inp.a or 0) < (inp.b or 0) } end
				return { out = (inp.a or 0) == (inp.b or 0) }
			end,
			emit = function(id, args, props) return string.format("local v%d_out = (%s %s %s)", id,
				VisualScript.argExpr(args, "a", "0"), props.op or ">", VisualScript.argExpr(args, "b", "0")) end,
		})
		g.defineType("Branch", {
			inputs = { port("condition", "boolean", true), port("whenTrue", "any"), port("whenFalse", "any") },
			outputs = { port("out", "any") },
			fn = function(inp) if inp.condition then return { out = inp.whenTrue } end return { out = inp.whenFalse } end,
			emit = function(id, args) return string.format("local v%d_out = (%s) and (%s) or (%s)", id,
				VisualScript.argExpr(args, "condition", "false"), VisualScript.argExpr(args, "whenTrue", "nil"),
				VisualScript.argExpr(args, "whenFalse", "nil")) end,
		})
		g.defineType("Context", {
			inputs = {}, outputs = { port("out", "any") },
			fn = function(_, props, ctx) return { out = ctx[props.key or "value"] } end,
			emit = function(id, _, props) return string.format("local v%d_out = ctx[%q]", id, props.key or "value") end,
		})
		g.defineType("Print", {
			inputs = { port("value", "any", true) }, outputs = {},
			fn = function(inp) return { out = inp.value } end,
			emit = function(id, args) return string.format("print(%s) local v%d_out = nil", VisualScript.argExpr(args, "value", "nil"), id) end,
		})
		g.defineType("SetProperty", {
			inputs = { port("target", "any", true), port("value", "any", true) }, outputs = { port("out", "any") },
			fn = function(inp, props)
				if type(inp.target) == "table" and props.property then inp.target[props.property] = inp.value end
				return { out = inp.target }
			end,
			emit = function(id, args, props) return string.format("local v%d_out = %s; if v%d_out then v%d_out[%q] = %s end",
				id, VisualScript.argExpr(args, "target", "nil"), id, id, props.property or "Value",
				VisualScript.argExpr(args, "value", "nil")) end,
		})
		return self
	end

	function VisualScript.argExpr(args, name, fallback)
		for _, a in ipairs(args) do
			local key, expr = string.match(a, "^(%w+) = (.+)$")
			if key == name then return expr end
		end
		return fallback
	end

	function VisualScript:node(typeName, props) return self.graph.addNode(typeName, props) end
	function VisualScript:connect(a, ap, b, bp) return self.graph.connect(a, ap, b, bp) end
	function VisualScript:validate() return self.graph.validate() end
	function VisualScript:run(ctx) return self.graph.evaluate(ctx) end

	function VisualScript:compile(name)
		local src, err = self.graph.compile(name or "arkherGraph")
		if not src then return nil, err end
		self.compiled = src
		return src
	end

	-- verify the compiled Luau actually loads (real compilation check)
	function VisualScript:verifyCompiled()
		if not self.compiled then return false, "nothing compiled" end
		local chunk, err = load(self.compiled, "=arkher.visualscript")
		if not chunk then return false, err end
		return true
	end

	function VisualScript:nodeTypes()
		local out = {}
		for name in pairs(self.graph.types) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	function VisualScript:report()
		return { types = #self:nodeTypes(), stats = self.graph.stats(), compiledBytes = self.compiled and #self.compiled or 0 }
	end

	return VisualScript

end
