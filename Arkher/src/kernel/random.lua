-- ARKHER KERNEL :: Deterministic Random
-- xoshiro128** + splitmix32 seeding on the portable Bits layer. Same seed produces
-- the same world on Roblox, on the headless VM and on every device.
--@arkher-module
return function(A)
	local Bits = A:import("arkher/kernel/bits")
	local Random = {}
	Random.__index = Random

	local bxor, band, rshift, rotl, mul32, add32 = Bits.bxor, Bits.band, Bits.rshift, Bits.rotl, Bits.mul32, Bits.add32

	local function splitmix(seed)
		seed = add32(seed, 2654435769)
		local z = seed
		z = mul32(bxor(z, rshift(z, 16)), 2246822507)
		z = mul32(bxor(z, rshift(z, 13)), 3266489909)
		z = bxor(z, rshift(z, 16))
		return z, seed
	end

	function Random.new(seed)
		local self = setmetatable({}, Random)
		self:reseed(seed or 20260907)
		self.count = 0
		return self
	end

	function Random:reseed(seed)
		local s = Bits.normalize(seed)
		local a, b, c, d
		a, s = splitmix(s)
		b, s = splitmix(s)
		c, s = splitmix(s)
		d, s = splitmix(s)
		self.s = { a == 0 and 1 or a, b == 0 and 2 or b, c == 0 and 3 or c, d == 0 and 4 or d }
		self.seed = seed
		self.count = 0
		return self
	end

	function Random:nextUInt()
		local s = self.s
		local result = mul32(rotl(mul32(s[2], 5), 7), 9)
		local t = Bits.lshift(s[2], 9)
		s[3] = bxor(s[3], s[1])
		s[4] = bxor(s[4], s[2])
		s[2] = bxor(s[2], s[3])
		s[1] = bxor(s[1], s[4])
		s[3] = bxor(s[3], t)
		s[4] = rotl(s[4], 11)
		self.count = self.count + 1
		return result
	end

	function Random:next() return self:nextUInt() / 4294967296 end
	function Random:range(lo, hi) return lo + self:next() * (hi - lo) end
	function Random:int(lo, hi) return lo + (self:nextUInt() % (hi - lo + 1)) end
	function Random:bool(p) return self:next() < (p or 0.5) end
	function Random:sign() if self:bool() then return 1 end return -1 end
	function Random:pick(list) if #list == 0 then return nil end return list[self:int(1, #list)] end
	function Random:weighted(items)
		local total = 0
		for _, it in ipairs(items) do total = total + (it.weight or 1) end
		local r = self:next() * total
		local acc = 0
		for _, it in ipairs(items) do
			acc = acc + (it.weight or 1)
			if r <= acc then
				if it.value ~= nil then return it.value end
				return it
			end
		end
		return items[#items]
	end
	function Random:shuffle(list)
		for i = #list, 2, -1 do
			local j = self:int(1, i)
			list[i], list[j] = list[j], list[i]
		end
		return list
	end
	function Random:sample(list, n)
		local copy = {}
		for i, v in ipairs(list) do copy[i] = v end
		self:shuffle(copy)
		local out = {}
		for i = 1, math.min(n, #copy) do out[i] = copy[i] end
		return out
	end
	function Random:gaussian(mean, stddev)
		local u1 = math.max(self:next(), 1e-12)
		local u2 = self:next()
		local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
		return (mean or 0) + z * (stddev or 1)
	end
	function Random:onUnitSphere()
		local z = self:range(-1, 1)
		local a = self:range(0, 2 * math.pi)
		local r = math.sqrt(math.max(0, 1 - z * z))
		return { x = r * math.cos(a), y = r * math.sin(a), z = z }
	end
	function Random:insideUnitCircle()
		local a = self:range(0, 2 * math.pi)
		local r = math.sqrt(self:next())
		return r * math.cos(a), r * math.sin(a)
	end
	function Random:fork(salt) return Random.new(Bits.mul32((self.seed or 0), 2654435761) + (salt or self:nextUInt())) end
	function Random:state() return { self.s[1], self.s[2], self.s[3], self.s[4], self.count } end
	function Random:restore(st) self.s = { st[1], st[2], st[3], st[4] } self.count = st[5] or 0 end

	-- Stateless coordinate hashes: reproducible sampling without any RNG state.
	function Random.hash2D(x, y, seed)
		local n = add32(add32(mul32(math.floor(x), 374761393), mul32(math.floor(y), 668265263)), mul32(seed or 0, 1274126177))
		n = bxor(n, rshift(n, 13))
		n = mul32(n, 1274126177)
		n = bxor(n, rshift(n, 16))
		return n / 4294967296
	end
	function Random.hash3D(x, y, z, seed)
		local n = add32(add32(mul32(math.floor(x), 73856093), mul32(math.floor(y), 19349663)), mul32(math.floor(z), 83492791))
		n = add32(n, mul32(seed or 0, 2654435761))
		n = bxor(n, rshift(n, 15))
		n = mul32(n, 2246822519)
		n = bxor(n, rshift(n, 13))
		return n / 4294967296
	end

	return Random
end
