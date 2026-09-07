-- ARKHER CHARACTER :: Digital Human Framework
-- One character = motor (physics) + rig (animation) + locomotion state + IK + ragdoll +
-- appearance + LOD. This is the layer a game actually talks to, and it keeps the physics,
-- animation and material frameworks in agreement instead of fighting each other.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local Animation = A:import("arkher/animation/animation_system")
	local MotionMatching = A:import("arkher/animation/motion_matching")
	local v3 = Vec.vec3

	local Character = {}
	Character.__index = Character

	-- Locomotion states and the transitions the motor is allowed to make.
	Character.STATES = {
		idle  = { walk = true, run = true, jump = true, fall = true, ragdoll = true, crouch = true },
		walk  = { idle = true, run = true, jump = true, fall = true, ragdoll = true, crouch = true },
		run   = { idle = true, walk = true, jump = true, fall = true, ragdoll = true },
		jump  = { fall = true, land = true, ragdoll = true },
		fall  = { land = true, ragdoll = true },
		land  = { idle = true, walk = true, run = true, ragdoll = true },
		crouch = { idle = true, walk = true, ragdoll = true },
		ragdoll = { getup = true },
		getup = { idle = true },
	}

	-- Appearance tiers: what a character costs at each distance.
	Character.LOD_TIERS = {
		{ name = "hero",   distance = 18,  bones = 60, materials = 6, ik = true,  ragdoll = true },
		{ name = "close",  distance = 55,  bones = 30, materials = 4, ik = true,  ragdoll = true },
		{ name = "mid",    distance = 140, bones = 16, materials = 2, ik = false, ragdoll = false },
		{ name = "far",    distance = 400, bones = 6,  materials = 1, ik = false, ragdoll = false },
		{ name = "crowd",  distance = math.huge, bones = 0, materials = 1, ik = false, ragdoll = false },
	}

	function Character.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Character)
		self.animation = opts.animation or Animation.new({})
		self.characters = {}
		self.order = {}
		self.onState = Signal.new("character.state")
		self.onFootstep = Signal.new("character.footstep")
		self.frame = 0
		self.transitions = 0
		self.materials = opts.materials
		self.motionMatchingEnabled = opts.motionMatching ~= false
		if not self.animation.clips.idle then
			self.animation:buildLocomotionSet({ "hips", "spine", "chest", "LUpperLeg",
				"RUpperLeg", "LUpperArm", "RUpperArm" })
		end
		return self
	end

	-- ------------------------------------------------------------------ spawning
	function Character:spawn(id, opts)
		opts = opts or {}
		if self.characters[id] then return nil, "duplicate character" end
		local motor = Kits.create("charmotor", {
			id = id, position = opts.position or v3(),
			radius = opts.radius or 0.45, height = opts.height or 1.8,
			maxSpeed = opts.maxSpeed or 6.5, jumpHeight = opts.jumpHeight or 1.9 })
		local rig = self.animation:createRig(id, { position = opts.position or v3() })
		self.animation:buildHumanoid(id)
		self.animation:installLocomotionTree(id)
		self.animation:attachRagdoll(id)
		local character = {
			id = id, motor = motor, rig = rig, state = "idle", previousState = "idle",
			stateTime = 0, health = opts.health or 100, tier = 1, distance = 0,
			appearance = opts.appearance or { skin = "skin", cloth = "fabric", metal = "steel" },
			matcher = nil, lookTarget = nil, intent = v3(), grounded = true,
			footsteps = 0, name = opts.name or id,
		}
		if self.motionMatchingEnabled then
			character.matcher = MotionMatching.new({ searchBudget = 256 })
			for clipId, clip in pairs(self.animation.clips) do
				local speed = clipId == "run" and 5.5 or (clipId == "walk" and 1.6 or 0)
				character.matcher:buildFromClip(clipId, clip, { rate = 8, speed = speed })
			end
		end
		self.characters[id] = character
		self.order[#self.order + 1] = id
		return character
	end

	function Character:despawn(id)
		if not self.characters[id] then return false end
		self.characters[id] = nil
		for i, k in ipairs(self.order) do
			if k == id then table.remove(self.order, i) break end
		end
		return true
	end

	function Character:get(id) return self.characters[id] end

	-- ------------------------------------------------------------------ state machine
	function Character:canTransition(from, to)
		local rules = Character.STATES[from]
		return rules ~= nil and rules[to] == true
	end

	function Character:setState(id, state)
		local c = self.characters[id]
		if not c then return false end
		if c.state == state then return false end
		if not self:canTransition(c.state, state) then return false end
		c.previousState = c.state
		c.state = state
		c.stateTime = 0
		self.transitions = self.transitions + 1
		self.onState:fire({ id = id, from = c.previousState, to = state })
		return true
	end

	-- Derive the state the motor's physics implies, then request it.
	function Character:syncState(id)
		local c = self.characters[id]
		if not c then return nil end
		if c.state == "ragdoll" or c.state == "getup" then return c.state end
		local motorState = c.motor.locomotionState()
		local wanted = motorState
		if motorState == "jump" then wanted = "jump" end
		if motorState == "fall" then wanted = "fall" end
		if (c.state == "jump" or c.state == "fall") and c.motor.grounded then wanted = "land" end
		if c.state == "land" and c.stateTime > 0.18 then wanted = motorState end
		if c.motor.crouching and c.motor.grounded and motorState ~= "run" then wanted = "crouch" end
		if wanted ~= c.state and self:canTransition(c.state, wanted) then self:setState(id, wanted) end
		return c.state
	end

	-- ------------------------------------------------------------------ input & motion
	function Character:setIntent(id, direction)
		local c = self.characters[id]
		if not c then return false end
		c.intent = direction or v3()
		return true
	end

	function Character:jump(id)
		local c = self.characters[id]
		if not c then return false end
		if not c.motor.jump() then return false end
		self:setState(id, "jump")
		return true
	end

	function Character:crouch(id, on)
		local c = self.characters[id]
		if not c then return false end
		c.motor.crouch(on)
		return true
	end

	function Character:damage(id, amount, impulse)
		local c = self.characters[id]
		if not c then return false end
		c.health = math.max(0, c.health - amount)
		if c.health <= 0 and c.state ~= "ragdoll" then
			self:setState(id, "ragdoll")
			self.animation:activateRagdoll(id, impulse or v3(0, 2, 0))
		end
		return c.health
	end

	function Character:getUp(id, dt)
		local c = self.characters[id]
		if not c or c.state ~= "ragdoll" then return false end
		if not c.rig.ragdoll.settled() then return false end
		self:setState(id, "getup")
		self.animation:recoverRagdoll(id, dt or (1 / 60))
		return true
	end

	function Character:lookAt(id, target)
		local c = self.characters[id]
		if not c then return false end
		c.lookTarget = target
		self.animation:setLookTarget(id, target)
		return true
	end

	-- ------------------------------------------------------------------ LOD
	function Character:updateTier(id, viewer)
		local c = self.characters[id]
		if not c then return nil end
		c.distance = c.motor.position:distance(viewer)
		for i, tier in ipairs(Character.LOD_TIERS) do
			if c.distance <= tier.distance then
				c.tier = i
				break
			end
		end
		return c.tier, Character.LOD_TIERS[c.tier]
	end

	function Character:tierConfig(id)
		local c = self.characters[id]
		if not c then return nil end
		return Character.LOD_TIERS[c.tier]
	end

	-- ------------------------------------------------------------------ the frame
	function Character:update(id, dt, collide)
		local c = self.characters[id]
		if not c then return nil end
		c.stateTime = c.stateTime + dt
		if c.state ~= "ragdoll" then
			c.motor.move(c.intent, dt, collide)
		end
		c.rig.position = c.motor.position
		self:syncState(id)
		local tier = Character.LOD_TIERS[c.tier]
		local speed = c.motor.speed()
		self.animation:setSpeed(id, speed)
		if c.matcher and tier.ik then
			local query = c.matcher:queryFromMotion(c.motor.velocity, c.intent)
			c.matchResult = c.matcher:update(dt, query)
		end
		if tier.ik then
			self.animation:setFootTarget(id, "L", 0)
			self.animation:setFootTarget(id, "R", 0)
		else
			c.rig.footTargets = {}
		end
		local pose, events = self.animation:evaluate(id, dt)
		if tier.ik then self.animation:solveIK(id) end
		for _, e in ipairs(events or {}) do
			if e.name == "footstep" then
				c.footsteps = c.footsteps + 1
				self.onFootstep:fire({ id = id, foot = e.payload and e.payload.foot,
					speed = speed, position = c.motor.position })
			end
		end
		return { state = c.state, speed = speed, tier = tier.name, pose = pose }
	end

	function Character:updateAll(dt, viewer, collide)
		self.frame = self.frame + 1
		viewer = viewer or v3()
		local updated = 0
		for _, id in ipairs(self.order) do
			self:updateTier(id, viewer)
			local tier = Character.LOD_TIERS[self.characters[id].tier]
			if tier.bones > 0 or self.characters[id].state == "ragdoll" then
				self:update(id, dt, collide)
				updated = updated + 1
			else
				-- crowd tier: move the motor, skip the rig entirely
				self.characters[id].motor.move(self.characters[id].intent, dt, collide)
			end
		end
		return { updated = updated, total = #self.order, frame = self.frame }
	end

	-- ------------------------------------------------------------------ appearance
	function Character:resolveAppearance(id, materials)
		local c = self.characters[id]
		if not c then return nil end
		materials = materials or self.materials
		if not materials then return c.appearance end
		local tier = Character.LOD_TIERS[c.tier]
		local out = {}
		local budget = tier.materials
		local n = 0
		for slot, materialId in pairs(c.appearance) do
			if n < budget then
				out[slot] = materials:resolveForDistance(materialId, { wetness = 0 }, c.distance)
				n = n + 1
			end
		end
		return out
	end

	function Character:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.animation:applyQuality(quality)
		for _, id in ipairs(self.order) do
			local c = self.characters[id]
			if c.matcher then c.matcher:applyQuality(quality) end
		end
		Character.LOD_TIERS[1].distance = 8 + quality * 22
		Character.LOD_TIERS[2].distance = 25 + quality * 45
		Character.LOD_TIERS[3].distance = 70 + quality * 100
		return { animation = self.animation.budget, heroDistance = Character.LOD_TIERS[1].distance }
	end

	function Character:report()
		local byState, byTier = {}, {}
		local footsteps = 0
		for _, id in ipairs(self.order) do
			local c = self.characters[id]
			byState[c.state] = (byState[c.state] or 0) + 1
			local tier = Character.LOD_TIERS[c.tier].name
			byTier[tier] = (byTier[tier] or 0) + 1
			footsteps = footsteps + c.footsteps
		end
		return { characters = #self.order, byState = byState, byTier = byTier,
			transitions = self.transitions, footsteps = footsteps, frame = self.frame,
			animation = self.animation:report() }
	end

	return Character
end
