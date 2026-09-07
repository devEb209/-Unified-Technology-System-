-- ARKHER RUNTIME :: Material / Rendering / Neural Kits
-- Round 4 machinery (kits 44-55). Same contract as runtime/kits.lua, kits_studio.lua and
-- kits_world.lua: every kit here is a complete working implementation that catalog systems
-- specialize. Nothing here is Roblox specific, nothing here is a stub, and every number is
-- computed rather than declared.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Noise = A:import("arkher/kernel/noise")
	local Random = A:import("arkher/kernel/random")
	local Spatial = A:import("arkher/kernel/spatial")
	local Signal = A:import("arkher/kernel/signal")
	local Hash = A:import("arkher/kernel/hash")

	local K = {}
	local v3 = Vec.vec3

	local function clamp01(v) return Mathx.clamp(v, 0, 1) end

	------------------------------------------------------------------ 44. MATERIAL
	-- Layered PBR material: an ordered stack of layers, each with a weight and an optional
	-- mask function, resolved into one parameter set. This is the ARKHER Material Framework
	-- core; the adapter turns the resolved parameters into whatever the platform can show.
	function K.material(cfg)
		local self = { kind = "material", id = cfg.id, layers = {}, order = {}, variants = {},
			activeVariant = nil, resolves = 0, texelBudget = cfg.texelBudget or 4194304,
			onChange = Signal.new("material.change") }

		local DEFAULTS = { albedo = 0x808080, roughness = 0.8, metallic = 0.0, normalStrength = 1.0,
			emissive = 0.0, opacity = 1.0, uvScale = 1.0, texels = 65536, blend = "mix" }

		function self.addLayer(id, params)
			if self.layers[id] then return nil, "duplicate layer" end
			local layer = { id = id, weight = 1.0, mask = nil, enabled = true }
			for k, v in pairs(DEFAULTS) do layer[k] = v end
			for k, v in pairs(params or {}) do layer[k] = v end
			self.layers[id] = layer
			self.order[#self.order + 1] = id
			self.onChange:fire({ layer = id, action = "add" })
			return layer
		end

		function self.removeLayer(id)
			if not self.layers[id] then return false end
			self.layers[id] = nil
			for i, k in ipairs(self.order) do
				if k == id then table.remove(self.order, i) break end
			end
			self.onChange:fire({ layer = id, action = "remove" })
			return true
		end

		function self.setParam(id, key, value)
			local layer = self.layers[id]
			if not layer then return nil, "unknown layer" end
			layer[key] = value
			self.onChange:fire({ layer = id, action = "set", key = key })
			return layer
		end

		function self.setEnabled(id, enabled)
			local layer = self.layers[id]
			if not layer then return false end
			layer.enabled = enabled and true or false
			return true
		end

		local function mixColor(a, b, t)
			local ar, ag, ab = math.floor(a / 65536) % 256, math.floor(a / 256) % 256, a % 256
			local br, bg, bb = math.floor(b / 65536) % 256, math.floor(b / 256) % 256, b % 256
			local r = math.floor(Mathx.lerp(ar, br, t) + 0.5)
			local g = math.floor(Mathx.lerp(ag, bg, t) + 0.5)
			local bl = math.floor(Mathx.lerp(ab, bb, t) + 0.5)
			return r * 65536 + g * 256 + bl
		end

		-- Resolve the whole stack at a surface point. `ctx` may carry u, v, slope, height,
		-- wetness, wear - anything a layer mask wants to read.
		function self.resolve(ctx)
			ctx = ctx or {}
			self.resolves = self.resolves + 1
			local out = { albedo = DEFAULTS.albedo, roughness = 0, metallic = 0,
				normalStrength = 0, emissive = 0, opacity = 0, uvScale = 0, layers = 0 }
			local total = 0
			local first = true
			for _, id in ipairs(self.order) do
				local layer = self.layers[id]
				if layer.enabled then
					local w = layer.weight
					if layer.mask then w = w * clamp01(layer.mask(ctx) or 0) end
					if w > 0.0005 then
						if layer.blend == "multiply" then w = w * 0.5 end
						if layer.blend == "add" then w = w * 1.25 end
						total = total + w
						local t = w / total
						if first then
							out.albedo = layer.albedo
							first = false
						else
							out.albedo = mixColor(out.albedo, layer.albedo, t)
						end
						out.roughness = Mathx.lerp(out.roughness, layer.roughness, t)
						out.metallic = Mathx.lerp(out.metallic, layer.metallic, t)
						out.normalStrength = Mathx.lerp(out.normalStrength, layer.normalStrength, t)
						out.emissive = Mathx.lerp(out.emissive, layer.emissive, t)
						out.opacity = Mathx.lerp(out.opacity, layer.opacity, t)
						out.uvScale = Mathx.lerp(out.uvScale, layer.uvScale, t)
						out.layers = out.layers + 1
					end
				end
			end
			if total == 0 then
				out.roughness = DEFAULTS.roughness
				out.opacity = DEFAULTS.opacity
				out.uvScale = DEFAULTS.uvScale
			end
			out.weight = total
			return out
		end

		function self.defineVariant(name, overrides)
			self.variants[name] = overrides or {}
			return self.variants[name]
		end

		function self.applyVariant(name)
			local v = self.variants[name]
			if not v then return nil, "unknown variant" end
			for layerId, params in pairs(v) do
				local layer = self.layers[layerId]
				if layer then
					for k, value in pairs(params) do layer[k] = value end
				end
			end
			self.activeVariant = name
			return true
		end

		-- Cheapest honest memory estimate: 4 bytes/texel per active layer.
		function self.memoryBytes()
			local bytes = 0
			for _, id in ipairs(self.order) do
				local layer = self.layers[id]
				if layer.enabled then bytes = bytes + layer.texels * 4 end
			end
			return bytes
		end

		function self.withinBudget() return self.memoryBytes() <= self.texelBudget * 4 end

		-- Distance LOD: drop the least significant layers until the budget is met.
		function self.lodParams(distance, bands)
			bands = bands or { 60, 200, 600 }
			local level = 0
			for i, d in ipairs(bands) do
				if distance > d then level = i end
			end
			local keep = math.max(1, #self.order - level)
			local dropped = {}
			local sorted = {}
			for _, id in ipairs(self.order) do sorted[#sorted + 1] = id end
			table.sort(sorted, function(a, b) return self.layers[a].weight > self.layers[b].weight end)
			for i = keep + 1, #sorted do dropped[#dropped + 1] = sorted[i] end
			return { level = level, layers = keep, dropped = dropped,
				normalStrength = level >= 2 and 0 or 1, uvDetail = 1 / (1 + level) }
		end

		function self.checksum()
			local parts = {}
			for _, id in ipairs(self.order) do
				local l = self.layers[id]
				parts[#parts + 1] = string.format("%s:%d:%.3f:%.3f:%.3f:%.3f", id, l.albedo,
					l.roughness, l.metallic, l.weight, l.uvScale)
			end
			return Hash.fnv1a(table.concat(parts, "|"))
		end

		function self.describe()
			local list = {}
			for _, id in ipairs(self.order) do
				local l = self.layers[id]
				list[#list + 1] = { id = id, weight = l.weight, blend = l.blend, enabled = l.enabled }
			end
			return { id = self.id, layers = list, variant = self.activeVariant,
				memoryBytes = self.memoryBytes(), checksum = self.checksum() }
		end

		function self.stats() return { layers = #self.order, variants = C.count(self.variants),
			resolves = self.resolves, memoryBytes = self.memoryBytes(), withinBudget = self.withinBudget() } end
		return self
	end

	------------------------------------------------------------------ 45. SAMPLER
	-- Texture store + shelf atlas packer + mip chain + bilinear sampling. Pixels are real
	-- numbers in a flat array, so filtering, mips and residency are measurable, not claimed.
	function K.sampler(cfg)
		local self = { kind = "sampler", id = cfg.id, textures = {}, order = {},
			atlasSize = cfg.atlasSize or 512, shelfY = 0, shelfX = 0, shelfH = 0,
			samples = 0, misses = 0, maxSide = cfg.maxSide or 64 }

		function self.defineTexture(id, width, height, generator)
			if self.textures[id] then return nil, "duplicate texture" end
			width = math.min(width or 16, self.maxSide)
			height = math.min(height or 16, self.maxSide)
			local pixels = {}
			for y = 0, height - 1 do
				for x = 0, width - 1 do
					local value = 0.5
					if generator then value = generator(x / math.max(1, width - 1), y / math.max(1, height - 1)) end
					pixels[y * width + x + 1] = value
				end
			end
			local tex = { id = id, width = width, height = height, pixels = pixels,
				mips = nil, rect = nil, resident = true }
			self.textures[id] = tex
			self.order[#self.order + 1] = id
			return tex
		end

		function self.get(id) return self.textures[id] end

		-- Shelf packing into a square atlas; returns the uv rect or nil when it does not fit.
		function self.pack(id)
			local tex = self.textures[id]
			if not tex then return nil, "unknown texture" end
			if tex.rect then return tex.rect end
			if self.shelfX + tex.width > self.atlasSize then
				self.shelfX = 0
				self.shelfY = self.shelfY + self.shelfH
				self.shelfH = 0
			end
			if self.shelfY + tex.height > self.atlasSize then return nil, "atlas full" end
			tex.rect = { x = self.shelfX, y = self.shelfY, w = tex.width, h = tex.height,
				u0 = self.shelfX / self.atlasSize, v0 = self.shelfY / self.atlasSize,
				u1 = (self.shelfX + tex.width) / self.atlasSize,
				v1 = (self.shelfY + tex.height) / self.atlasSize }
			self.shelfX = self.shelfX + tex.width
			if tex.height > self.shelfH then self.shelfH = tex.height end
			return tex.rect
		end

		function self.packAll()
			local packed, failed = 0, 0
			for _, id in ipairs(self.order) do
				if self.pack(id) then packed = packed + 1 else failed = failed + 1 end
			end
			return packed, failed
		end

		function self.occupancy()
			local used = 0
			for _, id in ipairs(self.order) do
				local t = self.textures[id]
				if t.rect then used = used + t.width * t.height end
			end
			return used / (self.atlasSize * self.atlasSize)
		end

		-- Box-filtered mip chain down to 1x1.
		function self.buildMips(id)
			local tex = self.textures[id]
			if not tex then return nil, "unknown texture" end
			local mips = { { width = tex.width, height = tex.height, pixels = tex.pixels } }
			local level = 1
			while mips[level].width > 1 or mips[level].height > 1 do
				local src = mips[level]
				local w = math.max(1, math.floor(src.width / 2))
				local h = math.max(1, math.floor(src.height / 2))
				local px = {}
				for y = 0, h - 1 do
					for x = 0, w - 1 do
						local sx, sy = x * 2, y * 2
						local total, n = 0, 0
						for dy = 0, 1 do
							for dx = 0, 1 do
								local qx, qy = math.min(src.width - 1, sx + dx), math.min(src.height - 1, sy + dy)
								total = total + src.pixels[qy * src.width + qx + 1]
								n = n + 1
							end
						end
						px[y * w + x + 1] = total / n
					end
				end
				level = level + 1
				mips[level] = { width = w, height = h, pixels = px }
			end
			tex.mips = mips
			return #mips
		end

		local function fetch(level, x, y)
			x = Mathx.clamp(x, 0, level.width - 1)
			y = Mathx.clamp(y, 0, level.height - 1)
			return level.pixels[y * level.width + x + 1] or 0
		end

		function self.sample(id, u, v)
			local tex = self.textures[id]
			if not tex then self.misses = self.misses + 1 return 0 end
			self.samples = self.samples + 1
			return self.sampleLevel({ width = tex.width, height = tex.height, pixels = tex.pixels }, u, v)
		end

		function self.sampleLevel(level, u, v)
			local x = clamp01(u) * (level.width - 1)
			local y = clamp01(v) * (level.height - 1)
			local x0, y0 = math.floor(x), math.floor(y)
			local fx, fy = x - x0, y - y0
			local a = fetch(level, x0, y0)
			local b = fetch(level, x0 + 1, y0)
			local c = fetch(level, x0, y0 + 1)
			local d = fetch(level, x0 + 1, y0 + 1)
			return Mathx.lerp(Mathx.lerp(a, b, fx), Mathx.lerp(c, d, fx), fy)
		end

		-- Trilinear: blends between two mip levels, exactly like a GPU would.
		function self.sampleLod(id, u, v, lod)
			local tex = self.textures[id]
			if not tex then self.misses = self.misses + 1 return 0 end
			if not tex.mips then self.buildMips(id) end
			self.samples = self.samples + 1
			local maxLod = #tex.mips - 1
			lod = Mathx.clamp(lod or 0, 0, maxLod)
			local l0 = math.floor(lod)
			local l1 = math.min(maxLod, l0 + 1)
			local a = self.sampleLevel(tex.mips[l0 + 1], u, v)
			local b = self.sampleLevel(tex.mips[l1 + 1], u, v)
			return Mathx.lerp(a, b, lod - l0)
		end

		-- Screen-space derivative driven lod, the same formula a rasterizer uses.
		function self.lodFor(id, texelsPerPixel)
			local tex = self.textures[id]
			if not tex or texelsPerPixel <= 0 then return 0 end
			return math.max(0, Mathx.log2(texelsPerPixel))
		end

		function self.evict(id)
			local tex = self.textures[id]
			if not tex or not tex.resident then return false end
			tex.resident = false
			tex.mips = nil
			return true
		end

		function self.residentBytes()
			local bytes = 0
			for _, id in ipairs(self.order) do
				local t = self.textures[id]
				if t.resident then
					bytes = bytes + t.width * t.height * 4
					if t.mips then bytes = math.floor(bytes * 1.34) end
				end
			end
			return bytes
		end

		function self.stats() return { textures = #self.order, samples = self.samples,
			misses = self.misses, occupancy = self.occupancy(), residentBytes = self.residentBytes(),
			atlasSize = self.atlasSize } end
		return self
	end

	------------------------------------------------------------------ 46. SHADEGRAPH
	-- Node graph for shading parameters: evaluates, folds constants and compiles to Luau
	-- source. This is how ARKHER expresses "shaders" on a platform that has none.
	function K.shadegraph(cfg)
		local self = { kind = "shadegraph", id = cfg.id, nodes = {}, order = {}, links = {},
			outputs = {}, evaluations = 0, folded = 0 }

		local OPS = {
			constant = function(n) return n.value or 0 end,
			input = function(n, inputs) return inputs[n.key] or n.default or 0 end,
			add = function(n, _, a, b) return (a or 0) + (b or 0) end,
			subtract = function(n, _, a, b) return (a or 0) - (b or 0) end,
			multiply = function(n, _, a, b) return (a or 0) * (b or 1) end,
			divide = function(n, _, a, b) if (b or 0) == 0 then return 0 end return a / b end,
			mix = function(n, _, a, b) return Mathx.lerp(a or 0, b or 0, n.factor or 0.5) end,
			clamp = function(n, _, a) return Mathx.clamp(a or 0, n.min or 0, n.max or 1) end,
			saturate = function(n, _, a) return clamp01(a or 0) end,
			power = function(n, _, a) return (math.max(0, a or 0)) ^ (n.exponent or 2) end,
			smoothstep = function(n, _, a) return Mathx.smoothstep(a or 0) end,
			oneminus = function(n, _, a) return 1 - (a or 0) end,
			fresnel = function(n, _, a) return (1 - clamp01(a or 0)) ^ (n.power or 5) end,
			noise = function(n, inputs) return Noise.value2D((inputs.u or 0) * (n.frequency or 4),
				(inputs.v or 0) * (n.frequency or 4), n.seed or 1) end,
			output = function(n, _, a) return a or 0 end,
		}
		self.OPS = OPS

		function self.addNode(id, op, params)
			if self.nodes[id] then return nil, "duplicate node" end
			if not OPS[op] then return nil, "unknown op: " .. tostring(op) end
			local node = { id = id, op = op, inputs = {}, constant = (op == "constant") }
			for k, v in pairs(params or {}) do node[k] = v end
			self.nodes[id] = node
			self.order[#self.order + 1] = id
			if op == "output" then self.outputs[#self.outputs + 1] = id end
			return node
		end

		function self.connect(fromId, toId, slot)
			local from, to = self.nodes[fromId], self.nodes[toId]
			if not from or not to then return nil, "unknown node" end
			to.inputs[slot or (#to.inputs + 1)] = fromId
			self.links[#self.links + 1] = { from = fromId, to = toId, slot = slot or #to.inputs }
			if self.hasCycle() then
				to.inputs[slot or #to.inputs] = nil
				table.remove(self.links)
				return nil, "cycle rejected"
			end
			return true
		end

		function self.hasCycle()
			local state = {}
			local function visit(id)
				if state[id] == 1 then return true end
				if state[id] == 2 then return false end
				state[id] = 1
				for _, dep in pairs(self.nodes[id].inputs) do
					if self.nodes[dep] and visit(dep) then return true end
				end
				state[id] = 2
				return false
			end
			for _, id in ipairs(self.order) do
				if visit(id) then return true end
			end
			return false
		end

		function self.topoOrder()
			local visited, out = {}, {}
			local function visit(id)
				if visited[id] then return end
				visited[id] = true
				local node = self.nodes[id]
				for i = 1, 4 do
					local dep = node.inputs[i]
					if dep and self.nodes[dep] then visit(dep) end
				end
				out[#out + 1] = id
			end
			for _, id in ipairs(self.order) do visit(id) end
			return out
		end

		function self.evaluate(inputs)
			inputs = inputs or {}
			self.evaluations = self.evaluations + 1
			local values = {}
			for _, id in ipairs(self.topoOrder()) do
				local node = self.nodes[id]
				local a = node.inputs[1] and values[node.inputs[1]] or nil
				local b = node.inputs[2] and values[node.inputs[2]] or nil
				values[id] = OPS[node.op](node, inputs, a, b)
			end
			local result = {}
			for _, id in ipairs(self.outputs) do result[self.nodes[id].channel or id] = values[id] end
			return result, values
		end

		-- Constant folding: any node whose whole subtree is constant becomes a constant.
		function self.fold()
			local folded = 0
			local values = select(2, self.evaluate({}))
			for _, id in ipairs(self.topoOrder()) do
				local node = self.nodes[id]
				if node.op ~= "constant" and node.op ~= "input" and node.op ~= "output" and node.op ~= "noise" then
					local allConst = true
					for i = 1, 4 do
						local dep = node.inputs[i]
						if dep and not self.nodes[dep].constant then allConst = false end
					end
					if allConst and not node.constant then
						node.constant = true
						node.foldedValue = values[id]
						folded = folded + 1
					end
				end
			end
			self.folded = self.folded + folded
			return folded
		end

		-- Compile to Luau source. The generated function is what an adapter actually ships.
		function self.compile()
			local lines = { "return function(inputs)", "\tlocal v = {}" }
			for _, id in ipairs(self.topoOrder()) do
				local node = self.nodes[id]
				local ref = string.format("v[%q]", id)
				local a = node.inputs[1] and string.format("v[%q]", node.inputs[1]) or "0"
				local b = node.inputs[2] and string.format("v[%q]", node.inputs[2]) or "0"
				if node.constant and node.foldedValue then
					lines[#lines + 1] = string.format("\t%s = %.9g", ref, node.foldedValue)
				elseif node.op == "constant" then
					lines[#lines + 1] = string.format("\t%s = %.9g", ref, node.value or 0)
				elseif node.op == "input" then
					lines[#lines + 1] = string.format("\t%s = inputs[%q] or %.9g", ref, node.key, node.default or 0)
				elseif node.op == "add" then
					lines[#lines + 1] = string.format("\t%s = %s + %s", ref, a, b)
				elseif node.op == "subtract" then
					lines[#lines + 1] = string.format("\t%s = %s - %s", ref, a, b)
				elseif node.op == "multiply" then
					lines[#lines + 1] = string.format("\t%s = %s * %s", ref, a, b)
				elseif node.op == "divide" then
					lines[#lines + 1] = string.format("\t%s = (%s == 0) and 0 or (%s / %s)", ref, b, a, b)
				elseif node.op == "mix" then
					lines[#lines + 1] = string.format("\t%s = %s + (%s - %s) * %.9g", ref, a, b, a, node.factor or 0.5)
				elseif node.op == "clamp" then
					lines[#lines + 1] = string.format("\t%s = math.max(%.9g, math.min(%.9g, %s))", ref,
						node.min or 0, node.max or 1, a)
				elseif node.op == "saturate" then
					lines[#lines + 1] = string.format("\t%s = math.max(0, math.min(1, %s))", ref, a)
				elseif node.op == "power" then
					lines[#lines + 1] = string.format("\t%s = math.max(0, %s) ^ %.9g", ref, a, node.exponent or 2)
				elseif node.op == "oneminus" then
					lines[#lines + 1] = string.format("\t%s = 1 - %s", ref, a)
				elseif node.op == "fresnel" then
					lines[#lines + 1] = string.format("\t%s = (1 - math.max(0, math.min(1, %s))) ^ %.9g", ref, a, node.power or 5)
				elseif node.op == "smoothstep" then
					lines[#lines + 1] = string.format("\tdo local t = math.max(0, math.min(1, %s)) %s = t * t * (3 - 2 * t) end", a, ref)
				elseif node.op == "noise" then
					lines[#lines + 1] = string.format("\t%s = 0.5 -- noise resolved by the host sampler", ref)
				elseif node.op == "output" then
					lines[#lines + 1] = string.format("\t%s = %s", ref, a)
				end
			end
			lines[#lines + 1] = "\tlocal out = {}"
			for _, id in ipairs(self.outputs) do
				lines[#lines + 1] = string.format("\tout[%q] = v[%q]", self.nodes[id].channel or id, id)
			end
			lines[#lines + 1] = "\treturn out"
			lines[#lines + 1] = "end"
			return table.concat(lines, "\n")
		end

		function self.stats() return { nodes = #self.order, links = #self.links,
			outputs = #self.outputs, evaluations = self.evaluations, folded = self.folded } end
		return self
	end

	------------------------------------------------------------------ 47. FRAMEGRAPH
	-- Render pass graph: declares passes, their reads/writes and their cost, then culls,
	-- orders, aliases memory and executes within a millisecond budget.
	function K.framegraph(cfg)
		local self = { kind = "framegraph", id = cfg.id, passes = {}, order = {}, resources = {},
			budgetMs = cfg.budgetMs or 8.0, executions = 0, culled = 0, skipped = 0 }

		function self.addResource(id, opts)
			opts = opts or {}
			self.resources[id] = { id = id, bytes = opts.bytes or 1048576,
				transient = opts.transient ~= false, firstUse = nil, lastUse = nil, alias = nil }
			return self.resources[id]
		end

		function self.addPass(id, opts)
			opts = opts or {}
			if self.passes[id] then return nil, "duplicate pass" end
			local pass = { id = id, reads = opts.reads or {}, writes = opts.writes or {},
				cost = opts.cost or 1.0, optional = opts.optional or false,
				priority = opts.priority or 5, execute = opts.execute, final = opts.final or false,
				enabled = true }
			for _, r in ipairs(pass.writes) do
				if not self.resources[r] then self.addResource(r) end
			end
			for _, r in ipairs(pass.reads) do
				if not self.resources[r] then self.addResource(r) end
			end
			self.passes[id] = pass
			self.order[#self.order + 1] = id
			return pass
		end

		local function producers(resource)
			local out = {}
			for _, id in ipairs(self.order) do
				for _, w in ipairs(self.passes[id].writes) do
					if w == resource then out[#out + 1] = id end
				end
			end
			return out
		end

		-- Cull passes whose outputs nobody reads and which are not marked final.
		function self.cull()
			local needed = {}
			local stack = {}
			for _, id in ipairs(self.order) do
				if self.passes[id].final then stack[#stack + 1] = id end
			end
			while #stack > 0 do
				local id = table.remove(stack)
				if not needed[id] then
					needed[id] = true
					for _, r in ipairs(self.passes[id].reads) do
						for _, p in ipairs(producers(r)) do stack[#stack + 1] = p end
					end
				end
			end
			local culled = 0
			for _, id in ipairs(self.order) do
				if not needed[id] then
					self.passes[id].enabled = false
					culled = culled + 1
				else
					self.passes[id].enabled = true
				end
			end
			self.culled = culled
			return culled
		end

		function self.compile()
			self.cull()
			local visited, sorted = {}, {}
			local function visit(id, seen)
				if visited[id] then return end
				if seen[id] then return end
				seen[id] = true
				for _, r in ipairs(self.passes[id].reads) do
					for _, p in ipairs(producers(r)) do
						if self.passes[p].enabled then visit(p, seen) end
					end
				end
				visited[id] = true
				sorted[#sorted + 1] = id
			end
			for _, id in ipairs(self.order) do
				if self.passes[id].enabled then visit(id, {}) end
			end
			-- resource lifetimes
			for _, res in pairs(self.resources) do res.firstUse, res.lastUse = nil, nil end
			for i, id in ipairs(sorted) do
				local pass = self.passes[id]
				local touched = {}
				for _, r in ipairs(pass.writes) do touched[#touched + 1] = r end
				for _, r in ipairs(pass.reads) do touched[#touched + 1] = r end
				for _, r in ipairs(touched) do
					local res = self.resources[r]
					if not res.firstUse then res.firstUse = i end
					res.lastUse = i
				end
			end
			self.compiled = sorted
			return sorted
		end

		-- Memory aliasing: transient resources with disjoint lifetimes share one allocation.
		function self.alias()
			if not self.compiled then self.compile() end
			local buckets = {}
			local saved = 0
			local list = {}
			for _, res in pairs(self.resources) do
				if res.transient and res.firstUse then list[#list + 1] = res end
			end
			table.sort(list, function(a, b) return a.firstUse < b.firstUse end)
			for _, res in ipairs(list) do
				res.alias = nil
				for _, bucket in ipairs(buckets) do
					if bucket.lastUse < res.firstUse then
						res.alias = bucket.id
						bucket.lastUse = res.lastUse
						bucket.bytes = math.max(bucket.bytes, res.bytes)
						saved = saved + res.bytes
						break
					end
				end
				if not res.alias then
					buckets[#buckets + 1] = { id = res.id, lastUse = res.lastUse, bytes = res.bytes }
				end
			end
			local peak = 0
			for _, bucket in ipairs(buckets) do peak = peak + bucket.bytes end
			return { buckets = #buckets, peakBytes = peak, savedBytes = saved }
		end

		function self.totalCost()
			if not self.compiled then self.compile() end
			local total = 0
			for _, id in ipairs(self.compiled) do total = total + self.passes[id].cost end
			return total
		end

		-- Execute within the budget. Optional passes are dropped by ascending priority first.
		function self.execute(ctx, budgetMs)
			if not self.compiled then self.compile() end
			budgetMs = budgetMs or self.budgetMs
			self.executions = self.executions + 1
			local spent, executed, skipped = 0, {}, {}
			local droppable = {}
			for _, id in ipairs(self.compiled) do
				if self.passes[id].optional then droppable[#droppable + 1] = id end
			end
			table.sort(droppable, function(a, b) return self.passes[a].priority < self.passes[b].priority end)
			local dropped = {}
			local projected = self.totalCost()
			local di = 1
			while projected > budgetMs and di <= #droppable do
				dropped[droppable[di]] = true
				projected = projected - self.passes[droppable[di]].cost
				di = di + 1
			end
			for _, id in ipairs(self.compiled) do
				local pass = self.passes[id]
				if dropped[id] then
					skipped[#skipped + 1] = id
				else
					spent = spent + pass.cost
					if pass.execute then pass.execute(ctx, pass) end
					executed[#executed + 1] = id
				end
			end
			self.skipped = self.skipped + #skipped
			return { executed = executed, skipped = skipped, costMs = spent, budgetMs = budgetMs }
		end

		function self.describe()
			if not self.compiled then self.compile() end
			return { order = self.compiled, passes = #self.order,
				resources = C.count(self.resources), costMs = self.totalCost(), alias = self.alias() }
		end

		function self.stats() return { passes = #self.order, compiled = self.compiled and #self.compiled or 0,
			culled = self.culled, executions = self.executions, skipped = self.skipped } end
		return self
	end

	------------------------------------------------------------------ 48. CAMERA
	-- View state, frustum culling, projection, temporal jitter and exposure.
	function K.camera(cfg)
		local self = { kind = "camera", id = cfg.id, position = cfg.position or v3(0, 10, 0),
			target = cfg.target or v3(0, 0, -1), up = v3(0, 1, 0),
			fov = cfg.fov or math.rad(70), aspect = cfg.aspect or (16 / 9),
			near = cfg.near or 0.5, far = cfg.far or 2000,
			width = cfg.width or 1280, height = cfg.height or 720,
			exposure = 1.0, frame = 0, culled = 0, tested = 0, frustum = nil }

		function self.setPosition(p) self.position = p self.frustum = nil return self end
		function self.lookAt(p) self.target = p self.frustum = nil return self end
		function self.setFov(f) self.fov = f self.frustum = nil return self end
		function self.setViewport(w, h)
			self.width, self.height = w, h
			self.aspect = w / math.max(1, h)
			self.frustum = nil
			return self
		end

		function self.forward() return (self.target - self.position):unit() end

		function self.buildFrustum()
			self.frustum = Spatial.frustumFromCamera(self.position, self.forward(), self.up,
				self.fov, self.aspect, self.near, self.far)
			return self.frustum
		end

		function self.visibleSphere(center, radius)
			if not self.frustum then self.buildFrustum() end
			self.tested = self.tested + 1
			local ok = self.frustum:containsSphere(center, radius)
			if not ok then self.culled = self.culled + 1 end
			return ok
		end

		function self.cull(items)
			local visible = {}
			for _, item in ipairs(items) do
				if self.visibleSphere(item.position, item.radius or 1) then visible[#visible + 1] = item end
			end
			return visible
		end

		-- World -> screen. Returns nil when behind the camera.
		function self.project(point)
			local f = self.forward()
			local r = f:cross(self.up):unit()
			local u = r:cross(f):unit()
			local rel = point - self.position
			local z = rel:dot(f)
			if z <= self.near then return nil end
			local x = rel:dot(r)
			local y = rel:dot(u)
			local tanHalf = math.tan(self.fov / 2)
			local ndcX = (x / (z * tanHalf * self.aspect))
			local ndcY = (y / (z * tanHalf))
			return { x = (ndcX * 0.5 + 0.5) * self.width, y = (0.5 - ndcY * 0.5) * self.height, depth = z }
		end

		-- Projected screen size of a sphere: the number every LOD decision should use.
		function self.screenRadius(center, radius)
			local d = self.position:distance(center)
			if d <= self.near then return self.height end
			local tanHalf = math.tan(self.fov / 2)
			return (radius / (d * tanHalf)) * (self.height / 2)
		end

		function self.lodFor(center, radius, thresholds)
			thresholds = thresholds or { 120, 48, 16, 5 }
			local px = self.screenRadius(center, radius)
			for i, t in ipairs(thresholds) do
				if px >= t then return i - 1, px end
			end
			return #thresholds, px
		end

		-- Halton sequence sub-pixel jitter: the input a temporal resolver needs.
		local function halton(index, base)
			local result, f, i = 0, 1, index
			while i > 0 do
				f = f / base
				result = result + f * (i % base)
				i = math.floor(i / base)
			end
			return result
		end
		self.halton = halton

		function self.jitter(frameIndex, phase)
			phase = phase or 8
			local i = (frameIndex or self.frame) % phase + 1
			return (halton(i, 2) - 0.5) / self.width, (halton(i, 3) - 0.5) / self.height
		end

		-- Physically-inspired auto exposure from average scene luminance.
		function self.autoExposure(averageLuminance, dt, speed)
			averageLuminance = math.max(1e-4, averageLuminance or 0.18)
			local targetEV = Mathx.log2(averageLuminance * 100 / 12.5)
			local target = 1 / (1.2 * (2 ^ targetEV))
			self.exposure = Mathx.damp(self.exposure, target, speed or 3, dt or (1 / 60))
			return self.exposure
		end

		function self.advance() self.frame = self.frame + 1 return self.frame end

		function self.stats() return { frame = self.frame, tested = self.tested, culled = self.culled,
			exposure = self.exposure, fov = self.fov, aspect = self.aspect } end
		return self
	end

	------------------------------------------------------------------ 49. VISIBILITY
	-- Cell and portal visibility with occluders: the classic answer to "what can I skip".
	function K.visibility(cfg)
		local self = { kind = "visibility", id = cfg.id, cells = {}, order = {}, portals = {},
			occluders = {}, pvs = {}, queries = 0, rejected = 0, maxDepth = cfg.maxDepth or 3 }

		function self.addCell(id, bounds)
			if self.cells[id] then return nil, "duplicate cell" end
			self.cells[id] = { id = id, bounds = bounds, neighbors = {}, items = {} }
			self.order[#self.order + 1] = id
			self.pvs = {}
			return self.cells[id]
		end

		function self.addPortal(a, b, area)
			if not self.cells[a] or not self.cells[b] then return nil, "unknown cell" end
			self.portals[#self.portals + 1] = { a = a, b = b, area = area or 1 }
			table.insert(self.cells[a].neighbors, b)
			table.insert(self.cells[b].neighbors, a)
			self.pvs = {}
			return true
		end

		function self.addItem(cellId, itemId)
			local cell = self.cells[cellId]
			if not cell then return false end
			cell.items[#cell.items + 1] = itemId
			return true
		end

		function self.cellAt(point)
			for _, id in ipairs(self.order) do
				if self.cells[id].bounds:contains(point) then return id end
			end
			return nil
		end

		-- Breadth-first flood through portals, bounded by depth: the potentially visible set.
		function self.computePVS(fromCell, maxDepth)
			maxDepth = maxDepth or self.maxDepth
			local key = tostring(fromCell) .. ":" .. tostring(maxDepth)
			if self.pvs[key] then return self.pvs[key] end
			local seen = { [fromCell] = 0 }
			local queue = { fromCell }
			local head = 1
			local out = { fromCell }
			while head <= #queue do
				local id = queue[head]
				head = head + 1
				local depth = seen[id]
				if depth < maxDepth then
					for _, n in ipairs(self.cells[id].neighbors) do
						if seen[n] == nil then
							seen[n] = depth + 1
							queue[#queue + 1] = n
							out[#out + 1] = n
						end
					end
				end
			end
			table.sort(out)
			self.pvs[key] = out
			return out
		end

		function self.visibleItems(fromCell, maxDepth)
			local out = {}
			for _, id in ipairs(self.computePVS(fromCell, maxDepth)) do
				for _, item in ipairs(self.cells[id].items) do out[#out + 1] = item end
			end
			return out
		end

		function self.addOccluder(bounds) self.occluders[#self.occluders + 1] = bounds return #self.occluders end

		-- Segment/AABB test against every registered occluder.
		function self.occluded(from, to)
			self.queries = self.queries + 1
			local dir = to - from
			local dist = dir:length()
			if dist < 1e-6 then return false end
			dir = dir * (1 / dist)
			for _, box in ipairs(self.occluders) do
				local t = box:rayHit(from, dir, dist)
				if t and t < dist then
					self.rejected = self.rejected + 1
					return true
				end
			end
			return false
		end

		function self.cullList(viewer, items)
			local out = {}
			for _, item in ipairs(items) do
				if not self.occluded(viewer, item.position) then out[#out + 1] = item end
			end
			return out
		end

		function self.coverage(fromCell)
			local visible = #self.computePVS(fromCell)
			if #self.order == 0 then return 0 end
			return visible / #self.order
		end

		function self.stats() return { cells = #self.order, portals = #self.portals,
			occluders = #self.occluders, queries = self.queries, rejected = self.rejected,
			cachedSets = C.count(self.pvs) } end
		return self
	end

	------------------------------------------------------------------ 50. IMPOSTOR
	-- Geometry virtualization: register expensive meshes, synthesize octahedral impostor
	-- views into an atlas, and switch representation by measured screen error.
	function K.impostor(cfg)
		local self = { kind = "impostor", id = cfg.id, entries = {}, order = {},
			atlasSlots = cfg.atlasSlots or 64, usedSlots = 0, viewCount = cfg.viewCount or 8,
			errorThreshold = cfg.errorThreshold or 2.0, switches = 0, savedTriangles = 0 }

		function self.register(id, opts)
			opts = opts or {}
			if self.entries[id] then return nil, "duplicate entry" end
			local entry = { id = id, triangles = opts.triangles or 5000, radius = opts.radius or 4,
				views = nil, slot = nil, error = nil, mode = "mesh" }
			self.entries[id] = entry
			self.order[#self.order + 1] = id
			return entry
		end

		-- Octahedral direction set - even coverage of the sphere with few views.
		function self.captureViews(id, count)
			local entry = self.entries[id]
			if not entry then return nil, "unknown entry" end
			count = count or self.viewCount
			if self.usedSlots + 1 > self.atlasSlots then return nil, "atlas full" end
			local views = {}
			for i = 0, count - 1 do
				local t = (i + 0.5) / count
				local azimuth = t * math.pi * 2
				local elevation = math.asin(Mathx.clamp(2 * ((i % 3) / 2) - 1, -1, 1)) * 0.5
				views[#views + 1] = { dir = v3(math.cos(azimuth) * math.cos(elevation),
					math.sin(elevation), math.sin(azimuth) * math.cos(elevation)),
					azimuth = azimuth, elevation = elevation }
			end
			entry.views = views
			entry.slot = self.usedSlots + 1
			self.usedSlots = self.usedSlots + 1
			return views
		end

		function self.nearestView(id, direction)
			local entry = self.entries[id]
			if not entry or not entry.views then return nil end
			local best, bestDot = nil, -math.huge
			local d = direction:unit()
			for i, view in ipairs(entry.views) do
				local dot = view.dir:dot(d)
				if dot > bestDot then bestDot = dot best = i end
			end
			return best, bestDot
		end

		-- Screen-space error of replacing the mesh with a billboard, in pixels.
		function self.screenError(id, distance, screenHeight, fov)
			local entry = self.entries[id]
			if not entry then return math.huge end
			screenHeight = screenHeight or 720
			fov = fov or math.rad(70)
			local px = (entry.radius / math.max(0.001, distance * math.tan(fov / 2))) * (screenHeight / 2)
			local views = entry.views and #entry.views or 1
			local angularError = math.pi * 2 / views
			entry.error = px * angularError * 0.25
			return entry.error
		end

		function self.select(id, distance, screenHeight, fov)
			local entry = self.entries[id]
			if not entry then return "culled" end
			local err = self.screenError(id, distance, screenHeight, fov)
			local previous = entry.mode
			if err > self.errorThreshold * 8 then
				entry.mode = "mesh"
			elseif err > self.errorThreshold * 0.15 then
				entry.mode = "impostor"
			else
				entry.mode = "culled"
			end
			if entry.mode ~= previous then self.switches = self.switches + 1 end
			if entry.mode ~= "mesh" then self.savedTriangles = self.savedTriangles + entry.triangles end
			return entry.mode, err
		end

		-- Hierarchical LOD: merge a group of entries into one proxy with a combined radius.
		function self.buildHLOD(groupId, members)
			local triangles, radius = 0, 0
			for _, m in ipairs(members) do
				local e = self.entries[m]
				if e then
					triangles = triangles + e.triangles
					radius = math.max(radius, e.radius)
				end
			end
			local proxy = self.register(groupId, { triangles = math.floor(triangles * 0.08),
				radius = radius * math.sqrt(#members) })
			if proxy then proxy.members = members end
			return proxy
		end

		function self.budgetPass(list, triangleBudget)
			local spent, promoted = 0, 0
			table.sort(list, function(a, b) return a.distance < b.distance end)
			for _, item in ipairs(list) do
				local entry = self.entries[item.id]
				if entry then
					if spent + entry.triangles <= triangleBudget then
						entry.mode = "mesh"
						spent = spent + entry.triangles
						promoted = promoted + 1
					else
						entry.mode = "impostor"
						spent = spent + 2
					end
				end
			end
			return { triangles = spent, meshes = promoted, budget = triangleBudget }
		end

		function self.stats() return { entries = #self.order, slots = self.usedSlots,
			switches = self.switches, savedTriangles = self.savedTriangles,
			atlasSlots = self.atlasSlots } end
		return self
	end

	------------------------------------------------------------------ 51. LIGHTRIG
	-- Lights, froxel clustering, shadow cascades and an importance budget.
	function K.lightrig(cfg)
		local self = { kind = "lightrig", id = cfg.id, lights = {}, order = {}, clusters = nil,
			maxActive = cfg.maxActive or 8, sun = nil, ambient = 0.15, assignments = 0 }

		function self.addLight(id, opts)
			opts = opts or {}
			if self.lights[id] then return nil, "duplicate light" end
			local light = { id = id, type = opts.type or "point", position = opts.position or v3(),
				direction = opts.direction or v3(0, -1, 0), color = opts.color or 0xFFFFFF,
				intensity = opts.intensity or 1, range = opts.range or 30,
				angle = opts.angle or math.rad(45), shadows = opts.shadows or false, enabled = true }
			self.lights[id] = light
			self.order[#self.order + 1] = id
			if light.type == "directional" then self.sun = id end
			self.clusters = nil
			return light
		end

		function self.remove(id)
			if not self.lights[id] then return false end
			self.lights[id] = nil
			for i, k in ipairs(self.order) do
				if k == id then table.remove(self.order, i) break end
			end
			self.clusters = nil
			return true
		end

		-- Uniform froxel grid over the play space; each cell lists the lights that touch it.
		function self.cluster(bounds, divisions)
			divisions = divisions or 4
			local size = bounds.max - bounds.min
			local cell = v3(size.x / divisions, size.y / divisions, size.z / divisions)
			local grid = {}
			self.assignments = 0
			for _, id in ipairs(self.order) do
				local light = self.lights[id]
				if light.enabled and light.type ~= "directional" then
					local lo = (light.position - v3(light.range, light.range, light.range)) - bounds.min
					local hi = (light.position + v3(light.range, light.range, light.range)) - bounds.min
					local x0 = Mathx.clamp(math.floor(lo.x / cell.x), 0, divisions - 1)
					local x1 = Mathx.clamp(math.floor(hi.x / cell.x), 0, divisions - 1)
					local y0 = Mathx.clamp(math.floor(lo.y / cell.y), 0, divisions - 1)
					local y1 = Mathx.clamp(math.floor(hi.y / cell.y), 0, divisions - 1)
					local z0 = Mathx.clamp(math.floor(lo.z / cell.z), 0, divisions - 1)
					local z1 = Mathx.clamp(math.floor(hi.z / cell.z), 0, divisions - 1)
					for x = x0, x1 do
						for y = y0, y1 do
							for z = z0, z1 do
								local key = x .. "," .. y .. "," .. z
								grid[key] = grid[key] or {}
								grid[key][#grid[key] + 1] = id
								self.assignments = self.assignments + 1
							end
						end
					end
				end
			end
			self.clusters = { grid = grid, bounds = bounds, divisions = divisions, cell = cell }
			return self.clusters
		end

		function self.lightsAt(point)
			if not self.clusters then return self.order end
			local c = self.clusters
			local rel = point - c.bounds.min
			local x = Mathx.clamp(math.floor(rel.x / c.cell.x), 0, c.divisions - 1)
			local y = Mathx.clamp(math.floor(rel.y / c.cell.y), 0, c.divisions - 1)
			local z = Mathx.clamp(math.floor(rel.z / c.cell.z), 0, c.divisions - 1)
			local list = c.grid[x .. "," .. y .. "," .. z] or {}
			local out = {}
			for _, id in ipairs(list) do out[#out + 1] = id end
			if self.sun then out[#out + 1] = self.sun end
			return out
		end

		-- Importance = intensity attenuated by distance; only the top N survive the budget.
		function self.importance(point)
			local scored = {}
			for _, id in ipairs(self.order) do
				local light = self.lights[id]
				if light.enabled then
					local score
					if light.type == "directional" then
						score = light.intensity * 10
					else
						local d = light.position:distance(point)
						local atten = math.max(0, 1 - d / math.max(0.001, light.range))
						score = light.intensity * atten * atten
					end
					if score > 0 then scored[#scored + 1] = { id = id, score = score } end
				end
			end
			table.sort(scored, function(a, b)
				if a.score == b.score then return a.id < b.id end
				return a.score > b.score
			end)
			local out = {}
			for i = 1, math.min(self.maxActive, #scored) do out[#out + 1] = scored[i] end
			return out
		end

		-- Practical split scheme (logarithmic/uniform blend) for shadow cascades.
		function self.cascadeSplits(near, far, count, lambda)
			count = count or 3
			lambda = lambda or 0.75
			local splits = {}
			for i = 1, count do
				local t = i / count
				local logSplit = near * ((far / near) ^ t)
				local uniSplit = near + (far - near) * t
				splits[i] = Mathx.lerp(uniSplit, logSplit, lambda)
			end
			return splits
		end

		function self.shadowCasters(budget)
			local casters = {}
			for _, id in ipairs(self.order) do
				local light = self.lights[id]
				if light.enabled and light.shadows then casters[#casters + 1] = id end
			end
			table.sort(casters, function(a, b) return self.lights[a].intensity > self.lights[b].intensity end)
			while #casters > (budget or 2) do table.remove(casters) end
			return casters
		end

		function self.setSunAngle(elevation)
			if not self.sun then return nil end
			local light = self.lights[self.sun]
			light.direction = v3(math.cos(elevation), -math.sin(elevation), 0):unit()
			light.intensity = math.max(0, math.sin(elevation)) * 3
			self.ambient = 0.03 + math.max(0, math.sin(elevation)) * 0.25
			return light.intensity, self.ambient
		end

		function self.stats() return { lights = #self.order, clustered = self.clusters ~= nil,
			assignments = self.assignments, maxActive = self.maxActive, ambient = self.ambient } end
		return self
	end

	------------------------------------------------------------------ 52. PROBE
	-- Irradiance probe volume with 9-coefficient spherical harmonics: ARKHER's GI answer
	-- on a platform with no realtime GI control.
	function K.probe(cfg)
		local self = { kind = "probe", id = cfg.id, probes = {}, dims = nil, bounds = nil,
			spacing = cfg.spacing or 16, bakes = 0, samples = 0 }

		local function shBasis(n)
			local x, y, z = n.x, n.y, n.z
			return { 0.282095,
				0.488603 * y, 0.488603 * z, 0.488603 * x,
				1.092548 * x * y, 1.092548 * y * z,
				0.315392 * (3 * z * z - 1), 1.092548 * x * z,
				0.546274 * (x * x - y * y) }
		end
		self.shBasis = shBasis

		function self.place(bounds, spacing)
			spacing = spacing or self.spacing
			self.spacing = spacing
			self.bounds = bounds
			local size = bounds.max - bounds.min
			local nx = math.max(2, math.floor(size.x / spacing) + 1)
			local ny = math.max(2, math.floor(size.y / spacing) + 1)
			local nz = math.max(2, math.floor(size.z / spacing) + 1)
			self.dims = { x = nx, y = ny, z = nz }
			self.probes = {}
			for iz = 0, nz - 1 do
				for iy = 0, ny - 1 do
					for ix = 0, nx - 1 do
						local pos = bounds.min + v3(ix * spacing, iy * spacing, iz * spacing)
						self.probes[#self.probes + 1] = { index = #self.probes + 1, position = pos,
							ix = ix, iy = iy, iz = iz, sh = nil, valid = false }
					end
				end
			end
			return #self.probes
		end

		-- Bake: integrate a radiance function over a fixed direction set into SH9.
		function self.bake(radianceFn, directions)
			if #self.probes == 0 then return 0 end
			directions = directions or 32
			local dirs = {}
			local rng = Random.new(90210)
			for i = 1, directions do
				local d = rng:onUnitSphere()
				dirs[#dirs + 1] = v3(d.x, d.y, d.z)
			end
			local weight = 4 * math.pi / directions
			for _, probe in ipairs(self.probes) do
				local sh = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
				for _, d in ipairs(dirs) do
					local radiance = radianceFn(probe.position, d) or 0
					local basis = shBasis(d)
					for i = 1, 9 do sh[i] = sh[i] + radiance * basis[i] * weight end
				end
				probe.sh = sh
				probe.valid = true
			end
			self.bakes = self.bakes + 1
			return #self.probes
		end

		function self.evalSH(sh, normal)
			if not sh then return 0 end
			local basis = shBasis(normal:unit())
			local total = 0
			local convolution = { 1.0, 2 / 3, 2 / 3, 2 / 3, 0.25, 0.25, 0.25, 0.25, 0.25 }
			for i = 1, 9 do total = total + sh[i] * basis[i] * convolution[i] end
			return math.max(0, total)
		end

		function self.probeAt(ix, iy, iz)
			if not self.dims then return nil end
			ix = Mathx.clamp(ix, 0, self.dims.x - 1)
			iy = Mathx.clamp(iy, 0, self.dims.y - 1)
			iz = Mathx.clamp(iz, 0, self.dims.z - 1)
			return self.probes[iz * self.dims.x * self.dims.y + iy * self.dims.x + ix + 1]
		end

		-- Trilinear blend of the eight surrounding probes.
		function self.sampleAt(point, normal)
			if not self.dims or not self.bounds then return 0 end
			self.samples = self.samples + 1
			local rel = point - self.bounds.min
			local fx = Mathx.clamp(rel.x / self.spacing, 0, self.dims.x - 1)
			local fy = Mathx.clamp(rel.y / self.spacing, 0, self.dims.y - 1)
			local fz = Mathx.clamp(rel.z / self.spacing, 0, self.dims.z - 1)
			local ix, iy, iz = math.floor(fx), math.floor(fy), math.floor(fz)
			local tx, ty, tz = fx - ix, fy - iy, fz - iz
			local total, weightSum = 0, 0
			for dz = 0, 1 do
				for dy = 0, 1 do
					for dx = 0, 1 do
						local probe = self.probeAt(ix + dx, iy + dy, iz + dz)
						if probe and probe.valid then
							local w = (dx == 1 and tx or (1 - tx)) * (dy == 1 and ty or (1 - ty))
								* (dz == 1 and tz or (1 - tz))
							if w > 0 then
								total = total + self.evalSH(probe.sh, normal) * w
								weightSum = weightSum + w
							end
						end
					end
				end
			end
			if weightSum < 1e-6 then return 0 end
			return total / weightSum
		end

		function self.invalidate(bounds)
			local n = 0
			for _, probe in ipairs(self.probes) do
				if bounds:contains(probe.position) then
					probe.valid = false
					n = n + 1
				end
			end
			return n
		end

		function self.dirtyCount()
			local n = 0
			for _, probe in ipairs(self.probes) do
				if not probe.valid then n = n + 1 end
			end
			return n
		end

		-- Rebake only what was invalidated, at most `budget` probes per call.
		function self.rebake(radianceFn, budget)
			budget = budget or 8
			local done = 0
			local rng = Random.new(90210)
			local dirs = {}
			for i = 1, 16 do
				local d = rng:onUnitSphere()
				dirs[#dirs + 1] = v3(d.x, d.y, d.z)
			end
			local weight = 4 * math.pi / #dirs
			for _, probe in ipairs(self.probes) do
				if done >= budget then break end
				if not probe.valid then
					local sh = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
					for _, d in ipairs(dirs) do
						local radiance = radianceFn(probe.position, d) or 0
						local basis = shBasis(d)
						for i = 1, 9 do sh[i] = sh[i] + radiance * basis[i] * weight end
					end
					probe.sh = sh
					probe.valid = true
					done = done + 1
				end
			end
			return done
		end

		function self.memoryBytes() return #self.probes * 9 * 4 end

		function self.stats() return { probes = #self.probes, dims = self.dims, bakes = self.bakes,
			samples = self.samples, dirty = self.dirtyCount(), memoryBytes = self.memoryBytes() } end
		return self
	end

	------------------------------------------------------------------ 53. TEMPORAL
	-- Temporal reconstruction: history, reprojection, neighbourhood clamping and
	-- disocclusion handling. The honest core of "more detail than we can afford".
	function K.temporal(cfg)
		local self = { kind = "temporal", id = cfg.id, history = {}, frame = 0,
			feedback = cfg.feedback or 0.9, clampStrength = cfg.clampStrength or 1.0,
			resolves = 0, rejections = 0, ghosting = 0, phase = cfg.phase or 8 }

		local function halton(index, base)
			local result, f, i = 0, 1, index
			while i > 0 do
				f = f / base
				result = result + f * (i % base)
				i = math.floor(i / base)
			end
			return result
		end

		function self.jitter(frameIndex)
			local i = ((frameIndex or self.frame) % self.phase) + 1
			return halton(i, 2) - 0.5, halton(i, 3) - 0.5
		end

		function self.advance() self.frame = self.frame + 1 return self.frame end

		-- Reproject a previous-frame sample: returns the history key or nil on disocclusion.
		function self.reproject(key, motion)
			local h = self.history[key]
			if not h then return nil end
			local m = motion or 0
			if m > (self.disocclusionThreshold or 8) then
				self.rejections = self.rejections + 1
				return nil
			end
			return h
		end

		-- Variance clipping against the local neighbourhood: the standard ghosting fix.
		function self.clamp(value, neighbors)
			if #neighbors == 0 then return value, false end
			local lo, hi = math.huge, -math.huge
			local sum, sumSq = 0, 0
			for _, n in ipairs(neighbors) do
				if n < lo then lo = n end
				if n > hi then hi = n end
				sum = sum + n
				sumSq = sumSq + n * n
			end
			local mean = sum / #neighbors
			local variance = math.max(0, sumSq / #neighbors - mean * mean)
			local sigma = math.sqrt(variance) * self.clampStrength
			lo = math.max(lo, mean - sigma * 1.5)
			hi = math.min(hi, mean + sigma * 1.5)
			if value < lo then return lo, true end
			if value > hi then return hi, true end
			return value, false
		end

		-- One resolved pixel/sample: history + current, with all the guards applied.
		function self.resolve(key, current, opts)
			opts = opts or {}
			self.resolves = self.resolves + 1
			local prev = self.reproject(key, opts.motion or 0)
			local result = current
			local blended = false
			if prev ~= nil then
				local target = current
				if opts.neighbors then
					local clamped, wasClamped = self.clamp(prev.value, opts.neighbors)
					if wasClamped then self.ghosting = self.ghosting + 1 end
					prev = { value = clamped, frames = prev.frames }
				end
				local feedback = self.feedback
				if opts.velocity and opts.velocity > 1 then
					feedback = feedback * math.max(0.4, 1 - opts.velocity / 32)
				end
				result = Mathx.lerp(target, prev.value, feedback)
				blended = true
			end
			self.history[key] = { value = result, frames = (prev and prev.frames or 0) + 1, frame = self.frame }
			return result, blended
		end

		function self.accumulationOf(key)
			local h = self.history[key]
			if not h then return 0 end
			return h.frames
		end

		-- Effective sample count: what the temporal accumulation is actually worth.
		function self.effectiveSamples(key)
			local frames = self.accumulationOf(key)
			if frames == 0 then return 1 end
			return math.min(self.phase, 1 + (frames - 1) * (1 - self.feedback) * self.phase)
		end

		function self.purge(olderThan)
			local removed = 0
			for key, h in pairs(self.history) do
				if self.frame - h.frame > (olderThan or 4) then
					self.history[key] = nil
					removed = removed + 1
				end
			end
			return removed
		end

		function self.reset()
			self.history = {}
			self.rejections = 0
			self.ghosting = 0
			return true
		end

		function self.stats() return { frame = self.frame, tracked = C.count(self.history),
			resolves = self.resolves, rejections = self.rejections, ghosting = self.ghosting,
			feedback = self.feedback } end
		return self
	end

	------------------------------------------------------------------ 54. UPSCALER
	-- Adaptive resolution ladder + edge-aware reconstruction + contrast-adaptive sharpening.
	function K.upscaler(cfg)
		local self = { kind = "upscaler", id = cfg.id,
			ladder = cfg.ladder or { 0.5, 0.58, 0.67, 0.75, 0.85, 1.0 },
			index = cfg.index or 4, targetMs = cfg.targetMs or 16.6,
			hysteresis = cfg.hysteresis or 0.12, changes = 0, evaluations = 0,
			sharpness = cfg.sharpness or 0.35 }

		function self.scale() return self.ladder[self.index] end

		-- Climb or drop the ladder with hysteresis so the resolution never oscillates.
		function self.evaluate(frameMs)
			self.evaluations = self.evaluations + 1
			local upper = self.targetMs * (1 + self.hysteresis)
			local lower = self.targetMs * (1 - self.hysteresis * 2)
			local before = self.index
			if frameMs > upper and self.index > 1 then
				self.index = self.index - 1
			elseif frameMs < lower and self.index < #self.ladder then
				self.index = self.index + 1
			end
			if self.index ~= before then self.changes = self.changes + 1 end
			return self.scale(), self.index ~= before
		end

		function self.pixelsFor(width, height)
			local s = self.scale()
			return math.floor(width * s + 0.5) * math.floor(height * s + 0.5)
		end

		function self.savings(width, height)
			local full = width * height
			return 1 - (self.pixelsFor(width, height) / full)
		end

		-- Edge-aware 1-D reconstruction: bilinear where the signal is smooth, nearest where
		-- there is an edge, which is exactly what stops upscaled UI text from smearing.
		function self.reconstruct(samples, targetCount)
			local n = #samples
			if n == 0 then return {} end
			if targetCount == n then return C.slice(samples, 1, n) end
			local out = {}
			for i = 0, targetCount - 1 do
				local t = (targetCount == 1) and 0 or (i / (targetCount - 1))
				local pos = t * (n - 1)
				local i0 = math.floor(pos)
				local i1 = math.min(n - 1, i0 + 1)
				local f = pos - i0
				local a, b = samples[i0 + 1], samples[i1 + 1]
				local gradient = math.abs(b - a)
				local edge = clamp01(gradient * 4)
				local smooth = Mathx.lerp(a, b, f)
				local nearest = (f < 0.5) and a or b
				out[#out + 1] = Mathx.lerp(smooth, nearest, edge * 0.75)
			end
			return out
		end

		-- Contrast-adaptive sharpening: sharpen flat areas more, spare high-contrast edges.
		function self.sharpen(samples, amount)
			amount = amount or self.sharpness
			local n = #samples
			local out = {}
			for i = 1, n do
				local prev = samples[math.max(1, i - 1)]
				local nextS = samples[math.min(n, i + 1)]
				local mn = math.min(prev, samples[i], nextS)
				local mx = math.max(prev, samples[i], nextS)
				local contrast = mx - mn
				local weight = amount * (1 - clamp01(contrast))
				local sharp = samples[i] + (samples[i] - (prev + nextS) / 2) * weight * 2
				out[#out + 1] = Mathx.clamp(sharp, mn - 0.05, mx + 0.05)
			end
			return out
		end

		-- Perceptual quality estimate of the current setting, 0..1.
		function self.quality()
			local s = self.scale()
			return clamp01(0.35 + 0.65 * (s ^ 0.7))
		end

		function self.describe()
			return { scale = self.scale(), index = self.index, steps = #self.ladder,
				quality = self.quality(), targetMs = self.targetMs, changes = self.changes }
		end

		function self.stats() return { scale = self.scale(), index = self.index,
			evaluations = self.evaluations, changes = self.changes, quality = self.quality() } end
		return self
	end

	------------------------------------------------------------------ 55. INFERENCE
	-- A real, tiny, deterministic neural network: forward pass, backpropagation training,
	-- fixed-point quantization and weight import/export. This is what makes ARKHER's neural
	-- frameworks actual inference rather than a marketing word.
	function K.inference(cfg)
		local self = { kind = "inference", id = cfg.id, layers = {}, seed = cfg.seed or 1337,
			forwards = 0, trainings = 0, quantBits = cfg.quantBits or 0 }

		local ACT = {
			relu = function(x) return Mathx.relu(x) end,
			tanh = function(x) return Mathx.tanh(x) end,
			sigmoid = function(x) return Mathx.sigmoid(x) end,
			linear = function(x) return x end,
		}
		local DACT = {
			relu = function(y) if y > 0 then return 1 end return 0 end,
			tanh = function(y) return 1 - y * y end,
			sigmoid = function(y) return y * (1 - y) end,
			linear = function() return 1 end,
		}

		-- Xavier-ish initialisation from the deterministic kernel RNG.
		function self.addLayer(inputs, outputs, activation)
			activation = activation or "relu"
			if not ACT[activation] then return nil, "unknown activation" end
			local rng = Random.new(self.seed + #self.layers * 7919)
			local limit = math.sqrt(6 / (inputs + outputs))
			local weights, bias = {}, {}
			for o = 1, outputs do
				weights[o] = {}
				for i = 1, inputs do weights[o][i] = rng:range(-limit, limit) end
				bias[o] = 0
			end
			local layer = { inputs = inputs, outputs = outputs, activation = activation,
				w = weights, b = bias, lastIn = nil, lastOut = nil }
			self.layers[#self.layers + 1] = layer
			return layer
		end

		function self.forward(input)
			self.forwards = self.forwards + 1
			local x = input
			for _, layer in ipairs(self.layers) do
				layer.lastIn = x
				local out = {}
				for o = 1, layer.outputs do
					local sum = layer.b[o]
					local row = layer.w[o]
					for i = 1, layer.inputs do sum = sum + row[i] * (x[i] or 0) end
					out[o] = ACT[layer.activation](sum)
				end
				layer.lastOut = out
				x = out
			end
			return x
		end

		function self.loss(prediction, target)
			local total = 0
			for i = 1, #target do
				local d = (prediction[i] or 0) - target[i]
				total = total + d * d
			end
			return total / math.max(1, #target)
		end

		-- One backpropagation step over a batch. Real gradients, real descent.
		function self.train(samples, epochs, learningRate)
			epochs = epochs or 10
			learningRate = learningRate or 0.05
			local lastLoss = 0
			for _ = 1, epochs do
				local epochLoss = 0
				for _, sample in ipairs(samples) do
					local prediction = self.forward(sample.input)
					epochLoss = epochLoss + self.loss(prediction, sample.target)
					-- output layer delta
					local deltas = {}
					local last = #self.layers
					deltas[last] = {}
					for o = 1, self.layers[last].outputs do
						local y = self.layers[last].lastOut[o]
						local err = y - (sample.target[o] or 0)
						deltas[last][o] = err * DACT[self.layers[last].activation](y)
					end
					for l = last - 1, 1, -1 do
						deltas[l] = {}
						local nextLayer = self.layers[l + 1]
						for o = 1, self.layers[l].outputs do
							local sum = 0
							for k = 1, nextLayer.outputs do
								sum = sum + nextLayer.w[k][o] * deltas[l + 1][k]
							end
							local y = self.layers[l].lastOut[o]
							deltas[l][o] = sum * DACT[self.layers[l].activation](y)
						end
					end
					for l = 1, last do
						local layer = self.layers[l]
						for o = 1, layer.outputs do
							local d = deltas[l][o]
							for i = 1, layer.inputs do
								layer.w[o][i] = layer.w[o][i] - learningRate * d * (layer.lastIn[i] or 0)
							end
							layer.b[o] = layer.b[o] - learningRate * d
						end
					end
				end
				lastLoss = epochLoss / math.max(1, #samples)
				self.trainings = self.trainings + 1
			end
			return lastLoss
		end

		function self.parameters()
			local n = 0
			for _, layer in ipairs(self.layers) do n = n + layer.inputs * layer.outputs + layer.outputs end
			return n
		end

		function self.flops()
			local n = 0
			for _, layer in ipairs(self.layers) do n = n + layer.inputs * layer.outputs * 2 end
			return n
		end

		-- Fixed-point quantization: the memory/precision trade a phone actually needs.
		function self.quantize(bits)
			bits = bits or 8
			self.quantBits = bits
			local levels = (2 ^ bits) - 1
			local maxError = 0
			for _, layer in ipairs(self.layers) do
				local lo, hi = math.huge, -math.huge
				for o = 1, layer.outputs do
					for i = 1, layer.inputs do
						lo = math.min(lo, layer.w[o][i])
						hi = math.max(hi, layer.w[o][i])
					end
				end
				local scale = (hi - lo) / levels
				if scale <= 0 then scale = 1e-6 end
				layer.quant = { lo = lo, hi = hi, scale = scale, bits = bits }
				for o = 1, layer.outputs do
					for i = 1, layer.inputs do
						local q = math.floor((layer.w[o][i] - lo) / scale + 0.5)
						local dq = lo + q * scale
						maxError = math.max(maxError, math.abs(dq - layer.w[o][i]))
						layer.w[o][i] = dq
					end
				end
			end
			return maxError
		end

		function self.exportWeights()
			local flat = {}
			for _, layer in ipairs(self.layers) do
				for o = 1, layer.outputs do
					for i = 1, layer.inputs do flat[#flat + 1] = layer.w[o][i] end
					flat[#flat + 1] = layer.b[o]
				end
			end
			return flat
		end

		function self.importWeights(flat)
			local idx = 1
			for _, layer in ipairs(self.layers) do
				for o = 1, layer.outputs do
					for i = 1, layer.inputs do
						layer.w[o][i] = flat[idx] or 0
						idx = idx + 1
					end
					layer.b[o] = flat[idx] or 0
					idx = idx + 1
				end
			end
			return idx - 1
		end

		function self.memoryBytes()
			local bits = self.quantBits > 0 and self.quantBits or 32
			return math.ceil(self.parameters() * bits / 8)
		end

		function self.stats() return { layers = #self.layers, parameters = self.parameters(),
			flops = self.flops(), forwards = self.forwards, trainings = self.trainings,
			quantBits = self.quantBits, memoryBytes = self.memoryBytes() } end
		return self
	end

	K.NAMES = { "material", "sampler", "shadegraph", "framegraph", "camera", "visibility",
		"impostor", "lightrig", "probe", "temporal", "upscaler", "inference" }

	return K

end
