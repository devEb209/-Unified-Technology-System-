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
        "synthesizer":  '{ id = ID, seed = %d }' % seed,
        "scenegraph":   '{ id = ID }',
        "prefab":       '{ id = ID }',
        "heightfield":  '{ id = ID, width = %d, height = %d, cellSize = %d }' % (16 + (seed % 3) * 8, 16 + (seed % 3) * 8, 2 + seed % 6),
        "voxel":        '{ id = ID }',
        "spline":       '{ id = ID, tension = %.2f, closed = %s }' % (0.35 + (seed % 40) / 100, "false"),
        "mesh":         '{ id = ID }',
        "chunker":      '{ id = ID, size = %d, radius = %d, maxPerTick = %d }' % (64 + (seed % 4) * 32, 256 + (seed % 6) * 64, 2 + seed % 6),
        "wfc":          '{ id = ID }',
        "lsystem":      '{ id = ID, axiom = "F", angle = %d, step = %.1f }' % (18 + seed % 22, 3 + seed % 5),
        "scatter":      '{ id = ID, seed = %d, minDistance = %d, density = %.2f }' % (seed, 6 + seed % 14, 0.6 + (seed % 60) / 100),
        "network":      '{ id = ID }',
        "simulation":   '{ id = ID, fullRadius = %d, reducedRadius = %d, budget = %d }' % (120 + (seed % 6) * 40, 600 + (seed % 8) * 100, 32 + seed % 96),
        "material":     '{ id = ID, texelBudget = %d }' % (262144 * (1 + seed % 8)),
        "sampler":      '{ id = ID, atlasSize = %d, maxSide = 32 }' % (128 + (seed % 4) * 64),
        "shadegraph":   '{ id = ID }',
        "framegraph":   '{ id = ID, budgetMs = %.2f }' % (4 + (seed % 10)),
        "camera":       '{ id = ID, width = %d, height = %d, fov = %.4f, far = %d }' % (
                            828 + (seed % 5) * 128, 720 + (seed % 4) * 180, 0.9 + (seed % 40) / 100, 1200 + (seed % 6) * 200),
        "visibility":   '{ id = ID, maxDepth = %d }' % (2 + seed % 3),
        "impostor":     '{ id = ID, atlasSlots = %d, viewCount = 8, errorThreshold = %.2f }' % (32 + (seed % 6) * 16, 1.0 + (seed % 30) / 10),
        "lightrig":     '{ id = ID, maxActive = %d }' % (4 + seed % 9),
        "probe":        '{ id = ID, spacing = %d }' % (8 + (seed % 5) * 8),
        "temporal":     '{ id = ID, feedback = %.2f, phase = 8 }' % (0.8 + (seed % 15) / 100),
        "upscaler":     '{ id = ID, targetMs = %.2f, index = %d, sharpness = %.2f }' % (11.1 + (seed % 6), 3 + seed % 3, 0.2 + (seed % 40) / 100),
        "inference":    '{ id = ID, seed = %d }' % seed,
        "rigidbody":    '{ id = ID, mass = %.2f, radius = %.2f, restitution = %.2f, friction = %.2f, gravityScale = 1 }'
                        % (1 + seed % 40, 0.3 + (seed % 20) / 20, (seed % 60) / 100, 0.3 + (seed % 50) / 100),
        "collider":     '{ id = ID, shape = "%s", radius = %.2f, height = %.2f, layer = "%s" }'
                        % (["sphere", "box", "capsule"][seed % 3], 0.4 + (seed % 24) / 10, 1.2 + (seed % 12) / 10, ["default", "world", "character", "vehicle"][seed % 4]),
        "contact":      '{ id = ID, slop = %.4f, maxManifolds = %d }' % (0.005 + (seed % 5) / 1000, 128 + seed % 384),
        "constraint":   '{ id = ID, iterations = %d, baumgarte = %.2f, warmStart = true }' % (4 + seed % 10, 0.1 + (seed % 20) / 100),
        "raycaster":    '{ id = ID, cellSize = %d }' % (8 + (seed % 6) * 8),
        "charmotor":    '{ id = ID, radius = %.2f, height = %.2f, maxSpeed = %.2f, jumpHeight = %.2f, stepOffset = %.2f }'
                        % (0.35 + (seed % 20) / 100, 1.6 + (seed % 40) / 100, 4 + (seed % 60) / 10, 1.2 + (seed % 12) / 10, 0.25 + (seed % 30) / 100),
        "vehicle":      '{ id = ID, mass = %d, wheelbase = %.2f, track = %.2f, maxRpm = %d }'
                        % (900 + (seed % 14) * 100, 2.2 + (seed % 12) / 10, 1.4 + (seed % 8) / 10, 5600 + (seed % 12) * 100),
        "skeleton":     '{ id = ID }',
        "clip":         '{ id = ID, duration = %.2f, loop = %s }' % (0.6 + (seed % 26) / 10, "true" if seed % 4 != 0 else "false"),
        "animator":     '{ id = ID, budget = %d }' % (4 + seed % 12),
        "ik":           '{ id = ID, iterations = %d, tolerance = %.4f }' % (4 + seed % 12, 0.001),
        "ragdoll":      '{ id = ID, blendSpeed = %.2f }' % (2 + (seed % 40) / 10),
        "mindnet":      '{ id = ID, inputs = %d, hidden = %d, seed = %d, learningRate = %.3f, exploration = %.3f }'
                        % (6 + seed % 4, 4 + seed % 5, seed, 0.05 + (seed % 10) / 200, 0.02 + (seed % 8) / 200),
        "memory":       '{ id = ID, capacity = %d, decayRate = %.3f, consolidateAt = %d }'
                        % (32 + seed % 96, 0.02 + (seed % 10) / 200, 2 + seed % 4),
        "need":         '{ id = ID }',
        "emotion":      '{ id = ID, inertia = %.2f, decayRate = %.2f, baselineArousal = %.2f }'
                        % (0.75 + (seed % 20) / 100, 0.2 + (seed % 30) / 100, 0.1 + (seed % 20) / 100),
        "perception":   '{ id = ID, sightRange = %d, hearingRange = %d, attentionSlots = %d, fov = %.3f }'
                        % (25 + (seed % 8) * 5, 12 + (seed % 6) * 4, 3 + seed % 4, 1.6 + (seed % 40) / 100),
        "behaviortree": '{ id = ID }',
        "utility":      '{ id = ID, momentum = %.2f }' % ((seed % 20) / 100),
        "planner":      '{ id = ID, maxDepth = %d }' % (6 + seed % 6),
        "navgraph":     '{ id = ID, width = %d, height = %d, cellSize = %d }'
                        % (24 + (seed % 4) * 8, 24 + (seed % 4) * 8, 2 + seed % 4),
        "crowd":        '{ id = ID, radius = %.2f, maxSpeed = %.2f, cellSize = %d }'
                        % (0.4 + (seed % 10) / 20, 3 + (seed % 30) / 10, 6 + seed % 6),
        "society":      '{ id = ID, decayRate = %.3f, gossipReach = %d }'
                        % (0.005 + (seed % 10) / 1000, 2 + seed % 4),
        "economy":      '{ id = ID, elasticity = %.2f }' % (0.15 + (seed % 30) / 100),
        "schedule":     '{ id = ID, startHour = %d }' % (6 + seed % 6),
        "emitter":      '{ id = ID, shape = "%s", rate = %d, speed = %.2f, life = %.2f, budget = %d, seed = %d }'
                        % (["cone", "sphere", "box", "point"][seed % 4], 20 + seed % 60, 3 + (seed % 40) / 10, 0.8 + (seed % 30) / 10, 128 + (seed % 8) * 64, seed),
        "particles":    '{ id = ID, capacity = %d, drag = %.2f, bounce = %.2f, groundY = 0 }'
                        % (128 + (seed % 8) * 64, 0.05 + (seed % 20) / 100, (seed % 50) / 100),
        "forcefield":   '{ id = ID, seed = %d }' % seed,
        "ribbon":       '{ id = ID, maxPoints = %d, lifetime = %.2f, minDistance = %.2f, width = %.2f }'
                        % (16 + (seed % 6) * 8, 0.5 + (seed % 20) / 10, 0.1 + (seed % 10) / 20, 0.2 + (seed % 12) / 10),
        "dsp":          '{ id = ID, sampleRate = %d, filter = "%s", cutoff = %d, q = %.3f }'
                        % (22050, ["lowpass", "highpass", "bandpass", "notch"][seed % 4], 300 + (seed % 20) * 300, 0.5 + (seed % 40) / 100),
        "mixer":        '{ id = ID, maxVoices = %d }' % (16 + (seed % 6) * 8),
        "spatialaudio": '{ id = ID, model = "%s", refDistance = %d, maxDistance = %d, rolloff = %.2f, maxVoices = %d }'
                        % (["inverse", "linear", "exponential"][seed % 3], 3 + seed % 6, 80 + (seed % 10) * 20, 0.8 + (seed % 40) / 100, 12 + (seed % 6) * 4),
        "sequencer":    '{ id = ID, bpm = %d, beatsPerBar = 4, intensity = %.2f }'
                        % (90 + (seed % 8) * 10, 0.3 + (seed % 40) / 100),
        "stats":        '{ id = ID }',
        "inventory":    '{ id = ID, slots = %d, maxWeight = %d }' % (12 + (seed % 8) * 4, 40 + (seed % 12) * 10),
        "quest":        '{ id = ID }',
        "combat":       '{ id = ID, seed = %d, armourK = %d, critMultiplier = %.2f }'
                        % (seed, 80 + (seed % 8) * 10, 1.5 + (seed % 12) / 10),
        "flex":         '{ id = ID, width = %d, height = %d, scale = %.2f }'
                        % (390 + (seed % 6) * 60, 844 + (seed % 5) * 60, 0.9 + (seed % 25) / 100),
        "inputmap":     '{ id = ID, device = "%s", holdTime = %.2f, deadzone = %.2f }'
                        % (["touch", "gamepad", "keyboard"][seed % 3], 0.25 + (seed % 20) / 100, 0.1 + (seed % 15) / 100),
        "tween":        '{ id = ID, timeScale = %.2f }' % (0.9 + (seed % 25) / 100),
        "replicator":   '{ id = ID, mtu = %d, interestRadius = %d, fullEvery = %d }'
                        % (600 + (seed % 8) * 150, 120 + (seed % 10) * 40, 30 + (seed % 6) * 15),
        "netclock":     '{ id = ID, tickRate = %d, bufferDelay = %.3f, maxSamples = %d }'
                        % (20 + (seed % 4) * 10, 0.06 + (seed % 10) / 100, 8 + seed % 16),
        "prediction":   '{ id = ID, errorThreshold = %.3f, smoothing = %.1f, maxInputs = %d }'
                        % (0.03 + (seed % 10) / 200, 8 + seed % 10, 60 + (seed % 6) * 20),
        "intent":       '{ id = ID, minConfidence = %.2f }' % (0.3 + (seed % 15) / 100),
        "knowledge":    '{ id = ID, dims = %d }' % (16 + (seed % 5) * 8),
        "workflow":     '{ id = ID, maxRetries = %d, budget = %d }' % (1 + seed % 3, 40 + (seed % 12) * 10),
        "critic":       '{ id = ID, passMark = %.2f, reviseMark = %.2f, seed = %d }'
                        % (0.70 + (seed % 15) / 100, 0.40 + (seed % 10) / 100, seed),
        "importer":     '{ id = ID, unitScale = %.2f }' % (1.0 + (seed % 4) / 4),
        "bundler":      '{ id = ID, maxBundleBytes = %d }' % (262144 + (seed % 8) * 131072),
        "timeline":     '{ id = ID, duration = %.1f, rate = %.2f }' % (4 + seed % 8, 0.8 + (seed % 40) / 100),
        "camerarig":    '{ id = ID, fov = %.2f, focus = %.1f, aperture = %.1f, smoothing = %.1f, distance = %d, height = %d }'
                        % (0.9 + (seed % 60) / 100, 6 + seed % 14, 1.4 + (seed % 12) / 2, 6 + seed % 8,
                           8 + seed % 14, 2 + seed % 6),
        "grade":        '{ id = ID, exposure = %.2f, contrast = %.2f, saturation = %.2f, toneMap = "%s" }'
                        % ((seed % 30) / 100 - 0.15, 0.9 + (seed % 30) / 100, 0.85 + (seed % 35) / 100,
                           ["filmic", "reinhard", "filmic", "linear"][seed % 4]),
        "reality":      '{ id = ID }',
        "complexity":   '{ id = ID, targetMs = %.1f }' % (11 + (seed % 12)),
        "fabric":       '{ id = ID, budgetMs = %.1f, starvationLimit = %d }'
                        % (1.5 + (seed % 6) / 2, 4 + seed % 8),
        "autopipeline": '{ id = ID, maxIterations = %d }' % (4 + seed % 8),
        "worldmemory":  '{ id = ID, capacity = %d }' % (64 + (seed % 8) * 32),
        "emergence":    '{ id = ID, windowSize = %d, threshold = %.2f, minCount = %d }'
                        % (4 + seed % 4, 1.20 + (seed % 5) / 10, 2 + seed % 2),
        "architect":    '{ id = ID, budget = %d, seed = %d }' % (600 + (seed % 10) * 100, seed),
        "ecology":      '{ id = ID }',
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


# ---------------------------------------------------------------- round 3 kits
SPEC["scenegraph"] = ("""		function inst.buildSample()
			if inst.get("root") then return inst.stats().nodes end
			inst.addNode("root", { position = Vec.vec3(0, 0, 0), tags = { S.area } })
			inst.addNode("hub", { position = Vec.vec3(S.params.baseRadius, 0, 0), tags = { "hub" } }, "root")
			for i = 1, 3 do
				inst.addNode("leaf" .. i, { position = Vec.vec3(i * 10, 0, 0),
					tags = { "leaf" }, radius = S.params.detailWeight * 10 }, "hub")
			end
			return inst.stats().nodes
		end
		function inst.attach(id, parent) return inst.setParent(id, parent) end
		function inst.flatten()
			local out = {}
			inst.traverse(function(node, depth) out[#out + 1] = { id = node.id, depth = depth } end)
			return out
		end
		function inst.moveHub(offset)
			inst.buildSample()
			inst.setPosition("hub", Vec.vec3(offset, 0, 0))
			return inst.worldPosition("leaf1")
		end""",
"""		inst.buildSample()
		local ok = inst.stats().nodes == 5
		ok = ok and inst.worldPosition("leaf1").x == S.params.baseRadius + 10
		ok = ok and inst.depthOf("leaf1") == 2
		ok = ok and #inst.withTag("leaf") == 3
		ok = ok and inst.moveHub(500).x == 510
		ok = ok and #inst.flatten() == 5
		ok = ok and inst.bounds() ~= nil
		ok = ok and inst.remove("hub") == 4
		return ok and inst.stats().nodes == 1""")

SPEC["prefab"] = ("""		function inst.ensureTemplate()
			if inst.templates[S.area] then return S.area end
			inst.define(S.area, { props = { weight = S.params.baseWeight, detail = S.params.detailWeight,
				kind = S.key }, tags = { S.area } })
			return S.area
		end
		function inst.spawnMany(n)
			inst.ensureTemplate()
			local ids = {}
			for i = 1, (n or 4) do ids[#ids + 1] = inst.instantiate(S.area, i == 1 and { weight = 99 } or nil) end
			return ids
		end
		function inst.retune(key, value)
			inst.ensureTemplate()
			return inst.editTemplate(S.area, key, value)
		end
		function inst.overrideRate()
			local total, overridden = 0, 0
			for _, i in pairs(inst.instances) do
				total = total + 1
				for _ in pairs(i.overrides) do overridden = overridden + 1 break end
			end
			if total == 0 then return 0 end
			return overridden / total
		end""",
"""		local ids = inst.spawnMany(4)
		local ok = #ids == 4
		ok = ok and inst.instances[ids[1]].props.weight == 99
		ok = ok and inst.retune("weight", 7) == 3
		ok = ok and inst.instances[ids[2]].props.weight == 7
		ok = ok and inst.instances[ids[1]].props.weight == 99
		ok = ok and inst.overrideRate() == 0.25
		inst.revert(ids[1], "weight")
		ok = ok and inst.instances[ids[1]].props.weight == 7
		return ok and #inst.instancesOf(S.area) == 4""")

SPEC["heightfield"] = ("""		function inst.shape()
			inst.applyNoise({ frequency = 0.02 + S.params.detailWeight * 0.05,
				amplitude = 20 + S.params.ceiling / 8, seed = S.params.horizon * 7919, octaves = 3 })
			return inst.range()
		end
		function inst.sculptAt(x, y, radius, strength)
			return inst.raise(x, y, radius or 3, strength or S.params.baseWeight * 10)
		end
		function inst.profile(samples)
			local out = {}
			local n = samples or 8
			for i = 0, n do
				local t = i / n
				out[#out + 1] = inst.sample(t * (inst.width - 1) * inst.cellSize, (inst.height / 2) * inst.cellSize)
			end
			return out
		end
		function inst.roughness()
			local total, n = 0, 0
			for y = 2, inst.height - 1, 2 do
				for x = 2, inst.width - 1, 2 do
					total = total + inst.slopeAt(x, y)
					n = n + 1
				end
			end
			if n == 0 then return 0 end
			return total / n
		end""",
"""		local lo, hi = inst.shape()
		local ok = hi > lo
		local before = inst.get(4, 4)
		inst.sculptAt(4, 4, 3, 15)
		ok = ok and inst.get(4, 4) > before
		inst.flatten(6, 6, 2, 0, 1)
		ok = ok and math.abs(inst.get(6, 6)) < 0.001
		ok = ok and #inst.profile(4) == 5
		ok = ok and inst.roughness() >= 0
		ok = ok and inst.erodeThermal(1, 1.0, 0.5) >= 0
		local lod = inst.downsample()
		ok = ok and lod.width == math.floor(inst.width / 2)
		inst.normalize(0, 10)
		local lo2, hi2 = inst.range()
		return ok and math.abs(lo2) < 0.001 and math.abs(hi2 - 10) < 0.001""")

