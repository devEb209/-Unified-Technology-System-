-- ARKHER RUNTIME :: Physics / Animation / Character Kits
-- Round 5 machinery (kits 56-67). Same contract as the other kit modules: complete working
-- implementations that catalog systems specialize. Deterministic, platform independent,
-- and budgeted - the physics here is ARKHER's own abstraction, not a wrapper.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 56. RIGIDBODY
	-- Body state and semi-implicit Euler integration with damping, sleeping and impulses.
	function K.rigidbody(cfg)
		local self = { kind = "rigidbody", id = cfg.id,
			position = cfg.position or v3(), velocity = cfg.velocity or v3(),
			angularVelocity = cfg.angularVelocity or v3(), orientation = cfg.orientation or v3(),
			mass = cfg.mass or 1, invMass = 0, force = v3(), torque = v3(),
			linearDamping = cfg.linearDamping or 0.02, angularDamping = cfg.angularDamping or 0.05,
			restitution = cfg.restitution or 0.2, friction = cfg.friction or 0.6,
			gravityScale = cfg.gravityScale or 1, kinematic = cfg.kinematic or false,
			sleeping = false, sleepTimer = 0, sleepThreshold = cfg.sleepThreshold or 0.05,
			steps = 0, radius = cfg.radius or 1 }
		self.invMass = (self.kinematic or self.mass <= 0) and 0 or (1 / self.mass)
		-- solid sphere inertia is a good enough default and keeps the solver stable
		self.inertia = (2 / 5) * self.mass * self.radius * self.radius
		self.invInertia = self.inertia > 0 and (1 / self.inertia) or 0

		function self.setMass(m)
			self.mass = m
			self.invMass = (self.kinematic or m <= 0) and 0 or (1 / m)
			self.inertia = (2 / 5) * m * self.radius * self.radius
			self.invInertia = self.inertia > 0 and (1 / self.inertia) or 0
			return self.invMass
		end

		function self.addForce(f) self.force = self.force + f self.wake() return self.force end
		function self.addTorque(t) self.torque = self.torque + t self.wake() return self.torque end

		function self.applyImpulse(impulse, contactOffset)
			if self.invMass == 0 then return self.velocity end
			self.velocity = self.velocity + impulse * self.invMass
			if contactOffset then
				self.angularVelocity = self.angularVelocity + contactOffset:cross(impulse) * self.invInertia
			end
			self.wake()
			return self.velocity
		end

		function self.wake()
			self.sleeping = false
			self.sleepTimer = 0
			return self
		end

		function self.sleep()
			self.sleeping = true
			self.velocity = v3()
			self.angularVelocity = v3()
			return self
		end

		function self.integrate(dt, gravity)
			self.steps = self.steps + 1
			if self.kinematic then
				self.position = self.position + self.velocity * dt
				return self.position
			end
			if self.sleeping then return self.position end
			gravity = gravity or v3(0, -9.81, 0)
			local acceleration = self.force * self.invMass + gravity * self.gravityScale
			self.velocity = self.velocity + acceleration * dt
			self.velocity = self.velocity * (1 / (1 + self.linearDamping * dt))
			self.position = self.position + self.velocity * dt
			local angularAcc = self.torque * self.invInertia
			self.angularVelocity = self.angularVelocity + angularAcc * dt
			self.angularVelocity = self.angularVelocity * (1 / (1 + self.angularDamping * dt))
			self.orientation = self.orientation + self.angularVelocity * dt
			self.force = v3()
			self.torque = v3()
			-- sleeping: below threshold for a quarter second
			if self.velocity:length() < self.sleepThreshold
				and self.angularVelocity:length() < self.sleepThreshold then
				self.sleepTimer = self.sleepTimer + dt
				if self.sleepTimer > 0.25 then self.sleep() end
			else
				self.sleepTimer = 0
			end
			return self.position
		end

		function self.kineticEnergy()
			local linear = 0.5 * self.mass * self.velocity:lengthSq()
			local angular = 0.5 * self.inertia * self.angularVelocity:lengthSq()
			return linear + angular
		end

		function self.momentum() return self.velocity * self.mass end

		function self.teleport(position)
			self.position = position
			self.velocity = v3()
			self.wake()
			return self.position
		end

		function self.stats() return { id = self.id, mass = self.mass, steps = self.steps,
			sleeping = self.sleeping, speed = self.velocity:length(),
			energy = self.kineticEnergy(), kinematic = self.kinematic } end
		return self
	end

	------------------------------------------------------------------ 57. COLLIDER
	-- Shape definitions with bounds, support points, containment and closest-point queries.
	function K.collider(cfg)
		local self = { kind = "collider", id = cfg.id, shape = cfg.shape or "sphere",
			center = cfg.center or v3(), radius = cfg.radius or 1,
			halfExtents = cfg.halfExtents or v3(1, 1, 1), height = cfg.height or 2,
			layer = cfg.layer or "default", trigger = cfg.trigger or false, queries = 0 }

		function self.setCenter(p) self.center = p return self end

		function self.aabb()
			if self.shape == "sphere" then
				local r = v3(self.radius, self.radius, self.radius)
				return Spatial.aabb(self.center - r, self.center + r)
			elseif self.shape == "capsule" then
				local half = self.height / 2
				local r = v3(self.radius, half + self.radius, self.radius)
				return Spatial.aabb(self.center - r, self.center + r)
			end
			return Spatial.aabb(self.center - self.halfExtents, self.center + self.halfExtents)
		end

		function self.volume()
			if self.shape == "sphere" then return (4 / 3) * math.pi * self.radius ^ 3 end
			if self.shape == "capsule" then
				return math.pi * self.radius ^ 2 * self.height + (4 / 3) * math.pi * self.radius ^ 3
			end
			return 8 * self.halfExtents.x * self.halfExtents.y * self.halfExtents.z
		end

		function self.segment()
			local half = math.max(0, self.height / 2)
			return self.center - v3(0, half, 0), self.center + v3(0, half, 0)
		end

		-- Support point in a direction: the primitive every convex algorithm needs.
		function self.support(direction)
			local d = direction:unit()
			if self.shape == "sphere" then return self.center + d * self.radius end
			if self.shape == "capsule" then
				local a, b = self.segment()
				local point = (d.y >= 0) and b or a
				return point + d * self.radius
			end
			return self.center + v3(
				Mathx.sign(d.x) * self.halfExtents.x,
				Mathx.sign(d.y) * self.halfExtents.y,
				Mathx.sign(d.z) * self.halfExtents.z)
		end

		function self.closestPoint(point)
			self.queries = self.queries + 1
			if self.shape == "sphere" then
				local delta = point - self.center
				local d = delta:length()
				if d <= self.radius then return point, 0 end
				return self.center + delta * (self.radius / d), d - self.radius
			elseif self.shape == "capsule" then
				local a, b = self.segment()
				local ab = b - a
				local t = clamp01((point - a):dot(ab) / math.max(1e-9, ab:dot(ab)))
				local axisPoint = a + ab * t
				local delta = point - axisPoint
				local d = delta:length()
				if d <= self.radius then return point, 0 end
				return axisPoint + delta * (self.radius / d), d - self.radius
			end
			local box = self.aabb()
			local p = v3(
				Mathx.clamp(point.x, box.min.x, box.max.x),
				Mathx.clamp(point.y, box.min.y, box.max.y),
				Mathx.clamp(point.z, box.min.z, box.max.z))
			return p, (p - point):length()
		end

		function self.contains(point)
			local _, distance = self.closestPoint(point)
			return distance <= 1e-6
		end

		function self.expandedAABB(margin)
			local box = self.aabb()
			local m = v3(margin, margin, margin)
			return Spatial.aabb(box.min - m, box.max + m)
		end

		-- A copy of this collider grown by `margin`: the Minkowski trick sweeps rely on.
		function self.expandedBy(margin)
			return K.collider({ id = self.id .. "+", shape = self.shape, center = self.center,
				radius = self.radius + margin, height = self.height,
				halfExtents = self.halfExtents + v3(margin, margin, margin),
				layer = self.layer, trigger = self.trigger })
		end

		function self.stats() return { id = self.id, shape = self.shape, layer = self.layer,
			trigger = self.trigger, volume = self.volume(), queries = self.queries } end
		return self
	end

	------------------------------------------------------------------ 58. CONTACT
	-- Narrow phase: manifolds between colliders, with normal, depth and contact point.
	function K.contact(cfg)
		local self = { kind = "contact", id = cfg.id, manifolds = {}, tests = 0, hits = 0,
			margin = cfg.margin or 0.001 }

		local function sphereSphere(a, b)
			local delta = b.center - a.center
			local dist = delta:length()
			local sum = a.radius + b.radius
			if dist >= sum or dist < 1e-9 then return nil end
			local normal = delta * (1 / dist)
			return { normal = normal, depth = sum - dist,
				point = a.center + normal * (a.radius - (sum - dist) * 0.5) }
		end

		local function sphereBox(sphere, box)
			local closest = box.closestPoint(sphere.center)
			local delta = sphere.center - closest
			local dist = delta:length()
			if dist >= sphere.radius then return nil end
			local normal
			if dist < 1e-9 then
				normal = v3(0, 1, 0)
			else
				normal = delta * (1 / dist)
			end
			return { normal = -normal, depth = sphere.radius - dist, point = closest }
		end

		local function boxBox(a, b)
			local ba, bb = a.aabb(), b.aabb()
			if not ba:intersects(bb) then return nil end
			local overlapX = math.min(ba.max.x, bb.max.x) - math.max(ba.min.x, bb.min.x)
			local overlapY = math.min(ba.max.y, bb.max.y) - math.max(ba.min.y, bb.min.y)
			local overlapZ = math.min(ba.max.z, bb.max.z) - math.max(ba.min.z, bb.min.z)
			local depth, normal = overlapX, v3(Mathx.sign(b.center.x - a.center.x), 0, 0)
			if overlapY < depth then
				depth = overlapY
				normal = v3(0, Mathx.sign(b.center.y - a.center.y), 0)
			end
			if overlapZ < depth then
				depth = overlapZ
				normal = v3(0, 0, Mathx.sign(b.center.z - a.center.z))
			end
			return { normal = normal, depth = depth, point = (a.center + b.center) * 0.5 }
		end

		local function capsuleSphere(capsule, sphere)
			local closest = capsule.closestPoint(sphere.center)
			local delta = sphere.center - closest
			local dist = delta:length()
			if dist >= sphere.radius then return nil end
			local normal = dist < 1e-9 and v3(0, 1, 0) or delta * (1 / dist)
			return { normal = normal, depth = sphere.radius - dist, point = closest }
		end

		function self.test(a, b)
			self.tests = self.tests + 1
			local m
			if a.shape == "sphere" and b.shape == "sphere" then
				m = sphereSphere(a, b)
			elseif a.shape == "sphere" and b.shape == "box" then
				m = sphereBox(a, b)
			elseif a.shape == "box" and b.shape == "sphere" then
				m = sphereBox(b, a)
				if m then m.normal = -m.normal end
			elseif a.shape == "capsule" and b.shape == "sphere" then
				m = capsuleSphere(a, b)
			elseif a.shape == "sphere" and b.shape == "capsule" then
				m = capsuleSphere(b, a)
				if m then m.normal = -m.normal end
			else
				m = boxBox(a, b)
			end
			if m then
				self.hits = self.hits + 1
				m.a = a.id
				m.b = b.id
				m.trigger = a.trigger or b.trigger
			end
			return m
		end

		function self.generate(pairs_)
			self.manifolds = {}
			for _, pair in ipairs(pairs_) do
				local m = self.test(pair[1], pair[2])
				if m then self.manifolds[#self.manifolds + 1] = m end
			end
			return self.manifolds
		end

		function self.deepest()
			local best = nil
			for _, m in ipairs(self.manifolds) do
				if not best or m.depth > best.depth then best = m end
			end
			return best
		end

		function self.triggers()
			local out = {}
			for _, m in ipairs(self.manifolds) do
				if m.trigger then out[#out + 1] = m end
			end
			return out
		end

		function self.clear() self.manifolds = {} return true end

		function self.stats() return { manifolds = #self.manifolds, tests = self.tests,
			hits = self.hits, hitRate = self.tests > 0 and (self.hits / self.tests) or 0 } end
		return self
	end

	------------------------------------------------------------------ 59. CONSTRAINT
	-- Sequential impulse solver: contacts with restitution and friction, distance joints,
	-- warm starting and Baumgarte position correction.
	function K.constraint(cfg)
		local self = { kind = "constraint", id = cfg.id, joints = {}, order = {},
			iterations = cfg.iterations or 6, baumgarte = cfg.baumgarte or 0.2,
			slop = cfg.slop or 0.01, warmStart = cfg.warmStart ~= false,
			cache = {}, solves = 0, impulseTotal = 0 }

		function self.addJoint(id, opts)
			opts = opts or {}
			if self.joints[id] then return nil, "duplicate joint" end
			local joint = { id = id, type = opts.type or "distance", a = opts.a, b = opts.b,
				rest = opts.rest or 1, stiffness = opts.stiffness or 1,
				min = opts.min, max = opts.max, axis = opts.axis or v3(0, 1, 0), broken = false }
			self.joints[id] = joint
			self.order[#self.order + 1] = id
			return joint
		end

		function self.removeJoint(id)
			if not self.joints[id] then return false end
			self.joints[id] = nil
			for i, k in ipairs(self.order) do
				if k == id then table.remove(self.order, i) break end
			end
			return true
		end

		local function contactKey(m) return tostring(m.a) .. ">" .. tostring(m.b) end

		-- One contact resolution pass: normal impulse then Coulomb friction.
		function self.solveContacts(manifolds, bodies, dt)
			self.solves = self.solves + 1
			local applied = 0
			for _ = 1, self.iterations do
				for _, m in ipairs(manifolds) do
					if not m.trigger then
						local a, b = bodies[m.a], bodies[m.b]
						if a and b then
							local invSum = a.invMass + b.invMass
							if invSum > 0 then
								local relative = b.velocity - a.velocity
								local vn = relative:dot(m.normal)
								local restitution = math.min(a.restitution, b.restitution)
								if math.abs(vn) < 1.0 then restitution = 0 end
								local bias = (self.baumgarte / math.max(1e-6, dt))
									* math.max(0, m.depth - self.slop)
								local key = contactKey(m)
								local accumulated = self.warmStart and (self.cache[key] or 0) or 0
								local lambda = -(1 + restitution) * vn + bias
								lambda = lambda / invSum
								local newAccum = math.max(0, accumulated + lambda)
								local delta = newAccum - accumulated
								self.cache[key] = newAccum
								local impulse = m.normal * delta
								a.applyImpulse(-impulse)
								b.applyImpulse(impulse)
								applied = applied + math.abs(delta)
								-- friction along the tangent of the relative motion
								local tangentVel = relative - m.normal * relative:dot(m.normal)
								local tLen = tangentVel:length()
								if tLen > 1e-6 then
									local tangent = tangentVel * (1 / tLen)
									local mu = math.sqrt(a.friction * b.friction)
									local jt = -tangentVel:dot(tangent) / invSum
									local maxFriction = mu * newAccum
									jt = Mathx.clamp(jt, -maxFriction, maxFriction)
									local frictionImpulse = tangent * jt
									a.applyImpulse(-frictionImpulse)
									b.applyImpulse(frictionImpulse)
									applied = applied + math.abs(jt)
								end
							end
						end
					end
				end
			end
			self.impulseTotal = self.impulseTotal + applied
			return applied
		end

		-- Positional correction so stacks do not sink over time.
		function self.correctPositions(manifolds, bodies)
			local corrected = 0
			for _, m in ipairs(manifolds) do
				if not m.trigger then
					local a, b = bodies[m.a], bodies[m.b]
					if a and b then
						local invSum = a.invMass + b.invMass
						if invSum > 0 and m.depth > self.slop then
							local push = m.normal * ((m.depth - self.slop) * 0.8 / invSum)
							a.position = a.position - push * a.invMass
							b.position = b.position + push * b.invMass
							corrected = corrected + 1
						end
					end
				end
			end
			return corrected
		end

		function self.solveJoints(bodies, dt)
			local solved = 0
			for _, id in ipairs(self.order) do
				local joint = self.joints[id]
				local a, b = bodies[joint.a], bodies[joint.b]
				if a and b and not joint.broken then
					local delta = b.position - a.position
					local dist = delta:length()
					if dist > 1e-9 then
						local normal = delta * (1 / dist)
						local error_ = dist - joint.rest
						if joint.type == "rope" and error_ < 0 then error_ = 0 end
						if joint.min and dist < joint.min then error_ = dist - joint.min end
						if joint.max and dist > joint.max then error_ = dist - joint.max end
						local invSum = a.invMass + b.invMass
						if invSum > 0 and math.abs(error_) > 1e-6 then
							local lambda = -error_ * joint.stiffness / invSum
							local impulse = normal * lambda
							a.position = a.position + normal * (error_ * joint.stiffness * a.invMass / invSum)
							b.position = b.position - normal * (error_ * joint.stiffness * b.invMass / invSum)
							a.applyImpulse(-impulse * 0.5)
							b.applyImpulse(impulse * 0.5)
							solved = solved + 1
						end
					end
				end
			end
			return solved
		end

		function self.breakJoint(id, threshold, bodies)
			local joint = self.joints[id]
			if not joint then return false end
			local a, b = bodies[joint.a], bodies[joint.b]
			if not a or not b then return false end
			local strain = math.abs((b.position - a.position):length() - joint.rest)
			if strain > (threshold or joint.rest) then
				joint.broken = true
				return true
			end
			return false
		end

		function self.clearCache()
			local n = C.count(self.cache)
			self.cache = {}
			return n
		end

		function self.stats() return { joints = #self.order, iterations = self.iterations,
			solves = self.solves, cached = C.count(self.cache), impulse = self.impulseTotal } end
		return self
	end

	------------------------------------------------------------------ 60. RAYCASTER
	-- Ray, sphere-sweep and overlap queries against registered colliders.
	function K.raycaster(cfg)
		local self = { kind = "raycaster", id = cfg.id, colliders = {}, order = {},
			hash = Spatial.spatialHash(cfg.cellSize or 16), casts = 0, hits = 0 }

		function self.register(collider)
			if self.colliders[collider.id] then return false end
			self.colliders[collider.id] = collider
			self.order[#self.order + 1] = collider.id
			self.hash:insert(collider.id, collider.center)
			return true
		end

		function self.unregister(id)
			if not self.colliders[id] then return false end
			self.hash:remove(id)
			self.colliders[id] = nil
			for i, k in ipairs(self.order) do
				if k == id then table.remove(self.order, i) break end
			end
			return true
		end

		function self.update(id, position)
			local collider = self.colliders[id]
			if not collider then return false end
			self.hash:update(id, position)
			collider.center = position
			return true
		end

		local function raySphere(origin, dir, center, radius, maxDist)
			local m = origin - center
			local b = m:dot(dir)
			local c = m:dot(m) - radius * radius
			if c > 0 and b > 0 then return nil end
			local disc = b * b - c
			if disc < 0 then return nil end
			local t = -b - math.sqrt(disc)
			if t < 0 then t = 0 end
			if t > maxDist then return nil end
			return t
		end

		function self.raycast(origin, direction, maxDist, filter)
			self.casts = self.casts + 1
			local dir = direction:unit()
			maxDist = maxDist or 1000
			local bestId, bestT, bestPoint = nil, maxDist, nil
			for _, id in ipairs(self.order) do
				local collider = self.colliders[id]
				if not filter or filter(collider) then
					local t
					if collider.shape == "sphere" then
						t = raySphere(origin, dir, collider.center, collider.radius, bestT)
					elseif collider.shape == "capsule" then
						t = raySphere(origin, dir, collider.center,
							collider.radius + collider.height / 2, bestT)
					else
						t = collider.aabb():rayHit(origin, dir, bestT)
					end
					if t and t < bestT then
						bestT = t
						bestId = id
						bestPoint = origin + dir * t
					end
				end
			end
			if bestId then
				self.hits = self.hits + 1
				local collider = self.colliders[bestId]
				local normal = (bestPoint - collider.center):unit()
				return { id = bestId, distance = bestT, point = bestPoint, normal = normal,
					collider = collider }
			end
			return nil
		end

		function self.raycastAll(origin, direction, maxDist)
			local dir = direction:unit()
			maxDist = maxDist or 1000
			local out = {}
			for _, id in ipairs(self.order) do
				local collider = self.colliders[id]
				local t
				if collider.shape == "box" then
					t = collider.aabb():rayHit(origin, dir, maxDist)
				else
					t = raySphere(origin, dir, collider.center,
						collider.radius + (collider.shape == "capsule" and collider.height / 2 or 0), maxDist)
				end
				if t then out[#out + 1] = { id = id, distance = t, point = origin + dir * t } end
			end
			table.sort(out, function(a, b) return a.distance < b.distance end)
			return out
		end

		-- Sphere sweep by Minkowski expansion: grow the obstacle, shoot a ray. Boxes use the
		-- expanded slab test, round shapes the expanded sphere test, so a wide floor does not
		-- behave like a giant ball.
		function self.spherecast(origin, direction, radius, maxDist)
			self.casts = self.casts + 1
			local dir = direction:unit()
			maxDist = maxDist or 1000
			local bestId, bestT = nil, maxDist
			for _, id in ipairs(self.order) do
				local collider = self.colliders[id]
				local t
				if collider.shape == "box" then
					t = collider.expandedAABB(radius):rayHit(origin, dir, bestT)
				else
					local effective = radius + collider.radius
						+ (collider.shape == "capsule" and collider.height / 2 or 0)
					t = raySphere(origin, dir, collider.center, effective, bestT)
				end
				if t and t < bestT then bestT = t bestId = id end
			end
			if not bestId then return nil end
			self.hits = self.hits + 1
			local point = origin + dir * bestT
			local collider = self.colliders[bestId]
			local surface = collider.closestPoint(point)
			local normal = point - surface
			if normal:length() < 1e-6 then normal = point - collider.center end
			if normal:length() < 1e-6 then normal = dir * -1 end
			return { id = bestId, distance = bestT, point = point, normal = normal:unit(),
				collider = collider }
		end

		function self.overlapSphere(center, radius)
			local out = {}
			for _, id in ipairs(self.order) do
				local collider = self.colliders[id]
				local _, distance = collider.closestPoint(center)
				if distance <= radius then out[#out + 1] = id end
			end
			table.sort(out)
			return out
		end

		function self.nearby(position, radius)
			local ids = self.hash:queryRadius(position, radius)
			local out = {}
			for _, entry in ipairs(ids) do out[#out + 1] = entry.id or entry end
			table.sort(out)
			return out
		end

		function self.stats() return { colliders = #self.order, casts = self.casts,
			hits = self.hits, hitRate = self.casts > 0 and (self.hits / self.casts) or 0 } end
		return self
	end

	------------------------------------------------------------------ 61. CHARMOTOR
	-- Kinematic capsule motor: move and slide, ground detection, slopes, steps, jumping.
	function K.charmotor(cfg)
		local self = { kind = "charmotor", id = cfg.id, position = cfg.position or v3(),
			velocity = v3(), radius = cfg.radius or 0.5, height = cfg.height or 1.8,
			stepOffset = cfg.stepOffset or 0.4, slopeLimit = cfg.slopeLimit or math.rad(48),
			gravity = cfg.gravity or -18, jumpHeight = cfg.jumpHeight or 2.0,
			maxSpeed = cfg.maxSpeed or 7, acceleration = cfg.acceleration or 40,
			airControl = cfg.airControl or 0.35, coyoteTime = cfg.coyoteTime or 0.12,
			grounded = false, groundNormal = v3(0, 1, 0), airborneFor = 0, steps = 0,
			slides = 0, jumps = 0, crouching = false }

		function self.jumpVelocity() return math.sqrt(2 * math.abs(self.gravity) * self.jumpHeight) end

		function self.setGround(grounded, normal)
			if grounded then
				self.grounded = true
				self.airborneFor = 0
				self.groundNormal = normal or v3(0, 1, 0)
			else
				self.grounded = false
			end
			return self.grounded
		end

		function self.canStand()
			local angle = math.acos(Mathx.clamp(self.groundNormal:dot(v3(0, 1, 0)), -1, 1))
			return angle <= self.slopeLimit
		end

		function self.jump()
			if not (self.grounded or self.airborneFor <= self.coyoteTime) then return false end
			self.velocity = v3(self.velocity.x, self.jumpVelocity(), self.velocity.z)
			self.grounded = false
			self.jumps = self.jumps + 1
			return true
		end

		function self.crouch(on)
			if on == self.crouching then return self.height end
			self.crouching = on and true or false
			self.height = self.crouching and (cfg.height or 1.8) * 0.55 or (cfg.height or 1.8)
			self.maxSpeed = self.crouching and (cfg.maxSpeed or 7) * 0.45 or (cfg.maxSpeed or 7)
			return self.height
		end

		-- Project motion along a plane: the core of "slide, do not stop".
		function self.slide(motion, normal)
			self.slides = self.slides + 1
			return motion - normal * motion:dot(normal)
		end

		-- One motor step. `collide(from, to, radius)` returns nil or { normal, point, distance }.
		function self.move(wish, dt, collide)
			self.steps = self.steps + 1
			local control = self.grounded and 1 or self.airControl
			local target = wish:clampMagnitude(1) * self.maxSpeed
			local horizontal = v3(self.velocity.x, 0, self.velocity.z)
			local delta = (target - horizontal):clampMagnitude(self.acceleration * control * dt)
			horizontal = horizontal + delta
			local vy = self.velocity.y
			if self.grounded and vy < 0 then vy = -1 end
			vy = vy + self.gravity * dt
			self.velocity = v3(horizontal.x, vy, horizontal.z)
			local motion = self.velocity * dt
			if self.grounded and self.canStand() then
				motion = self.slide(motion, self.groundNormal) + v3(0, motion.y, 0) * 0
			end
			local remaining = motion
			local from = self.position
			local iterations = 0
			while iterations < 4 and remaining:length() > 1e-6 do
				iterations = iterations + 1
				local hit = collide and collide(from, from + remaining, self.radius) or nil
				if not hit then
					from = from + remaining
					remaining = v3()
				else
					local travel = math.max(0, (hit.distance or 0) - 0.001)
					local dir = remaining:unit()
					from = from + dir * travel
					remaining = self.slide(remaining - dir * travel, hit.normal)
					self.velocity = self.slide(self.velocity, hit.normal)
					if hit.normal.y > 0.5 then self.setGround(true, hit.normal) end
				end
			end
			self.position = from
			if not self.grounded then self.airborneFor = self.airborneFor + dt end
			return self.position, self.velocity
		end

		function self.speed() return v3(self.velocity.x, 0, self.velocity.z):length() end

		function self.locomotionState()
			if not self.grounded then return self.velocity.y > 0 and "jump" or "fall" end
			local s = self.speed()
			if s < 0.15 then return "idle" end
			if s < self.maxSpeed * 0.45 then return "walk" end
			return "run"
		end

		function self.stats() return { steps = self.steps, grounded = self.grounded,
			speed = self.speed(), slides = self.slides, jumps = self.jumps,
			state = self.locomotionState(), crouching = self.crouching } end
		return self
	end

	------------------------------------------------------------------ 62. VEHICLE
	-- Raycast suspension wheels, torque curve, gearbox, Ackermann steering, tire friction.
	function K.vehicle(cfg)
		local self = { kind = "vehicle", id = cfg.id, position = cfg.position or v3(),
			velocity = v3(), heading = 0, wheels = {}, mass = cfg.mass or 1400,
			wheelbase = cfg.wheelbase or 2.7, track = cfg.track or 1.6,
			maxSteer = cfg.maxSteer or math.rad(35), throttle = 0, brake = 0, steer = 0,
			gear = 1, gears = cfg.gears or { 3.6, 2.1, 1.4, 1.0, 0.8 }, finalDrive = cfg.finalDrive or 3.7,
			rpm = 900, idleRpm = 900, maxRpm = cfg.maxRpm or 6800, wheelRadius = cfg.wheelRadius or 0.34,
			downforce = cfg.downforce or 0.4, drag = cfg.drag or 0.42, steps = 0, shifts = 0 }

		function self.addWheel(id, opts)
			opts = opts or {}
			local wheel = { id = id, offset = opts.offset or v3(), steered = opts.steered or false,
				driven = opts.driven ~= false, restLength = opts.restLength or 0.35,
				stiffness = opts.stiffness or 32000, damping = opts.damping or 3200,
				compression = 0, grounded = false, load = 0, slip = 0 }
			self.wheels[#self.wheels + 1] = wheel
			return wheel
		end

		function self.standardChassis()
			if #self.wheels > 0 then return self.wheels end
			local halfBase, halfTrack = self.wheelbase / 2, self.track / 2
			self.addWheel("FL", { offset = v3(-halfTrack, 0, halfBase), steered = true, driven = false })
			self.addWheel("FR", { offset = v3(halfTrack, 0, halfBase), steered = true, driven = false })
			self.addWheel("RL", { offset = v3(-halfTrack, 0, -halfBase), driven = true })
			self.addWheel("RR", { offset = v3(halfTrack, 0, -halfBase), driven = true })
			return self.wheels
		end

		-- Suspension: spring-damper against a measured ground distance per wheel.
		function self.updateSuspension(groundDistanceFn, dt)
			local totalLoad = 0
			for _, wheel in ipairs(self.wheels) do
				local distance = groundDistanceFn and groundDistanceFn(wheel, self) or wheel.restLength
				local compression = Mathx.clamp(wheel.restLength - distance, 0, wheel.restLength)
				local velocity = (compression - wheel.compression) / math.max(1e-6, dt)
				wheel.compression = compression
				wheel.grounded = distance < wheel.restLength
				wheel.load = math.max(0, compression * wheel.stiffness + velocity * wheel.damping)
				totalLoad = totalLoad + wheel.load
			end
			return totalLoad
		end

		-- Torque curve: rises to a mid-range peak then falls away, like a real engine.
		function self.engineTorque(rpm)
			local t = Mathx.clamp(rpm / self.maxRpm, 0, 1)
			local shaped = math.sin(math.pi * Mathx.clamp(t * 1.15, 0, 1)) * 0.85 + t * 0.15
			return 380 * shaped
		end

		function self.gearRatio() return (self.gears[self.gear] or 1) * self.finalDrive end

		function self.shiftUp()
			if self.gear >= #self.gears then return false end
			self.gear = self.gear + 1
			self.shifts = self.shifts + 1
			return true
		end

		function self.shiftDown()
			if self.gear <= 1 then return false end
			self.gear = self.gear - 1
			self.shifts = self.shifts + 1
			return true
		end

		function self.autoShift()
			if self.rpm > self.maxRpm * 0.92 then return self.shiftUp() end
			if self.rpm < self.maxRpm * 0.32 and self.gear > 1 then return self.shiftDown() end
			return false
		end

		-- Ackermann geometry: the inner wheel turns more than the outer one.
		function self.steerAngles(input)
			local steer = Mathx.clamp(input, -1, 1) * self.maxSteer
			if math.abs(steer) < 1e-6 then return 0, 0 end
			local radius = self.wheelbase / math.tan(math.abs(steer))
			local inner = math.atan(self.wheelbase / math.max(0.1, radius - self.track / 2))
			local outer = math.atan(self.wheelbase / (radius + self.track / 2))
			if steer < 0 then return -inner, -outer end
			return inner, outer
		end

		-- Friction circle: longitudinal and lateral grip share one budget.
		function self.tireForce(wheel, longitudinalSlip, lateralSlip, mu)
			mu = mu or 1.1
			local maxForce = wheel.load * mu
			local fx = Mathx.clamp(longitudinalSlip * 8, -1, 1) * maxForce
			local fy = Mathx.clamp(lateralSlip * 6, -1, 1) * maxForce
			local total = math.sqrt(fx * fx + fy * fy)
			if total > maxForce and total > 0 then
				local scale = maxForce / total
				fx, fy = fx * scale, fy * scale
			end
			wheel.slip = math.abs(longitudinalSlip) + math.abs(lateralSlip)
			return fx, fy
		end

		function self.step(dt, input)
			self.steps = self.steps + 1
			input = input or {}
			self.throttle = Mathx.clamp(input.throttle or 0, 0, 1)
			self.brake = Mathx.clamp(input.brake or 0, 0, 1)
			self.steer = Mathx.clamp(input.steer or 0, -1, 1)
			self.standardChassis()
			local speed = self.velocity:length()
			local wheelRpm = (speed / (2 * math.pi * self.wheelRadius)) * 60
			self.rpm = math.max(self.idleRpm, wheelRpm * self.gearRatio())
			self.autoShift()
			local torque = self.engineTorque(self.rpm) * self.throttle * self.gearRatio()
			local driveForce = torque / self.wheelRadius
			local dragForce = self.drag * speed * speed
			local brakeForce = self.brake * 12000
			local net = driveForce - dragForce - brakeForce * Mathx.sign(speed)
			local acceleration = net / self.mass
			local forward = v3(math.sin(self.heading), 0, math.cos(self.heading))
			self.velocity = self.velocity + forward * (acceleration * dt)
			if self.velocity:dot(forward) < 0 and self.throttle == 0 then self.velocity = v3() end
			-- yaw from the bicycle model
			local inner = select(1, self.steerAngles(self.steer))
			if math.abs(inner) > 1e-6 and speed > 0.2 then
				self.heading = self.heading + (speed / self.wheelbase) * math.tan(inner) * dt
			end
			self.position = self.position + self.velocity * dt
			return { speed = self.velocity:length(), rpm = self.rpm, gear = self.gear,
				heading = self.heading, position = self.position }
		end

		function self.speedKmh() return self.velocity:length() * 3.6 end

		function self.stats() return { wheels = #self.wheels, gear = self.gear, rpm = self.rpm,
			speedKmh = self.speedKmh(), steps = self.steps, shifts = self.shifts,
			grounded = (function()
				local n = 0
				for _, w in ipairs(self.wheels) do if w.grounded then n = n + 1 end end
				return n
			end)() } end
		return self
	end

	------------------------------------------------------------------ 63. SKELETON
	-- Bone hierarchy with bind pose, local/world transforms and pose algebra.
	function K.skeleton(cfg)
		local self = { kind = "skeleton", id = cfg.id, bones = {}, order = {}, roots = {},
			bindPose = {}, resolves = 0 }

		function self.addBone(id, opts, parent)
			opts = opts or {}
			if self.bones[id] then return nil, "duplicate bone" end
			local bone = { id = id, parent = parent, children = {},
				position = opts.position or v3(), rotation = opts.rotation or v3(),
				scale = opts.scale or v3(1, 1, 1), length = opts.length or 1,
				mask = opts.mask or 1, world = nil }
			self.bones[id] = bone
			self.order[#self.order + 1] = id
			if parent and self.bones[parent] then
				table.insert(self.bones[parent].children, id)
			else
				self.roots[#self.roots + 1] = id
			end
			self.bindPose[id] = { position = bone.position, rotation = bone.rotation, scale = bone.scale }
			return bone
		end

		-- Dirtying one bone must dirty its whole subtree, otherwise a cached grandchild
		-- keeps reporting a world transform that no longer exists.
		function self.invalidateSubtree(id)
			local bone = self.bones[id]
			if not bone then return 0 end
			bone.world = nil
			local n = 1
			for _, child in ipairs(bone.children) do n = n + self.invalidateSubtree(child) end
			return n
		end

		function self.setLocal(id, position, rotation, scale)
			local bone = self.bones[id]
			if not bone then return nil, "unknown bone" end
			bone.position = position or bone.position
			bone.rotation = rotation or bone.rotation
			bone.scale = scale or bone.scale
			self.invalidateSubtree(id)
			return bone
		end

		function self.worldOf(id)
			local bone = self.bones[id]
			if not bone then return nil end
			if bone.world then return bone.world end
			self.resolves = self.resolves + 1
			if not bone.parent then
				bone.world = { position = bone.position, rotation = bone.rotation, scale = bone.scale }
			else
				local parent = self.worldOf(bone.parent)
				bone.world = {
					position = parent.position + bone.position * parent.scale,
					rotation = parent.rotation + bone.rotation,
					scale = parent.scale * bone.scale,
				}
			end
			return bone.world
		end

		function self.invalidate()
			for _, id in ipairs(self.order) do self.bones[id].world = nil end
			return #self.order
		end

		function self.chain(fromId, toId)
			local out = {}
			local current = toId
			while current do
				table.insert(out, 1, current)
				if current == fromId then return out end
				current = self.bones[current] and self.bones[current].parent or nil
			end
			return nil
		end

		function self.depthOf(id)
			local depth, current = 0, self.bones[id]
			while current and current.parent do
				depth = depth + 1
				current = self.bones[current.parent]
			end
			return depth
		end

		function self.pose()
			local out = {}
			for _, id in ipairs(self.order) do
				local bone = self.bones[id]
				out[id] = { position = bone.position, rotation = bone.rotation, scale = bone.scale }
			end
			return out
		end

		function self.applyPose(pose, weight)
			weight = weight == nil and 1 or clamp01(weight)
			local applied = 0
			for id, transform in pairs(pose) do
				local bone = self.bones[id]
				if bone then
					local w = weight * bone.mask
					bone.position = bone.position:lerp(transform.position or bone.position, w)
					bone.rotation = bone.rotation:lerp(transform.rotation or bone.rotation, w)
					bone.world = nil
					applied = applied + 1
				end
			end
			self.invalidate()
			return applied
		end

		function self.blend(a, b, t)
			t = clamp01(t)
			local out = {}
			for id, ta in pairs(a) do
				local tb = b[id]
				if tb then
					out[id] = { position = ta.position:lerp(tb.position, t),
						rotation = ta.rotation:lerp(tb.rotation, t),
						scale = ta.scale and tb.scale and ta.scale:lerp(tb.scale, t) or ta.scale }
				else
					out[id] = ta
				end
			end
			return out
		end

		function self.additive(base, layer, weight)
			weight = clamp01(weight or 1)
			local out = {}
			for id, tb in pairs(base) do
				local tl = layer[id]
				if tl then
					out[id] = { position = tb.position + tl.position * weight,
						rotation = tb.rotation + tl.rotation * weight, scale = tb.scale }
				else
					out[id] = tb
				end
			end
			return out
		end

		function self.resetToBind()
			for id, t in pairs(self.bindPose) do
				local bone = self.bones[id]
				bone.position, bone.rotation, bone.scale = t.position, t.rotation, t.scale
				bone.world = nil
			end
			return #self.order
		end

		function self.setMask(id, weight)
			local bone = self.bones[id]
			if not bone then return false end
			bone.mask = clamp01(weight)
			return true
		end

		function self.stats() return { bones = #self.order, roots = #self.roots,
			resolves = self.resolves, depth = (function()
				local d = 0
				for _, id in ipairs(self.order) do d = math.max(d, self.depthOf(id)) end
				return d
			end)() } end
		return self
	end

	------------------------------------------------------------------ 64. CLIP
	-- Keyframed animation clip: tracks, sampling, events, looping, retiming, compression.
	function K.clip(cfg)
		local self = { kind = "clip", id = cfg.id, tracks = {}, trackOrder = {},
			duration = cfg.duration or 1, loop = cfg.loop ~= false, events = {},
			samples = 0, speed = cfg.speed or 1 }

		function self.addTrack(bone, channel)
			local key = bone .. "." .. (channel or "position")
			if self.tracks[key] then return self.tracks[key] end
			local track = { bone = bone, channel = channel or "position", keys = {} }
			self.tracks[key] = track
			self.trackOrder[#self.trackOrder + 1] = key
			return track
		end

		function self.addKey(bone, channel, time, value)
			local track = self.addTrack(bone, channel)
			track.keys[#track.keys + 1] = { time = time, value = value }
			table.sort(track.keys, function(a, b) return a.time < b.time end)
			if time > self.duration then self.duration = time end
			return #track.keys
		end

		function self.addEvent(time, name, payload)
			self.events[#self.events + 1] = { time = time, name = name, payload = payload }
			table.sort(self.events, function(a, b) return a.time < b.time end)
			return #self.events
		end

		function self.normalizeTime(time)
			if self.duration <= 0 then return 0 end
			if self.loop then return time % self.duration end
			return Mathx.clamp(time, 0, self.duration)
		end

		function self.sampleTrack(key, time)
			local track = self.tracks[key]
			if not track or #track.keys == 0 then return nil end
			time = self.normalizeTime(time)
			local keys = track.keys
			if time <= keys[1].time then return keys[1].value end
			if time >= keys[#keys].time then return keys[#keys].value end
			for i = 1, #keys - 1 do
				local a, b = keys[i], keys[i + 1]
				if time >= a.time and time <= b.time then
					local t = (time - a.time) / math.max(1e-9, b.time - a.time)
					if type(a.value) == "number" then return Mathx.lerp(a.value, b.value, t) end
					return a.value:lerp(b.value, t)
				end
			end
			return keys[#keys].value
		end

		function self.sample(time)
			self.samples = self.samples + 1
			local pose = {}
			for _, key in ipairs(self.trackOrder) do
				local track = self.tracks[key]
				local value = self.sampleTrack(key, time)
				if value then
					pose[track.bone] = pose[track.bone] or {}
					pose[track.bone][track.channel] = value
				end
			end
			-- fill the transform shape the skeleton expects
			for _, t in pairs(pose) do
				t.position = t.position or v3()
				t.rotation = t.rotation or v3()
				t.scale = t.scale or v3(1, 1, 1)
			end
			return pose
		end

		function self.eventsBetween(fromTime, toTime)
			local out = {}
			local from = self.normalizeTime(fromTime)
			local to = self.normalizeTime(toTime)
			for _, e in ipairs(self.events) do
				if from <= to then
					if e.time > from and e.time <= to then out[#out + 1] = e end
				else
					if e.time > from or e.time <= to then out[#out + 1] = e end
				end
			end
			return out
		end

		function self.retime(scale)
			scale = math.max(0.01, scale or 1)
			for _, key in ipairs(self.trackOrder) do
				for _, k in ipairs(self.tracks[key].keys) do k.time = k.time * scale end
			end
			for _, e in ipairs(self.events) do e.time = e.time * scale end
			self.duration = self.duration * scale
			return self.duration
		end

		-- Drop keys the interpolation would have produced anyway.
		function self.compress(tolerance)
			tolerance = tolerance or 0.001
			local dropped = 0
			for _, key in ipairs(self.trackOrder) do
				local track = self.tracks[key]
				local keys = track.keys
				local kept = { keys[1] }
				for i = 2, #keys - 1 do
					local prev, cur, nextK = kept[#kept], keys[i], keys[i + 1]
					local t = (cur.time - prev.time) / math.max(1e-9, nextK.time - prev.time)
					local predicted
					if type(cur.value) == "number" then
						predicted = Mathx.lerp(prev.value, nextK.value, t)
						if math.abs(predicted - cur.value) > tolerance then
							kept[#kept + 1] = cur
						else
							dropped = dropped + 1
						end
					else
						predicted = prev.value:lerp(nextK.value, t)
						if (predicted - cur.value):length() > tolerance then
							kept[#kept + 1] = cur
						else
							dropped = dropped + 1
						end
					end
				end
				if #keys > 1 then kept[#kept + 1] = keys[#keys] end
				track.keys = kept
			end
			return dropped
		end

		function self.keyCount()
			local n = 0
			for _, key in ipairs(self.trackOrder) do n = n + #self.tracks[key].keys end
			return n
		end

		function self.stats() return { tracks = #self.trackOrder, keys = self.keyCount(),
			duration = self.duration, loop = self.loop, events = #self.events,
			samples = self.samples } end
		return self
	end

	------------------------------------------------------------------ 65. ANIMATOR
	-- Layered playback: crossfades, additive layers, 1-D blend trees, masks and speed.
	function K.animator(cfg)
		local self = { kind = "animator", id = cfg.id, layers = {}, layerOrder = {},
			clips = {}, time = 0, evaluations = 0, budget = cfg.budget or 8 }

		function self.addClip(id, clip)
			self.clips[id] = clip
			return clip
		end

		function self.addLayer(name, opts)
			opts = opts or {}
			if self.layers[name] then return nil, "duplicate layer" end
			local layer = { name = name, weight = opts.weight or 1, additive = opts.additive or false,
				clip = nil, from = nil, blend = 0, blendTime = 0, time = 0,
				speed = opts.speed or 1, mask = opts.mask or {}, tree = nil, playing = false }
			self.layers[name] = layer
			self.layerOrder[#self.layerOrder + 1] = name
			return layer
		end

		function self.play(layerName, clipId, opts)
			opts = opts or {}
			local layer = self.layers[layerName]
			if not layer then return nil, "unknown layer" end
			if not self.clips[clipId] then return nil, "unknown clip" end
			if layer.clip and opts.fade and opts.fade > 0 then
				layer.from = layer.clip
				layer.fromTime = layer.time
				layer.blend = 0
				layer.blendTime = opts.fade
			else
				layer.from = nil
				layer.blend = 1
				layer.blendTime = 0
			end
			layer.clip = clipId
			layer.time = opts.offset or 0
			layer.speed = opts.speed or layer.speed
			layer.playing = true
			return layer
		end

		function self.stop(layerName)
			local layer = self.layers[layerName]
			if not layer then return false end
			layer.playing = false
			layer.clip = nil
			layer.from = nil
			return true
		end

		function self.setWeight(layerName, weight)
			local layer = self.layers[layerName]
			if not layer then return false end
			layer.weight = clamp01(weight)
			return true
		end

		-- 1-D blend tree: a parameter picks and blends the two nearest clips.
		function self.setBlendTree(layerName, entries, parameter)
			local layer = self.layers[layerName]
			if not layer then return nil, "unknown layer" end
			table.sort(entries, function(a, b) return a.threshold < b.threshold end)
			layer.tree = { entries = entries, parameter = parameter or 0 }
			layer.playing = true
			return layer.tree
		end

		function self.setParameter(layerName, value)
			local layer = self.layers[layerName]
			if not layer or not layer.tree then return false end
			layer.tree.parameter = value
			return true
		end

		local function sampleTree(tree, time)
			local entries = tree.entries
			local p = tree.parameter
			if p <= entries[1].threshold then return entries[1].clip, nil, 0 end
			if p >= entries[#entries].threshold then return entries[#entries].clip, nil, 0 end
			for i = 1, #entries - 1 do
				local a, b = entries[i], entries[i + 1]
				if p >= a.threshold and p <= b.threshold then
					local t = (p - a.threshold) / math.max(1e-9, b.threshold - a.threshold)
					return a.clip, b.clip, t
				end
			end
			return entries[1].clip, nil, 0
		end

		function self.evaluate(dt, skeleton)
			self.evaluations = self.evaluations + 1
			self.time = self.time + dt
			local result = nil
			local events = {}
			for _, name in ipairs(self.layerOrder) do
				local layer = self.layers[name]
				if layer.playing and layer.weight > 0.001 then
					layer.time = layer.time + dt * layer.speed
					local pose
					if layer.tree then
						local aId, bId, t = sampleTree(layer.tree, layer.time)
						local a = self.clips[aId]
						if a then
							pose = a.sample(layer.time)
							if bId and self.clips[bId] then
								pose = skeleton.blend(pose, self.clips[bId].sample(layer.time), t)
							end
						end
					elseif layer.clip and self.clips[layer.clip] then
						local clip = self.clips[layer.clip]
						pose = clip.sample(layer.time)
						for _, e in ipairs(clip.eventsBetween(layer.time - dt * layer.speed, layer.time)) do
							events[#events + 1] = { layer = name, name = e.name, payload = e.payload }
						end
						if layer.from and self.clips[layer.from] and layer.blendTime > 0 then
							layer.blend = math.min(1, layer.blend + dt / layer.blendTime)
							layer.fromTime = (layer.fromTime or 0) + dt * layer.speed
							local fromPose = self.clips[layer.from].sample(layer.fromTime)
							pose = skeleton.blend(fromPose, pose, layer.blend)
							if layer.blend >= 1 then layer.from = nil end
						end
					end
					if pose then
						if not result then
							result = pose
						elseif layer.additive then
							result = skeleton.additive(result, pose, layer.weight)
						else
							result = skeleton.blend(result, pose, layer.weight)
						end
					end
				end
			end
			return result or {}, events
		end

		function self.isBlending(layerName)
			local layer = self.layers[layerName]
			return layer ~= nil and layer.from ~= nil
		end

		function self.stats() return { layers = #self.layerOrder, clips = C.count(self.clips),
			evaluations = self.evaluations, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 66. IK
	-- Analytic two-bone IK, FABRIK chains and constrained look-at.
	function K.ik(cfg)
		local self = { kind = "ik", id = cfg.id, iterations = cfg.iterations or 8,
			tolerance = cfg.tolerance or 0.001, solves = 0, misses = 0 }

		-- Law of cosines two-bone solve: hips->knee->foot, elbow->hand, etc.
		function self.twoBone(root, mid, effector, target, poleVector)
			self.solves = self.solves + 1
			local upperLen = (mid - root):length()
			local lowerLen = (effector - mid):length()
			local toTarget = target - root
			local targetDist = toTarget:length()
			local reach = upperLen + lowerLen
			local clampedDist = math.min(targetDist, reach * 0.999)
			if targetDist > reach then self.misses = self.misses + 1 end
			if clampedDist < 1e-6 then return root, mid, effector, false end
			local dir = toTarget * (1 / math.max(1e-9, targetDist))
			local cosAngle = Mathx.clamp(
				(upperLen * upperLen + clampedDist * clampedDist - lowerLen * lowerLen)
				/ (2 * upperLen * clampedDist), -1, 1)
			local angle = math.acos(cosAngle)
			local pole = poleVector or v3(0, 0, 1)
			local axis = dir:cross(pole)
			if axis:length() < 1e-6 then axis = dir:cross(v3(0, 1, 0)) end
			if axis:length() < 1e-6 then axis = v3(1, 0, 0) end
			axis = axis:unit()
			local perpendicular = axis:cross(dir):unit()
			local newMid = root + dir * (math.cos(angle) * upperLen)
				+ perpendicular * (math.sin(angle) * upperLen)
			local newEffector = root + dir * clampedDist
			return root, newMid, newEffector, targetDist <= reach
		end

		-- FABRIK: forward and backward reaching over an arbitrary chain.
		function self.fabrik(points, target, iterations)
			self.solves = self.solves + 1
			iterations = iterations or self.iterations
			local n = #points
			if n < 2 then return points, false end
			local lengths = {}
			local total = 0
			for i = 1, n - 1 do
				lengths[i] = (points[i + 1] - points[i]):length()
				total = total + lengths[i]
			end
			local root = points[1]
			local out = {}
			for i = 1, n do out[i] = points[i] end
			if (target - root):length() > total then
				self.misses = self.misses + 1
				local dir = (target - root):unit()
				for i = 2, n do out[i] = out[i - 1] + dir * lengths[i - 1] end
				return out, false
			end
			for _ = 1, iterations do
				out[n] = target
				for i = n - 1, 1, -1 do
					local dir = (out[i] - out[i + 1]):unit()
					out[i] = out[i + 1] + dir * lengths[i]
				end
				out[1] = root
				for i = 2, n do
					local dir = (out[i] - out[i - 1]):unit()
					out[i] = out[i - 1] + dir * lengths[i - 1]
				end
				if (out[n] - target):length() < self.tolerance then break end
			end
			return out, (out[n] - target):length() < self.tolerance * 10
		end

		-- Constrained look-at: turn toward the target but never past the limit.
		function self.lookAt(origin, forward, target, maxAngle)
			self.solves = self.solves + 1
			local desired = (target - origin)
			if desired:length() < 1e-6 then return forward, 0 end
			desired = desired:unit()
			local current = forward:unit()
			local angle = current:angleTo(desired)
			maxAngle = maxAngle or math.pi
			if angle <= maxAngle then return desired, angle end
			local t = maxAngle / angle
			return current:lerp(desired, t):unit(), maxAngle
		end

		-- Foot placement: drop the foot onto the measured ground with a hip offset.
		function self.footPlacement(footPosition, groundHeight, maxDrop)
			local delta = footPosition.y - groundHeight
			local adjusted = v3(footPosition.x, groundHeight, footPosition.z)
			local hipOffset = 0
			if delta > (maxDrop or 0.45) then
				adjusted = v3(footPosition.x, footPosition.y - (maxDrop or 0.45), footPosition.z)
			elseif delta < 0 then
				hipOffset = delta
			end
			return adjusted, hipOffset
		end

		function self.stats() return { solves = self.solves, misses = self.misses,
			iterations = self.iterations, tolerance = self.tolerance } end
		return self
	end

	------------------------------------------------------------------ 67. RAGDOLL
	-- Physical bones with joint limits and a blend weight between animation and physics.
	function K.ragdoll(cfg)
		local self = { kind = "ragdoll", id = cfg.id, bones = {}, order = {}, joints = {},
			active = false, blend = 0, blendSpeed = cfg.blendSpeed or 4,
			gravity = cfg.gravity or v3(0, -18, 0), steps = 0, settleTime = 0 }

		function self.addBone(id, opts)
			opts = opts or {}
			if self.bones[id] then return nil, "duplicate bone" end
			local bone = { id = id, position = opts.position or v3(), velocity = v3(),
				animated = opts.position or v3(), mass = opts.mass or 4,
				parent = opts.parent, length = opts.length or 0.4, damping = opts.damping or 0.06 }
			self.bones[id] = bone
			self.order[#self.order + 1] = id
			if bone.parent and self.bones[bone.parent] then
				self.joints[#self.joints + 1] = { a = bone.parent, b = id, rest = bone.length,
					limit = opts.limit or math.rad(75) }
			end
			return bone
		end

		function self.setAnimatedPose(pose)
			local n = 0
			for id, transform in pairs(pose) do
				local bone = self.bones[id]
				if bone then
					bone.animated = transform.position or bone.animated
					n = n + 1
				end
			end
			return n
		end

		function self.activate(impulse)
			self.active = true
			self.settleTime = 0
			for _, id in ipairs(self.order) do
				local bone = self.bones[id]
				bone.position = bone.animated
				bone.velocity = impulse or v3()
			end
			return true
		end

		function self.deactivate() self.active = false return true end

		-- Verlet-ish integration plus distance joints: stable without a full solver.
		function self.step(dt, groundHeight)
			if not self.active then
				self.blend = math.max(0, self.blend - dt * self.blendSpeed)
				return self.blend
			end
			self.steps = self.steps + 1
			self.blend = math.min(1, self.blend + dt * self.blendSpeed)
			groundHeight = groundHeight or 0
			for _, id in ipairs(self.order) do
				local bone = self.bones[id]
				bone.velocity = bone.velocity + self.gravity * dt
				bone.velocity = bone.velocity * (1 / (1 + bone.damping))
				bone.position = bone.position + bone.velocity * dt
				if bone.position.y < groundHeight then
					bone.position = v3(bone.position.x, groundHeight, bone.position.z)
					bone.velocity = v3(bone.velocity.x * 0.6, -bone.velocity.y * 0.15, bone.velocity.z * 0.6)
				end
			end
			for _ = 1, 4 do
				for _, joint in ipairs(self.joints) do
					local a, b = self.bones[joint.a], self.bones[joint.b]
					local delta = b.position - a.position
					local dist = delta:length()
					if dist > 1e-6 then
						local correction = (dist - joint.rest) / dist * 0.5
						local offset = delta * correction
						a.position = a.position + offset
						b.position = b.position - offset
					end
				end
			end
			local moving = 0
			for _, id in ipairs(self.order) do
				moving = moving + self.bones[id].velocity:length()
			end
			if moving / math.max(1, #self.order) < 0.05 then
				self.settleTime = self.settleTime + dt
			else
				self.settleTime = 0
			end
			return self.blend
		end

		function self.settled() return self.settleTime > 0.5 end

		-- Blend physical bones back toward the animated pose: the "get up" transition.
		function self.pose()
			local out = {}
			for _, id in ipairs(self.order) do
				local bone = self.bones[id]
				out[id] = { position = bone.animated:lerp(bone.position, self.blend),
					rotation = v3(), scale = v3(1, 1, 1) }
			end
			return out
		end

		function self.recover(dt)
			self.active = false
			self.blend = math.max(0, self.blend - dt * self.blendSpeed)
			return self.blend
		end

		function self.centerOfMass()
			local total, mass = v3(), 0
			for _, id in ipairs(self.order) do
				local bone = self.bones[id]
				total = total + bone.position * bone.mass
				mass = mass + bone.mass
			end
			if mass == 0 then return v3() end
			return total * (1 / mass)
		end

		function self.stats() return { bones = #self.order, joints = #self.joints,
			active = self.active, blend = self.blend, steps = self.steps,
			settled = self.settled() } end
		return self
	end

	K.NAMES = { "rigidbody", "collider", "contact", "constraint", "raycaster", "charmotor",
		"vehicle", "skeleton", "clip", "animator", "ik", "ragdoll" }

	return K

end
