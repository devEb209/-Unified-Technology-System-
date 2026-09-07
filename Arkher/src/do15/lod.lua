-- ARKHER D-O15 :: LOD, Culling and Simulation Scaling
-- Distance/importance/screen-coverage driven level of detail for geometry, animation,
-- AI and simulation. Everything in ARKHER can be simulated at reduced fidelity
-- instead of being turned off - that is what keeps worlds alive on a phone.
--@arkher-module
return function(A)
	local Mathx = A:import("arkher/kernel/mathx")
	local LOD = {}
	LOD.__index = LOD

	LOD.BANDS = {
		{ id = 0, name = "hero",       maxDistance = 40,   quality = 1.00, tickRate = 60, shadow = true,  animation = "full" },
		{ id = 1, name = "near",       maxDistance = 110,  quality = 0.80, tickRate = 30, shadow = true,  animation = "full" },
		{ id = 2, name = "mid",        maxDistance = 260,  quality = 0.55, tickRate = 15, shadow = false, animation = "reduced" },
		{ id = 3, name = "far",        maxDistance = 600,  quality = 0.30, tickRate = 6,  shadow = false, animation = "pose-only" },
		{ id = 4, name = "impostor",   maxDistance = 1400, quality = 0.12, tickRate = 2,  shadow = false, animation = "none" },
		{ id = 5, name = "statistical",maxDistance = math.huge, quality = 0.03, tickRate = 0.2, shadow = false, animation = "none" },
	}

	function LOD.new(opts)
		opts = opts or {}
		local self = setmetatable({}, LOD)
		self.bias = opts.bias or 1.0
		self.hysteresis = opts.hysteresis or 0.12
		self.assignments = {}
		self.counts = {}
		self.transitions = 0
		return self
	end

	function LOD:bandFor(distance, importance, screenCoverage)
		local d = distance / math.max(0.05, self.bias)
		d = d / math.max(0.25, importance or 1)
		if screenCoverage and screenCoverage > 0.25 then d = d * 0.5 end
		for _, band in ipairs(LOD.BANDS) do
			if d <= band.maxDistance then return band end
		end
		return LOD.BANDS[#LOD.BANDS]
	end

	function LOD:assign(id, distance, importance, screenCoverage)
		local band = self:bandFor(distance, importance, screenCoverage)
		local prev = self.assignments[id]
		if prev and prev.band.id ~= band.id then
			-- hysteresis band: require crossing the threshold by a margin to switch
			local threshold = LOD.BANDS[math.min(#LOD.BANDS, math.max(1, prev.band.id + 1))].maxDistance
			local margin = threshold * self.hysteresis
			if math.abs(distance - threshold) < margin then return prev.band, false end
			self.transitions = self.transitions + 1
		end
		self.assignments[id] = { band = band, distance = distance, importance = importance or 1 }
		return band, prev == nil or prev.band.id ~= band.id
	end

	function LOD:recount()
		self.counts = {}
		for _, a in pairs(self.assignments) do
			self.counts[a.band.name] = (self.counts[a.band.name] or 0) + 1
		end
		return self.counts
	end

	-- budget-aware pass: if too many objects are in high bands, push the cheapest ones down
	function LOD:enforce(maxHero, maxNear)
		local hero, near = {}, {}
		for id, a in pairs(self.assignments) do
			if a.band.id == 0 then hero[#hero + 1] = { id = id, a = a }
			elseif a.band.id == 1 then near[#near + 1] = { id = id, a = a } end
		end
		table.sort(hero, function(x, y) return (x.a.importance / math.max(x.a.distance, 0.1)) < (y.a.importance / math.max(y.a.distance, 0.1)) end)
		local demoted = 0
		while #hero > (maxHero or 24) do
			local item = table.remove(hero, 1)
			self.assignments[item.id].band = LOD.BANDS[2]
			demoted = demoted + 1
		end
		table.sort(near, function(x, y) return x.a.distance > y.a.distance end)
		while #near > (maxNear or 90) do
			local item = table.remove(near, 1)
			self.assignments[item.id].band = LOD.BANDS[3]
			demoted = demoted + 1
		end
		return demoted
	end

	function LOD:tickRateFor(id)
		local a = self.assignments[id]
		if not a then return 1 end
		return a.band.tickRate
	end

	function LOD:shouldTick(id, frame)
		local rate = self:tickRateFor(id)
		if rate <= 0 then return false end
		if rate >= 60 then return true end
		local period = math.max(1, math.floor(60 / rate))
		return (frame + (id or 0)) % period == 0
	end

	function LOD:screenCoverage(radius, distance, fovY, screenHeight)
		if distance <= 0 then return 1 end
		local projected = (radius / distance) / math.tan(fovY / 2)
		return Mathx.clamp(projected, 0, 1)
	end

	function LOD:report()
		self:recount()
		return { bias = self.bias, transitions = self.transitions, counts = self.counts,
			tracked = (function() local n = 0 for _ in pairs(self.assignments) do n = n + 1 end return n end)() }
	end

	return LOD

end
