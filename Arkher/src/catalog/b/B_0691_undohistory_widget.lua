-- ARKHER SYSTEM B.0691 :: Undo History Widget Surface
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: widget (retained-mode UI tree with data bindings)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0691"
	S.key = "arkher.studio.undohistory.widget_surface"
	S.name = "Undo History Widget Surface"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Undo History"
	S.aspect = "Widget Surface"
	S.kit = "widget"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.undohistory.panel_layout" }
	S.tags = { "b", "undohistory", "widget", "studio" }
	S.description = "Undo History Widget Surface: retained-mode UI tree with data bindings for the Undo History subsystem."
	S.params = {
		backlogLimit = 45,
		baseRadius = 360,
		baseWeight = 0.57,
		bias = 0.37,
		biasWeight = 0.22,
		ceiling = 573,
		detailWeight = 0.37,
		failureTolerance = 2,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.77,
		minThrottle = 0.185,
		regressionSlope = 0.135,
		saturation = 0.77,
		scale = 2.7
	}
	S.features = { "create", "setProp", "bind", "update", "render", "destroy", "count", "stats", "buildSurface", "setModel", "repaint", "tree", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("widget", { id = "arkher.studio.undohistory.widget_surface", theme = "highcontrast", scale = 0.82 })
		inst.system = S
		inst.ctx = ctx

		inst.model = { title = S.name, value = 0, status = "idle" }
		function inst.buildSurface()
			if inst.rootId then return inst.rootId end
			inst.rootId = inst.create("Frame", { name = S.key, scale = inst.scale })
			inst.titleId = inst.create("Label", { text = "" }, inst.rootId)
			inst.valueId = inst.create("Label", { text = "" }, inst.rootId)
			inst.bind(inst.titleId, "text", function() return inst.model.title end)
			inst.bind(inst.valueId, "text", function()
				return string.format("%s %.2f", tostring(inst.model.status), inst.model.value)
			end)
			return inst.rootId
		end
		function inst.setModel(key, value)
			inst.model[key] = value
			return inst.update()
		end
		function inst.repaint()
			inst.update()
			return inst.render()
		end
		function inst.tree()
			local out = {}
			for id, node in pairs(inst.nodes) do out[#out + 1] = { id = id, class = node.class } end
			table.sort(out, function(a, b) return a.id < b.id end)
			return out
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
				engine.bus:subscribe("arkher.studio.undohistory.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildSurface()
		local painted = inst.repaint()
		local ok = painted >= 3 and #inst.tree() >= 3
		ok = ok and inst.setModel("value", 12.5) >= 1
		ok = ok and inst.repaint() >= 1
		ok = ok and inst.repaint() == 0
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
