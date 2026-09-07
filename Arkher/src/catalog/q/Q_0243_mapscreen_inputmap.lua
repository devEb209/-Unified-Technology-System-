-- ARKHER SYSTEM Q.0243 :: Map Screen Input Mapping
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: inputmap (one action bound to touch, gamepad, keyboard and mouse)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0243"
	S.key = "arkher.ui.mapscreen.input_mapping"
	S.name = "Map Screen Input Mapping"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Map Screen"
	S.aspect = "Input Mapping"
	S.kit = "inputmap"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.mapscreen.widget_tree" }
	S.tags = { "q", "mapscreen", "inputmap", "ui" }
	S.description = "Map Screen Input Mapping: one action bound to touch, gamepad, keyboard and mouse for the Map Screen subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 440,
		baseWeight = 0.51,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 367,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.71,
		scale = 1.1
	}
	S.features = { "bind", "press", "release", "isDown", "wasTapped", "isHeld", "chordActive", "setAxis", "axis", "thumbstick", "touchAt", "tick", "setDevice", "bindingsFor", "stats", "installActions", "tap", "holdFor", "move", "releaseAll", "deviceBindings", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("inputmap", { id = "arkher.ui.mapscreen.input_mapping", device = "gamepad", holdTime = 0.36, deadzone = 0.11 })
		inst.system = S
		inst.ctx = ctx

		function inst.installActions()
			if #inst.order > 0 then return #inst.order end
			inst.bind("jump", { keys = { "Space" }, buttons = { "A" },
				touchZone = { x = 0, y = 0, width = 96, height = 96 } })
			inst.bind("crouch", { keys = { "C" }, buttons = { "B" } })
			inst.bind("slide", { chord = { "jump", "crouch" } })
			return #inst.order
		end
		function inst.tap(action)
			inst.installActions()
			inst.press(action or "jump")
			inst.tick(0.05)
			inst.release(action or "jump")
			return inst.wasTapped(action or "jump")
		end
		function inst.holdFor(action, seconds)
			inst.installActions()
			inst.press(action or "jump")
			inst.tick(seconds or (inst.holdTime + 0.1))
			return inst.isHeld(action or "jump")
		end
		function inst.move(x, y)
			inst.installActions()
			return inst.setAxis("move", x or 1, y or 0)
		end
		function inst.releaseAll()
			for _, name in ipairs(inst.order) do inst.release(name) end
			return true
		end
		function inst.deviceBindings(device)
			inst.installActions()
			return inst.bindingsFor(device or inst.device)
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
				engine.bus:subscribe("arkher.ui.mapscreen.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installActions() == 3
		ok = ok and inst.tap("jump")
		ok = ok and not inst.wasTapped("jump")
		ok = ok and inst.holdFor("jump", inst.holdTime + 0.1)
		inst.press("crouch")
		ok = ok and inst.chordActive("slide")
		inst.releaseAll()
		ok = ok and not inst.isDown("jump")
		local axis = inst.move(inst.deadzone * 0.5, 0)
		ok = ok and axis.magnitude == 0
		axis = inst.move(1, 0)
		ok = ok and axis.magnitude > 0.9
		ok = ok and #inst.deviceBindings("keyboard") >= 2
		return ok and inst.stats().presses > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
