-- ARKHER SYSTEM I.0212 :: Transition Rule Inverse Kinematics
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: ik (two-bone, FABRIK and constrained look-at solving)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0212"
	S.key = "arkher.anim.transitionrule.inverse_kinematics"
	S.name = "Transition Rule Inverse Kinematics"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Transition Rule"
	S.aspect = "Inverse Kinematics"
	S.kit = "ik"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.transitionrule.layered_blending" }
	S.tags = { "i", "transitionrule", "ik", "anim" }
	S.description = "Transition Rule Inverse Kinematics: two-bone, FABRIK and constrained look-at solving for the Transition Rule subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 160,
		baseWeight = 0.6,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 436,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.8,
		scale = 1.0
	}
	S.features = { "twoBone", "fabrik", "lookAt", "footPlacement", "stats", "solveLeg", "reachError", "chainTo", "aim", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ik", { id = "arkher.anim.transitionrule.inverse_kinematics", iterations = 4, tolerance = 0.0010 })
		inst.system = S
		inst.ctx = ctx

		function inst.solveLeg(target)
			local hip = Vec.vec3(0, 2, 0)
			local knee = Vec.vec3(0, 1, 0)
			local foot = Vec.vec3(0, 0, 0)
			return inst.twoBone(hip, knee, foot, target or Vec.vec3(0.8, 1, 0), Vec.vec3(0, 0, 1))
		end
		function inst.reachError(target)
			local _, _, effector = inst.solveLeg(target)
			return (effector - (target or Vec.vec3(0.8, 1, 0))):length()
		end
		function inst.chainTo(target, links)
			local points = {}
			for i = 0, (links or 3) do points[i + 1] = Vec.vec3(i, 0, 0) end
			return inst.fabrik(points, target or Vec.vec3(1, 1, 0), inst.iterations)
		end
		function inst.aim(target, maxAngle)
			return inst.lookAt(Vec.vec3(), Vec.vec3(0, 0, 1), target or Vec.vec3(1, 0, 0), maxAngle)
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
				engine.bus:subscribe("arkher.anim.transitionrule.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.reachError(Vec.vec3(0.8, 1, 0)) < 0.05
		local _, _, far, reached = inst.solveLeg(Vec.vec3(40, 2, 0))
		ok = ok and reached == false and far ~= nil
		local chain = inst.chainTo(Vec.vec3(1.5, 1.5, 0), 3)
		ok = ok and #chain == 4 and (chain[1] - Vec.vec3(0, 0, 0)):length() < 0.001
		local dir, angle = inst.aim(Vec.vec3(1, 0, 0), math.rad(30))
		ok = ok and math.abs(angle - math.rad(30)) < 0.001 and dir:length() > 0.9
		local placed, offset = inst.footPlacement(Vec.vec3(0, 0.2, 0), 0, 0.45)
		ok = ok and math.abs(placed.y) < 0.001 and offset == 0
		return ok and inst.stats().solves > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