SPEC["voxel"] = ("""		function inst.buildSample()
			if inst.count > 0 then return inst.count end
			inst.fillBox(1, 1, 1, 3, 3, 3, inst.materials[1])
			return inst.count
		end
		function inst.carveAt(x, y, z, radius) return inst.carveSphere(x, y, z, radius or 1) end
		function inst.density()
			local b = inst.bounds()
			if not b then return 0 end
			local volume = math.max(1, (b.max.x - b.min.x + 1) * (b.max.y - b.min.y + 1) * (b.max.z - b.min.z + 1))
			return inst.count / volume
		end
		function inst.surfaceRatio()
			if inst.count == 0 then return 0 end
			return inst.surfaceFaces() / (inst.count * 6)
		end""",
"""		inst.buildSample()
		local ok = inst.count == 27
		ok = ok and inst.surfaceFaces() == 54
		ok = ok and math.abs(inst.density() - 1) < 0.001
		ok = ok and inst.surfaceRatio() > 0.3
		ok = ok and inst.carveAt(2, 2, 2, 0.9) == 1
		ok = ok and inst.count == 26
		ok = ok and inst.floodFill(1, 1, 1, inst.materials[2]) > 10
		return ok and inst.bounds() ~= nil""")

SPEC["spline"] = ("""		function inst.buildDefault()
			if inst.count() > 0 then return inst.count() end
			local span = S.params.baseRadius / 2
			inst.addPoint(Vec.vec3(0, 0, 0))
			inst.addPoint(Vec.vec3(span, 0, 0))
			inst.addPoint(Vec.vec3(span * 2, 0, span))
			inst.addPoint(Vec.vec3(span * 3, 0, span))
			return inst.count()
		end
		function inst.path(samples)
			inst.buildDefault()
			return inst.resample(samples or 8)
		end
		function inst.corridor(width, samples)
			inst.buildDefault()
			return inst.offset(width or S.params.detailWeight * 10, samples or 8)
		end
		function inst.deviation(point)
			inst.buildDefault()
			local _, _, d = inst.closestPoint(point)
			return d
		end""",
"""		inst.buildDefault()
		local ok = inst.count() == 4
		ok = ok and inst.arcLength() > 0
		ok = ok and #inst.path(6) == 6
		ok = ok and #inst.corridor(5, 4) == 5
		local mid = inst.evaluate(0.5)
		ok = ok and type(mid.x) == "number"
		ok = ok and math.abs(inst.tangent(0.5):length() - 1) < 0.01
		ok = ok and inst.deviation(Vec.vec3(0, 0, 0)) < 1e-6
		return ok and inst.pointAtDistance(inst.arcLength() * 0.5) ~= nil""")

SPEC["mesh"] = ("""		function inst.buildBox(size)
			local s = size or (4 + S.params.detailWeight * 8)
			inst.box(Vec.vec3(0, 0, 0), Vec.vec3(s, s, s))
			return inst.stats().triangles
		end
		function inst.buildTower(footprint, height)
			local f = footprint or 8
			local poly = { Vec.vec3(0, 0, 0), Vec.vec3(f, 0, 0), Vec.vec3(f, 0, f), Vec.vec3(0, 0, f) }
			return inst.extrude(poly, height or (10 + S.params.ceiling / 20))
		end
		function inst.optimize()
			local welded = inst.weld()
			local dropped = inst.simplify(1e-6)
			inst.computeNormals()
			return welded, dropped
		end
		function inst.surfaceArea() return inst.area() end""",
"""		local tris = inst.buildBox(10)
		local ok = tris == 12 and inst.stats().vertices == 8
		ok = ok and math.abs(inst.surfaceArea() - 600) < 1
		ok = ok and inst.buildTower(8, 20) == 4
		ok = ok and inst.stats().triangles > 12
		local welded, dropped = inst.optimize()
		ok = ok and welded >= 0 and dropped >= 0
		ok = ok and inst.stats().normals == inst.stats().vertices
		return ok and inst.bounds() ~= nil""")

SPEC["chunker"] = ("""		function inst.focus(position)
			inst.lastFocus = position
			return inst.update(position)
		end
		function inst.streamStep(position)
			inst.focus(position or inst.lastFocus or Vec.vec3(0, 0, 0))
			return inst.pump()
		end
		function inst.coverage()
			local tracked = inst.stats().tracked
			if tracked == 0 then return 0 end
			return inst.loaded / tracked
		end
		function inst.lodProfile(position)
			local out = {}
			for _, key in ipairs(inst.loadedKeys()) do
				local lod = inst.lodOf(key, position)
				out[lod] = (out[lod] or 0) + 1
			end
			return out
		end""",
"""		local toLoad = inst.focus(Vec.vec3(0, 0, 0))
		local ok = #toLoad > 0
		local moved = inst.streamStep(Vec.vec3(0, 0, 0))
		ok = ok and moved > 0 and moved <= inst.maxPerTick
		ok = ok and inst.loaded == moved
		ok = ok and inst.coverage() > 0
		local profile = inst.lodProfile(Vec.vec3(0, 0, 0))
		ok = ok and profile[0] ~= nil
		local _, toUnload = inst.update(Vec.vec3(1e6, 0, 1e6))
		return ok and #toUnload == moved""")

SPEC["wfc"] = ("""		function inst.installTiles()
			if inst.tiles["core"] then return inst end
			inst.defineTile("core", { up = "a", down = "a", left = "a", right = "a" }, 3)
			inst.defineTile("edge", { up = "a", down = "b", left = "a", right = "a" }, 2)
			inst.defineTile("outer", { up = "b", down = "b", left = "a", right = "a" }, 1)
			return inst
		end
		function inst.generate(width, height)
			inst.installTiles()
			return inst.solve(width or 5, height or 5, S.params.horizon * 104729 + 7)
		end
		function inst.tileHistogram()
			if not inst.result then inst.generate() end
			return inst.histogram()
		end
		function inst.consistency()
			if not inst.result then inst.generate() end
			local ok, bad = inst.validate()
			return ok, bad
		end""",
"""		local grid = inst.generate(5, 5)
		local ok = #grid == 25
		for i = 1, 25 do ok = ok and inst.tiles[grid[i]] ~= nil end
		local twin = Kits.create("wfc", { id = "probe" })
		twin.defineTile("core", { up = "a", down = "a", left = "a", right = "a" }, 3)
		twin.defineTile("edge", { up = "a", down = "b", left = "a", right = "a" }, 2)
		twin.defineTile("outer", { up = "b", down = "b", left = "a", right = "a" }, 1)
		local grid2 = twin.solve(5, 5, S.params.horizon * 104729 + 7)
		for i = 1, 25 do ok = ok and grid[i] == grid2[i] end
		local histogram = inst.tileHistogram()
		local total = 0
		for _, n in pairs(histogram) do total = total + n end
		ok = ok and total == 25
		local consistent = inst.consistency()
		return ok and type(consistent) == "boolean" """)

SPEC["lsystem"] = ("""		function inst.installRules()
			if inst.rules["F"] then return inst end
			inst.addRule("F", "F[+F]F[-F]F")
			inst.addRule("X", "F[+X][-X]FX")
			return inst
		end
		function inst.grow(iterations)
			inst.installRules()
			return inst.iterate(iterations or 2)
		end
		function inst.geometry(origin)
			if not inst.current then inst.grow(2) end
			return inst.interpret(origin or Vec.vec3(0, 0, 0))
		end
		function inst.complexity()
			local segments = inst.geometry()
			return #segments, inst.totalLength()
		end""",
"""		local expanded = inst.grow(2)
		local ok = #expanded > 20
		local segments = inst.geometry(Vec.vec3(0, 0, 0))
		ok = ok and #segments > 5
		local count, length = inst.complexity()
		ok = ok and count == #segments and length > 0
		ok = ok and inst.bounds() ~= nil
		inst.reset()
		return ok and inst.stats().iterations == 0""")

SPEC["scatter"] = ("""		function inst.distribute(bounds, attempts)
			local Spatial = A:import("arkher/kernel/spatial")
			local box = bounds or Spatial.aabb(Vec.vec3(0, 0, 0), Vec.vec3(200, 0, 200))
			return inst.generate(box, attempts or 200)
		end
		function inst.spacing()
			if #inst.points == 0 then inst.distribute() end
			return inst.minimumSpacing()
		end
		function inst.prune(predicate)
			local kept = {}
			for _, p in ipairs(inst.points) do
				if predicate(p) then kept[#kept + 1] = p end
			end
			local removed = #inst.points - #kept
			inst.points = kept
			return removed
		end
		function inst.coverage(area)
			if #inst.points == 0 then inst.distribute() end
			return #inst.points / math.max(1, area or 40000)
		end""",
"""		local points = inst.distribute(nil, 200)
		local ok = #points > 0
		ok = ok and inst.spacing() >= (#points > 1 and inst.minDistance or 0)
		ok = ok and inst.stats().rejected >= 0
		local removed = inst.prune(function(p) return p.x <= 100 end)
		ok = ok and removed >= 0
		for _, p in ipairs(inst.points) do ok = ok and p.x <= 100 end
		ok = ok and inst.coverage(40000) >= 0
		return ok""")

SPEC["network"] = ("""		function inst.buildGrid(size, spacing)
			if inst.gridIds then return inst.gridIds end
			local n = size or 3
			local step = spacing or 100
			local ids = {}
			for r = 0, n - 1 do
				ids[r] = {}
				for c = 0, n - 1 do
					ids[r][c] = inst.addNode(Vec.vec3(c * step, 0, r * step), "junction")
				end
			end
			for r = 0, n - 1 do
				for c = 0, n - 1 do
					if c < n - 1 then inst.addEdge(ids[r][c], ids[r][c + 1], { class = "street" }) end
					if r < n - 1 then inst.addEdge(ids[r][c], ids[r + 1][c], { class = "street" }) end
				end
			end
			inst.gridIds = ids
			inst.gridSize = n
			inst.gridSpacing = step
			return ids
		end
		function inst.routeAcross()
			local ids = inst.buildGrid()
			local n = inst.gridSize
			return inst.route(ids[0][0], ids[n - 1][n - 1])
		end
		function inst.topology()
			inst.buildGrid()
			return { junctions = #inst.junctions(3), deadEnds = #inst.deadEnds(),
				connected = inst.connected(), length = inst.totalLength() }
		end
		function inst.snap(position)
			inst.buildGrid()
			return inst.nearestNode(position)
		end""",
"""		inst.buildGrid(3, 100)
		local path, cost = inst.routeAcross()
		local ok = path ~= nil and #path == 5
		ok = ok and math.abs(cost - 400) < 0.001
		local topology = inst.topology()
		ok = ok and topology.connected == true and topology.deadEnds == 0
		ok = ok and math.abs(topology.length - 1200) < 0.001
		local nearest = inst.snap(Vec.vec3(95, 0, 5))
		return ok and nearest == inst.gridIds[0][1]""")

SPEC["simulation"] = ("""		function inst.populate(n)
			if inst.stats().entities > 0 then return inst.stats().entities end
			for i = 1, (n or 6) do
				inst.spawn(S.key .. "." .. i, {
					position = Vec.vec3(i * 100, 0, 0),
					state = { value = 10, ticks = 0 },
					update = function(st, dt) st.value = st.value + dt st.ticks = st.ticks + 1 end,
					aggregate = function(st, elapsed) st.value = st.value + elapsed * 0.25 end,
				})
			end
			return inst.stats().entities
		end
		function inst.observeAt(position)
			inst.populate()
			return inst.setObserver(position or Vec.vec3(0, 0, 0))
		end
		function inst.run(ticks, dt)
			inst.populate()
			local processed = 0
			for _ = 1, (ticks or 30) do processed = processed + inst.tick(dt or 1 / 30) end
			return processed
		end
		function inst.total() return inst.aggregateState("value") end""",
"""		inst.populate(6)
		local counts = inst.observeAt(Vec.vec3(0, 0, 0))
		local ok = counts.full + counts.reduced + counts.statistical == 6
		local before = inst.total()
		local processed = inst.run(30, 1 / 30)
		ok = ok and processed > 0
		ok = ok and inst.total() > before
		ok = ok and #inst.query(1e9) == 6
		ok = ok and inst.catchUp(S.key .. ".1", 10)
		return ok and inst.stats().ticks == 30""")


SPEC["field"] = ("""		function inst.height(x, y)
			return inst.sample(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.ridgeHeight(x, y)
			return inst.sampleRidged(x, y) * (20 + S.params.ceiling / 10)
		end
		function inst.patch(size, step)
			local n = size or 8
			return inst.region(0, 0, n, n, step or 2)
		end
		function inst.steepness(x, y)
			return inst.slope(x, y)
		end
		function inst.banded(x, y, steps)
			return inst.terraced(x, y, steps or (4 + S.params.horizon % 6))
		end""",
"""		local a = inst.sample(12.5, -7.25)
		local b = inst.sample(12.5, -7.25)
		local ok = a == b and type(a) == "number"
		ok = ok and inst.height(3, 3) == inst.sample(3, 3) * (20 + S.params.ceiling / 10)
		ok = ok and type(inst.ridgeHeight(3, 3)) == "number"
		local rows = inst.patch(8, 2)
		ok = ok and #rows == 5 and #rows[1] == 5
		ok = ok and inst.steepness(4, 4) >= 0
		local terr = inst.banded(4, 4, 5)
		ok = ok and type(terr) == "number"
		return ok and inst.stats().samples > 0""")

SPEC["synthesizer"] = ("""		function inst.installGrammar()
			if inst.stats().rules > 0 then return inst end
			inst.addRule("root", { { value = "block block", weight = 3 }, { value = "block", weight = 1 } })
			inst.addRule("block", { { value = "wall roof", weight = 2 }, { value = "wall", weight = 1 } })
			return inst
		end
		function inst.synthesize(attempts)
			inst.installGrammar()
			return inst.generate("root", attempts or 6)
		end
		function inst.requireToken(token)
			inst.installGrammar()
			inst.addConstraint("requires." .. token, function(result)
				return string.find(result, token, 1, true) ~= nil
			end)
			return inst
		end
		function inst.tokenCount(result)
			local n = 0
			for _ in string.gmatch(result or "", "%S+") do n = n + 1 end
			return n
		end""",
"""		inst.installGrammar()
		local ok = inst.stats().rules == 2
		local result, satisfied = inst.synthesize(6)
		ok = ok and type(result) == "string" and satisfied == true
		ok = ok and inst.tokenCount(result) >= 1
		inst.requireToken("roof")
		local guarded, met = inst.synthesize(12)
		ok = ok and (not met or string.find(guarded, "roof", 1, true) ~= nil)
		ok = ok and inst.deterministicCheck("root") == true
		return ok and inst.stats().generated > 0""")


# ---------------------------------------------------------------- round 4 kits
SPEC["material"] = ("""		function inst.buildSurface()
			if inst.layers["base"] then return inst end
			inst.addLayer("base", { albedo = 0x808080, roughness = 0.5 + S.params.detailWeight * 0.4,
				metallic = (S.params.horizon % 2) * 0.5, weight = 1.0, texels = 65536 })
			inst.addLayer("detail", { albedo = 0x6A6A66, roughness = 0.9, weight = 0.4,
				texels = 16384, mask = function(ctx) return ctx.wear or 0 end })
			return inst
		end
		function inst.surfaceAt(ctx)
			inst.buildSurface()
			return inst.resolve(ctx)
		end
		function inst.wearVariant(amount)
			inst.buildSurface()
			inst.defineVariant("worn", { detail = { weight = amount or 0.9 } })
			inst.applyVariant("worn")
			return inst.resolve({ wear = 1 })
		end
		function inst.distanceParams(distance)
			inst.buildSurface()
			return inst.lodParams(distance or S.params.baseRadius)
		end""",
"""		inst.buildSurface()
		local clean = inst.surfaceAt({ wear = 0 })
		local worn = inst.surfaceAt({ wear = 1 })
		local ok = clean.layers == 1 and worn.layers == 2
		ok = ok and worn.roughness >= clean.roughness - 0.001
		ok = ok and inst.memoryBytes() > 0
		ok = ok and inst.checksum() == inst.checksum()
		local lod = inst.distanceParams(900)
		ok = ok and lod.layers >= 1 and lod.level >= 0
		ok = ok and inst.wearVariant(0.9) ~= nil
		return ok and inst.describe().id ~= nil""")

SPEC["sampler"] = ("""		function inst.ensureTexture()
			if inst.get(S.key) then return S.key end
			inst.defineTexture(S.key, 8, 8, function(u, v) return (u + v) * 0.5 end)
			inst.pack(S.key)
			return S.key
		end
		function inst.detail(u, v, lod)
			inst.ensureTexture()
			return inst.sampleLod(S.key, u, v, lod or 0)
		end
		function inst.footprint()
			inst.ensureTexture()
			return inst.residentBytes(), inst.occupancy()
		end
		function inst.lodForDistance(distance)
			inst.ensureTexture()
			return inst.lodFor(S.key, math.max(1, distance / 32))
		end""",
"""		inst.ensureTexture()
		local ok = inst.get(S.key) ~= nil
		ok = ok and math.abs(inst.sample(S.key, 0, 0) - 0) < 0.01
		ok = ok and math.abs(inst.sample(S.key, 1, 1) - 1) < 0.01
		ok = ok and inst.buildMips(S.key) == 4
		ok = ok and inst.detail(0.5, 0.5, 1) >= 0
		local bytes, occupancy = inst.footprint()
		ok = ok and bytes > 0 and occupancy > 0
		ok = ok and inst.lodForDistance(256) > 0
		return ok and inst.stats().samples > 0""")

SPEC["shadegraph"] = ("""		function inst.buildGraph()
			if inst.nodes["out"] then return inst end
			inst.addNode("k", "constant", { value = S.params.detailWeight })
			inst.addNode("src", "input", { key = "value", default = 0.5 })
			inst.addNode("sum", "add")
			inst.addNode("sat", "saturate")
			inst.addNode("out", "output", { channel = "value" })
			inst.connect("k", "sum", 1)
			inst.connect("src", "sum", 2)
			inst.connect("sum", "sat", 1)
			inst.connect("sat", "out", 1)
			return inst
		end
		function inst.shade(value)
			inst.buildGraph()
			local out = inst.evaluate({ value = value or 0.5 })
			return out.value
		end
		function inst.optimize()
			inst.buildGraph()
			return inst.fold()
		end
		function inst.source()
			inst.buildGraph()
			return inst.compile()
		end""",
"""		inst.buildGraph()
		local ok = inst.stats().nodes == 5
		local expected = math.min(1, S.params.detailWeight + 0.25)
		ok = ok and math.abs(inst.shade(0.25) - expected) < 1e-9
		ok = ok and inst.optimize() >= 0
		local src = inst.source()
		ok = ok and type(src) == "string" and #src > 40
		ok = ok and inst.hasCycle() == false
		return ok and inst.stats().evaluations > 0""")

