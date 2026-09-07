-- ARKHER SYSTEM R.0122 :: Reliable Channel Time Sync
-- Category R - NETWORKING
-- ARKHER Networking Framework capability: authoritative replication, prediction and bandwidth discipline.
-- Kit: netclock (offset estimation, outlier rejection and jitter buffering)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "R.0122"
	S.key = "arkher.net.reliablechannel.time_sync"
	S.name = "Reliable Channel Time Sync"
	S.category = "R"
	S.family = "NETWORKING"
	S.area = "Reliable Channel"
	S.aspect = "Time Sync"
	S.kit = "netclock"
	S.version = "1.0.0"
	S.deps = { "arkher.net.reliablechannel.replication" }
	S.tags = { "r", "reliablechannel", "netclock", "net" }
	S.description = "Reliable Channel Time Sync: offset estimation, outlier rejection and jitter buffering for the Reliable Channel subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 280,
		baseWeight = 0.79,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 211,
		detailWeight = 0.59,
		failureTolerance = 4,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.59,
		minThrottle = 0.145,
		regressionSlope = 0.145,
		saturation = 0.74,
		scale = 1.9
	}
	S.features = { "tickDuration", "sample", "recompute", "serverTime", "advance", "push", "pop", "dropStale", "interpolationTime", "setBufferDelay", "adaptBuffer", "stats", "syncFor", "runTicks", "bufferSnapshot", "drain", "clockHealth", "retune", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("netclock", { id = "arkher.net.reliablechannel.time_sync", tickRate = 50, bufferDelay = 0.150, maxSamples = 11 })
		inst.system = S
		inst.ctx = ctx

		function inst.syncFor(samples, latency, offset)
			local n = samples or 6
			local rtt = latency or 0.05
			local skew = offset or 1.0
			for i = 1, n do
				local sent = i * 0.1
				inst.sample(sent, sent + rtt * 0.5 + skew, sent + rtt)
			end
			return inst.offset
		end
		function inst.runTicks(seconds)
			return inst.advance(seconds or 1)
		end
		function inst.bufferSnapshot(count)
			local pushed = 0
			for i = 1, (count or 3) do
				if inst.push({ tick = i }, inst.localTime) then pushed = pushed + 1 end
			end
			return pushed
		end
		function inst.drain(seconds)
			inst.advance(seconds or (inst.bufferDelay + 0.05))
			return #inst.pop()
		end
		function inst.clockHealth()
			return { rtt = inst.rtt, jitter = inst.jitter, offset = inst.offset,
				buffered = #inst.buffer }
		end
		function inst.retune()
			return inst.adaptBuffer()
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
				engine.bus:subscribe("arkher.net.reliablechannel.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local offset = inst.syncFor(6, 0.05, 1.0)
		local ok = math.abs(offset - 1.0) < 0.1
		ok = ok and inst.rtt > 0 and inst.jitter >= 0
		ok = ok and inst.runTicks(1) >= 1
		ok = ok and inst.tickDuration() > 0
		ok = ok and inst.bufferSnapshot(3) == 3
		ok = ok and #inst.pop() == 0
		ok = ok and inst.drain(inst.bufferDelay + 0.05) >= 1
		local h = inst.clockHealth()
		ok = ok and h.rtt > 0
		ok = ok and inst.retune() >= 0.016
		inst.setBufferDelay(0.1)
		return ok and inst.serverTime() > 0 and inst.stats().tick >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
