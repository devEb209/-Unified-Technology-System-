-- ARKHER PLATFORM :: Roblox Adapter
-- The ONLY file in ARKHER allowed to touch Roblox APIs. Everything above this layer
-- is platform agnostic. All Roblox access is lazy so the module also loads headless.
--@arkher-module
return function(A)
	local Adapter = A:import("arkher/platform/adapter")
	local RobloxAdapter = {}
	RobloxAdapter.__index = RobloxAdapter

	local function svc(name)
		-- Normal global access only: Roblox host globals live behind the script
		-- environment metatable, so rawget(_G, "game") is nil on the real runtime.
		local g = _G.game or game or rawget(_G, "game")
		if not g then return nil end
		local ok, s = pcall(function() return g:GetService(name) end)
		if ok then return s end
		return nil
	end

	function RobloxAdapter.available()
		-- Roblox host globals (game, Instance) are only reachable through the script
		-- environment metatable: rawget(_G, ...) returns nil for them inside Roblox,
		-- which made V1.0.0 bind the HEADLESS adapter there and boot a zombie engine
		-- (frozen clock, no services, no real device profile). Probe with a normal
		-- global access instead - it resolves through the metatable on Roblox and
		-- still returns nil on a plain Lua host.
		local g = _G.game or game
		local inst = _G.Instance or Instance
		return (g ~= nil and g.GetService ~= nil) or (inst ~= nil and inst.new ~= nil)
	end

	function RobloxAdapter.new(opts)
		opts = opts or {}
		local self = setmetatable({}, RobloxAdapter)
		self.kind = "roblox"
		self.services = {
			RunService = svc("RunService"),
			Players = svc("Players"),
			Workspace = svc("Workspace"),
			Lighting = svc("Lighting"),
			ReplicatedStorage = svc("ReplicatedStorage"),
			UserInputService = svc("UserInputService"),
			TweenService = svc("TweenService"),
			HttpService = svc("HttpService"),
			CollectionService = svc("CollectionService"),
			SoundService = svc("SoundService"),
			ContentProvider = svc("ContentProvider"),
			PhysicsService = svc("PhysicsService"),
			Stats = svc("Stats"),
			GuiService = svc("GuiService"),
			VRService = svc("VRService"),
			Debris = svc("Debris"),
		}
		self.nodes = {}
		self.nextId = 1
		self.rootFolder = nil
		return self
	end

	function RobloxAdapter:ensureRoot(parent)
		local Instance_ = _G.Instance or Instance or rawget(_G, "Instance")
		local folder = Instance_.new("Folder")
		folder.Name = "ARKHER"
		folder.Parent = parent or self.services.ReplicatedStorage
		self.rootFolder = folder
		return folder
	end

	function RobloxAdapter:now()
		-- os is a Roblox global too: read it with a normal access, never rawget.
		local os_ = os or _G.os or rawget(_G, "os")
		if os_ and os_.clock then return os_.clock() end
		return 0
	end

	function RobloxAdapter:wait(seconds, fn)
		local task_ = _G.task or task or rawget(_G, "task")
		if task_ and task_.delay then return task_.delay(seconds, fn or function() end) end
		return nil
	end

	function RobloxAdapter:spawn(fn, ...)
		local task_ = _G.task or task or rawget(_G, "task")
		if task_ and task_.spawn then return task_.spawn(fn, ...) end
		local co = coroutine.create(fn)
		coroutine.resume(co, ...)
		return co
	end

	function RobloxAdapter:isServer() return self.services.RunService and self.services.RunService:IsServer() or false end
	function RobloxAdapter:isClient() return self.services.RunService and self.services.RunService:IsClient() or false end
	function RobloxAdapter:isStudio() return self.services.RunService and self.services.RunService:IsStudio() or false end

	function RobloxAdapter:createNode(className, name, parentId)
		local Instance_ = _G.Instance or Instance or rawget(_G, "Instance")
		local inst = Instance_.new(className)
		inst.Name = name or className
		local id = self.nextId
		self.nextId = id + 1
		self.nodes[id] = inst
		if parentId and self.nodes[parentId] then inst.Parent = self.nodes[parentId]
		else inst.Parent = self:ensureRoot() end
		return id
	end

	function RobloxAdapter:adopt(instance)
		local id = self.nextId
		self.nextId = id + 1
		self.nodes[id] = instance
		return id
	end

	function RobloxAdapter:instanceOf(id) return self.nodes[id] end

	function RobloxAdapter:destroyNode(id)
		local inst = self.nodes[id]
		if not inst then return false end
		inst:Destroy()
		self.nodes[id] = nil
		return true
	end

	function RobloxAdapter:setProperty(id, key, value)
		local inst = self.nodes[id]
		if not inst then return false end
		local ok = pcall(function() inst[key] = value end)
		return ok
	end

	function RobloxAdapter:getProperty(id, key)
		local inst = self.nodes[id]
		if not inst then return nil end
		local ok, v = pcall(function() return inst[key] end)
		if ok then return v end
		return nil
	end

	function RobloxAdapter:setParent(id, parentId)
		local inst = self.nodes[id]
		if not inst then return false end
		inst.Parent = parentId and self.nodes[parentId] or self:ensureRoot()
		return true
	end

	function RobloxAdapter:children(id)
		local inst = self.nodes[id]
		if not inst then return {} end
		local out = {}
		for _, c in ipairs(inst:GetChildren()) do out[#out + 1] = self:adopt(c) end
		return out
	end

	-- device classification straight from the live host, feeding D-O15
	function RobloxAdapter:deviceProfile()
		local ui = self.services.UserInputService
		local gui = self.services.GuiService
		local stats = self.services.Stats
		local touch = ui and ui.TouchEnabled or false
		local keyboard = ui and ui.KeyboardEnabled or false
		local gamepad = ui and ui.GamepadEnabled or false
		local vr = ui and ui.VREnabled or false
		local w, h = self:screenSize()
		local memoryMB = 2048
		if stats then
			local ok, v = pcall(function() return stats:GetTotalMemoryUsageMb() end)
			if ok and v then memoryMB = math.max(1024, v * 4) end
		end
		local class = "desktop"
		if vr then class = "vr"
		elseif touch and not keyboard then class = (w >= 1000 and "tablet" or "phone")
		elseif gamepad and not keyboard then class = "console" end
		local gpuTier = 2
		if class == "phone" then gpuTier = 1 elseif class == "console" or class == "vr" then gpuTier = 3 end
		return { class = class, memoryMB = memoryMB, cores = 4, gpuTier = gpuTier,
			screen = { width = w, height = h }, touch = touch, keyboard = keyboard,
			gamepad = gamepad, vr = vr, os = "roblox" }
	end

	function RobloxAdapter:screenSize()
		local ok, cam = pcall(function() return self.services.Workspace.CurrentCamera end)
		if ok and cam and cam.ViewportSize then return cam.ViewportSize.X, cam.ViewportSize.Y end
		return 1280, 720
	end

	function RobloxAdapter:inputKinds()
		local ui = self.services.UserInputService
		if not ui then return { keyboard = false, mouse = false, touch = false, gamepad = false, vr = false } end
		return { keyboard = ui.KeyboardEnabled, mouse = ui.MouseEnabled, touch = ui.TouchEnabled,
			gamepad = ui.GamepadEnabled, vr = ui.VREnabled }
	end

	function RobloxAdapter:log(level, message)
		if level == "ERROR" or level == "FATAL" then warn("[ARKHER] " .. tostring(message))
		else print("[ARKHER] " .. tostring(message)) end
	end

	function RobloxAdapter:capabilities() return Adapter.CAPABILITY_MATRIX.roblox end

	-- live frame stats used by the D-O15 controller
	function RobloxAdapter:frameStats()
		local stats = self.services.Stats
		local out = { fps = 60, memoryMB = 0, drawCalls = 0, instanceCount = 0 }
		if stats then
			pcall(function()
				out.memoryMB = stats:GetTotalMemoryUsageMb()
				out.instanceCount = stats.InstanceCount
				out.drawCalls = stats.RenderStepTime or 0
			end)
		end
		local rs = self.services.RunService
		if rs then
			pcall(function() out.fps = 1 / math.max(rs.Heartbeat:Wait(), 1e-4) end)
		end
		return out
	end

	function RobloxAdapter:onHeartbeat(fn)
		local rs = self.services.RunService
		if not rs then return nil end
		return rs.Heartbeat:Connect(fn)
	end
	function RobloxAdapter:onRenderStep(fn)
		local rs = self.services.RunService
		if not rs then return nil end
		if rs:IsClient() then return rs.RenderStepped:Connect(fn) end
		return rs.Heartbeat:Connect(fn)
	end
	function RobloxAdapter:onStepped(fn)
		local rs = self.services.RunService
		if not rs then return nil end
		return rs.Stepped:Connect(fn)
	end

	return RobloxAdapter

end