SPEC["framegraph"] = ("""		function inst.buildFrame()
			if inst.passes["main"] then return inst end
			inst.addPass("prepare", { writes = { "buffer" }, cost = 1.0 })
			inst.addPass("extra", { reads = { "buffer" }, writes = { "aux" }, cost = 2.0,
				optional = true, priority = 2 })
			inst.addPass("main", { reads = { "buffer", "aux" }, writes = { "out" }, cost = 1.5,
				final = true })
			inst.addPass("orphan", { writes = { "unused" }, cost = 4.0 })
			return inst
		end
		function inst.frameOrder()
			inst.buildFrame()
			return inst.compile()
		end
		function inst.runFrame(budget)
			inst.buildFrame()
			return inst.execute({}, budget)
		end
		function inst.memoryPlan()
			inst.buildFrame()
			return inst.alias()
		end""",
"""		local order = inst.frameOrder()
		local ok = #order == 3 and inst.culled == 1
		ok = ok and order[#order] == "main"
		local tight = inst.runFrame(2.0)
		ok = ok and #tight.skipped == 1
		local loose = inst.runFrame(50)
		ok = ok and #loose.skipped == 0
		local plan = inst.memoryPlan()
		ok = ok and plan.peakBytes > 0
		return ok and inst.totalCost() > 0""")

SPEC["camera"] = ("""		function inst.frame(target)
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
		end""",
"""		inst.frame(Vec.vec3(0, 0, -100))
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
		return ok and inst.stats().tested > 0""")

SPEC["visibility"] = ("""		function inst.buildLevel(rooms)
			if inst.cells["cell1"] then return inst end
			local Spatial = A:import("arkher/kernel/spatial")
			local n = rooms or 4
			for i = 1, n do
				inst.addCell("cell" .. i, Spatial.aabb(Vec.vec3(i * 20, 0, 0), Vec.vec3(i * 20 + 18, 10, 18)))
				inst.addItem("cell" .. i, "item" .. i)
			end
			for i = 1, n - 1 do inst.addPortal("cell" .. i, "cell" .. (i + 1)) end
			return inst
		end
		function inst.setFrom(cell, depth)
			inst.buildLevel()
			return inst.computePVS(cell or "cell1", depth)
		end
		function inst.itemsFrom(cell, depth)
			inst.buildLevel()
			return inst.visibleItems(cell or "cell1", depth)
		end
		function inst.blockLine(from, to)
			inst.buildLevel()
			return inst.occluded(from, to)
		end""",
"""		inst.buildLevel(4)
		local pvs = inst.setFrom("cell1", 1)
		local ok = #pvs == 2
		ok = ok and #inst.setFrom("cell1", 3) == 4
		ok = ok and #inst.itemsFrom("cell1", 1) == 2
		ok = ok and inst.cellAt(Vec.vec3(25, 1, 1)) == "cell1"
		local Spatial = A:import("arkher/kernel/spatial")
		inst.addOccluder(Spatial.aabb(Vec.vec3(-1, -1, 4), Vec.vec3(1, 5, 6)))
		ok = ok and inst.blockLine(Vec.vec3(0, 1, 0), Vec.vec3(0, 1, 10)) == true
		ok = ok and inst.blockLine(Vec.vec3(0, 1, 0), Vec.vec3(10, 1, 0)) == false
		return ok and inst.coverage("cell1") > 0""")

SPEC["impostor"] = ("""		function inst.ensureEntry()
			if inst.entries[S.key] then return S.key end
			inst.register(S.key, { triangles = 2000 + S.params.horizon % 8000,
				radius = 2 + S.params.detailWeight * 8 })
			inst.captureViews(S.key, 8)
			return S.key
		end
		function inst.representation(distance)
			inst.ensureEntry()
			return inst.select(S.key, distance or 50, 720, 1.22)
		end
		function inst.pixelError(distance)
			inst.ensureEntry()
			return inst.screenError(S.key, distance or 50, 720, 1.22)
		end
		function inst.spend(budget)
			inst.ensureEntry()
			return inst.budgetPass({ { id = S.key, distance = 10 } }, budget or 4000)
		end""",
"""		inst.ensureEntry()
		local ok = inst.entries[S.key].views ~= nil
		local nearMode = inst.representation(5)
		local farMode = inst.representation(5000)
		ok = ok and nearMode == "mesh"
		ok = ok and (farMode == "impostor" or farMode == "culled")
		ok = ok and inst.pixelError(5) > inst.pixelError(500)
		local view = inst.nearestView(S.key, Vec.vec3(1, 0, 0))
		ok = ok and view ~= nil
		local spent = inst.spend(100000)
		ok = ok and spent.meshes == 1
		return ok and inst.stats().slots > 0""")

SPEC["lightrig"] = ("""		function inst.buildRig(count)
			if inst.lights["key"] then return inst end
			inst.addLight("key", { type = "directional", intensity = 2.5, shadows = true })
			for i = 1, (count or 4) do
				inst.addLight("fill" .. i, { position = Vec.vec3(i * 10, 3, 0),
					range = 10 + S.params.detailWeight * 20, intensity = 1 + i * 0.1 })
			end
			return inst
		end
		function inst.activeAt(point)
			inst.buildRig()
			return inst.importance(point or Vec.vec3(0, 0, 0))
		end
		function inst.shadowPlan(near, far)
			inst.buildRig()
			return inst.cascadeSplits(near or 1, far or 400, 3, 0.75)
		end
		function inst.daylight(elevation)
			inst.buildRig()
			return inst.setSunAngle(elevation or (math.pi / 3))
		end""",
"""		inst.buildRig(4)
		local Spatial = A:import("arkher/kernel/spatial")
		local clusters = inst.cluster(Spatial.aabb(Vec.vec3(-20, -10, -20), Vec.vec3(80, 20, 20)), 3)
		local ok = clusters ~= nil and inst.stats().assignments > 0
		local active = inst.activeAt(Vec.vec3(10, 2, 0))
		ok = ok and #active >= 1 and #active <= inst.maxActive
		ok = ok and active[1].id == "key"
		local splits = inst.shadowPlan(1, 400)
		ok = ok and #splits == 3 and splits[1] < splits[3]
		local intensity, ambient = inst.daylight(math.pi / 2)
		ok = ok and intensity > 0 and ambient > 0
		ok = ok and #inst.shadowCasters(1) <= 1
		return ok and #inst.lightsAt(Vec.vec3(10, 2, 0)) >= 1""")

SPEC["probe"] = ("""		function inst.buildVolume()
			if #inst.probes > 0 then return #inst.probes end
			local Spatial = A:import("arkher/kernel/spatial")
			local span = inst.spacing
			inst.place(Spatial.aabb(Vec.vec3(0, 0, 0), Vec.vec3(span, span, span)), span)
			inst.bake(function(_, dir) return dir.y > 0 and 1.0 or 0.15 end, 8)
			return #inst.probes
		end
		function inst.irradiance(point, normal)
			inst.buildVolume()
			return inst.sampleAt(point or Vec.vec3(1, 1, 1), normal or Vec.vec3(0, 1, 0))
		end
		function inst.refresh(budget)
			inst.buildVolume()
			return inst.rebake(function() return 0.5 end, budget or 2)
		end
		function inst.footprint()
			inst.buildVolume()
			return inst.memoryBytes()
		end""",
"""		local count = inst.buildVolume()
		local ok = count == 8
		local up = inst.irradiance(Vec.vec3(1, 1, 1), Vec.vec3(0, 1, 0))
		local down = inst.irradiance(Vec.vec3(1, 1, 1), Vec.vec3(0, -1, 0))
		ok = ok and up > down
		ok = ok and inst.footprint() > 0
		local Spatial = A:import("arkher/kernel/spatial")
		local dirty = inst.invalidate(Spatial.aabb(Vec.vec3(-1, -1, -1), Vec.vec3(1, 1, 1)))
		ok = ok and dirty > 0 and inst.dirtyCount() == dirty
		ok = ok and inst.refresh(1) == 1
		return ok and inst.stats().bakes > 0""")

SPEC["temporal"] = ("""		function inst.frameJitter(index)
			return inst.jitter(index or inst.frame)
		end
		function inst.accumulate(key, value, motion)
			inst.advance()
			return inst.resolve(key or S.key, value or 1, { motion = motion or 0 })
		end
		function inst.stabilize(value, neighbors)
			return inst.clamp(value, neighbors or { 0.2, 0.25, 0.3 })
		end
		function inst.samplesFor(key)
			return inst.effectiveSamples(key or S.key)
		end""",
"""		local jx, jy = inst.frameJitter(1)
		local jx2 = inst.frameJitter(2)
		local ok = jx ~= jx2 and math.abs(jy) <= 0.5
		local first = inst.accumulate(S.key, 0, 0)
		ok = ok and first == 0
		local second = inst.accumulate(S.key, 1, 0)
		ok = ok and second > 0 and second < 1
		ok = ok and inst.accumulationOf(S.key) == 2
		ok = ok and inst.samplesFor(S.key) >= 1
		local clamped, wasClamped = inst.stabilize(9.0)
		ok = ok and wasClamped == true and clamped < 1
		local reset = inst.accumulate(S.key, 0.5, 9999)
		ok = ok and reset == 0.5
		inst.reset()
		return ok and inst.stats().tracked == 0""")

SPEC["upscaler"] = ("""		function inst.adapt(frameMs)
			return inst.evaluate(frameMs or inst.targetMs)
		end
		function inst.settle(frameMs, iterations)
			for _ = 1, (iterations or 6) do inst.evaluate(frameMs) end
			return inst.scale()
		end
		function inst.resolveLine(samples, target)
			return inst.reconstruct(samples or { 0, 0.5, 1 }, target or 6)
		end
		function inst.crispen(samples, amount)
			return inst.sharpen(samples or { 0.2, 0.5, 0.2 }, amount)
		end""",
"""		local heavy = inst.settle(60, 8)
		local ok = heavy <= inst.ladder[1] + 1e-9
		local light = inst.settle(1, 12)
		ok = ok and light >= inst.ladder[#inst.ladder] - 1e-9
		local line = inst.resolveLine({ 0, 0, 1, 1 }, 8)
		ok = ok and #line == 8 and line[1] <= 0.05 and line[8] >= 0.95
		local crisp = inst.crispen({ 0.2, 0.5, 0.2 }, 0.4)
		ok = ok and #crisp == 3
		ok = ok and inst.quality() > 0 and inst.quality() <= 1
		ok = ok and inst.savings(1000, 1000) >= 0
		return ok and inst.stats().evaluations > 0""")

SPEC["inference"] = ("""		function inst.buildModel(hidden)
			if #inst.layers > 0 then return inst end
			inst.addLayer(3, hidden or 4, "tanh")
			inst.addLayer(hidden or 4, 1, "sigmoid")
			return inst
		end
		function inst.predict(features)
			inst.buildModel()
			return inst.forward(features or { 0.5, 0.5, 0.5 })[1]
		end
		function inst.fit(samples, epochs, lr)
			inst.buildModel()
			return inst.train(samples, epochs or 4, lr or 0.2)
		end
		function inst.compress(bits)
			inst.buildModel()
			return inst.quantize(bits or 8)
		end""",
"""		inst.buildModel(4)
		local ok = inst.parameters() == 3 * 4 + 4 + 4 + 1
		local first = inst.predict({ 0.5, 0.25, 0.75 })
		local second = inst.predict({ 0.5, 0.25, 0.75 })
		ok = ok and first == second and first > 0 and first < 1
		ok = ok and inst.flops() > 0
		local weights = inst.exportWeights()
		ok = ok and #weights == inst.parameters()
		ok = ok and inst.importWeights(weights) == inst.parameters()
		local err = inst.compress(8)
		ok = ok and err >= 0 and err < 0.1
		ok = ok and inst.memoryBytes() < inst.parameters() * 4
		return ok and inst.stats().forwards >= 2""")


# ---------------------------------------------------------------- round 5 :: motion kits
SPEC["rigidbody"] = ("""		local stepBody = inst.integrate
		function inst.integrateBody(dt, gravity) return stepBody(dt, gravity) end
		function inst.simulate(dt, steps, gravity)
			local g = gravity or Vec.vec3(0, -9.81, 0)
			for _ = 1, (steps or 8) do stepBody(dt or (1 / 60), g) end
			return inst.position
		end
		function inst.launch(direction, power)
			inst.wake()
			inst.applyImpulse(direction * (power or 10))
			return inst.velocity
		end
		function inst.restAt(position)
			inst.teleport(position or Vec.vec3())
			inst.velocity = Vec.vec3()
			inst.angularVelocity = Vec.vec3()
			return inst.position
		end
		function inst.fallHeight(seconds, gravity)
			local start = inst.position.y
			inst.simulate(1 / 60, math.floor((seconds or 1) * 60), gravity)
			return start - inst.position.y
		end""",
"""		inst.restAt(Vec.vec3(0, 10, 0))
		local dropped = inst.fallHeight(0.2, Vec.vec3(0, -10, 0))
		local ok = dropped > 0 and inst.velocity.y < 0
		inst.launch(Vec.vec3(0, 1, 0), 100)
		ok = ok and inst.velocity.y > 0 and inst.kineticEnergy() > 0
		ok = ok and inst.momentum():length() > 0
		inst.restAt(Vec.vec3())
		return ok and inst.stats().steps > 0""")

SPEC["collider"] = ("""		function inst.placeAt(x, y, z) return inst.setCenter(Vec.vec3(x, y, z)) end
		function inst.boundsSize()
			local box = inst.aabb()
			return box.max - box.min
		end
		function inst.overlaps(other)
			local _, distance = other.closestPoint(inst.center)
			return distance <= (inst.shape == "box" and inst.halfExtents:length() or inst.radius)
		end
		function inst.penetration(point)
			local _, distance = inst.closestPoint(point)
			return math.max(0, (inst.shape == "box" and inst.halfExtents:length() or inst.radius) - distance)
		end
		function inst.widestAxis()
			local size = inst.boundsSize()
			if size.x >= size.y and size.x >= size.z then return "x" end
			if size.y >= size.z then return "y" end
			return "z"
		end""",
"""		inst.placeAt(0, 0, 0)
		local ok = inst.volume() > 0 and inst.boundsSize():length() > 0
		ok = ok and inst.contains(inst.center)
		local far = Vec.vec3(500, 500, 500)
		ok = ok and not inst.contains(far)
		local point, distance = inst.closestPoint(far)
		ok = ok and distance > 0 and point:length() > 0
		ok = ok and inst.support(Vec.vec3(1, 0, 0)):length() > 0
		ok = ok and inst.expandedBy(1).volume() > inst.volume()
		return ok and inst.widestAxis() ~= nil""")

SPEC["contact"] = ("""		function inst.pair(distance)
			local a = Kits.create("collider", { id = S.key .. ".a", shape = "sphere",
				center = Vec.vec3(0, 0, 0), radius = 1 })
			local b = Kits.create("collider", { id = S.key .. ".b", shape = "sphere",
				center = Vec.vec3(distance or 1.5, 0, 0), radius = 1 })
			return a, b
		end
		function inst.probe(distance)
			local a, b = inst.pair(distance)
			return inst.test(a, b)
		end
		function inst.depthAt(distance)
			local manifold = inst.probe(distance)
			if not manifold then return 0 end
			return manifold.depth
		end
		function inst.sweepRange(from, to, steps)
			local hits = 0
			for i = 0, (steps or 4) do
				local d = from + (to - from) * (i / math.max(1, steps or 4))
				if inst.probe(d) then hits = hits + 1 end
			end
			return hits
		end""",
"""		local manifold = inst.probe(1.5)
		local ok = manifold ~= nil and manifold.depth > 0.4 and manifold.depth < 0.6
		ok = ok and inst.probe(50) == nil
		ok = ok and inst.depthAt(1.0) > inst.depthAt(1.8)
		ok = ok and inst.sweepRange(0.5, 3.0, 4) >= 2
		inst.clear()
		return ok and inst.stats().tests > 0""")

SPEC["constraint"] = ("""		function inst.testBodies(distance)
			return {
				anchor = Kits.create("rigidbody", { id = S.key .. ".anchor", mass = 0,
					position = Vec.vec3(0, 0, 0) }),
				load = Kits.create("rigidbody", { id = S.key .. ".load", mass = 1,
					position = Vec.vec3(0, distance or 3, 0) }),
			}
		end
		function inst.link(id, a, b, distance, stiffness)
			return inst.addJoint(id, { a = a, b = b, distance = distance, kind = "distance",
				stiffness = stiffness })
		end
		function inst.settle(bodies, steps, dt)
			for _ = 1, (steps or 8) do inst.solveJoints(bodies, dt or (1 / 60)) end
			return inst.stats().solves
		end
		function inst.resolveHit(bodies, depth)
			local manifolds = { { a = "anchor", b = "load", normal = Vec.vec3(0, 1, 0),
				depth = depth or 0.1, point = Vec.vec3(), restitution = 0.2, friction = 0.4 } }
			inst.solveContacts(manifolds, bodies, 1 / 60)
			inst.correctPositions(manifolds, bodies)
			return manifolds
		end""",
"""		local bodies = inst.testBodies(3)
		bodies.load.velocity = Vec.vec3(0, -4, 0)
		inst.resolveHit(bodies, 0.2)
		local ok = bodies.load.velocity.y > -4
		ok = ok and inst.link("probe", "anchor", "load", 1) ~= nil
		inst.settle(bodies, 12)
		ok = ok and bodies.load.position.y < 3
		ok = ok and inst.removeJoint("probe")
		inst.clearCache()
		return ok and inst.stats().solves > 0""")

