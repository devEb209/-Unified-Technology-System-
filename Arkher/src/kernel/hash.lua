-- ARKHER KERNEL :: Hashing / Digest
-- FNV-1a, xxHash-style mixing, string interning, content addressing, base64, CRC32.
--@arkher-module
return function(A)
	local Bits = A:import("arkher/kernel/bits")
	local H = {}

	local FNV_OFFSET = 2166136261
	local FNV_PRIME = 16777619

	function H.fnv1a(str)
		local hash = FNV_OFFSET
		for i = 1, #str do
			hash = Bits.bxor(hash, string.byte(str, i))
			hash = Bits.mul32(hash, FNV_PRIME)
		end
		return hash
	end

	function H.fnv1a64(str)
		local h1 = H.fnv1a(str)
		local h2 = H.fnv1a(str .. "\1arkher")
		return h1 * 4294967296 + h2
	end

	local CRC_TABLE = nil
	local function buildCrcTable()
		CRC_TABLE = {}
		for i = 0, 255 do
			local c = i
			for _ = 1, 8 do
				if c % 2 == 1 then c = Bits.bxor(3988292384, Bits.rshift(c, 1)) else c = Bits.rshift(c, 1) end
			end
			CRC_TABLE[i] = c
		end
	end
	function H.crc32(str)
		if not CRC_TABLE then buildCrcTable() end
		local crc = 4294967295
		for i = 1, #str do
			crc = Bits.bxor(CRC_TABLE[Bits.band(Bits.bxor(crc, string.byte(str, i)), 255)], Bits.rshift(crc, 8))
		end
		return Bits.bxor(crc, 4294967295)
	end

	function H.mix(a, b)
		local x = Bits.add32(Bits.mul32(a, 2654435761), b)
		x = Bits.bxor(x, Bits.rshift(x, 15))
		x = Bits.mul32(x, 2246822507)
		x = Bits.bxor(x, Bits.rshift(x, 13))
		return x
	end

	function H.hashTable(t, seen)
		seen = seen or {}
		if type(t) ~= "table" then return H.fnv1a(tostring(t)) end
		if seen[t] then return 0 end
		seen[t] = true
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		local acc = FNV_OFFSET
		for _, k in ipairs(keys) do
			acc = H.mix(acc, H.fnv1a(k))
			acc = H.mix(acc, H.hashTable(t[k], seen))
		end
		return acc
	end

	local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	function H.base64encode(data)
		local out = {}
		local n = #data
		local i = 1
		while i <= n do
			local a = string.byte(data, i) or 0
			local b = string.byte(data, i + 1)
			local c = string.byte(data, i + 2)
			local n1 = Bits.rshift(a, 2)
			local n2 = Bits.bor(Bits.lshift(Bits.band(a, 3), 4), Bits.rshift(b or 0, 4))
			local n3 = b and Bits.bor(Bits.lshift(Bits.band(b, 15), 2), Bits.rshift(c or 0, 6)) or nil
			local n4 = c and Bits.band(c, 63) or nil
			out[#out + 1] = string.sub(B64, n1 + 1, n1 + 1)
			out[#out + 1] = string.sub(B64, n2 + 1, n2 + 1)
			out[#out + 1] = n3 and string.sub(B64, n3 + 1, n3 + 1) or "="
			out[#out + 1] = n4 and string.sub(B64, n4 + 1, n4 + 1) or "="
			i = i + 3
		end
		return table.concat(out)
	end
	local B64_INV = nil
	function H.base64decode(str)
		if not B64_INV then
			B64_INV = {}
			for i = 1, #B64 do B64_INV[string.sub(B64, i, i)] = i - 1 end
		end
		str = string.gsub(str, "=", "")
		local out = {}
		local bits, nbits = 0, 0
		for i = 1, #str do
			local v = B64_INV[string.sub(str, i, i)]
			if v then
				bits = Bits.bor(Bits.lshift(bits, 6), v)
				nbits = nbits + 6
				if nbits >= 8 then
					nbits = nbits - 8
					out[#out + 1] = string.char(Bits.band(Bits.rshift(bits, nbits), 255))
				end
			end
		end
		return table.concat(out)
	end

	-- content address: stable id for any serializable payload (asset dedup, caching)
	function H.contentId(value)
		local h = H.hashTable(value)
		return string.format("arkc_%08x", h)
	end

	-- string interning table: memory optimization for tag/name heavy systems
	local interned = {}
	local internCount = 0
	function H.intern(s)
		local v = interned[s]
		if v then return v end
		internCount = internCount + 1
		interned[s] = s
		return s
	end
	function H.internStats() return { count = internCount } end

	return H

end
