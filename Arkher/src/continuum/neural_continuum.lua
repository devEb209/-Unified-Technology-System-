-- ARKHER V2 Continuum :: Neural Continuum
-- On-device neural reconstruction continuum: the engine renders at a virtual scale
-- chosen by a tiny field, upscales temporally, and keeps quality continuous across
-- devices via quantized weights that never leave the adapter budget.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")

	local NeuralContinuum = {}
	NeuralContinuum.__index = NeuralContinuum

	function NeuralContinuum.new(cfg)
		cfg = cfg or {}
		local self = setmetatable({}, NeuralContinuum)
		self.id = cfg.id or "neural.continuum"
		self.field = Kits.neuralfield({ id = self.id .. ".field", dims = cfg.dims or 16, hidden = cfg.hidden or 12, seed = cfg.seed or 1337 })
		self.temporal = Kits.epoch({ id = self.id .. ".temporal", tickRate = 60 })
		self.coherence = Kits.coherence({ id = self.id .. ".coherence", window = 48 })
		self.scales = { 0.55, 0.67, 0.78, 0.85, 1.0 }
		self.currentScale = 0.78
		self.frameHistory = {}
		self.maxHistory = 8
		self.deviceClass = cfg.deviceClass or "mobile"
		self.budgetMs = cfg.budgetMs or 16.6
		return self
	end

	function NeuralContinuum:measureFrame(ms)
		self.frameHistory[#self.frameHistory+1] = ms
		if #self.frameHistory > self.maxHistory then table.remove(self.frameHistory, 1) end
		-- temporal smoothing
		local avg = 0
		for _, v in ipairs(self.frameHistory) do avg = avg + v end
		avg = avg / math.max(1, #self.frameHistory)
		-- encoded input is (avg/budget, history variance, scale)
		local enc = self.field.encode(avg / math.max(1, self.budgetMs), self.currentScale)
		local predicted = self.field.infer(enc) -- 0..1
		-- map predicted to scale index
		local idx = math.floor(Mathx.clamp(predicted * #self.scales + 0.5, 1, #self.scales))
		local chosen = self.scales[idx]
		-- hysteresis: don't jump more than one step per frame
		local curIdx = 1
		for i, s in ipairs(self.scales) do if math.abs(s - self.currentScale) < 0.01 then curIdx = i break end end
		if math.abs(idx - curIdx) > 1 then
			if idx > curIdx then chosen = self.scales[curIdx + 1] else chosen = self.scales[curIdx - 1] end
		end
		self.currentScale = chosen
		self.temporal.advance(1/60)
		local coherence = self.coherence.observe({ coherence = 1 - math.abs(avg - self.budgetMs)/self.budgetMs, drift = self.temporal.drift(), cost = avg, budget = self.budgetMs })
		return { scale = chosen, predicted = predicted, avg = avg, coherence = coherence }
	end

	function NeuralContinuum:trainForDevice(deviceClass)
		-- synthetic dataset: frameCost -> ideal scale is inverse (high cost -> low scale)
		local function ideal(x)
			-- x in -1..1 maps to cost 8..30
			local cost = 8 + (x+1)*11
			if cost < 11 then return 1.0
			elseif cost < 14 then return 0.85
			elseif cost < 18 then return 0.78
			elseif cost < 22 then return 0.67
			else return 0.55 end
		end
		local ds = self.field.generateDataset(96, ideal)
		local loss = self.field.train(ds, 12)
		self.deviceClass = deviceClass or self.deviceClass
		return loss
	end

	function NeuralContinuum:quantizeAndExport(bits)
		bits = bits or 8
		local q = self.field.quantize(bits)
		return { bits = bits, quantized = q, weights = self.field.exportWeights(), class = self.deviceClass, scale = self.currentScale, scaleTable = q }
	end

	function NeuralContinuum:reconstruct(inputSamples)
		-- temporal accumulation: blend last N frames by variance clipping
		if #inputSamples == 0 then return 0 end
		local sum, sum2 = 0, 0
		for _, v in ipairs(inputSamples) do sum = sum + v sum2 = sum2 + v*v end
		local mean = sum / #inputSamples
		local variance = math.max(0, sum2 / #inputSamples - mean*mean)
		-- clip variance
		local clipped = Mathx.clamp(variance, 0, 0.15)
		-- reconstruction = mean biased toward currentScale
		local recon = mean * (0.72 + 0.28 * self.currentScale) + (1 - clipped) * 0.02
		return Mathx.clamp(recon, 0, 1)
	end

	function NeuralContinuum:report()
		return {
			scale = self.currentScale,
			loss = self.field.stats().loss,
			trained = self.field.stats().trained,
			temporal = self.temporal.stats(),
			coherence = self.coherence.score(),
			coherenceStats = self.coherence.stats(),
			device = self.deviceClass
		}
	end

	return NeuralContinuum
end