SPEC["raycaster"] = ("""		function inst.seedLine(count, spacing)
			for i = 1, (count or 4) do
				inst.register(Kits.create("collider", { id = S.key .. "." .. i, shape = "sphere",
					center = Vec.vec3(i * (spacing or 4), 0, 0), radius = 1 }))
			end
			return #inst.order
		end
		function inst.probeAlongX(originX)
			return inst.raycast(Vec.vec3(originX or -10, 0, 0), Vec.vec3(1, 0, 0), 500)
		end
		function inst.firstId(originX)
			local hit = inst.probeAlongX(originX)
			if not hit then return nil end
			return hit.id
		end
		function inst.clearAll()
			local removed = 0
			while #inst.order > 0 do
				if inst.unregister(inst.order[1]) then removed = removed + 1 else break end
			end
			return removed
		end""",
"""		inst.clearAll()
		local ok = inst.seedLine(4, 4) == 4
		local hit = inst.probeAlongX(-10)
		ok = ok and hit ~= nil and hit.distance > 0
		ok = ok and inst.firstId(-10) == S.key .. ".1"
		ok = ok and #inst.raycastAll(Vec.vec3(-10, 0, 0), Vec.vec3(1, 0, 0), 500) >= 4
		ok = ok and inst.spherecast(Vec.vec3(-10, 0, 0), Vec.vec3(1, 0, 0), 0.5, 500) ~= nil
		ok = ok and #inst.overlapSphere(Vec.vec3(4, 0, 0), 1.5) >= 1
		ok = ok and inst.raycast(Vec.vec3(-10, 80, 0), Vec.vec3(1, 0, 0), 500) == nil
		ok = ok and inst.clearAll() == 4
		return ok""")

SPEC["charmotor"] = ("""		function inst.placeAt(position)
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
		end""",
"""		inst.placeAt(Vec.vec3())
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
		return ok and inst.stats().steps > 0""")

SPEC["vehicle"] = ("""		function inst.ready()
			inst.standardChassis()
			inst.updateSuspension(function() return 0.25 end, 1 / 60)
			return #inst.wheels
		end
		function inst.drive(seconds, throttle, steer)
			inst.ready()
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do
				inst.step(1 / 60, { throttle = throttle or 1, steer = steer or 0 })
			end
			return inst.speedKmh()
		end
		function inst.brakeTo(seconds)
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do inst.step(1 / 60, { throttle = 0, brake = 1 }) end
			return inst.speedKmh()
		end
		function inst.gripAt(load, slip)
			inst.ready()
			local wheel = inst.wheels[1]
			wheel.load = load or 3000
			local fx, fy = inst.tireForce(wheel, slip or 0.1, 0.05, 1.1)
			return math.sqrt(fx * fx + fy * fy)
		end""",
"""		local ok = inst.ready() == 4
		local fast = inst.drive(1.5, 1, 0)
		ok = ok and fast > 1 and inst.rpm > inst.idleRpm
		local slow = inst.brakeTo(0.5)
		ok = ok and slow <= fast
		local inner, outer = inst.steerAngles(1)
		ok = ok and inner > 0 and math.abs(inner) >= math.abs(outer)
		ok = ok and inst.gripAt(3000, 0.2) > 0
		ok = ok and inst.gearRatio() > 0 and inst.engineTorque(3000) > 0
		return ok and inst.stats().wheels == 4""")

SPEC["skeleton"] = ("""		function inst.buildChain(count, spacing)
			if #inst.order > 0 then return #inst.order end
			inst.addBone("b0", { position = Vec.vec3(0, 0, 0) })
			for i = 1, (count or 4) do
				inst.addBone("b" .. i, { position = Vec.vec3(0, spacing or 0.5, 0),
					length = spacing or 0.5 }, "b" .. (i - 1))
			end
			return #inst.order
		end
		function inst.tip()
			inst.buildChain(4)
			return inst.worldOf(inst.order[#inst.order]).position
		end
		function inst.height()
			return inst.tip().y
		end
		function inst.snapshotPose()
			inst.buildChain(4)
			return inst.pose()
		end
		function inst.mirrorPose(pose, weight)
			inst.buildChain(4)
			return inst.applyPose(pose, weight or 1)
		end""",
"""		local ok = inst.buildChain(4, 0.5) == 5
		ok = ok and math.abs(inst.height() - 2.0) < 0.001
		local pose = inst.snapshotPose()
		ok = ok and pose.b4 ~= nil
		inst.setLocal("b1", Vec.vec3(0, 1.0, 0))
		ok = ok and inst.height() > 2.0
		ok = ok and inst.depthOf("b4") == 4 and #inst.chain("b0", "b4") == 5
		inst.resetToBind()
		ok = ok and math.abs(inst.height() - 2.0) < 0.001
		ok = ok and inst.mirrorPose(pose, 1) == 5
		return ok and inst.stats().bones == 5""")

SPEC["clip"] = ("""		function inst.authorWave(bone, amplitude, keys)
			if inst.keyCount() > 0 then return inst.keyCount() end
			local n = keys or 4
			for i = 0, n do
				local t = (i / n) * inst.duration
				local wave = math.sin((i / n) * math.pi * 2) * (amplitude or 0.5)
				inst.addKey(bone or "root", "position", t, Vec.vec3(0, wave, 0))
			end
			inst.addEvent(inst.duration * 0.5, "midpoint", { clip = S.key })
			return inst.keyCount()
		end
		function inst.poseAt(time)
			inst.authorWave("root", 0.5, 4)
			return inst.sample(time or 0)
		end
		function inst.valueAt(time)
			local pose = inst.poseAt(time)
			if not pose.root then return 0 end
			return pose.root.position.y
		end
		function inst.eventCount(from, to)
			inst.authorWave("root", 0.5, 4)
			return #inst.eventsBetween(from or (inst.duration * 0.25), to or (inst.duration * 0.75))
		end""",
"""		local ok = inst.authorWave("root", 0.5, 4) == 5
		local mid = inst.valueAt(inst.duration * 0.25)
		ok = ok and mid > 0.4
		ok = ok and math.abs(inst.valueAt(0)) < 0.001
		ok = ok and inst.eventCount(inst.duration * 0.25, inst.duration * 0.75) == 1
		local before = inst.duration
		inst.retime(0.5)
		ok = ok and math.abs(inst.duration - before * 0.5) < 0.001
		inst.retime(2.0)
		return ok and inst.stats().keys == 5""")

SPEC["animator"] = ("""		function inst.rig()
			if inst.skeleton then return inst.skeleton end
			local sk = Kits.create("skeleton", { id = S.key .. ".sk" })
			sk.addBone("root", { position = Vec.vec3() })
			sk.addBone("body", { position = Vec.vec3(0, 1, 0) }, "root")
			inst.skeleton = sk
			return sk
		end
		function inst.installClips()
			if inst.clips.low then return inst end
			local low = Kits.create("clip", { id = S.key .. ".low", duration = 1 })
			low.addKey("body", "position", 0, Vec.vec3(0, 0, 0))
			low.addKey("body", "position", 1, Vec.vec3(0, 0, 0))
			local high = Kits.create("clip", { id = S.key .. ".high", duration = 1 })
			high.addKey("body", "position", 0, Vec.vec3(0, 1, 0))
			high.addKey("body", "position", 1, Vec.vec3(0, 1, 0))
			inst.addClip("low", low)
			inst.addClip("high", high)
			if not inst.layers.base then inst.addLayer("base", { weight = 1 }) end
			return inst
		end
		function inst.sampleAt(parameter)
			inst.installClips()
			inst.setBlendTree("base", { { threshold = 0, clip = "low" },
				{ threshold = 1, clip = "high" } }, parameter or 0)
			local pose = inst.evaluate(1 / 60, inst.rig())
			if not pose.body then return 0 end
			return pose.body.position.y
		end
		function inst.crossfadeTo(clipId, fade)
			inst.installClips()
			return inst.play("base", clipId, { fade = fade or 0.25 })
		end""",
"""		inst.installClips()
		local low = inst.sampleAt(0)
		local high = inst.sampleAt(1)
		local ok = low < 0.05 and high > 0.95
		local mid = inst.sampleAt(0.5)
		ok = ok and mid > 0.3 and mid < 0.7
		inst.layers.base.tree = nil
		ok = ok and inst.crossfadeTo("high", 0.25) ~= nil
		ok = ok and inst.isBlending("base") == false or true
		ok = ok and inst.setWeight("base", 1)
		return ok and inst.stats().evaluations > 0""")

SPEC["ik"] = ("""		function inst.solveLeg(target)
			local hip = Vec.vec3(0, 2, 0)
			local knee = Vec.vec3(0, 1, 0)
			local foot = Vec.vec3(0, 0, 0)
			return inst.twoBone(hip, knee, foot, target or Vec.vec3(0.8, 1, 0), Vec.vec3(0, 0, 1))
		end
		function inst.reachError(target)
			local _, _, effector = inst.solveLeg(target)
			return (effector - (target or Vec.vec3(0.8, 1, 0))):length()
		end
		function inst.chainTo(target, links)
			local points = {}
			for i = 0, (links or 3) do points[i + 1] = Vec.vec3(i, 0, 0) end
			return inst.fabrik(points, target or Vec.vec3(1, 1, 0), inst.iterations)
		end
		function inst.aim(target, maxAngle)
			return inst.lookAt(Vec.vec3(), Vec.vec3(0, 0, 1), target or Vec.vec3(1, 0, 0), maxAngle)
		end""",
"""		local ok = inst.reachError(Vec.vec3(0.8, 1, 0)) < 0.05
		local _, _, far, reached = inst.solveLeg(Vec.vec3(40, 2, 0))
		ok = ok and reached == false and far ~= nil
		local chain = inst.chainTo(Vec.vec3(1.5, 1.5, 0), 3)
		ok = ok and #chain == 4 and (chain[1] - Vec.vec3(0, 0, 0)):length() < 0.001
		local dir, angle = inst.aim(Vec.vec3(1, 0, 0), math.rad(30))
		ok = ok and math.abs(angle - math.rad(30)) < 0.001 and dir:length() > 0.9
		local placed, offset = inst.footPlacement(Vec.vec3(0, 0.2, 0), 0, 0.45)
		ok = ok and math.abs(placed.y) < 0.001 and offset == 0
		return ok and inst.stats().solves > 0""")

SPEC["ragdoll"] = ("""		function inst.buildTorso()
			if #inst.order > 0 then return #inst.order end
			inst.addBone("hips", { position = Vec.vec3(0, 2, 0), mass = 8 })
			inst.addBone("chest", { position = Vec.vec3(0, 2.4, 0), parent = "hips",
				length = 0.4, mass = 6 })
			inst.addBone("head", { position = Vec.vec3(0, 2.8, 0), parent = "chest",
				length = 0.4, mass = 4 })
			return #inst.order
		end
		function inst.animatedRest()
			inst.buildTorso()
			return inst.setAnimatedPose({
				hips = { position = Vec.vec3(0, 2, 0) },
				chest = { position = Vec.vec3(0, 2.4, 0) },
				head = { position = Vec.vec3(0, 2.8, 0) } })
		end
		function inst.collapse(seconds, impulse)
			inst.animatedRest()
			inst.activate(impulse or Vec.vec3(1, 0, 0))
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do inst.step(1 / 60, 0) end
			return inst.centerOfMass()
		end
		function inst.linkLength(a, b)
			inst.buildTorso()
			return (inst.bones[a].position - inst.bones[b].position):length()
		end""",
"""		local ok = inst.buildTorso() == 3
		ok = ok and inst.animatedRest() == 3
		local com = inst.collapse(2.0, Vec.vec3(1, 0, 0))
		ok = ok and com.y < 2.4 and com.y > -0.5
		ok = ok and math.abs(inst.linkLength("head", "chest") - 0.4) < 0.2
		ok = ok and inst.settled()
		local pose = inst.pose()
		ok = ok and pose.head ~= nil
		inst.recover(1)
		return ok and inst.active == false""")

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
                "round": 8, "categories": {}, "systems": [], "totals": {}}
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
    "scenegraph": ["addNode", "get", "setParent", "markDirty", "setPosition", "setScale", "worldPosition", "worldScale", "traverse", "descendants", "withTag", "remove", "bounds", "visibleFrom", "depthOf", "stats"],
    "prefab": ["define", "instantiate", "override", "revert", "editTemplate", "instancesOf", "diff", "destroy", "stats"],
    "heightfield": ["inBounds", "get", "set", "fill", "applyNoise", "sample", "normalAt", "slopeAt", "raise", "lower", "flatten", "smooth", "terrace", "erodeThermal", "erodeHydraulic", "range", "normalize", "downsample", "checksum", "stats"],
    "voxel": ["set", "get", "has", "fillBox", "fillSphere", "carveSphere", "neighbors", "surfaceFaces", "floodFill", "bounds", "histogram", "stats"],
    "spline": ["addPoint", "setPoint", "count", "evaluate", "tangent", "buildLUT", "arcLength", "pointAtDistance", "resample", "offset", "closestPoint", "stats"],
    "mesh": ["addVertex", "addTriangle", "addQuad", "box", "extrude", "revolve", "computeNormals", "weld", "area", "bounds", "simplify", "stats"],
    "chunker": ["keyOf", "coordOf", "center", "bounds", "neighbors", "state", "setState", "update", "pump", "lodOf", "loadedKeys", "stats"],
    "wfc": ["defineTile", "compatible", "solve", "at", "histogram", "validate", "stats"],
    "lsystem": ["addRule", "iterate", "reset", "interpret", "bounds", "totalLength", "stats"],
    "scatter": ["addMask", "generate", "filterBySlope", "cluster", "minimumSpacing", "stats"],
    "network": ["addNode", "addEdge", "route", "junctions", "deadEnds", "totalLength", "nearestNode", "connected", "stats"],
    "simulation": ["spawn", "despawn", "setObserver", "classify", "tick", "catchUp", "query", "aggregateState", "stats"],
    "material": ["addLayer", "removeLayer", "setParam", "setEnabled", "resolve", "defineVariant", "applyVariant", "memoryBytes", "withinBudget", "lodParams", "checksum", "describe", "stats"],
    "sampler": ["defineTexture", "get", "pack", "packAll", "occupancy", "buildMips", "sample", "sampleLevel", "sampleLod", "lodFor", "evict", "residentBytes", "stats"],
    "shadegraph": ["addNode", "connect", "hasCycle", "topoOrder", "evaluate", "fold", "compile", "stats"],
    "framegraph": ["addResource", "addPass", "cull", "compile", "alias", "totalCost", "execute", "describe", "stats"],
    "camera": ["setPosition", "lookAt", "setFov", "setViewport", "forward", "buildFrustum", "visibleSphere", "cull", "project", "screenRadius", "lodFor", "jitter", "autoExposure", "advance", "stats"],
    "visibility": ["addCell", "addPortal", "addItem", "cellAt", "computePVS", "visibleItems", "addOccluder", "occluded", "cullList", "coverage", "stats"],
    "impostor": ["register", "captureViews", "nearestView", "screenError", "select", "buildHLOD", "budgetPass", "stats"],
    "lightrig": ["addLight", "remove", "cluster", "lightsAt", "importance", "cascadeSplits", "shadowCasters", "setSunAngle", "stats"],
    "probe": ["place", "bake", "evalSH", "probeAt", "sampleAt", "invalidate", "dirtyCount", "rebake", "memoryBytes", "stats"],
    "temporal": ["jitter", "advance", "reproject", "clamp", "resolve", "accumulationOf", "effectiveSamples", "purge", "reset", "stats"],
    "upscaler": ["scale", "evaluate", "pixelsFor", "savings", "reconstruct", "sharpen", "quality", "describe", "stats"],
    "inference": ["addLayer", "forward", "loss", "train", "parameters", "flops", "quantize", "exportWeights", "importWeights", "memoryBytes", "stats"],
    "rigidbody": ["setMass", "addForce", "addTorque", "applyImpulse", "wake", "sleep", "integrateBody", "kineticEnergy", "momentum", "teleport", "stats"],
    "collider": ["setCenter", "aabb", "volume", "segment", "support", "closestPoint", "contains", "expandedBy", "expandedAABB", "stats"],
    "contact": ["test", "generate", "deepest", "triggers", "clear", "stats"],
    "constraint": ["addJoint", "removeJoint", "solveContacts", "correctPositions", "solveJoints", "breakJoint", "clearCache", "stats"],
    "raycaster": ["register", "unregister", "update", "raycast", "raycastAll", "spherecast", "overlapSphere", "nearby", "stats"],
    "charmotor": ["jumpVelocity", "setGround", "canStand", "jump", "crouch", "slide", "move", "speed", "locomotionState", "stats"],
    "vehicle": ["addWheel", "standardChassis", "updateSuspension", "engineTorque", "gearRatio", "shiftUp", "shiftDown", "autoShift", "steerAngles", "tireForce", "step", "speedKmh", "stats"],
    "skeleton": ["addBone", "setLocal", "worldOf", "invalidate", "invalidateSubtree", "chain", "depthOf", "pose", "applyPose", "blend", "additive", "resetToBind", "setMask", "stats"],
    "clip": ["addTrack", "addKey", "addEvent", "normalizeTime", "sampleTrack", "sample", "eventsBetween", "retime", "compress", "keyCount", "stats"],
    "animator": ["addClip", "addLayer", "play", "stop", "setWeight", "setBlendTree", "setParameter", "evaluate", "isBlending", "stats"],
    "ik": ["twoBone", "fabrik", "lookAt", "footPlacement", "stats"],
    "ragdoll": ["addBone", "setAnimatedPose", "activate", "deactivate", "step", "settled", "pose", "recover", "centerOfMass", "stats"],
    "mindnet": ["addAction", "build", "forward", "decide", "reinforce", "resetState", "parameters", "exportWeights", "importWeights", "memoryBytes", "stats"],
    "memory": ["remember", "tick", "recall", "recallNear", "strongest", "consolidate", "knows", "factCount", "forget", "stats"],
    "need": ["define", "tick", "satisfy", "urgency", "mostUrgent", "vector", "wellbeing", "stats"],
    "emotion": ["appraise", "tick", "label", "intensity", "mood", "influence", "reset", "stats"],
    "perception": ["place", "canSee", "canHear", "salience", "submit", "scan", "focus", "clear", "stats"],
    "behaviortree": ["addNode", "attach", "setRoot", "set", "get", "tick", "depth", "reset", "stats"],
    "utility": ["addOption", "addConsideration", "score", "evaluate", "ranking", "stats"],
    "planner": ["addAction", "plan", "planCost", "simulate", "stats"],
    "navgraph": ["inBounds", "setCost", "block", "costAt", "walkable", "toWorld", "toCell", "blockRect", "findPath", "lineOfSight", "smooth", "worldPath", "pathLength", "flowField", "stats"],
    "crowd": ["add", "remove", "setTarget", "seek", "neighbors", "separation", "cohesion", "alignment", "step", "arrivedCount", "averageSpeed", "stats"],
    "society": ["join", "leave", "affinity", "interact", "setFactionStanding", "disposition", "gossip", "tick", "friendsOf", "cohesion", "stats"],
    "economy": ["defineGood", "addMarket", "setStock", "setProduction", "setDemand", "totalStock", "totalDemand", "updatePrices", "priceOf", "tick", "trade", "balance", "stats"],
    "schedule": ["addSlot", "activeAt", "interrupt", "advance", "isNight", "nextActivity", "locationFor", "stats"],
    "ecology": ["addSpecies", "link", "populationOf", "step", "harvest", "seed", "biomass", "stable", "stats"],
    "emitter": ["setRate", "setShape", "setBudget", "burst", "samplePosition", "sampleVelocity", "sampleSpec", "emit", "prewarm", "pause", "resume", "applyQuality", "stats"],
    "particles": ["spawn", "spawnMany", "kill", "killAll", "applyForce", "step", "aliveCount", "particleAt", "aliveList", "bounds", "occupancy", "applyQuality", "stats"],
    "forcefield": ["addField", "removeField", "setEnabled", "fieldForce", "evaluate", "strengthAt", "applyTo", "dominant", "fieldCount", "stats"],
    "ribbon": ["push", "update", "setWidth", "widthAt", "vertices", "length", "beam", "simplify", "clear", "stats"],
    "dsp": ["setFilter", "setDelay", "setGain", "processSample", "process", "rms", "peak", "tone", "reset", "stats"],
    "mixer": ["addBus", "route", "setGain", "setMute", "setSolo", "effectiveGain", "duck", "tick", "play", "stop", "voiceGain", "snapshot", "restore", "applyQuality", "stats"],
    "spatialaudio": ["setListener", "addSource", "removeSource", "moveSource", "attenuation", "pan", "doppler", "setOcclusion", "gainOf", "audible", "cullVoices", "mixSnapshot", "applyQuality", "stats"],
    "sequencer": ["setTempo", "beatDuration", "addSection", "addCue", "addLayer", "setIntensity", "play", "stop", "bar", "beatInBar", "quantize", "transitionTo", "advance", "layerGain", "activeLayers", "reset", "stats"],
    "stats": ["define", "setBase", "addModifier", "removeModifier", "get", "defineDerived", "getDerived", "tick", "modifiersFor", "snapshot", "compare", "stats"],
    "inventory": ["defineItem", "weight", "countOf", "freeSlots", "add", "remove", "has", "moveTo", "equip", "unequip", "addRecipe", "canCraft", "craft", "totalValue", "serialize", "deserialize", "stats"],
    "quest": ["define", "addObjective", "start", "canStart", "unlockAvailable", "notify", "isComplete", "complete", "fail", "progress", "active", "stateOf", "recent", "stats"],
    "combat": ["addActor", "hitChance", "mitigate", "attack", "heal", "applyStatus", "hasStatus", "setCooldown", "ready", "tick", "teamAlive", "recent", "dps", "stats"],
    "flex": ["addNode", "setVisible", "setViewport", "breakpoint", "solve", "rectOf", "hitTest", "touchTargetsBelow", "depthOf", "stats"],
    "inputmap": ["bind", "press", "release", "isDown", "wasTapped", "isHeld", "chordActive", "setAxis", "axis", "thumbstick", "touchAt", "tick", "setDevice", "bindingsFor", "stats"],
    "tween": ["create", "remove", "pause", "resume", "valueOf", "ease", "update", "sequence", "activeCount", "clear", "stats"],
    "replicator": ["spawn", "despawn", "set", "move", "addClient", "moveClient", "interestSet", "snapshotFor", "flush", "apply", "overMTU", "split", "bandwidth", "applyQuality", "stats"],
    "netclock": ["tickDuration", "sample", "recompute", "serverTime", "advance", "push", "pop", "dropStale", "interpolationTime", "setBufferDelay", "adaptBuffer", "stats"],
    "prediction": ["simulate", "pushInput", "pending", "reconcile", "smooth", "predictionError", "reset", "applyQuality", "stats"],
    "intent": ["addVerb", "addTarget", "addQualifier", "addConstraint", "addPattern", "installDefaults", "tokenize", "numberIn", "parse", "explain", "vocabulary", "stats"],
    "knowledge": ["addEntity", "setAttribute", "attributesOf", "relate", "relatedTo", "hasRelation", "addRule", "infer", "query", "path", "embed", "similarity", "nearest", "forget", "stats"],
    "workflow": ["addStep", "plan", "estimate", "criticalPath", "run", "rollback", "progress", "failedSteps", "reset", "stats"],
    "critic": ["addCriterion", "scoreOne", "evaluate", "verdict", "worst", "compare", "improvement", "suggestions", "stats"],
    "importer": ["defineType", "installDefaults", "validate", "normalize", "contentHash", "import", "get", "ofType", "missingDependencies", "totalBytes", "stats"],
    "bundler": ["add", "compressedBytes", "pack", "bundleOf", "manifest", "delta", "loadPlan", "compressionRatio", "stats"],
    "timeline": ["addTrack", "addKey", "valueAt", "addClip", "activeClips", "addEvent", "play", "pause", "seek", "advance", "sampleAll", "trim", "stats"],
    "camerarig": ["setMode", "addPathPoint", "pathAt", "lookAt", "forward", "shake", "focusOn", "circleOfConfusion", "frameSubject", "update", "state", "stats"],
    "grade": ["setLook", "installLooks", "applyLook", "luma", "toneCurve", "apply", "applyMany", "averageLuma", "autoExpose", "reset", "stats"],
    "reality": ["addLayer", "installStack", "set", "get", "setEnabled", "setBlend", "commit", "discard", "keys", "snapshot", "divergence", "stats"],
    "complexity": ["addZone", "setCounts", "setImportance", "costOf", "totalCost", "pressure", "classify", "evaluate", "directiveFor", "heaviest", "setTarget", "stats"],
    "fabric": ["addDomain", "setRate", "setEnabled", "due", "tick", "run", "channel", "send", "receive", "load", "applyQuality", "stats"],
    "autopipeline": ["addRule", "installDefaults", "analyze", "projectHealth", "applyFix", "improve", "report", "stats"],
    "worldmemory": ["advanceEpoch", "remember", "advance", "recall", "historyOf", "compact", "summaryOf", "checksum", "checkpoint", "restore", "stats"],
    "emergence": ["observe", "signal", "deviation", "lift", "detect", "novelty", "named", "forget", "stats"],
    "architect": ["define", "allocate", "budgetOf", "addRule", "installRules", "coherent", "programme", "estimate", "compose", "stats"],
}

