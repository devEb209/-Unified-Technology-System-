-- ARKHER ANIMATION :: Animation Framework
-- Skeletons, clips, layered playback, IK and ragdoll blending as one system, with a
-- distance-based LOD ladder and a per-frame evaluation budget so a crowd never melts a phone.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local Animation = {}
	Animation.__index = Animation

	-- Evaluation tiers by screen distance: full rate, half rate, quarter rate, frozen pose.
	Animation.LOD_BANDS = { 25, 70, 160 }
	Animation.LOD_RATES = { 1, 2, 4, 0 }

	function Animation.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Animation)
		self.clips = {}
		self.rigs = {}
		self.rigOrder = {}
		self.ik = Kits.create("ik", { id = "anim.ik", iterations = opts.ikIterations or 8 })
		self.budget = opts.budget or 24        -- rigs evaluated per frame
		self.frame = 0
		self.evaluations = 0
		self.skipped = 0
		self.onEvent = Signal.new("animation.event")
		return self
	end

	-- ------------------------------------------------------------------ clips
	function Animation:defineClip(id, opts)
		opts = opts or {}
		if self.clips[id] then return nil, "duplicate clip" end
		local clip = Kits.create("clip", { id = id, duration = opts.duration or 1,
			loop = opts.loop ~= false })
		self.clips[id] = clip
		return clip
	end

	-- A procedural walk/run/idle set so a rig is never empty: real keyframes, real curves.
	function Animation:buildLocomotionSet(bones, opts)
		opts = opts or {}
		local made = {}
		local specs = {
			{ id = "idle", duration = 2.4, amplitude = 0.015, frequency = 1 },
			{ id = "walk", duration = 1.05, amplitude = 0.16, frequency = 2 },
			{ id = "run", duration = 0.72, amplitude = 0.30, frequency = 2 },
		}
		for _, spec in ipairs(specs) do
			local clip = self.clips[spec.id] or self:defineClip(spec.id, { duration = spec.duration })
			for index, bone in ipairs(bones) do
				local phase = (index % 2 == 0) and 0.5 or 0
				for k = 0, 4 do
					local t = (k / 4) * spec.duration
					local wave = math.sin((k / 4 + phase) * math.pi * 2 * spec.frequency)
					clip.addKey(bone, "position", t, v3(0, wave * spec.amplitude * 0.35, 0))
					clip.addKey(bone, "rotation", t, v3(wave * spec.amplitude, 0, 0))
				end
			end
			clip.addEvent(spec.duration * 0.25, "footstep", { foot = "left" })
			clip.addEvent(spec.duration * 0.75, "footstep", { foot = "right" })
			made[#made + 1] = spec.id
		end
		return made
	end

	-- ------------------------------------------------------------------ rigs
	function Animation:createRig(id, opts)
		opts = opts or {}
		if self.rigs[id] then return nil, "duplicate rig" end
		local skeleton = Kits.create("skeleton", { id = id })
		local animator = Kits.create("animator", { id = id })
		animator.addLayer("base", { weight = 1 })
		animator.addLayer("upper", { weight = 0, mask = opts.upperMask or {} })
		animator.addLayer("additive", { weight = 0, additive = true })
		for clipId, clip in pairs(self.clips) do animator.addClip(clipId, clip) end
		local rig = { id = id, skeleton = skeleton, animator = animator,
			position = opts.position or v3(), lod = 0, rate = 1, accumulator = 0,
			ragdoll = nil, pose = nil, footTargets = {}, lookTarget = nil,
			evaluations = 0, lastEvents = {} }
		self.rigs[id] = rig
		self.rigOrder[#self.rigOrder + 1] = id
		return rig
	end

	-- A humanoid skeleton with the bones every locomotion system actually needs.
	function Animation:buildHumanoid(rigId)
		local rig = self.rigs[rigId]
		if not rig then return nil, "unknown rig" end
		local s = rig.skeleton
		s.addBone("root", { position = v3(0, 0, 0) })
		s.addBone("hips", { position = v3(0, 1.0, 0), length = 0.2 }, "root")
		s.addBone("spine", { position = v3(0, 0.28, 0), length = 0.28 }, "hips")
		s.addBone("chest", { position = v3(0, 0.26, 0), length = 0.26 }, "spine")
		s.addBone("neck", { position = v3(0, 0.18, 0), length = 0.1 }, "chest")
		s.addBone("head", { position = v3(0, 0.16, 0), length = 0.22 }, "neck")
		for _, side in ipairs({ "L", "R" }) do
			local sign = side == "L" and -1 or 1
			s.addBone(side .. "Shoulder", { position = v3(sign * 0.18, 0.14, 0), length = 0.14 }, "chest")
			s.addBone(side .. "UpperArm", { position = v3(sign * 0.12, 0, 0), length = 0.28 }, side .. "Shoulder")
			s.addBone(side .. "LowerArm", { position = v3(sign * 0.28, 0, 0), length = 0.26 }, side .. "UpperArm")
			s.addBone(side .. "Hand", { position = v3(sign * 0.26, 0, 0), length = 0.1 }, side .. "LowerArm")
			s.addBone(side .. "UpperLeg", { position = v3(sign * 0.1, -0.05, 0), length = 0.42 }, "hips")
			s.addBone(side .. "LowerLeg", { position = v3(0, -0.42, 0), length = 0.4 }, side .. "UpperLeg")
			s.addBone(side .. "Foot", { position = v3(0, -0.4, 0.06), length = 0.16 }, side .. "LowerLeg")
			s.addBone(side .. "Toe", { position = v3(0, -0.06, 0.14), length = 0.08 }, side .. "Foot")
		end
		-- the upper layer only drives the torso and arms
		for _, bone in ipairs({ "chest", "neck", "head", "LShoulder", "LUpperArm", "LLowerArm",
			"LHand", "RShoulder", "RUpperArm", "RLowerArm", "RHand" }) do
			rig.animator.layers.upper.mask[bone] = true
		end
		return s.stats().bones
	end

	function Animation:boneList(rigId, filter)
		local rig = self.rigs[rigId]
		if not rig then return {} end
		local out = {}
		for _, id in ipairs(rig.skeleton.order) do
			if not filter or filter(id) then out[#out + 1] = id end
		end
		return out
	end

	-- ------------------------------------------------------------------ playback
	function Animation:play(rigId, clipId, opts)
		local rig = self.rigs[rigId]
		if not rig then return nil, "unknown rig" end
		if not rig.animator.clips[clipId] and self.clips[clipId] then
			rig.animator.addClip(clipId, self.clips[clipId])
		end
		return rig.animator.play((opts and opts.layer) or "base", clipId, opts)
	end

	-- Locomotion blend tree: one speed parameter walks idle -> walk -> run.
	function Animation:installLocomotionTree(rigId)
		local rig = self.rigs[rigId]
		if not rig then return nil, "unknown rig" end
		for _, id in ipairs({ "idle", "walk", "run" }) do
			if self.clips[id] then rig.animator.addClip(id, self.clips[id]) end
		end
		return rig.animator.setBlendTree("base", {
			{ threshold = 0, clip = "idle" },
			{ threshold = 1.6, clip = "walk" },
			{ threshold = 5.5, clip = "run" },
		}, 0)
	end

	function Animation:setSpeed(rigId, speed)
		local rig = self.rigs[rigId]
		if not rig then return false end
		return rig.animator.setParameter("base", speed)
	end

	-- ------------------------------------------------------------------ LOD & budget
	function Animation:updateLOD(rigId, viewer)
		local rig = self.rigs[rigId]
		if not rig then return nil end
		local distance = rig.position:distance(viewer)
		local band = #Animation.LOD_BANDS + 1
		for i, limit in ipairs(Animation.LOD_BANDS) do
			if distance <= limit then band = i break end
		end
		rig.lod = band - 1
		rig.rate = Animation.LOD_RATES[band] or 0
		return rig.lod, distance
	end

	-- ------------------------------------------------------------------ IK
	function Animation:setFootTarget(rigId, side, groundHeight)
		local rig = self.rigs[rigId]
		if not rig then return false end
		rig.footTargets[side] = groundHeight
		return true
	end

	function Animation:setLookTarget(rigId, target)
		local rig = self.rigs[rigId]
		if not rig then return false end
		rig.lookTarget = target
		return true
	end

	function Animation:solveIK(rigId)
		local rig = self.rigs[rigId]
		if not rig then return 0 end
		local solved = 0
		local s = rig.skeleton
		for side, groundHeight in pairs(rig.footTargets) do
			local hip = s.worldOf(side .. "UpperLeg")
			local knee = s.worldOf(side .. "LowerLeg")
			local foot = s.worldOf(side .. "Foot")
			if hip and knee and foot then
				local target, hipOffset = self.ik.footPlacement(
					v3(foot.position.x, foot.position.y, foot.position.z), groundHeight, 0.45)
				local _, newKnee, newFoot, reached = self.ik.twoBone(
					hip.position, knee.position, foot.position, target, v3(0, 0, 1))
				s.setLocal(side .. "LowerLeg", newKnee - hip.position)
				s.setLocal(side .. "Foot", newFoot - newKnee)
				if hipOffset < 0 then
					local hips = s.bones.hips
					s.setLocal("hips", v3(hips.position.x, hips.position.y + hipOffset * 0.5, hips.position.z))
				end
				solved = solved + 1
				if not reached then rig.ikMiss = true end
			end
		end
		if rig.lookTarget then
			local head = s.worldOf("head")
			if head then
				local dir, angle = self.ik.lookAt(head.position, v3(0, 0, 1), rig.lookTarget, math.rad(75))
				s.setLocal("neck", s.bones.neck.position, v3(0, math.atan(dir.x / math.max(0.001, math.abs(dir.z))) * 0.5, 0))
				rig.lookAngle = angle
				solved = solved + 1
			end
		end
		return solved
	end

	-- ------------------------------------------------------------------ ragdoll
	function Animation:attachRagdoll(rigId)
		local rig = self.rigs[rigId]
		if not rig then return nil, "unknown rig" end
		local ragdoll = Kits.create("ragdoll", { id = rigId })
		local parents = { hips = nil, spine = "hips", chest = "spine", head = "chest",
			LUpperLeg = "hips", LLowerLeg = "LUpperLeg", RUpperLeg = "hips", RLowerLeg = "RUpperLeg",
			LUpperArm = "chest", LLowerArm = "LUpperArm", RUpperArm = "chest", RLowerArm = "RUpperArm" }
		for bone, parent in pairs(parents) do
			local world = rig.skeleton.worldOf(bone)
			if world then
				ragdoll.addBone(bone, { position = world.position, parent = parent,
					length = rig.skeleton.bones[bone].length, mass = 4 })
			end
		end
		rig.ragdoll = ragdoll
		return ragdoll
	end

	function Animation:activateRagdoll(rigId, impulse)
		local rig = self.rigs[rigId]
		if not rig or not rig.ragdoll then return false end
		rig.ragdoll.setAnimatedPose(rig.pose or rig.skeleton.pose())
		return rig.ragdoll.activate(impulse)
	end

	function Animation:recoverRagdoll(rigId, dt)
		local rig = self.rigs[rigId]
		if not rig or not rig.ragdoll then return 0 end
		return rig.ragdoll.recover(dt or (1 / 60))
	end

	-- ------------------------------------------------------------------ the frame
	function Animation:evaluate(rigId, dt)
		local rig = self.rigs[rigId]
		if not rig then return nil end
		rig.evaluations = rig.evaluations + 1
		self.evaluations = self.evaluations + 1
		local pose, events = rig.animator.evaluate(dt, rig.skeleton)
		if rig.ragdoll and rig.ragdoll.active then
			rig.ragdoll.setAnimatedPose(pose)
			rig.ragdoll.step(dt, 0)
			pose = rig.ragdoll.pose()
		end
		rig.skeleton.applyPose(pose, 1)
		rig.pose = pose
		rig.lastEvents = events
		for _, e in ipairs(events) do self.onEvent:fire({ rig = rigId, event = e }) end
		return pose, events
	end

	-- Update every rig, honouring LOD rates and the per-frame budget. Nearest first.
	function Animation:update(dt, viewer)
		self.frame = self.frame + 1
		viewer = viewer or v3()
		local candidates = {}
		for _, id in ipairs(self.rigOrder) do
			local rig = self.rigs[id]
			self:updateLOD(id, viewer)
			if rig.rate > 0 then
				rig.accumulator = rig.accumulator + 1
				if rig.accumulator >= rig.rate then
					candidates[#candidates + 1] = { id = id, distance = rig.position:distance(viewer) }
				end
			end
		end
		table.sort(candidates, function(a, b) return a.distance < b.distance end)
		local evaluated = 0
		for _, c in ipairs(candidates) do
			if evaluated >= self.budget then
				self.skipped = self.skipped + 1
			else
				local rig = self.rigs[c.id]
				self:evaluate(c.id, dt * rig.accumulator)
				rig.accumulator = 0
				evaluated = evaluated + 1
			end
		end
		return { evaluated = evaluated, candidates = #candidates, frame = self.frame }
	end

	function Animation:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.budget = math.max(4, math.floor(4 + quality * 40))
		self.ik.iterations = math.max(2, math.floor(2 + quality * 8))
		Animation.LOD_BANDS = { 15 + quality * 25, 45 + quality * 45, 110 + quality * 90 }
		return { budget = self.budget, ikIterations = self.ik.iterations }
	end

	function Animation:report()
		local bones, ragdolls = 0, 0
		for _, id in ipairs(self.rigOrder) do
			bones = bones + #self.rigs[id].skeleton.order
			if self.rigs[id].ragdoll then ragdolls = ragdolls + 1 end
		end
		local clipCount, keys = 0, 0
		for _, clip in pairs(self.clips) do
			clipCount = clipCount + 1
			keys = keys + clip.keyCount()
		end
		return { rigs = #self.rigOrder, bones = bones, ragdolls = ragdolls,
			clips = clipCount, keys = keys, frame = self.frame,
			evaluations = self.evaluations, skipped = self.skipped,
			budget = self.budget, ik = self.ik.stats() }
	end

	return Animation
end
