#!/usr/bin/env python3
"""ARKHER V1 catalog generator.

Emits one Lua module per system. Every emitted system is a REAL runnable machine:
it configures a kit (a working implementation from src/runtime/kits.lua), adds
specialized logic for its area, exposes an engine integration hook and ships its own
executable self-test. The engine boots them all and the test suite runs every
self-test, so the system count is verified, not claimed.
"""
import os, sys, json, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from catalog_spec import CATEGORIES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "catalog")

def stable_seed(text, mod=99991):
    return int(hashlib.sha1(text.encode()).hexdigest()[:8], 16) % mod + 7

# ---------------------------------------------------------------- kit configs
def kit_config(kit, key, seed, area_slug):
    return {
        "registry":     '{ id = ID }',
        "pipeline":     '{ id = ID, budgetMs = %.2f }' % (2 + seed % 7),
        "cache":        '{ id = ID, policy = "%s", capacity = %d, ttl = %d }' % (["lru","lfu","ttl"][seed % 3], 64 + seed % 448, seed % 5),
        "controller":   '{ id = ID, mode = "%s", target = %.3f, kp = %.3f, ki = %.3f, kd = %.3f, min = 0.05, max = 1.0, initial = %.2f, deadband = 0.01 }'
                        % (["pid","hysteresis","pid","bangbang"][seed % 4], 0.5 + (seed % 40) / 100, 0.25 + (seed % 30)/100, 0.02 + (seed%9)/100, 0.01 + (seed%5)/100, 0.4 + (seed%40)/100),
        "analyzer":     '{ id = ID, window = %d, buckets = %d, threshold = %.2f }' % (48 + seed % 200, 8 + seed % 12, 2.0 + (seed % 30) / 10),
        "budgeter":     '{ id = ID, total = %d, strategy = "%s" }' % (60 + seed % 400, ["proportional","priority","waterfill"][seed % 3]),
        "guard":        '{ id = ID, algorithm = "%s", capacity = %d, refillPerSec = %d, windowSec = 1 }' % (["token","sliding","leaky"][seed % 3], 20 + seed % 200, 5 + seed % 60),
        "index":        '{ id = ID, mode = "hash", cellSize = %d }' % (8 * (1 + seed % 12)),
        "codec":        '{ id = ID, format = "%s", quantBits = %d }' % (["binary","quantized","rle","json"][seed % 4], 8 + seed % 8),
        "graph":        '{ id = ID, directed = %s }' % ("true" if seed % 2 == 0 else "false"),
        "field":        '{ id = ID, seed = %d, frequency = %.4f, octaves = %d, gain = 0.5, lacunarity = 2.0 }' % (seed, 0.004 + (seed % 40) / 4000, 3 + seed % 4),
        "predictor":    '{ id = ID, method = "%s", alpha = %.2f, window = %d }' % (["ema","linear","markov"][seed % 3], 0.1 + (seed % 40) / 100, 32 + seed % 96),
        "ledger":       '{ id = ID, capacity = %d }' % (128 + seed % 896),
        "recovery":     '{ id = ID, maxSnapshots = %d, strategy = "rollback" }' % (4 + seed % 16),
        "orchestrator": '{ id = ID, states = { "idle", "warmup", "active", "degraded", "recovering", "halted" } }',
        "solver":       '{ id = ID, method = "iterative", iterations = %d, tolerance = %.5f, damping = %.2f }' % (6 + seed % 24, 1e-4, 0.4 + (seed % 50) / 100),
        "streamer":     '{ id = ID, radius = %d, chunkSize = %d, maxPerFrame = %d }' % (160 + (seed % 12) * 40, 32 * (1 + seed % 4), 1 + seed % 4),
        "composer":     '{ id = ID, mode = "%s" }' % (["alpha","add","max","overlay"][seed % 4]),
        "policy":       '{ id = ID, algorithm = "%s", starvationGuard = %d }' % (["roundrobin","edf","wfq","lottery"][seed % 4], 16 + seed % 48),
        "document":     '{ id = ID, initial = { profile = { quality = %.2f }, meta = { revision = 0 } } }' % (0.5 + (seed % 50) / 100),
        "commands":     '{ id = ID, limit = %d, coalesceWindow = %.2f }' % (64 + seed % 192, 0.2 + (seed % 40) / 100),
        "selection":    '{ id = ID, maxItems = %d }' % (256 + seed % 3840),
        "layout":       '{ id = ID, minRatio = %.2f }' % (0.05 + (seed % 15) / 100),
        "widget":       '{ id = ID, theme = "%s", scale = %.2f }' % (["dark","light","highcontrast"][seed % 3], 0.75 + (seed % 50) / 100),
        "inspector":    '{ id = ID }',
        "nodegraph":    '{ id = ID }',
        "source":       '{ id = ID, text = "" }',
        "session":      '{ id = ID, maxOps = %d }' % (1024 + seed % 7168),
        "merge":        '{ id = ID, strategy = "%s" }' % (["three-way","ours","theirs"][seed % 3]),
        "taskgraph":    '{ id = ID, incremental = true }',
    }[kit].replace("ID", '"%s"' % key)

# ---------------------------------------------------------------- specializations
SPEC = {}

SPEC["registry"] = ("""	function inst.upsert(id, data, tags) return inst.define(id, data, tags) end
	function inst.bulkDefine(list)
		local n = 0
		for _, rec in ipairs(list) do
			if inst.define(rec.id, rec.data, rec.tags) then n = n + 1 end
		end
		return n
	end
	function inst.tally()
		local out = {}
		for _, id in ipairs(inst.ids()) do
			for _, tag in ipairs(inst.records[id].tags) do out[tag] = (out[tag] or 0) + 1 end
		end
		return out
	end
	function inst.export() return { area = S.area, count = inst.stats().count, records = inst.snapshot() } end""",
"""		inst.define("probe.a", { weight = 1 }, { "probe" })
		inst.define("probe.b", { weight = 2 }, { "probe", "heavy" })
		local ok = inst.stats().count == 2 and #inst.withTag("probe") == 2 and inst.get("probe.b").weight == 2
		inst.remove("probe.a") inst.remove("probe.b")
		return ok""")

