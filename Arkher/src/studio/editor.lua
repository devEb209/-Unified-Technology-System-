-- ARKHER STUDIO :: Editor Runtime
-- The ARKHER IDE core: documents, selection, undo/redo, tools, panels, command palette,
-- inspector binding and editor automation. Runs inside Studio (via the plugin), inside a
-- running game (in-experience editing) and headless (automation / AI-driven editing).
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Viewport = A:import("arkher/studio/viewport")
	local Signal = A:import("arkher/kernel/signal")
	local Spatial = A:import("arkher/kernel/spatial")
	local Vec = A:import("arkher/kernel/vec")
	local Reflection = A:import("arkher/kernel/reflection")
	local Editor = {}
	Editor.__index = Editor

	function Editor.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Editor)
		self.document = Kits.document({ id = opts.projectName or "untitled", initial = opts.initial or
			{ meta = { name = opts.projectName or "untitled", engine = "ARKHER", version = "1.0.0" }, objects = {} } })
		self.commands = Kits.commands({ limit = opts.undoLimit or 256 })
		self.selection = Kits.selection({})
		self.layout = Kits.layout({})
		self.widgets = Kits.widget({ theme = opts.theme or "dark" })
		self.inspector = Kits.inspector({})
		self.viewport = Viewport.new(opts.viewport)
		self.palette = {}
		self.tools = {}
		self.activeTool = "select"
		self.onCommand = Signal.new("editor.command")
		self.onSave = Signal.new("editor.save")
		self.clipboard = nil
		self.stats = { commands = 0, objectsCreated = 0, objectsDeleted = 0, saves = 0 }
		self:installDefaultPanels()
		self:installDefaultCommands()
		self:installDefaultTools()
		return self
	end

	function Editor:installDefaultPanels()
		for _, id in ipairs({ "Viewport", "Hierarchy", "Inspector", "Assets", "Console",
			"Profiler", "Script", "VisualScript", "Terrain", "Materials", "Timeline", "AI" }) do
			self.layout.addPanel(id, { title = id })
		end
		self.layout.focus("Viewport")
		return self.layout.stats().panels
	end

	function Editor:registerCommand(id, spec)
		self.palette[id] = { id = id, title = spec.title or id, category = spec.category or "General",
			shortcut = spec.shortcut, run = spec.run, undo = spec.undo, description = spec.description }
		return self.palette[id]
	end

	function Editor:installDefaultCommands()
		local ed = self
		self:registerCommand("object.create", { title = "Create Object", category = "Edit",
			run = function(args) return ed:createObject(args) end })
		self:registerCommand("object.delete", { title = "Delete Selection", category = "Edit", shortcut = "Delete",
			run = function() return ed:deleteSelection() end })
		self:registerCommand("object.duplicate", { title = "Duplicate", category = "Edit", shortcut = "Ctrl+D",
			run = function() return ed:duplicateSelection() end })
		self:registerCommand("edit.undo", { title = "Undo", category = "Edit", shortcut = "Ctrl+Z",
			run = function() return ed.commands.undo() end })
		self:registerCommand("edit.redo", { title = "Redo", category = "Edit", shortcut = "Ctrl+Y",
			run = function() return ed.commands.redo() end })
		self:registerCommand("view.frame", { title = "Frame Selection", category = "View", shortcut = "F",
			run = function() return ed:frameSelection() end })
		self:registerCommand("edit.copy", { title = "Copy", category = "Edit", shortcut = "Ctrl+C",
			run = function() return ed:copy() end })
		self:registerCommand("edit.paste", { title = "Paste", category = "Edit", shortcut = "Ctrl+V",
			run = function() return ed:paste() end })
		self:registerCommand("project.save", { title = "Save Project", category = "File", shortcut = "Ctrl+S",
			run = function() return ed:save() end })
		self:registerCommand("select.all", { title = "Select All", category = "Select", shortcut = "Ctrl+A",
			run = function() return ed:selectAll() end })
		self:registerCommand("select.none", { title = "Deselect", category = "Select", shortcut = "Esc",
			run = function() ed.selection.clear() return true end })
		self:registerCommand("tool.translate", { title = "Translate Tool", category = "Tools", shortcut = "W",
			run = function() return ed:setTool("translate") end })
		self:registerCommand("tool.rotate", { title = "Rotate Tool", category = "Tools", shortcut = "E",
			run = function() return ed:setTool("rotate") end })
		self:registerCommand("tool.scale", { title = "Scale Tool", category = "Tools", shortcut = "R",
			run = function() return ed:setTool("scale") end })
		return #self:commandList()
	end

	function Editor:installDefaultTools()
		self.tools.select = { id = "select", cursor = "arrow" }
		self.tools.translate = { id = "translate", gizmo = "axes", snapKind = "translate" }
		self.tools.rotate = { id = "rotate", gizmo = "rings", snapKind = "rotate" }
		self.tools.scale = { id = "scale", gizmo = "boxes", snapKind = "scale" }
		self.tools.measure = { id = "measure", cursor = "cross" }
		self.tools.paint = { id = "paint", brush = { radius = 8, strength = 0.5 } }
		self.tools.sculpt = { id = "sculpt", brush = { radius = 16, strength = 0.4, falloff = "smooth" } }
		return self.tools
	end

	function Editor:setTool(id)
		if not self.tools[id] then return false end
		self.activeTool = id
		self.viewport:setMode(id == "select" and "select" or id)
		return true
	end

	function Editor:run(commandId, args)
		local cmd = self.palette[commandId]
		if not cmd then return nil, "unknown command: " .. tostring(commandId) end
		self.stats.commands = self.stats.commands + 1
		self.onCommand:fire(commandId, args)
		return cmd.run(args)
	end

	function Editor:commandList()
		local out = {}
		for id, c in pairs(self.palette) do out[#out + 1] = { id = id, title = c.title, category = c.category, shortcut = c.shortcut } end
		table.sort(out, function(a, b) return a.id < b.id end)
		return out
	end

	function Editor:searchCommands(query)
		local q = string.lower(query)
		local out = {}
		for _, c in ipairs(self:commandList()) do
			if string.find(string.lower(c.title), q, 1, true) or string.find(string.lower(c.id), q, 1, true) then
				out[#out + 1] = c
			end
		end
		return out
	end

	function Editor:createObject(args)
		args = args or {}
		local id = args.id or ("object_" .. tostring(self.stats.objectsCreated + 1))
		local data = { id = id, class = args.class or "ArkherPart", name = args.name or id,
			position = args.position or { 0, 0, 0 }, size = args.size or { 4, 1, 2 },
			rotation = args.rotation or { 0, 0, 0 }, material = args.material or "arkher.default" }
		local doc = self.document
		local ok = self.commands.execute({
			label = "Create " .. id,
			doFn = function() doc.set("objects." .. id, data) end,
			undoFn = function() doc.set("objects." .. id, nil) end,
		})
		if ok then
			self.stats.objectsCreated = self.stats.objectsCreated + 1
			self.selection.set({ id })
		end
		return ok and id or nil
	end

	function Editor:deleteSelection()
		local ids = self.selection.all()
		if #ids == 0 then return 0 end
		local doc = self.document
		local backup = {}
		for _, id in ipairs(ids) do backup[id] = doc.get("objects." .. id) end
		self.commands.execute({
			label = "Delete " .. #ids .. " object(s)",
			doFn = function() for _, id in ipairs(ids) do doc.set("objects." .. id, nil) end end,
			undoFn = function() for id, data in pairs(backup) do doc.set("objects." .. id, data) end end,
		})
		self.stats.objectsDeleted = self.stats.objectsDeleted + #ids
		self.selection.clear()
		return #ids
	end

	function Editor:duplicateSelection()
		local ids = self.selection.all()
		local created = {}
		for _, id in ipairs(ids) do
			local src = self.document.get("objects." .. id)
			if src then
				local copy = {}
				for k, v in pairs(src) do copy[k] = v end
				copy.id = id .. "_copy" .. tostring(self.stats.objectsCreated + 1)
				created[#created + 1] = self:createObject(copy)
			end
		end
		if #created > 0 then self.selection.set(created) end
		return created
	end

	function Editor:copy()
		local ids = self.selection.all()
		local buffer = {}
		for _, id in ipairs(ids) do buffer[#buffer + 1] = self.document.get("objects." .. id) end
		self.clipboard = buffer
		return #buffer
	end

	function Editor:paste()
		if not self.clipboard then return 0 end
		local created = {}
		for _, data in ipairs(self.clipboard) do
			local copy = {}
			for k, v in pairs(data) do copy[k] = v end
			copy.id = (data.id or "pasted") .. "_p" .. tostring(self.stats.objectsCreated + 1)
			created[#created + 1] = self:createObject(copy)
		end
		return #created
	end

	function Editor:selectAll()
		local objects = self.document.get("objects") or {}
		local ids = {}
		for id in pairs(objects) do ids[#ids + 1] = id end
		table.sort(ids)
		self.selection.set(ids)
		return #ids
	end

	function Editor:selectionBounds()
		local ids = self.selection.all()
		if #ids == 0 then return nil end
		local box = Spatial.aabb(Vec.vec3(math.huge, math.huge, math.huge), Vec.vec3(-math.huge, -math.huge, -math.huge))
		for _, id in ipairs(ids) do
			local o = self.document.get("objects." .. id)
			if o then
				local p = Vec.vec3(o.position[1], o.position[2], o.position[3])
				local s = Vec.vec3((o.size[1] or 1) / 2, (o.size[2] or 1) / 2, (o.size[3] or 1) / 2)
				box:expand(p - s)
				box:expand(p + s)
			end
		end
		return box
	end

	function Editor:frameSelection()
		local bounds = self:selectionBounds()
		if not bounds then return false end
		return self.viewport:frame(bounds)
	end

	function Editor:transformSelection(delta)
		local ids = self.selection.all()
		if #ids == 0 then return 0 end
		local doc = self.document
		local before = {}
		for _, id in ipairs(ids) do
			local o = doc.get("objects." .. id)
			if o then before[id] = { o.position[1], o.position[2], o.position[3] } end
		end
		self.commands.execute({
			label = "Transform " .. #ids,
			coalesceKey = "transform",
			doFn = function()
				for _, id in ipairs(ids) do
					local o = doc.get("objects." .. id)
					if o then
						o.position = { o.position[1] + delta.x, o.position[2] + delta.y, o.position[3] + delta.z }
						doc.set("objects." .. id .. ".dirty", true)
					end
				end
			end,
			undoFn = function()
				for id, pos in pairs(before) do
					local o = doc.get("objects." .. id)
					if o then o.position = pos end
				end
			end,
		})
		return #ids
	end

	function Editor:inspect(id)
		local obj = self.document.get("objects." .. id)
		if not obj then return nil end
		if not Reflection.getType("ArkherObject") then
			Reflection.defineType("ArkherObject", { category = "scene", description = "ARKHER scene object", fields = {
				name = { type = "string", default = "object", editor = { group = "Identity" } },
				class = { type = "string", default = "ArkherPart", editor = { group = "Identity" } },
				material = { type = "string", default = "arkher.default", editor = { group = "Appearance" } },
			} })
		end
		self.inspector.attach(obj, "ArkherObject")
		return self.inspector.layout()
	end

	function Editor:save()
		self.stats.saves = self.stats.saves + 1
		local blob = self.document.serialize()
		self.document.markSaved()
		self.onSave:fire(#blob)
		return blob
	end

	function Editor:load(blob)
		local ok = self.document.deserialize(blob)
		self.selection.clear()
		self.commands.clear()
		return ok
	end

	function Editor:objectCount()
		local objects = self.document.get("objects") or {}
		local n = 0
		for _ in pairs(objects) do n = n + 1 end
		return n
	end

	function Editor:report()
		return { project = self.document.get("meta.name"), objects = self:objectCount(),
			selection = self.selection.count(), tool = self.activeTool,
			commands = #self:commandList(), panels = self.layout.stats().panels,
			undo = self.commands.stats(), dirty = self.document.isDirty(),
			viewport = self.viewport:report(), stats = self.stats }
	end

	return Editor

end
