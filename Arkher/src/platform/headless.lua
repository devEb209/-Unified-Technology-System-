-- ARKHER PLATFORM :: Headless Adapter
-- A complete virtual host implementing the ARKHER platform interface with an
-- in-memory node tree. Used for automated tests, CI, server simulation and the
-- deterministic replay of editor sessions without Roblox.
--@arkher-module
return function(A)
	local Adapter = A:import("arkher/platform/adapter")
	local Headless = {}
	Headless.__index = Headless

	function Headless.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Headless)
		self.kind = "headless"
		self.t = 0
		self.nodes = {}
		self.nextId = 1
		self.root = nil
		self.logs = {}
		self.tasks = {}
		self.device = opts.device or {
			class = "virtual", memoryMB = 4096, cores = 4, gpuTier = 2,
			screen = { width = 1280, height = 720 }, touch = false, os = "virtual",
		}
		self.root = self:createNode("Folder", "ArkherRoot", nil)
		return self
	end

	function Headless:now() return self.t end
	function Headless:advance(dt)
		self.t = self.t + dt
		local due = {}
		for i = #self.tasks, 1, -1 do
			if self.tasks[i].at <= self.t then
				due[#due + 1] = table.remove(self.tasks, i)
			end
		end
		for _, task in ipairs(due) do pcall(task.fn) end
		return #due
	end
	function Headless:wait(seconds, fn) self.tasks[#self.tasks + 1] = { at = self.t + seconds, fn = fn or function() end } end
	function Headless:spawn(fn, ...) local co = coroutine.create(fn) coroutine.resume(co, ...) return co end
	function Headless:isServer() return true end
	function Headless:isClient() return false end
	function Headless:isStudio() return false end

	function Headless:createNode(className, name, parent)
		local id = self.nextId
		self.nextId = id + 1
		local node = { id = id, className = className, name = name or className, props = {}, childIds = {}, parentId = parent }
		self.nodes[id] = node
		if parent and self.nodes[parent] then table.insert(self.nodes[parent].childIds, id) end
		return id
	end
	function Headless:destroyNode(id)
		local node = self.nodes[id]
		if not node then return false end
		for _, c in ipairs({ table.unpack(node.childIds) }) do self:destroyNode(c) end
		if node.parentId and self.nodes[node.parentId] then
			local siblings = self.nodes[node.parentId].childIds
			for i, c in ipairs(siblings) do if c == id then table.remove(siblings, i) break end end
		end
		self.nodes[id] = nil
		return true
	end
	function Headless:setProperty(id, key, value)
		local node = self.nodes[id]
		if not node then return false end
		node.props[key] = value
		return true
	end
	function Headless:getProperty(id, key)
		local node = self.nodes[id]
		if not node then return nil end
		if key == "Name" then return node.name end
		if key == "ClassName" then return node.className end
		return node.props[key]
	end
	function Headless:setParent(id, parentId)
		local node = self.nodes[id]
		if not node then return false end
		if node.parentId and self.nodes[node.parentId] then
			local siblings = self.nodes[node.parentId].childIds
			for i, c in ipairs(siblings) do if c == id then table.remove(siblings, i) break end end
		end
		node.parentId = parentId
		if parentId and self.nodes[parentId] then table.insert(self.nodes[parentId].childIds, id) end
		return true
	end
	function Headless:children(id)
		local node = self.nodes[id]
		if not node then return {} end
		return node.childIds
	end
	function Headless:nodeCount()
		local n = 0
		for _ in pairs(self.nodes) do n = n + 1 end
		return n
	end
	function Headless:findByName(name)
		for id, node in pairs(self.nodes) do if node.name == name then return id end end
		return nil
	end
	function Headless:deviceProfile() return self.device end
	function Headless:screenSize() return self.device.screen.width, self.device.screen.height end
	function Headless:inputKinds() return { keyboard = true, mouse = true, touch = self.device.touch, gamepad = false, vr = false } end
	function Headless:log(level, message) self.logs[#self.logs + 1] = { level = level, message = message, t = self.t } end
	function Headless:capabilities() return Adapter.CAPABILITY_MATRIX.headless end

	function Headless:tree(id, depth, out)
		id = id or self.root
		depth = depth or 0
		out = out or {}
		local node = self.nodes[id]
		if not node then return out end
		out[#out + 1] = string.rep("  ", depth) .. node.className .. " '" .. node.name .. "'"
		for _, c in ipairs(node.childIds) do self:tree(c, depth + 1, out) end
		return out
	end

	return Headless

end
