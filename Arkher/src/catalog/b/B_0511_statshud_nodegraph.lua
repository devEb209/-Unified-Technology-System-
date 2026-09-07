-- ARKHER SYSTEM B.0511 :: Statistics HUD Node Editor
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: nodegraph (typed node graph authoring and compilation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0511"
	S.key = "arkher.studio.statshud.node_editor"
	S.name = "Statistics HUD Node Editor"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Statistics HUD"
	S.aspect = "Node Editor"
	S.kit = "nodegraph"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.statshud.property_inspector" }
	S.tags = { "b", "statshud", "nodegraph", "studio" }
	S.description = "Statistics HUD Node Editor: typed node graph authoring and compilation for the Statistics HUD subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 240,
		baseWeight = 0.68,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 294,
		detailWeight = 0.58,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.14,
		regressionSlope = 0.14,
		saturation = 0.88,
		scale = 1.8
	}
	S.features = { "defineType", "addNode", "connect", "topoOrder", "evaluate", "compile", "validate", "stats", "installStdNodes", "buildDefault", "evaluateDefault", "compileDefault", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("nodegraph", { id = "arkher.studio.statshud.node_editor" })
		inst.system = S
		inst.ctx = ctx

		function inst.installStdNodes()
			if inst.types["Const"] then return inst end
			inst.defineType("Const", { inputs = {}, outputs = { { name = "out", type = "number" } },
				fn = function(_, props) return { out = props.value or 0 } end,
				emit = function(id, args, props) return string.format("local v%d_out = %.6f", id, props.value or 0) end })
			inst.defineType("Scale", { inputs = { { name = "a", type = "number", required = true } },
				outputs = { { name = "out", type = "number" } },
				fn = function(inputs, props) return { out = (inputs.a or 0) * (props.factor or 1) } end,
				emit = function(id, args, props)
					local src = "0"
					for _, arg in ipairs(args) do src = string.match(arg, "=%s*(.+)$") or src end
					return string.format("local v%d_out = (%s) * %.6f", id, src, props.factor or 1)
				end })
			inst.defineType("Sum", { inputs = { { name = "a", type = "number", required = true },
					{ name = "b", type = "number", required = true } },
				outputs = { { name = "out", type = "number" } },
				fn = function(inputs) return { out = (inputs.a or 0) + (inputs.b or 0) } end,
				emit = function(id, args)
					local parts = {}
					for _, arg in ipairs(args) do parts[#parts + 1] = string.match(arg, "=%s*(.+)$") or "0" end
					if #parts == 0 then parts[1] = "0" end
					return string.format("local v%d_out = %s", id, table.concat(parts, " + "))
				end })
			return inst
		end
		function inst.buildDefault()
			if inst.defaultGraph then return inst.defaultGraph end
			inst.installStdNodes()
			local a = inst.addNode("Const", { value = S.params.baseWeight })
			local b = inst.addNode("Const", { value = S.params.detailWeight })
			local scaled = inst.addNode("Scale", { factor = S.params.scale })
			local sum = inst.addNode("Sum", {})
			inst.connect(a, "out", scaled, "a")
			inst.connect(scaled, "out", sum, "a")
			inst.connect(b, "out", sum, "b")
			inst.defaultGraph = { a = a, b = b, scaled = scaled, sum = sum }
			return inst.defaultGraph
		end
		function inst.evaluateDefault()
			local ids = inst.buildDefault()
			local values, err = inst.evaluate({})
			if not values then return nil, err end
			return values[ids.sum .. ":out"]
		end
		function inst.compileDefault(name)
			inst.buildDefault()
			return inst.compile(name or "arkherGraph")
		end

		function inst.describe()
			return { id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return { system = S.key, status = status, stats = st }
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("arkher.studio.statshud.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local expected = S.params.baseWeight * S.params.scale + S.params.detailWeight
		local value = inst.evaluateDefault()
		local ok = type(value) == "number" and math.abs(value - expected) < 1e-6
		local src = inst.compileDefault("probeGraph")
		ok = ok and type(src) == "string" and string.find(src, "local v", 1, true) ~= nil
		ok = ok and inst.validate() and #inst.topoOrder() == 4
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
