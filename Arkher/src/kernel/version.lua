-- ARKHER KERNEL :: Versioning, Compatibility and Migration
-- Semantic versions, engine generations (ARKHER V1 -> V2 -> ...), project migration
-- chains and compatibility policies.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local Version = {}

	function Version.parse(str)
		local maj, min, pat, pre = string.match(str, "^(%d+)%.(%d+)%.(%d+)%-?(.*)$")
		if not maj then return nil, Errors.new(Errors.Codes.VALIDATION, "invalid semver: " .. tostring(str)) end
		return { major = tonumber(maj), minor = tonumber(min), patch = tonumber(pat), prerelease = pre ~= "" and pre or nil, raw = str }
	end

	function Version.compare(a, b)
		local va = type(a) == "string" and Version.parse(a) or a
		local vb = type(b) == "string" and Version.parse(b) or b
		if va.major ~= vb.major then return va.major < vb.major and -1 or 1 end
		if va.minor ~= vb.minor then return va.minor < vb.minor and -1 or 1 end
		if va.patch ~= vb.patch then return va.patch < vb.patch and -1 or 1 end
		if va.prerelease and not vb.prerelease then return -1 end
		if vb.prerelease and not va.prerelease then return 1 end
		return 0
	end

	function Version.satisfies(version, range)
		local v = type(version) == "string" and Version.parse(version) or version
		local op, target = string.match(range, "^([%^~>=<]*)%s*(.+)$")
		local t = Version.parse(target)
		if not t then return false end
		if op == "" or op == "=" then return Version.compare(v, t) == 0 end
		if op == ">=" then return Version.compare(v, t) >= 0 end
		if op == ">" then return Version.compare(v, t) > 0 end
		if op == "<=" then return Version.compare(v, t) <= 0 end
		if op == "<" then return Version.compare(v, t) < 0 end
		if op == "^" then return v.major == t.major and Version.compare(v, t) >= 0 end
		if op == "~" then return v.major == t.major and v.minor == t.minor and Version.compare(v, t) >= 0 end
		return false
	end

	------------------------------------------------------------------ Migration chains
	local Migrator = {}
	Migrator.__index = Migrator
	function Version.migrator()
		return setmetatable({ steps = {}, applied = {} }, Migrator)
	end
	function Migrator:add(fromVersion, toVersion, fn, description)
		self.steps[#self.steps + 1] = { from = fromVersion, to = toVersion, fn = fn, description = description }
		return self
	end
	function Migrator:path(from, to)
		local chain = {}
		local current = from
		local guard = 0
		while Version.compare(current, to) < 0 and guard < 256 do
			local found = nil
			for _, s in ipairs(self.steps) do
				if s.from == current then found = s break end
			end
			if not found then return nil, Errors.new(Errors.Codes.VERSION_MISMATCH, "no migration path from " .. current) end
			chain[#chain + 1] = found
			current = found.to
			guard = guard + 1
		end
		return chain
	end
	function Migrator:migrate(data, from, to)
		local chain, err = self:path(from, to)
		if not chain then return nil, err end
		local current = data
		for _, step in ipairs(chain) do
			local ok, res = pcall(step.fn, current)
			if not ok then return nil, Errors.wrap(res, Errors.Codes.INTERNAL, "migration failed " .. step.from .. "->" .. step.to) end
			current = res
			self.applied[#self.applied + 1] = step.from .. "->" .. step.to
		end
		return current, nil, #chain
	end

	------------------------------------------------------------------ Engine generations
	Version.GENERATIONS = {
		{ name = "ARKHER V1", version = "1.0.0", codename = "Genesis", target = "Roblox platform adapter, UES kernel, D-O15 core" },
		{ name = "ARKHER V2", version = "2.0.0", codename = "Continuum", target = "full world simulation + neural reconstruction" },
		{ name = "ARKHER V3", version = "3.0.0", codename = "Ascension", target = "autonomous production pipeline" },
	}
	function Version.generationFor(v)
		local parsed = type(v) == "string" and Version.parse(v) or v
		for i = #Version.GENERATIONS, 1, -1 do
			local g = Version.GENERATIONS[i]
			if Version.compare(parsed, g.version) >= 0 then return g end
		end
		return Version.GENERATIONS[1]
	end

	Version.CURRENT = "1.0.0"
	Version.ENGINE = "ARKHER"
	Version.BUILD_CHANNEL = "release"

	return Version

end
