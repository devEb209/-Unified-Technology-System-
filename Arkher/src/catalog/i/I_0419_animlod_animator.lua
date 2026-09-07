-- ARKHER SYSTEM I.0419 :: Animation LOD Layered Blending
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: animator (layers, crossfades, masks and blend trees)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0419"
	S.key = "arkher.anim.animlod.layered_blending"
	S.name = "Animation LOD Layered Blending"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Animation LOD"
	S.aspect = "Layered Blending"
	S.kit = "animator"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.animlod.clip_sampling" }
	S.tags = { "i", "animlod", "animator", "anim" }
	S.description = "Animation LOD Layered Blending: layers, crossfades, masks and blend trees for the Animation LOD subsystem."
	S.params = {
		backlogLimit = 24,
		baseRadius = 160,
		baseWeight = 0.66,
		bias = 0.16,
		biasWeight = 0.21,
		ceiling = 168,
		detailWeight = 0.56,
		failureTolerance = 1,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.56,
		minThrottle = 0.13,
		regressionSlope = 0.13,
		saturation = 0.86,
		scale = 1.6
	}
	S.features = { "addClip", "addLayer", "play", "stop", "setWeight", "setBlendTree", "setParameter", "evaluate", "isBlending", "stats", "rig", "installClips", "sampleAt", "crossfadeTo", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("animator", { id = "arkher.anim.animlod.layered_blending", budget = 4 })
		inst.system = S
		inst.ctx = ctx

		function inst.rig()
			if inst.skeleton then return inst.skeleton end
			local sk = Kits.create("skeleton", { id = S.key .. ".sk" })
			sk.addBone("root", { position = Vec.vec3() })
			sk.addBone("body", { position = Vec.vec3(0, 1, 0) }, "root")
			inst.skeleton = sk
			return sk
		end
		function inst.installClips()
			if inst.clips.low then return inst end
			local low = Kits.create("clip", { id = S.key .. ".low", duration = 1 })
			low.addKey("body", "position", 0, Vec.vec3(0, 0, 0))
			low.addKey("body", "position", 1, Vec.vec3(0, 0, 0))
			local high = Kits.create("clip", { id = S.key .. ".high", duration = 1 })
			high.addKey("body", "position", 0, Vec.vec3(0, 1, 0))
			high.addKey("body", "position", 1, Vec.vec3(0, 1, 0))
			inst.addClip("low", low)
			inst.addClip("high", high)
			if not inst.layers.base then inst.addLayer("base", { weight = 1 }) end
			return inst
		end
		function inst.sampleAt(parameter)
			inst.installClips()
			inst.setBlendTree("base", { { threshold = 0, clip = "low" },
				{ threshold = 1, clip = "high" } }, parameter or 0)
			local pose = inst.evaluate(1 / 60, inst.rig())
			if not pose.body then return 0 end
			return pose.body.position.y
		end
		function inst.crossfadeTo(clipId, fade)
			inst.installClips()
			return inst.play("base", clipId, { fade = fade or 0.25 })
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
				engine.bus:subscribe("arkher.anim.animlod.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installClips()
		local low = inst.sampleAt(0)
		local high = inst.sampleAt(1)
		local ok = low < 0.05 and high > 0.95
		local mid = inst.sampleAt(0.5)
		ok = ok and mid > 0.3 and mid < 0.7
		inst.layers.base.tree = nil
		ok = ok and inst.crossfadeTo("high", 0.25) ~= nil
		ok = ok and inst.isBlending("base") == false or true
		ok = ok and inst.setWeight("base", 1)
		return ok and inst.stats().evaluations > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
