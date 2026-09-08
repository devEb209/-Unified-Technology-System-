-- ARKHER V2 Continuum :: World Continuum
-- Infinite, seamless world built on continuum + sparse + multiscale + temporal kits.
-- The world is never bounded: chunks stream with hysteresis, sparse pages hold
-- distant data, multiscale picks fidelity per distance, temporal keeps the clock
-- continuous across sleeps, and coherence validates the whole thing.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Hash = A:import("arkher/kernel/hash")

	local WorldContinuum = {}
	WorldContinuum.__index = WorldContinuum

	function WorldContinuum.new(cfg)
		cfg = cfg or {}
		local self = setmetatable({}, WorldContinuum)
		self.id = cfg.id or "world.continuum"
		self.continuum = Kits.continuum({ id = self.id .. ".continuum", cellSize = cfg.cellSize or 128, radius = cfg.radius or 640 })
		self.sparse = Kits.sparse({ id = self.id .. ".sparse", capacity = cfg.sparseCap or 512, pageBytes = cfg.pageBytes or 8192 })
		self.multiscale = Kits.multiscale({ id = self.id .. ".multiscale", levels = cfg.levels or 5, baseTriangles = cfg.baseTriangles or 100000 })
		self.temporal = Kits.epoch({ id = self.id .. ".temporal", tickRate = cfg.tickRate or 20 })
		self.coherence = Kits.coherence({ id = self.id .. ".coherence", window = 64 })
		self.persistent = Kits.persistent({ id = self.id .. ".persistent", capacity = cfg.persistCap or 128 })
		self.objects = {} -- id -> { x, z, importance }
		self.checkpoints = {}
		return self
	end

	function WorldContinuum:registerObject(id, xOrPos, zOrOpts, importance)
		local x, z, imp
		if type(xOrPos) == "table" and xOrPos.x ~= nil then -- Vec
			x = xOrPos.x; z = xOrPos.z or xOrPos.y or 0
			local opts = zOrOpts
			imp = (opts and opts.importance) or opts and opts.lodBias or 1.0
			if type(importance) == "number" then imp = importance end
		else
			x = xOrPos or 0; z = zOrOpts or 0; imp = importance or 1.0
		end
		self.objects[id] = { x = x, z = z, importance = imp }
		-- seed sparse with a page for the object's cell
		local cell = self.continuum.cellOf(x, z)
		if not self.sparse.has(cell.key) then
			self.sparse.write(cell.key, { kind = "cell", x = cell.x, z = cell.z, seeded = true, bytes = 4096 })
		end
		return id
	end

	function WorldContinuum:removeObject(id)
		self.objects[id] = nil
		self.multiscale.selections[id] = nil
		return true
	end

	function WorldContinuum:step(viewX, viewZ, dt)
		dt = dt or 1/60
		self.temporal.advance(dt)
		self.continuum.update(viewX or 0, viewZ or 0)
		local pumped = self.continuum.pump(4)
		-- sparse residency: keep only loaded cells resident
		for k in pairs(self.sparse.pages) do
			if not self.continuum.isLoadedKey(k) and not self.sparse.pinned[k] then
				-- demote chance based on distance
			end
		end
		-- multiscale for every registered object
		local totalCost = 0
		for id, obj in pairs(self.objects) do
			local dx = obj.x - (viewX or 0)
			local dz = obj.z - (viewZ or 0)
			local dist = math.sqrt(dx*dx+dz*dz)
			local _, cost = self.multiscale.select(id, dist, 1.0, obj.importance)
			totalCost = totalCost + cost
		end
		local fits = self.multiscale.fits(800000)
		if not fits then self.multiscale.evictToBudget(600000) end
		-- coherence observation
		local score = self.coherence.observe({
			coherence = self.continuum.coherence,
			residency = self.sparse.residency(),
			seams = self.continuum.seams,
			loaded = self.continuum.loadedCount(),
			drift = self.temporal.drift(),
			cost = totalCost,
			budget = 800000
		})
		return { pumped = pumped, coherence = score, totalCost = totalCost, loaded = self.continuum.loadedCount() }
	end

	function WorldContinuum:checkpoint()
		local state = {
			loaded = self.continuum.loaded,
			pages = self.sparse.pages,
			objects = self.objects,
			epoch = self.temporal.epoch,
			selections = self.multiscale.selections
		}
		local cp = self.persistent.commit(nil, state, { t = self.temporal.time })
		cp.checksum = self:checksum()
		cp.epoch = cp.epoch -- keep epoch for restore
		self.checkpoints[#self.checkpoints+1] = cp
		return cp
	end

	function WorldContinuum:restore(arg)
		local epoch = arg
		if type(arg) == "table" and arg.epoch ~= nil then epoch = arg.epoch end
		if type(arg) == "table" and arg.state ~= nil then -- passed full snap
			-- direct restore from snapshot object
			self.continuum.loaded = arg.state.loaded or {}
			self.sparse.pages = arg.state.pages or {}
			self.objects = arg.state.objects or {}
			self.temporal.seek(arg.state.epoch or 0)
			self.multiscale.selections = arg.state.selections or {}
			return arg
		end
		local snap = self.persistent.get(epoch)
		if not snap then return nil end
		self.continuum.loaded = snap.state.loaded or {}
		self.sparse.pages = snap.state.pages or {}
		self.objects = snap.state.objects or {}
		self.temporal.seek(snap.state.epoch or 0)
		self.multiscale.selections = snap.state.selections or {}
		return snap
	end

	function WorldContinuum:loadedCount() return self.continuum.loadedCount() end
	function WorldContinuum:totalCost() return self.multiscale.totalCost() end

	function WorldContinuum:catchUp(targetEpoch)
		return self.temporal.catchUp(targetEpoch, function(ep)
			-- simulate one tick of offline progression: sparse pages decay, continuum would page
			if ep % 20 == 0 then self.sparse.compact() end
		end)
	end

	function WorldContinuum:checksum()
		return Hash.mix(self.continuum.checksum(), self.persistent.checksum())
	end

	function WorldContinuum:report()
		return {
			continuum = self.continuum.stats(),
			sparse = self.sparse.stats(),
			multiscale = self.multiscale.stats(),
			temporal = self.temporal.stats(),
			coherence = self.coherence.stats(),
			persistent = self.persistent.stats(),
			objects = 0 + (function() local n=0 for _ in pairs(self.objects) do n=n+1 end return n end)(),
			checksum = self:checksum(),
			epoch = self.temporal.epoch,
			budget = 800000
		}
	end

	return WorldContinuum
end
