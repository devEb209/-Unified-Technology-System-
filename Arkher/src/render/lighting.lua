-- ARKHER RENDER :: Lighting, Sky and Global Illumination Framework
-- Time of day -> sun/moon rig -> clustered local lights -> irradiance probe GI ->
-- atmospheric depth -> exposure -> tonemap. All of it computed, all of it budgeted.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local v3 = Vec.vec3

	local Lighting = {}
	Lighting.__index = Lighting

	-- Colour temperature of daylight through the day, in Kelvin.
	local function kelvinToRGB(k)
		k = Mathx.clamp(k, 1500, 12000) / 100
		local r, g, b
		if k <= 66 then
			r = 255
			g = Mathx.clamp(99.47 * math.log(k) - 161.12, 0, 255)
		else
			r = Mathx.clamp(329.7 * ((k - 60) ^ -0.1332), 0, 255)
			g = Mathx.clamp(288.12 * ((k - 60) ^ -0.0755), 0, 255)
		end
		if k >= 66 then
			b = 255
		elseif k <= 19 then
			b = 0
		else
			b = Mathx.clamp(138.52 * math.log(k - 10) - 305.04, 0, 255)
		end
		return math.floor(r) * 65536 + math.floor(g) * 256 + math.floor(b)
	end
	Lighting.kelvinToRGB = kelvinToRGB

	function Lighting.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Lighting)
		self.rig = Kits.create("lightrig", { id = "world.lights", maxActive = opts.maxActive or 8 })
		self.probes = Kits.create("probe", { id = "world.gi", spacing = opts.probeSpacing or 24 })
		self.bounds = opts.bounds or Spatial.aabb(v3(-256, 0, -256), v3(256, 128, 256))
		self.timeOfDay = opts.timeOfDay or 12.0
		self.exposure = 1.0
		self.fog = { density = opts.fogDensity or 0.0018, height = opts.fogHeight or 120,
			color = 0xA8BED8, start = opts.fogStart or 80 }
		self.shadowBudget = opts.shadowBudget or 2
		self.cascades = 3
		self.rig.addLight("sun", { type = "directional", intensity = 3, shadows = true,
			color = 0xFFF2D8 })
		self.rig.addLight("moon", { type = "directional", intensity = 0.0, shadows = false,
			color = 0x9FB4D8 })
		self.rig.sun = "sun"
		self.baked = false
		self:setTimeOfDay(self.timeOfDay)
		return self
	end

	-- ------------------------------------------------------------------ sky model
	-- Sun elevation from a 24h clock; everything else (colour, ambient, fog) follows it.
	function Lighting:setTimeOfDay(hours)
		self.timeOfDay = hours % 24
		local t = (self.timeOfDay - 6) / 12          -- 0 at sunrise, 1 at sunset
		local elevation = math.sin(t * math.pi) * (math.pi / 2)
		self.sunElevation = elevation
		local sun = self.rig.lights.sun
		local moon = self.rig.lights.moon
		local day = math.max(0, math.sin(t * math.pi))
		sun.direction = v3(math.cos(elevation), -math.max(0.02, math.sin(elevation)), 0.35):unit()
		sun.intensity = day * 3.2
		-- warm at the horizon, neutral at noon
		local kelvin = Mathx.lerp(2100, 6500, Mathx.clamp(day * 1.4, 0, 1))
		sun.color = kelvinToRGB(kelvin)
		moon.intensity = (1 - day) * 0.35
		moon.direction = v3(-math.cos(elevation), -0.6, -0.35):unit()
		self.ambient = 0.02 + day * 0.22
		self.rig.ambient = self.ambient
		self.skyLuminance = 0.005 + day * 1.2
		self.fog.color = day > 0.15 and 0xA8BED8 or 0x1A2230
		return { elevation = elevation, intensity = sun.intensity, ambient = self.ambient,
			kelvin = kelvin, day = day }
	end

	function Lighting:advanceTime(minutes)
		return self:setTimeOfDay(self.timeOfDay + (minutes or 1) / 60)
	end

	function Lighting:isNight() return self.rig.lights.sun.intensity < 0.15 end

	-- ------------------------------------------------------------------ local lights
	function Lighting:addLight(id, opts)
		local light = self.rig.addLight(id, opts)
		self.dirtyGI = true
		return light
	end

	function Lighting:removeLight(id)
		local ok = self.rig.remove(id)
		if ok then self.dirtyGI = true end
		return ok
	end

	function Lighting:cluster(divisions)
		return self.rig.cluster(self.bounds, divisions or 4)
	end

	-- The list a renderer should actually bind for one draw, already budgeted.
	function Lighting:lightsFor(point)
		local important = self.rig.importance(point)
		local out = {}
		for _, item in ipairs(important) do
			local light = self.rig.lights[item.id]
			out[#out + 1] = { id = item.id, score = item.score, type = light.type,
				color = light.color, intensity = light.intensity, position = light.position,
				direction = light.direction, range = light.range }
		end
		return out
	end

	function Lighting:shadowCasters() return self.rig.shadowCasters(self.shadowBudget) end

	function Lighting:cascadeSplits(near, far)
		return self.rig.cascadeSplits(near or 1, far or 500, self.cascades, 0.75)
	end

	-- ------------------------------------------------------------------ global illumination
	-- Probe radiance: sky above, bounce from the ground, plus local light contribution.
	function Lighting:radianceAt(position, direction)
		local sky = math.max(0, direction.y) * self.skyLuminance
		local ground = math.max(0, -direction.y) * self.skyLuminance * 0.25
		local sun = self.rig.lights.sun
		local sunDot = math.max(0, direction:dot(-sun.direction))
		local direct = (sunDot ^ 8) * sun.intensity * 0.35
		local local_ = 0
		for _, id in ipairs(self.rig.order) do
			local light = self.rig.lights[id]
			if light.type == "point" and light.enabled then
				local d = light.position:distance(position)
				if d < light.range then
					local atten = 1 - d / light.range
					local_ = local_ + light.intensity * atten * atten * 0.5
				end
			end
		end
		return sky + ground + direct + local_ + self.ambient
	end

	function Lighting:bakeGI(spacing)
		self.probes.place(self.bounds, spacing or self.probes.spacing)
		local n = self.probes.bake(function(pos, dir) return self:radianceAt(pos, dir) end, 32)
		self.baked = true
		self.dirtyGI = false
		return n
	end

	function Lighting:irradiance(point, normal)
		if not self.baked then return self.ambient end
		return self.probes.sampleAt(point, normal)
	end

	function Lighting:invalidateGI(bounds)
		return self.probes.invalidate(bounds or self.bounds)
	end

	-- Incremental relight: the only sane way to move the sun on a phone.
	function Lighting:relight(budget)
		return self.probes.rebake(function(pos, dir) return self:radianceAt(pos, dir) end, budget or 8)
	end

	-- ------------------------------------------------------------------ atmosphere
	-- Exponential height fog: the cheapest, most convincing depth cue there is.
	function Lighting:fogFactor(distance, height)
		local d = math.max(0, distance - self.fog.start)
		local heightFalloff = math.exp(-math.max(0, height or 0) / math.max(1, self.fog.height))
		return Mathx.clamp(1 - math.exp(-d * self.fog.density * heightFalloff), 0, 1)
	end

	function Lighting:applyFog(color, distance, height)
		local f = self:fogFactor(distance, height)
		local cr, cg, cb = math.floor(color / 65536) % 256, math.floor(color / 256) % 256, color % 256
		local fr, fg, fb = math.floor(self.fog.color / 65536) % 256,
			math.floor(self.fog.color / 256) % 256, self.fog.color % 256
		return math.floor(Mathx.lerp(cr, fr, f)) * 65536
			+ math.floor(Mathx.lerp(cg, fg, f)) * 256
			+ math.floor(Mathx.lerp(cb, fb, f))
	end

	-- ------------------------------------------------------------------ exposure & tonemap
	function Lighting:autoExposure(averageLuminance, dt)
		local target = 1 / (1.2 * math.max(0.02, averageLuminance or self.skyLuminance))
		target = Mathx.clamp(target, 0.35, 6.0)
		self.exposure = Mathx.damp(self.exposure, target, 2.5, dt or (1 / 60))
		return self.exposure
	end

	-- ACES-style filmic curve: highlights roll off instead of clipping to white.
	function Lighting:tonemap(value)
		local x = math.max(0, value * self.exposure)
		local a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
		return Mathx.clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1)
	end

	function Lighting:tonemapColor(color)
		local r, g, b = math.floor(color / 65536) % 256, math.floor(color / 256) % 256, color % 256
		local tr = math.floor(self:tonemap(r / 255) * 255 + 0.5)
		local tg = math.floor(self:tonemap(g / 255) * 255 + 0.5)
		local tb = math.floor(self:tonemap(b / 255) * 255 + 0.5)
		return tr * 65536 + tg * 256 + tb
	end

	-- ------------------------------------------------------------------ quality control
	-- D-O15 asks for a level, lighting gives back what it can afford.
	function Lighting:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.rig.maxActive = math.max(2, math.floor(2 + quality * 10))
		self.shadowBudget = quality > 0.7 and 2 or (quality > 0.35 and 1 or 0)
		self.cascades = quality > 0.7 and 3 or (quality > 0.4 and 2 or 1)
		self.probes.spacing = quality > 0.6 and 24 or 48
		return { maxActive = self.rig.maxActive, shadowBudget = self.shadowBudget,
			cascades = self.cascades, probeSpacing = self.probes.spacing }
	end

	function Lighting:report()
		return {
			timeOfDay = self.timeOfDay, night = self:isNight(),
			sunIntensity = self.rig.lights.sun.intensity, ambient = self.ambient,
			lights = #self.rig.order, maxActive = self.rig.maxActive,
			shadowCasters = #self:shadowCasters(), cascades = self.cascades,
			probes = self.probes.stats().probes, dirtyProbes = self.probes.dirtyCount(),
			exposure = self.exposure, fogDensity = self.fog.density,
			giMemoryBytes = self.probes.memoryBytes(),
		}
	end

	return Lighting
end
