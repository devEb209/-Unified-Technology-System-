-- ARKHER NEURAL :: Reconstruction & Temporal Intelligence Framework
-- ARKHER's own reconstruction stack (never a bolted-on vendor upscaler): a small trained
-- network predicts the render scale and sharpening that will hit the frame target, a
-- temporal resolver reuses history under motion, and every decision has a measured fallback.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Random = A:import("arkher/kernel/random")

	local Reconstruction = {}
	Reconstruction.__index = Reconstruction

	function Reconstruction.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Reconstruction)
		self.upscaler = Kits.create("upscaler", { id = "neural.scale",
			targetMs = opts.targetMs or 16.6, index = opts.index or 4,
			sharpness = opts.sharpness or 0.35 })
		self.temporal = Kits.create("temporal", { id = "neural.taa",
			feedback = opts.feedback or 0.88, phase = opts.phase or 8 })
		self.net = Kits.create("inference", { id = "neural.policy", seed = opts.seed or 7331 })
		self.net.addLayer(4, 8, "tanh")
		self.net.addLayer(8, 2, "sigmoid")
		self.trained = false
		self.frames = 0
		self.history = {}
		self.mode = opts.mode or "balanced"
		self.fallbacks = 0
		self.targetMs = opts.targetMs or 16.6
		return self
	end

	-- ------------------------------------------------------------------ training
	-- The policy is trained on a synthetic, deterministic dataset that encodes the physics
	-- of the trade: heavier frames want a lower scale; more motion wants less sharpening.
	function Reconstruction:buildDataset(count)
		count = count or 96
		local rng = Random.new(20260907)
		local samples = {}
		for _ = 1, count do
			local frameMs = rng:range(6, 40)
			local motion = rng:range(0, 24)
			local complexity = rng:range(0, 1)
			local battery = rng:range(0.2, 1)
			local load = Mathx.clamp(frameMs / (self.targetMs * 2), 0, 1)
			-- target scale: drop with load and complexity, recover with headroom and battery
			local scale = Mathx.clamp(1.05 - load * 0.85 - complexity * 0.15 + battery * 0.12, 0.35, 1.0)
			-- target sharpening: more when upscaling harder, less under fast motion
			local sharpen = Mathx.clamp((1 - scale) * 1.2 - motion / 60, 0.0, 0.85)
			samples[#samples + 1] = {
				input = { frameMs / 40, motion / 24, complexity, battery },
				target = { scale, sharpen },
			}
		end
		return samples
	end

	function Reconstruction:train(epochs, lr)
		local samples = self:buildDataset(96)
		local loss = self.net.train(samples, epochs or 220, lr or 0.35)
		self.trained = true
		self.trainingLoss = loss
		return loss
	end

	function Reconstruction:ensureTrained()
		if not self.trained then self:train() end
		return self.trained
	end

	-- ------------------------------------------------------------------ policy
	-- Predict the settings for the next frame from measured features.
	function Reconstruction:predict(features)
		self:ensureTrained()
		features = features or {}
		local input = {
			Mathx.clamp((features.frameMs or self.targetMs) / 40, 0, 1),
			Mathx.clamp((features.motion or 0) / 24, 0, 1),
			Mathx.clamp(features.complexity or 0.5, 0, 1),
			Mathx.clamp(features.battery or 1, 0, 1),
		}
		local out = self.net.forward(input)
		return { scale = Mathx.clamp(out[1], 0.35, 1.0), sharpen = Mathx.clamp(out[2], 0, 0.85) }
	end

	-- Apply the prediction through the ladder so the scale never jitters frame to frame.
	function Reconstruction:apply(features)
		local prediction = self:predict(features)
		local ladder = self.upscaler.ladder
		local bestIndex, bestDelta = 1, math.huge
		for i, s in ipairs(ladder) do
			local delta = math.abs(s - prediction.scale)
			if delta < bestDelta then bestDelta = delta bestIndex = i end
		end
		-- move at most one step per frame: stability beats accuracy here
		if bestIndex > self.upscaler.index then
			self.upscaler.index = self.upscaler.index + 1
		elseif bestIndex < self.upscaler.index then
			self.upscaler.index = self.upscaler.index - 1
		end
		self.upscaler.sharpness = prediction.sharpen
		return { scale = self.upscaler.scale(), sharpen = prediction.sharpen,
			predicted = prediction.scale, index = self.upscaler.index }
	end

	-- ------------------------------------------------------------------ per-frame work
	function Reconstruction:beginFrame()
		self.frames = self.frames + 1
		self.temporal.advance()
		local jx, jy = self.temporal.jitter(self.frames)
		return { frame = self.frames, jitterX = jx, jitterY = jy, scale = self.upscaler.scale() }
	end

	-- Resolve a scanline of low-resolution samples into display resolution:
	-- reconstruct -> temporal accumulate -> sharpen. Real arithmetic, measurable output.
	function Reconstruction:resolveLine(key, samples, targetCount, opts)
		opts = opts or {}
		local reconstructed = self.upscaler.reconstruct(samples, targetCount)
		local resolved = {}
		for i, value in ipairs(reconstructed) do
			local neighbors = {}
			if i > 1 then neighbors[#neighbors + 1] = reconstructed[i - 1] end
			if i < #reconstructed then neighbors[#neighbors + 1] = reconstructed[i + 1] end
			resolved[i] = self.temporal.resolve(key .. ":" .. i, value,
				{ motion = opts.motion or 0, velocity = opts.velocity or 0, neighbors = neighbors })
		end
		if self.upscaler.sharpness > 0.01 then
			resolved = self.upscaler.sharpen(resolved, self.upscaler.sharpness)
		end
		return resolved
	end

	-- ------------------------------------------------------------------ quality accounting
	-- Effective resolution: what the temporal accumulation is really buying us.
	function Reconstruction:effectiveScale(key)
		local base = self.upscaler.scale()
		local samples = self.temporal.effectiveSamples(key or "0:1")
		local gain = math.min(1.35, math.sqrt(math.max(1, samples)) * 0.5 + 0.5)
		return math.min(1.0, base * gain)
	end

	function Reconstruction:quality()
		return Mathx.clamp(self.upscaler.quality() * (1 - self.temporal.stats().ghosting /
			math.max(1, self.temporal.stats().resolves) * 0.5), 0, 1)
	end

	-- Hard fallback: when history is useless (teleport, camera cut, resize) we drop
	-- everything temporal rather than smear the frame.
	function Reconstruction:invalidate(reason)
		self.temporal.reset()
		self.fallbacks = self.fallbacks + 1
		self.lastFallback = reason or "invalidate"
		return true
	end

	function Reconstruction:onCameraCut() return self:invalidate("camera-cut") end

	function Reconstruction:pixelsSaved(width, height)
		return self.upscaler.savings(width, height)
	end

	function Reconstruction:report()
		local t = self.temporal.stats()
		return {
			frames = self.frames, scale = self.upscaler.scale(),
			sharpness = self.upscaler.sharpness, quality = self:quality(),
			trained = self.trained, trainingLoss = self.trainingLoss,
			parameters = self.net.parameters(), flops = self.net.flops(),
			netMemoryBytes = self.net.memoryBytes(),
			historyEntries = t.tracked, rejections = t.rejections, ghosting = t.ghosting,
			fallbacks = self.fallbacks, lastFallback = self.lastFallback,
			effectiveScale = self:effectiveScale(),
		}
	end

	-- Ship the trained policy as data: quantized weights an adapter can load at boot
	-- without ever running the trainer on a phone.
	function Reconstruction:exportPolicy(bits)
		self:ensureTrained()
		local error_ = self.net.quantize(bits or 8)
		return { weights = self.net.exportWeights(), bits = bits or 8,
			quantError = error_, parameters = self.net.parameters(),
			bytes = self.net.memoryBytes() }
	end

	function Reconstruction:importPolicy(policy)
		if not policy or not policy.weights then return false end
		local n = self.net.importWeights(policy.weights)
		self.trained = true
		return n == self.net.parameters()
	end

	return Reconstruction
end
