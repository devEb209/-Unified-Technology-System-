-- ARKHER SYSTEM R.0073 :: Transform Replication Replication
-- Category R - NETWORKING
-- ARKHER Networking Framework capability: authoritative replication, prediction and bandwidth discipline.
-- Kit: replicator (authoritative entity state, interest and delta snapshots)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "R.0073"
	S.key = "arkher.net.transformreplication.replication"
	S.name = "Transform Replication Replication"
	S.category = "R"
	S.family = "NETWORKING"
	S.area = "Transform Replication"
	S.aspect = "Replication"
	S.kit = "replicator"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "r", "transformreplication", "replicator", "net" }
	S.description = "Transform Replication Replication: authoritative entity state, interest and delta snapshots for the Transform Replication subsystem."
	S.params = {
		backlogLimit = 43,
		baseRadius = 280,
		baseWeight = 0.95,
		bias = 0.35,
		biasWeight = 0.2,
		ceiling = 395,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.75,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.9,
		scale = 2.5
	}
	S.features = { "spawn", "despawn", "set", "move", "addClient", "moveClient", "interestSet", "snapshotFor", "flush", "apply", "overMTU", "split", "bandwidth", "applyQuality", "stats", "installWorld", "connectViewer", "pump", "mirror", "fragments", "visibleTo", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("replicator", { id = "arkher.net.transformreplication.replication", mtu = 1050, interestRadius = 320, fullEvery = 75 })
		inst.system = S
		inst.ctx = ctx

		function inst.installWorld(count)
			if #inst.order > 0 then return #inst.order end
			for i = 1, (count or 4) do
				inst.spawn("ent" .. i, { hp = 100, tier = i },
					Vec.vec3(i * 12, 0, i * 6))
			end
			return #inst.order
		end
		function inst.connectViewer(clientId, position)
			inst.installWorld()
			return inst.addClient(clientId or "viewer", position or Vec.vec3())
		end
		function inst.pump(steps)
			inst.connectViewer("viewer", Vec.vec3())
			local packets = 0
			for i = 1, (steps or 2) do
				inst.set("ent1", "hp", 100 - i)
				local sent = inst.flush()
				for _ in pairs(sent) do packets = packets + 1 end
			end
			return packets
		end
		function inst.mirror(clientId)
			inst.connectViewer(clientId or "viewer", Vec.vec3())
			local packet = inst.snapshotFor(clientId or "viewer")
			local target = {}
			inst.apply(packet, target)
			return target
		end
		function inst.fragments(clientId)
			inst.connectViewer(clientId or "viewer", Vec.vec3())
			return inst.split(inst.snapshotFor(clientId or "viewer"))
		end
		function inst.visibleTo(clientId)
			inst.connectViewer(clientId or "viewer", Vec.vec3())
			return #inst.interestSet(clientId or "viewer")
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
				engine.bus:subscribe("arkher.net.transformreplication.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installWorld(4) == 4
		ok = ok and inst.connectViewer("viewer", Vec.vec3()) ~= nil
		ok = ok and inst.visibleTo("viewer") >= 1
		local mirrored = inst.mirror("viewer")
		ok = ok and mirrored.ent1 ~= nil and mirrored.ent1.hp == 100
		inst.flush()
		ok = ok and inst.pump(2) >= 1
		local parts = inst.fragments("viewer")
		ok = ok and #parts >= 0
		for _, part in ipairs(parts) do ok = ok and part.bytes <= inst.mtu * 2 end
		inst.move("ent1", Vec.vec3(4, 0, 0))
		ok = ok and inst.despawn("ent4")
		return ok and inst.bandwidth() >= 0 and inst.stats().entities == 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