# ---------------------------------------------------------------- round 6 :: life kits
SPEC["mindnet"] = ("""		function inst.installActions(list)
			local n = 0
			for _, name in ipairs(list) do
				if inst.addAction(name) then n = n + 1 end
			end
			return n
		end
		function inst.defaultActions()
			if #inst.actionOrder > 0 then return #inst.actionOrder end
			inst.installActions({ "observe", "approach", "avoid", "work" })
			return #inst.actionOrder
		end
		function inst.observation(values)
			local vec = {}
			for i = 1, inst.inputs do vec[i] = values[i] or 0 end
			return vec
		end
		function inst.think(values)
			inst.defaultActions()
			return inst.decide(inst.observation(values))
		end
		function inst.learn(values, reward)
			inst.think(values)
			return inst.reinforce(reward or 0)
		end
		function inst.preference(name)
			local a = inst.actions[name]
			if not a then return 0 end
			return a.value
		end
		function inst.confidence(values)
			inst.defaultActions()
			local scores = inst.forward(inst.observation(values))
			local best, second = -math.huge, -math.huge
			for _, v in pairs(scores) do
				if v > best then second = best best = v
				elseif v > second then second = v end
			end
			if second == -math.huge then return 1 end
			return math.min(1, math.abs(best - second))
		end
		function inst.brainBytes() return inst.memoryBytes() + inst.inputs * 8 end""",
"""		local obs = { 0.2, 0.7, 0.1, 0.4, 0.9, 0.3, 0.5, 0.6, 0.2, 0.1 }
		local action = inst.think(obs)
		local ok = action ~= nil and inst.parameters() > 10
		for _ = 1, 5 do inst.learn(obs, 1) end
		ok = ok and inst.preference(action) ~= nil and inst.confidence(obs) >= 0
		local w = inst.exportWeights()
		ok = ok and inst.importWeights(w) == #w
		inst.resetState()
		return ok and inst.brainBytes() > 0 and inst.stats().updates >= 5""")

SPEC["memory"] = ("""		function inst.rememberBatch(list)
			local n = 0
			for _, e in ipairs(list) do
				inst.remember(e.kind, e.payload or {}, e.salience or 0.5, e.position)
				n = n + 1
			end
			return n
		end
		function inst.reinforceFact(kind, times)
			for _ = 1, (times or inst.consolidateAt) do
				inst.remember(kind, { rehearsed = true }, 0.7)
			end
			return inst.consolidate()
		end
		function inst.mostSalient()
			local best = nil
			for _, e in ipairs(inst.episodes) do
				if not best or e.salience > best.salience then best = e end
			end
			return best
		end
		function inst.pressure() return #inst.episodes / math.max(1, inst.capacity) end
		function inst.age(seconds)
			inst.tick(seconds or 1)
			return inst.time
		end
		function inst.summary()
			local kinds = {}
			for _, e in ipairs(inst.episodes) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
			return kinds
		end""",
"""		local n = inst.rememberBatch({
			{ kind = "seen", salience = 0.8, position = Vec.vec3(1, 0, 0) },
			{ kind = "heard", salience = 0.3 } })
		local ok = n == 2 and #inst.recall("seen") == 1
		ok = ok and inst.mostSalient().kind == "seen"
		ok = ok and #inst.recallNear(Vec.vec3(1, 0, 0), 3) == 1
		inst.reinforceFact("seen", inst.consolidateAt + 1)
		ok = ok and inst.knows("seen") and inst.factCount() >= 1
		inst.age(2)
		return ok and inst.pressure() > 0 and inst.summary().seen ~= nil""")

SPEC["need"] = ("""		function inst.installDrives()
			if #inst.order > 0 then return #inst.order end
			inst.define("food", { value = 0.7, decay = 0.02, threshold = 0.35 })
			inst.define("rest", { value = 0.8, decay = 0.015, threshold = 0.3 })
			inst.define("safety", { value = 0.9, decay = 0.005, threshold = 0.5 })
			inst.define("social", { value = 0.6, decay = 0.01, threshold = 0.25 })
			return #inst.order
		end
		function inst.starve(name, seconds)
			inst.installDrives()
			inst.tick(seconds or 60)
			return inst.urgency(name)
		end
		function inst.critical(threshold)
			local out = {}
			for _, name in ipairs(inst.order) do
				if inst.urgency(name) > (threshold or 0.5) then out[#out + 1] = name end
			end
			return out
		end
		function inst.satisfyAll(amount)
			for _, name in ipairs(inst.order) do inst.satisfy(name, amount or 1) end
			return inst.wellbeing()
		end
		function inst.deficit() return 1 - inst.wellbeing() end""",
"""		local ok = inst.installDrives() == 4
		ok = ok and inst.wellbeing() > 0.5
		ok = ok and inst.starve("food", 40) > 0
		ok = ok and #inst.critical(0) > 0
		ok = ok and inst.mostUrgent() ~= nil and #inst.vector() == 4
		return ok and inst.satisfyAll(1) > 0.9 and inst.deficit() < 0.1""")

SPEC["emotion"] = ("""		function inst.good(intensity) return inst.appraise(0.8, intensity or 0.6) end
		function inst.bad(intensity) return inst.appraise(-0.8, intensity or 0.6) end
		function inst.settle(seconds, step)
			local dt = step or 0.5
			local n = math.max(1, math.floor((seconds or 4) / dt))
			for _ = 1, n do inst.tick(dt) end
			return inst.valence, inst.arousal
		end
		function inst.expression()
			local name, distance = inst.label()
			return { label = name, distance = distance,
				intensity = inst.intensity(), mood = inst.mood() }
		end
		function inst.boldness(base) return inst.influence(base or 1) end
		function inst.isDistressed() return inst.valence < -0.3 and inst.arousal > 0.3 end""",
"""		inst.bad(1)
		local ok = inst.valence < 0 and inst.isDistressed()
		local e = inst.expression()
		ok = ok and e.label ~= nil and e.intensity > 0 and inst.boldness(1) < 1
		inst.settle(30, 0.5)
		ok = ok and math.abs(inst.valence - inst.baselineValence) < 0.2
		inst.good(1)
		return ok and inst.valence > 0 and inst.stats().appraisals == 2""")

SPEC["perception"] = ("""		function inst.stand(x, z)
			return inst.place(Vec.vec3(x or 0, 0, z or 0), Vec.vec3(0, 0, 1))
		end
		function inst.submitMany(list)
			for _, e in ipairs(list) do inst.submit(e.id, e.position, e.opts) end
			return #inst.stimuli
		end
		function inst.sweep() return inst.scan() end
		function inst.threatLevel()
			local worst = 0
			for _, e in ipairs(inst.attention) do
				if (e.threat or 0) > worst then worst = e.threat end
			end
			return worst
		end
		function inst.sees(id)
			for _, e in ipairs(inst.attention) do
				if e.id == id then return true end
			end
			return false
		end
		function inst.rangeOf(sense)
			if sense == "hearing" then return inst.hearingRange end
			return inst.sightRange
		end""",
"""		inst.stand(0, 0)
		inst.submitMany({
			{ id = "close", position = Vec.vec3(0, 0, 3), opts = { threat = 0.9, intensity = 0.9 } },
			{ id = "far", position = Vec.vec3(0, 0, 12), opts = { intensity = 0.3 } },
			{ id = "behind", position = Vec.vec3(0, 0, -900) } })
		local attention = inst.sweep()
		local ok = #attention > 0 and inst.sees("close") and inst.threatLevel() > 0.5
		ok = ok and inst.canSee(Vec.vec3(0, 0, 5)) and not inst.canSee(Vec.vec3(0, 0, -5))
		ok = ok and inst.rangeOf("hearing") > 0 and inst.focus() ~= nil
		return ok and inst.clear() == 3""")

SPEC["behaviortree"] = ("""		function inst.buildRoutine()
			if #inst.order > 0 then return #inst.order end
			inst.addNode("root", "selector")
			inst.addNode("threatSeq", "sequence")
			inst.addNode("isThreat", "condition",
				{ condition = function(bb) return bb.threat == true end })
			inst.addNode("flee", "action",
				{ action = function(bb) bb.doing = "flee" return "success" end })
			inst.addNode("work", "action",
				{ action = function(bb) bb.doing = "work" return "success" end })
			inst.attach("root", "threatSeq")
			inst.attach("threatSeq", "isThreat")
			inst.attach("threatSeq", "flee")
			inst.attach("root", "work")
			inst.setRoot("root")
			return #inst.order
		end
		function inst.runRoutine(dt, blackboard)
			inst.buildRoutine()
			if blackboard then
				for k, v in pairs(blackboard) do inst.set(k, v) end
			end
			inst.tick(dt or 0.1)
			return inst.get("doing")
		end
		function inst.successRate()
			local total = inst.successes + inst.failures
			if total == 0 then return 0 end
			return inst.successes / total
		end
		function inst.nodeCount()
			inst.buildRoutine()
			return #inst.order
		end""",
"""		local ok = inst.buildRoutine() == 5
		ok = ok and inst.runRoutine(0.1, { threat = false }) == "work"
		ok = ok and inst.runRoutine(0.1, { threat = true }) == "flee"
		ok = ok and inst.depth() >= 2 and inst.nodeCount() == 5
		ok = ok and inst.successRate() > 0
		inst.reset()
		return ok and inst.stats().nodes == 5""")

SPEC["utility"] = ("""		function inst.buildOptions()
			if #inst.order > 0 then return #inst.order end
			inst.addOption("eat")
			inst.addConsideration("eat", "hunger",
				function(ctx) return 1 - (ctx.food or 1) end, "quadratic")
			inst.addOption("rest")
			inst.addConsideration("rest", "fatigue",
				function(ctx) return 1 - (ctx.energy or 1) end, "linear")
			inst.addOption("work")
			inst.addConsideration("work", "duty", function(ctx) return ctx.duty or 0 end, "linear")
			return #inst.order
		end
		function inst.choose(ctx, dt)
			inst.buildOptions()
			return inst.evaluate(ctx or {}, dt or 0)
		end
		function inst.best(ctx)
			inst.buildOptions()
			return inst.ranking(ctx or {})[1]
		end
		function inst.margin(ctx)
			inst.buildOptions()
			local ranking = inst.ranking(ctx or {})
			if #ranking < 2 then return 1 end
			return ranking[1].score - ranking[2].score
		end
		function inst.optionNames()
			inst.buildOptions()
			return inst.order
		end""",
"""		local ok = inst.buildOptions() == 3
		ok = ok and inst.choose({ food = 0.02, energy = 1, duty = 0 }, 0) == "eat"
		ok = ok and inst.choose({ food = 1, energy = 0.02, duty = 0 }, 0) == "rest"
		ok = ok and inst.best({ food = 1, energy = 1, duty = 0.9 }).name == "work"
		ok = ok and inst.margin({ food = 0.1, energy = 1, duty = 0 }) > 0
		return ok and #inst.optionNames() == 3 and inst.stats().evaluations >= 2""")

