-- ARKHER ASSETS :: Pipeline
-- The whole road an asset travels: import and validation, dependency resolution, LOD and
-- mip derivation, platform-specific cooking with real byte budgets, bundling, and a
-- manifest that a device can diff against what it already holds. Mobile is the default
-- target, not an afterthought - every cook step is measured against a phone budget.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Hash = A:import("arkher/kernel/hash")
	local Signal = A:import("arkher/kernel/signal")

	local Pipeline = {}
	Pipeline.__index = Pipeline

	local PROFILES = {
		mobile = { textureMax = 1024, triangleBudget = 8000, audioSeconds = 30,
			lodLevels = 4, compression = 0.45, memoryMb = 320 },
		pc = { textureMax = 4096, triangleBudget = 120000, audioSeconds = 240,
			lodLevels = 3, compression = 0.7, memoryMb = 3072 },
		console = { textureMax = 2048, triangleBudget = 60000, audioSeconds = 180,
			lodLevels = 3, compression = 0.6, memoryMb = 2048 },
		vr = { textureMax = 2048, triangleBudget = 24000, audioSeconds = 120,
			lodLevels = 4, compression = 0.5, memoryMb = 1024 },
	}

	function Pipeline.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Pipeline)
		self.importer = Kits.create("importer", { id = "assets.importer",
			unitScale = opts.unitScale or 1 })
		self.bundler = Kits.create("bundler", { id = "assets.bundler",
			maxBundleBytes = opts.maxBundleBytes or 2 * 1024 * 1024 })
		self.cache = Kits.create("cache", { id = "assets.cache", capacity = opts.cache or 128 })
		self.profileName = opts.profile or "mobile"
		self.profile = PROFILES[self.profileName] or PROFILES.mobile
		self.cooked = {}
		self.cookOrder = {}
		self.rejects = {}
		self.onImport = Signal.new()
		self.onCook = Signal.new()
		self.importer.installDefaults()
		self.stages = { "import", "resolve", "derive", "cook", "bundle", "manifest" }
		self.stageTimes = {}
		return self
	end

	function Pipeline:setProfile(name)
		self.profile = PROFILES[name] or self.profile
		self.profileName = PROFILES[name] and name or self.profileName
		return self.profile
	end

	function Pipeline:profiles()
		local out = {}
		for name in pairs(PROFILES) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	-- ------------------------------------------------------------------ import
	function Pipeline:add(typeName, descriptor, dependencies)
		local asset, errors, note = self.importer.import(typeName, descriptor, dependencies)
		if not asset then
			self.rejects[#self.rejects + 1] = { descriptor = descriptor, errors = errors }
			return nil, errors
		end
		self.onImport:fire({ id = asset.id, type = asset.type, duplicate = note == "duplicate" })
		return asset, nil, note
	end

	function Pipeline:resolve()
		local missing = self.importer.missingDependencies()
		local ordered, visited = {}, {}
		local cycle = false
		local function visit(id, stack)
			if cycle or visited[id] then return end
			if stack[id] then cycle = true return end
			stack[id] = true
			local asset = self.importer.get(id)
			if asset then
				for _, dep in ipairs(asset.dependencies) do
					if self.importer.get(dep) then visit(dep, stack) end
				end
			end
			stack[id] = nil
			visited[id] = true
			ordered[#ordered + 1] = id
		end
		for _, id in ipairs(self.importer.order) do visit(id, {}) end
		if cycle then return nil, "cyclic dependencies" end
		return ordered, missing
	end

	-- ------------------------------------------------------------------ derive
	-- LODs are derived from a real triangle count with a halving ratio, and stop when the
	-- next level would be too small to be worth a draw call.
	function Pipeline:deriveLods(id)
		local asset = self.importer.get(id)
		if not asset or asset.type ~= "mesh" then return {} end
		local triangles = asset.data.triangles or 0
		local levels = {}
		local current = triangles
		for level = 0, self.profile.lodLevels - 1 do
			levels[#levels + 1] = { level = level, triangles = math.floor(current),
				screenSize = 1 / (2 ^ level),
				bytes = math.floor((asset.data.bytes or triangles * 36) / (2 ^ level)) }
			current = current * 0.5
			if current < 32 then break end
		end
		asset.lods = levels
		return levels
	end

	function Pipeline:deriveMips(id)
		local asset = self.importer.get(id)
		if not asset or asset.type ~= "texture" then return {} end
		local width = math.min(asset.data.width or 1, self.profile.textureMax)
		local height = math.min(asset.data.height or 1, self.profile.textureMax)
		local mips = {}
		while width >= 1 and height >= 1 do
			mips[#mips + 1] = { width = math.floor(width), height = math.floor(height),
				bytes = math.floor(width * height * 4 * self.profile.compression) }
			if width == 1 and height == 1 then break end
			width = math.max(1, width / 2)
			height = math.max(1, height / 2)
		end
		asset.mips = mips
		return mips
	end

	-- ------------------------------------------------------------------ cook
	function Pipeline:cook(id)
		local asset = self.importer.get(id)
		if not asset then return nil, "unknown asset" end
		local profile = self.profile
		local record = { id = id, type = asset.type, profile = self.profileName,
			warnings = {}, actions = {} }
		local bytes = asset.data.bytes or 0
		if asset.type == "mesh" then
			local lods = self:deriveLods(id)
			local triangles = asset.data.triangles or 0
			if triangles > profile.triangleBudget then
				local ratio = profile.triangleBudget / triangles
				record.actions[#record.actions + 1] = "decimated"
				record.triangles = profile.triangleBudget
				bytes = math.floor(bytes * ratio)
			else
				record.triangles = triangles
			end
			record.lods = #lods
		elseif asset.type == "texture" then
			local mips = self:deriveMips(id)
			local width, height = asset.data.width or 1, asset.data.height or 1
			if width > profile.textureMax or height > profile.textureMax then
				local ratio = profile.textureMax / math.max(width, height)
				record.actions[#record.actions + 1] = "downscaled"
				bytes = math.floor(bytes * ratio * ratio)
				record.width = math.floor(width * ratio)
				record.height = math.floor(height * ratio)
			else
				record.width, record.height = width, height
			end
			record.mips = #mips
		elseif asset.type == "audio" then
			local seconds = asset.data.seconds or 0
			if seconds > profile.audioSeconds then
				record.actions[#record.actions + 1] = "streamed"
				record.streamed = true
				bytes = math.floor(bytes * 0.25)
			end
			record.seconds = seconds
		elseif asset.type == "animation" then
			record.actions[#record.actions + 1] = "compressed"
			bytes = math.floor(bytes * 0.6)
			record.tracks = asset.data.tracks
		end
		record.bytes = math.max(1, math.floor(bytes * profile.compression))
		record.hash = Hash.mix(asset.hash, Hash.fnv1a(self.profileName))
		if not self.cooked[id] then self.cookOrder[#self.cookOrder + 1] = id end
		self.cooked[id] = record
		self.cache.set(id, record, record.bytes)
		self.onCook:fire(record)
		return record
	end

	function Pipeline:cookAll()
		local ordered, missing = self:resolve()
		if not ordered then return nil, missing end
		local count = 0
		for _, id in ipairs(ordered) do
			if self:cook(id) then count = count + 1 end
		end
		return count, missing
	end

	-- ------------------------------------------------------------------ bundle
	function Pipeline:bundle(grouping)
		self.bundler.entries = {}
		self.bundler.order = {}
		for _, id in ipairs(self.cookOrder) do
			local record = self.cooked[id]
			local group = grouping and grouping(id, record) or "core"
			self.bundler.add(id, { bytes = record.bytes, type = record.type,
				group = group, hash = record.hash,
				priority = record.type == "mesh" and 3 or 1 })
		end
		return self.bundler.pack()
	end

	function Pipeline:manifest()
		if #self.bundler.order == 0 then self:bundle() end
		local manifest = self.bundler.manifest()
		manifest.profile = self.profileName
		manifest.assets = #self.cookOrder
		manifest.memoryMb = manifest.totalBytes / (1024 * 1024)
		manifest.withinBudget = manifest.memoryMb <= self.profile.memoryMb
		return manifest
	end

	function Pipeline:patch(previousManifest)
		if #self.bundler.order == 0 then self:bundle() end
		return self.bundler.delta(previousManifest)
	end

	-- ------------------------------------------------------------------ reporting
	function Pipeline:budgetReport()
		local totals = {}
		local grand = 0
		for _, id in ipairs(self.cookOrder) do
			local record = self.cooked[id]
			totals[record.type] = (totals[record.type] or 0) + record.bytes
			grand = grand + record.bytes
		end
		return { byType = totals, totalBytes = grand,
			memoryMb = grand / (1024 * 1024), ceilingMb = self.profile.memoryMb,
			headroom = Mathx.clamp(1 - (grand / (1024 * 1024)) / self.profile.memoryMb, -1, 1) }
	end

	function Pipeline:savings()
		local raw, cooked = 0, 0
		for _, id in ipairs(self.cookOrder) do
			local asset = self.importer.get(id)
			raw = raw + (asset and asset.bytes or 0)
			cooked = cooked + self.cooked[id].bytes
		end
		if raw == 0 then return 0 end
		return 1 - cooked / raw
	end

	function Pipeline:report()
		return { profile = self.profileName, importer = self.importer.stats(),
			bundler = self.bundler.stats(), cooked = #self.cookOrder,
			rejects = #self.rejects, savings = self:savings(),
			budget = self:budgetReport() }
	end

	Pipeline.PROFILES = PROFILES
	return Pipeline
end