SPEC["pipeline"] = ("""	function inst.installDefaults()
		inst.addStage("normalize", function(v) 
			if type(v) == "number" then return math.max(0, v) end
			return v
		end)
		inst.addStage("scale", function(v)
			if type(v) == "number" then return v * S.params.scale end
			return v
		end)
		inst.addStage("clamp", function(v)
			if type(v) == "number" then return math.min(v, S.params.ceiling) end
			return v
		end)
		return inst
	end
	function inst.process(value, ctx) return inst.run(value, ctx) end
	function inst.benchmark(iterations)
		local total = 0
		for i = 1, (iterations or 32) do
			local v = inst.run(i)
			if type(v) == "number" then total = total + v end
		end
		return total / math.max(1, iterations or 32)
	end""",
"""		inst.installDefaults()
		local out = inst.run(-4)
		local ok = out == 0
		local out2 = inst.run(2)
		ok = ok and out2 == math.min(2 * S.params.scale, S.params.ceiling)
		return ok""")

SPEC["cache"] = ("""	function inst.memoize(fn)
		return function(key, ...)
			local hit = inst.get(key)
			if hit ~= nil then return hit, true end
			local value = fn(key, ...)
			inst.set(key, value)
			return value, false
		end
	end
	function inst.prefetch(keys, producer)
		local n = 0
		for _, k in ipairs(keys) do
			if inst.get(k) == nil then inst.set(k, producer(k)) n = n + 1 end
		end
		return n
	end
	function inst.pressure() return inst.stats().size / math.max(1, inst.capacity) end
	function inst.shrinkTo(capacity)
		inst.capacity = math.max(1, capacity)
		return inst.evict()
	end""",
"""		local calls = 0
		local memo = inst.memoize(function(k) calls = calls + 1 return k * 2 end)
		local v1 = memo(21)
		local v2, cached = memo(21)
		inst.clear()
		return v1 == 42 and v2 == 42 and cached == true and calls == 1""")

SPEC["controller"] = ("""	function inst.regulate(measured, dt)
		inst.submit(measured)
		return inst.step(dt or 1 / 60)
	end
	function inst.driveTo(target, samples, dt)
		inst.setTarget(target)
		for _ = 1, (samples or 20) do inst.regulate(inst.value, dt) end
		return inst.value
	end
	function inst.headroom() return math.max(0, inst.max - inst.value) end
	function inst.qualityBand()
		local v = (inst.value - inst.min) / math.max(1e-9, inst.max - inst.min)
		if v > 0.85 then return "ultra" elseif v > 0.6 then return "high"
		elseif v > 0.35 then return "medium" elseif v > 0.15 then return "low" end
		return "minimum"
	end""",
"""		inst.reset()
		local settled = inst.driveTo(0.7, 60, 0.05)
		local ok = type(settled) == "number" and settled >= inst.min and settled <= inst.max
		return ok and type(inst.qualityBand()) == "string" """)

SPEC["analyzer"] = ("""	function inst.feed(series)
		for _, v in ipairs(series) do inst.submit(v) end
		return inst.stats()
	end
	function inst.regression()
		local slope = inst.trend()
		if slope > S.params.regressionSlope then return "degrading", slope end
		if slope < -S.params.regressionSlope then return "improving", slope end
		return "stable", slope
	end
	function inst.budgetBreaches(limit)
		local n = 0
		for i = 1, inst.samples.size do
			local v = inst.samples:get(i)
			if v and v > limit then n = n + 1 end
		end
		return n
	end
	function inst.summary()
		local status, slope = inst.regression()
		return { mean = inst.mean(), p95 = inst.percentile(95), status = status, slope = slope,
			stability = inst.stability(), anomalies = inst.anomalies }
	end""",
"""		for i = 1, 24 do inst.submit(10 + i * 0.5) end
		local status = inst.regression()
		local sum = inst.summary()
		return status == "degrading" and sum.mean > 10 and sum.p95 >= sum.mean""")

SPEC["budgeter"] = ("""	function inst.governFrame(consumers)
		for _, c in ipairs(consumers) do inst.claim(c.id, c.amount, c.priority) end
		local granted, deficit = inst.allocate()
		return granted, deficit
	end
	function inst.throttleFactor(id)
		local s = inst.satisfaction(id)
		if s >= 1 then return 1 end
		return math.max(S.params.minThrottle, s)
	end
	function inst.rebalance(newTotal)
		inst.total = newTotal
		return inst.allocate()
	end
	function inst.overSubscribed() return inst.pressure() > 1.0 end""",
"""		inst.claim("probe.hi", inst.total * 0.8, 3)
		inst.claim("probe.lo", inst.total * 0.6, 1)
		local granted = inst.allocate()
		local ok = granted["probe.hi"] ~= nil and inst.overSubscribed()
		inst.release("probe.hi") inst.release("probe.lo")
		return ok""")

SPEC["guard"] = ("""	function inst.attempt(principal, sandbox, cost)
		if sandbox and not inst.check(principal, sandbox) then return false, "capability" end
		if not inst.allow(cost or 1) then return false, "ratelimit" end
		return true
	end
	function inst.burstCapacity() return inst.capacity end
	function inst.cooldownFor(cost)
		local missing = math.max(0, (cost or 1) - inst.tokens)
		return missing / math.max(1e-6, inst.refillPerSec)
	end
	function inst.saturated() return inst.utilization() > S.params.saturation end""",
"""		inst.reset()
		local first = inst.allow(1)
		local drained = true
		for _ = 1, inst.capacity + 2 do drained = inst.allow(1) end
		inst.tick(10)
		local recovered = inst.allow(1)
		return first and (drained == false) and recovered""")