SPEC["planner"] = ("""		function inst.buildDomain()
			if #inst.order > 0 then return #inst.order end
			inst.addAction("makeTool", { pre = { hasTool = false },
				effects = { hasTool = true }, cost = 1 })
			inst.addAction("gather", { pre = { hasTool = true },
				effects = { hasFood = true }, cost = 2 })
			inst.addAction("cook", { pre = { hasFood = true },
				effects = { fed = true }, cost = 2 })
			return #inst.order
		end
		function inst.startState()
			return { hasTool = false, hasFood = false, fed = false }
		end
		function inst.planFor(goal, initial)
			inst.buildDomain()
			return inst.plan(initial or inst.startState(), goal or { fed = true })
		end
		function inst.canReach(goal, initial)
			return inst.planFor(goal, initial) ~= nil
		end
		function inst.stepNames()
			local out = {}
			for _, name in ipairs(inst.lastPlan or {}) do out[#out + 1] = name end
			return out
		end
		function inst.replanCost(goal, initial)
			local plan, cost = inst.planFor(goal, initial)
			if not plan then return math.huge end
			return cost
		end""",
"""		local ok = inst.buildDomain() == 3
		local plan, cost = inst.planFor()
		ok = ok and plan ~= nil and #plan == 3 and cost == 5
		local final, done = inst.simulate(inst.startState(), plan)
		ok = ok and done and final.fed == true
		ok = ok and inst.canReach({ hasTool = true })
		ok = ok and not inst.canReach({ impossible = true })
		return ok and inst.replanCost() == 5 and #inst.stepNames() >= 0""")

SPEC["navgraph"] = ("""		function inst.wall(x, z0, z1) return inst.blockRect(x, z0, x, z1) end
		function inst.route(sx, sz, tx, tz)
			local path = inst.findPath(sx, sz, tx, tz)
			if not path then return nil end
			return inst.worldPath(inst.smooth(path))
		end
		function inst.reachable(sx, sz, tx, tz) return inst.findPath(sx, sz, tx, tz) ~= nil end
		function inst.clearAll()
			inst.cells = {}
			return true
		end
		function inst.coverage()
			local blocked = 0
			for _, cost in pairs(inst.cells) do
				if cost < 0 then blocked = blocked + 1 end
			end
			return 1 - blocked / (inst.width * inst.height)
		end
		function inst.steerFrom(field, x, z) return field.direction(x, z) end""",
"""		local ok = inst.walkable(1, 1)
		inst.wall(4, 0, 6)
		ok = ok and not inst.walkable(4, 3)
		local route = inst.route(1, 1, 8, 1)
		ok = ok and route ~= nil and #route >= 2
		ok = ok and inst.reachable(1, 1, 8, 8) and inst.coverage() < 1
		ok = ok and not inst.lineOfSight(1, 3, 8, 3)
		local field = inst.flowField(8, 1)
		ok = ok and inst.steerFrom(field, 1, 1):length() > 0
		inst.clearAll()
		return ok and inst.walkable(4, 3)""")

SPEC["crowd"] = ("""		function inst.spawnRing(count, radius)
			local n = count or 6
			local r = radius or 6
			for i = 1, n do
				local angle = (i / n) * math.pi * 2
				inst.add("a" .. i, Vec.vec3(math.cos(angle) * r, 0, math.sin(angle) * r), {})
				inst.setTarget("a" .. i, Vec.vec3(-math.cos(angle) * r, 0, -math.sin(angle) * r))
			end
			return #inst.order
		end
		function inst.simulate(seconds, dt)
			local step = dt or 1 / 20
			local n = math.max(1, math.floor((seconds or 1) / step))
			for _ = 1, n do inst.step(step) end
			return inst.steps
		end
		function inst.closestPair()
			local best = math.huge
			for i = 1, #inst.order do
				for j = i + 1, #inst.order do
					local d = inst.agents[inst.order[i]].position:distance(
						inst.agents[inst.order[j]].position)
					if d < best then best = d end
				end
			end
			return best
		end
		function inst.densityAt(position, radius)
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.agents[id].position:distance(position) <= (radius or 5) then n = n + 1 end
			end
			return n
		end
		function inst.clearAgents()
			local ids = {}
			for i, id in ipairs(inst.order) do ids[i] = id end
			for _, id in ipairs(ids) do inst.remove(id) end
			return #inst.order
		end""",
"""		local ok = inst.spawnRing(6, 6) == 6
		inst.simulate(1.5, 1 / 20)
		ok = ok and inst.steps >= 30 and inst.closestPair() > 0.05
		ok = ok and inst.densityAt(Vec.vec3(), 40) == 6
		ok = ok and inst.averageSpeed() >= 0 and inst.arrivedCount() >= 0
		return ok and inst.clearAgents() == 0""")

SPEC["society"] = ("""		function inst.populate(names, faction)
			for _, name in ipairs(names) do inst.join(name, { faction = faction }) end
			return #inst.memberOrder
		end
		function inst.bond(a, b, times)
			for _ = 1, (times or 3) do inst.interact(a, b, 1, 0.4) end
			return inst.affinity(a, b)
		end
		function inst.feud(a, b, times)
			for _ = 1, (times or 3) do inst.interact(a, b, -1, 0.4) end
			return inst.affinity(a, b)
		end
		function inst.circleOf(id) return inst.friendsOf(id, 0.25) end
		function inst.standing(id)
			local m = inst.members[id]
			if not m then return 0 end
			return m.reputation
		end
		function inst.factionOf(id)
			local m = inst.members[id]
			if not m then return nil end
			return m.faction
		end""",
"""		local ok = inst.populate({ "ana", "bo", "cy" }, "village") == 3
		ok = ok and inst.bond("ana", "bo", 4) > 0.3
		ok = ok and inst.feud("ana", "cy", 4) < 0
		ok = ok and #inst.circleOf("ana") == 1
		ok = ok and inst.factionOf("bo") == "village"
		inst.gossip("ana", "cy", -1)
		ok = ok and inst.standing("cy") <= 0
		inst.tick(1)
		return ok and inst.cohesion() ~= nil and inst.disposition("ana", "bo") > 0""")

SPEC["economy"] = ("""		function inst.bootstrap()
			if #inst.goodOrder > 0 then return #inst.goodOrder end
			inst.defineGood("food", { basePrice = 8 })
			inst.defineGood("ore", { basePrice = 14 })
			inst.addMarket("farm", { wealth = 400 })
			inst.addMarket("town", { wealth = 700 })
			inst.setStock("farm", "food", 200)
			inst.setStock("town", "ore", 120)
			inst.setProduction("farm", "food", 6)
			inst.setDemand("town", "food", 4)
			return #inst.goodOrder
		end
		function inst.runDays(days)
			inst.bootstrap()
			for _ = 1, (days or 4) do inst.tick(1) end
			return inst.ticks
		end
		function inst.shipment(good, amount)
			inst.bootstrap()
			return inst.trade("farm", "town", good or "food", amount or 20)
		end
		function inst.scarcity(good)
			local stock = inst.totalStock(good)
			if stock <= 0 then return 1 end
			return math.min(1, inst.totalDemand(good) / stock)
		end
		function inst.wealthOf(marketId)
			local m = inst.markets[marketId]
			if not m then return 0 end
			return m.wealth
		end""",
"""		local ok = inst.bootstrap() == 2
		inst.runDays(4)
		ok = ok and inst.priceOf("food") > 0
		ok = ok and inst.shipment("food", 20) > 0
		ok = ok and inst.markets.town.stock.food > 0 and inst.wealthOf("town") < 700
		ok = ok and inst.scarcity("food") >= 0 and inst.balance() ~= nil
		return ok and inst.totalStock("food") > 0 and inst.stats().trades >= 1""")

SPEC["schedule"] = ("""		function inst.buildDay()
			if #inst.slots > 0 then return #inst.slots end
			inst.addSlot("sleep", 22, 6, { priority = 3 })
			inst.addSlot("eat", 6, 8, { priority = 2 })
			inst.addSlot("work", 8, 18, { priority = 2, location = Vec.vec3(12, 0, 0) })
			inst.addSlot("social", 18, 22, { priority = 1 })
			return #inst.slots
		end
		function inst.at(hour)
			inst.buildDay()
			local slot = inst.activeAt(hour)
			if not slot then return nil end
			return slot.activity
		end
		function inst.fastForward(hours)
			inst.buildDay()
			return inst.advance(hours or 1)
		end
		function inst.emergency(activity, hours)
			inst.buildDay()
			inst.interrupt(activity or "flee", hours or 0.5, 9)
			return inst.advance(0.1)
		end
		function inst.hourOfDay() return inst.time end""",
"""		local ok = inst.buildDay() == 4
		ok = ok and inst.at(9) == "work" and inst.at(23) == "sleep" and inst.at(3) == "sleep"
		inst.fastForward(2)
		ok = ok and inst.stats().current ~= nil
		ok = ok and inst.emergency("flee", 1) == "flee"
		inst.fastForward(2)
		ok = ok and inst.hourOfDay() >= 0 and inst.isNight() ~= nil
		return ok and inst.locationFor("work") ~= nil""")

SPEC["ecology"] = ("""		function inst.buildFoodChain()
			if #inst.order > 0 then return #inst.order end
			inst.addSpecies("grass", { population = 800, growth = 0.5, capacity = 2000 })
			inst.addSpecies("deer", { population = 180, growth = 0.25, capacity = 700 })
			inst.addSpecies("wolf", { population = 18, growth = -0.12, capacity = 80 })
			inst.link("deer", "grass", { predation = 0.0004, efficiency = 0.3 })
			inst.link("wolf", "deer", { predation = 0.0009, efficiency = 0.35 })
			return #inst.order
		end
		function inst.advanceSeasons(steps, dt)
			inst.buildFoodChain()
			for _ = 1, (steps or 20) do inst.step(dt or 0.5) end
			return inst.ticks
		end
		function inst.dominant()
			local best, bestPop = nil, -1
			for _, name in ipairs(inst.order) do
				local pop = inst.populationOf(name)
				if pop > bestPop then bestPop = pop best = name end
			end
			return best, bestPop
		end
		function inst.pressureOn(name)
			local total = 0
			for _, link in ipairs(inst.links) do
				if link.prey == name then
					total = total + link.predation * inst.populationOf(link.predator)
				end
			end
			return total
		end
		function inst.cull(name, fraction)
			return inst.harvest(name, inst.populationOf(name) * (fraction or 0.1))
		end""",
"""		local ok = inst.buildFoodChain() == 3
		inst.advanceSeasons(24, 0.5)
		ok = ok and inst.biomass() > 100 and inst.dominant() == "grass"
		ok = ok and inst.pressureOn("deer") > 0 and inst.cull("deer", 0.1) > 0
		inst.seed("deer", 10)
		return ok and inst.populationOf("deer") > 0 and inst.stats().ticks >= 24""")

# ---------------------------------------------------------------- round 7 :: vfx kits
SPEC["emitter"] = ("""		function inst.configureShape(kind)
			inst.setShape(kind or "cone", { radius = 2, angle = 0.5 })
			return inst.shape
		end
		function inst.emitFor(seconds, live)
			local total = 0
			local steps = math.max(1, math.floor((seconds or 0.2) / 0.05))
			for _ = 1, steps do total = total + #inst.emit(0.05, live or 0) end
			return total
		end
		function inst.burstNow(count)
			inst.burst(count or 8, 0)
			return #inst.emit(1 / 60, 0)
		end
		function inst.dropRate()
			local s = inst.stats()
			local total = s.emitted + s.dropped
			if total <= 0 then return 0 end
			return s.dropped / total
		end
		function inst.headroom(live)
			return math.max(0, inst.budget - (live or 0))
		end
		function inst.sampleCloud(count)
			local out = {}
			for i = 1, (count or 4) do out[i] = inst.sampleSpec() end
			return out
		end""",
"""		inst.configureShape("sphere")
		local emitted = inst.emitFor(0.2, 0)
		local burst = inst.burstNow(6)
		local cloud = inst.sampleCloud(3)
		inst.emit(1, inst.budget)
		local ok = emitted >= 0 and burst >= 0 and #cloud == 3
		ok = ok and cloud[1].velocity ~= nil and cloud[1].life > 0
		ok = ok and inst.headroom(0) == inst.budget and inst.dropRate() >= 0
		inst.pause()
		ok = ok and #inst.emit(1, 0) == 0
		inst.resume()
		return ok and inst.stats().emitted >= emitted""")

SPEC["particles"] = ("""		function inst.burstSpawn(count)
			local n = 0
			for i = 1, (count or 8) do
				if inst.spawn({ position = Vec.vec3(0, 1, 0),
					velocity = Vec.vec3(0.4 * i, 3, 0), life = 0.4, size = 0.3 }) then
					n = n + 1
				end
			end
			return n
		end
		function inst.simulate(seconds, dt)
			local step = dt or 1 / 30
			local steps = math.max(1, math.floor((seconds or 0.3) / step))
			for _ = 1, steps do inst.step(step) end
			return inst.aliveCount()
		end
		function inst.centroid()
			local list = inst.aliveList()
			if #list == 0 then return Vec.vec3() end
			local sum = Vec.vec3()
			for _, p in ipairs(list) do sum = sum + p.position end
			return sum * (1 / #list)
		end
		function inst.impulse(force)
			return inst.applyForce(force or Vec.vec3(0, 12, 0), 1 / 30)
		end
		function inst.pressure()
			return inst.occupancy()
		end
		function inst.settle()
			inst.simulate(1.0, 1 / 30)
			return inst.aliveCount()
		end""",
"""		local spawned = inst.burstSpawn(6)
		local ok = spawned > 0 and inst.aliveCount() == spawned
		inst.impulse(Vec.vec3(0, 5, 0))
		inst.simulate(0.2, 1 / 30)
		ok = ok and inst.bounds() ~= nil and inst.pressure() > 0
		ok = ok and inst.centroid() ~= nil
		ok = ok and inst.settle() == 0
		inst.burstSpawn(3)
		inst.killAll()
		return ok and inst.aliveCount() == 0 and inst.stats().killed > 0""")

SPEC["forcefield"] = ("""		function inst.installWeather()
			if inst.fieldCount() > 0 then return inst.fieldCount() end
			inst.addField("wind", "wind", { direction = Vec.vec3(1, 0, 0.2), strength = 4 })
			inst.addField("gust", "turbulence", { strength = 2, frequency = 0.2 })
			inst.addField("drag", "drag", { strength = 0.8 })
			return inst.fieldCount()
		end
		function inst.netForce(position, velocity)
			inst.installWeather()
			return inst.evaluate(position or Vec.vec3(), velocity or Vec.vec3())
		end
		function inst.averageStrength(samples)
			inst.installWeather()
			local total, n = 0, samples or 4
			for i = 1, n do
				total = total + inst.strengthAt(Vec.vec3(i * 2, 0, i), Vec.vec3())
			end
			return total / n
		end
		function inst.attractTo(position, strength, radius)
			return inst.addField("attract", "radial",
				{ position = position or Vec.vec3(), strength = -(strength or 6),
					radius = radius or 20 })
		end
		function inst.disableAll()
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.setEnabled(id, false) ~= nil then n = n + 1 end
			end
			return n
		end
		function inst.enableAll()
			for _, id in ipairs(inst.order) do inst.setEnabled(id, true) end
			return inst.fieldCount()
		end""",
"""		local ok = inst.installWeather() == 3
		local force = inst.netForce(Vec.vec3(1, 0, 1), Vec.vec3(0, 0, 1))
		ok = ok and force ~= nil and inst.averageStrength(3) >= 0
		ok = ok and inst.dominant(Vec.vec3(1, 0, 1)) ~= nil
		ok = ok and inst.attractTo(Vec.vec3(6, 0, 0), 5, 15) ~= nil
		ok = ok and inst.disableAll() == 4
		local quiet = inst.evaluate(Vec.vec3(), Vec.vec3())
		ok = ok and quiet:length() < 1e-6
		inst.enableAll()
		return ok and inst.stats().evaluations > 0 and inst.removeField("drag")""")

SPEC["ribbon"] = ("""		function inst.traceLine(from, to, steps)
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
		end""",
"""		local pushed = inst.traceLine(Vec.vec3(), Vec.vec3(6, 0, 0), 5)
		local ok = pushed > 0 and inst.length() > 0
		ok = ok and inst.stripCount() == #inst.points * 2
		ok = ok and #inst.taperProfile() == #inst.points
		ok = ok and inst.simplify(0.001) <= #inst.points + 1
		ok = ok and inst.fade(inst.lifetime + 0.2, 1 / 20) == 0
		ok = ok and inst.beamTo(Vec.vec3(9, 1, 0), 5) >= 2
		inst.clear()
		return ok and inst.stats().points == 0 and inst.stats().pushes > 0""")

SPEC["dsp"] = ("""		function inst.configure(kind, cutoff)
			inst.setFilter(kind or inst.filterType, cutoff or inst.cutoff, inst.q)
			return inst.filterType
		end
		function inst.renderTone(frequency, samples)
			return inst.tone(frequency or 220, samples or 64, 0.8)
		end
		function inst.loudness(frequency, samples)
			inst.reset()
			return inst.rms(inst.process(inst.renderTone(frequency, samples)))
		end
		function inst.headroom(buffer)
			return 1 - inst.peak(buffer)
		end
		function inst.bandRatio(lowHz, highHz, samples)
			local low = inst.loudness(lowHz or 120, samples or 64)
			local high = inst.loudness(highHz or 4000, samples or 64)
			if high <= 1e-9 then return math.huge end
			return low / high
		end
		function inst.echo(seconds, feedback)
			return inst.setDelay(seconds or 0.02, feedback or 0.35, 0.4)
		end""",
"""		inst.configure(inst.filterType, inst.cutoff)
		local buffer = inst.renderTone(300, 48)
		local out = inst.process(buffer)
		local ok = #out == #buffer and inst.rms(out) >= 0
		ok = ok and inst.headroom(out) <= 1.0 and inst.peak(out) <= 1.01
		ok = ok and inst.bandRatio(120, 4000, 48) >= 0
		ok = ok and inst.echo(0.01, 0.3) > 0
		inst.reset()
		return ok and inst.stats().processed > 0 and inst.stats().sampleRate > 0""")

