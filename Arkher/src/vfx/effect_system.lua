-- ARKHER VFX :: Effect System
-- The ARKHER VFX Framework: effect templates assembled from emission, simulation, force
-- fields and ribbons; instances spawned in the world; distance LOD; and one global
-- particle budget that the whole game shares, because a phone has exactly one GPU.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local Effects = {}
	Effects.__index = Effects

	-- Distance bands: how much of an effect actually runs at this distance.
	Effects.LOD = {
		{ name = "full",    distance = 40,        rateScale = 1.0,  capacityScale = 1.0,  step = 1 },
		{ name = "reduced", distance = 110,       rateScale = 0.45, capacityScale = 0.5,  step = 1 },
		{ name = "minimal", distance = 260,       rateScale = 0.15, capacityScale = 0.2,  step = 2 },
		{ name = "culled",  distance = math.huge, rateScale = 0,    capacityScale = 0,    step = 0 },
	}

	function Effects.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Effects)
		self.templates = {}
		self.instances = {}
		self.order = {}
		self.nextId = 1
		self.budget = opts.budget or 2000
		self.observer = v3()
		self.frame = 0
		self.spawned = 0
		self.completed = 0
		self.culled = 0
		self.starved = 0
		self.liveParticles = 0
		self.onSpawn = Signal.new()
		self.onComplete = Signal.new()
		self.profiler = Kits.create("analyzer", { id = "vfx.profiler", window = 120 })
		self.budgeter = Kits.create("budgeter", { id = "vfx.budget",
			total = self.budget, strategy = "priority" })
		return self
	end

	-- ------------------------------------------------------------------ templates
	function Effects:define(name, spec)
		if self.templates[name] then return nil, "duplicate template" end
		spec = spec or {}
		self.templates[name] = {
			name = name,
			emitter = spec.emitter or {},
			particles = spec.particles or {},
			fields = spec.fields or {},
			ribbon = spec.ribbon,
			duration = spec.duration or 2,
			priority = spec.priority or 1,
			looping = spec.looping or false,
			burst = spec.burst,
		}
		return self.templates[name]
	end

	function Effects:defineDefaults()
		if self.templates.spark then return 4 end
		self:define("spark", {
			emitter = { shape = "cone", rate = 90, speed = 9, angle = math.rad(30),
				life = 0.7, startSize = 0.12, budget = 180 },
			particles = { capacity = 180, gravity = v3(0, -14, 0), drag = 0.6, groundY = 0,
				bounce = 0.25, sizeCurve = { 1, 0.8, 0 } },
			fields = { { id = "wind", kind = "wind", direction = v3(1, 0, 0), strength = 1.5 } },
			duration = 0.9, priority = 2, burst = 40 })
		self:define("smoke", {
			emitter = { shape = "sphere", radius = 0.5, rate = 24, speed = 1.4,
				life = 3.2, startSize = 1.1, budget = 90 },
			particles = { capacity = 90, gravity = v3(0, 1.2, 0), drag = 1.2,
				sizeCurve = { 0.4, 1.0, 1.8 }, alphaCurve = { 0, 0.7, 0 } },
			fields = { { id = "swirl", kind = "turbulence", strength = 2.2, radius = 40,
				frequency = 0.2 } },
			duration = 4, priority = 1, looping = true })
		self:define("magic", {
			emitter = { shape = "circle", radius = 1.2, rate = 60, speed = 3.5,
				direction = v3(0, 1, 0), life = 1.6, startSize = 0.2, budget = 140 },
			particles = { capacity = 140, gravity = v3(0, 2.5, 0), drag = 0.9,
				alphaCurve = { 0, 1, 0 } },
			fields = { { id = "vortex", kind = "vortex", direction = v3(0, 1, 0),
				strength = 6, radius = 8 } },
			ribbon = { maxPoints = 24, lifetime = 0.6, width = 0.35 },
			duration = 2.2, priority = 3 })
		self:define("impact", {
			emitter = { shape = "sphere", radius = 0.2, rate = 0, speed = 12,
				life = 0.45, startSize = 0.18, budget = 120 },
			particles = { capacity = 120, gravity = v3(0, -22, 0), drag = 1.4, groundY = 0 },
			fields = {},
			duration = 0.6, priority = 4, burst = 60 })
		return 4
	end

	-- ------------------------------------------------------------------ instances
	function Effects:spawn(templateName, position, opts)
		local template = self.templates[templateName]
		if not template then return nil, "unknown template" end
		opts = opts or {}
		local id = opts.id or (templateName .. "#" .. self.nextId)
		self.nextId = self.nextId + 1

		local emitterCfg = {}
		for k, v in pairs(template.emitter) do emitterCfg[k] = v end
		emitterCfg.id = id .. ".emitter"
		emitterCfg.position = position or v3()
		emitterCfg.seed = opts.seed or (self.nextId * 7919)

		local particlesCfg = {}
		for k, v in pairs(template.particles) do particlesCfg[k] = v end
		particlesCfg.id = id .. ".particles"

		local inst = {
			id = id,
			template = templateName,
			position = position or v3(),
			priority = opts.priority or template.priority,
			age = 0,
			duration = opts.duration or template.duration,
			looping = opts.looping == nil and template.looping or opts.looping,
			emitter = Kits.create("emitter", emitterCfg),
			particles = Kits.create("particles", particlesCfg),
			fields = Kits.create("forcefield", { id = id .. ".fields", seed = self.nextId }),
			ribbon = template.ribbon and Kits.create("ribbon",
				{ id = id .. ".ribbon", maxPoints = template.ribbon.maxPoints,
				  lifetime = template.ribbon.lifetime, width = template.ribbon.width }) or nil,
			lod = "full",
			baseRate = emitterCfg.rate or 20,
			baseCapacity = particlesCfg.capacity or 64,
			alive = true,
		}
		for _, f in ipairs(template.fields) do
			inst.fields.addField(f.id, f.kind, f)
		end
		if template.burst then inst.emitter.burst(template.burst, 0) end

		self.instances[id] = inst
		self.order[#self.order + 1] = id
		self.spawned = self.spawned + 1
		self.onSpawn:fire({ id = id, template = templateName, position = inst.position })
		return inst
	end

	function Effects:get(id) return self.instances[id] end

	function Effects:stop(id)
		local inst = self.instances[id]
		if not inst then return false end
		inst.looping = false
		inst.emitter.pause()
		return true
	end

	function Effects:destroy(id)
		local inst = self.instances[id]
		if not inst then return false end
		self.liveParticles = self.liveParticles - inst.particles.aliveCount()
		if self.liveParticles < 0 then self.liveParticles = 0 end
		self.instances[id] = nil
		for i, name in ipairs(self.order) do
			if name == id then table.remove(self.order, i) break end
		end
		self.completed = self.completed + 1
		self.onComplete:fire({ id = id })
		return true
	end

	function Effects:move(id, position)
		local inst = self.instances[id]
		if not inst then return false end
		inst.position = position
		inst.emitter.position = position
		if inst.ribbon then inst.ribbon.push(position) end
		return true
	end

	-- ------------------------------------------------------------------ simulation
	function Effects:lodFor(distance)
		for _, band in ipairs(Effects.LOD) do
			if distance <= band.distance then return band end
		end
		return Effects.LOD[#Effects.LOD]
	end

	function Effects:setObserver(position)
		self.observer = position or v3()
		return self.observer
	end

	function Effects:update(dt, observer)
		self.frame = self.frame + 1
		if observer then self.observer = observer end
		local live = 0
		local simulated = 0
		local culled = 0

		-- Claim the global particle budget by priority: important effects keep their density.
		local claims = {}
		for _, id in ipairs(self.order) do
			local inst = self.instances[id]
			local distance = inst.position:distance(self.observer)
			inst.lod = self:lodFor(distance).name
			local band = self:lodFor(distance)
			local want = math.floor(inst.baseCapacity * band.capacityScale)
			claims[id] = want
			self.budgeter.claim(id, want, inst.priority)
		end
		local granted = self.budgeter.allocate()

		local dead = {}
		for _, id in ipairs(self.order) do
			local inst = self.instances[id]
			local band = self:lodFor(inst.position:distance(self.observer))
			local allowance = granted[id] or 0
			if claims[id] > 0 and allowance < claims[id] * 0.25 then self.starved = self.starved + 1 end
			inst.age = inst.age + dt
			if band.step == 0 or allowance <= 0 then
				culled = culled + 1
				inst.particles.killAll()
			elseif self.frame % band.step == 0 then
				simulated = simulated + 1
				inst.emitter.rate = inst.baseRate * band.rateScale
				local emitting = inst.looping or inst.age <= inst.duration
				local specs = emitting and inst.emitter.emit(dt * band.step, inst.particles.aliveCount()) or {}
				local room = math.max(0, math.floor(allowance) - inst.particles.aliveCount())
				for i = 1, math.min(#specs, room) do inst.particles.spawn(specs[i]) end
				inst.fields.applyTo(inst.particles, dt * band.step)
				inst.particles.step(dt * band.step)
				if inst.ribbon then inst.ribbon.update(dt * band.step) end
			end
			live = live + inst.particles.aliveCount()
			if not inst.looping and inst.age > inst.duration and inst.particles.aliveCount() == 0 then
				dead[#dead + 1] = id
			end
			self.budgeter.release(id)
		end

		for _, id in ipairs(dead) do self:destroy(id) end
		self.liveParticles = live
		self.culled = self.culled + culled
		self.profiler.submit(live)
		return { live = live, simulated = simulated, culled = culled, effects = #self.order }
	end

	function Effects:run(seconds, dt)
		local step = dt or 1 / 60
		local n = math.max(1, math.floor(seconds / step))
		local last
		for _ = 1, n do last = self:update(step) end
		return last
	end

	function Effects:activeCount() return #self.order end
	function Effects:particleCount() return self.liveParticles end

	function Effects:byLod()
		local out = {}
		for _, id in ipairs(self.order) do
			local lod = self.instances[id].lod
			out[lod] = (out[lod] or 0) + 1
		end
		return out
	end

	function Effects:applyQuality(q)
		q = Mathx.clamp(q, 0, 1)
		self.budget = math.max(120, math.floor(2000 * Mathx.lerp(0.1, 1, q)))
		self.budgeter.total = self.budget
		for i, band in ipairs(Effects.LOD) do
			if band.distance ~= math.huge then
				band.distance = Effects.LOD[i].distance
			end
		end
		Effects.LOD[1].distance = 40 * Mathx.lerp(0.35, 1, q)
		Effects.LOD[2].distance = 110 * Mathx.lerp(0.35, 1, q)
		Effects.LOD[3].distance = 260 * Mathx.lerp(0.35, 1, q)
		for _, id in ipairs(self.order) do
			local inst = self.instances[id]
			inst.baseCapacity = math.max(8, math.floor(inst.baseCapacity * Mathx.lerp(0.2, 1, q)))
		end
		return { budget = self.budget, fullDistance = Effects.LOD[1].distance }
	end

	function Effects:report()
		return { effects = #self.order, templates = 0 == 0 and self:templateCount() or 0,
			particles = self.liveParticles, budget = self.budget, frame = self.frame,
			spawned = self.spawned, completed = self.completed, culled = self.culled,
			starved = self.starved, byLod = self:byLod(),
			meanParticles = self.profiler.mean() }
	end

	function Effects:templateCount()
		local n = 0
		for _ in pairs(self.templates) do n = n + 1 end
		return n
	end

	return Effects
end
