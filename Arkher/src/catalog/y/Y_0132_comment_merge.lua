-- ARKHER SYSTEM Y.0132 :: Comment Merge Engine
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: merge (three-way reconciliation and conflict handling)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0132"
	S.key = "arkher.collab.comment.merge_engine"
	S.name = "Comment Merge Engine"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Comment"
	S.aspect = "Merge Engine"
	S.kit = "merge"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.comment.live_session" }
	S.tags = { "y", "comment", "merge", "collab" }
	S.description = "Comment Merge Engine: three-way reconciliation and conflict handling for the Comment subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 440,
		baseWeight = 0.61,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 467,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.81,
		scale = 1.1
	}
	S.features = { "diff", "threeWay", "resolve", "hasConflicts", "conflictPaths", "stats", "mergeStates", "autoResolve", "conflictReport", "divergence", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("merge", { id = "arkher.collab.comment.merge_engine", strategy = "ours" })
		inst.system = S
		inst.ctx = ctx

		function inst.mergeStates(base, ours, theirs) return inst.threeWay(base, ours, theirs) end
		function inst.autoResolve(choice)
			local paths = inst.conflictPaths()
			local n = 0
			for _, path in ipairs(paths) do
				if inst.resolve(path, choice or "ours") then n = n + 1 end
			end
			return n
		end
		function inst.conflictReport()
			local out = {}
			for _, c in ipairs(inst.conflicts) do
				out[#out + 1] = { path = c.path, base = c.base, ours = c.ours, theirs = c.theirs }
			end
			return out
		end
		function inst.divergence(a, b)
			local d = inst.diff(a, b)
			local n = 0
			for _ in pairs(d or {}) do n = n + 1 end
			return n
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
				engine.bus:subscribe("arkher.collab.comment.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local base = { alpha = 1, beta = 2, nested = { gamma = 3 } }
		local ours = { alpha = 5, beta = 2, nested = { gamma = 3 } }
		local theirs = { alpha = 1, beta = 9, nested = { gamma = 7 } }
		local merged, conflicts = inst.mergeStates(base, ours, theirs)
		local ok = #conflicts == 0 and merged.alpha == 5 and merged.beta == 9 and merged.nested.gamma == 7
		local _, conflicts2 = inst.mergeStates({ v = 1 }, { v = 2 }, { v = 3 })
		ok = ok and #conflicts2 == 1 and #inst.conflictReport() == 1
		ok = ok and inst.autoResolve("theirs") == 1 and inst.hasConflicts() == false
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
