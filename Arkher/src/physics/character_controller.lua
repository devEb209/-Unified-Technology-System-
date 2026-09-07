-- ARKHER PHYSICS :: Character Controller
-- The bridge between the physics world and a controllable body: capsule sweeps against real
-- colliders, ground probing, step-up, slope handling, moving platforms, push-out depenetration
-- and input buffering. This is what makes movement *feel* right on a phone.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local CharacterController = {}
	CharacterController.__index = CharacterController

	function CharacterController.new(world, opts)
		opts = opts or {}
		local self = setmetatable({}, CharacterController)
		self.world = world
		self.controllers = {}
		self.order = {}
		self.groundProbe = opts.groundProbe or 0.35
		self.pushOutIterations = opts.pushOutIterations or 3
		self.inputBuffer = opts.inputBuffer or 0.15
		self.onLand = Signal.new("controller.land")
		self.onStep = Signal.new("controller.step")
		self.sweeps = 0
		self.depenetrations = 0
		self.frame = 0
		return self
	end

	function CharacterController:add(id, opts)
		opts = opts or {}
		if self.controllers[id] then return nil, "duplicate controller" end
		local motor = Kits.create("charmotor", {
			id = id, position = opts.position or v3(),
			radius = opts.radius or 0.4, height = opts.height or 1.8,
			maxSpeed = opts.maxSpeed or 6.5, acceleration = opts.acceleration or 45,
			jumpHeight = opts.jumpHeight or 1.8, stepOffset = opts.stepOffset or 0.4,
			slopeLimit = opts.slopeLimit or math.rad(48) })
		local entry = { id = id, motor = motor, platform = nil, platformOffset = v3(),
			jumpBuffered = -1, wasGrounded = true, landings = 0, steps = 0,
			lastGroundNormal = v3(0, 1, 0), layer = opts.layer or "character" }
		self.controllers[id] = entry
		self.order[#self.order + 1] = id
		return entry
	end

	function CharacterController:remove(id)
		if not self.controllers[id] then return false end
		self.controllers[id] = nil
		for i, k in ipairs(self.order) do
			if k == id then table.remove(self.order, i) break end
		end
		return true
	end

	function CharacterController:get(id) return self.controllers[id] end

	-- ------------------------------------------------------------------ collision callback
	-- Builds the `collide(from, to, radius)` function the motor expects, backed by the world's
	-- spherecast. Returns nil when the path is clear.
	function CharacterController:collideFn(id)
		local entry = self.controllers[id]
		local world = self.world
		return function(from, to, radius)
			self.sweeps = self.sweeps + 1
			local delta = to - from
			local distance = delta:length()
			if distance < 1e-6 or not world then return nil end
			local hit = world:spherecast(from, delta * (1 / distance), radius, distance)
			if not hit then return nil end
			if hit.id == id then return nil end
			entry.lastHit = hit
			return { normal = hit.normal or v3(0, 1, 0), point = hit.point,
				distance = hit.distance or 0, id = hit.id }
		end
	end

	-- Downward probe: is there ground under the capsule, and what is its normal?
	function CharacterController:probeGround(id)
		local entry = self.controllers[id]
		if not entry or not self.world then return false, v3(0, 1, 0) end
		local origin = entry.motor.position
		local hit = self.world:raycast(origin, v3(0, -1, 0),
			entry.motor.height * 0.5 + self.groundProbe)
		if not hit then return false, v3(0, 1, 0) end
		entry.groundId = hit.id
		return true, hit.normal or v3(0, 1, 0), hit.distance
	end

	-- Step-up: if a forward blocker is lower than stepOffset and there is floor above it, climb.
	function CharacterController:tryStep(id, wish)
		local entry = self.controllers[id]
		if not entry or not self.world then return false end
		local motor = entry.motor
		if not motor.grounded or wish:length() < 1e-4 then return false end
		local dir = wish:unit()
		local ahead = motor.position + dir * (motor.radius + 0.05)
		local blocked = self.world:raycast(motor.position, dir, motor.radius + 0.15)
		if not blocked then return false end
		local above = ahead + v3(0, motor.stepOffset + 0.05, 0)
		local floor = self.world:raycast(above, v3(0, -1, 0), motor.stepOffset + 0.1)
		if not floor then return false end
		local rise = (motor.stepOffset + 0.05) - (floor.distance or 0)
		if rise <= 0.01 or rise > motor.stepOffset then return false end
		motor.position = motor.position + v3(0, rise, 0) + dir * 0.02
		entry.steps = entry.steps + 1
		self.onStep:fire({ id = id, rise = rise })
		return true, rise
	end

	-- Depenetration: if the capsule ends the frame inside something, push it out along the
	-- shortest axis instead of letting the solver explode.
	function CharacterController:pushOut(id)
		local entry = self.controllers[id]
		if not entry or not self.world then return 0 end
		local motor = entry.motor
		local moved = 0
		for _ = 1, self.pushOutIterations do
			local overlaps = self.world:overlapSphere(motor.position, motor.radius)
			local corrected = false
			for _, otherId in ipairs(overlaps) do
				if otherId ~= id then
					local collider = self.world:collider(otherId)
					if collider and not collider.trigger then
						local closest = collider.closestPoint(motor.position)
						local delta = motor.position - closest
						local distance = delta:length()
						if distance < motor.radius then
							local normal = distance > 1e-6 and delta * (1 / distance) or v3(0, 1, 0)
							motor.position = motor.position + normal * (motor.radius - distance + 0.001)
							self.depenetrations = self.depenetrations + 1
							moved = moved + 1
							corrected = true
						end
					end
				end
			end
			if not corrected then break end
		end
		return moved
	end

	-- ------------------------------------------------------------------ platforms
	function CharacterController:attachPlatform(id, platformId)
		local entry = self.controllers[id]
		if not entry then return false end
		local body = self.world and self.world:body(platformId)
		if not body then return false end
		entry.platform = platformId
		entry.platformOffset = entry.motor.position - body.position
		return true
	end

	function CharacterController:detachPlatform(id)
		local entry = self.controllers[id]
		if not entry then return false end
		entry.platform = nil
		return true
	end

	function CharacterController:followPlatform(id)
		local entry = self.controllers[id]
		if not entry or not entry.platform then return false end
		local body = self.world and self.world:body(entry.platform)
		if not body then entry.platform = nil return false end
		local target = body.position + entry.platformOffset
		local delta = target - entry.motor.position
		entry.motor.position = entry.motor.position + v3(delta.x, 0, delta.z)
		return true, delta
	end

	-- ------------------------------------------------------------------ input
	function CharacterController:requestJump(id)
		local entry = self.controllers[id]
		if not entry then return false end
		if entry.motor.jump() then
			entry.jumpBuffered = -1
			return true
		end
		entry.jumpBuffered = self.inputBuffer
		return false
	end

	-- ------------------------------------------------------------------ frame
	function CharacterController:update(id, wish, dt)
		local entry = self.controllers[id]
		if not entry then return nil end
		local motor = entry.motor
		self:followPlatform(id)
		local grounded, normal = self:probeGround(id)
		motor.setGround(grounded, normal)
		entry.lastGroundNormal = normal
		if entry.jumpBuffered >= 0 then
			entry.jumpBuffered = entry.jumpBuffered - dt
			if grounded and motor.jump() then entry.jumpBuffered = -1 end
		end
		motor.move(wish or v3(), dt, self:collideFn(id))
		self:tryStep(id, wish or v3())
		self:pushOut(id)
		if motor.grounded and not entry.wasGrounded then
			entry.landings = entry.landings + 1
			self.onLand:fire({ id = id, speed = math.abs(motor.velocity.y), position = motor.position })
		end
		entry.wasGrounded = motor.grounded
		if self.world and self.world:body(id) then
			self.world:body(id).teleport(motor.position)
		end
		return { position = motor.position, grounded = motor.grounded,
			state = motor.locomotionState(), speed = motor.speed() }
	end

	function CharacterController:updateAll(dt, wishes)
		self.frame = self.frame + 1
		local results = {}
		for _, id in ipairs(self.order) do
			results[id] = self:update(id, wishes and wishes[id] or v3(), dt)
		end
		return results
	end

	function CharacterController:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.pushOutIterations = math.max(1, math.floor(1 + quality * 3))
		self.groundProbe = Mathx.lerp(0.2, 0.45, quality)
		return { pushOutIterations = self.pushOutIterations, groundProbe = self.groundProbe }
	end

	function CharacterController:report()
		local grounded, landings, steps = 0, 0, 0
		for _, id in ipairs(self.order) do
			local e = self.controllers[id]
			if e.motor.grounded then grounded = grounded + 1 end
			landings = landings + e.landings
			steps = steps + e.steps
		end
		return { controllers = #self.order, grounded = grounded, landings = landings,
			steps = steps, sweeps = self.sweeps, depenetrations = self.depenetrations,
			frame = self.frame, pushOutIterations = self.pushOutIterations }
	end

	return CharacterController
end
