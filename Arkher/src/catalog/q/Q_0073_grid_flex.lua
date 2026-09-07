-- ARKHER SYSTEM Q.0073 :: Grid Responsive Layout
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: flex (flex solving with safe areas, weights and breakpoints)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0073"
	S.key = "arkher.ui.grid.responsive_layout"
	S.name = "Grid Responsive Layout"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Grid"
	S.aspect = "Responsive Layout"
	S.kit = "flex"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "q", "grid", "flex", "ui" }
	S.description = "Grid Responsive Layout: flex solving with safe areas, weights and breakpoints for the Grid subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 360,
		baseWeight = 0.63,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 533,
		detailWeight = 0.73,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.215,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 3.3
	}
	S.features = { "addNode", "setVisible", "setViewport", "breakpoint", "solve", "rectOf", "hitTest", "touchTargetsBelow", "depthOf", "stats", "installScreen", "layoutFor", "regionOf", "smallTargets", "collapse", "pick", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("flex", { id = "arkher.ui.grid.responsive_layout", width = 690, height = 1024, scale = 1.03 })
		inst.system = S
		inst.ctx = ctx

		function inst.installScreen()
			if inst.root then return #inst.order end
			inst.addNode("root", { direction = "column", padding = 8, gap = 8 })
			inst.addNode("header", { parent = "root", height = 56 })
			inst.addNode("body", { parent = "root", weight = 1 })
			inst.addNode("footer", { parent = "root", height = 72 })
			inst.solve()
			return #inst.order
		end
		function inst.layoutFor(width, height)
			inst.installScreen()
			inst.setViewport(width or inst.width, height or inst.height)
			inst.solve()
			return inst.breakpoint()
		end
		function inst.regionOf(id)
			inst.installScreen()
			return inst.rectOf(id or "body")
		end
		function inst.smallTargets(minSize)
			inst.installScreen()
			return inst.touchTargetsBelow(minSize or 44)
		end
		function inst.collapse(id)
			inst.installScreen()
			inst.setVisible(id or "header", false)
			inst.solve()
			return inst.rectOf("body")
		end
		function inst.pick(x, y)
			inst.installScreen()
			return inst.hitTest(x or inst.width * 0.5, y or inst.height * 0.5)
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
				engine.bus:subscribe("arkher.ui.grid.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installScreen() == 4
		local body = inst.regionOf("body")
		ok = ok and body ~= nil and body.height > 0 and body.width > 0
		ok = ok and inst.rectOf("root").y >= inst.safeArea.top
		ok = ok and inst.layoutFor(inst.width, inst.height) ~= nil
		ok = ok and inst.pick(inst.width * 0.5, inst.safeArea.top + 10) ~= nil
		local grown = inst.collapse("header")
		ok = ok and grown.height >= body.height
		ok = ok and type(inst.smallTargets(44)) == "table"
		return ok and inst.depthOf("body") == 1 and inst.stats().solves > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
