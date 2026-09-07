-- ARKHER SYSTEM F.0282 :: Color Grading View And Culling
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: camera (view state, frustum culling and screen-size LOD)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0282"
	S.key = "arkher.render.grading.view_and_culling"
	S.name = "Color Grading View And Culling"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Color Grading"
	S.aspect = "View And Culling"
	S.kit = "camera"
	S.version = "1.0.0"
	S.deps = { "arkher.render.grading.frame_graph" }
	S.tags = { "f", "grading", "camera", "render" }
	S.description = "Color Grading View And Culling: view state, frustum culling and screen-size LOD for the Color Grading subsystem."
	S.params = {
		backlogLimit = 42,
		baseRadius = 560,
		baseWeight = 0.84,
		bias = 0.34,
		biasWeight = 0.19,
		ceiling = 530,
		detailWeight = 0.54,
		failureTolerance = 4,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.74,
		minThrottle = 0.12,
		regressionSlope = 0.12,
		saturation = 0.79,
		scale = 1.4
	}
	S.features = { "setPosition", "lookAt", "setFov", "setViewport", "forward", "buildFrustum", "visibleSphere", "cull", "project", "screenRadius", "lodFor", "jitter", "autoExposure", "advance", "stats", "frame", "visible", "detailLevel", "subpixel", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("camera", { id = "arkher.render.grading.view_and_culling", width = 1340, height = 1080, fov = 1.2400, far = 2000 })
		inst.system = S
		inst.ctx = ctx

		function inst.frame(target)
			inst.setPosition(Vec.vec3(0, S.params.detailWeight * 20, 0))
			inst.lookAt(target or Vec.vec3(0, 0, -100))
			return inst.buildFrustum()
		end
		function inst.visible(items)
			inst.frame()
			return inst.cull(items)
		end
		function inst.detailLevel(distance, radius)
			inst.frame()
			return inst.lodFor(Vec.vec3(0, 0, -(distance or 100)), radius or 2)
		end
		function inst.subpixel(frameIndex)
			return inst.jitter(frameIndex or 1)
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
				engine.bus:subscribe("arkher.render.grading.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.frame(Vec.vec3(0, 0, -100))
		local ok = inst.visibleSphere(Vec.vec3(0, 0, -50), 5) == true
		ok = ok and inst.visibleSphere(Vec.vec3(0, 0, 500), 5) == false
		local p = inst.project(Vec.vec3(0, inst.position.y, -20))
		ok = ok and p ~= nil and math.abs(p.x - inst.width / 2) < 2
		ok = ok and inst.project(Vec.vec3(0, 0, 1000)) == nil
		local nearLod = inst.detailLevel(10, 2)
		local farLod = inst.detailLevel(900, 2)
		ok = ok and nearLod <= farLod
		local jx, jy = inst.subpixel(3)
		ok = ok and math.abs(jx) <= 0.5 and math.abs(jy) <= 0.5
		ok = ok and inst.autoExposure(0.18, 1 / 60) > 0
		return ok and inst.stats().tested > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