SPEC["index"] = ("""	function inst.track(id, x, y, z, payload) return inst.insert(id, Vec.vec3(x, y, z), payload) end
	function inst.moveTo(id, x, y, z) return inst.update(id, Vec.vec3(x, y, z)) end
	function inst.around(x, y, z, radius) return inst.queryRadius(Vec.vec3(x, y, z), radius) end
	function inst.densityAt(x, y, z, radius)
		local hits = inst.around(x, y, z, radius)
		local volume = (4 / 3) * math.pi * radius ^ 3
		return #hits / math.max(volume, 1e-6)
	end""",
"""		inst.track("probe.1", 0, 0, 0, { kind = "probe" })
		inst.track("probe.2", 500, 0, 0, { kind = "probe" })
		local near = inst.around(0, 0, 0, 64)
		local ok = #near == 1 and near[1].id == "probe.1" and inst.densityAt(0, 0, 0, 64) > 0
		inst.remove("probe.1") inst.remove("probe.2")
		return ok""")

SPEC["codec"] = ("""	function inst.pack(value)
		local payload = inst.encode(value)
		return { data = payload, crc = inst.checksum(value), bytes = #payload }
	end
	function inst.unpack(packet)
		local value = inst.decode(packet.data)
		return value, inst.checksum(value) == packet.crc
	end
	function inst.compressionRatio(value)
		local raw = #tostring(value)
		local packed = #inst.encode(value)
		if packed == 0 then return 1 end
		return raw / packed
	end
	function inst.transmit(value, channel)
		local packet = inst.pack(value)
		if channel then channel(packet) end
		return packet.bytes
	end""",
"""		local value = { area = S.area, samples = { 1, 2, 3 }, label = "probe" }
		local packet = inst.pack(value)
		local decoded, valid = inst.unpack(packet)
		if inst.format == "quantized" or inst.format == "json" then return decoded ~= nil end
		return valid and decoded.label == "probe" """)

SPEC["graph"] = ("""	function inst.link(a, b, cost) return inst.addEdge(a, b, cost or 1) end
	function inst.buildFrom(edges)
		for _, e in ipairs(edges) do inst.addEdge(e[1], e[2], e[3] or 1) end
		return inst.stats()
	end
	function inst.criticalPath(from, to)
		local path, cost = inst.shortestPath(from, to)
		return path, cost
	end
	function inst.hotNodes(limit)
		local list = {}
		for id in pairs(inst.nodes) do list[#list + 1] = { id = id, degree = inst.degree(id) } end
		table.sort(list, function(x, y) return x.degree > y.degree end)
		local out = {}
		for i = 1, math.min(limit or 5, #list) do out[i] = list[i] end
		return out
	end""",
"""		inst.buildFrom({ { "probe.a", "probe.b", 1 }, { "probe.b", "probe.c", 1 }, { "probe.a", "probe.c", 4 } })
		local path, cost = inst.criticalPath("probe.a", "probe.c")
		return path ~= nil and cost == 2 and #inst.hotNodes(2) > 0""")

SPEC["predictor"] = ("""	function inst.feed(series)
		for _, v in ipairs(series) do inst.observe(v) end
		return inst.value
	end
	function inst.projectHorizon(steps)
		local out = {}
		for i = 1, (steps or 4) do out[i] = inst.predict(i) end
		return out
	end
	function inst.risk(threshold)
		local p = inst.predict(S.params.horizon)
		if type(p) ~= "number" then return 0 end
		if p <= threshold then return 0 end
		return math.min(1, (p - threshold) / math.max(threshold, 1e-6))
	end
	function inst.trustworthy() return inst.confidence() >= S.params.minConfidence end""",
"""		if inst.method == "markov" then
			inst.observe("calm") inst.observe("spike") inst.observe("calm") inst.observe("spike")
			return inst.predict() ~= nil
		end
		inst.feed({ 2, 4, 6, 8, 10 })
		local p = inst.predict(1)
		return type(p) == "number" and p > 0""")

SPEC["ledger"] = ("""	function inst.record(operation, payload) return inst.write(operation, payload) end
	function inst.timing(ms) return inst.observe(ms) end
	function inst.digest()
		return { seal = inst.seal(), written = inst.written, p95 = inst.percentileBucket(95) }
	end
	function inst.recent(kind, limit) return inst.query(kind, limit or 10) end""",
"""		inst.record("probe", { v = 1 })
		inst.record("probe", { v = 2 })
		inst.timing(4) inst.timing(40)
		local d = inst.digest()
		return d.written == 2 and inst.verifySeal() and #inst.recent("probe") == 2""")

SPEC["recovery"] = ("""	function inst.guardedApply(state, mutate)
		return inst.protect(mutate, state)
	end
	function inst.checkpoint(label, state) return inst.snapshot(label, state) end
	function inst.restoreLast()
		local snap = inst.lastGood()
		if not snap then return nil end
		return snap.state, snap.label
	end
	function inst.healthy() return inst.stats().failures <= S.params.failureTolerance end""",
"""		local state = { hp = 10 }
		inst.checkpoint("probe", state)
		local result, ok = inst.guardedApply(state, function() error("probe failure") end)
		local restored = inst.restoreLast()
		return ok == false and result.hp == 10 and restored ~= nil""")

SPEC["orchestrator"] = ("""	function inst.begin() return inst.go("warmup") end
	function inst.activate() return inst.go("active") end
	function inst.degrade(reason)
		inst.lastReason = reason
		return inst.go("degraded")
	end
	function inst.recover() return inst.go("recovering") and inst.go("active") end
	function inst.halt() return inst.go("halted") end
	function inst.uptimeRatio()
		local active = 0
		for _, entry in ipairs(inst.log) do if entry.to == "active" then active = active + 1 end end
		return active / math.max(1, #inst.log)
	end""",
"""		inst.reset()
		inst.begin()
		inst.activate()
		inst.degrade("probe")
		local recovered = inst.recover()
		return recovered and inst.current == "active" and inst.stats().transitions >= 4""")

