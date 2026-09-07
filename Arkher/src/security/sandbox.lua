-- ARKHER SECURITY :: Sandbox + Capability + Permission
-- Every ARKHER extension, plugin, AI agent action and user script runs through this
-- capability gate. Nothing touches the platform adapter without an explicit grant.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local Signal = A:import("arkher/kernel/signal")
	local Sandbox = {}
	Sandbox.__index = Sandbox

	Sandbox.CAPABILITIES = {
		"scene.read", "scene.write", "scene.destroy",
		"asset.read", "asset.write", "asset.import",
		"script.read", "script.write", "script.execute",
		"terrain.read", "terrain.write",
		"network.send", "network.receive",
		"datastore.read", "datastore.write",
		"player.read", "player.write",
		"ui.create", "ui.modify",
		"physics.write", "render.write", "audio.write",
		"ai.invoke", "ai.train", "ai.tools",
		"filesystem.read", "filesystem.write",
		"process.spawn", "profiler.read", "config.write",
		"collab.read", "collab.write", "build.execute",
	}

	function Sandbox.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Sandbox)
		self.principals = {}
		self.onViolation = Signal.new("sandbox.violation")
		self.onGrant = Signal.new("sandbox.grant")
		self.violations = {}
		self.auditLog = {}
		self.maxAudit = opts.maxAudit or 4096
		self.strict = opts.strict ~= false
		self.quotas = {}
		return self
	end

	function Sandbox:createPrincipal(id, opts)
		opts = opts or {}
		self.principals[id] = {
			id = id, kind = opts.kind or "plugin", granted = {}, denied = {},
			trust = opts.trust or 0.5, callCount = 0, blockedCount = 0,
			quota = opts.quota or { calls = 100000, perFrame = 5000 },
			frameCalls = 0,
		}
		return self.principals[id]
	end

	function Sandbox:grant(principalId, capability)
		local p = self.principals[principalId]
		if not p then return false, "unknown principal" end
		local valid = false
		if string.find(capability, "*", 1, true) then
			-- wildcard grant: valid when at least one known capability matches the prefix
			local prefix = string.sub(capability, 1, string.find(capability, "*", 1, true) - 1)
			for _, c in ipairs(Sandbox.CAPABILITIES) do
				if string.sub(c, 1, #prefix) == prefix then valid = true break end
			end
		else
			for _, c in ipairs(Sandbox.CAPABILITIES) do if c == capability then valid = true break end end
		end
		if not valid and self.strict then return false, "unknown capability: " .. tostring(capability) end
		p.granted[capability] = true
		self.onGrant:fire(principalId, capability)
		return true
	end

	function Sandbox:grantAll(principalId, list)
		local n = 0
		for _, c in ipairs(list) do if self:grant(principalId, c) then n = n + 1 end end
		return n
	end

	function Sandbox:revoke(principalId, capability)
		local p = self.principals[principalId]
		if not p then return false end
		p.granted[capability] = nil
		p.denied[capability] = true
		return true
	end

	function Sandbox:can(principalId, capability)
		local p = self.principals[principalId]
		if not p then return false end
		if p.denied[capability] then return false end
		if p.granted[capability] then return true end
		-- wildcard grants: "scene.*"
		for cap in pairs(p.granted) do
			local star = string.find(cap, "*", 1, true)
			if star then
				local prefix = string.sub(cap, 1, star - 1)
				if string.sub(capability, 1, #prefix) == prefix then return true end
			end
		end
		return false
	end

	function Sandbox:audit(principalId, capability, allowed, detail)
		self.auditLog[#self.auditLog + 1] = { principal = principalId, capability = capability, allowed = allowed, detail = detail }
		if #self.auditLog > self.maxAudit then table.remove(self.auditLog, 1) end
	end

	-- the gate: wrap any privileged operation
	function Sandbox:invoke(principalId, capability, fn, ...)
		local p = self.principals[principalId]
		if not p then
			return nil, Errors.new(Errors.Codes.PERMISSION_DENIED, "unknown principal: " .. tostring(principalId))
		end
		p.callCount = p.callCount + 1
		p.frameCalls = p.frameCalls + 1
		if p.frameCalls > p.quota.perFrame then
			p.blockedCount = p.blockedCount + 1
			return nil, Errors.new(Errors.Codes.RESOURCE_EXHAUSTED, "per-frame quota exceeded for " .. principalId)
		end
		if p.callCount > p.quota.calls then
			p.blockedCount = p.blockedCount + 1
			return nil, Errors.new(Errors.Codes.RESOURCE_EXHAUSTED, "call quota exceeded for " .. principalId)
		end
		if not self:can(principalId, capability) then
			p.blockedCount = p.blockedCount + 1
			self.violations[#self.violations + 1] = { principal = principalId, capability = capability }
			self.onViolation:fire(principalId, capability)
			self:audit(principalId, capability, false)
			return nil, Errors.new(Errors.Codes.SANDBOX_VIOLATION, "capability denied: " .. capability .. " for " .. principalId)
		end
		self:audit(principalId, capability, true)
		local ok, res = pcall(fn, ...)
		if not ok then return nil, Errors.wrap(res, Errors.Codes.INTERNAL, "sandboxed call failed") end
		return res
	end

	function Sandbox:resetFrameQuotas()
		for _, p in pairs(self.principals) do p.frameCalls = 0 end
	end

	function Sandbox:trustScore(principalId)
		local p = self.principals[principalId]
		if not p then return 0 end
		local denial = p.callCount > 0 and (p.blockedCount / p.callCount) or 0
		return math.max(0, math.min(1, p.trust * (1 - denial)))
	end

	function Sandbox:report()
		local out = { principals = {}, violations = #self.violations, auditEntries = #self.auditLog }
		for id, p in pairs(self.principals) do
			local caps = {}
			for c in pairs(p.granted) do caps[#caps + 1] = c end
			table.sort(caps)
			out.principals[#out.principals + 1] = { id = id, kind = p.kind, capabilities = caps,
				calls = p.callCount, blocked = p.blockedCount, trust = self:trustScore(id) }
		end
		table.sort(out.principals, function(a, b) return a.id < b.id end)
		return out
	end

	-- Preset roles used by the editor, runtime and AI agents.
	Sandbox.ROLES = {
		viewer = { "scene.read", "asset.read", "script.read", "profiler.read" },
		builder = { "scene.read", "scene.write", "asset.read", "asset.write", "terrain.read", "terrain.write", "ui.create", "ui.modify" },
		scripter = { "script.read", "script.write", "script.execute", "scene.read", "scene.write" },
		aiAgent = { "scene.read", "scene.write", "asset.read", "asset.write", "terrain.write", "script.write", "ai.invoke", "ai.tools", "profiler.read" },
		optimizer = { "profiler.read", "render.write", "physics.write", "config.write", "scene.write" },
		admin = { "scene.*", "asset.*", "script.*", "terrain.*", "network.*", "ai.*", "config.*", "build.*", "collab.*" },
	}
	function Sandbox:applyRole(principalId, role)
		local caps = Sandbox.ROLES[role]
		if not caps then return 0 end
		return self:grantAll(principalId, caps)
	end

	return Sandbox

end
