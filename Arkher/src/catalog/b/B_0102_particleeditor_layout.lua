-- ARKHER SYSTEM B.0102 :: Particle Editor Panel Layout
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: layout (dockable panel tree with persistence)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0102"
	S.key = "arkher.studio.particleeditor.panel_layout"
	S.name = "Particle Editor Panel Layout"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Particle Editor"
	S.aspect = "Panel Layout"
	S.kit = "layout"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.particleeditor.selection_model" }
	S.tags = { "b", "particleeditor", "layout", "studio" }
	S.description = "Particle Editor Panel Layout: dockable panel tree with persistence for the Particle Editor subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 240,
		baseWeight = 0.86,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 246,
		detailWeight = 0.46,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.23,
		regressionSlope = 0.08,
		saturation = 0.81,
		scale = 3.6
	}
	S.features = { "addPanel", "split", "dock", "focus", "setVisible", "visiblePanels", "save", "restore", "stats", "installDefault", "toggle", "panelIds", "workspacePreset", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("layout", { id = "arkher.studio.particleeditor.panel_layout", minRatio = 0.16 })
		inst.system = S
		inst.ctx = ctx

		function inst.installDefault()
			local ids = { "main", "side", "bottom" }
			for _, id in ipairs(ids) do
				if not inst.panels[id] then inst.addPanel(id, { title = S.name .. " " .. id }) end
			end
			inst.focus("main")
			return #ids
		end
		function inst.toggle(panelId)
			local p = inst.panels[panelId]
			if not p then return false end
			return inst.setVisible(panelId, not p.visible)
		end
		function inst.panelIds()
			local out = {}
			for id in pairs(inst.panels) do out[#out + 1] = id end
			table.sort(out)
			return out
		end
		function inst.workspacePreset(name)
			inst.installDefault()
			local focus = (name == "focus")
			inst.setVisible("side", not focus)
			inst.setVisible("bottom", not focus)
			return #inst.visiblePanels()
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
				engine.bus:subscribe("arkher.studio.particleeditor.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefault()
		local ok = #inst.panelIds() >= 3 and #inst.visiblePanels() >= 3
		local blob = inst.save()
		ok = ok and type(blob) == "string" and #blob > 2
		ok = ok and inst.workspacePreset("focus") == 1
		ok = ok and inst.toggle("side") and #inst.visiblePanels() == 2
		ok = ok and inst.workspacePreset("full") == 3
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
