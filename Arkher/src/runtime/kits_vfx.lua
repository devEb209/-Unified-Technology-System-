-- ARKHER RUNTIME :: VFX and Audio Kits
-- Round 7 machinery (kits 82-89). Complete working implementations that the generated
-- catalog specializes: particle emission and simulation, force fields, ribbons/beams,
-- DSP, mixing, spatialization and musical sequencing. Deterministic and budgeted.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Random = A:import("arkher/kernel/random")
	local Noise = A:import("arkher/kernel/noise")

	local K = {}
	local v3 = Vec.vec3
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 82. EMITTER
	-- ARKHER VFX emission: shapes, rate and burst emission, deterministic variance and a
	-- hard spawn budget. It produces particle *specs*; the simulation kit owns the motion.
	function K.emitter(cfg)
		local self = { kind = "emitter", id = cfg.id, shape = cfg.shape or "point",
			size = cfg.size or v3(1, 1, 1), radius = cfg.radius or 1,
			angle = cfg.angle or math.rad(25), rate = cfg.rate or 20,
			speed = cfg.speed or 6, speedVariance = cfg.speedVariance or 0.3,
			life = cfg.life or 1.5, lifeVariance = cfg.lifeVariance or 0.2,
			startSize = cfg.startSize or 0.4, sizeVariance = cfg.sizeVariance or 0.25,
			position = cfg.position or v3(), direction = (cfg.direction or v3(0, 1, 0)):unit(),
			budget = cfg.budget or 256, accumulator = 0, emitted = 0, dropped = 0,
			bursts = {}, active = true, time = 0,
			rng = Random.new(cfg.seed or 4242) }

		function self.setRate(rate)
			self.rate = math.max(0, rate)
			return self.rate
		end

		function self.setShape(shape, opts)
			opts = opts or {}
			self.shape = shape
			if opts.radius then self.radius = opts.radius end
			if opts.size then self.size = opts.size end
			if opts.angle then self.angle = opts.angle end
			return self.shape
		end

		function self.setBudget(n)
			self.budget = math.max(0, math.floor(n))
			return self.budget
		end

		function self.burst(count, atTime)
			self.bursts[#self.bursts + 1] = { count = math.floor(count), at = atTime or self.time,
				fired = false }
			return #self.bursts
		end

		-- Spawn position depends on the emitter shape, not on a random blob.
		function self.samplePosition()
			local rng = self.rng
			if self.shape == "sphere" then
				local dir = rng:onUnitSphere()
				local r = self.radius * (rng:next() ^ (1 / 3))
				return self.position + v3(dir.x, dir.y, dir.z) * r
			elseif self.shape == "box" then
				return self.position + v3((rng:next() - 0.5) * self.size.x,
					(rng:next() - 0.5) * self.size.y, (rng:next() - 0.5) * self.size.z)
			elseif self.shape == "circle" then
				local a = rng:next() * math.pi * 2
				local r = self.radius * math.sqrt(rng:next())
				return self.position + v3(math.cos(a) * r, 0, math.sin(a) * r)
			elseif self.shape == "cone" then
				local a = rng:next() * math.pi * 2
				local r = self.radius * math.sqrt(rng:next())
				return self.position + v3(math.cos(a) * r, 0, math.sin(a) * r)
			end
			return self.position
		end

		function self.sampleVelocity()
			local rng = self.rng
			local speed = self.speed * (1 + (rng:next() - 0.5) * 2 * self.speedVariance)
			if self.shape == "sphere" then
				local dir = rng:onUnitSphere()
				return v3(dir.x, dir.y, dir.z) * speed
			elseif self.shape == "cone" then
				local spread = math.tan(self.angle)
				local a = rng:next() * math.pi * 2
				local r = spread * math.sqrt(rng:next())
				local dir = (self.direction + v3(math.cos(a) * r, 0, math.sin(a) * r)):unit()
				return dir * speed
			end
			return self.direction * speed
		end

		function self.sampleSpec()
			local rng = self.rng
			return { position = self.samplePosition(), velocity = self.sampleVelocity(),
				life = math.max(0.05, self.life * (1 + (rng:next() - 0.5) * 2 * self.lifeVariance)),
				size = math.max(0.01, self.startSize * (1 + (rng:next() - 0.5) * 2 * self.sizeVariance)),
				seed = rng:int(1, 1000000) }
		end

		-- One emission step: continuous rate plus any burst whose time has come.
		function self.emit(dt, liveCount)
			self.time = self.time + dt
			local out = {}
			if not self.active then return out end
			local room = self.budget - (liveCount or 0)
			self.accumulator = self.accumulator + self.rate * dt
			local want = math.floor(self.accumulator)
			self.accumulator = self.accumulator - want
			for _, b in ipairs(self.bursts) do
				if not b.fired and self.time >= b.at then
					want = want + b.count
					b.fired = true
				end
			end
			for _ = 1, want do
				if #out >= room then
					self.dropped = self.dropped + 1
				else
					out[#out + 1] = self.sampleSpec()
					self.emitted = self.emitted + 1
				end
			end
			return out
		end

		function self.prewarm(seconds, dt)
			local step = dt or 1 / 30
			local total = 0
			local n = math.max(1, math.floor((seconds or 1) / step))
			for _ = 1, n do total = total + #self.emit(step, 0) end
			return total
		end

		function self.pause() self.active = false return true end
		function self.resume() self.active = true return true end

		function self.applyQuality(q)
			q = clamp01(q)
			self.budget = math.max(8, math.floor(self.budget * Mathx.lerp(0.15, 1, q)))
			self.rate = self.rate * Mathx.lerp(0.2, 1, q)
			return { budget = self.budget, rate = self.rate }
		end

		function self.stats() return { shape = self.shape, rate = self.rate, budget = self.budget,
			emitted = self.emitted, dropped = self.dropped, bursts = #self.bursts,
			active = self.active, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 83. PARTICLES
	-- Particle simulation with a fixed pool: integration, drag, gravity, curves over life,
	-- ground bounce and stable culling. Never allocates per particle after the pool is built.
	function K.particles(cfg)
		local self = { kind = "particles", id = cfg.id, capacity = cfg.capacity or 256,
			pool = {}, alive = 0, gravity = cfg.gravity or v3(0, -9.81, 0),
			drag = cfg.drag or 0.1, bounce = cfg.bounce or 0, groundY = cfg.groundY,
			spawned = 0, killed = 0, steps = 0, time = 0,
			sizeCurve = cfg.sizeCurve or { 0.2, 1.0, 0.6 },
			alphaCurve = cfg.alphaCurve or { 0.0, 1.0, 0.0 } }

		for i = 1, self.capacity do
			self.pool[i] = { alive = false, position = v3(), velocity = v3(), age = 0,
				life = 1, size = 1, baseSize = 1, alpha = 1, seed = 0 }
		end

		local function curveAt(curve, t)
			local n = #curve
			if n == 0 then return 1 end
			if n == 1 then return curve[1] end
			local x = clamp01(t) * (n - 1)
			local i = math.floor(x)
			local f = x - i
			local a = curve[i + 1]
			local b = curve[math.min(n, i + 2)]
			return Mathx.lerp(a, b, f)
		end
		self.curveAt = curveAt

		function self.spawn(spec)
			for i = 1, self.capacity do
				local p = self.pool[i]
				if not p.alive then
					p.alive = true
					p.position = spec.position or v3()
					p.velocity = spec.velocity or v3()
					p.age = 0
					p.life = spec.life or 1
					p.baseSize = spec.size or 1
					p.size = p.baseSize * curveAt(self.sizeCurve, 0)
					p.alpha = curveAt(self.alphaCurve, 0)
					p.seed = spec.seed or i
					self.alive = self.alive + 1
					self.spawned = self.spawned + 1
					return i
				end
			end
			return nil
		end

		function self.spawnMany(specs)
			local n = 0
			for _, spec in ipairs(specs) do
				if self.spawn(spec) then n = n + 1 end
			end
			return n
		end

		function self.kill(index)
			local p = self.pool[index]
			if not p or not p.alive then return false end
			p.alive = false
			self.alive = self.alive - 1
			self.killed = self.killed + 1
			return true
		end

		function self.killAll()
			local n = 0
			for i = 1, self.capacity do
				if self.kill(i) then n = n + 1 end
			end
			return n
		end

		function self.applyForce(force, dt)
			for i = 1, self.capacity do
				local p = self.pool[i]
				if p.alive then p.velocity = p.velocity + force * dt end
			end
			return self.alive
		end

		function self.step(dt)
			self.steps = self.steps + 1
			self.time = self.time + dt
			local damping = math.max(0, 1 - self.drag * dt)
			for i = 1, self.capacity do
				local p = self.pool[i]
				if p.alive then
					p.age = p.age + dt
					if p.age >= p.life then
						self.kill(i)
					else
						p.velocity = (p.velocity + self.gravity * dt) * damping
						p.position = p.position + p.velocity * dt
						if self.groundY and p.position.y < self.groundY then
							p.position = v3(p.position.x, self.groundY, p.position.z)
							if self.bounce > 0 then
								p.velocity = v3(p.velocity.x, -p.velocity.y * self.bounce, p.velocity.z)
							else
								p.velocity = v3(p.velocity.x, 0, p.velocity.z)
							end
						end
						local t = p.age / p.life
						p.size = p.baseSize * curveAt(self.sizeCurve, t)
						p.alpha = curveAt(self.alphaCurve, t)
					end
				end
			end
			return self.alive
		end

		function self.aliveCount() return self.alive end

		function self.particleAt(index) return self.pool[index] end

		function self.aliveList()
			local out = {}
			for i = 1, self.capacity do
				if self.pool[i].alive then out[#out + 1] = self.pool[i] end
			end
			return out
		end

		function self.bounds()
			local min, max = nil, nil
			for i = 1, self.capacity do
				local p = self.pool[i]
				if p.alive then
					min = min and min:min(p.position) or p.position
					max = max and max:max(p.position) or p.position
				end
			end
			if not min then return nil end
			return { min = min, max = max, center = (min + max) * 0.5 }
		end

		function self.occupancy() return self.alive / math.max(1, self.capacity) end

		function self.applyQuality(q)
			q = clamp01(q)
			local newCap = math.max(8, math.floor(self.capacity * Mathx.lerp(0.15, 1, q)))
			for i = newCap + 1, self.capacity do
				if self.pool[i] and self.pool[i].alive then self.kill(i) end
			end
			return { capacity = newCap, alive = self.alive }
		end

		function self.stats() return { capacity = self.capacity, alive = self.alive,
			spawned = self.spawned, killed = self.killed, steps = self.steps,
			occupancy = self.occupancy(), time = self.time } end
		return self
	end

	------------------------------------------------------------------ 84. FORCEFIELD
	-- Force fields evaluated analytically at a point: uniform wind, radial attract/repel,
	-- vortex, drag and curl-noise turbulence. Fields compose additively.
	function K.forcefield(cfg)
		local self = { kind = "forcefield", id = cfg.id, fields = {}, order = {},
			evaluations = 0, seed = cfg.seed or 1234 }

		function self.addField(id, kind, opts)
			opts = opts or {}
			if self.fields[id] then return nil, "duplicate field" end
			local f = { id = id, kind = kind, position = opts.position or v3(),
				direction = (opts.direction or v3(0, 1, 0)):unit(),
				strength = opts.strength or 10, radius = opts.radius or 20,
				falloff = opts.falloff or "inverse", frequency = opts.frequency or 0.15,
				enabled = true }
			self.fields[id] = f
			self.order[#self.order + 1] = id
			return f
		end

		function self.removeField(id)
			if not self.fields[id] then return false end
			self.fields[id] = nil
			for i, name in ipairs(self.order) do
				if name == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.setEnabled(id, on)
			local f = self.fields[id]
			if not f then return false end
			f.enabled = on and true or false
			return f.enabled
		end

		local function falloffAt(f, distance)
			if distance >= f.radius then return 0 end
			local t = 1 - distance / f.radius
			if f.falloff == "linear" then return t end
			if f.falloff == "constant" then return 1 end
			if f.falloff == "smooth" then return Mathx.smoothstep(t) end
			return t * t
		end

		function self.fieldForce(f, position, velocity)
			if not f.enabled then return v3() end
			if f.kind == "wind" then
				return f.direction * f.strength
			elseif f.kind == "drag" then
				return (velocity or v3()) * (-f.strength)
			end
			local delta = position - f.position
			local distance = delta:length()
			local scale = falloffAt(f, distance)
			if scale <= 0 then return v3() end
			if f.kind == "radial" then
				if distance < 1e-6 then return v3() end
				return delta:unit() * (f.strength * scale)
			elseif f.kind == "vortex" then
				local axis = f.direction
				local tangent = axis:cross(delta)
				if tangent:length() < 1e-6 then return v3() end
				return tangent:unit() * (f.strength * scale)
			elseif f.kind == "turbulence" then
				local fx, fy, fz = position.x * f.frequency, position.y * f.frequency,
					position.z * f.frequency
				local n1 = Noise.perlin3D(fx, fy, fz, self.seed)
				local n2 = Noise.perlin3D(fy + 31.7, fz, fx, self.seed + 7)
				local n3 = Noise.perlin3D(fz, fx + 17.3, fy, self.seed + 13)
				return v3(n1, n2, n3) * (f.strength * scale)
			end
			return v3()
		end

		function self.evaluate(position, velocity)
			self.evaluations = self.evaluations + 1
			local total = v3()
			for _, id in ipairs(self.order) do
				total = total + self.fieldForce(self.fields[id], position, velocity)
			end
			return total
		end

		function self.strengthAt(position, velocity)
			return self.evaluate(position, velocity):length()
		end

		function self.applyTo(particles, dt)
			local n = 0
			for i = 1, particles.capacity do
				local p = particles.particleAt(i)
				if p and p.alive then
					p.velocity = p.velocity + self.evaluate(p.position, p.velocity) * dt
					n = n + 1
				end
			end
			return n
		end

		function self.dominant(position)
			local best, bestMag = nil, -1
			for _, id in ipairs(self.order) do
				local mag = self.fieldForce(self.fields[id], position, v3()):length()
				if mag > bestMag then bestMag = mag best = id end
			end
			return best, bestMag
		end

		function self.fieldCount() return #self.order end

		function self.stats() return { fields = #self.order, evaluations = self.evaluations } end
		return self
	end

	------------------------------------------------------------------ 85. RIBBON
	-- Trails and beams: a point history with lifetime and minimum spacing, width and
	-- fade curves, strip generation and a decimation pass so a long trail stays cheap.
	function K.ribbon(cfg)
		local self = { kind = "ribbon", id = cfg.id, points = {}, maxPoints = cfg.maxPoints or 32,
			lifetime = cfg.lifetime or 1.0, minDistance = cfg.minDistance or 0.15,
			width = cfg.width or 0.5, taper = cfg.taper == nil and true or cfg.taper,
			pushes = 0, dropped = 0, time = 0 }

		function self.push(position, forceAdd)
			self.pushes = self.pushes + 1
			local last = self.points[#self.points]
			if last and not forceAdd and last.position:distance(position) < self.minDistance then
				last.age = 0
				return false
			end
			self.points[#self.points + 1] = { position = position, age = 0, birth = self.time }
			while #self.points > self.maxPoints do
				table.remove(self.points, 1)
				self.dropped = self.dropped + 1
			end
			return true
		end

		function self.update(dt)
			self.time = self.time + dt
			local i = 1
			while i <= #self.points do
				local p = self.points[i]
				p.age = p.age + dt
				if p.age > self.lifetime then
					table.remove(self.points, i)
					self.dropped = self.dropped + 1
				else
					i = i + 1
				end
			end
			return #self.points
		end

		function self.setWidth(w)
			self.width = math.max(0.001, w)
			return self.width
		end

		function self.widthAt(index)
			local n = #self.points
			if n == 0 then return 0 end
			local t = (index - 1) / math.max(1, n - 1)
			local fade = 1 - clamp01(self.points[index].age / self.lifetime)
			if self.taper then return self.width * t * fade end
			return self.width * fade
		end

		-- A camera-facing strip: two vertices per point, offset along the segment normal.
		function self.vertices(cameraPosition)
			local out = {}
			local n = #self.points
			if n < 2 then return out end
			local eye = cameraPosition or v3(0, 0, -1)
			for i = 1, n do
				local p = self.points[i].position
				local nextP = self.points[math.min(n, i + 1)].position
				local prevP = self.points[math.max(1, i - 1)].position
				local tangent = (nextP - prevP)
				if tangent:length() < 1e-6 then tangent = v3(1, 0, 0) end
				local toEye = (eye - p)
				if toEye:length() < 1e-6 then toEye = v3(0, 0, 1) end
				local side = tangent:cross(toEye):unit()
				local half = self.widthAt(i) * 0.5
				out[#out + 1] = p + side * half
				out[#out + 1] = p - side * half
			end
			return out
		end

		function self.length()
			local total = 0
			for i = 2, #self.points do
				total = total + self.points[i].position:distance(self.points[i - 1].position)
			end
			return total
		end

		-- A beam is a ribbon between two fixed points with optional sag and noise.
		function self.beam(from, to, segments, sag)
			self.points = {}
			local n = math.max(2, segments or 8)
			local drop = sag or 0
			for i = 0, n do
				local t = i / n
				local p = from:lerp(to, t)
				local dip = math.sin(t * math.pi) * drop
				self.points[#self.points + 1] = { position = v3(p.x, p.y - dip, p.z),
					age = 0, birth = self.time }
			end
			self.maxPoints = math.max(self.maxPoints, n + 1)
			return #self.points
		end

		function self.simplify(tolerance)
			local tol = tolerance or 0.05
			if #self.points < 3 then return #self.points end
			local kept = { self.points[1] }
			for i = 2, #self.points - 1 do
				local a = kept[#kept].position
				local b = self.points[i].position
				local c = self.points[i + 1].position
				local ab = (b - a)
				local ac = (c - a)
				local cross = ab:cross(ac):length()
				local base = ac:length()
				local deviation = base > 1e-6 and cross / base or 0
				if deviation > tol then kept[#kept + 1] = self.points[i] end
			end
			kept[#kept + 1] = self.points[#self.points]
			local removed = #self.points - #kept
			self.points = kept
			return #self.points, removed
		end

		function self.clear()
			local n = #self.points
			self.points = {}
			return n
		end

		function self.stats() return { points = #self.points, maxPoints = self.maxPoints,
			length = self.length(), pushes = self.pushes, dropped = self.dropped,
			width = self.width, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 86. DSP
	-- Signal processing on real sample buffers: biquad filtering, a delay line with
	-- feedback, soft clipping, gain staging and level metering.
	function K.dsp(cfg)
		local self = { kind = "dsp", id = cfg.id, sampleRate = cfg.sampleRate or 44100,
			filterType = cfg.filter or "lowpass", cutoff = cfg.cutoff or 8000,
			q = cfg.q or 0.707, gain = cfg.gain or 1, delayLine = {}, delayIndex = 1,
			delaySamples = 0, feedback = cfg.feedback or 0.3, mix = cfg.mix or 0,
			x1 = 0, x2 = 0, y1 = 0, y2 = 0, processed = 0, envelope = 0,
			b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0 }

		function self.setFilter(kind, cutoff, q)
			self.filterType = kind or self.filterType
			self.cutoff = Mathx.clamp(cutoff or self.cutoff, 20, self.sampleRate * 0.45)
			self.q = q or self.q
			local omega = 2 * math.pi * self.cutoff / self.sampleRate
			local sn = math.sin(omega)
			local cs = math.cos(omega)
			local alpha = sn / (2 * self.q)
			local b0, b1, b2, a0, a1, a2
			if self.filterType == "highpass" then
				b0 = (1 + cs) / 2 b1 = -(1 + cs) b2 = (1 + cs) / 2
				a0 = 1 + alpha a1 = -2 * cs a2 = 1 - alpha
			elseif self.filterType == "bandpass" then
				b0 = alpha b1 = 0 b2 = -alpha
				a0 = 1 + alpha a1 = -2 * cs a2 = 1 - alpha
			else
				b0 = (1 - cs) / 2 b1 = 1 - cs b2 = (1 - cs) / 2
				a0 = 1 + alpha a1 = -2 * cs a2 = 1 - alpha
			end
			self.b0 = b0 / a0 self.b1 = b1 / a0 self.b2 = b2 / a0
			self.a1 = a1 / a0 self.a2 = a2 / a0
			return self.filterType, self.cutoff
		end
		self.setFilter(self.filterType, self.cutoff, self.q)

		function self.setDelay(seconds, feedback, mix)
			self.delaySamples = math.max(0, math.floor((seconds or 0) * self.sampleRate))
			self.feedback = Mathx.clamp(feedback or self.feedback, 0, 0.95)
			self.mix = clamp01(mix == nil and self.mix or mix)
			self.delayLine = {}
			for i = 1, math.max(1, self.delaySamples) do self.delayLine[i] = 0 end
			self.delayIndex = 1
			return self.delaySamples
		end

		function self.setGain(g)
			self.gain = math.max(0, g)
			return self.gain
		end

		local function softClip(x)
			if x > 1 then return 1 - 1 / (x + 1) end
			if x < -1 then return -1 + 1 / (1 - x) end
			return x - (x * x * x) / 3 * 0.5
		end
		self.softClip = softClip

		function self.processSample(x)
			self.processed = self.processed + 1
			local y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2
				- self.a1 * self.y1 - self.a2 * self.y2
			self.x2 = self.x1 self.x1 = x
			self.y2 = self.y1 self.y1 = y
			if self.delaySamples > 0 then
				local d = self.delayLine[self.delayIndex] or 0
				local wet = y + d * self.feedback
				self.delayLine[self.delayIndex] = wet
				self.delayIndex = self.delayIndex % self.delaySamples + 1
				y = Mathx.lerp(y, d, self.mix)
			end
			y = softClip(y * self.gain)
			self.envelope = self.envelope + (math.abs(y) - self.envelope) * 0.01
			return y
		end

		function self.process(buffer)
			local out = {}
			for i = 1, #buffer do out[i] = self.processSample(buffer[i]) end
			return out
		end

		function self.rms(buffer)
			if #buffer == 0 then return 0 end
			local sum = 0
			for i = 1, #buffer do sum = sum + buffer[i] * buffer[i] end
			return math.sqrt(sum / #buffer)
		end

		function self.peak(buffer)
			local m = 0
			for i = 1, #buffer do
				local a = math.abs(buffer[i])
				if a > m then m = a end
			end
			return m
		end

		function self.tone(frequency, samples, amplitude)
			local out = {}
			local n = samples or 256
			for i = 1, n do
				out[i] = (amplitude or 1) * math.sin(2 * math.pi * frequency * (i - 1) / self.sampleRate)
			end
			return out
		end

		function self.reset()
			self.x1, self.x2, self.y1, self.y2 = 0, 0, 0, 0
			for i = 1, #self.delayLine do self.delayLine[i] = 0 end
			self.envelope = 0
			return true
		end

		function self.stats() return { filter = self.filterType, cutoff = self.cutoff,
			q = self.q, gain = self.gain, delaySamples = self.delaySamples,
			processed = self.processed, envelope = self.envelope,
			sampleRate = self.sampleRate } end
		return self
	end

	------------------------------------------------------------------ 87. MIXER
	-- Bus mixing: a routing tree with gains in dB, mute/solo, sidechain ducking with
	-- attack/release, snapshots and a voice limiter that steals by priority.
	function K.mixer(cfg)
		local self = { kind = "mixer", id = cfg.id, buses = {}, order = {},
			maxVoices = cfg.maxVoices or 32, voices = {}, voiceOrder = {},
			soloActive = false, steals = 0, changes = 0 }

		local function dbToLinear(db) return 10 ^ (db / 20) end
		self.dbToLinear = dbToLinear
		local function linearToDb(l)
			if l <= 1e-6 then return -120 end
			return 20 * math.log(l, 10)
		end
		self.linearToDb = linearToDb

		function self.addBus(id, opts)
			opts = opts or {}
			if self.buses[id] then return nil, "duplicate bus" end
			local bus = { id = id, parent = opts.parent, gainDb = opts.gainDb or 0,
				mute = false, solo = false, duck = 0, duckTarget = 0,
				attack = opts.attack or 0.05, release = opts.release or 0.35 }
			self.buses[id] = bus
			self.order[#self.order + 1] = id
			return bus
		end

		function self.route(id, parentId)
			local bus = self.buses[id]
			if not bus or (parentId and not self.buses[parentId]) then return false end
			bus.parent = parentId
			return true
		end

		function self.setGain(id, db)
			local bus = self.buses[id]
			if not bus then return false end
			bus.gainDb = db
			self.changes = self.changes + 1
			return bus.gainDb
		end

		function self.setMute(id, on)
			local bus = self.buses[id]
			if not bus then return false end
			bus.mute = on and true or false
			return bus.mute
		end

		function self.setSolo(id, on)
			local bus = self.buses[id]
			if not bus then return false end
			bus.solo = on and true or false
			self.soloActive = false
			for _, name in ipairs(self.order) do
				if self.buses[name].solo then self.soloActive = true end
			end
			return bus.solo
		end

		-- Effective gain walks the routing tree: parents scale their children.
		function self.effectiveGain(id)
			local bus = self.buses[id]
			if not bus then return 0 end
			local gain = 1
			local node = bus
			local guard = 0
			while node and guard < 16 do
				if node.mute then return 0 end
				if self.soloActive and not node.solo and not node.parent then return 0 end
				gain = gain * dbToLinear(node.gainDb) * (1 - node.duck)
				node = node.parent and self.buses[node.parent] or nil
				guard = guard + 1
			end
			return gain
		end

		function self.duck(id, amount)
			local bus = self.buses[id]
			if not bus then return false end
			bus.duckTarget = clamp01(amount)
			return bus.duckTarget
		end

		function self.tick(dt)
			for _, name in ipairs(self.order) do
				local bus = self.buses[name]
				local rate = bus.duckTarget > bus.duck and bus.attack or bus.release
				bus.duck = Mathx.damp(bus.duck, bus.duckTarget, 1 / math.max(1e-3, rate), dt)
			end
			return true
		end

		function self.play(voiceId, busId, priority)
			if self.voices[voiceId] then return false end
			if #self.voiceOrder >= self.maxVoices then
				local worst, worstPriority = nil, math.huge
				for _, vid in ipairs(self.voiceOrder) do
					local v = self.voices[vid]
					if v.priority < worstPriority then worstPriority = v.priority worst = vid end
				end
				if not worst or worstPriority >= (priority or 1) then return false end
				self.stop(worst)
				self.steals = self.steals + 1
			end
			self.voices[voiceId] = { id = voiceId, bus = busId, priority = priority or 1 }
			self.voiceOrder[#self.voiceOrder + 1] = voiceId
			return true
		end

		function self.stop(voiceId)
			if not self.voices[voiceId] then return false end
			self.voices[voiceId] = nil
			for i, vid in ipairs(self.voiceOrder) do
				if vid == voiceId then table.remove(self.voiceOrder, i) break end
			end
			return true
		end

		function self.voiceGain(voiceId)
			local v = self.voices[voiceId]
			if not v then return 0 end
			return self.effectiveGain(v.bus)
		end

		function self.snapshot()
			local snap = {}
			for _, name in ipairs(self.order) do
				local b = self.buses[name]
				snap[name] = { gainDb = b.gainDb, mute = b.mute, solo = b.solo }
			end
			return snap
		end

		function self.restore(snap)
			local n = 0
			for name, state in pairs(snap) do
				local bus = self.buses[name]
				if bus then
					bus.gainDb = state.gainDb
					bus.mute = state.mute
					bus.solo = state.solo
					n = n + 1
				end
			end
			self.setSolo(self.order[1], self.buses[self.order[1]] and self.buses[self.order[1]].solo)
			return n
		end

		function self.applyQuality(q)
			q = clamp01(q)
			self.maxVoices = math.max(4, math.floor(self.maxVoices * Mathx.lerp(0.25, 1, q)))
			while #self.voiceOrder > self.maxVoices do self.stop(self.voiceOrder[#self.voiceOrder]) end
			return { maxVoices = self.maxVoices, voices = #self.voiceOrder }
		end

		function self.stats() return { buses = #self.order, voices = #self.voiceOrder,
			maxVoices = self.maxVoices, steals = self.steals, changes = self.changes,
			soloActive = self.soloActive } end
		return self
	end

	------------------------------------------------------------------ 88. SPATIALAUDIO
	-- 3D audio: listener frame, distance attenuation models, stereo panning, Doppler,
	-- occlusion and a distance/priority voice cull so a phone never runs 200 voices.
	function K.spatialaudio(cfg)
		local self = { kind = "spatialaudio", id = cfg.id, sources = {}, order = {},
			listener = { position = v3(), forward = v3(0, 0, 1), up = v3(0, 1, 0),
				velocity = v3() },
			model = cfg.model or "inverse", refDistance = cfg.refDistance or 5,
			maxDistance = cfg.maxDistance or 120, rolloff = cfg.rolloff or 1,
			speedOfSound = cfg.speedOfSound or 343, maxVoices = cfg.maxVoices or 24,
			updates = 0, culled = 0 }

		function self.setListener(position, forward, up, velocity)
			self.listener.position = position or self.listener.position
			self.listener.forward = (forward or self.listener.forward):unit()
			self.listener.up = (up or self.listener.up):unit()
			self.listener.velocity = velocity or v3()
			return self.listener
		end

		function self.addSource(id, position, opts)
			opts = opts or {}
			if self.sources[id] then return nil, "duplicate source" end
			local src = { id = id, position = position or v3(), velocity = opts.velocity or v3(),
				volume = opts.volume or 1, priority = opts.priority or 1,
				occlusion = opts.occlusion or 0, loop = opts.loop or false, active = true }
			self.sources[id] = src
			self.order[#self.order + 1] = id
			return src
		end

		function self.removeSource(id)
			if not self.sources[id] then return false end
			self.sources[id] = nil
			for i, name in ipairs(self.order) do
				if name == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.moveSource(id, position, velocity)
			local src = self.sources[id]
			if not src then return false end
			src.position = position
			src.velocity = velocity or src.velocity
			return true
		end

		function self.attenuation(distance)
			if distance <= self.refDistance then return 1 end
			if distance >= self.maxDistance then return 0 end
			if self.model == "linear" then
				return 1 - (distance - self.refDistance) / (self.maxDistance - self.refDistance)
			elseif self.model == "exponential" then
				return (distance / self.refDistance) ^ (-self.rolloff)
			end
			return self.refDistance / (self.refDistance + self.rolloff * (distance - self.refDistance))
		end

		-- Pan is the projection on the listener's right axis: -1 left, +1 right.
		function self.pan(position)
			local right = self.listener.forward:cross(self.listener.up):unit()
			local delta = position - self.listener.position
			if delta:length() < 1e-6 then return 0 end
			return Mathx.clamp(delta:unit():dot(right), -1, 1)
		end

		function self.doppler(sourceId)
			local src = self.sources[sourceId]
			if not src then return 1 end
			local delta = src.position - self.listener.position
			local distance = delta:length()
			if distance < 1e-6 then return 1 end
			local dir = delta:unit()
			local vs = src.velocity:dot(dir)
			local vl = self.listener.velocity:dot(dir)
			-- dir points from listener to source: a negative vs means the source is closing in
			local ratio = (self.speedOfSound + vl) / math.max(1e-3, self.speedOfSound + vs)
			return Mathx.clamp(ratio, 0.5, 2)
		end

		function self.setOcclusion(id, amount)
			local src = self.sources[id]
			if not src then return false end
			src.occlusion = clamp01(amount)
			return src.occlusion
		end

		function self.gainOf(id)
			local src = self.sources[id]
			if not src or not src.active then return 0 end
			local distance = src.position:distance(self.listener.position)
			return src.volume * self.attenuation(distance) * (1 - src.occlusion * 0.8)
		end

		function self.audible(id, threshold)
			return self.gainOf(id) > (threshold or 0.01)
		end

		-- Keep only the loudest/highest-priority voices; everything else is virtualised.
		function self.cullVoices()
			self.updates = self.updates + 1
			local ranked = {}
			for _, id in ipairs(self.order) do
				ranked[#ranked + 1] = { id = id, score = self.gainOf(id) * self.sources[id].priority }
			end
			table.sort(ranked, function(a, b)
				if a.score == b.score then return a.id < b.id end
				return a.score > b.score
			end)
			local live = {}
			for i, entry in ipairs(ranked) do
				if i <= self.maxVoices and entry.score > 0.001 then
					live[#live + 1] = entry.id
				else
					self.culled = self.culled + 1
				end
			end
			return live
		end

		function self.mixSnapshot()
			local out = {}
			for _, id in ipairs(self.cullVoices()) do
				out[#out + 1] = { id = id, gain = self.gainOf(id), pan = self.pan(self.sources[id].position),
					pitch = self.doppler(id) }
			end
			return out
		end

		function self.applyQuality(q)
			q = clamp01(q)
			self.maxVoices = math.max(4, math.floor(self.maxVoices * Mathx.lerp(0.25, 1, q)))
			self.maxDistance = self.maxDistance * Mathx.lerp(0.4, 1, q)
			return { maxVoices = self.maxVoices, maxDistance = self.maxDistance }
		end

		function self.stats() return { sources = #self.order, maxVoices = self.maxVoices,
			model = self.model, updates = self.updates, culled = self.culled,
			maxDistance = self.maxDistance } end
		return self
	end

	------------------------------------------------------------------ 89. SEQUENCER
	-- Musical time: tempo, bars and beats, cue scheduling with quantized firing, stem
	-- layers driven by an intensity parameter, and quantized transitions between sections.
	function K.sequencer(cfg)
		local self = { kind = "sequencer", id = cfg.id, bpm = cfg.bpm or 120,
			beatsPerBar = cfg.beatsPerBar or 4, beat = 0, cues = {}, layers = {},
			layerOrder = {}, sections = {}, sectionOrder = {}, current = nil,
			pending = nil, intensity = cfg.intensity or 0.5, fired = 0, transitions = 0,
			playing = false }

		function self.setTempo(bpm)
			self.bpm = math.max(20, bpm)
			return self.bpm
		end

		function self.beatDuration() return 60 / self.bpm end

		function self.addSection(name, bars)
			if self.sections[name] then return nil, "duplicate section" end
			local section = { name = name, bars = bars or 4 }
			self.sections[name] = section
			self.sectionOrder[#self.sectionOrder + 1] = name
			if not self.current then self.current = name end
			return section
		end

		function self.addCue(name, atBeat, payload)
			self.cues[#self.cues + 1] = { name = name, at = atBeat, payload = payload,
				fired = false }
			table.sort(self.cues, function(a, b) return a.at < b.at end)
			return #self.cues
		end

		function self.addLayer(name, opts)
			opts = opts or {}
			if self.layers[name] then return nil, "duplicate layer" end
			local layer = { name = name, threshold = opts.threshold or 0,
				gain = 0, target = 0, fade = opts.fade or 1 }
			self.layers[name] = layer
			self.layerOrder[#self.layerOrder + 1] = name
			return layer
		end

		function self.setIntensity(value)
			self.intensity = clamp01(value)
			for _, name in ipairs(self.layerOrder) do
				local layer = self.layers[name]
				layer.target = self.intensity >= layer.threshold and 1 or 0
			end
			return self.intensity
		end

		function self.play() self.playing = true return true end
		function self.stop() self.playing = false return true end

		function self.bar() return math.floor(self.beat / self.beatsPerBar) + 1 end
		function self.beatInBar() return self.beat % self.beatsPerBar end

		function self.quantize(beat, grid)
			local g = grid or self.beatsPerBar
			return math.ceil(beat / g) * g
		end

		function self.transitionTo(section, grid)
			if not self.sections[section] then return nil, "unknown section" end
			self.pending = { section = section, at = self.quantize(self.beat + 0.001, grid) }
			return self.pending.at
		end

		-- Advance musical time; returns every cue that fired during the step.
		function self.advance(dt)
			if not self.playing then return {} end
			local beats = dt / self.beatDuration()
			local from = self.beat
			self.beat = self.beat + beats
			local firedNow = {}
			for _, cue in ipairs(self.cues) do
				if not cue.fired and cue.at > from - 1e-9 and cue.at <= self.beat then
					cue.fired = true
					self.fired = self.fired + 1
					firedNow[#firedNow + 1] = cue
				end
			end
			if self.pending and self.beat >= self.pending.at then
				self.current = self.pending.section
				self.pending = nil
				self.transitions = self.transitions + 1
			end
			for _, name in ipairs(self.layerOrder) do
				local layer = self.layers[name]
				layer.gain = Mathx.damp(layer.gain, layer.target, 1 / math.max(0.05, layer.fade), dt)
			end
			return firedNow
		end

		function self.layerGain(name)
			local layer = self.layers[name]
			if not layer then return 0 end
			return layer.gain
		end

		function self.activeLayers()
			local out = {}
			for _, name in ipairs(self.layerOrder) do
				if self.layers[name].gain > 0.01 then out[#out + 1] = name end
			end
			return out
		end

		function self.reset()
			self.beat = 0
			for _, cue in ipairs(self.cues) do cue.fired = false end
			return true
		end

		function self.stats() return { bpm = self.bpm, beat = self.beat, bar = self.bar(),
			cues = #self.cues, layers = #self.layerOrder, sections = #self.sectionOrder,
			current = self.current, intensity = self.intensity, fired = self.fired,
			transitions = self.transitions, playing = self.playing } end
		return self
	end

	K.NAMES = { "emitter", "particles", "forcefield", "ribbon",
		"dsp", "mixer", "spatialaudio", "sequencer" }

	return K
end
