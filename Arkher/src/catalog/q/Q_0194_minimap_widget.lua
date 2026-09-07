-- ARKHER SYSTEM Q.0194 :: Minimap Widget Tree
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: widget (retained widget nodes, properties, bindings and rendering)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0194"
	S.key = "arkher.ui.minimap.widget_tree"
	S.name = "Minimap Widget Tree"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Minimap"
	S.aspect = "Widget Tree"
	S.kit = "widget"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.minimap.responsive_layout" }
	S.tags = { "q", "minimap", "widget", "ui" }
	S.description = "Minimap Widget Tree: retained widget nodes, properties, bindings and rendering for the Minimap subsystem."
	S.params = {
		backlogLimit = 40,
		baseRadius = 160,
		baseWeight = 0.82,
		bias = 0.32,
		biasWeight = 0.17,
		ceiling = 144,
		detailWeight = 0.32,
		failureTolerance = 2,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.72,
		minThrottle = 0.16,
		regressionSlope = 0.11,
		saturation = 0.77,
		scale = 2.2
	}
	S.features = { "create", "setProp", "bind", "update", "render", "destroy", "count", "stats", "buildSurface", "setModel", "repaint", "tree", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("widget", { id = "arkher.ui.minimap.widget_tree", theme = "dark", scale = 1.07 })
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
				engine.bus:subscribe("arkher.ui.minimap.*", function(payload) inst.lastSignal = payload end)
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
