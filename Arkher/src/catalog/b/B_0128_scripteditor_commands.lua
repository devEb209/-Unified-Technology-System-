-- ARKHER SYSTEM B.0128 :: Script Editor Command Stack
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: commands (undoable operations with grouping and coalescing)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0128"
	S.key = "arkher.studio.scripteditor.command_stack"
	S.name = "Script Editor Command Stack"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Script Editor"
	S.aspect = "Command Stack"
	S.kit = "commands"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.scripteditor.document_model" }
	S.tags = { "b", "scripteditor", "commands", "studio" }
	S.description = "Script Editor Command Stack: undoable operations with grouping and coalescing for the Script Editor subsystem."
	S.params = {
		backlogLimit = 9,
		baseRadius = 520,
		baseWeight = 0.51,
		bias = 0.01,
		biasWeight = 0.06,
		ceiling = 369,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.41,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.71,
		scale = 3.1
	}
	S.features = { "execute", "beginGroup", "endGroup", "undo", "redo", "canUndo", "canRedo", "tick", "historyLabels", "clear", "stats", "push", "undoAll", "redoAll", "depth", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("commands", { id = "arkher.studio.scripteditor.command_stack", limit = 241, coalesceWindow = 0.21 })
		inst.system = S
		inst.ctx = ctx

		function inst.push(label, doFn, undoFn, coalesceKey)
			return inst.execute({ label = label, doFn = doFn, undoFn = undoFn, coalesceKey = coalesceKey })
		end
		function inst.undoAll()
			local n = 0
			while inst.canUndo() do
				if not inst.undo() then break end
				n = n + 1
			end
			return n
		end
		function inst.redoAll()
			local n = 0
			while inst.canRedo() do
				if not inst.redo() then break end
				n = n + 1
			end
			return n
		end
		function inst.depth() return #inst.undoStack, #inst.redoStack end

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
				engine.bus:subscribe("arkher.studio.scripteditor.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.clear()
		local value = 0
		for i = 1, 3 do
			inst.push("probe." .. i, function() value = value + i end, function() value = value - i end)
		end
		local ok = value == 6
		ok = ok and inst.undoAll() == 3 and value == 0
		ok = ok and inst.redoAll() == 3 and value == 6
		inst.undoAll()
		inst.clear()
		return ok and inst.canUndo() == false
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