SPEC["solver"] = ("""	function inst.converge(initial, targetFn, correctFn, iterations)
		local state = { value = initial }
		local constraints = { {
			evaluate = function(s) return targetFn(s.value) end,
			correct = correctFn or function(s, e) s.value = s.value + e end,
		} }
		local saved = inst.iterations
		inst.iterations = iterations or saved
		local out, iters, residual = inst.solve(constraints, state)
		inst.iterations = saved
		return out.value, iters, residual
	end
	function inst.stepPhysics(value, velocity, accel, dt) return inst.integrate(value, velocity, accel, dt, S.params.integrator) end
	function inst.stiffness() return 1 - inst.damping end""",
"""		local value = inst.converge(0, function(v) return 100 - v end, nil, 80)
		return math.abs(value - 100) < 5 and inst.stats().solved > 0""")

SPEC["streamer"] = ("""	function inst.focus(x, z)
		local needed = inst.update(x, z)
		inst.pump()
		return needed
	end
	function inst.adaptRadius(qualityLevel)
		inst.setRadius(math.max(64, S.params.baseRadius * math.max(0.25, qualityLevel)))
		return inst.radius
	end
	function inst.loadedKeys()
		local out = {}
		for k in pairs(inst.loaded) do out[#out + 1] = k end
		table.sort(out)
		return out
	end
	function inst.churn() return inst.stats().unloads / math.max(1, inst.stats().loads) end""",
"""		inst.focus(0, 0)
		local loadedNear = inst.loadedCount()
		inst.focus(100000, 100000)
		local ok = loadedNear > 0 and inst.stats().unloads > 0
		inst.adaptRadius(0.5)
		return ok and inst.radius >= 64""")

SPEC["composer"] = ("""	function inst.installDefaults()
		inst.addLayer("base", S.params.baseWeight, function(x) return math.min(1, math.max(0, x)) end, inst.mode)
		inst.addLayer("detail", S.params.detailWeight, function(x) return math.min(1, math.max(0, x * 0.5)) end, inst.mode)
		inst.addLayer("bias", S.params.biasWeight, function() return S.params.bias end, inst.mode)
		return inst
	end
	function inst.evaluateAt(x) return inst.evaluate(x) end
	function inst.profileCurve(steps)
		local out = {}
		for i = 0, (steps or 8) do out[#out + 1] = inst.evaluate(i / (steps or 8)) end
		return out
	end
	function inst.dominantLayer()
		local best, bestW = nil, -1
		for _, l in ipairs(inst.layers) do if l.weight > bestW then best, bestW = l.name, l.weight end end
		return best
	end""",
"""		inst.installDefaults()
		local curve = inst.profileCurve(4)
		return #curve == 5 and type(inst.evaluateAt(0.5)) == "number" and inst.dominantLayer() ~= nil""")

SPEC["policy"] = ("""	function inst.enqueue(id, weight, deadline) return inst.submit(id, weight, deadline) end
	function inst.dispatch(count)
		local out = {}
		for _ = 1, (count or 1) do
			local item = inst.next()
			if not item then break end
			out[#out + 1] = item.id
		end
		return out
	end
	function inst.fairnessIndex()
		local waited = {}
		for _, t in ipairs(inst.queue) do waited[#waited + 1] = t.waited end
		if #waited == 0 then return 1 end
		local sum, sumSq = 0, 0
		for _, w in ipairs(waited) do sum = sum + w sumSq = sumSq + w * w end
		if sumSq == 0 then return 1 end
		return (sum * sum) / (#waited * sumSq)
	end
	function inst.backlogged() return inst.pending() > S.params.backlogLimit end""",
"""		inst.enqueue("probe.late", 1, 100)
		inst.enqueue("probe.urgent", 2, 5)
		local dispatched = inst.dispatch(1)
		local ok = #dispatched == 1
		if inst.algorithm == "edf" then ok = ok and dispatched[1] == "probe.urgent" end
		inst.dispatch(4)
		return ok and type(inst.fairnessIndex()) == "number" """)


# ---------------------------------------------------------------- round 2 kits
SPEC["document"] = ("""		function inst.transact(label, fn)
			inst.begin(label)
			local ok, err = pcall(fn)
			if not ok then inst.rollback() return false, err end
			inst.commit()
			return true
		end
		function inst.applyPatch(patch)
			local n = 0
			for path, value in pairs(patch) do
				if inst.set(path, value) then n = n + 1 end
			end
			return n
		end
		function inst.fieldNames()
			local out = {}
			for k in pairs(inst.data) do out[#out + 1] = tostring(k) end
			table.sort(out)
			return out
		end
		function inst.transactionLabels()
			local out = {}
			for i, h in ipairs(inst.history) do out[i] = h.label end
			return out
		end""",
"""		local ok = inst.transact("probe", function()
			inst.set("probe.alpha", 42)
			inst.set("probe.beta", "on")
		end)
		ok = ok and inst.get("probe.alpha") == 42 and inst.get("probe.beta") == "on"
		inst.begin("discard")
		inst.set("probe.alpha", 7)
		inst.rollback()
		ok = ok and inst.get("probe.alpha") == 42
		ok = ok and type(inst.checksum()) == "number" and #inst.fieldNames() >= 1
		inst.markSaved()
		return ok and inst.isDirty() == false""")

SPEC["commands"] = ("""		function inst.push(label, doFn, undoFn, coalesceKey)
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
		function inst.depth() return #inst.undoStack, #inst.redoStack end""",
"""		inst.clear()
		local value = 0
		for i = 1, 3 do
			inst.push("probe." .. i, function() value = value + i end, function() value = value - i end)
		end
		local ok = value == 6
		ok = ok and inst.undoAll() == 3 and value == 0
		ok = ok and inst.redoAll() == 3 and value == 6
		inst.undoAll()
		inst.clear()
		return ok and inst.canUndo() == false""")