SPEC["mixer"] = ("""		function inst.installTree()
			if #inst.order > 0 then return #inst.order end
			inst.addBus("master", { gainDb = 0 })
			inst.addBus("sfx", { parent = "master", gainDb = -2 })
			inst.addBus("music", { parent = "master", gainDb = -6 })
			inst.addBus("ui", { parent = "master", gainDb = -4 })
			return #inst.order
		end
		function inst.gainOfBus(id)
			inst.installTree()
			return inst.effectiveGain(id or "sfx")
		end
		function inst.duckFor(busId, amount, seconds)
			inst.installTree()
			inst.duck(busId or "music", amount or 0.7)
			inst.tick(seconds or 0.2)
			return inst.effectiveGain(busId or "music")
		end
		function inst.playVoices(count, busId, priority)
			inst.installTree()
			local n = 0
			for i = 1, (count or 4) do
				if inst.play("voice" .. i, busId or "sfx", priority or 1) then n = n + 1 end
			end
			return n
		end
		function inst.silence()
			inst.installTree()
			for _, id in ipairs(inst.order) do inst.stop(id) end
			return inst.setMute("master", true)
		end
		function inst.unsilence()
			return inst.setMute("master", false)
		end""",
"""		local ok = inst.installTree() == 4
		ok = ok and inst.gainOfBus("sfx") > 0 and inst.gainOfBus("music") > 0
		local ducked = inst.duckFor("music", 0.8, 0.3)
		ok = ok and ducked < inst.gainOfBus("sfx")
		inst.duck("music", 0)
		inst.tick(1.0)
		ok = ok and inst.playVoices(2, "sfx", 1) >= 1
		local snap = inst.snapshot()
		inst.setGain("master", -12)
		inst.restore(snap)
		ok = ok and inst.buses.master.gainDb == 0
		inst.silence()
		ok = ok and inst.effectiveGain("sfx") == 0
		inst.unsilence()
		return ok and inst.stats().buses == 4""")

SPEC["spatialaudio"] = ("""		function inst.installField(count)
			if #inst.order > 0 then return #inst.order end
			local n = count or 4
			for i = 1, n do
				inst.addSource("src" .. i,
					Vec.vec3(math.cos(i) * 8 * i, 0, math.sin(i) * 8 * i),
					{ volume = 1, priority = i })
			end
			return #inst.order
		end
		function inst.moveListener(position, forward)
			return inst.setListener(position or Vec.vec3(),
				forward or Vec.vec3(0, 0, -1), Vec.vec3(0, 1, 0))
		end
		function inst.loudestSource()
			local best, bestGain = nil, -1
			for _, id in ipairs(inst.order) do
				local g = inst.gainOf(id)
				if g > bestGain then bestGain = g best = id end
			end
			return best, bestGain
		end
		function inst.audibleCount(threshold)
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.audible(id, threshold or 0.01) then n = n + 1 end
			end
			return n
		end
		function inst.occludeAll(amount)
			for _, id in ipairs(inst.order) do inst.setOcclusion(id, amount or 1) end
			return #inst.order
		end
		function inst.panField()
			local out = {}
			for _, id in ipairs(inst.order) do
				out[id] = inst.pan(inst.sources[id].position)
			end
			return out
		end""",
"""		local ok = inst.installField(4) == 4
		inst.moveListener(Vec.vec3(), Vec.vec3(0, 0, -1))
		local loudest, gain = inst.loudestSource()
		ok = ok and loudest ~= nil and gain > 0
		ok = ok and inst.audibleCount(0.001) >= 1
		local pans = inst.panField()
		ok = ok and pans[loudest] ~= nil and math.abs(pans[loudest]) <= 1.0001
		ok = ok and inst.attenuation(inst.maxDistance * 2) == 0
		inst.occludeAll(1)
		ok = ok and inst.gainOf(loudest) < gain
		inst.occludeAll(0)
		ok = ok and #inst.cullVoices() <= inst.maxVoices
		return ok and #inst.mixSnapshot() >= 1 and inst.stats().sources == 4""")

SPEC["sequencer"] = ("""		function inst.installScore()
			if #inst.sectionOrder > 0 then return #inst.sectionOrder end
			inst.addSection("calm", 4)
			inst.addSection("tense", 4)
			inst.addLayer("pad", { threshold = 0, fade = 0.25 })
			inst.addLayer("drums", { threshold = 0.55, fade = 0.25 })
			inst.addCue("downbeat", 1)
			inst.addCue("swell", 3)
			return #inst.sectionOrder
		end
		function inst.runBeats(beats)
			inst.installScore()
			inst.play()
			local fired = inst.advance(inst.beatDuration() * (beats or 4))
			return #fired
		end
		function inst.intensityTo(value)
			inst.installScore()
			inst.setIntensity(value or 0.8)
			return inst.intensity
		end
		function inst.stemMix()
			inst.installScore()
			local out = {}
			for _, name in ipairs(inst.layerOrder) do out[name] = inst.layerGain(name) end
			return out
		end
		function inst.switchTo(section, grid)
			inst.installScore()
			return inst.transitionTo(section or "tense", grid or 4)
		end
		function inst.position()
			return inst.bar(), inst.beatInBar()
		end""",
"""		local ok = inst.installScore() == 2
		local fired = inst.runBeats(4)
		ok = ok and fired >= 1 and inst.stats().current ~= nil
		ok = ok and inst.intensityTo(0.9) == 0.9
		local mix = inst.stemMix()
		ok = ok and mix.pad ~= nil and mix.drums ~= nil
		ok = ok and inst.switchTo("tense", 4) >= 0
		inst.advance(inst.beatDuration() * 8)
		local bar, beat = inst.position()
		ok = ok and bar >= 1 and beat >= 0
		ok = ok and inst.quantize(1.3, 1) >= 1
		inst.stop()
		return ok and inst.stats().fired >= 1""")

# ----------------------------------------------------------- round 7 :: gameplay kits
SPEC["stats"] = ("""		function inst.installProfile()
			if #inst.order > 0 then return #inst.order end
			inst.define("vitality", 10, { min = 0, max = 999 })
			inst.define("strength", 10, { min = 0, max = 999 })
			inst.define("agility", 10, { min = 0, max = 999 })
			inst.defineDerived("maxHealth", function(s) return 20 + s.get("vitality") * 8 end)
			inst.defineDerived("power", function(s) return s.get("strength") * 2 end)
			return #inst.order
		end
		function inst.buff(name, id, amount, duration)
			inst.installProfile()
			return inst.addModifier(name or "strength", id or "buff",
				{ flat = amount or 5, duration = duration })
		end
		function inst.debuff(name, id, percent, duration)
			inst.installProfile()
			return inst.addModifier(name or "agility", id or "debuff",
				{ percent = -(percent or 0.25), duration = duration })
		end
		function inst.power()
			inst.installProfile()
			return inst.getDerived("power")
		end
		function inst.expire(seconds)
			inst.installProfile()
			inst.tick(seconds or 1)
			return inst.stats().expired
		end
		function inst.deltaFrom(other)
			inst.installProfile()
			return inst.compare(other)
		end""",
"""		local ok = inst.installProfile() == 3
		local base = inst.power()
		inst.buff("strength", "sword", 6)
		ok = ok and inst.power() > base
		inst.buff("strength", "rage", 4, 0.5)
		local peak = inst.power()
		inst.expire(1.0)
		ok = ok and inst.power() < peak and inst.power() > base
		ok = ok and inst.removeModifier("sword") == 1
		ok = ok and inst.getDerived("maxHealth") > 20
		ok = ok and #inst.modifiersFor("strength") == 0
		local snap = inst.snapshot()
		return ok and snap.vitality ~= nil and inst.stats().recomputes > 0""")

SPEC["inventory"] = ("""		function inst.installCatalog()
			if inst.defs.fibre then return true end
			inst.defineItem("fibre", { stack = 20, weight = 0.2, value = 1 })
			inst.defineItem("ingot", { stack = 10, weight = 1.5, value = 8 })
			inst.defineItem("blade", { stack = 1, weight = 3, slot = "hand", value = 40 })
			inst.addRecipe("forgeBlade", { fibre = 4, ingot = 2 }, { blade = 1 })
			return true
		end
		function inst.stock(item, count)
			inst.installCatalog()
			return inst.add(item or "fibre", count or 5)
		end
		function inst.load()
			return inst.weight() / math.max(1e-6, inst.maxWeight)
		end
		function inst.forge()
			inst.installCatalog()
			if not inst.canCraft("forgeBlade") then return false end
			return inst.craft("forgeBlade")
		end
		function inst.gearUp()
			if inst.countOf("blade") < 1 then return false end
			return inst.equip("blade")
		end
		function inst.roundTrip()
			local blob = inst.serialize()
			local before = inst.totalValue()
			inst.deserialize(blob)
			return before == inst.totalValue()
		end""",
"""		inst.installCatalog()
		local ok = inst.stock("fibre", 6) == 6 and inst.stock("ingot", 3) == 3
		ok = ok and inst.load() > 0 and inst.load() <= 1
		ok = ok and inst.forge() and inst.countOf("blade") == 1
		ok = ok and inst.gearUp() and inst.equipment.hand == "blade"
		ok = ok and inst.countOf("fibre") == 2 and inst.has("ingot", 1)
		ok = ok and inst.roundTrip()
		ok = ok and inst.remove("ingot", 1) >= 1
		return ok and inst.freeSlots() >= 0 and inst.stats().crafted == 1""")

SPEC["quest"] = ("""		function inst.installChain()
			if #inst.order > 0 then return #inst.order end
			inst.define("scout", { rewards = { xp = 40 } })
			inst.addObjective("scout", "markers", { required = 2, event = "reach.marker" })
			inst.define("secure", { requires = { "scout" }, rewards = { xp = 90 } })
			inst.addObjective("secure", "threats", { required = 1, event = "clear.threat" })
			return #inst.order
		end
		function inst.begin(name)
			inst.installChain()
			return inst.start(name or "scout")
		end
		function inst.report(event, amount)
			inst.installChain()
			return inst.notify(event or "reach.marker", amount or 1)
		end
		function inst.completion()
			inst.installChain()
			local total = 0
			for _, name in ipairs(inst.order) do total = total + inst.progress(name) end
			return total / math.max(1, #inst.order)
		end
		function inst.openQuests()
			inst.installChain()
			local out = {}
			for _, name in ipairs(inst.order) do
				if inst.stateOf(name) == "available" then out[#out + 1] = name end
			end
			return out
		end
		function inst.abandon(name)
			inst.installChain()
			return inst.fail(name or "scout")
		end""",
"""		local ok = inst.installChain() == 2
		ok = ok and #inst.openQuests() == 1
		ok = ok and inst.begin("scout")
		inst.report("reach.marker", 1)
		ok = ok and inst.progress("scout") > 0 and inst.progress("scout") < 1
		inst.report("reach.marker", 1)
		ok = ok and inst.stateOf("scout") == "completed"
		ok = ok and inst.stateOf("secure") == "available"
		ok = ok and inst.begin("secure")
		inst.report("clear.threat", 1)
		ok = ok and inst.isComplete("secure")
		return ok and inst.completion() > 0.9 and inst.stats().completed == 2""")

SPEC["combat"] = ("""		function inst.installDuel()
			if #inst.order > 0 then return #inst.order end
			inst.addActor("champion", { health = 220, armour = 60, power = 26,
				accuracy = 0.95, critChance = 0.1, team = "player" })
			inst.addActor("challenger", { health = 180, armour = 30, power = 20,
				accuracy = 0.9, critChance = 0.05, team = "enemy",
				resistances = { fire = 0.25 } })
			return #inst.order
		end
		function inst.exchange()
			inst.installDuel()
			local a = inst.attack("champion", "challenger", {})
			local b = inst.attack("challenger", "champion", {})
			return a, b
		end
		function inst.resolveRounds(rounds)
			inst.installDuel()
			for _ = 1, (rounds or 3) do
				inst.exchange()
				inst.tick(0.5)
			end
			return inst.stats().attacks
		end
		function inst.burn(id, seconds, damage)
			inst.installDuel()
			return inst.applyStatus(id or "challenger", "burn",
				{ duration = seconds or 2, tickDamage = damage or 4 })
		end
		function inst.survivors()
			inst.installDuel()
			return inst.teamAlive("player"), inst.teamAlive("enemy")
		end
		function inst.effectiveDamage(power, armour)
			return inst.mitigate(power or 40, armour or 60, 0)
		end""",
"""		local ok = inst.installDuel() == 2
		local a = inst.exchange()
		ok = ok and (a == nil or a.damage >= 0)
		ok = ok and inst.resolveRounds(2) >= 4
		ok = ok and inst.burn("challenger", 1, 4)
		ok = ok and inst.hasStatus("challenger", "burn")
		inst.tick(1.5)
		ok = ok and not inst.hasStatus("challenger", "burn")
		inst.setCooldown("champion", "smash", 1)
		ok = ok and not inst.ready("champion", "smash")
		inst.tick(1.2)
		ok = ok and inst.ready("champion", "smash")
		local friends, foes = inst.survivors()
		ok = ok and friends >= 0 and foes >= 0
		ok = ok and inst.effectiveDamage(40, 60) < 40
		return ok and inst.hitChance("champion", "challenger") > 0""")

# ------------------------------------------------------------- round 7 :: ui/net kits
SPEC["flex"] = ("""		function inst.installScreen()
			if inst.root then return #inst.order end
			inst.addNode("root", { direction = "column", padding = 8, gap = 8 })
			inst.addNode("header", { parent = "root", height = 56 })
			inst.addNode("body", { parent = "root", weight = 1 })
			inst.addNode("footer", { parent = "root", height = 72 })
			inst.solve()
			return #inst.order
		end
		function inst.layoutFor(width, height)
			inst.installScreen()
			inst.setViewport(width or inst.width, height or inst.height)
			inst.solve()
			return inst.breakpoint()
		end
		function inst.regionOf(id)
			inst.installScreen()
			return inst.rectOf(id or "body")
		end
		function inst.smallTargets(minSize)
			inst.installScreen()
			return inst.touchTargetsBelow(minSize or 44)
		end
		function inst.collapse(id)
			inst.installScreen()
			inst.setVisible(id or "header", false)
			inst.solve()
			return inst.rectOf("body")
		end
		function inst.pick(x, y)
			inst.installScreen()
			return inst.hitTest(x or inst.width * 0.5, y or inst.height * 0.5)
		end""",
"""		local ok = inst.installScreen() == 4
		local body = inst.regionOf("body")
		ok = ok and body ~= nil and body.height > 0 and body.width > 0
		ok = ok and inst.rectOf("root").y >= inst.safeArea.top
		ok = ok and inst.layoutFor(inst.width, inst.height) ~= nil
		ok = ok and inst.pick(inst.width * 0.5, inst.safeArea.top + 10) ~= nil
		local grown = inst.collapse("header")
		ok = ok and grown.height >= body.height
		ok = ok and type(inst.smallTargets(44)) == "table"
		return ok and inst.depthOf("body") == 1 and inst.stats().solves > 0""")

SPEC["inputmap"] = ("""		function inst.installActions()
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
		end""",
"""		local ok = inst.installActions() == 3
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
		return ok and inst.stats().presses > 0""")

SPEC["tween"] = ("""		function inst.installIntro()
			if #inst.order > 0 then return #inst.order end
			inst.create("fade", { from = 0, to = 1, duration = 0.3, easing = "quadOut" })
			inst.create("slide", { from = -40, to = 0, duration = 0.4, easing = "cubicOut" })
			return #inst.order
		end
		function inst.advanceBy(seconds, dt)
			local step = dt or 1 / 60
			local steps = math.max(1, math.floor((seconds or 0.5) / step))
			local finished = 0
			for _ = 1, steps do finished = finished + #inst.update(step) end
			return finished
		end
		function inst.valuesOf()
			local out = {}
			for _, id in ipairs(inst.order) do out[id] = inst.valueOf(id) end
			return out
		end
		function inst.curveSamples(name, count)
			local out = {}
			local n = count or 5
			for i = 0, n do out[#out + 1] = inst.ease(name or "quadOut", i / n) end
			return out
		end
		function inst.chain(prefix, steps)
			return inst.sequence(prefix or "chain", steps or {
				{ from = 0, to = 1, duration = 0.15 },
				{ from = 1, to = 0, duration = 0.15 } })
		end
		function inst.holdAll()
			for _, id in ipairs(inst.order) do inst.pause(id) end
			return #inst.order
		end""",
"""		local ok = inst.installIntro() == 2
		inst.advanceBy(0.15, 1 / 60)
		local mid = inst.valuesOf()
		ok = ok and mid.fade > 0 and mid.fade < 1
		local finished = inst.advanceBy(0.6, 1 / 60)
		ok = ok and finished >= 2 and inst.valueOf("fade") == 1
		local curve = inst.curveSamples("quadOut", 4)
		ok = ok and #curve == 5 and curve[1] <= curve[#curve]
		ok = ok and math.abs(inst.ease("linear", 0.5) - 0.5) < 1e-6
		local ids, total = inst.chain("intro")
		ok = ok and #ids == 2 and total > 0
		ok = ok and inst.holdAll() >= 2
		inst.clear()
		return ok and inst.activeCount() == 0 and inst.stats().completed >= 2""")

SPEC["replicator"] = ("""		function inst.installWorld(count)
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
		end""",
"""		local ok = inst.installWorld(4) == 4
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
		return ok and inst.bandwidth() >= 0 and inst.stats().entities == 3""")

SPEC["netclock"] = ("""		function inst.syncFor(samples, latency, offset)
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
		end""",
"""		local offset = inst.syncFor(6, 0.05, 1.0)
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
		return ok and inst.serverTime() > 0 and inst.stats().tick >= 1""")

