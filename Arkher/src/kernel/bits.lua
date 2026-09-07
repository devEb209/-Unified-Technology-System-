-- ARKHER KERNEL :: Portable Bit Operations
-- Luau (Roblox) has no bitwise operators, only the bit32 library; standard Lua 5.3+
-- has operators but no bit32. ARKHER ships one implementation that is correct on both,
-- so hashing, noise, bitsets and RNG produce IDENTICAL results on every host.
--@arkher-module
return function(A)
	local Bits = {}

	local b32 = rawget(_G, "bit32")
	local MASK = 4294967295 -- 0xFFFFFFFF
	local TWO32 = 4294967296

	local function normalize(x)
		x = math.floor(x or 0) % TWO32
		if x < 0 then x = x + TWO32 end
		return x
	end
	Bits.normalize = normalize

	if b32 then
		Bits.backend = "bit32"
		function Bits.band(a, b) return b32.band(normalize(a), normalize(b)) end
		function Bits.bor(a, b) return b32.bor(normalize(a), normalize(b)) end
		function Bits.bxor(a, b) return b32.bxor(normalize(a), normalize(b)) end
		function Bits.bnot(a) return b32.bnot(normalize(a)) end
		function Bits.lshift(a, n) return b32.lshift(normalize(a), n) end
		function Bits.rshift(a, n) return b32.rshift(normalize(a), n) end
		function Bits.rotl(a, n) return b32.lrotate(normalize(a), n) end
		function Bits.rotr(a, n) return b32.rrotate(normalize(a), n) end
	else
		Bits.backend = "arithmetic"
		-- Arithmetic implementations: no bitwise syntax anywhere, so this file still
		-- parses under the Luau compiler even though this branch never runs there.
		local function bitop(a, b, op)
			a, b = normalize(a), normalize(b)
			local result, bitval = 0, 1
			for _ = 1, 32 do
				local abit = a % 2
				local bbit = b % 2
				local r
				if op == "and" then r = (abit == 1 and bbit == 1) and 1 or 0
				elseif op == "or" then r = (abit == 1 or bbit == 1) and 1 or 0
				else r = (abit ~= bbit) and 1 or 0 end
				if r == 1 then result = result + bitval end
				a = (a - abit) / 2
				b = (b - bbit) / 2
				bitval = bitval * 2
			end
			return result
		end
		function Bits.band(a, b) return bitop(a, b, "and") end
		function Bits.bor(a, b) return bitop(a, b, "or") end
		function Bits.bxor(a, b) return bitop(a, b, "xor") end
		function Bits.bnot(a) return MASK - normalize(a) end
		function Bits.lshift(a, n)
			if n >= 32 then return 0 end
			return normalize(normalize(a) * (2 ^ n))
		end
		function Bits.rshift(a, n)
			if n >= 32 then return 0 end
			return math.floor(normalize(a) / (2 ^ n))
		end
		function Bits.rotl(a, n)
			n = n % 32
			return Bits.bor(Bits.lshift(a, n), Bits.rshift(a, 32 - n))
		end
		function Bits.rotr(a, n) return Bits.rotl(a, 32 - (n % 32)) end
	end

	-- 32-bit safe multiply (avoids float precision loss above 2^53 on Luau doubles)
	function Bits.mul32(a, b)
		a, b = normalize(a), normalize(b)
		local ah = math.floor(a / 65536)
		local al = a % 65536
		local bh = math.floor(b / 65536)
		local bl = b % 65536
		local high = (ah * bl + al * bh) % 65536
		return normalize(high * 65536 + al * bl)
	end

	function Bits.add32(a, b) return normalize(normalize(a) + normalize(b)) end

	function Bits.popcount(x)
		x = normalize(x)
		local n = 0
		while x > 0 do
			n = n + (x % 2)
			x = math.floor(x / 2)
		end
		return n
	end

	function Bits.testBit(x, i) return Bits.band(x, Bits.lshift(1, i)) ~= 0 end
	function Bits.setBit(x, i) return Bits.bor(x, Bits.lshift(1, i)) end
	function Bits.clearBit(x, i) return Bits.band(x, Bits.bnot(Bits.lshift(1, i))) end

	function Bits.toHex(x) return string.format("%08x", normalize(x)) end
	function Bits.isPow2(n) return n > 0 and n % 1 == 0 and Bits.band(n, n - 1) == 0 end

	return Bits

end
