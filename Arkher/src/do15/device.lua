-- ARKHER D-O15 :: Device Intelligence
-- Classifies the host device and derives an initial quality contract. Mobile-first:
-- every tier is defined by measured budgets, not guesses.
--@arkher-module
return function(A)
	local Device = {}

	-- Tier contracts: what ARKHER promises to keep within on each class of hardware.
	Device.TIERS = {
		{ id = "potato", label = "Low-end mobile", score = 0,
		  budgets = { frameMs = 22, drawCalls = 250, parts = 2500, particles = 300, lights = 4,
			  npcs = 24, memoryMB = 380, streamRadius = 240, shadowDistance = 0, textureRes = 256 } },
		{ id = "mobile", label = "Mainstream mobile", score = 25,
		  budgets = { frameMs = 16.6, drawCalls = 500, parts = 6000, particles = 800, lights = 8,
			  npcs = 60, memoryMB = 700, streamRadius = 380, shadowDistance = 60, textureRes = 512 } },
		{ id = "mobileHigh", label = "Flagship mobile / tablet", score = 45,
		  budgets = { frameMs = 16.6, drawCalls = 900, parts = 12000, particles = 1600, lights = 14,
			  npcs = 120, memoryMB = 1200, streamRadius = 520, shadowDistance = 120, textureRes = 1024 } },
		{ id = "desktop", label = "Desktop", score = 65,
		  budgets = { frameMs = 13.9, drawCalls = 1800, parts = 24000, particles = 3500, lights = 28,
			  npcs = 260, memoryMB = 2400, streamRadius = 800, shadowDistance = 240, textureRes = 1024 } },
		{ id = "console", label = "Console", score = 75,
		  budgets = { frameMs = 16.6, drawCalls = 2200, parts = 28000, particles = 4000, lights = 32,
			  npcs = 320, memoryMB = 3000, streamRadius = 900, shadowDistance = 280, textureRes = 1024 } },
		{ id = "desktopHigh", label = "High-end desktop", score = 88,
		  budgets = { frameMs = 8.3, drawCalls = 3600, parts = 45000, particles = 8000, lights = 64,
			  npcs = 600, memoryMB = 4500, streamRadius = 1400, shadowDistance = 420, textureRes = 2048 } },
		{ id = "vr", label = "VR", score = 80,
		  budgets = { frameMs = 8.3, drawCalls = 1400, parts = 18000, particles = 2000, lights = 20,
			  npcs = 180, memoryMB = 2200, streamRadius = 600, shadowDistance = 160, textureRes = 1024 } },
	}

	function Device.score(profile)
		local s = 0
		local classScore = { phone = 18, tablet = 40, desktop = 62, console = 74, vr = 78, virtual = 55 }
		s = s + (classScore[profile.class] or 40)
		s = s + math.min(20, (profile.memoryMB or 1024) / 400)
		s = s + math.min(12, (profile.cores or 2) * 2)
		s = s + math.min(14, (profile.gpuTier or 1) * 5)
		local px = (profile.screen and profile.screen.width or 1280) * (profile.screen and profile.screen.height or 720)
		if px > 2200000 then s = s - 6 elseif px < 800000 then s = s + 3 end
		return math.max(0, math.min(100, s))
	end

	function Device.classify(profile)
		if profile.vr or profile.class == "vr" then return Device.TIERS[7] end
		local s = Device.score(profile)
		local best = Device.TIERS[1]
		for _, t in ipairs(Device.TIERS) do
			if s >= t.score and t.id ~= "vr" then best = t end
		end
		return best, s
	end

	function Device.budgets(profile)
		local tier = Device.classify(profile)
		local b = {}
		for k, v in pairs(tier.budgets) do b[k] = v end
		-- Mobile-first refinement: thermal headroom and battery awareness.
		if profile.class == "phone" then
			b.frameMs = math.max(b.frameMs, 16.6)
			b.thermalHeadroom = 0.8
			b.batteryAware = true
		else
			b.thermalHeadroom = 1.0
			b.batteryAware = false
		end
		b.tier = tier.id
		return b
	end

	function Device.qualityPreset(tierId)
		local presets = {
			potato = { renderScale = 0.62, shadows = false, reflections = false, gi = "flat", vfxDensity = 0.25,
				lodBias = 1.9, animationRate = 20, physicsRate = 20, npcTickRate = 3, textureRes = 256, aa = "none" },
			mobile = { renderScale = 0.78, shadows = "low", reflections = false, gi = "probe-lite", vfxDensity = 0.45,
				lodBias = 1.5, animationRate = 30, physicsRate = 30, npcTickRate = 6, textureRes = 512, aa = "temporal-lite" },
			mobileHigh = { renderScale = 0.9, shadows = "medium", reflections = "planar-lite", gi = "probe", vfxDensity = 0.7,
				lodBias = 1.2, animationRate = 45, physicsRate = 45, npcTickRate = 10, textureRes = 1024, aa = "temporal" },
			desktop = { renderScale = 1.0, shadows = "high", reflections = "ssr-lite", gi = "probe+", vfxDensity = 1.0,
				lodBias = 1.0, animationRate = 60, physicsRate = 60, npcTickRate = 15, textureRes = 1024, aa = "temporal" },
			console = { renderScale = 1.0, shadows = "high", reflections = "ssr-lite", gi = "probe+", vfxDensity = 1.0,
				lodBias = 1.0, animationRate = 60, physicsRate = 60, npcTickRate = 15, textureRes = 1024, aa = "temporal" },
			desktopHigh = { renderScale = 1.0, shadows = "ultra", reflections = "ssr", gi = "probe-volumetric", vfxDensity = 1.4,
				lodBias = 0.8, animationRate = 90, physicsRate = 60, npcTickRate = 24, textureRes = 2048, aa = "temporal+" },
			vr = { renderScale = 0.95, shadows = "medium", reflections = false, gi = "probe", vfxDensity = 0.6,
				lodBias = 1.1, animationRate = 90, physicsRate = 90, npcTickRate = 12, textureRes = 1024, aa = "temporal-vr" },
		}
		return presets[tierId] or presets.mobile
	end

	function Device.describe(profile)
		local tier, score = Device.classify(profile)
		return {
			class = profile.class, tier = tier.id, label = tier.label, score = score,
			budgets = Device.budgets(profile), quality = Device.qualityPreset(tier.id),
			inputs = { touch = profile.touch, keyboard = profile.keyboard, gamepad = profile.gamepad, vr = profile.vr },
		}
	end

	return Device

end