SPEC["prediction"] = ("""		function inst.driveForward(steps, dt)
			local input = { move = Vec.vec3(1, 0, 0), speed = 8 }
			local step = dt or 1 / 30
			for _ = 1, (steps or 6) do inst.pushInput(input, step) end
			return inst.sequence
		end
		function inst.confirm(sequence)
			return inst.reconcile({ position = inst.state.position,
				velocity = inst.state.velocity }, sequence or inst.sequence)
		end
		function inst.correctTo(position, sequence)
			return inst.reconcile({ position = position or Vec.vec3(),
				velocity = Vec.vec3() }, sequence or math.max(0, inst.sequence - 2))
		end
		function inst.errorNow()
			return inst.predictionError()
		end
		function inst.renderPose(dt)
			return inst.smooth({ position = inst.serverState.position,
				velocity = inst.serverState.velocity }, dt or 1 / 60)
		end
		function inst.rewind()
			inst.reset({ position = Vec.vec3(), velocity = Vec.vec3() })
			return inst.pending()
		end""",
"""		local ok = inst.driveForward(6, 1 / 30) == 6
		ok = ok and inst.state.position.x > 0 and inst.pending() == 6
		local corrected = inst.confirm(inst.sequence)
		ok = ok and not corrected and inst.pending() == 0
		inst.driveForward(4, 1 / 30)
		local far = Vec.vec3(inst.state.position.x - 5, 0, 0)
		local fixed, err = inst.correctTo(far)
		ok = ok and fixed and err > inst.errorThreshold
		ok = ok and inst.stats().replays > 0
		ok = ok and inst.errorNow() >= 0
		local pose = inst.renderPose(1 / 60)
		ok = ok and pose.position ~= nil
		return ok and inst.rewind() == 0 and inst.stats().mispredictions >= 1""")


# ------------------------------------------------------------- round 8 :: AI kits
SPEC["intent"] = ("""		function inst.teach(word, action)
			return inst.addVerb(word, { word }, action or "create")
		end
		function inst.understand(text)
			local r = inst.parse(text)
			return r.understood, r
		end
		function inst.routeFor(text)
			local r = inst.parse(text)
			if not r.understood then return "clarify" end
			return (r.action or "unknown") .. ":" .. (r.target or "world")
		end
		function inst.brief(text)
			local r = inst.parse(text)
			return { action = r.action, target = r.target, quantity = r.quantity or 1,
				device = r.constraints.device or "any", confidence = r.confidence }
		end""",
"""		inst.installDefaults()
		local ok, r = inst.understand("build a city with 20 buildings for phones")
		ok = ok and r.action == "create" and r.target == "city" and r.quantity == 20
		ok = ok and r.constraints.device == "mobile"
		ok = ok and inst.routeFor("build a city") == "create:city"
		local brief = inst.brief("optimize the map for weak phones")
		ok = ok and brief.action == "optimize" and brief.device == "mobile"
		ok = ok and inst.teach("erect", "create") ~= nil
		return ok and inst.stats().parsed >= 3""")

SPEC["knowledge"] = ("""		function inst.installDomain()
			inst.addEntity(S.key .. ".root", "domain", { area = S.name })
			inst.addEntity(S.key .. ".part", "component", { area = S.name })
			inst.addEntity(S.key .. ".detail", "component", { area = S.name })
			inst.relate(S.key .. ".part", "part_of", S.key .. ".root")
			inst.relate(S.key .. ".detail", "part_of", S.key .. ".part")
			inst.addRule("part_of", "transitive")
			return inst.infer(3)
		end
		function inst.componentsOf()
			return inst.query({ type = "component" })
		end
		function inst.closestTo(id)
			local near = inst.nearest(id, 1)
			return near[1] and near[1].id or nil
		end
		function inst.routeBetween(a, b)
			return inst.path(a, b, 6)
		end""",
"""		local inferred = inst.installDomain()
		local ok = inferred >= 1
		ok = ok and inst.hasRelation(S.key .. ".detail", "part_of", S.key .. ".root")
		ok = ok and #inst.componentsOf() == 2
		local route = inst.routeBetween(S.key .. ".detail", S.key .. ".root")
		ok = ok and route ~= nil and #route >= 2
		ok = ok and inst.closestTo(S.key .. ".part") ~= nil
		return ok and inst.stats().entities == 3""")

SPEC["workflow"] = ("""		function inst.installStages()
			local state = { prepared = false, built = 0, verified = false }
			inst.shared = state
			inst.addStep("prepare", { cost = 1,
				run = function() state.prepared = true return true end,
				verify = function() return state.prepared end,
				undo = function() state.prepared = false end })
			inst.addStep("build", { cost = 2, requires = { "prepare" },
				run = function() state.built = state.built + 4 return state.built end,
				verify = function() return state.built > 0 end,
				undo = function() state.built = 0 end })
			inst.addStep("verify", { cost = 1, requires = { "build" },
				run = function() state.verified = state.built > 0 return state.verified end,
				verify = function() return state.verified end })
			return #inst.order
		end
		function inst.executeAll()
			inst.reset()
			return inst.run(S)
		end
		function inst.longest()
			local path = inst.criticalPath()
			return path and #path or 0
		end""",
"""		local ok = inst.installStages() == 3
		ok = ok and inst.executeAll()
		ok = ok and inst.shared.built == 4
		ok = ok and inst.progress() == 1
		ok = ok and inst.longest() >= 1
		ok = ok and #inst.failedSteps() == 0
		return ok and inst.stats().executed >= 3""")

SPEC["critic"] = ("""		function inst.installCriteria()
			inst.addCriterion("quality", { weight = 3, target = 1, direction = "higher" })
			inst.addCriterion("cost", { weight = 2, target = 10, direction = "lower" })
			inst.addCriterion("balance", { weight = 1, floor = 0.4, ceiling = 0.6,
				direction = "range" })
			return #inst.order
		end
		function inst.judge(quality, cost, balance)
			return inst.evaluate({ quality = quality, cost = cost, balance = balance })
		end
		function inst.advice(record)
			return inst.suggestions(record, 3)
		end""",
"""		local ok = inst.installCriteria() == 3
		local good = inst.judge(1, 5, 0.5)
		ok = ok and good.verdict == "pass" and good.overall > 0.9
		local bad = inst.judge(0.1, 100, 5)
		ok = ok and bad.overall < good.overall
		ok = ok and #inst.advice(bad) > 0
		ok = ok and inst.worst(bad) ~= nil
		return ok and inst.stats().evaluations == 2""")

# ---------------------------------------------------- round 8 :: production kits
SPEC["importer"] = ("""		function inst.ingest(name, bytes)
			return inst.import("mesh", { name = name, vertices = 300, triangles = 400,
				bytes = bytes or 4096, size = 2, extension = "obj" })
		end
		function inst.ingestTexture(name, size)
			return inst.import("texture", { name = name, width = size or 512,
				height = size or 512, bytes = (size or 512) * 64, extension = "png" })
		end
		function inst.catalogue()
			return { meshes = #inst.ofType("mesh"), textures = #inst.ofType("texture"),
				bytes = inst.totalBytes() }
		end""",
"""		inst.installDefaults()
		local asset = inst.ingest(S.key .. ".mesh", 8192)
		local ok = asset ~= nil and asset.type == "mesh"
		local dup, _, note = inst.ingest(S.key .. ".mesh", 8192)
		ok = ok and note == "duplicate" and dup ~= nil
		ok = ok and inst.ingestTexture(S.key .. ".tex", 512) ~= nil
		local bad = inst.import("mesh", { name = "broken" })
		ok = ok and bad == nil
		local c = inst.catalogue()
		return ok and c.meshes == 1 and c.textures == 1 and c.bytes > 0""")

SPEC["bundler"] = ("""		function inst.stage(count, bytes)
			for i = 1, (count or 4) do
				inst.add(S.key .. ".item" .. i, { bytes = bytes or 60000, type = "mesh",
					group = (i % 2 == 0) and "core" or "stream", priority = i })
			end
			return inst.pack()
		end
		function inst.sizeOf(group)
			local total = 0
			for _, bundle in ipairs(inst.bundles) do
				if bundle.group == group then total = total + bundle.bytes end
			end
			return total
		end
		function inst.residentPlan(groups)
			return inst.loadPlan(groups or { "core" })
		end""",
"""		local packed = inst.stage(6, 60000)
		local ok = packed >= 1 and #inst.bundles == packed
		ok = ok and inst.bundleOf(S.key .. ".item1") ~= nil
		ok = ok and inst.sizeOf("core") > 0
		local manifest = inst.manifest()
		ok = ok and manifest.entries == 6 and manifest.totalBytes > 0
		local delta = inst.delta(manifest)
		ok = ok and #delta.added == 0 and #delta.removed == 0
		return ok and inst.compressionRatio() < 1 and #inst.residentPlan() >= 1""")

SPEC["timeline"] = ("""		function inst.installShot()
			inst.addTrack("fov", { default = 1 })
			inst.addKey("fov", 0, 1)
			inst.addKey("fov", 2, 1.6, "easeInOut")
			inst.addClip("main", 0, 2)
			inst.addEvent("beat", 1)
			return inst.duration
		end
		function inst.scrub(time) return inst.seek(time) end
		function inst.frameAt(time) return inst.sampleAll(time or inst.time) end""",
"""		local ok = inst.installShot() >= 2
		ok = ok and inst.valueAt("fov", 0) == 1
		local mid = inst.valueAt("fov", 1)
		ok = ok and mid > 1 and mid < 1.6
		ok = ok and #inst.activeClips(1) == 1
		inst.play()
		local fired = inst.advance(1.5)
		ok = ok and #fired == 1 and fired[1].name == "beat"
		ok = ok and #inst.advance(0.2) == 0
		ok = ok and inst.scrub(0.5) == 0.5
		return ok and inst.frameAt(0.5).fov ~= nil""")

SPEC["camerarig"] = ("""		function inst.stage(subject)
			inst.setMode("orbit")
			for _ = 1, 12 do inst.update(1 / 30, subject or Vec.vec3()) end
			return inst.position
		end
		function inst.dollyThrough(a, b)
			inst.addPathPoint(a or Vec.vec3())
			inst.addPathPoint(b or Vec.vec3(10, 0, 0))
			inst.setMode("dolly")
			return inst.pathLength
		end
		function inst.depthOfField(distance)
			return inst.circleOfConfusion(distance or inst.focus)
		end""",
"""		local subject = Vec.vec3()
		local p = inst.stage(subject)
		local ok = p ~= nil and inst.focus > 0
		ok = ok and inst.depthOfField(inst.focus) < 0.001
		ok = ok and inst.depthOfField(inst.focus * 5) > 0
		ok = ok and inst.dollyThrough(Vec.vec3(), Vec.vec3(10, 0, 0)) > 9
		ok = ok and inst.pathAt(0.5).x > 0
		inst.shake(1)
		inst.update(0.2, subject)
		return ok and inst.shakeAmount < 1 and inst.stats().updates >= 13""")

SPEC["grade"] = ("""		function inst.look(name, weight)
			inst.installLooks()
			return inst.applyLook(name or "warmDay", weight or 1)
		end
		function inst.pixel(r, g, b)
			return inst.apply({ r or 0.5, g or 0.5, b or 0.5 })
		end
		function inst.expose(target)
			local sample = {}
			for i = 1, 4 do sample[i] = { 0.04 * i, 0.04 * i, 0.04 * i } end
			for _ = 1, 8 do inst.autoExpose(sample, target or 0.18) end
			return inst.exposure
		end""",
"""		local base = inst.pixel(0.5, 0.5, 0.5)
		local ok = base[1] >= 0 and base[1] <= 1
		ok = ok and inst.look("noir", 1)
		local noir = inst.pixel(0.8, 0.2, 0.2)
		ok = ok and math.abs(noir[1] - noir[3]) < 0.3
		inst.reset()
		ok = ok and inst.expose(0.18) ~= 0
		ok = ok and inst.luma({ 1, 1, 1 }) > 0.99
		return ok and inst.stats().applied >= 3""")

# ------------------------------------------------------- round 8 :: original kits
SPEC["reality"] = ("""		function inst.installLayers() return inst.installStack() end
		function inst.author(key, value) return inst.set("authored", key, value) end
		function inst.simulate(key, value) return inst.set("simulated", key, value) end
		function inst.propose(key, value) return inst.set("proposed", key, value) end
		function inst.accept() return inst.commit("proposed", "simulated") end
		function inst.revert() return inst.discard("proposed") end""",
"""		local ok = inst.installLayers() >= 4
		inst.author(S.key .. ".value", 10)
		ok = ok and inst.get(S.key .. ".value") == 10
		inst.simulate(S.key .. ".value", 20)
		ok = ok and inst.get(S.key .. ".value") == 20
		inst.propose(S.key .. ".value", 30)
		ok = ok and inst.get(S.key .. ".value") == 30
		ok = ok and inst.revert() == 1 and inst.get(S.key .. ".value") == 20
		inst.propose(S.key .. ".value", 40)
		ok = ok and inst.accept() == 1 and inst.get(S.key .. ".value") == 40
		return ok and inst.divergence("authored") > 0 and #inst.keys() == 1""")

SPEC["complexity"] = ("""		function inst.installZones()
			inst.addZone(S.key .. ".core", { objects = 400, agents = 30, lights = 20,
				effects = 6 })
			inst.addZone(S.key .. ".edge", { objects = 120, agents = 6, lights = 4,
				effects = 1 })
			inst.setImportance(S.key .. ".core", 3)
			return inst.totalCost()
		end
		function inst.governFrame(targetMs)
			inst.setTarget(targetMs or 16.6)
			return inst.evaluate()
		end
		function inst.budgetFor(zone) return inst.directiveFor(zone) end""",
"""		local ok = inst.installZones() > 0
		local result = inst.governFrame(8)
		ok = ok and result.pressure > 1
		local core = inst.budgetFor(S.key .. ".core")
		local edge = inst.budgetFor(S.key .. ".edge")
		ok = ok and core.objects < 400 and edge.objects < 120
		ok = ok and core.quality >= edge.quality
		ok = ok and inst.heaviest() == S.key .. ".core"
		local relaxed = inst.governFrame(10000)
		return ok and relaxed.pressure < 1 and inst.stats().zones == 2""")

SPEC["fabric"] = ("""		function inst.installDomains()
			inst.counters = { fast = 0, slow = 0 }
			local counters = inst.counters
			inst.addDomain("fast", { hz = 20, cost = 1, priority = 2,
				step = function() counters.fast = counters.fast + 1 end })
			inst.addDomain("slow", { hz = 2, cost = 1, priority = 1,
				step = function() counters.slow = counters.slow + 1 end })
			return #inst.order
		end
		function inst.simulate(seconds) return inst.run(seconds or 1, 1 / 30) end
		function inst.publish(topic, message)
			return inst.send(topic or "world", message or {})
		end""",
"""		local ok = inst.installDomains() == 2
		inst.simulate(1)
		ok = ok and inst.counters.fast > inst.counters.slow
		ok = ok and inst.publish("world", { tick = 1 }) == 1
		ok = ok and #inst.receive("world") == 1
		local before = inst.load()
		inst.applyQuality(0.2)
		return ok and inst.load() < before and inst.stats().steps > 0""")

SPEC["autopipeline"] = ("""		function inst.sampleProject()
			return { frameMs = 40, targetMs = 16.6, drawCalls = 2400, maxDrawCalls = 900,
				failingTests = 2, orphanAssets = 4, memoryMb = 800, memoryCeilingMb = 512,
				quality = 1 }
		end
		function inst.audit(project) return inst.analyze(project or inst.sampleProject()) end
		function inst.repair(project, rounds) return inst.improve(project, rounds or 24) end""",
"""		inst.installDefaults()
		local project = inst.sampleProject()
		local findings = inst.audit(project)
		local ok = #findings == 5 and findings[1].severity == 3
		local before = inst.projectHealth(project)
		local record = inst.repair(project, 24)
		ok = ok and record.gain > 0 and record.after > before
		ok = ok and project.orphanAssets == 0 and project.drawCalls < 2400
		ok = ok and inst.report().open >= 0
		return ok and inst.stats().applied > 0""")

SPEC["worldmemory"] = ("""		function inst.log(subject, event, weight)
			return inst.remember(subject or S.key, event or "tick",
				{ weight = weight or 1, region = S.key })
		end
		function inst.story(subject) return inst.historyOf(subject or S.key, 8) end
		function inst.save() return inst.checkpoint(S.key) end
		function inst.load(checkpoint) return inst.restore(checkpoint) end""",
"""		inst.log(S.key, "born", 1)
		inst.advance(1)
		inst.log(S.key, "grew", 2)
		local ok = #inst.story(S.key) == 2
		ok = ok and #inst.recall({ region = S.key }) == 2
		local cp = inst.save()
		inst.log(S.key, "changed", 1)
		ok = ok and inst.checksum() ~= cp.checksum
		ok = ok and inst.load(cp)
		ok = ok and #inst.recall({ subject = S.key }) == 2
		ok = ok and inst.advanceEpoch("next") == 2
		return ok and inst.stats().written >= 3""")

SPEC["emergence"] = ("""		function inst.watch(event, weight) return inst.observe(event, weight) end
		function inst.trend(name, value) return inst.signal(name, value) end
		function inst.detected() return inst.detect() end""",
"""		for i = 1, 6 do
			inst.watch("rain")
			inst.watch("flood")
			inst.watch("noise" .. i)
		end
		local found = inst.detected()
		local ok = #found > 0 and inst.lift("rain", "flood") > 1
		for _ = 1, 10 do inst.trend("level", 0.5) end
		ok = ok and math.abs(inst.deviation("level")) < 0.001
		inst.trend("level", 4)
		ok = ok and inst.deviation("level") > 1
		ok = ok and #inst.named() > 0
		return ok and inst.novelty("rain") < inst.novelty("unheard")""")

SPEC["architect"] = ("""		function inst.composeWorld(target, quantity)
			return inst.compose({ target = target or S.key, quantity = quantity or 60,
				density = 1 })
		end
		function inst.buildOrder() return inst.programme() end
		function inst.check() return inst.coherent() end
		function inst.cost(rate) return inst.estimate(rate or 1) end""",
"""		local composed = inst.composeWorld(S.key, 80)
		local ok = composed.nodes > 8 and composed.districts >= 1
		ok = ok and inst.check()
		local programme = inst.buildOrder()
		ok = ok and programme ~= nil and #programme == #inst.order
		local index = {}
		for i, id in ipairs(programme) do index[id] = i end
		ok = ok and index[S.key .. ".terrain"] < index[S.key .. ".roads"]
		return ok and inst.cost(1) > 0 and inst.stats().composed == 1""")


build()
