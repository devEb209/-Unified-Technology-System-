-- ARKHER SYSTEM N.0277 :: Heal Effect Ribbon And Trail
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: ribbon (trail points, tapering, beams and decimation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0277"
	S.key = "arkher.vfx.healfx.ribbon_and_trail"
	S.name = "Heal Effect Ribbon And Trail"
	S.category = "N"
	S.family = "VFX"
	S.area = "Heal Effect"
	S.aspect = "Ribbon And Trail"
	S.kit = "ribbon"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.healfx.force_field" }
	S.tags = { "n", "healfx", "ribbon", "vfx" }
	S.description = "Heal Effect Ribbon And Trail: trail points, tapering, beams and decimation for the Heal Effect subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 400,
		baseWeight = 0.68,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 126,
		detailWeight = 0.38,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.19,
		regressionSlope = 0.14,
		saturation = 0.88,
		scale = 2.8
	}
	S.features = { "push", "update", "setWidth", "widthAt", "vertices", "length", "beam", "simplify", "clear", "stats", "traceLine", "follow", "stripCount", "fade", "beamTo", "taperProfile", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ribbon", { id = "arkher.vfx.healfx.ribbon_and_trail", maxPoints = 16, lifetime = 2.30, minDistance = 0.50, width = 0.80 })
		inst.system = S
		inst.ctx = ctx

		function inst.traceLine(from, to, steps)
			from = from or Vec.vec3()
			to = to or Vec.vec3(8, 0, 0)
			local n = steps or 6
			local pushed = 0
			for i = 0, n do
				if inst.push(from:lerp(to, i / n)) then pushed = pushed + 1 end
			end
			return pushed
		end
		function inst.follow(points)
			local pushed = 0
			for _, p in ipairs(points) do
				if inst.push(p) then pushed = pushed + 1 end
			end
			return pushed
		end
		function inst.stripCount(cameraPosition)
			return #inst.vertices(cameraPosition or Vec.vec3(0, 6, -6))
		end
		function inst.fade(seconds, dt)
			local step = dt or 1 / 30
			local steps = math.max(1, math.floor((seconds or 0.5) / step))
			for _ = 1, steps do inst.update(step) end
			return #inst.points
		end
		function inst.beamTo(target, segments)
			return inst.beam(Vec.vec3(), target or Vec.vec3(10, 0, 0), segments or 6, 1)
		end
		function inst.taperProfile()
			local out = {}
			for i = 1, #inst.points do out[i] = inst.widthAt(i) end
			return out
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
				engine.bus:subscribe("arkher.vfx.healfx.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local pushed = inst.traceLine(Vec.vec3(), Vec.vec3(6, 0, 0), 5)
		local ok = pushed > 0 and inst.length() > 0
		ok = ok and inst.stripCount() == #inst.points * 2
		ok = ok and #inst.taperProfile() == #inst.points
		ok = ok and inst.simplify(0.001) <= #inst.points + 1
		ok = ok and inst.fade(inst.lifetime + 0.2, 1 / 20) == 0
		ok = ok and inst.beamTo(Vec.vec3(9, 1, 0), 5) >= 2
		inst.clear()
		return ok and inst.stats().points == 0 and inst.stats().pushes > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