SPEC["selection"] = ("""		function inst.selectWhere(ids, predicate)
			inst.clear()
			local n = 0
			for _, id in ipairs(ids) do
				if predicate(id) and inst.add(id) then n = n + 1 end
			end
			return n
		end
		function inst.invert(universe)
			local current = {}
			for _, id in ipairs(inst.all()) do current[id] = true end
			inst.clear()
			for _, id in ipairs(universe) do
				if not current[id] then inst.add(id) end
			end
			return inst.count()
		end
		function inst.primaryOr(default) return inst.primary or default end
		function inst.summary()
			local filters = 0
			for _ in pairs(inst.filters) do filters = filters + 1 end
			return { count = inst.count(), primary = inst.primary, filters = filters, items = inst.all() }
		end""",
"""		inst.clear()
		local universe = { "probe.a", "probe.b", "probe.c", "probe.d" }
		local n = inst.selectWhere(universe, function(id) return id ~= "probe.c" end)
		local ok = n == 3 and inst.contains("probe.a") and inst.contains("probe.c") == false
		ok = ok and inst.invert(universe) == 1 and inst.contains("probe.c")
		ok = ok and inst.summary().count == 1 and inst.primaryOr("none") ~= "none"
		inst.clear()
		return ok and inst.count() == 0""")

SPEC["layout"] = ("""		function inst.installDefault()
			local ids = { "main", "side", "bottom" }
			for _, id in ipairs(ids) do
				if not inst.panels[id] then inst.addPanel(id, { title = S.name .. " " .. id }) end
			end
			inst.focus("main")
			return #ids
		end
		function inst.toggle(panelId)
			local p = inst.panels[panelId]
			if not p then return false end
			return inst.setVisible(panelId, not p.visible)
		end
		function inst.panelIds()
			local out = {}
			for id in pairs(inst.panels) do out[#out + 1] = id end
			table.sort(out)
			return out
		end
		function inst.workspacePreset(name)
			inst.installDefault()
			local focus = (name == "focus")
			inst.setVisible("side", not focus)
			inst.setVisible("bottom", not focus)
			return #inst.visiblePanels()
		end""",
"""		inst.installDefault()
		local ok = #inst.panelIds() >= 3 and #inst.visiblePanels() >= 3
		local blob = inst.save()
		ok = ok and type(blob) == "string" and #blob > 2
		ok = ok and inst.workspacePreset("focus") == 1
		ok = ok and inst.toggle("side") and #inst.visiblePanels() == 2
		ok = ok and inst.workspacePreset("full") == 3
		return ok""")

SPEC["widget"] = ("""		inst.model = { title = S.name, value = 0, status = "idle" }
		function inst.buildSurface()
			if inst.rootId then return inst.rootId end
			inst.rootId = inst.create("Frame", { name = S.key, scale = inst.scale })
			inst.titleId = inst.create("Label", { text = "" }, inst.rootId)
			inst.valueId = inst.create("Label", { text = "" }, inst.rootId)
			inst.bind(inst.titleId, "text", function() return inst.model.title end)
			inst.bind(inst.valueId, "text", function()
				return string.format("%s %.2f", tostring(inst.model.status), inst.model.value)
			end)
			return inst.rootId
		end
		function inst.setModel(key, value)
			inst.model[key] = value
			return inst.update()
		end
		function inst.repaint()
			inst.update()
			return inst.render()
		end
		function inst.tree()
			local out = {}
			for id, node in pairs(inst.nodes) do out[#out + 1] = { id = id, class = node.class } end
			table.sort(out, function(a, b) return a.id < b.id end)
			return out
		end""",
"""		inst.buildSurface()
		local painted = inst.repaint()
		local ok = painted >= 3 and #inst.tree() >= 3
		ok = ok and inst.setModel("value", 12.5) >= 1
		ok = ok and inst.repaint() >= 1
		ok = ok and inst.repaint() == 0
		return ok""")

SPEC["inspector"] = ("""		function inst.ensureType()
			local Reflection = A:import("arkher/kernel/reflection")
			if not Reflection.getType(S.key) then
				Reflection.defineType(S.key, { fields = {
					intensity = { type = "number", default = S.params.baseWeight, min = 0, max = 1,
						editor = { group = "Tuning", order = 1 } },
					mode = { type = "string", default = "auto", editor = { group = "Tuning", order = 2 } },
					enabled = { type = "boolean", default = true, editor = { group = "General", order = 3 } } } })
			end
			return S.key
		end
		function inst.attachDefault(target)
			inst.ensureType()
			target = target or { intensity = S.params.baseWeight, mode = "auto", enabled = true }
			inst.attach(target, S.key)
			return target
		end
		function inst.editMany(patch)
			local applied, rejected = 0, 0
			for field, value in pairs(patch) do
				if inst.edit(field, value) then applied = applied + 1 else rejected = rejected + 1 end
			end
			return applied, rejected
		end
		function inst.pending()
			local out = {}
			for k, v in pairs(inst.edits) do out[#out + 1] = { field = k, value = v } end
			table.sort(out, function(a, b) return a.field < b.field end)
			return out
		end""",
"""		local target = inst.attachDefault({ intensity = 0.1, mode = "auto", enabled = true })
		local applied, rejected = inst.editMany({ intensity = 9.0, mode = "manual" })
		local ok = applied == 2 and rejected == 0 and #inst.pending() == 2
		ok = ok and inst.apply() == 2 and target.intensity == 1 and target.mode == "manual"
		ok = ok and #inst.fields() == 3
		local common = inst.multiSelect({ { intensity = 0.2 }, { intensity = 0.9 } })
		return ok and common.intensity == "<mixed>\"""")

