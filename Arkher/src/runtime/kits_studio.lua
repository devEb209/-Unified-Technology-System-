-- ARKHER RUNTIME :: Studio / Code / Collaboration Kits
-- Round 2 machinery. Same contract as runtime/kits.lua: each kit is a complete working
-- implementation that catalog systems specialize. Nothing here is Roblox specific.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")
	local Errors = A:import("arkher/kernel/errors")
	local Validate = A:import("arkher/kernel/validate")
	local Ser = A:import("arkher/kernel/serialize")
	local Hash = A:import("arkher/kernel/hash")
	local Reflection = A:import("arkher/kernel/reflection")

	local K = {}

	------------------------------------------------------------------ 21. DOCUMENT
	-- Transactional document model: fields, dirty tracking, validation, revisions.
	function K.document(cfg)
		local self = { kind = "document", id = cfg.id, data = cfg.initial or {}, schema = cfg.schema,
			revision = 0, dirty = {}, savedRevision = 0, onChange = Signal.new((cfg.id or "doc") .. ".change"),
			transaction = nil, history = {} }
		function self.get(path)
			local node = self.data
			for part in string.gmatch(path, "[^%.]+") do
				if type(node) ~= "table" then return nil end
				node = node[part]
			end
			return node
		end
		function self.set(path, value)
			local parts = {}
			for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = part end
			local node = self.data
			for i = 1, #parts - 1 do
				node[parts[i]] = node[parts[i]] or {}
				node = node[parts[i]]
			end
			local old = node[parts[#parts]]
			if old == value then return false end
			if self.transaction then self.transaction.changes[#self.transaction.changes + 1] = { path = path, old = old, new = value } end
			node[parts[#parts]] = value
			self.revision = self.revision + 1
			self.dirty[path] = true
			self.onChange:fire(path, value, old)
			return true
		end
		function self.begin(label)
			self.transaction = { label = label or "edit", changes = {}, snapshot = C.deepCopy(self.data) }
			return self.transaction
		end
		function self.commit()
			if not self.transaction then return false end
			local tx = self.transaction
			self.transaction = nil
			self.history[#self.history + 1] = { label = tx.label, changes = #tx.changes, revision = self.revision }
			return true, #tx.changes
		end
		function self.rollback()
			if not self.transaction then return false end
			self.data = self.transaction.snapshot
			self.transaction = nil
			self.revision = self.revision + 1
			return true
		end
		function self.validate()
			if not self.schema then return true, {} end
			return Validate.check(self.data, self.schema)
		end
		function self.isDirty() return next(self.dirty) ~= nil end
		function self.markSaved() self.dirty = {} self.savedRevision = self.revision return self.savedRevision end
		function self.serialize() return Ser.encodeBinary({ data = self.data, revision = self.revision }) end
		function self.deserialize(blob)
			local decoded = Ser.decodeBinary(blob)
			if not decoded then return false end
			self.data = decoded.data
			self.revision = decoded.revision or 0
			return true
		end
		function self.checksum() return Hash.crc32(Ser.encodeBinary(self.data)) end
		function self.stats() return { revision = self.revision, dirty = C.count(self.dirty),
			saved = self.savedRevision, transactions = #self.history } end
		return self
	end

	------------------------------------------------------------------ 22. COMMANDS (undo/redo)
	function K.commands(cfg)
		local self = { kind = "commands", limit = cfg.limit or 128, undoStack = {}, redoStack = {},
			executed = 0, undone = 0, redone = 0, coalesceWindow = cfg.coalesceWindow or 0.4,
			time = 0, group = nil, onExecute = Signal.new("commands.execute") }
		function self.execute(command)
			local ok, err = pcall(command.doFn)
			if not ok then return false, err end
			self.executed = self.executed + 1
			command.time = self.time
			if self.group then
				self.group.commands[#self.group.commands + 1] = command
			else
				local top = self.undoStack[#self.undoStack]
				if top and command.coalesceKey and top.coalesceKey == command.coalesceKey
					and (self.time - (top.time or 0)) <= self.coalesceWindow then
					top.undoFn = top.undoFn
					top.doFn = command.doFn
					top.time = self.time
				else
					self.undoStack[#self.undoStack + 1] = command
					if #self.undoStack > self.limit then table.remove(self.undoStack, 1) end
				end
			end
			self.redoStack = {}
			self.onExecute:fire(command.label)
			return true
		end
		function self.beginGroup(label) self.group = { label = label, commands = {} } return self.group end
		function self.endGroup()
			if not self.group then return false end
			local g = self.group
			self.group = nil
			if #g.commands == 0 then return false end
			self.undoStack[#self.undoStack + 1] = {
				label = g.label,
				doFn = function() for _, c in ipairs(g.commands) do c.doFn() end end,
				undoFn = function() for i = #g.commands, 1, -1 do g.commands[i].undoFn() end end,
			}
			return true, #g.commands
		end
		function self.undo()
			local cmd = table.remove(self.undoStack)
			if not cmd then return false end
			local ok = pcall(cmd.undoFn)
			if not ok then return false end
			self.redoStack[#self.redoStack + 1] = cmd
			self.undone = self.undone + 1
			return true, cmd.label
		end
		function self.redo()
			local cmd = table.remove(self.redoStack)
			if not cmd then return false end
			local ok = pcall(cmd.doFn)
			if not ok then return false end
			self.undoStack[#self.undoStack + 1] = cmd
			self.redone = self.redone + 1
			return true, cmd.label
		end
		function self.canUndo() return #self.undoStack > 0 end
		function self.canRedo() return #self.redoStack > 0 end
		function self.tick(dt) self.time = self.time + (dt or 0) end
		function self.historyLabels()
			local out = {}
			for i, c in ipairs(self.undoStack) do out[i] = c.label end
			return out
		end
		function self.clear() self.undoStack = {} self.redoStack = {} end
		function self.stats() return { undo = #self.undoStack, redo = #self.redoStack, executed = self.executed,
			undone = self.undone, redone = self.redone } end
		return self
	end

	------------------------------------------------------------------ 23. SELECTION
	function K.selection(cfg)
		local self = { kind = "selection", items = {}, order = {}, primary = nil, filters = {},
			onChange = Signal.new("selection.change"), maxItems = cfg.maxItems or 4096, changes = 0 }
		function self.contains(id) return self.items[id] == true end
		function self.add(id)
			if self.items[id] then return false end
			if #self.order >= self.maxItems then return false end
			self.items[id] = true
			self.order[#self.order + 1] = id
			self.primary = id
			self.changes = self.changes + 1
			self.onChange:fire("add", id)
			return true
		end
		function self.remove(id)
			if not self.items[id] then return false end
			self.items[id] = nil
			for i, x in ipairs(self.order) do if x == id then table.remove(self.order, i) break end end
			if self.primary == id then self.primary = self.order[#self.order] end
			self.changes = self.changes + 1
			self.onChange:fire("remove", id)
			return true
		end
		function self.toggle(id) if self.contains(id) then return self.remove(id) end return self.add(id) end
		function self.set(ids)
			self.items = {} self.order = {}
			for _, id in ipairs(ids) do self.add(id) end
			return #self.order
		end
		function self.clear()
			self.items = {} self.order = {} self.primary = nil
			self.changes = self.changes + 1
			self.onChange:fire("clear")
		end
		function self.all()
			local out = {}
			for i, id in ipairs(self.order) do out[i] = id end
			return out
		end
		function self.count() return #self.order end
		function self.addFilter(name, fn) self.filters[name] = fn end
		function self.filtered()
			local out = {}
			for _, id in ipairs(self.order) do
				local keep = true
				for _, fn in pairs(self.filters) do if not fn(id) then keep = false break end end
				if keep then out[#out + 1] = id end
			end
			return out
		end
		function self.stats() return { count = #self.order, primary = self.primary, changes = self.changes,
			filters = C.count(self.filters) } end
		return self
	end

	------------------------------------------------------------------ 24. LAYOUT (docking)
	function K.layout(cfg)
		local self = { kind = "layout", root = { id = "root", type = "split", orientation = "horizontal",
			ratio = 0.5, children = {} }, panels = {}, focused = nil, saved = nil,
			minRatio = cfg.minRatio or 0.1, operations = 0 }
		local function findNode(node, id)
			if node.id == id then return node end
			for _, child in ipairs(node.children or {}) do
				local hit = findNode(child, id)
				if hit then return hit end
			end
			return nil
		end
		function self.addPanel(id, opts)
			opts = opts or {}
			local panel = { id = id, type = "panel", title = opts.title or id, tabs = { id },
				activeTab = id, size = opts.size or 0.5, visible = true }
			self.panels[id] = panel
			local parent = opts.parent and findNode(self.root, opts.parent) or self.root
			table.insert(parent.children, panel)
			self.operations = self.operations + 1
			return panel
		end
		function self.split(panelId, orientation, newPanelId, ratio)
			local panel = self.panels[panelId]
			if not panel then return nil end
			local node = { id = panelId .. "|split", type = "split", orientation = orientation,
				ratio = Mathx.clamp(ratio or 0.5, self.minRatio, 1 - self.minRatio), children = {} }
			local function replace(parent)
				for i, child in ipairs(parent.children or {}) do
					if child == panel then
						parent.children[i] = node
						return true
					end
					if replace(child) then return true end
				end
				return false
			end
			replace(self.root)
			table.insert(node.children, panel)
			table.insert(node.children, self.addPanel(newPanelId, { parent = node.id }))
			self.operations = self.operations + 1
			return node
		end
		function self.dock(panelId, targetId)
			local panel = self.panels[panelId]
			local target = self.panels[targetId]
			if not panel or not target then return false end
			table.insert(target.tabs, panelId)
			target.activeTab = panelId
			panel.docked = targetId
			self.operations = self.operations + 1
			return true
		end
		function self.focus(panelId)
			if not self.panels[panelId] then return false end
			self.focused = panelId
			return true
		end
		function self.setVisible(panelId, visible)
			local p = self.panels[panelId]
			if not p then return false end
			p.visible = visible
			return true
		end
		function self.visiblePanels()
			local out = {}
			for id, p in pairs(self.panels) do if p.visible then out[#out + 1] = id end end
			table.sort(out)
			return out
		end
		function self.save() self.saved = Ser.encodeJSON({ panels = self.panels, focused = self.focused }) return self.saved end
		function self.restore(blob)
			local data = Ser.decodeJSON(blob or self.saved or "{}")
			if not data or not data.panels then return false end
			self.panels = data.panels
			self.focused = data.focused
			return true
		end
		function self.stats() return { panels = C.count(self.panels), visible = #self.visiblePanels(),
			focused = self.focused, operations = self.operations } end
		return self
	end

	------------------------------------------------------------------ 25. WIDGET (UI tree + binding)
	function K.widget(cfg)
		local self = { kind = "widget", nodes = {}, roots = {}, nextId = 1, bindings = {},
			dirty = {}, renders = 0, theme = cfg.theme or "dark", scale = cfg.scale or 1 }
		function self.create(class, props, parent)
			local id = self.nextId
			self.nextId = id + 1
			local node = { id = id, class = class, props = props or {}, children = {}, parent = parent }
			self.nodes[id] = node
			if parent and self.nodes[parent] then table.insert(self.nodes[parent].children, id)
			else self.roots[#self.roots + 1] = id end
			self.dirty[id] = true
			return id
		end
		function self.setProp(id, key, value)
			local node = self.nodes[id]
			if not node then return false end
			if node.props[key] == value then return false end
			node.props[key] = value
			self.dirty[id] = true
			return true
		end
		function self.bind(id, key, source)
			self.bindings[#self.bindings + 1] = { id = id, key = key, source = source }
			return #self.bindings
		end
		function self.update()
			local changed = 0
			for _, b in ipairs(self.bindings) do
				local value = b.source()
				if self.setProp(b.id, b.key, value) then changed = changed + 1 end
			end
			return changed
		end
		function self.render(emit)
			self.renders = self.renders + 1
			local painted = 0
			local function walk(id, depth)
				local node = self.nodes[id]
				if not node then return end
				if self.dirty[id] then
					if emit then emit(node, depth) end
					self.dirty[id] = nil
					painted = painted + 1
				end
				for _, child in ipairs(node.children) do walk(child, depth + 1) end
			end
			for _, root in ipairs(self.roots) do walk(root, 0) end
			return painted
		end
		function self.destroy(id)
			local node = self.nodes[id]
			if not node then return false end
			for _, child in ipairs({ table.unpack(node.children) }) do self.destroy(child) end
			self.nodes[id] = nil
			return true
		end
		function self.count() return C.count(self.nodes) end
		function self.stats() return { nodes = self.count(), dirty = C.count(self.dirty),
			bindings = #self.bindings, renders = self.renders, theme = self.theme } end
		return self
	end

	------------------------------------------------------------------ 26. INSPECTOR (reflection driven)
	function K.inspector(cfg)
		local self = { kind = "inspector", typeName = cfg.typeName, target = nil, edits = {},
			applied = 0, rejected = 0, multi = {} }
		function self.attach(target, typeName)
			self.target = target
			self.typeName = typeName or self.typeName or (type(target) == "table" and target.__type)
			self.edits = {}
			return self.typeName
		end
		function self.fields()
			if not self.typeName then return {} end
			return Reflection.fieldsOf(self.typeName)
		end
		function self.layout()
			if not self.typeName then return { groups = {} } end
			return Reflection.editorLayout(self.typeName)
		end
		function self.edit(field, value)
			local spec = nil
			for _, f in ipairs(self.fields()) do if f.name == field then spec = f break end end
			if not spec then self.rejected = self.rejected + 1 return false, "unknown field" end
			if spec.type == "number" and type(value) ~= "number" then self.rejected = self.rejected + 1 return false, "type" end
			if spec.min and value < spec.min then value = spec.min end
			if spec.max and value > spec.max then value = spec.max end
			self.edits[field] = value
			return true, value
		end
		function self.apply()
			if not self.target then return 0 end
			local n = 0
			for field, value in pairs(self.edits) do
				self.target[field] = value
				n = n + 1
			end
			self.edits = {}
			self.applied = self.applied + n
			return n
		end
		function self.revert() self.edits = {} return true end
		function self.multiSelect(targets)
			self.multi = targets
			local common = {}
			for _, f in ipairs(self.fields()) do
				local value, same = nil, true
				for i, t in ipairs(targets) do
					if i == 1 then value = t[f.name]
					elseif t[f.name] ~= value then same = false end
				end
				common[f.name] = same and value or "<mixed>"
			end
			return common
		end
		function self.applyToAll(field, value)
			local n = 0
			for _, t in ipairs(self.multi) do t[field] = value n = n + 1 end
			self.applied = self.applied + n
			return n
		end
		function self.stats() return { typeName = self.typeName, fields = #self.fields(),
			pendingEdits = C.count(self.edits), applied = self.applied, rejected = self.rejected } end
		return self
	end

	------------------------------------------------------------------ 27. NODEGRAPH (visual scripting)
	function K.nodegraph(cfg)
		local self = { kind = "nodegraph", nodes = {}, links = {}, nextId = 1, types = cfg.types or {},
			executions = 0, compiled = nil, errors = {} }
		function self.defineType(name, spec) self.types[name] = spec return self end
		function self.addNode(typeName, props)
			local spec = self.types[typeName]
			if not spec then return nil, "unknown node type: " .. tostring(typeName) end
			local id = self.nextId
			self.nextId = id + 1
			self.nodes[id] = { id = id, type = typeName, props = props or {},
				inputs = spec.inputs or {}, outputs = spec.outputs or {}, fn = spec.fn, emit = spec.emit }
			return id
		end
		function self.connect(fromNode, fromPort, toNode, toPort)
			local a, b = self.nodes[fromNode], self.nodes[toNode]
			if not a or not b then return false, "missing node" end
			local outType, inType
			for _, p in ipairs(a.outputs) do if p.name == fromPort then outType = p.type end end
			for _, p in ipairs(b.inputs) do if p.name == toPort then inType = p.type end end
			if not outType or not inType then return false, "missing port" end
			if outType ~= inType and outType ~= "any" and inType ~= "any" then
				return false, string.format("type mismatch %s -> %s", outType, inType)
			end
			for _, l in ipairs(self.links) do
				if l.toNode == toNode and l.toPort == toPort then return false, "input already connected" end
			end
			self.links[#self.links + 1] = { fromNode = fromNode, fromPort = fromPort, toNode = toNode, toPort = toPort }
			return true
		end
		function self.topoOrder()
			local indeg, order, ready = {}, {}, {}
			for id in pairs(self.nodes) do indeg[id] = 0 end
			for _, l in ipairs(self.links) do indeg[l.toNode] = (indeg[l.toNode] or 0) + 1 end
			for id, d in pairs(indeg) do if d == 0 then ready[#ready + 1] = id end end
			table.sort(ready)
			while #ready > 0 do
				local id = table.remove(ready, 1)
				order[#order + 1] = id
				for _, l in ipairs(self.links) do
					if l.fromNode == id then
						indeg[l.toNode] = indeg[l.toNode] - 1
						if indeg[l.toNode] == 0 then ready[#ready + 1] = l.toNode table.sort(ready) end
					end
				end
			end
			if #order ~= C.count(self.nodes) then return nil, "graph contains a cycle" end
			return order
		end
		function self.evaluate(context)
			self.executions = self.executions + 1
			local order, err = self.topoOrder()
			if not order then return nil, err end
			local values = {}
			for _, id in ipairs(order) do
				local node = self.nodes[id]
				local inputs = {}
				for _, l in ipairs(self.links) do
					if l.toNode == id then inputs[l.toPort] = values[l.fromNode .. ":" .. l.fromPort] end
				end
				if node.fn then
					local ok, out = pcall(node.fn, inputs, node.props, context or {})
					if not ok then return nil, "node " .. id .. " failed: " .. tostring(out) end
					if type(out) == "table" then
						for k, v in pairs(out) do values[id .. ":" .. k] = v end
					else
						values[id .. ":out"] = out
					end
				end
			end
			return values
		end
		-- compile the graph into real Luau source
		function self.compile(functionName)
			local order, err = self.topoOrder()
			if not order then return nil, err end
			local lines = { "-- generated by ARKHER Visual Scripting", "local function " .. (functionName or "graphMain") .. "(ctx)" }
			for _, id in ipairs(order) do
				local node = self.nodes[id]
				local args = {}
				for _, l in ipairs(self.links) do
					if l.toNode == id then args[#args + 1] = string.format("%s = v%d_%s", l.toPort, l.fromNode, l.fromPort) end
				end
				table.sort(args)
				local emit = node.emit
				if emit then
					lines[#lines + 1] = "\t" .. emit(id, args, node.props)
				else
					lines[#lines + 1] = string.format("\tlocal v%d_out = nil -- %s", id, node.type)
				end
			end
			lines[#lines + 1] = "\treturn true"
			lines[#lines + 1] = "end"
			lines[#lines + 1] = "return " .. (functionName or "graphMain")
			self.compiled = table.concat(lines, "\n")
			return self.compiled
		end
		function self.validate()
			self.errors = {}
			for id, node in pairs(self.nodes) do
				for _, p in ipairs(node.inputs) do
					if p.required then
						local connected = false
						for _, l in ipairs(self.links) do
							if l.toNode == id and l.toPort == p.name then connected = true break end
						end
						if not connected then
							self.errors[#self.errors + 1] = { node = id, port = p.name, issue = "required input not connected" }
						end
					end
				end
			end
			local _, cycleErr = self.topoOrder()
			if cycleErr then self.errors[#self.errors + 1] = { issue = cycleErr } end
			return #self.errors == 0, self.errors
		end
		function self.stats() return { nodes = C.count(self.nodes), links = #self.links,
			types = C.count(self.types), executions = self.executions, errors = #self.errors } end
		return self
	end

	------------------------------------------------------------------ 28. SOURCE (code intelligence)
	-- A real Luau-subset tokenizer + symbol extractor + diagnostics engine.
	function K.source(cfg)
		local KEYWORDS = { ["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["false"]=1,
			["for"]=1,["function"]=1,["if"]=1,["in"]=1,["local"]=1,["nil"]=1,["not"]=1,["or"]=1,
			["repeat"]=1,["return"]=1,["then"]=1,["true"]=1,["until"]=1,["while"]=1,["continue"]=1,["export"]=1,["type"]=1 }
		local self = { kind = "source", text = cfg.text or "", tokens = {}, symbols = {}, diagnostics = {},
			rules = {}, analyses = 0, keywords = KEYWORDS }
		function self.setText(text) self.text = text self.tokens = {} self.symbols = {} return #text end
		function self.tokenize()
			local tokens = {}
			local i = 1
			local line = 1
			local text = self.text
			while i <= #text do
				local c = string.sub(text, i, i)
				if c == "\n" then line = line + 1 i = i + 1
				elseif string.match(c, "%s") then i = i + 1
				elseif string.sub(text, i, i + 1) == "--" then
					local nl = string.find(text, "\n", i) or (#text + 1)
					tokens[#tokens + 1] = { type = "comment", value = string.sub(text, i, nl - 1), line = line }
					i = nl
				elseif c == '"' or c == "'" then
					local j = i + 1
					while j <= #text and string.sub(text, j, j) ~= c do
						if string.sub(text, j, j) == "\\" then j = j + 1 end
						j = j + 1
					end
					tokens[#tokens + 1] = { type = "string", value = string.sub(text, i, j), line = line }
					i = j + 1
				elseif string.match(c, "[%a_]") then
					local s, e = string.find(text, "^[%a_][%w_]*", i)
					local word = string.sub(text, s, e)
					tokens[#tokens + 1] = { type = KEYWORDS[word] and "keyword" or "identifier", value = word, line = line }
					i = e + 1
				elseif string.match(c, "%d") then
					local s, e = string.find(text, "^%d+%.?%d*", i)
					tokens[#tokens + 1] = { type = "number", value = string.sub(text, s, e), line = line }
					i = e + 1
				else
					tokens[#tokens + 1] = { type = "operator", value = c, line = line }
					i = i + 1
				end
			end
			self.tokens = tokens
			return tokens
		end
		function self.extractSymbols()
			if #self.tokens == 0 then self.tokenize() end
			local symbols = {}
			for idx, tok in ipairs(self.tokens) do
				if tok.type == "keyword" and tok.value == "function" then
					local nameParts = {}
					local j = idx + 1
					while self.tokens[j] and (self.tokens[j].type == "identifier" or
						(self.tokens[j].type == "operator" and (self.tokens[j].value == "." or self.tokens[j].value == ":"))) do
						nameParts[#nameParts + 1] = self.tokens[j].value
						j = j + 1
					end
					if #nameParts > 0 then
						symbols[#symbols + 1] = { kind = "function", name = table.concat(nameParts), line = tok.line }
					end
				elseif tok.type == "keyword" and tok.value == "local" then
					local nxt = self.tokens[idx + 1]
					if nxt and nxt.type == "identifier" then
						symbols[#symbols + 1] = { kind = "local", name = nxt.value, line = nxt.line }
					end
				end
			end
			self.symbols = symbols
			return symbols
		end
		function self.addRule(id, fn) self.rules[id] = fn return self end
		function self.analyze()
			self.analyses = self.analyses + 1
			if #self.tokens == 0 then self.tokenize() end
			if #self.symbols == 0 then self.extractSymbols() end
			self.diagnostics = {}
			-- built-in rules
			local depth = 0
			local maxDepth = 0
			for _, tok in ipairs(self.tokens) do
				if tok.type == "keyword" then
					if tok.value == "function" or tok.value == "if" or tok.value == "for" or tok.value == "while" or tok.value == "do" then
						depth = depth + 1
						if depth > maxDepth then maxDepth = depth end
					elseif tok.value == "end" then depth = depth - 1 end
				end
			end
			if depth ~= 0 then
				self.diagnostics[#self.diagnostics + 1] = { severity = "error", rule = "block-balance",
					message = "unbalanced block structure (" .. depth .. ")" }
			end
			if maxDepth > (cfg.maxNesting or 6) then
				self.diagnostics[#self.diagnostics + 1] = { severity = "warning", rule = "deep-nesting",
					message = "nesting depth " .. maxDepth .. " exceeds " .. (cfg.maxNesting or 6) }
			end
			local seen = {}
			for _, s in ipairs(self.symbols) do
				if s.kind == "function" then
					if seen[s.name] then
						self.diagnostics[#self.diagnostics + 1] = { severity = "warning", rule = "duplicate-function",
							message = "duplicate function " .. s.name, line = s.line }
					end
					seen[s.name] = true
				end
			end
			for id, fn in pairs(self.rules) do
				local ok, issues = pcall(fn, self)
				if ok and type(issues) == "table" then
					for _, iss in ipairs(issues) do
						iss.rule = iss.rule or id
						self.diagnostics[#self.diagnostics + 1] = iss
					end
				end
			end
			return self.diagnostics
		end
		function self.complete(prefix)
			if #self.symbols == 0 then self.extractSymbols() end
			local out = {}
			for _, s in ipairs(self.symbols) do
				if string.sub(s.name, 1, #prefix) == prefix then
					out[#out + 1] = { label = s.name, kind = s.kind, line = s.line }
				end
			end
			for word in pairs(self.keywords) do
				if string.sub(word, 1, #prefix) == prefix then out[#out + 1] = { label = word, kind = "keyword" } end
			end
			table.sort(out, function(a, b) return a.label < b.label end)
			return out
		end
		function self.metrics()
			if #self.tokens == 0 then self.tokenize() end
			local lines = 1
			for _ in string.gmatch(self.text, "\n") do lines = lines + 1 end
			local comments = 0
			local branches = 0
			for _, t in ipairs(self.tokens) do
				if t.type == "comment" then comments = comments + 1 end
				if t.type == "keyword" and (t.value == "if" or t.value == "elseif" or t.value == "for" or t.value == "while") then
					branches = branches + 1
				end
			end
			return { lines = lines, tokens = #self.tokens, comments = comments,
				complexity = 1 + branches, commentRatio = comments / math.max(1, lines),
				symbols = #self.symbols }
		end
		function self.rename(oldName, newName)
			local count = 0
			local out = string.gsub(self.text, "([%w_]+)", function(w)
				if w == oldName then count = count + 1 return newName end
				return w
			end)
			self.text = out
			self.tokens = {} self.symbols = {}
			return count, out
		end
		function self.stats() return { length = #self.text, tokens = #self.tokens, symbols = #self.symbols,
			diagnostics = #self.diagnostics, analyses = self.analyses } end
		return self
	end

	------------------------------------------------------------------ 29. SESSION (multi-user)
	function K.session(cfg)
		local self = { kind = "session", participants = {}, locks = {}, opLog = {}, cursor = 0,
			presence = {}, maxOps = cfg.maxOps or 4096, conflicts = 0, merges = 0,
			onOp = Signal.new("session.op") }
		function self.join(userId, role)
			self.participants[userId] = { id = userId, role = role or "editor", joinedAt = self.cursor, active = true }
			self.presence[userId] = { path = nil, updatedAt = self.cursor }
			return self.participants[userId]
		end
		function self.leave(userId)
			if not self.participants[userId] then return false end
			self.participants[userId].active = false
			for path, holder in pairs(self.locks) do
				if holder == userId then self.locks[path] = nil end
			end
			return true
		end
		function self.acquireLock(userId, path)
			if self.locks[path] and self.locks[path] ~= userId then return false, self.locks[path] end
			self.locks[path] = userId
			return true
		end
		function self.releaseLock(userId, path)
			if self.locks[path] ~= userId then return false end
			self.locks[path] = nil
			return true
		end
		function self.submit(userId, op)
			local p = self.participants[userId]
			if not p or not p.active then return false, "not a participant" end
			if p.role == "viewer" then return false, "read-only role" end
			local holder = self.locks[op.path]
			if holder and holder ~= userId then
				self.conflicts = self.conflicts + 1
				return false, "locked by " .. tostring(holder)
			end
			self.cursor = self.cursor + 1
			op.seq = self.cursor
			op.user = userId
			self.opLog[#self.opLog + 1] = op
			if #self.opLog > self.maxOps then table.remove(self.opLog, 1) end
			self.onOp:fire(op)
			return true, op.seq
		end
		-- operational transform: rebase a client op onto newer server ops on the same path
		function self.rebase(op, sinceSeq)
			local transformed = { path = op.path, value = op.value, kind = op.kind, base = sinceSeq }
			for _, applied in ipairs(self.opLog) do
				if applied.seq > sinceSeq and applied.path == op.path then
					if applied.kind == "delete" then return nil, "target deleted" end
					if applied.kind == "set" and op.kind == "set" then
						transformed.conflict = true
						transformed.theirs = applied.value
					end
				end
			end
			self.merges = self.merges + 1
			return transformed
		end
		function self.since(seq)
			local out = {}
			for _, op in ipairs(self.opLog) do if op.seq > seq then out[#out + 1] = op end end
			return out
		end
		function self.updatePresence(userId, path)
			if not self.presence[userId] then return false end
			self.presence[userId] = { path = path, updatedAt = self.cursor }
			return true
		end
		function self.activeUsers()
			local out = {}
			for id, p in pairs(self.participants) do if p.active then out[#out + 1] = id end end
			table.sort(out)
			return out
		end
		function self.stats() return { participants = C.count(self.participants), active = #self.activeUsers(),
			locks = C.count(self.locks), ops = #self.opLog, conflicts = self.conflicts, merges = self.merges } end
		return self
	end

	------------------------------------------------------------------ 30. MERGE (three-way)
	function K.merge(cfg)
		local self = { kind = "merge", strategy = cfg.strategy or "three-way", merges = 0,
			conflicts = {}, resolutions = {} }
		function self.diff(a, b) return Ser.diff(a, b) end
		function self.threeWay(base, ours, theirs)
			self.merges = self.merges + 1
			local result = C.deepCopy(base)
			local conflicts = {}
			local function walk(baseNode, ourNode, theirNode, target, path)
				local keys = {}
				for k in pairs(ourNode or {}) do keys[k] = true end
				for k in pairs(theirNode or {}) do keys[k] = true end
				for k in pairs(baseNode or {}) do keys[k] = true end
				for k in pairs(keys) do
					local p = path == "" and tostring(k) or (path .. "." .. tostring(k))
					local bv = baseNode and baseNode[k]
					local ov = ourNode and ourNode[k]
					local tv = theirNode and theirNode[k]
					if type(bv) == "table" or type(ov) == "table" or type(tv) == "table" then
						target[k] = type(target[k]) == "table" and target[k] or {}
						walk(type(bv) == "table" and bv or {}, type(ov) == "table" and ov or {},
							type(tv) == "table" and tv or {}, target[k], p)
					elseif ov == tv then
						target[k] = ov
					elseif ov == bv then
						target[k] = tv
					elseif tv == bv then
						target[k] = ov
					else
						conflicts[#conflicts + 1] = { path = p, base = bv, ours = ov, theirs = tv }
						target[k] = (self.strategy == "theirs") and tv or ov
					end
				end
			end
			walk(base, ours, theirs, result, "")
			self.conflicts = conflicts
			return result, conflicts
		end
		function self.resolve(path, choice)
			for i, c in ipairs(self.conflicts) do
				if c.path == path then
					self.resolutions[path] = choice
					table.remove(self.conflicts, i)
					return true, (choice == "theirs") and c.theirs or c.ours
				end
			end
			return false
		end
		function self.hasConflicts() return #self.conflicts > 0 end
		function self.conflictPaths()
			local out = {}
			for i, c in ipairs(self.conflicts) do out[i] = c.path end
			return out
		end
		function self.stats() return { strategy = self.strategy, merges = self.merges,
			conflicts = #self.conflicts, resolved = C.count(self.resolutions) } end
		return self
	end

	------------------------------------------------------------------ 31. TASKGRAPH (build system)
	function K.taskgraph(cfg)
		local self = { kind = "taskgraph", tasks = {}, order = nil, artifacts = {}, runs = 0,
			cacheHits = 0, failures = 0, incremental = cfg.incremental ~= false }
		function self.addTask(id, spec)
			self.tasks[id] = { id = id, deps = spec.deps or {}, fn = spec.fn, inputs = spec.inputs or {},
				outputs = spec.outputs or {}, hash = nil, lastResult = nil, state = "pending" }
			self.order = nil
			return self.tasks[id]
		end
		function self.resolveOrder()
			if self.order then return self.order end
			local indeg, ready, order = {}, {}, {}
			for id in pairs(self.tasks) do indeg[id] = #self.tasks[id].deps end
			for id, d in pairs(indeg) do if d == 0 then ready[#ready + 1] = id end end
			table.sort(ready)
			while #ready > 0 do
				local id = table.remove(ready, 1)
				order[#order + 1] = id
				for other, task in pairs(self.tasks) do
					for _, dep in ipairs(task.deps) do
						if dep == id then
							indeg[other] = indeg[other] - 1
							if indeg[other] == 0 then ready[#ready + 1] = other table.sort(ready) end
						end
					end
				end
			end
			if #order ~= C.count(self.tasks) then return nil, "cyclic build graph" end
			self.order = order
			return order
		end
		function self.inputHash(task)
			local payload = { inputs = task.inputs, deps = {} }
			for _, d in ipairs(task.deps) do payload.deps[d] = self.artifacts[d] and self.artifacts[d].hash or 0 end
			return Hash.hashTable(payload)
		end
		function self.run(only)
			self.runs = self.runs + 1
			local order, err = self.resolveOrder()
			if not order then return nil, err end
			local executed = {}
			for _, id in ipairs(order) do
				local task = self.tasks[id]
				local wanted = true
				if only then
					wanted = false
					for _, o in ipairs(only) do if o == id then wanted = true break end end
				end
				if wanted then
					local h = self.inputHash(task)
					if self.incremental and task.hash == h and task.state == "done" then
						self.cacheHits = self.cacheHits + 1
					else
						local ok, result = pcall(task.fn, self.artifacts)
						if ok then
							task.state = "done"
							task.hash = h
							task.lastResult = result
							self.artifacts[id] = { value = result, hash = h }
							executed[#executed + 1] = id
						else
							task.state = "failed"
							self.failures = self.failures + 1
							return executed, "task " .. id .. " failed: " .. tostring(result)
						end
					end
				end
			end
			return executed
		end
		function self.invalidate(id)
			local task = self.tasks[id]
			if not task then return false end
			task.hash = nil
			task.state = "pending"
			for other, t in pairs(self.tasks) do
				for _, dep in ipairs(t.deps) do
					if dep == id and t.state == "done" then t.state = "pending" t.hash = nil end
				end
			end
			return true
		end
		function self.artifact(id) local a = self.artifacts[id] return a and a.value or nil end
		function self.stats() return { tasks = C.count(self.tasks), runs = self.runs,
			cacheHits = self.cacheHits, failures = self.failures, artifacts = C.count(self.artifacts) } end
		return self
	end

	K.NAMES = { "document", "commands", "selection", "layout", "widget", "inspector",
		"nodegraph", "source", "session", "merge", "taskgraph" }

	return K

end
