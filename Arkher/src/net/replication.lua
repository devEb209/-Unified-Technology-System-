-- ARKHER NET :: Replication
-- Authoritative networking: a server world that owns the truth, delta snapshots limited
-- by interest and bandwidth, a synchronized clock with a jitter buffer, client-side
-- prediction with reconciliation, and lag compensation for hit validation.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local v3 = Vec.vec3

	local Net = {}
	Net.__index = Net

	function Net.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Net)
		self.replicator = Kits.create("replicator", { id = "net.replicator",
			mtu = opts.mtu or 1200, interestRadius = opts.interestRadius or 200,
			fullEvery = opts.fullEvery or 60 })
		self.clock = Kits.create("netclock", { id = "net.clock",
			tickRate = opts.tickRate or 30, bufferDelay = opts.bufferDelay or 0.1 })
		self.guard = Kits.create("guard", { id = "net.guard", algorithm = "token",
			capacity = opts.rateCapacity or 120, refillPerSec = opts.rateRefill or 60 })
		self.ledger = Kits.create("ledger", { id = "net.ledger", capacity = 512 })
		self.clients = {}
		self.clientOrder = {}
		self.history = {}
		self.historyLength = opts.historyLength or 60
		self.tick = 0
		self.time = 0
		self.rejected = 0
		self.validated = 0
		self.onSnapshot = Signal.new()
		self.onReject = Signal.new()
		return self
	end

	-- ------------------------------------------------------------------ server side
	function Net:spawn(id, fields, position)
		return self.replicator.spawn(id, fields, position)
	end

	function Net:despawn(id) return self.replicator.despawn(id) end

	function Net:setField(id, field, value) return self.replicator.set(id, field, value) end

	function Net:move(id, position) return self.replicator.move(id, position) end

	function Net:connect(clientId, opts)
		opts = opts or {}
		if self.clients[clientId] then return nil, "already connected" end
		local client = {
			id = clientId,
			position = opts.position or v3(),
			latency = opts.latency or 0.06,
			prediction = Kits.create("prediction", { id = clientId .. ".prediction",
				errorThreshold = opts.errorThreshold or 0.08 }),
			acked = 0,
			received = 0,
			bytes = 0,
		}
		self.replicator.addClient(clientId, client.position)
		self.clients[clientId] = client
		self.clientOrder[#self.clientOrder + 1] = clientId
		return client
	end

	function Net:disconnect(clientId)
		if not self.clients[clientId] then return false end
		self.clients[clientId] = nil
		for i, id in ipairs(self.clientOrder) do
			if id == clientId then table.remove(self.clientOrder, i) break end
		end
		return true
	end

	function Net:moveClient(clientId, position)
		local client = self.clients[clientId]
		if not client then return false end
		client.position = position
		return self.replicator.moveClient(clientId, position)
	end

	-- The server records a snapshot of positions every tick: this is what lag
	-- compensation rewinds into when a client claims it hit something.
	function Net:recordHistory()
		local frame = { tick = self.tick, time = self.time, positions = {} }
		for _, id in ipairs(self.replicator.order) do
			local e = self.replicator.entities[id]
			frame.positions[id] = e.position
		end
		self.history[#self.history + 1] = frame
		while #self.history > self.historyLength do table.remove(self.history, 1) end
		return #self.history
	end

	function Net:rewind(seconds)
		local target = self.time - seconds
		local best = self.history[1]
		for _, frame in ipairs(self.history) do
			if frame.time <= target then best = frame end
		end
		return best
	end

	-- Validate a hit claim against where the target *was* when the shooter fired.
	function Net:validateHit(clientId, targetId, claimedPosition, tolerance)
		local client = self.clients[clientId]
		if not client then return false, "unknown client" end
		local frame = self:rewind(client.latency)
		if not frame then return false, "no history" end
		local was = frame.positions[targetId]
		if not was then return false, "unknown target" end
		local distance = was:distance(claimedPosition)
		local ok = distance <= (tolerance or 1.5)
		if ok then
			self.validated = self.validated + 1
		else
			self.rejected = self.rejected + 1
			self.onReject:fire({ client = clientId, target = targetId, distance = distance })
		end
		self.ledger.write("hit", { client = clientId, target = targetId,
			distance = distance, accepted = ok })
		return ok, distance
	end

	function Net:acceptInput(clientId, input, dt)
		if not self.guard.allow(1) then
			self.rejected = self.rejected + 1
			return nil, "rate limited"
		end
		local client = self.clients[clientId]
		if not client then return nil, "unknown client" end
		local entity = self.replicator.entities[clientId]
		if not entity then return nil, "no entity" end
		local state = { position = entity.position,
			velocity = input.velocity or v3() }
		local nextState = client.prediction.simulate(state, input, dt)
		self.replicator.move(clientId, nextState.position)
		client.acked = input.sequence or client.acked
		return nextState
	end

	-- ------------------------------------------------------------------ tick
	function Net:step(dt)
		self.time = self.time + dt
		self.tick = self.tick + 1
		self.guard.tick(dt)
		self.clock.advance(dt)
		self:recordHistory()
		local packets = self.replicator.flush()
		local sent = 0
		for clientId, packet in pairs(packets) do
			local client = self.clients[clientId]
			if client then
				local parts = self.replicator.split(packet)
				for _, part in ipairs(parts) do
					client.bytes = client.bytes + part.bytes
					client.received = client.received + 1
					sent = sent + 1
					self.onSnapshot:fire({ client = clientId, tick = part.tick,
						bytes = part.bytes, full = part.full })
				end
			end
		end
		return { tick = self.tick, packets = sent, bandwidth = self.replicator.bandwidth() }
	end

	function Net:run(seconds, dt)
		local step = dt or 1 / 30
		local n = math.max(1, math.floor(seconds / step))
		local last
		for _ = 1, n do last = self:step(step) end
		return last
	end

	-- ------------------------------------------------------------------ client side
	function Net:clientPredict(clientId, input, dt)
		local client = self.clients[clientId]
		if not client then return nil end
		return client.prediction.pushInput(input, dt)
	end

	function Net:clientReconcile(clientId)
		local client = self.clients[clientId]
		if not client then return nil end
		local entity = self.replicator.entities[clientId]
		if not entity then return nil end
		local serverState = { position = entity.position, velocity = v3() }
		return client.prediction.reconcile(serverState, client.acked)
	end

	function Net:clientState(clientId)
		local client = self.clients[clientId]
		if not client then return nil end
		return client.prediction.state
	end

	function Net:syncClock(clientId, sentAt, serverTime, receivedAt)
		return self.clock.sample(sentAt, serverTime, receivedAt)
	end

	function Net:bandwidthPerClient()
		local out = {}
		for _, id in ipairs(self.clientOrder) do
			local client = self.clients[id]
			out[id] = self.time > 0 and client.bytes / self.time or 0
		end
		return out
	end

	function Net:applyQuality(q)
		q = Mathx.clamp(q, 0, 1)
		local rep = self.replicator.applyQuality(q)
		for _, id in ipairs(self.clientOrder) do
			self.clients[id].prediction.applyQuality(q)
		end
		self.clock.tickRate = math.max(10, math.floor(30 * Mathx.lerp(0.5, 1, q)))
		return { interestRadius = rep.interestRadius, tickRate = self.clock.tickRate }
	end

	function Net:report()
		return { entities = #self.replicator.order, clients = #self.clientOrder,
			tick = self.tick, bandwidth = self.replicator.bandwidth(),
			bytesSent = self.replicator.stats().bytesSent,
			validated = self.validated, rejected = self.rejected,
			history = #self.history, rtt = self.clock.stats().rtt,
			bufferDelay = self.clock.stats().bufferDelay }
	end

	return Net
end