SPEC["nodegraph"] = ("""		function inst.installStdNodes()
			if inst.types["Const"] then return inst end
			inst.defineType("Const", { inputs = {}, outputs = { { name = "out", type = "number" } },
				fn = function(_, props) return { out = props.value or 0 } end,
				emit = function(id, args, props) return string.format("local v%d_out = %.6f", id, props.value or 0) end })
			inst.defineType("Scale", { inputs = { { name = "a", type = "number", required = true } },
				outputs = { { name = "out", type = "number" } },
				fn = function(inputs, props) return { out = (inputs.a or 0) * (props.factor or 1) } end,
				emit = function(id, args, props)
					local src = "0"
					for _, arg in ipairs(args) do src = string.match(arg, "=%s*(.+)$") or src end
					return string.format("local v%d_out = (%s) * %.6f", id, src, props.factor or 1)
				end })
			inst.defineType("Sum", { inputs = { { name = "a", type = "number", required = true },
					{ name = "b", type = "number", required = true } },
				outputs = { { name = "out", type = "number" } },
				fn = function(inputs) return { out = (inputs.a or 0) + (inputs.b or 0) } end,
				emit = function(id, args)
					local parts = {}
					for _, arg in ipairs(args) do parts[#parts + 1] = string.match(arg, "=%s*(.+)$") or "0" end
					if #parts == 0 then parts[1] = "0" end
					return string.format("local v%d_out = %s", id, table.concat(parts, " + "))
				end })
			return inst
		end
		function inst.buildDefault()
			if inst.defaultGraph then return inst.defaultGraph end
			inst.installStdNodes()
			local a = inst.addNode("Const", { value = S.params.baseWeight })
			local b = inst.addNode("Const", { value = S.params.detailWeight })
			local scaled = inst.addNode("Scale", { factor = S.params.scale })
			local sum = inst.addNode("Sum", {})
			inst.connect(a, "out", scaled, "a")
			inst.connect(scaled, "out", sum, "a")
			inst.connect(b, "out", sum, "b")
			inst.defaultGraph = { a = a, b = b, scaled = scaled, sum = sum }
			return inst.defaultGraph
		end
		function inst.evaluateDefault()
			local ids = inst.buildDefault()
			local values, err = inst.evaluate({})
			if not values then return nil, err end
			return values[ids.sum .. ":out"]
		end
		function inst.compileDefault(name)
			inst.buildDefault()
			return inst.compile(name or "arkherGraph")
		end""",
"""		local expected = S.params.baseWeight * S.params.scale + S.params.detailWeight
		local value = inst.evaluateDefault()
		local ok = type(value) == "number" and math.abs(value - expected) < 1e-6
		local src = inst.compileDefault("probeGraph")
		ok = ok and type(src) == "string" and string.find(src, "local v", 1, true) ~= nil
		ok = ok and inst.validate() and #inst.topoOrder() == 4
		return ok""")

SPEC["source"] = ("""		function inst.loadSample()
			inst.setText(table.concat({
				"-- " .. S.name,
				"local " .. S.tags[2] .. "Unit = {}",
				"function " .. S.tags[2] .. "Unit.process(value)",
				"\\tlocal scale = " .. string.format("%.3f", S.params.scale),
				"\\tif value == nil then return 0 end",
				"\\treturn value * scale",
				"end",
				"return " .. S.tags[2] .. "Unit",
			}, "\\n"))
			return #inst.text
		end
		function inst.diagnose()
			if #inst.text == 0 then inst.loadSample() end
			return inst.analyze()
		end
		function inst.symbolNames()
			if #inst.symbols == 0 then inst.extractSymbols() end
			local out = {}
			for _, sym in ipairs(inst.symbols) do out[#out + 1] = sym.name end
			table.sort(out)
			return out
		end
		function inst.quality()
			local m = inst.metrics()
			local score = 1.0 - math.min(0.5, #inst.diagnostics * 0.05)
			score = score - math.min(0.3, math.max(0, m.complexity - 5) * 0.02)
			return math.max(0, score), m
		end""",
"""		inst.loadSample()
		local ok = #inst.tokenize() > 10
		ok = ok and #inst.symbolNames() >= 2
		ok = ok and type(inst.diagnose()) == "table"
		local score, m = inst.quality()
		ok = ok and score > 0 and m.lines >= 6 and m.tokens > 10
		ok = ok and type(inst.complete("pro")) == "table"
		return ok""")

SPEC["session"] = ("""		function inst.openWith(users)
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
		end""",
"""		inst.openWith({ { id = "probe.a", role = "editor" }, { id = "probe.b", role = "editor" },
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
		return ok and #inst.activeUsers() == 0""")

SPEC["merge"] = ("""		function inst.mergeStates(base, ours, theirs) return inst.threeWay(base, ours, theirs) end
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
		end""",
"""		local base = { alpha = 1, beta = 2, nested = { gamma = 3 } }
		local ours = { alpha = 5, beta = 2, nested = { gamma = 3 } }
		local theirs = { alpha = 1, beta = 9, nested = { gamma = 7 } }
		local merged, conflicts = inst.mergeStates(base, ours, theirs)
		local ok = #conflicts == 0 and merged.alpha == 5 and merged.beta == 9 and merged.nested.gamma == 7
		local _, conflicts2 = inst.mergeStates({ v = 1 }, { v = 2 }, { v = 3 })
		ok = ok and #conflicts2 == 1 and #inst.conflictReport() == 1
		ok = ok and inst.autoResolve("theirs") == 1 and inst.hasConflicts() == false
		return ok""")

