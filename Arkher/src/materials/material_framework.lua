-- ARKHER MATERIALS :: Material Framework
-- The ARKHER answer to "Roblox has no user shaders": a real layered PBR material system
-- with a library, presets, procedural wear, atlas-backed detail and device-tiered quality.
-- Everything here resolves to plain numbers; the platform adapter decides how to show them.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Noise = A:import("arkher/kernel/noise")
	local Random = A:import("arkher/kernel/random")
	local Hash = A:import("arkher/kernel/hash")
	local Signal = A:import("arkher/kernel/signal")

	local MaterialFramework = {}
	MaterialFramework.__index = MaterialFramework

	-- Physically plausible starting points. Roughness/metallic follow the usual PBR ranges;
	-- albedo values stay inside the 30-240 sRGB window real surfaces occupy.
	MaterialFramework.PRESETS = {
		concrete = { albedo = 0x9A9A94, roughness = 0.92, metallic = 0.0, texels = 262144 },
		asphalt  = { albedo = 0x3B3B3E, roughness = 0.88, metallic = 0.0, texels = 262144 },
		brick    = { albedo = 0x8C4A32, roughness = 0.85, metallic = 0.0, texels = 262144 },
		wood     = { albedo = 0x8A5A32, roughness = 0.62, metallic = 0.0, texels = 262144 },
		steel    = { albedo = 0xB8BCC2, roughness = 0.28, metallic = 1.0, texels = 131072 },
		copper   = { albedo = 0xB87333, roughness = 0.32, metallic = 1.0, texels = 131072 },
		glass    = { albedo = 0xD8E6F0, roughness = 0.05, metallic = 0.0, opacity = 0.25, texels = 65536 },
		plastic  = { albedo = 0xC8C8CC, roughness = 0.45, metallic = 0.0, texels = 65536 },
		fabric   = { albedo = 0x5A6070, roughness = 0.95, metallic = 0.0, texels = 131072 },
		leather  = { albedo = 0x4A3226, roughness = 0.72, metallic = 0.0, texels = 131072 },
		skin     = { albedo = 0xC8907A, roughness = 0.55, metallic = 0.0, texels = 262144 },
		grass    = { albedo = 0x4C7A32, roughness = 0.96, metallic = 0.0, texels = 131072 },
		dirt     = { albedo = 0x6B5236, roughness = 0.94, metallic = 0.0, texels = 131072 },
		sand     = { albedo = 0xC2AE82, roughness = 0.9, metallic = 0.0, texels = 131072 },
		rock     = { albedo = 0x6E6E68, roughness = 0.88, metallic = 0.0, texels = 262144 },
		snow     = { albedo = 0xE8EEF5, roughness = 0.55, metallic = 0.0, texels = 131072 },
		water    = { albedo = 0x2C5A78, roughness = 0.06, metallic = 0.0, opacity = 0.55, texels = 65536 },
		gold     = { albedo = 0xD4AF37, roughness = 0.22, metallic = 1.0, texels = 65536 },
	}

	-- Quality tiers are budgets, not adjectives: each is a texel ceiling and a layer ceiling.
	MaterialFramework.TIERS = {
		mobile  = { texelBudget = 1048576, maxLayers = 3, detail = 0.5, normals = false },
		tablet  = { texelBudget = 2097152, maxLayers = 4, detail = 0.7, normals = true },
		desktop = { texelBudget = 8388608, maxLayers = 6, detail = 1.0, normals = true },
		console = { texelBudget = 6291456, maxLayers = 6, detail = 0.9, normals = true },
		vr      = { texelBudget = 4194304, maxLayers = 4, detail = 0.8, normals = true },
	}

	function MaterialFramework.new(opts)
		opts = opts or {}
		local self = setmetatable({}, MaterialFramework)
		self.materials = {}
		self.order = {}
		self.tier = opts.tier or "mobile"
		self.sampler = Kits.create("sampler", { id = "material.detail", atlasSize = opts.atlasSize or 256 })
		self.graphs = {}
		self.cache = Kits.create("cache", { id = "material.resolve", policy = "lru", capacity = 512 })
		self.budget = Kits.create("budgeter", { id = "material.memory",
			total = self:tierConfig().texelBudget, strategy = "priority" })
		self.onChange = Signal.new("materials.change")
		self.resolves = 0
		return self
	end

	function MaterialFramework:tierConfig()
		return MaterialFramework.TIERS[self.tier] or MaterialFramework.TIERS.mobile
	end

	function MaterialFramework:setTier(tier)
		self.tier = tier
		self.budget = Kits.create("budgeter", { id = "material.memory",
			total = self:tierConfig().texelBudget, strategy = "priority" })
		for _, id in ipairs(self.order) do self:enforceTier(id) end
		self.onChange:fire({ action = "tier", tier = tier })
		return self:tierConfig()
	end

	-- ------------------------------------------------------------------ authoring
	function MaterialFramework:define(id, opts)
		opts = opts or {}
		if self.materials[id] then return nil, "duplicate material" end
		local mat = Kits.create("material", { id = id, texelBudget = self:tierConfig().texelBudget })
		local preset = MaterialFramework.PRESETS[opts.preset or id]
		mat.addLayer("base", preset and {
			albedo = preset.albedo, roughness = preset.roughness, metallic = preset.metallic,
			opacity = preset.opacity or 1.0, texels = preset.texels, weight = 1.0,
		} or { albedo = opts.albedo or 0x808080, roughness = opts.roughness or 0.8,
			metallic = opts.metallic or 0, weight = 1.0 })
		self.materials[id] = { id = id, material = mat, preset = opts.preset or id,
			tags = opts.tags or {}, priority = opts.priority or 5 }
		self.order[#self.order + 1] = id
		self.onChange:fire({ action = "define", id = id })
		return mat
	end

	function MaterialFramework:get(id)
		local entry = self.materials[id]
		if not entry then return nil end
		return entry.material
	end

	-- Hyperrealism rule #1 from docs/HYPERREALISM.md: nothing in reality is uniform.
	-- Wear, dust, moisture and edge damage are layers driven by procedural masks.
	function MaterialFramework:addWear(id, kind, amount)
		local mat = self:get(id)
		if not mat then return nil, "unknown material" end
		amount = Mathx.clamp(amount or 0.35, 0, 1)
		local seed = Hash.fnv1a(id .. kind) % 100000
		local masks = {
			dust = function(ctx)
				local n = Noise.value2D((ctx.u or 0) * 8, (ctx.v or 0) * 8, seed)
				return amount * (0.5 + 0.5 * n) * (1 - (ctx.slope or 0))
			end,
			grime = function(ctx)
				local n = Noise.value2D((ctx.u or 0) * 3, (ctx.v or 0) * 3, seed)
				return amount * n * (ctx.occlusion or 0.6)
			end,
			edgewear = function(ctx)
				return amount * Mathx.clamp((ctx.curvature or 0) * 2, 0, 1)
			end,
			moisture = function(ctx)
				return amount * Mathx.clamp(ctx.wetness or 0, 0, 1)
			end,
			rust = function(ctx)
				local n = Noise.value2D((ctx.u or 0) * 5, (ctx.v or 0) * 5, seed + 7)
				return amount * n * Mathx.clamp((ctx.wetness or 0) + (ctx.age or 0.4), 0, 1)
			end,
			snowcover = function(ctx)
				return amount * Mathx.clamp(1 - (ctx.slope or 0) * 2.5, 0, 1)
			end,
		}
		local looks = {
			dust     = { albedo = 0xA8A093, roughness = 0.96, metallic = 0.0 },
			grime    = { albedo = 0x2E2A26, roughness = 0.9, metallic = 0.0 },
			edgewear = { albedo = 0xBFC3C8, roughness = 0.35, metallic = 0.85 },
			moisture = { albedo = 0x2A2F36, roughness = 0.12, metallic = 0.0 },
			rust     = { albedo = 0x8A4326, roughness = 0.95, metallic = 0.0 },
			snowcover = { albedo = 0xE8EEF5, roughness = 0.6, metallic = 0.0 },
		}
		if not masks[kind] then return nil, "unknown wear kind: " .. tostring(kind) end
		local look = looks[kind]
		local layer = mat.addLayer(kind, { albedo = look.albedo, roughness = look.roughness,
			metallic = look.metallic, weight = amount, mask = masks[kind], texels = 65536 })
		self:enforceTier(id)
		return layer
	end

	-- Keep every material inside the tier's layer ceiling, dropping the lightest layers.
	function MaterialFramework:enforceTier(id)
		local mat = self:get(id)
		if not mat then return 0 end
		local maxLayers = self:tierConfig().maxLayers
		local dropped = 0
		while #mat.order > maxLayers do
			local lightest, weight = nil, math.huge
			for _, layerId in ipairs(mat.order) do
				local l = mat.layers[layerId]
				if layerId ~= "base" and l.weight < weight then
					weight = l.weight
					lightest = layerId
				end
			end
			if not lightest then break end
			mat.removeLayer(lightest)
			dropped = dropped + 1
		end
		return dropped
	end

	-- ------------------------------------------------------------------ shading graphs
	-- A material may own a shade graph that computes context-dependent parameters and
	-- compiles to Luau the adapter can run directly.
	function MaterialFramework:attachGraph(id)
		if not self.materials[id] then return nil, "unknown material" end
		local g = Kits.create("shadegraph", { id = id .. ".graph" })
		g.addNode("wetness", "input", { key = "wetness", default = 0 })
		g.addNode("baseRough", "input", { key = "roughness", default = 0.8 })
		g.addNode("wetRough", "constant", { value = 0.08 })
		g.addNode("blend", "mix", { factor = 0.85 })
		g.addNode("sat", "saturate")
		g.addNode("out", "output", { channel = "roughness" })
		g.connect("baseRough", "blend", 1)
		g.connect("wetRough", "blend", 2)
		g.connect("blend", "sat", 1)
		g.connect("sat", "out", 1)
		self.graphs[id] = g
		return g
	end

	function MaterialFramework:compileGraph(id)
		local g = self.graphs[id]
		if not g then return nil, "no graph attached" end
		g.fold()
		return g.compile()
	end

	-- ------------------------------------------------------------------ resolve
	function MaterialFramework:resolve(id, ctx)
		local entry = self.materials[id]
		if not entry then return nil, "unknown material" end
		self.resolves = self.resolves + 1
		local params = entry.material.resolve(ctx)
		local graph = self.graphs[id]
		if graph then
			local out = graph.evaluate({ wetness = (ctx and ctx.wetness) or 0, roughness = params.roughness })
			if out.roughness then params.roughness = out.roughness end
		end
		if not self:tierConfig().normals then params.normalStrength = 0 end
		params.detail = self:tierConfig().detail
		return params
	end

	-- Distance-aware resolve: the version a renderer actually calls per draw.
	function MaterialFramework:resolveForDistance(id, ctx, distance)
		local params = self:resolve(id, ctx)
		if not params then return nil end
		local mat = self:get(id)
		local lod = mat.lodParams(distance)
		params.lod = lod.level
		params.normalStrength = params.normalStrength * (lod.normalStrength or 1)
		params.uvScale = params.uvScale * (lod.uvDetail or 1)
		return params
	end

	-- ------------------------------------------------------------------ detail atlas
	function MaterialFramework:bakeDetail(id, size)
		local entry = self.materials[id]
		if not entry then return nil, "unknown material" end
		size = size or 16
		local seed = Hash.fnv1a(id) % 65536
		local tex = self.sampler.defineTexture(id, size, size, function(u, v)
			local base = Noise.fbm(Noise.field("perlin"), u * 6, v * 6,
				{ octaves = 3, frequency = 1, seed = seed })
			return Mathx.clamp(0.5 + base * 0.5, 0, 1)
		end)
		if not tex then return nil, "already baked" end
		self.sampler.pack(id)
		self.sampler.buildMips(id)
		return tex
	end

	function MaterialFramework:detailAt(id, u, v, lod)
		return self.sampler.sampleLod(id, u, v, lod or 0)
	end

	-- ------------------------------------------------------------------ budgets & reports
	function MaterialFramework:memoryBytes()
		local total = 0
		for _, id in ipairs(self.order) do total = total + self.materials[id].material.memoryBytes() end
		return total + self.sampler.residentBytes()
	end

	function MaterialFramework:withinBudget()
		return self:memoryBytes() <= self:tierConfig().texelBudget * 4
	end

	-- Shed memory until the tier budget is met, cheapest-priority materials first.
	function MaterialFramework:compact()
		local removed = 0
		local sorted = {}
		for _, id in ipairs(self.order) do sorted[#sorted + 1] = id end
		table.sort(sorted, function(a, b)
			return self.materials[a].priority < self.materials[b].priority
		end)
		local i = 1
		while not self:withinBudget() and i <= #sorted do
			local mat = self:get(sorted[i])
			if #mat.order > 1 then
				local victim = mat.order[#mat.order]
				if victim ~= "base" then
					mat.removeLayer(victim)
					removed = removed + 1
				else
					i = i + 1
				end
			else
				i = i + 1
			end
		end
		return removed
	end

	function MaterialFramework:checksum()
		local parts = {}
		for _, id in ipairs(self.order) do
			parts[#parts + 1] = id .. ":" .. tostring(self.materials[id].material.checksum())
		end
		return Hash.fnv1a(table.concat(parts, "|"))
	end

	function MaterialFramework:report()
		local layers = 0
		for _, id in ipairs(self.order) do layers = layers + #self:get(id).order end
		return {
			materials = #self.order, layers = layers, tier = self.tier,
			memoryBytes = self:memoryBytes(), withinBudget = self:withinBudget(),
			graphs = 0 + (function()
				local n = 0
				for _ in pairs(self.graphs) do n = n + 1 end
				return n
			end)(),
			atlasOccupancy = self.sampler.occupancy(), resolves = self.resolves,
			checksum = self:checksum(),
		}
	end

	-- Build a standard starter library so a project is never empty.
	function MaterialFramework:installStandardLibrary()
		local installed = 0
		for name in pairs(MaterialFramework.PRESETS) do
			if not self.materials[name] then
				self:define(name, { preset = name })
				installed = installed + 1
			end
		end
		return installed
	end

	return MaterialFramework
end
