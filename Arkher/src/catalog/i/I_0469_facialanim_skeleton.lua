-- ARKHER SYSTEM I.0469 :: Facial Animation Skeleton
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: skeleton (bone hierarchy, bind pose and world resolution)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0469"
	S.key = "arkher.anim.facialanim.skeleton"
	S.name = "Facial Animation Skeleton"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Facial Animation"
	S.aspect = "Skeleton"
	S.kit = "skeleton"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "i", "facialanim", "skeleton", "anim" }
	S.description = "Facial Animation Skeleton: bone hierarchy, bind pose and world resolution for the Facial Animation subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 440,
		baseWeight = 0.71,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 347,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.91,
		scale = 1.1
	}
	S.features = { "addBone", "setLocal", "worldOf", "invalidate", "invalidateSubtree", "chain", "depthOf", "pose", "applyPose", "blend", "additive", "resetToBind", "setMask", "stats", "buildChain", "tip", "height", "snapshotPose", "mirrorPose", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("skeleton", { id = "arkher.anim.facialanim.skeleton" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildChain(count, spacing)
			if #inst.order > 0 then return #inst.order end
			inst.addBone("b0", { position = Vec.vec3(0, 0, 0) })
			for i = 1, (count or 4) do
				inst.addBone("b" .. i, { position = Vec.vec3(0, spacing or 0.5, 0),
					length = spacing or 0.5 }, "b" .. (i - 1))
			end
			return #inst.order
		end
		function inst.tip()
			inst.buildChain(4)
			return inst.worldOf(inst.order[#inst.order]).position
		end
		function inst.height()
			return inst.tip().y
		end
		function inst.snapshotPose()
			inst.buildChain(4)
			return inst.pose()
		end
		function inst.mirrorPose(pose, weight)
			inst.buildChain(4)
			return inst.applyPose(pose, weight or 1)
		end

		function inst.describe()
			return { id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return { system = S.key, status = status, stats = st }
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("arkher.anim.facialanim.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildChain(4, 0.5) == 5
		ok = ok and math.abs(inst.height() - 2.0) < 0.001
		local pose = inst.snapshotPose()
		ok = ok and pose.b4 ~= nil
		inst.setLocal("b1", Vec.vec3(0, 1.0, 0))
		ok = ok and inst.height() > 2.0
		ok = ok and inst.depthOf("b4") == 4 and #inst.chain("b0", "b4") == 5
		inst.resetToBind()
		ok = ok and math.abs(inst.height() - 2.0) < 0.001
		ok = ok and inst.mirrorPose(pose, 1) == 5
		return ok and inst.stats().bones == 5
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
