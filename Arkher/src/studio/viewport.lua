-- ARKHER STUDIO :: Viewport + Universal Transform Framework
-- Camera model, ray picking, gizmo math, snapping, measurement and framing.
-- Pure math over the ARKHER platform abstraction: identical in Studio, in game and headless.
--@arkher-module
return function(A)
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local Mathx = A:import("arkher/kernel/mathx")
	local Viewport = {}
	Viewport.__index = Viewport

	Viewport.MODES = { "select", "translate", "rotate", "scale", "measure", "paint", "sculpt" }
	Viewport.SPACES = { "world", "local", "screen", "parent" }
	Viewport.PIVOTS = { "center", "origin", "primary", "cursor", "bounds" }

	function Viewport.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Viewport)
		self.camera = {
			position = opts.position or Vec.vec3(40, 30, 40),
			target = opts.target or Vec.vec3(0, 0, 0),
			up = Vec.vec3(0, 1, 0),
			fov = opts.fov or math.rad(70),
			near = 0.1, far = opts.far or 5000,
			orthographic = false, orthoScale = 20,
		}
		self.width = opts.width or 1280
		self.height = opts.height or 720
		self.mode = "select"
		self.space = "world"
		self.pivot = "center"
		self.snap = { translate = opts.snapTranslate or 1, rotate = math.rad(15), scale = 0.1, enabled = true }
		self.gizmo = { active = false, axis = nil, plane = nil, dragStart = nil, delta = Vec.vec3() }
		self.measurements = {}
		self.stats = { picks = 0, drags = 0, framings = 0 }
		return self
	end

	function Viewport:aspect() return self.width / math.max(1, self.height) end

	function Viewport:forward() return (self.camera.target - self.camera.position):unit() end
	function Viewport:right() return self:forward():cross(self.camera.up):unit() end

	function Viewport:frustum()
		return Spatial.frustumFromCamera(self.camera.position, self:forward(), self.camera.up,
			self.camera.fov, self:aspect(), self.camera.near, self.camera.far)
	end

	-- screen point (pixels) -> world ray
	function Viewport:screenToRay(x, y)
		local ndcX = (2 * x / self.width) - 1
		local ndcY = 1 - (2 * y / self.height)
		local tanHalf = math.tan(self.camera.fov / 2)
		local f = self:forward()
		local r = self:right()
		local u = r:cross(f):unit()
		local dir = (f + r * (ndcX * tanHalf * self:aspect()) + u * (ndcY * tanHalf)):unit()
		return self.camera.position, dir
	end

	function Viewport:worldToScreen(p)
		local f = self:forward()
		local r = self:right()
		local u = r:cross(f):unit()
		local rel = p - self.camera.position
		local z = rel:dot(f)
		if z <= 0 then return nil end
		local tanHalf = math.tan(self.camera.fov / 2)
		local x = (rel:dot(r) / (z * tanHalf * self:aspect()) + 1) * 0.5 * self.width
		local y = (1 - rel:dot(u) / (z * tanHalf)) * 0.5 * self.height
		return x, y, z
	end

	-- pick the nearest primitive under a screen point using the BVH
	function Viewport:pick(x, y, bvh, maxDist)
		self.stats.picks = self.stats.picks + 1
		local origin, dir = self:screenToRay(x, y)
		local hit, t = bvh:raycast(origin, dir, maxDist or self.camera.far)
		if not hit then return nil end
		return hit, origin + dir * t, t
	end

	function Viewport:pickRegion(x0, y0, x1, y1, candidates)
		local out = {}
		local minX, maxX = math.min(x0, x1), math.max(x0, x1)
		local minY, maxY = math.min(y0, y1), math.max(y0, y1)
		for _, c in ipairs(candidates) do
			local sx, sy = self:worldToScreen(c.position)
			if sx and sx >= minX and sx <= maxX and sy >= minY and sy <= maxY then out[#out + 1] = c.id end
		end
		return out
	end

	function Viewport:applySnap(value, kind)
		if not self.snap.enabled then return value end
		local grid = self.snap[kind or "translate"]
		if not grid or grid <= 0 then return value end
		if type(value) == "number" then return Mathx.snap(value, grid) end
		return Vec.vec3(Mathx.snap(value.x, grid), Mathx.snap(value.y, grid), Mathx.snap(value.z, grid))
	end

	function Viewport:beginDrag(axis, worldPoint)
		self.gizmo.active = true
		self.gizmo.axis = axis
		self.gizmo.dragStart = worldPoint
		self.gizmo.delta = Vec.vec3()
		self.stats.drags = self.stats.drags + 1
		return true
	end

	function Viewport:updateDrag(worldPoint)
		if not self.gizmo.active then return nil end
		local raw = worldPoint - self.gizmo.dragStart
		local axis = self.gizmo.axis
		local constrained = raw
		if axis == "x" then constrained = Vec.vec3(raw.x, 0, 0)
		elseif axis == "y" then constrained = Vec.vec3(0, raw.y, 0)
		elseif axis == "z" then constrained = Vec.vec3(0, 0, raw.z)
		elseif axis == "xy" then constrained = Vec.vec3(raw.x, raw.y, 0)
		elseif axis == "xz" then constrained = Vec.vec3(raw.x, 0, raw.z)
		elseif axis == "yz" then constrained = Vec.vec3(0, raw.y, raw.z) end
		self.gizmo.delta = self:applySnap(constrained, self.mode == "rotate" and "rotate" or "translate")
		return self.gizmo.delta
	end

	function Viewport:endDrag()
		local delta = self.gizmo.delta
		self.gizmo.active = false
		self.gizmo.axis = nil
		return delta
	end

	function Viewport:pivotPoint(bounds, primary, cursor)
		if self.pivot == "origin" then return Vec.vec3(0, 0, 0) end
		if self.pivot == "cursor" and cursor then return cursor end
		if self.pivot == "primary" and primary then return primary end
		if bounds then return bounds:center() end
		return Vec.vec3(0, 0, 0)
	end

	-- frame the camera on a bounding box (the "focus selection" command)
	function Viewport:frame(bounds, padding)
		self.stats.framings = self.stats.framings + 1
		local center = bounds:center()
		local size = bounds:size()
		local radius = math.max(size.x, size.y, size.z) * 0.5 * (padding or 1.6)
		local distance = radius / math.tan(self.camera.fov / 2)
		local dir = (self.camera.position - center):unit()
		if dir:length() < 1e-6 then dir = Vec.vec3(1, 1, 1):unit() end
		self.camera.target = center
		self.camera.position = center + dir * distance
		return distance
	end

	function Viewport:orbit(deltaYaw, deltaPitch)
		local offset = self.camera.position - self.camera.target
		local radius = offset:length()
		local yaw = math.atan(offset.z, offset.x) + deltaYaw
		local pitch = math.asin(Mathx.clamp(offset.y / math.max(radius, 1e-6), -0.999, 0.999)) + deltaPitch
		pitch = Mathx.clamp(pitch, -1.5, 1.5)
		self.camera.position = self.camera.target + Vec.vec3(
			radius * math.cos(pitch) * math.cos(yaw),
			radius * math.sin(pitch),
			radius * math.cos(pitch) * math.sin(yaw))
		return self.camera.position
	end

	function Viewport:dolly(amount)
		local dir = self:forward()
		local dist = (self.camera.target - self.camera.position):length()
		local move = math.min(amount, dist - 1)
		self.camera.position = self.camera.position + dir * move
		return (self.camera.target - self.camera.position):length()
	end

	function Viewport:pan(dx, dy)
		local r = self:right()
		local u = r:cross(self:forward()):unit()
		local delta = r * dx + u * dy
		self.camera.position = self.camera.position + delta
		self.camera.target = self.camera.target + delta
		return delta
	end

	function Viewport:measure(a, b)
		local d = a:distance(b)
		self.measurements[#self.measurements + 1] = { a = a, b = b, distance = d }
		return d
	end

	function Viewport:setMode(mode)
		for _, m in ipairs(Viewport.MODES) do if m == mode then self.mode = mode return true end end
		return false
	end

	function Viewport:report()
		return { mode = self.mode, space = self.space, pivot = self.pivot, snap = self.snap,
			camera = { position = self.camera.position:toArray(), fov = self.camera.fov },
			stats = self.stats, measurements = #self.measurements }
	end

	return Viewport

end
