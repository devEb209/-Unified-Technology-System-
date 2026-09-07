-- ARKHER PHYSICS :: Physics World (ARKHER Physics Abstraction)
-- A complete deterministic rigid-body world: broadphase, narrow phase, sequential impulse
-- solving, joints, queries, sleeping, substepping and a D-O15 time budget. Roblox physics is
-- one possible *output* of this world, never its brain.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")
	local v3 = Vec.vec3

	local World = {}
	World.__index = World

	function World.new(opts)
		opts = opts or {}
		local self = setmetatable({}, World)
		self.gravity = opts.gravity or v3(0, -9.81, 0)
		self.fixedStep = opts.fixedStep or (1 / 60)
		self.maxSubsteps = opts.maxSubsteps or 4
		self.bodies = {}
		self.order = {}
		self.colliders = {}
		self.contacts = Kits.create("contact", { id = "world.contacts" })
		self.constraints = Kits.create("constraint", { id = "world.constraints",
			iterations = opts.iterations or 6 })
		self.queries = Kits.create("raycaster", { id = "world.queries",
			cellSize = opts.cellSize or 16 })
		self.hash = Spatial.spatialHash(opts.cellSize or 16)
		self.accumulator = 0
		self.time = 0
		self.steps = 0
		self.pairsTested = 0
		self.layers = { default = { default = true } }
		self.onCollision = Signal.new("physics.collision")
		self.onTrigger = Signal.new("physics.trigger")
		self.budgetMs = opts.budgetMs or 4.0
		self.lastManifolds = {}
		return self
	end

	-- ------------------------------------------------------------------ authoring
	function World:addBody(id, opts)
		opts = opts or {}
		if self.bodies[id] then return nil, "duplicate body" end
		local body = Kits.create("rigidbody", {
			id = id, position = opts.position or v3(), mass = opts.mass or 1,
			kinematic = opts.kinematic, restitution = opts.restitution,
			friction = opts.friction, radius = opts.radius or 0.5,
			gravityScale = opts.gravityScale })
		local collider = Kits.create("collider", {
			id = id, shape = opts.shape or "sphere", center = body.position,
			radius = opts.radius or 0.5, halfExtents = opts.halfExtents,
			height = opts.height, layer = opts.layer or "default", trigger = opts.trigger })
		self.bodies[id] = body
		self.colliders[id] = collider
		self.order[#self.order + 1] = id
		self.hash:insert(id, body.position)
		self.queries.register(collider)
		return body, collider
	end

	function World:removeBody(id)
		if not self.bodies[id] then return false end
		self.hash:remove(id)
		self.queries.unregister(id)
		self.bodies[id] = nil
		self.colliders[id] = nil
		for i, k in ipairs(self.order) do
			if k == id then table.remove(self.order, i) break end
		end
		return true
	end

	function World:body(id) return self.bodies[id] end
	function World:collider(id) return self.colliders[id] end

	function World:setLayerRule(a, b, collide)
		self.layers[a] = self.layers[a] or {}
		self.layers[b] = self.layers[b] or {}
		self.layers[a][b] = collide and true or false
		self.layers[b][a] = collide and true or false
		return true
	end

	function World:layersCollide(a, b)
		local rule = self.layers[a]
		if rule == nil then return true end
		if rule[b] == nil then return true end
		return rule[b]
	end

	function World:addJoint(id, opts) return self.constraints.addJoint(id, opts) end

	-- ------------------------------------------------------------------ broadphase
	-- Spatial hash + AABB rejection: only plausible pairs reach the narrow phase.
	function World:broadphase()
		local pairs_ = {}
		local seen = {}
		for _, id in ipairs(self.order) do
			local body = self.bodies[id]
			if not body.sleeping then
				local collider = self.colliders[id]
				local box = collider.aabb()
				local radius = (box.max - box.min):length()
				for _, entry in ipairs(self.hash:queryRadius(body.position, radius + 2)) do
					local otherId = entry.id or entry
					if otherId ~= id then
						local key = (id < otherId) and (id .. "|" .. otherId) or (otherId .. "|" .. id)
						if not seen[key] then
							seen[key] = true
							local other = self.colliders[otherId]
							if other and self:layersCollide(collider.layer, other.layer)
								and box:intersects(other.aabb()) then
								pairs_[#pairs_ + 1] = { collider, other }
							end
						end
					end
				end
			end
		end
		self.pairsTested = self.pairsTested + #pairs_
		return pairs_
	end

	-- ------------------------------------------------------------------ simulation
	function World:substep(dt)
		self.steps = self.steps + 1
		for _, id in ipairs(self.order) do
			local body = self.bodies[id]
			body.integrate(dt, self.gravity)
			local collider = self.colliders[id]
			collider.setCenter(body.position)
			self.hash:update(id, body.position)
		end
		local manifolds = self.contacts.generate(self:broadphase())
		self.lastManifolds = manifolds
		self.constraints.solveContacts(manifolds, self.bodies, dt)
		self.constraints.correctPositions(manifolds, self.bodies)
		self.constraints.solveJoints(self.bodies, dt)
		for _, id in ipairs(self.order) do
			self.colliders[id].setCenter(self.bodies[id].position)
		end
		for _, m in ipairs(manifolds) do
			if m.trigger then
				self.onTrigger:fire(m)
			else
				self.onCollision:fire(m)
			end
		end
		self.time = self.time + dt
		return #manifolds
	end

	-- Fixed-timestep accumulator: identical results at 30, 60 or 144 fps.
	function World:step(dt)
		self.accumulator = self.accumulator + math.min(dt, self.fixedStep * self.maxSubsteps)
		local substeps = 0
		local collisions = 0
		while self.accumulator >= self.fixedStep and substeps < self.maxSubsteps do
			collisions = collisions + self:substep(self.fixedStep)
			self.accumulator = self.accumulator - self.fixedStep
			substeps = substeps + 1
		end
		return { substeps = substeps, collisions = collisions, time = self.time }
	end

	function World:run(seconds, dt)
		dt = dt or self.fixedStep
		local iterations = math.floor(seconds / dt)
		for _ = 1, iterations do self:step(dt) end
		return self.time
	end

	-- ------------------------------------------------------------------ queries
	function World:raycast(origin, direction, maxDist, layer)
		local filter = layer and function(c) return c.layer == layer end or nil
		return self.queries.raycast(origin, direction, maxDist, filter)
	end

	function World:spherecast(origin, direction, radius, maxDist)
		return self.queries.spherecast(origin, direction, radius, maxDist)
	end

	function World:overlapSphere(center, radius)
		return self.queries.overlapSphere(center, radius)
	end

	-- Radial explosion: a real impulse falloff, not a scripted push.
	function World:explode(center, radius, force)
		local affected = 0
		for _, id in ipairs(self:overlapSphere(center, radius)) do
			local body = self.bodies[id]
			if body and body.invMass > 0 then
				local delta = body.position - center
				local distance = math.max(0.001, delta:length())
				local falloff = math.max(0, 1 - distance / radius)
				body.applyImpulse(delta * (1 / distance) * (force * falloff))
				affected = affected + 1
			end
		end
		return affected
	end

	-- ------------------------------------------------------------------ D-O15
	-- Cheaper physics under pressure: fewer substeps, fewer iterations, earlier sleeping.
	function World:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.maxSubsteps = math.max(1, math.floor(1 + quality * 3))
		self.constraints.iterations = math.max(2, math.floor(2 + quality * 6))
		for _, id in ipairs(self.order) do
			self.bodies[id].sleepThreshold = Mathx.lerp(0.25, 0.03, quality)
		end
		return { maxSubsteps = self.maxSubsteps, iterations = self.constraints.iterations }
	end

	function World:sleepingCount()
		local n = 0
		for _, id in ipairs(self.order) do
			if self.bodies[id].sleeping then n = n + 1 end
		end
		return n
	end

	function World:totalEnergy()
		local total = 0
		for _, id in ipairs(self.order) do total = total + self.bodies[id].kineticEnergy() end
		return total
	end

	-- Determinism proof: the same world, stepped the same way, hashes the same.
	function World:checksum()
		local parts = {}
		for _, id in ipairs(self.order) do
			local b = self.bodies[id]
			parts[#parts + 1] = string.format("%s:%.4f,%.4f,%.4f", id,
				b.position.x, b.position.y, b.position.z)
		end
		table.sort(parts)
		return Hash.fnv1a(table.concat(parts, "|"))
	end

	function World:report()
		return {
			bodies = #self.order, sleeping = self:sleepingCount(),
			steps = self.steps, time = self.time, pairsTested = self.pairsTested,
			contacts = #self.lastManifolds, contactStats = self.contacts.stats(),
			solver = self.constraints.stats(), queries = self.queries.stats(),
			energy = self:totalEnergy(), checksum = self:checksum(),
			maxSubsteps = self.maxSubsteps,
		}
	end

	return World
end
