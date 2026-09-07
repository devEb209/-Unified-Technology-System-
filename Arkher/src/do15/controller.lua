-- ARKHER D-O15 :: Adaptive Quality Controller
-- Closed-loop controller that holds a target frame time by moving a single scalar
-- "quality level" and projecting it onto every subsystem's knobs. Hysteresis and
-- perceptual weighting prevent visible pumping.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Device = A:import("arkher/do15/device")
	local Controller = {}
	Controller.__index = Controller

	-- 15 dimensions of optimization (the "15" in D-O15)
	Controller.DIMENSIONS = {
		"resolution", "geometry", "shadows", "lighting", "reflections", "postfx",
		"particles", "textures", "animation", "physics", "ai", "audio",
		"streaming", "network", "simulation",
	}

	-- how visible each dimension is to a player (perceptual cost of cutting it)
	Controller.PERCEPTUAL_WEIGHT = {
		resolution = 1.00, geometry = 0.86, shadows = 0.52, lighting = 0.78, reflections = 0.35,
		postfx = 0.45, particles = 0.55, textures = 0.80, animation = 0.72, physics = 0.60,
		ai = 0.40, audio = 0.50, streaming = 0.30, network = 0.25, simulation = 0.33,
	}

	function Controller.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Controller)
		self.targetFrameMs = opts.targetFrameMs or 16.6
		self.level = opts.level or 1.0            -- 0 = minimum, 1 = maximum quality
		self.minLevel = opts.minLevel or 0.15
		self.maxLevel = opts.maxLevel or 1.0
		self.samples = C.ring(opts.window or 60)
		self.kp = opts.kp or 0.035
		self.ki = opts.ki or 0.004
		self.kd = opts.kd or 0.010
		self.integral = 0
		self.lastError = 0
		self.hysteresis = opts.hysteresis or 0.8
		self.cooldown = 0
		self.dimensions = {}
		for _, d in ipairs(Controller.DIMENSIONS) do self.dimensions[d] = 1.0 end
		self.locked = {}
		self.changes = 0
		self.history = C.ring(120)
		self.mode = opts.mode or "balanced"       -- battery | balanced | quality
		return self
	end

	function Controller:setTarget(ms) self.targetFrameMs = ms end
	function Controller:lock(dimension, value)
		self.locked[dimension] = value
		self.dimensions[dimension] = value
	end
	function Controller:unlock(dimension) self.locked[dimension] = nil end

	function Controller:submitFrame(frameMs)
		self.samples:push(frameMs)
		return self.samples:average()
	end

	-- one control step; returns new level and the dimension vector
	function Controller:step(dt)
		local avg = self.samples:average()
		if self.samples.size < 6 then return self.level, self.dimensions end
		local err = (self.targetFrameMs - avg) / self.targetFrameMs   -- >0 means we have headroom
		self.integral = Mathx.clamp(self.integral + err * dt, -3, 3)
		local derivative = (err - self.lastError) / math.max(dt, 1e-4)
		self.lastError = err

		local delta = self.kp * err + self.ki * self.integral + self.kd * derivative
		-- asymmetric response: drop fast when late, recover slowly (avoids oscillation)
		if delta < 0 then delta = delta * 2.4 else delta = delta * 0.55 end

		if self.cooldown > 0 then
			self.cooldown = self.cooldown - dt
			if delta > 0 then delta = 0 end
		end

		local newLevel = Mathx.clamp(self.level + delta, self.minLevel, self.maxLevel)
		if math.abs(newLevel - self.level) > 0.005 then
			self.level = newLevel
			self.changes = self.changes + 1
			if delta < 0 then self.cooldown = self.hysteresis end
		end
		self:project()
		self.history:push({ level = self.level, avgMs = avg })
		return self.level, self.dimensions
	end

	-- project the scalar level onto each dimension, cutting the least perceptible first
	function Controller:project()
		local modeBias = { battery = 0.75, balanced = 1.0, quality = 1.2 }
		local bias = modeBias[self.mode] or 1.0
		for _, d in ipairs(Controller.DIMENSIONS) do
			if self.locked[d] then
				self.dimensions[d] = self.locked[d]
			else
				local w = Controller.PERCEPTUAL_WEIGHT[d] or 0.5
				-- low-weight dimensions degrade earlier and harder
				local exponent = 0.45 + w * 1.35
				local v = self.level ^ (1 / exponent)
				self.dimensions[d] = Mathx.clamp(v * bias, 0.05, 1.0)
			end
		end
		return self.dimensions
	end

	function Controller:applyToPreset(preset)
		local d = self.dimensions
		local out = {}
		for k, v in pairs(preset) do out[k] = v end
		out.renderScale = Mathx.clamp((preset.renderScale or 1) * (0.55 + 0.45 * d.resolution), 0.4, 1.0)
		out.lodBias = (preset.lodBias or 1) * (1 + (1 - d.geometry) * 1.6)
		out.vfxDensity = (preset.vfxDensity or 1) * d.particles
		out.animationRate = math.max(12, math.floor((preset.animationRate or 30) * d.animation))
		out.physicsRate = math.max(15, math.floor((preset.physicsRate or 30) * d.physics))
		out.npcTickRate = math.max(1, math.floor((preset.npcTickRate or 6) * d.ai))
		out.textureRes = math.max(128, 2 ^ math.floor(Mathx.log2((preset.textureRes or 512) * d.textures)))
		out.shadows = (d.shadows < 0.35) and false or preset.shadows
		out.reflections = (d.reflections < 0.4) and false or preset.reflections
		return out
	end

	function Controller:bindDevice(profile)
		local desc = Device.describe(profile)
		self.targetFrameMs = desc.budgets.frameMs
		self.basePreset = desc.quality
		self.tier = desc.tier
		if desc.budgets.batteryAware then self.mode = "battery" end
		return desc
	end

	function Controller:currentPreset()
		return self:applyToPreset(self.basePreset or Device.qualityPreset("mobile"))
	end

	function Controller:stability()
		local list = {}
		for i = 1, self.history.size do
			local h = self.history:get(i)
			if h then list[#list + 1] = h.level end
		end
		if #list < 3 then return 1 end
		return 1 - math.min(1, Mathx.stddev(list) * 4)
	end

	function Controller:report()
		return { level = self.level, target = self.targetFrameMs, avgMs = self.samples:average(),
			dimensions = self.dimensions, changes = self.changes, stability = self:stability(),
			mode = self.mode, tier = self.tier }
	end

	return Controller

end
