-- ARKHER :: ENGINE
-- The ARKHER runtime. Boots the UES kernel, binds a platform adapter, loads the
-- system catalog, wires D-O15 and drives the frame loop. This is the object a game,
-- the editor, or the Singularity AI talks to.
--@arkher-module
return function(A)
	local Engine = {}
	Engine.__index = Engine

	function Engine.boot(A, opts)
		opts = opts or {}
		local self = setmetatable({}, Engine)

		------------------------------------------------------------------ platform
		local Headless = A:import("arkher/platform/headless")
		local RobloxAdapter = A:import("arkher/platform/roblox")
		local AdapterSpec = A:import("arkher/platform/adapter")

		if opts.adapter then
			self.adapter = opts.adapter
		elseif RobloxAdapter.available() then
			self.adapter = RobloxAdapter.new()
		else
			self.adapter = Headless.new(opts.headless)
		end
		self.platform = self.adapter.kind
		local okAdapter, adapterErr = AdapterSpec.validate(self.adapter)
		self.adapterValid = okAdapter
		self.adapterError = adapterErr

		local timeFn = function() return self.adapter:now() end

		------------------------------------------------------------------ kernel
		self.loader = A
		self.version = A:import("arkher/kernel/version")
		self.log = A:import("arkher/kernel/log").new({ level = opts.logLevel or 30, timeFn = timeFn })
		self.clock = A:import("arkher/kernel/clock").new(timeFn)
		self.bus = A:import("arkher/kernel/eventbus").new({ maxQueue = opts.maxQueue or 8192 })
		self.scheduler = A:import("arkher/kernel/scheduler").new({ timeFn = timeFn, frameBudgetMs = opts.frameBudgetMs or 8 })
		self.jobs = A:import("arkher/kernel/jobsystem").new({ workers = opts.workers or 4, timeFn = timeFn })
		self.profiler = A:import("arkher/kernel/profiler").new({ timeFn = timeFn })
		self.world = A:import("arkher/kernel/ecs").new()
		self.services = A:import("arkher/kernel/service").new({ engine = self })
		self.resources = A:import("arkher/kernel/resource").new({ budgetBytes = opts.resourceBudget })
		self.config = A:import("arkher/kernel/config").new(opts.config or {})
		self.flags = A:import("arkher/kernel/config").flags()
		self.sandbox = A:import("arkher/security/sandbox").new()
		self.integrity = A:import("arkher/security/integrity").new()
		self.reflection = A:import("arkher/kernel/reflection")

		------------------------------------------------------------------ D-O15
		local Device = A:import("arkher/do15/device")
		local Controller = A:import("arkher/do15/controller")
		local Budget = A:import("arkher/do15/budget")
		local Bottleneck = A:import("arkher/do15/bottleneck")
		local LOD = A:import("arkher/do15/lod")

		self.deviceProfile = self.adapter:deviceProfile()
		self.device = Device.describe(self.deviceProfile)
		self.do15 = {
			controller = Controller.new({ targetFrameMs = self.device.budgets.frameMs }),
			budget = Budget.new({ frameMs = self.device.budgets.frameMs,
				drawCalls = self.device.budgets.drawCalls, parts = self.device.budgets.parts,
				memoryMB = self.device.budgets.memoryMB, npcs = self.device.budgets.npcs }),
			bottleneck = Bottleneck.new(),
			lod = LOD.new({ bias = self.device.quality.lodBias }),
			device = Device,
		}
		self.do15.controller:bindDevice(self.deviceProfile)
		self.quality = self.do15.controller:currentPreset()

		------------------------------------------------------------------ registries
		self.registry = {}          -- key -> live system instance
		self.systems = {}           -- ordered list of descriptors
		self.byCategory = {}
		self.frameCount = 0
		self.booted = false
		self.bootMs = 0
		self.errors = {}

		self.sandbox:createPrincipal("arkher.engine", { kind = "engine", trust = 1.0 })
		self.sandbox:applyRole("arkher.engine", "admin")

		self.log:info("engine", "ARKHER " .. self.version.CURRENT .. " booting on " .. self.platform)
		return self
	end

	-- Load the generated system catalog. Systems are instantiated lazily by category so a
	-- mobile client can boot only what it needs.
	function Engine:loadCatalog(categories)
		local t0 = self.adapter:now()
		local Index = self.loader:import("arkher/catalog/index")
		local loaded, failed = 0, 0
		for _, moduleId in ipairs(Index.modules) do
			local ok, sys = pcall(function() return self.loader:import(moduleId) end)
			if ok and type(sys) == "table" and sys.create then
				local wanted = true
				if categories then
					wanted = false
					for _, c in ipairs(categories) do if c == sys.category then wanted = true break end end
				end
				if wanted then
					local okInst, inst = pcall(sys.create, { engine = self })
					if okInst then
						self.registry[sys.key] = inst
						self.systems[#self.systems + 1] = sys
						self.byCategory[sys.category] = self.byCategory[sys.category] or {}
						table.insert(self.byCategory[sys.category], sys.key)
						if inst.integrate then pcall(inst.integrate, self) end
						loaded = loaded + 1
					else
						failed = failed + 1
						self.errors[#self.errors + 1] = { module = moduleId, error = tostring(inst) }
					end
				end
			else
				failed = failed + 1
				self.errors[#self.errors + 1] = { module = moduleId, error = tostring(sys) }
			end
		end
		self.bootMs = (self.adapter:now() - t0) * 1000
		self.booted = true
		self.log:info("engine", string.format("catalog loaded: %d systems (%d failed) in %.1f ms", loaded, failed, self.bootMs))
		self.bus:publish("arkher.engine.ready", { systems = loaded })
		return loaded, failed
	end

	function Engine:system(key) return self.registry[key] end

	function Engine:systemsIn(category)
		local out = {}
		for _, key in ipairs(self.byCategory[category] or {}) do out[#out + 1] = self.registry[key] end
		return out
	end

	function Engine:findSystems(pattern)
		local out = {}
		for key, inst in pairs(self.registry) do
			if string.find(key, pattern, 1, true) then out[#out + 1] = { key = key, instance = inst } end
		end
		table.sort(out, function(a, b) return a.key < b.key end)
		return out
	end

	-- Run every system's own self-test. This is how ARKHER proves its catalog is real.
	function Engine:verify(progressFn)
		local passed, failed = 0, 0
		local failures = {}
		local i = 0
		for key, inst in pairs(self.registry) do
			i = i + 1
			if inst.selfTest then
				local ok, err = inst.selfTest()
				if ok then passed = passed + 1
				else
					failed = failed + 1
					failures[#failures + 1] = { key = key, error = tostring(err) }
				end
			end
			if progressFn and i % 100 == 0 then progressFn(i) end
		end
		return { passed = passed, failed = failed, failures = failures, total = passed + failed }
	end

	function Engine:step(dt)
		dt = dt or self.clock:tick()
		self.frameCount = self.frameCount + 1
		self.profiler:beginFrame()
		self.do15.budget:beginFrame()
		self.sandbox:resetFrameQuotas()

		self.profiler:push("bus")
		self.bus:flush(self.quality and 512 or 256)
		self.profiler:pop()

		self.profiler:push("jobs")
		self.jobs:pump(2)
		self.profiler:pop()

		self.profiler:push("scheduler")
		self.scheduler:frame(dt, self)
		self.profiler:pop()

		self.profiler:push("resources")
		self.resources:pump(self.quality and 4 or 2)
		self.profiler:pop()

		local frameMs = self.profiler:endFrame()
		self.do15.controller:submitFrame(frameMs)
		if self.frameCount % 6 == 0 then
			self.do15.controller:step(dt * 6)
			self.quality = self.do15.controller:currentPreset()
			self.do15.lod.bias = self.quality.lodBias
			self.bus:post("arkher.do15.quality", self.quality)
		end
		return frameMs
	end

	function Engine:run(frames, dt)
		local total = 0
		for _ = 1, frames do total = total + (self:step(dt) or 0) end
		return total / math.max(1, frames)
	end

	function Engine:optimize()
		local stats = self.profiler:frameStats()
		local metrics = {
			frameMs = stats.avg > 0 and stats.avg or self.device.budgets.frameMs,
			p99Ms = stats.p99,
			scriptMs = stats.avg * 0.6,
			memoryMB = self.resources.usedBytes / (1024 * 1024),
			budgets = self.device.budgets,
		}
		local findings = self.do15.bottleneck:analyze(metrics)
		local plan = self.do15.bottleneck:plan(findings, 0.6)
		self.bus:publish("arkher.do15.plan", plan)
		return findings, plan
	end

	function Engine:report()
		local counts = {}
		for cat, list in pairs(self.byCategory) do counts[cat] = #list end
		return {
			engine = "ARKHER", version = self.version.CURRENT,
			generation = self.version.generationFor(self.version.CURRENT).name,
			platform = self.platform, device = self.device,
			systems = #self.systems, byCategory = counts,
			frames = self.frameCount, bootMs = self.bootMs,
			quality = self.quality, do15 = self.do15.controller:report(),
			profiler = self.profiler:frameStats(), errors = #self.errors,
			modulesLoaded = self.loader:loadedCount(),
		}
	end

	function Engine:shutdown()
		self.bus:publish("arkher.engine.shutdown", {})
		self.services:stopAll()
		self.booted = false
		return true
	end

	return Engine

end
