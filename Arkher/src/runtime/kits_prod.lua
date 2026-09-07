-- ARKHER RUNTIME :: Asset Pipeline and Cinematic Kits
-- Round 8 machinery (kits 104-108). The production half of ARKHER: bringing content in,
-- validating and bundling it, and then staging it as a shot - timeline, camera and grade.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3
	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 104. IMPORTER
	-- Asset ingestion: declared types with required fields and unit conventions, real
	-- validation with errors and warnings, normalization into ARKHER units, content
	-- hashing for deduplication, and a dependency list per asset.
	function K.importer(cfg)
		local self = { kind = "importer", id = cfg.id, types = {}, assets = {}, order = {},
			byHash = {}, imported = 0, rejected = 0, duplicates = 0, warnings = 0,
			unitScale = cfg.unitScale or 1 }

		function self.defineType(name, opts)
			opts = opts or {}
			if self.types[name] then return false end
			self.types[name] = { name = name, required = opts.required or {},
				numeric = opts.numeric or {}, maxBytes = opts.maxBytes or math.huge,
				scaleFields = opts.scaleFields or {}, extensions = opts.extensions or {} }
			return true
		end

		function self.installDefaults()
			if C.count(self.types) > 0 then return C.count(self.types) end
			self.defineType("mesh", { required = { "name", "vertices", "triangles" },
				numeric = { "vertices", "triangles", "bytes" }, maxBytes = 8 * 1024 * 1024,
				scaleFields = { "size" }, extensions = { "obj", "fbx", "gltf" } })
			self.defineType("texture", { required = { "name", "width", "height" },
				numeric = { "width", "height", "bytes" }, maxBytes = 4 * 1024 * 1024,
				extensions = { "png", "jpg", "tga" } })
			self.defineType("audio", { required = { "name", "seconds" },
				numeric = { "seconds", "bytes" }, maxBytes = 6 * 1024 * 1024,
				extensions = { "wav", "ogg", "mp3" } })
			self.defineType("animation", { required = { "name", "seconds", "tracks" },
				numeric = { "seconds", "tracks", "bytes" }, extensions = { "fbx", "anim" } })
			return C.count(self.types)
		end

		function self.validate(typeName, descriptor)
			local t = self.types[typeName]
			if not t then return false, { "unknown type: " .. tostring(typeName) } end
			local errors, warnings = {}, {}
			for _, field in ipairs(t.required) do
				if descriptor[field] == nil then errors[#errors + 1] = "missing field: " .. field end
			end
			for _, field in ipairs(t.numeric) do
				local value = descriptor[field]
				if value ~= nil then
					if type(value) ~= "number" then
						errors[#errors + 1] = field .. " must be numeric"
					elseif value < 0 then
						errors[#errors + 1] = field .. " must not be negative"
					end
				end
			end
			if descriptor.bytes and descriptor.bytes > t.maxBytes then
				errors[#errors + 1] = string.format("%s exceeds the %d byte budget",
					tostring(descriptor.name), t.maxBytes)
			end
			if descriptor.extension and #t.extensions > 0 then
				local known = false
				for _, ext in ipairs(t.extensions) do
					if ext == descriptor.extension then known = true end
				end
				if not known then
					warnings[#warnings + 1] = "unusual extension: " .. tostring(descriptor.extension)
				end
			end
			if typeName == "texture" and descriptor.width and descriptor.height then
				local function powerOfTwo(n)
					local v = 1
					while v < n do v = v * 2 end
					return v == n
				end
				if not powerOfTwo(descriptor.width) or not powerOfTwo(descriptor.height) then
					warnings[#warnings + 1] = "texture is not power-of-two"
				end
			end
			return #errors == 0, errors, warnings
		end

		function self.normalize(typeName, descriptor)
			local t = self.types[typeName]
			local out = {}
			for key, value in pairs(descriptor) do out[key] = value end
			if t then
				for _, field in ipairs(t.scaleFields) do
					if type(out[field]) == "number" then out[field] = out[field] * self.unitScale end
				end
			end
			out.type = typeName
			out.name = tostring(out.name or "unnamed")
			return out
		end

		function self.contentHash(descriptor)
			local parts = {}
			for _, key in ipairs(C.keys(descriptor)) do
				parts[#parts + 1] = key .. "=" .. tostring(descriptor[key])
			end
			table.sort(parts)
			return Hash.fnv1a(table.concat(parts, "|"))
		end

		function self.import(typeName, descriptor, dependencies)
			self.installDefaults()
			local ok, errors, warnings = self.validate(typeName, descriptor)
			if not ok then
				self.rejected = self.rejected + 1
				return nil, errors
			end
			local normalized = self.normalize(typeName, descriptor)
			local hash = self.contentHash(normalized)
			if self.byHash[hash] then
				self.duplicates = self.duplicates + 1
				return self.assets[self.byHash[hash]], nil, "duplicate"
			end
			local id = normalized.name
			local asset = { id = id, type = typeName, data = normalized, hash = hash,
				dependencies = dependencies or {}, warnings = warnings or {},
				bytes = normalized.bytes or 0 }
			self.assets[id] = asset
			self.order[#self.order + 1] = id
			self.byHash[hash] = id
			self.imported = self.imported + 1
			self.warnings = self.warnings + #asset.warnings
			return asset
		end

		function self.get(id) return self.assets[id] end

		function self.ofType(typeName)
			local out = {}
			for _, id in ipairs(self.order) do
				if self.assets[id].type == typeName then out[#out + 1] = id end
			end
			return out
		end

		function self.missingDependencies()
			local out = {}
			for _, id in ipairs(self.order) do
				for _, dep in ipairs(self.assets[id].dependencies) do
					if not self.assets[dep] then out[#out + 1] = { asset = id, missing = dep } end
				end
			end
			return out
		end

		function self.totalBytes()
			local total = 0
			for _, id in ipairs(self.order) do total = total + self.assets[id].bytes end
			return total
		end

		function self.stats() return { types = C.count(self.types), assets = #self.order,
			imported = self.imported, rejected = self.rejected, duplicates = self.duplicates,
			warnings = self.warnings, bytes = self.totalBytes() } end
		return self
	end

	------------------------------------------------------------------ 105. BUNDLER
	-- Packaging: assets grouped into size-bounded bundles by priority and locality,
	-- compression estimation per type, a manifest with hashes, delta bundles against a
	-- previous manifest, and a load plan ordered by what the player needs first.
	function K.bundler(cfg)
		local self = { kind = "bundler", id = cfg.id, entries = {}, order = {},
			bundles = {}, maxBundleBytes = cfg.maxBundleBytes or 4 * 1024 * 1024,
			ratios = cfg.ratios or { mesh = 0.55, texture = 0.35, audio = 0.5,
				animation = 0.4, script = 0.3 },
			packed = 0, savedBytes = 0 }

		function self.add(id, opts)
			opts = opts or {}
			if self.entries[id] then return false end
			self.entries[id] = { id = id, bytes = opts.bytes or 1024,
				type = opts.type or "mesh", priority = opts.priority or 1,
				group = opts.group or "core", hash = opts.hash or Hash.fnv1a(id) }
			self.order[#self.order + 1] = id
			return true
		end

		function self.compressedBytes(id)
			local entry = self.entries[id]
			if not entry then return 0 end
			local ratio = self.ratios[entry.type] or 0.6
			return math.floor(entry.bytes * ratio)
		end

		function self.pack()
			self.bundles = {}
			local ids = {}
			for i, id in ipairs(self.order) do ids[i] = id end
			table.sort(ids, function(a, b)
				local ea, eb = self.entries[a], self.entries[b]
				if ea.group ~= eb.group then return ea.group < eb.group end
				if ea.priority ~= eb.priority then return ea.priority > eb.priority end
				return ea.bytes > eb.bytes
			end)
			local current = nil
			local savedTotal = 0
			for _, id in ipairs(ids) do
				local size = self.compressedBytes(id)
				savedTotal = savedTotal + (self.entries[id].bytes - size)
				if not current or current.group ~= self.entries[id].group
					or current.bytes + size > self.maxBundleBytes then
					current = { id = "bundle" .. (#self.bundles + 1), items = {}, bytes = 0,
						group = self.entries[id].group }
					self.bundles[#self.bundles + 1] = current
				end
				current.items[#current.items + 1] = id
				current.bytes = current.bytes + size
			end
			self.packed = self.packed + 1
			self.savedBytes = savedTotal
			return #self.bundles
		end

		function self.bundleOf(id)
			for _, bundle in ipairs(self.bundles) do
				for _, item in ipairs(bundle.items) do
					if item == id then return bundle.id end
				end
			end
			return nil
		end

		function self.manifest()
			if #self.bundles == 0 then self.pack() end
			local manifest = { bundles = {}, totalBytes = 0, entries = #self.order }
			for _, bundle in ipairs(self.bundles) do
				local record = { id = bundle.id, group = bundle.group, bytes = bundle.bytes,
					items = {} }
				for _, item in ipairs(bundle.items) do
					record.items[#record.items + 1] = { id = item,
						hash = self.entries[item].hash, bytes = self.compressedBytes(item) }
				end
				manifest.totalBytes = manifest.totalBytes + bundle.bytes
				manifest.bundles[#manifest.bundles + 1] = record
			end
			return manifest
		end

		function self.delta(previous)
			local now = self.manifest()
			local old = {}
			for _, bundle in ipairs((previous or {}).bundles or {}) do
				for _, item in ipairs(bundle.items) do old[item.id] = item.hash end
			end
			local added, changed, removed = {}, {}, {}
			local seen = {}
			for _, bundle in ipairs(now.bundles) do
				for _, item in ipairs(bundle.items) do
					seen[item.id] = true
					if old[item.id] == nil then added[#added + 1] = item.id
					elseif old[item.id] ~= item.hash then changed[#changed + 1] = item.id end
				end
			end
			for id in pairs(old) do
				if not seen[id] then removed[#removed + 1] = id end
			end
			table.sort(added) table.sort(changed) table.sort(removed)
			return { added = added, changed = changed, removed = removed }
		end

		function self.loadPlan(groups)
			if #self.bundles == 0 then self.pack() end
			local wanted = {}
			for _, group in ipairs(groups or { "core" }) do wanted[group] = true end
			local plan = {}
			for _, bundle in ipairs(self.bundles) do
				if wanted[bundle.group] then plan[#plan + 1] = bundle.id end
			end
			return plan
		end

		function self.compressionRatio()
			local raw, packed = 0, 0
			for _, id in ipairs(self.order) do
				raw = raw + self.entries[id].bytes
				packed = packed + self.compressedBytes(id)
			end
			if raw == 0 then return 1 end
			return packed / raw
		end

		function self.stats() return { entries = #self.order, bundles = #self.bundles,
			packs = self.packed, savedBytes = self.savedBytes,
			ratio = self.compressionRatio(), maxBundleBytes = self.maxBundleBytes } end
		return self
	end

	------------------------------------------------------------------ 106. TIMELINE
	-- Cinematic time: tracks of keyframes with interpolation and easing, clips that own a
	-- time range, a playhead that scrubs forward or backward, events that fire exactly
	-- once when the head crosses them, and looping/ping-pong playback.
	function K.timeline(cfg)
		local self = { kind = "timeline", id = cfg.id, tracks = {}, order = {},
			clips = {}, events = {}, time = 0, duration = cfg.duration or 10,
			playing = false, rate = cfg.rate or 1, loop = cfg.loop or false,
			fired = 0, scrubs = 0 }

		local function ease(kind, t)
			if kind == "step" then return t >= 1 and 1 or 0 end
			if kind == "easeIn" then return t * t end
			if kind == "easeOut" then return 1 - (1 - t) * (1 - t) end
			if kind == "easeInOut" then
				if t < 0.5 then return 2 * t * t end
				return 1 - 2 * (1 - t) * (1 - t)
			end
			return t
		end

		function self.addTrack(name, opts)
			opts = opts or {}
			if self.tracks[name] then return false end
			self.tracks[name] = { name = name, keys = {}, default = opts.default or 0,
				easing = opts.easing or "linear", target = opts.target }
			self.order[#self.order + 1] = name
			return true
		end

		function self.addKey(track, time, value, easing)
			local t = self.tracks[track]
			if not t then return false end
			t.keys[#t.keys + 1] = { time = time, value = value, easing = easing or t.easing }
			table.sort(t.keys, function(a, b) return a.time < b.time end)
			if time > self.duration then self.duration = time end
			return #t.keys
		end

		function self.valueAt(track, time)
			local t = self.tracks[track]
			if not t then return nil end
			if #t.keys == 0 then return t.default end
			time = time or self.time
			if time <= t.keys[1].time then return t.keys[1].value end
			if time >= t.keys[#t.keys].time then return t.keys[#t.keys].value end
			for i = 1, #t.keys - 1 do
				local a, b = t.keys[i], t.keys[i + 1]
				if time >= a.time and time <= b.time then
					local span = math.max(1e-9, b.time - a.time)
					local alpha = ease(b.easing, (time - a.time) / span)
					if type(a.value) == "number" then
						return a.value + (b.value - a.value) * alpha
					end
					if type(a.value) == "table" and a.value.lerp then
						return a.value:lerp(b.value, alpha)
					end
					return alpha < 1 and a.value or b.value
				end
			end
			return t.default
		end

		function self.addClip(id, startTime, length, payload)
			if self.clips[id] then return false end
			self.clips[id] = { id = id, startTime = startTime, length = length,
				payload = payload, active = false }
			if startTime + length > self.duration then self.duration = startTime + length end
			return true
		end

		function self.activeClips(time)
			time = time or self.time
			local out = {}
			for id, clip in pairs(self.clips) do
				if time >= clip.startTime and time <= clip.startTime + clip.length then
					out[#out + 1] = id
				end
			end
			table.sort(out)
			return out
		end

		function self.addEvent(name, time, payload)
			self.events[#self.events + 1] = { name = name, time = time, payload = payload }
			table.sort(self.events, function(a, b) return a.time < b.time end)
			if time > self.duration then self.duration = time end
			return #self.events
		end

		function self.play() self.playing = true return true end
		function self.pause() self.playing = false return true end

		function self.seek(time)
			self.time = Mathx.clamp(time, 0, self.duration)
			self.scrubs = self.scrubs + 1
			return self.time
		end

		function self.advance(dt)
			if not self.playing then return {} end
			local from = self.time
			local to = from + dt * self.rate
			local fired = {}
			if to > self.duration then
				if self.loop then
					for _, event in ipairs(self.events) do
						if event.time > from and event.time <= self.duration then
							fired[#fired + 1] = event
						end
					end
					to = to - self.duration
					from = 0
				else
					to = self.duration
					self.playing = false
				end
			end
			for _, event in ipairs(self.events) do
				if event.time > from and event.time <= to then fired[#fired + 1] = event end
			end
			self.time = to
			self.fired = self.fired + #fired
			return fired
		end

		function self.sampleAll(time)
			local out = {}
			for _, name in ipairs(self.order) do out[name] = self.valueAt(name, time) end
			return out
		end

		function self.trim()
			local last = 0
			for _, name in ipairs(self.order) do
				local keys = self.tracks[name].keys
				if #keys > 0 and keys[#keys].time > last then last = keys[#keys].time end
			end
			for _, clip in pairs(self.clips) do
				if clip.startTime + clip.length > last then last = clip.startTime + clip.length end
			end
			for _, event in ipairs(self.events) do
				if event.time > last then last = event.time end
			end
			self.duration = last
			return last
		end

		function self.stats() return { tracks = #self.order, clips = C.count(self.clips),
			events = #self.events, duration = self.duration, time = self.time,
			playing = self.playing, fired = self.fired, scrubs = self.scrubs } end
		return self
	end

	------------------------------------------------------------------ 107. CAMERARIG
	-- A real camera rig: dolly along a path, orbit, crane and handheld modes, smoothed
	-- look-at with lead, focus distance and depth-of-field parameters, shake with decay,
	-- and framing helpers that keep a subject at a chosen screen height.
	function K.camerarig(cfg)
		local self = { kind = "camerarig", id = cfg.id, mode = cfg.mode or "free",
			position = cfg.position or v3(0, 5, -10), target = cfg.target or v3(),
			up = v3(0, 1, 0), fov = cfg.fov or 1.2, focus = cfg.focus or 10,
			aperture = cfg.aperture or 2.8, smoothing = cfg.smoothing or 8,
			shakeAmount = 0, shakeDecay = cfg.shakeDecay or 2, path = {},
			pathLength = 0, distance = cfg.distance or 12, height = cfg.height or 4,
			angle = 0, orbitSpeed = cfg.orbitSpeed or 0.4, time = 0, updates = 0 }

		function self.setMode(mode)
			self.mode = mode
			return self.mode
		end

		function self.addPathPoint(point)
			self.path[#self.path + 1] = point
			if #self.path > 1 then
				self.pathLength = self.pathLength + self.path[#self.path - 1]:distance(point)
			end
			return #self.path
		end

		function self.pathAt(alpha)
			if #self.path == 0 then return self.position end
			if #self.path == 1 then return self.path[1] end
			alpha = clamp01(alpha)
			local scaled = alpha * (#self.path - 1)
			local index = math.min(#self.path - 1, math.floor(scaled) + 1)
			local localT = scaled - (index - 1)
			return self.path[index]:lerp(self.path[index + 1], localT)
		end

		function self.lookAt(point, lead)
			self.target = point + (lead or v3())
			return self.target
		end

		function self.forward()
			local delta = self.target - self.position
			if delta:length() < 1e-6 then return v3(0, 0, -1) end
			return delta:unit()
		end

		function self.shake(amount)
			self.shakeAmount = math.max(self.shakeAmount, amount or 0.5)
			return self.shakeAmount
		end

		function self.focusOn(point)
			self.focus = self.position:distance(point)
			return self.focus
		end

		-- Circle of confusion for the current focus/aperture: the DOF signal a renderer needs.
		function self.circleOfConfusion(distance)
			if distance <= 0 or self.focus <= 0 then return 0 end
			local coc = math.abs(distance - self.focus) / math.max(1e-6, distance)
			return clamp01(coc * (2.8 / math.max(0.5, self.aperture)))
		end

		-- Keep a subject of a given world height at a target fraction of the screen.
		function self.frameSubject(subjectHeight, screenFraction)
			local fraction = math.max(0.05, screenFraction or 0.5)
			local halfFov = self.fov * 0.5
			local wanted = (subjectHeight * 0.5) / math.max(1e-6, math.tan(halfFov) * fraction)
			self.distance = wanted
			return wanted
		end

		function self.update(dt, subject)
			self.time = self.time + dt
			self.updates = self.updates + 1
			local desired = self.position
			if self.mode == "orbit" and subject then
				self.angle = self.angle + self.orbitSpeed * dt
				desired = subject + v3(math.cos(self.angle) * self.distance, self.height,
					math.sin(self.angle) * self.distance)
			elseif self.mode == "dolly" and #self.path > 1 then
				local alpha = clamp01((self.time * (self.orbitSpeed + 0.1)) % 1)
				desired = self.pathAt(alpha)
			elseif self.mode == "crane" and subject then
				desired = subject + v3(0, self.height + self.time * 0.5, -self.distance)
			elseif self.mode == "follow" and subject then
				desired = subject - self.forward() * self.distance + v3(0, self.height, 0)
			end
			local blend = 1 - math.exp(-self.smoothing * dt)
			self.position = self.position:lerp(desired, blend)
			if subject then self.lookAt(subject) end
			if self.shakeAmount > 0 then
				local wobble = math.sin(self.time * 31.7) * self.shakeAmount
				local sway = math.cos(self.time * 27.3) * self.shakeAmount
				self.position = self.position + v3(wobble * 0.1, sway * 0.1, 0)
				self.shakeAmount = math.max(0, self.shakeAmount - self.shakeDecay * dt)
			end
			if subject then self.focusOn(subject) end
			return self.position
		end

		function self.state()
			return { position = self.position, target = self.target, fov = self.fov,
				focus = self.focus, aperture = self.aperture, mode = self.mode }
		end

		function self.stats() return { mode = self.mode, updates = self.updates,
			pathPoints = #self.path, pathLength = self.pathLength, focus = self.focus,
			shake = self.shakeAmount, fov = self.fov, time = self.time } end
		return self
	end

	------------------------------------------------------------------ 108. GRADE
	-- Colour grading as arithmetic, not a lookup blob: exposure, contrast around a pivot,
	-- saturation against real luma weights, lift/gamma/gain per channel, white balance,
	-- a filmic tone curve and named looks that blend into each other.
	function K.grade(cfg)
		local self = { kind = "grade", id = cfg.id, exposure = cfg.exposure or 0,
			contrast = cfg.contrast or 1, saturation = cfg.saturation or 1,
			temperature = cfg.temperature or 0, tint = cfg.tint or 0,
			lift = cfg.lift or { 0, 0, 0 }, gamma = cfg.gamma or { 1, 1, 1 },
			gain = cfg.gain or { 1, 1, 1 }, toneMap = cfg.toneMap or "filmic",
			looks = {}, applied = 0 }

		local LUMA = { 0.2126, 0.7152, 0.0722 }

		function self.setLook(name, params)
			self.looks[name] = params
			return true
		end

		function self.installLooks()
			if C.count(self.looks) > 0 then return C.count(self.looks) end
			self.setLook("neutral", { exposure = 0, contrast = 1, saturation = 1,
				temperature = 0 })
			self.setLook("warmDay", { exposure = 0.15, contrast = 1.05, saturation = 1.1,
				temperature = 0.25 })
			self.setLook("coldNight", { exposure = -0.4, contrast = 1.15, saturation = 0.85,
				temperature = -0.35 })
			self.setLook("noir", { exposure = -0.1, contrast = 1.4, saturation = 0.05,
				temperature = -0.05 })
			return C.count(self.looks)
		end

		function self.applyLook(name, weight)
			self.installLooks()
			local look = self.looks[name]
			if not look then return false end
			local w = clamp01(weight == nil and 1 or weight)
			self.exposure = Mathx.lerp(self.exposure, look.exposure or 0, w)
			self.contrast = Mathx.lerp(self.contrast, look.contrast or 1, w)
			self.saturation = Mathx.lerp(self.saturation, look.saturation or 1, w)
			self.temperature = Mathx.lerp(self.temperature, look.temperature or 0, w)
			return true
		end

		function self.luma(rgb)
			return rgb[1] * LUMA[1] + rgb[2] * LUMA[2] + rgb[3] * LUMA[3]
		end

		function self.toneCurve(x)
			if self.toneMap == "reinhard" then return x / (1 + x) end
			if self.toneMap == "linear" then return clamp01(x) end
			local a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
			return clamp01((x * (a * x + b)) / (x * (c * x + d) + e))
		end

		function self.apply(rgb)
			self.applied = self.applied + 1
			local out = { rgb[1], rgb[2], rgb[3] }
			local exposureScale = 2 ^ self.exposure
			for i = 1, 3 do out[i] = out[i] * exposureScale end
			-- white balance: temperature pushes red against blue, tint green against magenta
			out[1] = out[1] * (1 + self.temperature * 0.3)
			out[3] = out[3] * (1 - self.temperature * 0.3)
			out[2] = out[2] * (1 + self.tint * 0.2)
			for i = 1, 3 do
				out[i] = self.lift[i] + out[i] * self.gain[i]
				if out[i] > 0 then out[i] = out[i] ^ (1 / math.max(0.01, self.gamma[i])) end
			end
			local pivot = 0.435
			for i = 1, 3 do out[i] = (out[i] - pivot) * self.contrast + pivot end
			local grey = self.luma(out)
			for i = 1, 3 do out[i] = grey + (out[i] - grey) * self.saturation end
			for i = 1, 3 do out[i] = self.toneCurve(math.max(0, out[i])) end
			return out
		end

		function self.applyMany(colours)
			local out = {}
			for i, rgb in ipairs(colours) do out[i] = self.apply(rgb) end
			return out
		end

		function self.averageLuma(colours)
			if #colours == 0 then return 0 end
			local total = 0
			for _, rgb in ipairs(colours) do total = total + self.luma(self.apply(rgb)) end
			return total / #colours
		end

		-- Auto-exposure: move the exposure stop until the average luma hits the target.
		function self.autoExpose(colours, target, step)
			local wanted = target or 0.18
			local current = self.averageLuma(colours)
			if current <= 1e-5 then
				self.exposure = self.exposure + (step or 0.25)
				return self.exposure
			end
			local error = math.log(wanted / current) / math.log(2)
			self.exposure = self.exposure + error * (step or 0.5)
			self.exposure = Mathx.clamp(self.exposure, -6, 6)
			return self.exposure
		end

		function self.reset()
			self.exposure, self.contrast, self.saturation = 0, 1, 1
			self.temperature, self.tint = 0, 0
			self.lift = { 0, 0, 0 }
			self.gamma = { 1, 1, 1 }
			self.gain = { 1, 1, 1 }
			return true
		end

		function self.stats() return { exposure = self.exposure, contrast = self.contrast,
			saturation = self.saturation, temperature = self.temperature,
			toneMap = self.toneMap, looks = C.count(self.looks), applied = self.applied } end
		return self
	end

	K.NAMES = { "importer", "bundler", "timeline", "camerarig", "grade" }
	return K
end
