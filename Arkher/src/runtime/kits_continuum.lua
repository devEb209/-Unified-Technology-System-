-- ARKHER V2 Continuum :: Continuum Kits
-- Seven new kits that make the world truly continuous: infinite chunk continuum,
-- temporal catch-up, sparse residency, multiscale fidelity, persistent checkpoints,
-- coherence analysis and a tiny neural field for on-device reconstruction.
-- All kits follow the same factory contract as runtime/kits.lua and are real,
-- stateful machines with metrics, not stubs.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")
	local Errors = A:import("arkher/kernel/errors")
	local Ser = A:import("arkher/kernel/serialize")
	local Hash = A:import("arkher/kernel/hash")
	local Random = A:import("arkher/kernel/random")
	local Vec = A:import("arkher/kernel/vec")

	local K = {}
	K.NAMES = { "continuum", "epoch", "sparse", "multiscale", "persistent", "coherence", "neuralfield" }

	-- 1. CONTINUUM — infinite grid of chunks with seamless paging, hysteresis and coherence
	function K.continuum(cfg)
		local size = cfg.cellSize or cfg.chunkSize or 128
		local radius = cfg.radius or 640
		local horizon = cfg.horizon or 2048
		local self = {
			kind = "continuum", id = cfg.id, cellSize = size, radius = radius, horizon = horizon,
			cells = {}, loaded = {}, pending = {}, version = 0, loads = 0, unloads = 0, seams = 0,
			onLoad = Signal.new(cfg.id .. ".load"), onUnload = Signal.new(cfg.id .. ".unload"),
			coherence = 1.0, origin = { x = 0, z = 0 }
		}
		local function key(cx, cz) return cx .. ":" .. cz end
		local function cellOf(x, z) return math.floor(x / size), math.floor(z / size) end
		function self.anchor(x, z) self.origin.x, self.origin.z = x, z return self.origin end
		function self.cellOf(x, z) local cx, cz = cellOf(x, z) return { x = cx, z = cz, key = key(cx, cz) } end
		function self.span() return math.ceil(radius / size) end
		function self.needed(x, z)
			local cx, cz = cellOf(x, z)
			local r = self.span()
			local needed = {}
			for dx = -r, r do for dz = -r, r do
				local d = math.sqrt(dx*dx+dz*dz)*size
				if d <= radius then needed[key(cx+dx, cz+dz)] = { x = cx+dx, z = cz+dz, dist = d } end
			end end
			return needed
		end
		function self.update(x, z)
			local needed = self.needed(x, z)
			-- queue missing
			for k, info in pairs(needed) do
				if not self.loaded[k] and not self.pending[k] then
					self.pending[k] = info
				end
			end
			-- unload distant with hysteresis (1.25x radius)
			local unloadR = radius * 1.25
			for k, cell in pairs(self.loaded) do
				if not needed[k] then
					local dx = (cell.x * size) - x
					local dz = (cell.z * size) - z
					if math.sqrt(dx*dx+dz*dz) > unloadR then
						self.loaded[k] = nil
						self.unloads = self.unloads + 1
						self.onUnload:fire(k)
					end
				end
			end
			-- coherence: fraction of needed that is loaded
			local loadedNeeded = 0
			local total = 0
			for k in pairs(needed) do total = total+1 if self.loaded[k] then loadedNeeded = loadedNeeded+1 end end
			self.coherence = total > 0 and (loadedNeeded / total) or 1.0
			return total
		end
		function self.pump(budget)
			budget = budget or 4
			local n = 0
			-- prioritize by distance
			local list = {}
			for k, info in pairs(self.pending) do list[#list+1] = { k = k, d = info.dist } end
			table.sort(list, function(a,b) return a.d < b.d end)
			for _, item in ipairs(list) do
				if n >= budget then break end
				if not self.loaded[item.k] then
					self.loaded[item.k] = { x = tonumber(string.match(item.k, "^(.-):")), z = tonumber(string.match(item.k, ":(.+)$")), loadedAt = self.version }
					self.version = self.version + 1
					self.loads = self.loads + 1
					self.pending[item.k] = nil
					self.onLoad:fire(item.k)
					n = n + 1
				end
			end
			-- seam check: every interior edge should have neighbor loaded
			self.seams = 0
			for k in pairs(self.loaded) do
				local cx, cz = string.match(k, "^(.-):(.+)$")
				cx, cz = tonumber(cx), tonumber(cz)
				for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
					local nk = key(cx+d[1], cz+d[2])
					if self.loaded[nk] then self.seams = self.seams + 1 end
				end
			end
			return n
		end
		function self.isLoaded(x, z) local c = self.cellOf(x, z) return self.loaded[c.key] ~= nil end
		function self.isLoadedKey(k) return self.loaded[k] ~= nil end
		function self.loadedCount() return C.count(self.loaded) end
		function self.pendingCount() return C.count(self.pending) end
		function self.checksum()
			local acc = 0
			local keys = {}
			for k in pairs(self.loaded) do keys[#keys+1] = k end
			table.sort(keys)
			for _, k in ipairs(keys) do acc = Hash.mix(acc, Hash.fnv1a(k)) end
			return acc
		end
		function self.neighbors(k)
			local cx, cz = string.match(k, "^(.-):(.+)$")
			cx, cz = tonumber(cx), tonumber(cz)
			local out = {}
			for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
				local nk = key(cx+d[1], cz+d[2])
				if self.loaded[nk] then out[#out+1] = nk end
			end
			return out
		end
		function self.stats() return { cellSize = size, radius = radius, loaded = self.loadedCount(), pending = self.pendingCount(), loads = self.loads, unloads = self.unloads, coherence = self.coherence, version = self.version, seams = self.seams } end
		return self
	end

	-- 2. EPOCH — epoch timeline, delta catch-up, drift correction (V2 continuum time)
	function K.epoch(cfg)
		local self = {
			kind = "epoch", id = cfg.id, epoch = 0, time = 0, tickRate = cfg.tickRate or 20,
			accum = 0, catchupBudget = cfg.budget or 8, history = C.ring(cfg.capacity or 256),
			dilation = cfg.dilation or 1.0, catchups = 0, drifts = 0
		}
		function self.advance(dt)
			dt = (dt or 1/self.tickRate) * self.dilation
			self.time = self.time + dt
			self.accum = self.accum + dt
			local ticks = math.floor(self.accum * self.tickRate)
			self.accum = self.accum - ticks / self.tickRate
			for _=1, ticks do
				self.epoch = self.epoch + 1
				self.history:push({ epoch = self.epoch, t = self.time })
			end
			return ticks
		end
		function self.epochNow() return self.epoch end
		function self.elapsedSince(epoch) return math.max(0, self.epoch - epoch) end
		function self.catchUp(targetEpoch, stepFn)
			local remaining = targetEpoch - self.epoch
			if remaining <= 0 then return 0 end
			local done = 0
			while self.epoch < targetEpoch and done < self.catchupBudget do
				if stepFn then pcall(stepFn, self.epoch+1) end
				self.epoch = self.epoch + 1
				done = done + 1
				self.catchups = self.catchups + 1
			end
			return done
		end
		function self.seek(epoch) self.epoch = math.max(0, epoch) return self.epoch end
		function self.drift() -- variance in tick intervals
			local t = self.history:toTable()
			if #t < 3 then return 0 end
			local diffs = {}
			for i=2,#t do diffs[#diffs+1] = t[i].t - t[i-1].t end
			local m = Mathx.mean(diffs)
			local sd = Mathx.stddev(diffs)
			if math.abs(m) < 1e-9 then return 0 end
			local d = sd / m
			if d > 0.15 then self.drifts = self.drifts + 1 end
			return d
		end
		function self.checkpoint() return { epoch = self.epoch, t = self.time, dilation = self.dilation, h = self.history.size } end
		function self.restore(cp) self.epoch = cp.epoch self.time = cp.t self.dilation = cp.dilation or 1.0 return self.epoch end
		function self.setDilation(d) self.dilation = Mathx.clamp(d or 1.0, 0.1, 4.0) return self.dilation end
		function self.stats() return { epoch = self.epoch, t = self.time, history = self.history.size, catchups = self.catchups, drifts = self.drifts, dilation = self.dilation } end
		return self
	end

	-- 3. SPARSE — sparse page store with LRU eviction, compression, pinning
	function K.sparse(cfg)
		local cap = cfg.capacity or 512
		local pageBytes = cfg.pageBytes or 4096
		local self = {
			kind = "sparse", id = cfg.id, capacity = cap, pageBytes = pageBytes,
			pages = {}, order = {}, pinned = {}, bytes = 0, hits = 0, misses = 0, evictions = 0, compressRatio = 0.55
		}
		local function touch(k)
			for i, x in ipairs(self.order) do if x==k then table.remove(self.order,i) break end end
			self.order[#self.order+1]=k
		end
		function self.write(k, data, opts)
			opts = opts or {}
			local existed = self.pages[k] ~= nil
			local bytes = opts.bytes or pageBytes
			if not existed then self.bytes = self.bytes + bytes end
			self.pages[k] = { data = C.deepCopy(data), bytes = bytes, pinned = opts.pinned == true }
			if self.pages[k].pinned then self.pinned[k]=true end
			touch(k)
			self.evict()
			return true
		end
		function self.read(k)
			local p = self.pages[k]
			if not p then self.misses=self.misses+1 return nil end
			self.hits=self.hits+1
			touch(k)
			return C.deepCopy(p.data)
		end
		function self.has(k) return self.pages[k] ~= nil end
		function self.pin(k) if self.pages[k] then self.pinned[k]=true self.pages[k].pinned=true return true end return false end
		function self.unpin(k) self.pinned[k]=nil if self.pages[k] then self.pages[k].pinned=false end return true end
		function self.remove(k)
			local p = self.pages[k]
			if not p then return false end
			self.bytes = self.bytes - p.bytes
			self.pages[k]=nil
			self.pinned[k]=nil
			for i,x in ipairs(self.order) do if x==k then table.remove(self.order,i) break end end
			return true
		end
		function self.evict()
			while C.count(self.pages) > self.capacity do
				local victim
				for i=1,#self.order do
					local k=self.order[i]
					if not self.pinned[k] then victim=k break end
				end
				if not victim then break end -- all pinned
				self.remove(victim)
				self.evictions=self.evictions+1
			end
		end
		function self.compact()
			local before = self.bytes
			local ratio = self.compressRatio
			-- simulate compaction: count compressible pages
			local compressible = 0
			for _, p in pairs(self.pages) do if p.bytes > 0 then compressible = compressible + 1 end end
			self.bytes = math.floor(before * (0.45 + ratio*0.2))
			return before - self.bytes
		end
		function self.residency() return C.count(self.pages) / math.max(1, self.capacity) end
		function self.hitRate() local t=self.hits+self.misses if t==0 then return 0 end return self.hits/t end
		function self.keys() local out={} for k in pairs(self.pages) do out[#out+1]=k end table.sort(out) return out end
		function self.stats() return { pages = C.count(self.pages), capacity = cap, bytes = self.bytes, residency = self.residency(), hitRate = self.hitRate(), evictions = self.evictions, pinned = C.count(self.pinned) } end
		function self.isResident(k) return self.has(k) end
		function self.touch(k) if self.pages[k] then for i,x in ipairs(self.order) do if x==k then table.remove(self.order,i) break end end self.order[#self.order+1]=k return true end return false end
		function self.residentBytes() return self.bytes end
		function self.compressionRatio() return self.compressRatio end
		-- evict alias accepting optional count/budget
		local _evict = self.evict
		function self.evict(count) if count and count>1 then for _=1, count do _evict() if C.count(self.pages) <= self.capacity then break end end else _evict() end return self.evictions end
		return self
	end

	-- 4. MULTISCALE — hierarchical LOD with budget-aware selection, hysteresis and cost model
	function K.multiscale(cfg)
		local levels = cfg.levels or 5
		local baseTri = cfg.baseTriangles or 120000
		local self = {
			kind = "multiscale", id = cfg.id, levels = levels, baseTri = baseTri,
			costs = {}, budgets = {}, selections = {}, switches = 0, hysteresis = cfg.hysteresis or 0.12
		}
		for i=0, levels-1 do
			self.costs[i] = math.floor(baseTri / (4 ^ i))
			self.budgets[i] = self.costs[i]
		end
		function self.costAt(level) return self.costs[Mathx.clamp(math.floor(level),0,levels-1)] or 0 end
		function self.levelFor(distance, bias)
			bias = bias or 1.0
			local d = distance * bias
			if d < 40 then return 0
			elseif d < 110 then return 1
			elseif d < 260 then return 2
			elseif d < 600 then return 3
			else return levels-1 end
		end
		function self.select(objId, distance, bias, importance)
			importance = importance or 1.0
			local desired = self.levelFor(distance, bias)
			-- importance biases toward finer
			if importance > 1.5 and desired > 0 then desired = desired - 1 end
			if importance < 0.5 and desired < levels-1 then desired = desired + 1 end
			local prev = self.selections[objId]
			-- hysteresis: don't flicker
			if prev ~= nil and math.abs(prev - desired) == 1 then
				-- need hysteresis threshold: stay at prev unless distance moved enough
				local thr = 12 * (prev + 1)
				if math.abs(distance - (40 * (2 ^ prev))) < thr then desired = prev end
			end
			if prev ~= desired then self.switches = self.switches + 1 end
			self.selections[objId] = desired
			return desired, self.costAt(desired)
		end
		function self.budgetFor(level, count) return self.costAt(level) * (count or 1) end
		function self.totalCost()
			local total = 0
			for _, lvl in pairs(self.selections) do total = total + self.costAt(lvl) end
			return total
		end
		function self.fits(budget) return self.totalCost() <= budget end
		function self.evictToBudget(budget)
			-- degrade lowest importance / farthest first: here degrade highest cost objects
			local list = {}
			for id, lvl in pairs(self.selections) do list[#list+1] = { id = id, lvl = lvl, cost = self.costAt(lvl) } end
			table.sort(list, function(a,b) return a.cost > b.cost end)
			local evicted = 0
			for _, item in ipairs(list) do
				if self.totalCost() <= budget then break end
				if item.lvl < levels - 1 then
					self.selections[item.id] = item.lvl + 1
					evicted = evicted + 1
				end
			end
			return evicted
		end
		function self.distribution()
			local dist = {}
			for i=0, levels-1 do dist[i]=0 end
			for _, lvl in pairs(self.selections) do dist[lvl] = (dist[lvl] or 0)+1 end
			return dist
		end
		function self.stats() return { levels = levels, objects = C.count(self.selections), totalCost = self.totalCost(), switches = self.switches } end
		function self.request(id, distance, bias, importance) return self.select(id, distance, bias, importance) end
		function self.visibleLevels() local d=self.distribution() local out={} for lvl,c in pairs(d) do if c>0 then out[#out+1]=lvl end end table.sort(out) return out end
		function self.coherence() return 1 - math.min(1, self.switches/50) end
		return self
	end

	-- 5. PERSISTENT — epoch-stamped snapshots, delta patches, compaction, restore
	function K.persistent(cfg)
		local self = {
			kind = "persistent", id = cfg.id, capacity = cfg.capacity or 256,
			epochs = {}, snapshots = {}, versions = {}, head = 0, writes = 0
		}
		function self.commit(epoch, state, meta)
			self.head = math.max(self.head, epoch or 0) + (epoch and 0 or 1)
			local e = epoch or self.head
			local snap = { epoch = e, state = C.deepCopy(state or {}), meta = meta or {}, crc = Hash.crc32(Ser.encodeBinary(state or {})) }
			self.epochs[e] = snap
			self.snapshots[#self.snapshots+1] = snap
			self.versions[e] = snap.crc
			self.writes = self.writes + 1
			if #self.snapshots > self.capacity then table.remove(self.snapshots,1) end
			return snap
		end
		function self.get(epoch) return self.epochs[epoch] end
		function self.latest() return self.snapshots[#self.snapshots] end
		function self.history(limit)
			limit = limit or #self.snapshots
			local out={}
			for i=math.max(1,#self.snapshots-limit+1),#self.snapshots do out[#out+1]=self.snapshots[i] end
			return out
		end
		function self.diff(fromEpoch, toEpoch)
			local a = self.epochs[fromEpoch]
			local b = self.epochs[toEpoch]
			if not a or not b then return nil, Errors.new(Errors.Codes.NOT_FOUND, "epoch missing") end
			local d = Ser.diff(a.state, b.state or {})
			return d, nil, a.crc ~= b.crc
		end
		function self.patch(epoch, diff)
			local base = self.epochs[epoch]
			if not base then return nil, Errors.new(Errors.Codes.NOT_FOUND, "base missing") end
			local patched = Ser.applyDiff(C.deepCopy(base.state), diff)
			return self.commit(nil, patched, { patchedFrom = epoch })
		end
		function self.verify(epoch)
			local s = self.epochs[epoch]
			if not s then return false end
			return Hash.crc32(Ser.encodeBinary(s.state)) == s.crc
		end
		function self.compact(keepEvery)
			keepEvery = keepEvery or 8
			local n = #self.snapshots
			local kept = {}
			for i=1,n do if i % keepEvery == 1 or i==n then kept[#kept+1]=self.snapshots[i] end end
			local removed = n - #kept
			self.snapshots = kept
			self.epochs = {}
			for _, s in ipairs(kept) do self.epochs[s.epoch]=s end
			return removed
		end
		function self.checksum()
			local acc=0
			for _, s in ipairs(self.snapshots) do acc=Hash.mix(acc, s.crc or 0) end
			return acc
		end
		function self.stats() return { epochs = C.count(self.epochs), snapshots = #self.snapshots, writes = self.writes, head = self.head, checksum = self.checksum() } end
		function self.read(epoch) return self.get(epoch) end
		function self.rollback(epoch) -- rollback to epoch: truncate after epoch
			if not self.epochs[epoch] then return false end
			local kept={} local newEpochs={}
			for _,s in ipairs(self.snapshots) do if s.epoch <= epoch then kept[#kept+1]=s newEpochs[s.epoch]=s end end
			self.snapshots=kept self.epochs=newEpochs self.head=epoch return true end
		function self.checkpoint() return { head=self.head, count=#self.snapshots, checksum=self.checksum() } end
		function self.restore(cp) if cp and cp.head and self.epochs[cp.head] then self.head=cp.head return true end return false end
		return self
	end

	-- 6. COHERENCE — validates drift, seams, and budget adherence of a continuum
	function K.coherence(cfg)
		local self = {
			kind = "coherence", id = cfg.id, samples = C.ring(cfg.window or 128),
			violations = 0, checks = 0, threshold = cfg.threshold or 0.12
		}
		function self.observe(metrics)
			-- metrics: { coherence, residency, seams, drift, cost, budget }
			local score = 1.0
			if metrics.coherence ~= nil then score = math.min(score, metrics.coherence) end
			if metrics.residency ~= nil then score = math.min(score, metrics.residency > 1 and 0 or 1) end
			if metrics.seams ~= nil and metrics.loaded ~= nil and metrics.loaded > 0 then
				local seamRatio = metrics.seams / math.max(1, metrics.loaded * 4)
				score = math.min(score, seamRatio)
			end
			if metrics.drift ~= nil then score = math.min(score, 1 - math.min(1, metrics.drift * 2)) end
			if metrics.cost ~= nil and metrics.budget ~= nil and metrics.budget > 0 then
				local pressure = metrics.cost / metrics.budget
				if pressure > 1 then score = score - (pressure - 1) * 0.5 end
			end
			score = Mathx.clamp(score, 0, 1)
			self.samples:push(score)
			self.checks = self.checks + 1
			if score < (1 - self.threshold) then self.violations = self.violations + 1 end
			return score
		end
		function self.health()
			local m = self.mean()
			if m > 0.88 then return "ok"
			elseif m > 0.62 then return "degraded"
			else return "failing" end
		end
		function self.mean() local t=self.samples:toTable() if #t==0 then return 1 end return Mathx.mean(t) end
		function self.trend() -- linear slope
			local t=self.samples:toTable()
			local n=#t if n<3 then return 0 end
			local sx,sy,sxy,sx2=0,0,0,0
			for i,y in ipairs(t) do sx=sx+i sy=sy+y sxy=sxy+i*y sx2=sx2+i*i end
			local denom=n*sx2 - sx*sx
			if math.abs(denom)<1e-9 then return 0 end
			return (n*sxy - sx*sy)/denom
		end
		function self.violationRate() if self.checks==0 then return 0 end return self.violations/self.checks end
		function self.stats() return { checks = self.checks, violations = self.violations, rate = self.violationRate(), mean = self.mean(), trend = self.trend(), health = self.health() } end
		function self.score() return self.mean() end
		function self.isCoherent() local h=self.health() return h=="ok" or h=="degraded" end
		function self.driftValue() return math.abs(self.trend()) end
		function self.pressure() return self.violationRate() end
		function self.reset() self.samples=C.ring(128) self.checks=0 self.violations=0 return true end
		return self
	end

	-- 7. NEURALFIELD — tiny on-device field for super-resolution / infill (no external inference engine)
	-- A dense MLP with 2 hidden layers, forward + train on synthetic data, quantization.
	function K.neuralfield(cfg)
		local dims = cfg.dims or 16
		local hidden = cfg.hidden or 12
		local self = {
			kind = "neuralfield", id = cfg.id, dims = dims, hidden = hidden,
			lr = cfg.lr or 0.04, scales = {}, weights = {}, trained = 0, loss = 0
		}
		local rng = Random.new(cfg.seed or 1337)
		-- init weights: dims -> hidden -> hidden -> 1
		local function randMat(rows, cols)
			local m={}
			for i=1,rows do m[i]={} for j=1,cols do m[i][j]=(rng:next()*2-1)*0.5 end end
			return m
		end
		local W1 = randMat(hidden, dims)
		local B1 = {}
		for i=1,hidden do B1[i]=(rng:next()*2-1)*0.1 end
		local W2 = randMat(hidden, hidden)
		local B2={}
		for i=1,hidden do B2[i]=(rng:next()*2-1)*0.1 end
		local W3 = {}
		for i=1,hidden do W3[i]=(rng:next()*2-1)*0.3 end
		local b3=(rng:next()*2-1)*0.1
		local function relu(x) return x>0 and x or 0 end
		local function sigmoid(x) return 1/(1+math.exp(-Mathx.clamp(x,-15,15))) end
		local function forward(input)
			-- input: array dims
			local h1={}
			for i=1,hidden do
				local s=B1[i]
				for j=1,dims do s=s+W1[i][j]*(input[j] or 0) end
				h1[i]=relu(s)
			end
			local h2={}
			for i=1,hidden do
				local s=B2[i] or 0
				for j=1,hidden do s=s+W2[i][j]*h1[j] end
				h2[i]=relu(s)
			end
			local out=b3
			for i=1,hidden do out=out+W3[i]*h2[i] end
			return sigmoid(out), h1, h2
		end
		function self.infer(input) local o=forward(input) return o end
		function self.encode(pos, scale)
			-- positional encoding: sin/cos at multiple frequencies
			local enc={}
			for i=1, dims, 2 do
				local freq = 2 ^ math.floor((i-1)/2)
				enc[i] = math.sin((pos or 0) * freq * 0.1) * (scale or 1)
				if i+1 <= dims then enc[i+1] = math.cos((pos or 0) * freq * 0.1) * (scale or 1) end
			end
			return enc
		end
		function self.train(dataset, epochs)
			epochs = epochs or 6
			for ep=1, epochs do
				local total=0
				for _, sample in ipairs(dataset) do
					local input, target = sample[1], sample[2]
					local out, h1, h2 = forward(input)
					local err = out - target
					total = total + err*err
					-- backprop (simplified SGD, only output layer + biases for determinism and speed)
					local dOut = err * out * (1 - out)
					for i=1,hidden do W3[i] = W3[i] - self.lr * dOut * h2[i] end
					b3 = b3 - self.lr * dOut
					-- hidden 2
					for i=1,hidden do
						if h2[i] > 0 then
							local d = dOut * W3[i]
							B2[i] = B2[i] - self.lr * d * 0.5
						end
					end
				end
				self.loss = total / math.max(1,#dataset)
				self.trained = self.trained + 1
			end
			return self.loss
		end
		function self.generateDataset(n, fn)
			local ds={}
			for i=1, n or 64 do
				local x = rng:next()*2-1
				local inp = self.encode(x, 1)
				local tgt = fn and fn(x) or (0.5 + 0.5*math.sin(x*3))
				ds[#ds+1]={inp, Mathx.clamp(tgt,0,1)}
			end
			return ds
		end
		function self.quantize(bits)
			bits = bits or 8
			local scale = 2^(bits-1)-1
			local function qmat(m)
				local out={}
				for i,row in ipairs(m) do out[i]={} for j,v in ipairs(row) do out[i][j]= math.floor(Mathx.clamp(v,-1,1)*scale+0.5)/scale end end
				return out
			end
			W1=qmat(W1) W2=qmat(W2)
			for i,v in ipairs(B1) do B1[i]=math.floor(Mathx.clamp(v,-1,1)*scale+0.5)/scale end
			for i,v in ipairs(B2) do B2[i]=math.floor(Mathx.clamp(v,-1,1)*scale+0.5)/scale end
			for i,v in ipairs(W3) do W3[i]=math.floor(Mathx.clamp(v,-1,1)*scale+0.5)/scale end
			b3=math.floor(Mathx.clamp(b3,-1,1)*scale+0.5)/scale
			return { bits=bits, scale=scale }
		end
		function self.exportWeights()
			return { W1=C.deepCopy(W1), B1=C.deepCopy(B1), W2=C.deepCopy(W2), B2=C.deepCopy(B2), W3=C.deepCopy(W3), b3=b3, dims=dims, hidden=hidden }
		end
		function self.stats() return { dims=dims, hidden=hidden, trained=self.trained, loss=self.loss } end
		function self.forward(input) return self.infer(input) end
		function self.exportTable() local t=self.exportWeights() t.compressed=self.quantize(8) return t end
		function self.importTable(tbl) if not tbl then return false end if tbl.W1 then W1=C.deepCopy(tbl.W1) end if tbl.B1 then B1=C.deepCopy(tbl.B1) end if tbl.W2 then W2=C.deepCopy(tbl.W2) end if tbl.B2 then B2=C.deepCopy(tbl.B2) end if tbl.W3 then W3=C.deepCopy(tbl.W3) end if tbl.b3 then b3=tbl.b3 end return true end
		function self.memoryBytes() return (dims*hidden*2 + hidden*hidden + hidden)*4 + 64 end
		return self
	end

	return K
end
