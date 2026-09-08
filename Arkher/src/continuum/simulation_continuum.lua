-- ARKHER V2 Continuum :: Simulation Continuum
-- Persistent, multiscale simulation that never stops: ecology, economy, society
-- and weather stepped through the temporal kit, with sparse residency, coherence
-- checks, and delta checkpoints that survive offline gaps.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Hash = A:import("arkher/kernel/hash")

	local SimContinuum = {}
	SimContinuum.__index = SimContinuum

	function SimContinuum.new(cfg)
		cfg = cfg or {}
		local self = setmetatable({}, SimContinuum)
		self.id = cfg.id or "sim.continuum"
		self.temporal = Kits.epoch({ id = self.id .. ".temporal", tickRate = cfg.tickRate or 10 })
		self.sparse = Kits.sparse({ id = self.id .. ".sparse", capacity = cfg.sparseCap or 256 })
		self.multiscale = Kits.multiscale({ id = self.id .. ".multiscale", levels = cfg.levels or 4, baseTriangles = 40000 })
		self.persistent = Kits.persistent({ id = self.id .. ".persistent", capacity = 128 })
		self.coherence = Kits.coherence({ id = self.id .. ".coherence" })
		self.continuum = Kits.continuum({ id = self.id .. ".continuum", cellSize = cfg.cellSize or 256, radius = cfg.radius or 1200 })
		-- domain clocks
		self.domains = {}
		self.order = {}
		self.epoch = 0
		self.statsLog = {}
		return self
	end

	function SimContinuum:addDomain(name, cfg)
		cfg = cfg or {}
		self.domains[name] = { hz = cfg.hz or 5, cost = cfg.cost or 1, priority = cfg.priority or 1, state = cfg.initial or { value = 0 }, stepFn = cfg.stepFn }
		if not self.order then self.order = {} end
		self.order[#self.order+1]=name
		return name
	end

	function SimContinuum:installDefaults()
		self:addDomain("ecology", { hz = 4, cost = 2, priority = 2, initial = { population = 100, carrying = 500 } , stepFn = function(s) s.population = Mathx.clamp(s.population + (s.carrying - s.population)*0.04 + (math.random()-0.5)*2, 0, s.carrying) end })
		self:addDomain("economy", { hz = 8, cost = 2, priority = 3, initial = { wealth = 50, flow = 1.2 }, stepFn = function(s) s.wealth = s.wealth + s.flow - s.wealth*0.01 end })
		self:addDomain("society", { hz = 2, cost = 1, priority = 1, initial = { cohesion = 0.72, unrest = 0.08 }, stepFn = function(s) s.cohesion = Mathx.clamp(s.cohesion + (0.02 - s.unrest*0.1)*0.05, 0, 1) end })
		self:addDomain("weather", { hz = 12, cost = 1, priority = 2, initial = { temp = 18, humidity = 0.55 }, stepFn = function(s) s.temp = s.temp + math.sin(s.temp*0.01)*0.2 end })
		return 4
	end

	function SimContinuum:step(dt, budget)
		budget = budget or 6
		self.temporal.advance(dt or 1/10)
		self.continuum.update(0, 0)
		self.continuum.pump(2)
		local spent = 0
		local order = {}
		for name, d in pairs(self.domains) do order[#order+1] = { name = name, d = d } end
		table.sort(order, function(a,b) return a.d.priority > b.d.priority end)
		for _, item in ipairs(order) do
			if spent + item.d.cost > budget then break end
			-- hz gating: run only if enough epochs passed
			local period = math.max(1, math.floor(10 / item.d.hz))
			if self.temporal.epoch % period == 0 then
				if item.d.stepFn then pcall(item.d.stepFn, item.d.state) end
				spent = spent + item.d.cost
			end
		end
		-- multiscale for regions
		local totalCost = 0
		for name, d in pairs(self.domains) do
			local lvl = self.multiscale.levelFor(math.random()*600, 1.0)
			totalCost = totalCost + self.multiscale.costAt(lvl)
		end
		local score = self.coherence.observe({ coherence = 1 - math.abs(totalCost - 90000)/90000, drift = self.temporal.drift(), cost = spent, budget = budget })
		self.epoch = self.temporal.epoch
		self.statsLog[#self.statsLog+1] = { epoch = self.epoch, spent = spent, cost = totalCost, coherence = score }
		if #self.statsLog > 256 then table.remove(self.statsLog, 1) end
		return { spent = spent, coherence = score, epoch = self.epoch }
	end

	function SimContinuum:checkpoint()
		local state = {}
		for name, d in pairs(self.domains) do state[name] = d.state end
		state._continuum = { loaded = self.continuum.loadedCount(), sparse = self.sparse.stats() }
		return self.persistent.commit(nil, state, { epoch = self.epoch })
	end

	function SimContinuum:restore(arg)
		local epoch = arg
		if type(arg)=="table" and arg.epoch ~= nil then epoch = arg.epoch end
		local snap = self.persistent.get(epoch)
		if not snap and type(arg)=="table" and arg.state then snap = arg end
		if not snap then return nil end
		for name, s in pairs(snap.state) do if self.domains[name] then self.domains[name].state = s end end
		return snap
	end

	function SimContinuum:catchUp(seconds)
		local target = self.temporal.epoch + math.floor((seconds or 1) * self.temporal.tickRate)
		return self.temporal.catchUp(target, function(ep)
			self:step(1/self.temporal.tickRate, 6)
		end)
	end

	function SimContinuum:checksum()
		local acc = 0
		for name, d in pairs(self.domains) do
			acc = Hash.mix(acc, Hash.hashTable(d.state or {}))
		end
		return Hash.mix(acc, self.persistent.checksum())
	end

	function SimContinuum:report()
		local count = (function() local n=0 for _ in pairs(self.domains) do n=n+1 end return n end)()
		return {
			domains = self.domains,
			domainCount = count,
			epoch = self.epoch,
			temporal = self.temporal.stats(),
			coherence = self.coherence.stats(),
			persistent = self.persistent.stats(),
			continuum = self.continuum.stats(),
			sparse = self.sparse.stats(),
			checksum = self:checksum()
		}
	end
	function SimContinuum:domainCount() return (function() local n=0 for _ in pairs(self.domains) do n=n+1 end return n end)() end

	return SimContinuum
end
