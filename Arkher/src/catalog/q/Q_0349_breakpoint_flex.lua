-- ARKHER SYSTEM Q.0349 :: Responsive Breakpoint Responsive Layout
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: flex (flex solving with safe areas, weights and breakpoints)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0349"
	S.key = "arkher.ui.breakpoint.responsive_layout"
	S.name = "Responsive Breakpoint Responsive Layout"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Responsive Breakpoint"
	S.aspect = "Responsive Layout"
	S.kit = "flex"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "q", "breakpoint", "flex", "ui" }
	S.description = "Responsive Breakpoint Responsive Layout: flex solving with safe areas, weights and breakpoints for the Responsive Breakpoint subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 400,
		baseWeight = 0.86,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 370,
		detailWeight = 0.26,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.13,
		regressionSlope = 0.08,
		saturation = 0.81,
		scale = 1.6
	}
	S.features = { "addNode", "setVisible", "setViewport", "breakpoint", "solve", "rectOf", "hitTest", "touchTargetsBelow", "depthOf", "stats", "installScreen", "layoutFor", "regionOf", "smallTargets", "collapse", "pick", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("flex", { id = "arkher.ui.breakpoint.responsive_layout", width = 390, height = 904, scale = 1.01 })
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
				engine.bus:subscribe("arkher.ui.breakpoint.*", function(payload) inst.lastSignal = payload end)
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
