-- ARKHER UI :: UI Framework
-- A mobile-first interface runtime: responsive layout with safe areas and breakpoints,
-- widgets bound to state, input actions that behave the same on touch, gamepad and
-- keyboard, tweened transitions, and accessibility audits that can fail a build.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")
	local Theme = A:import("arkher/ui/theme")

	local UI = {}
	UI.__index = UI

	function UI.new(opts)
		opts = opts or {}
		local self = setmetatable({}, UI)
		self.layout = Kits.create("flex", { id = "ui.layout",
			width = opts.width or 828, height = opts.height or 1792,
			safeArea = opts.safeArea })
		self.widgets = Kits.create("widget", { id = "ui.widgets",
			theme = opts.theme or Theme.DEFAULT, scale = opts.scale or 1 })
		self.input = Kits.create("inputmap", { id = "ui.input",
			device = opts.device or "touch" })
		self.tweens = Kits.create("tween", { id = "ui.tweens" })
		self.themeName = opts.theme or Theme.DEFAULT
		self.palette = Theme.get(self.themeName)
		self.screens = {}
		self.screenOrder = {}
		self.stack = {}
		self.state = {}
		self.nodeWidget = {}
		self.nodeAction = {}
		self.frame = 0
		self.time = 0
		self.interactions = 0
		self.onNavigate = Signal.new()
		self.onAction = Signal.new()
		return self
	end

	-- ------------------------------------------------------------------ screens
	function UI:defineScreen(name, builder)
		if self.screens[name] then return nil, "duplicate screen" end
		self.screens[name] = { name = name, builder = builder, built = false, root = nil }
		self.screenOrder[#self.screenOrder + 1] = name
		return self.screens[name]
	end

	function UI:buildScreen(name)
		local screen = self.screens[name]
		if not screen then return nil, "unknown screen" end
		if screen.built then return screen.root end
		local rootId = name .. ".root"
		self.layout.addNode(rootId, { direction = "column", padding = 12, gap = 8 })
		self.nodeWidget[rootId] = self.widgets.create("screen",
			{ name = name, background = self.palette.background })
		screen.root = rootId
		if screen.builder then screen.builder(self, rootId) end
		screen.built = true
		self.layout.solve()
		return rootId
	end

	function UI:push(name)
		local root = self:buildScreen(name)
		if not root then return false end
		for _, other in ipairs(self.stack) do
			self.layout.setVisible(self.screens[other].root, false)
		end
		self.stack[#self.stack + 1] = name
		self.layout.setVisible(root, true)
		self.tweens.create("screen." .. name .. "." .. #self.stack,
			{ from = 0, to = 1, duration = 0.22, easing = "quadOut" })
		self.onNavigate:fire({ screen = name, depth = #self.stack })
		self.layout.solve()
		return true
	end

	function UI:pop()
		if #self.stack <= 1 then return false end
		local top = table.remove(self.stack)
		self.layout.setVisible(self.screens[top].root, false)
		local below = self.stack[#self.stack]
		self.layout.setVisible(self.screens[below].root, true)
		self.onNavigate:fire({ screen = below, depth = #self.stack })
		self.layout.solve()
		return top
	end

	function UI:current() return self.stack[#self.stack] end

	-- ------------------------------------------------------------------ widgets
	function UI:panel(parent, id, opts)
		opts = opts or {}
		self.layout.addNode(id, { parent = parent, direction = opts.direction or "column",
			weight = opts.weight or 1, height = opts.height, width = opts.width,
			padding = opts.padding or 0, gap = opts.gap or 6,
			minHeight = opts.minHeight or 0, minWidth = opts.minWidth or 0 })
		self.nodeWidget[id] = self.widgets.create("panel",
			{ background = opts.background or self.palette.surface },
			self.nodeWidget[parent])
		return id
	end

	function UI:button(parent, id, label, action, opts)
		opts = opts or {}
		self.layout.addNode(id, { parent = parent, height = opts.height or 48,
			minHeight = 44, minWidth = 44, weight = 0 })
		self.nodeWidget[id] = self.widgets.create("button",
			{ text = label, action = action,
			  background = opts.background or self.palette.accent,
			  foreground = opts.foreground or self.palette.textStrong },
			self.nodeWidget[parent])
		if action and not self.input.actions[action] then
			self.input.bind(action, { keys = opts.keys or {}, buttons = opts.buttons or {} })
		end
		self.nodeAction[id] = action
		return id
	end

	function UI:label(parent, id, text, opts)
		opts = opts or {}
		self.layout.addNode(id, { parent = parent, height = opts.height or 24, weight = 0,
			minHeight = 16, minWidth = 16 })
		self.nodeWidget[id] = self.widgets.create("label",
			{ text = text, foreground = opts.foreground or self.palette.text },
			self.nodeWidget[parent])
		return id
	end

	-- Bind a widget property to a state key: set the key, the widget follows.
	function UI:bind(nodeId, prop, key, transform)
		local widgetId = self.nodeWidget[nodeId]
		if not widgetId then return false end
		local ui = self
		self.widgets.bind(widgetId, prop, function()
			local value = ui.state[key]
			if transform then return transform(value) end
			return value
		end)
		return true
	end

	function UI:set(key, value)
		self.state[key] = value
		return self.widgets.update()
	end

	function UI:propOf(nodeId, prop)
		local widgetId = self.nodeWidget[nodeId]
		if not widgetId then return nil end
		local node = self.widgets.nodes[widgetId]
		if not node then return nil end
		return node.props[prop]
	end

	-- ------------------------------------------------------------------ input
	function UI:tap(x, y)
		self.interactions = self.interactions + 1
		local hit = self.layout.hitTest(x, y)
		if not hit then return nil end
		local action = self.nodeAction[hit]
		if action then
			self.input.press(action)
			self.input.release(action)
			self.onAction:fire({ action = action, widget = hit })
		end
		return hit, action
	end

	function UI:setDevice(device)
		self.input.setDevice(device)
		if device == "gamepad" or device == "desktop" then
			self.layout.safeArea = { top = 16, bottom = 16, left = 16, right = 16 }
		end
		self.layout.solve()
		return device
	end

	function UI:setViewport(width, height, safeArea)
		local breakpoint = self.layout.setViewport(width, height, safeArea)
		self.layout.solve()
		return breakpoint
	end

	function UI:setTheme(name)
		self.themeName = name
		self.palette = Theme.get(name)
		for nodeId, widgetId in pairs(self.nodeWidget) do
			local node = self.widgets.nodes[widgetId]
			if node then
				if node.props.background then
					self.widgets.setProp(widgetId, "background",
						node.class == "button" and self.palette.accent or self.palette.surface)
				end
				if node.props.foreground then
					self.widgets.setProp(widgetId, "foreground", self.palette.text)
				end
			end
		end
		return self.palette.name
	end

	-- ------------------------------------------------------------------ frame
	function UI:update(dt)
		self.frame = self.frame + 1
		self.time = self.time + dt
		self.input.tick(dt)
		local finished = self.tweens.update(dt)
		local changed = self.widgets.update()
		return { frame = self.frame, tweens = self.tweens.activeCount(),
			finished = #finished, changed = changed }
	end

	function UI:run(seconds, dt)
		local step = dt or 1 / 60
		local n = math.max(1, math.floor(seconds / step))
		local last
		for _ = 1, n do last = self:update(step) end
		return last
	end

	function UI:render(emit) return self.widgets.render(emit) end

	-- ------------------------------------------------------------------ audits
	-- Mobile accessibility: every touch target must be at least 44 points.
	function UI:auditTouchTargets(minSize)
		self.layout.solve()
		return self.layout.touchTargetsBelow(minSize or 44)
	end

	function UI:auditContrast()
		local ok, failures = Theme.audit(self.themeName)
		return failures or {}, ok
	end

	function UI:applyQuality(q)
		q = Mathx.clamp(q, 0, 1)
		self.tweens.timeScale = Mathx.lerp(1.8, 1, q)
		self.layout.scale = Mathx.lerp(0.85, 1, q)
		return { timeScale = self.tweens.timeScale, scale = self.layout.scale }
	end

	function UI:report()
		return { screens = #self.screenOrder, depth = #self.stack, current = self:current(),
			nodes = self.layout.stats().nodes, breakpoint = self.layout.breakpoint(),
			device = self.input.stats().device, interactions = self.interactions,
			frame = self.frame, tweens = self.tweens.stats().tweens,
			theme = self.themeName }
	end

	return UI
end
