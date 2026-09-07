-- ARKHER SYSTEM H.0006 :: Rigid Body Character Motion
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: charmotor (capsule move-and-slide with slopes, steps and jumps)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0006"
	S.key = "arkher.physics.rigidbody.character_motion"
	S.name = "Rigid Body Character Motion"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Rigid Body"
	S.aspect = "Character Motion"
	S.kit = "charmotor"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.rigidbody.query" }
	S.tags = { "h", "rigidbody", "charmotor", "physics" }
	S.description = "Rigid Body Character Motion: capsule move-and-slide with slopes, steps and jumps for the Rigid Body subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 560,
		baseWeight = 0.92,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 210,
		detailWeight = 0.42,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.21,
		regressionSlope = 0.06,
		saturation = 0.87,
		scale = 3.2
	}
	S.features = { "jumpVelocity", "setGround", "canStand", "jump", "crouch", "slide", "move", "speed", "locomotionState", "stats", "placeAt", "walk", "wallCollide", "travelled", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("charmotor", { id = "arkher.physics.rigidbody.character_motion", radius = 0.37, height = 1.62, maxSpeed = 6.20, jumpHeight = 2.20, stepOffset = 0.47 })
		inst.system = S
		inst.ctx = ctx

		function inst.placeAt(position)
			inst.position = position or Vec.vec3()
			inst.velocity = Vec.vec3()
			return inst.position
		end
		function inst.walk(direction, seconds, collide)
			local steps = math.max(1, math.floor((seconds or 0.5) * 60))
			for _ = 1, steps do inst.move(direction, 1 / 60, collide) end
			return inst.position, inst.speed()
		end
		function inst.wallCollide(limitX)
			return function(from, to)
				if to.x > (limitX or 5) then
					return { normal = Vec.vec3(-1, 0, 0), distance = 0, point = Vec.vec3(limitX or 5, 0, 0) }
				end
				return nil
			end
		end
		function inst.travelled(direction, seconds)
			local start = inst.position
			inst.walk(direction, seconds)
			return (inst.position - start):length()
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
				engine.bus:subscribe("arkher.physics.rigidbody.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.placeAt(Vec.vec3())
		inst.setGround(true, Vec.vec3(0, 1, 0))
		local ok = inst.canStand()
		ok = ok and inst.travelled(Vec.vec3(1, 0, 0), 0.5) > 0.2
		ok = ok and inst.speed() > 0
		ok = ok and inst.jump() and inst.velocity.y > 0
		inst.setGround(true, Vec.vec3(0, 1, 0))
		local tall = inst.height
		inst.crouch(true)
		ok = ok and inst.height < tall
		inst.crouch(false)
		inst.placeAt(Vec.vec3(4.9, 0, 0))
		inst.setGround(true, Vec.vec3(0, 1, 0))
		inst.walk(Vec.vec3(1, 0, 0), 0.2, inst.wallCollide(5))
		ok = ok and inst.position.x <= 5.3
		return ok and inst.stats().steps > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
