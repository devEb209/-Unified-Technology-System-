-- ARKHER SYSTEM J.0225 :: Character Variant Physical Response
-- Category J - CHARACTERS / DIGITAL HUMANS
-- ARKHER Digital Human capability: a body that moves, reacts, dresses, ages and scales to a crowd.
-- Kit: ragdoll (physical reaction, ragdoll and recovery)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "J.0225"
	S.key = "arkher.character.charvariant.physical_response"
	S.name = "Character Variant Physical Response"
	S.category = "J"
	S.family = "CHARACTERS / DIGITAL HUMANS"
	S.area = "Character Variant"
	S.aspect = "Physical Response"
	S.kit = "ragdoll"
	S.version = "1.0.0"
	S.deps = { "arkher.character.charvariant.look_and_reach" }
	S.tags = { "j", "charvariant", "ragdoll", "character" }
	S.description = "Character Variant Physical Response: physical reaction, ragdoll and recovery for the Character Variant subsystem."
	S.params = {
		backlogLimit = 16,
		baseRadius = 160,
		baseWeight = 0.98,
		bias = 0.08,
		biasWeight = 0.13,
		ceiling = 400,
		detailWeight = 0.68,
		failureTolerance = 3,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.48,
		minThrottle = 0.19,
		regressionSlope = 0.09,
		saturation = 0.93,
		scale = 2.8
	}
	S.features = { "addBone", "setAnimatedPose", "activate", "deactivate", "step", "settled", "pose", "recover", "centerOfMass", "stats", "buildTorso", "animatedRest", "collapse", "linkLength", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ragdoll", { id = "arkher.character.charvariant.physical_response", blendSpeed = 2.80 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildTorso()
			if #inst.order > 0 then return #inst.order end
			inst.addBone("hips", { position = Vec.vec3(0, 2, 0), mass = 8 })
			inst.addBone("chest", { position = Vec.vec3(0, 2.4, 0), parent = "hips",
				length = 0.4, mass = 6 })
			inst.addBone("head", { position = Vec.vec3(0, 2.8, 0), parent = "chest",
				length = 0.4, mass = 4 })
			return #inst.order
		end
		function inst.animatedRest()
			inst.buildTorso()
			return inst.setAnimatedPose({
				hips = { position = Vec.vec3(0, 2, 0) },
				chest = { position = Vec.vec3(0, 2.4, 0) },
				head = { position = Vec.vec3(0, 2.8, 0) } })
		end
		function inst.collapse(seconds, impulse)
			inst.animatedRest()
			inst.activate(impulse or Vec.vec3(1, 0, 0))
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do inst.step(1 / 60, 0) end
			return inst.centerOfMass()
		end
		function inst.linkLength(a, b)
			inst.buildTorso()
			return (inst.bones[a].position - inst.bones[b].position):length()
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
				engine.bus:subscribe("arkher.character.charvariant.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildTorso() == 3
		ok = ok and inst.animatedRest() == 3
		local com = inst.collapse(2.0, Vec.vec3(1, 0, 0))
		ok = ok and com.y < 2.4 and com.y > -0.5
		ok = ok and math.abs(inst.linkLength("head", "chest") - 0.4) < 0.2
		ok = ok and inst.settled()
		local pose = inst.pose()
		ok = ok and pose.head ~= nil
		inst.recover(1)
		return ok and inst.active == false
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