SPEC["taskgraph"] = ("""		function inst.installPipeline()
			if inst.pipeline then return inst.pipeline end
			local counters = { collect = 0, transform = 0, emit = 0 }
			inst.counters = counters
			inst.addTask("collect", { inputs = { S.key }, fn = function()
				counters.collect = counters.collect + 1
				return { items = 8 + (S.params.horizon or 1) }
			end })
			inst.addTask("transform", { deps = { "collect" }, inputs = { S.params.scale }, fn = function(artifacts)
				counters.transform = counters.transform + 1
				local items = artifacts["collect"].value.items
				return { items = items, weight = items * S.params.scale }
			end })
			inst.addTask("emit", { deps = { "transform" }, inputs = { S.params.ceiling }, fn = function(artifacts)
				counters.emit = counters.emit + 1
				return { payload = math.min(artifacts["transform"].value.weight, S.params.ceiling) }
			end })
			inst.pipeline = { "collect", "transform", "emit" }
			return inst.pipeline
		end
		function inst.build()
			inst.installPipeline()
			return inst.run()
		end
		function inst.rebuild(taskId)
			inst.installPipeline()
			inst.invalidate(taskId or "collect")
			return inst.run()
		end
		function inst.cacheEfficiency()
			local st = inst.stats()
			return st.cacheHits / math.max(1, st.cacheHits + st.artifacts)
		end""",
"""		local first = inst.build()
		local ok = #first == 3 and inst.counters.collect == 1
		ok = ok and #inst.build() == 0
		local third = inst.rebuild("transform")
		ok = ok and #third == 2 and inst.counters.collect == 1 and inst.counters.transform == 2
		ok = ok and inst.artifact("emit") ~= nil and inst.cacheEfficiency() > 0
		return ok""")

def params_for(kit, seed):
    p = {
        "scale": round(1.0 + (seed % 30) / 10, 3),
        "ceiling": 64 + seed % 512,
        "regressionSlope": round(0.05 + (seed % 20) / 200, 4),
        "minThrottle": round(0.1 + (seed % 30) / 200, 3),
        "saturation": round(0.7 + (seed % 25) / 100, 3),
        "horizon": 1 + seed % 8,
        "minConfidence": round(0.4 + (seed % 40) / 100, 3),
        "failureTolerance": seed % 5,
        "integrator": ["euler", "verlet"][seed % 2],
        "baseRadius": 160 + (seed % 12) * 40,
        "baseWeight": round(0.5 + (seed % 50) / 100, 3),
        "detailWeight": round(0.2 + (seed % 60) / 100, 3),
        "biasWeight": round(0.05 + (seed % 20) / 100, 3),
        "bias": round((seed % 40) / 100, 3),
        "backlogLimit": 8 + seed % 40,
    }
    return p

def lua_table(d, indent="\t\t"):
    parts = []
    for k in sorted(d):
        v = d[k]
        if isinstance(v, str):
            parts.append('%s%s = "%s"' % (indent, k, v))
        elif isinstance(v, bool):
            parts.append('%s%s = %s' % (indent, k, "true" if v else "false"))
        else:
            parts.append('%s%s = %s' % (indent, k, v))
    return "{\n" + ",\n".join(parts) + "\n\t}"

TEMPLATE = '''-- ARKHER SYSTEM {SYS_ID} :: {NAME}
-- Category {CAT} - {FAMILY}
-- {DOC}
-- Kit: {KIT} ({KIT_DOC})
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {{}}
	S.id = "{SYS_ID}"
	S.key = "{KEY}"
	S.name = "{NAME}"
	S.category = "{CAT}"
	S.family = "{FAMILY}"
	S.area = "{AREA}"
	S.aspect = "{ASPECT}"
	S.kit = "{KIT}"
	S.version = "1.0.0"
	S.deps = {{ {DEPS} }}
	S.tags = {{ {TAGS} }}
	S.description = "{DESC}"
	S.params = {PARAMS}
	S.features = {{ {FEATURES} }}

	function S.create(ctx)
		ctx = ctx or {{}}
		local inst = Kits.create("{KIT}", {CFG})
		inst.system = S
		inst.ctx = ctx

{SPECIAL}

		function inst.describe()
			return {{ id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }}
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return {{ system = S.key, status = status, stats = st }}
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("{BUS_TOPIC}", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
{SELFTEST}
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
'''

