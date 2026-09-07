-- ARKHER SYSTEM Y.0321 :: Version Tag Live Session
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: session (presence, locks and operation log)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0321"
	S.key = "arkher.collab.versiontag.live_session"
	S.name = "Version Tag Live Session"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Version Tag"
	S.aspect = "Live Session"
	S.kit = "session"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "y", "versiontag", "session", "collab" }
	S.description = "Version Tag Live Session: presence, locks and operation log for the Version Tag subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 400,
		baseWeight = 0.92,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 378,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.87,
		scale = 2.2
	}
	S.features = { "join", "leave", "acquireLock", "releaseLock", "submit", "rebase", "since", "updatePresence", "activeUsers", "stats", "openWith", "editPath", "lockedEdit", "conflictRate", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("session", { id = "arkher.collab.versiontag.live_session", maxOps = 4922 })
		inst.system = S
		inst.ctx = ctx

		function inst.openWith(users)
			for _, u in ipairs(users) do inst.join(u.id or u, u.role or "editor") end
			return #inst.activeUsers()
		end
		function inst.editPath(userId, path, value)
			return inst.submit(userId, { kind = "set", path = path, value = value })
		end
		function inst.lockedEdit(userId, path, value)
			local ok, holder = inst.acquireLock(userId, path)
			if not ok then return false, holder end
			local applied = inst.editPath(userId, path, value)
			inst.releaseLock(userId, path)
			return applied
		end
		function inst.conflictRate()
			local st = inst.stats()
			return st.conflicts / math.max(1, st.ops + st.conflicts)
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
				engine.bus:subscribe("arkher.collab.versiontag.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.openWith({ { id = "probe.a", role = "editor" }, { id = "probe.b", role = "editor" },
			{ id = "probe.v", role = "viewer" } })
		local ok = #inst.activeUsers() == 3
		ok = ok and inst.acquireLock("probe.a", "probe.path")
		ok = ok and inst.editPath("probe.a", "probe.path", 1)
		ok = ok and inst.editPath("probe.b", "probe.path", 2) == false
		ok = ok and inst.editPath("probe.v", "probe.other", 3) == false
		inst.releaseLock("probe.a", "probe.path")
		ok = ok and #inst.since(0) == 1
		local rebased = inst.rebase({ kind = "set", path = "probe.path", value = 9 }, 0)
		ok = ok and rebased ~= nil and rebased.conflict == true
		ok = ok and inst.lockedEdit("probe.b", "probe.other", 4)
		inst.leave("probe.a") inst.leave("probe.b") inst.leave("probe.v")
		return ok and #inst.activeUsers() == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
