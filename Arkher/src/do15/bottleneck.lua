-- ARKHER D-O15 :: Bottleneck Detection + Optimization Planner
-- Turns profiler data into a ranked, actionable optimization plan. This is the
-- engine talking back to the developer (and to the Singularity AI) in real terms.
--@arkher-module
return function(A)
	local Bottleneck = {}
	Bottleneck.__index = Bottleneck

	Bottleneck.SIGNATURES = {
		{ id = "cpu-scripts", when = function(m) return m.scriptMs > m.frameMs * 0.45 end,
		  diagnosis = "Luau script execution dominates the frame",
		  actions = { "raise task intervals via scheduler importance", "move per-frame loops to interval tasks",
			  "batch entity queries", "enable ARKHER job slicing", "cache hot lookups" } },
		{ id = "gpu-drawcalls", when = function(m) return m.drawCalls > m.budgets.drawCalls end,
		  diagnosis = "Draw call count exceeds the device budget",
		  actions = { "merge static geometry into chunks", "enable HLOD impostors", "reduce material variants",
			  "increase cull aggressiveness", "raise LOD bias" } },
		{ id = "geometry", when = function(m) return m.parts > m.budgets.parts end,
		  diagnosis = "Instance/part count above budget",
		  actions = { "enable geometry virtualization", "stream distant chunks", "instance repeated props",
			  "convert decorative parts to baked detail" } },
		{ id = "memory", when = function(m) return m.memoryMB > m.budgets.memoryMB end,
		  diagnosis = "Memory pressure - eviction storms and hitching likely",
		  actions = { "lower texture resolution tier", "shrink streaming radius", "evict unreferenced resources",
			  "compress animation tracks", "reduce audio streaming buffers" } },
		{ id = "physics", when = function(m) return m.physicsMs > m.frameMs * 0.3 end,
		  diagnosis = "Physics simulation over budget",
		  actions = { "increase physics LOD distance", "sleep distant bodies", "simplify collision meshes",
			  "reduce solver iterations for background objects" } },
		{ id = "ai", when = function(m) return m.aiMs > m.frameMs * 0.25 end,
		  diagnosis = "NPC/AI thinking over budget",
		  actions = { "reduce NPC tick rate by distance", "use group-level abstractions for crowds",
			  "defer planning to job system", "swap distant NPCs to statistical simulation" } },
		{ id = "particles", when = function(m) return m.particles > m.budgets.particles end,
		  diagnosis = "VFX particle count above budget",
		  actions = { "scale emitter rates by D-O15 vfxDensity", "cull emitters outside frustum",
			  "merge overlapping effects", "reduce lifetime of ambient effects" } },
		{ id = "network", when = function(m) return (m.bandwidthKbps or 0) > 220 end,
		  diagnosis = "Replication bandwidth high; latency spikes expected on mobile data",
		  actions = { "raise interest-management radius", "reduce replication rate by distance",
			  "delta-compress state", "prioritize gameplay-critical entities" } },
		{ id = "stall", when = function(m) return (m.p99Ms or 0) > m.frameMs * 2.5 end,
		  diagnosis = "Frame time spikes (hitching) despite acceptable average",
		  actions = { "spread instantiation across frames", "pre-warm object pools",
			  "chunk terrain edits", "throttle asset loads per frame" } },
	}

	function Bottleneck.new()
		return setmetatable({ history = {}, detections = 0 }, Bottleneck)
	end

	function Bottleneck:analyze(metrics)
		local m = metrics
		m.frameMs = m.frameMs or 16.6
		m.budgets = m.budgets or {}
		m.budgets.drawCalls = m.budgets.drawCalls or 900
		m.budgets.parts = m.budgets.parts or 12000
		m.budgets.memoryMB = m.budgets.memoryMB or 1200
		m.budgets.particles = m.budgets.particles or 1600
		m.scriptMs = m.scriptMs or 0
		m.physicsMs = m.physicsMs or 0
		m.aiMs = m.aiMs or 0
		m.drawCalls = m.drawCalls or 0
		m.parts = m.parts or 0
		m.memoryMB = m.memoryMB or 0
		m.particles = m.particles or 0

		local findings = {}
		for _, sig in ipairs(Bottleneck.SIGNATURES) do
			local ok, hit = pcall(sig.when, m)
			if ok and hit then
				local severity = 1
				if sig.id == "cpu-scripts" then severity = m.scriptMs / math.max(m.frameMs, 1e-3)
				elseif sig.id == "gpu-drawcalls" then severity = m.drawCalls / math.max(m.budgets.drawCalls, 1)
				elseif sig.id == "memory" then severity = m.memoryMB / math.max(m.budgets.memoryMB, 1)
				elseif sig.id == "geometry" then severity = m.parts / math.max(m.budgets.parts, 1) end
				findings[#findings + 1] = { id = sig.id, diagnosis = sig.diagnosis, actions = sig.actions,
					severity = severity }
			end
		end
		table.sort(findings, function(a, b) return a.severity > b.severity end)
		self.detections = self.detections + #findings
		self.history[#self.history + 1] = { count = #findings, top = findings[1] and findings[1].id }
		if #self.history > 240 then table.remove(self.history, 1) end
		return findings
	end

	-- build an executable optimization plan (consumed by the Singularity optimizer agent)
	function Bottleneck:plan(findings, aggressiveness)
		local a = aggressiveness or 0.5
		local plan = { steps = {}, expectedGainMs = 0 }
		for rank, f in ipairs(findings) do
			for i, action in ipairs(f.actions) do
				local weight = (1 / rank) * (1 / i) * f.severity
				if weight > (0.12 * (1 - a)) then
					plan.steps[#plan.steps + 1] = { target = f.id, action = action, weight = weight,
						reversible = true, order = #plan.steps + 1 }
					plan.expectedGainMs = plan.expectedGainMs + weight * 0.9
				end
			end
		end
		table.sort(plan.steps, function(x, y) return x.weight > y.weight end)
		return plan
	end

	function Bottleneck:trend()
		local counts = {}
		for _, h in ipairs(self.history) do
			if h.top then counts[h.top] = (counts[h.top] or 0) + 1 end
		end
		local list = {}
		for id, n in pairs(counts) do list[#list + 1] = { id = id, frames = n } end
		table.sort(list, function(a, b) return a.frames > b.frames end)
		return list
	end

	return Bottleneck

end