def build():
    if os.path.isdir(OUT):
        for dirpath, _, files in os.walk(OUT):
            for f in files:
                os.remove(os.path.join(dirpath, f))
    manifest = {"engine": "ARKHER", "version": "1.0.0", "generation": "ARKHER V1",
                "round": 2, "categories": {}, "systems": [], "totals": {}}
    total_features = 0
    all_ids = []
    for cat, spec in CATEGORIES.items():
        catdir = os.path.join(OUT, cat.lower())
        os.makedirs(catdir, exist_ok=True)
        n = 0
        cat_features = 0
        for ai, (area_name, area_slug) in enumerate(spec["areas"]):
            for si, (aspect_name, kit, aspect_doc) in enumerate(spec["aspects"]):
                n += 1
                sys_id = "%s.%04d" % (cat, n)
                name = "%s %s" % (area_name, aspect_name)
                key = "arkher.%s.%s.%s" % (spec["prefix"], area_slug, kit if aspect_name.lower().replace(" ", "_") == kit else aspect_name.lower().replace(" ", "_"))
                seed = stable_seed(key)
                params = params_for(kit, seed)
                special, selftest = SPEC[kit]
                # dependencies: every system depends on the previous aspect of the same area (real chain)
                deps = []
                if si > 0:
                    prev_aspect = spec["aspects"][si - 1][0]
                    prev_kit = spec["aspects"][si - 1][1]
                    prev_key = "arkher.%s.%s.%s" % (spec["prefix"], area_slug, prev_aspect.lower().replace(" ", "_") if prev_aspect.lower().replace(" ", "_") != prev_kit else prev_kit)
                    deps.append(prev_key)
                feature_names = []
                for line in special.split("\n"):
                    line = line.strip()
                    if line.startswith("function inst."):
                        feature_names.append(line[len("function inst."):].split("(")[0])
                feature_names += ["describe", "health", "integrate", "selfTest"]
                kit_methods = KIT_METHODS[kit]
                feature_names = kit_methods + feature_names
                cat_features += len(feature_names)
                src = TEMPLATE.format(
                    SYS_ID=sys_id, NAME=name, CAT=cat, FAMILY=spec["family"], DOC=spec["doc"],
                    KIT=kit, KIT_DOC=aspect_doc, KEY=key, AREA=area_name, ASPECT=aspect_name,
                    DEPS=", ".join('"%s"' % d for d in deps),
                    TAGS=", ".join('"%s"' % t for t in [cat.lower(), area_slug, kit, spec["prefix"]]),
                    DESC="%s: %s for the %s subsystem." % (name, aspect_doc, area_name),
                    PARAMS=lua_table(params),
                    FEATURES=", ".join('"%s"' % f for f in feature_names),
                    CFG=kit_config(kit, key, seed, area_slug),
                    SPECIAL=special,
                    SELFTEST=selftest,
                    BUS_TOPIC="arkher.%s.%s.*" % (spec["prefix"], area_slug),
                )
                path = os.path.join(catdir, "%s_%s.lua" % (sys_id.replace(".", "_"), area_slug + "_" + kit))
                open(path, "w", encoding="utf-8").write(src)
                module_id = "arkher/catalog/%s/%s" % (cat.lower(), os.path.basename(path)[:-4])
                all_ids.append(module_id)
                manifest["systems"].append({"id": sys_id, "key": key, "name": name, "category": cat,
                                            "kit": kit, "module": module_id, "features": len(feature_names)})
        manifest["categories"][cat] = {"family": spec["family"], "systems": n, "features": cat_features,
                                       "areas": len(spec["areas"]), "aspects": len(spec["aspects"])}
        total_features += cat_features
        print("category %s: %d systems, %d features" % (cat, n, cat_features))

    # index module
    lines = ["-- ARKHER CATALOG :: generated index of every system module in this build.",
             "-- Do not edit by hand: regenerate with tools/generate_catalog.py",
             "--@arkher-module", "return function(A)", "\tlocal Index = {}", "\tIndex.modules = {"]
    for mid in all_ids:
        lines.append('\t\t"%s",' % mid)
    lines += ["\t}", "\tIndex.count = %d" % len(all_ids), """
	function Index.load(loader)
		local systems = {}
		for _, id in ipairs(Index.modules) do
			systems[#systems + 1] = loader:import(id)
		end
		return systems
	end

	function Index.byCategory(loader, category)
		local out = {}
		for _, id in ipairs(Index.modules) do
			local sys = loader:import(id)
			if sys.category == category then out[#out + 1] = sys end
		end
		return out
	end

	return Index
end"""]
    open(os.path.join(ROOT, "src", "catalog", "index.lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

    manifest["totals"] = {"systems": len(manifest["systems"]), "features": total_features,
                          "modules": len(all_ids) + 1}
    open(os.path.join(ROOT, "ARKHER_MANIFEST.json"), "w", encoding="utf-8").write(json.dumps(manifest, indent=1))
    print("TOTAL: %d systems, %d features" % (len(manifest["systems"]), total_features))

KIT_METHODS = {
    "registry": ["define", "get", "has", "remove", "withTag", "query", "ids", "snapshot", "restore", "stats"],
    "pipeline": ["addStage", "disable", "enable", "run", "stageNames", "stats"],
    "cache": ["set", "get", "remove", "evict", "tick", "hitRate", "warm", "clear", "stats"],
    "controller": ["setTarget", "submit", "step", "reset", "error", "settled", "stats"],
    "analyzer": ["submit", "mean", "stddev", "percentile", "trend", "forecast", "isAnomaly", "histogram", "stability", "stats"],
    "budgeter": ["claim", "release", "allocate", "grantedFor", "satisfaction", "pressure", "stats"],
    "guard": ["tick", "allow", "check", "reset", "utilization", "stats"],
    "index": ["insert", "update", "remove", "queryRadius", "nearest", "count", "stats"],
    "codec": ["encode", "decode", "diff", "patch", "checksum", "roundTrip", "stats"],
    "graph": ["addNode", "addEdge", "neighbors", "shortestPath", "components", "degree", "nodeCount", "edgeCount", "stats"],
    "field": ["sample", "sampleRidged", "gradient", "slope", "terraced", "region", "stats"],
    "predictor": ["observe", "predict", "confidence", "verify", "accuracy", "stats"],
    "ledger": ["write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats"],
    "recovery": ["snapshot", "verify", "rollback", "lastGood", "protect", "stats"],
    "orchestrator": ["on", "canGo", "go", "step", "isIn", "reset", "stats"],
    "solver": ["solve", "integrate", "relax", "converged", "stats"],
    "streamer": ["chunkOf", "update", "pump", "isLoaded", "loadedCount", "setRadius", "stats"],
    "composer": ["addLayer", "setWeight", "evaluate", "normalize", "layerNames", "stats"],
    "policy": ["submit", "next", "starved", "pending", "stats"],
    "synthesizer": ["addRule", "addConstraint", "expand", "generate", "reseed", "deterministicCheck", "stats"],
    "document": ["get", "set", "begin", "commit", "rollback", "validate", "isDirty", "markSaved", "serialize", "deserialize", "checksum", "stats"],
    "commands": ["execute", "beginGroup", "endGroup", "undo", "redo", "canUndo", "canRedo", "tick", "historyLabels", "clear", "stats"],
    "selection": ["contains", "add", "remove", "toggle", "set", "clear", "all", "count", "addFilter", "filtered", "stats"],
    "layout": ["addPanel", "split", "dock", "focus", "setVisible", "visiblePanels", "save", "restore", "stats"],
    "widget": ["create", "setProp", "bind", "update", "render", "destroy", "count", "stats"],
    "inspector": ["attach", "fields", "layout", "edit", "apply", "revert", "multiSelect", "applyToAll", "stats"],
    "nodegraph": ["defineType", "addNode", "connect", "topoOrder", "evaluate", "compile", "validate", "stats"],
    "source": ["setText", "tokenize", "extractSymbols", "addRule", "analyze", "complete", "metrics", "rename", "stats"],
    "session": ["join", "leave", "acquireLock", "releaseLock", "submit", "rebase", "since", "updatePresence", "activeUsers", "stats"],
    "merge": ["diff", "threeWay", "resolve", "hasConflicts", "conflictPaths", "stats"],
    "taskgraph": ["addTask", "resolveOrder", "inputHash", "run", "invalidate", "artifact", "stats"],
}

build()
