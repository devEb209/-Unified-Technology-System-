-- ARKHER KERNEL :: Noise Field Library
-- Value, Perlin, Simplex-style, Worley/cellular, fBm, ridged, billow, turbulence,
-- domain warping and erosion-friendly derivatives. Feeds terrain, materials, VFX, AI.
--@arkher-module
return function(A)
	local Mathx = A:import("arkher/kernel/mathx")
	local Rand = A:import("arkher/kernel/random")
	local Bits = A:import("arkher/kernel/bits")
	local Noise = {}

	local floor = math.floor
	local fade = function(t) return t * t * t * (t * (t * 6 - 15) + 10) end
	local lerp = Mathx.lerp

	local function grad2(hash, x, y)
		local h = hash % 8
		local u = h < 4 and x or y
		local v = h < 4 and y or x
		local a = (h % 2 == 0) and u or -u
		local b = ((h // 2) % 2 == 0) and 2 * v or -2 * v
		return a + b
	end

	function Noise.value2D(x, y, seed)
		local xi, yi = floor(x), floor(y)
		local xf, yf = x - xi, y - yi
		local u, v = fade(xf), fade(yf)
		local a = Rand.hash2D(xi, yi, seed)
		local b = Rand.hash2D(xi + 1, yi, seed)
		local c = Rand.hash2D(xi, yi + 1, seed)
		local d = Rand.hash2D(xi + 1, yi + 1, seed)
		return lerp(lerp(a, b, u), lerp(c, d, u), v) * 2 - 1
	end

	function Noise.perlin2D(x, y, seed)
		local xi, yi = floor(x), floor(y)
		local xf, yf = x - xi, y - yi
		local u, v = fade(xf), fade(yf)
		local function g(ix, iy, dx, dy)
			local h = floor(Rand.hash2D(ix, iy, seed) * 255)
			return grad2(h, dx, dy)
		end
		local n00 = g(xi, yi, xf, yf)
		local n10 = g(xi + 1, yi, xf - 1, yf)
		local n01 = g(xi, yi + 1, xf, yf - 1)
		local n11 = g(xi + 1, yi + 1, xf - 1, yf - 1)
		return lerp(lerp(n00, n10, u), lerp(n01, n11, u), v) * 0.7
	end

	function Noise.perlin3D(x, y, z, seed)
		local xi, yi, zi = floor(x), floor(y), floor(z)
		local xf, yf, zf = x - xi, y - yi, z - zi
		local u, v, w = fade(xf), fade(yf), fade(zf)
		local function g(ix, iy, iz, dx, dy, dz)
			local h = Rand.hash3D(ix, iy, iz, seed)
			local ax = (h * 2 - 1)
			local ay = (Rand.hash3D(ix + 71, iy, iz, seed) * 2 - 1)
			local az = (Rand.hash3D(ix, iy + 71, iz, seed) * 2 - 1)
			return ax * dx + ay * dy + az * dz
		end
		local c000 = g(xi, yi, zi, xf, yf, zf)
		local c100 = g(xi + 1, yi, zi, xf - 1, yf, zf)
		local c010 = g(xi, yi + 1, zi, xf, yf - 1, zf)
		local c110 = g(xi + 1, yi + 1, zi, xf - 1, yf - 1, zf)
		local c001 = g(xi, yi, zi + 1, xf, yf, zf - 1)
		local c101 = g(xi + 1, yi, zi + 1, xf - 1, yf, zf - 1)
		local c011 = g(xi, yi + 1, zi + 1, xf, yf - 1, zf - 1)
		local c111 = g(xi + 1, yi + 1, zi + 1, xf - 1, yf - 1, zf - 1)
		local x00 = lerp(c000, c100, u)
		local x10 = lerp(c010, c110, u)
		local x01 = lerp(c001, c101, u)
		local x11 = lerp(c011, c111, u)
		return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w)
	end

	-- gradient-simplex flavoured noise (skewed lattice, cheaper than 4-corner bilinear)
	function Noise.simplex2D(x, y, seed)
		local F2 = 0.5 * (math.sqrt(3) - 1)
		local G2 = (3 - math.sqrt(3)) / 6
		local s = (x + y) * F2
		local i, j = floor(x + s), floor(y + s)
		local t = (i + j) * G2
		local x0, y0 = x - (i - t), y - (j - t)
		local i1, j1
		if x0 > y0 then i1, j1 = 1, 0 else i1, j1 = 0, 1 end
		local x1, y1 = x0 - i1 + G2, y0 - j1 + G2
		local x2, y2 = x0 - 1 + 2 * G2, y0 - 1 + 2 * G2
		local function corner(cx, cy, ci, cj)
			local tt = 0.5 - cx * cx - cy * cy
			if tt < 0 then return 0 end
			tt = tt * tt
			local h = floor(Rand.hash2D(ci, cj, seed) * 255)
			return tt * tt * grad2(h, cx, cy)
		end
		local n = corner(x0, y0, i, j) + corner(x1, y1, i + i1, j + j1) + corner(x2, y2, i + 1, j + 1)
		return 40 * n * 0.5
	end

	function Noise.worley2D(x, y, seed, distanceMode)
		local xi, yi = floor(x), floor(y)
		local best, second = math.huge, math.huge
		local bestId = 0
		for dy = -1, 1 do
			for dx = -1, 1 do
				local cx, cy = xi + dx, yi + dy
				local fx = cx + Rand.hash2D(cx, cy, seed)
				local fy = cy + Rand.hash2D(cx, cy, (seed or 0) + 977)
				local ddx, ddy = fx - x, fy - y
				local d
				if distanceMode == "manhattan" then d = math.abs(ddx) + math.abs(ddy)
				elseif distanceMode == "chebyshev" then d = math.max(math.abs(ddx), math.abs(ddy))
				else d = math.sqrt(ddx * ddx + ddy * ddy) end
				if d < best then second = best best = d bestId = Bits.bxor(Bits.mul32(cx, 73856093), Bits.mul32(cy, 19349663))
				elseif d < second then second = d end
			end
		end
		return best, second, bestId
	end

	function Noise.fbm(fn, x, y, opts)
		opts = opts or {}
		local octaves = opts.octaves or 5
		local lacunarity = opts.lacunarity or 2.0
		local gain = opts.gain or 0.5
		local freq = opts.frequency or 1.0
		local amp = opts.amplitude or 1.0
		local seed = opts.seed or 0
		local sum, norm = 0, 0
		for o = 1, octaves do
			sum = sum + fn(x * freq, y * freq, seed + o * 131) * amp
			norm = norm + amp
			freq = freq * lacunarity
			amp = amp * gain
		end
		if norm == 0 then return 0 end
		return sum / norm
	end

	function Noise.ridged(fn, x, y, opts)
		opts = opts or {}
		local octaves = opts.octaves or 5
		local lacunarity = opts.lacunarity or 2.0
		local gain = opts.gain or 0.5
		local freq = opts.frequency or 1.0
		local amp = 1.0
		local sum, norm = 0, 0
		local offset = opts.offset or 1.0
		for o = 1, octaves do
			local n = offset - math.abs(fn(x * freq, y * freq, (opts.seed or 0) + o * 131))
			sum = sum + n * n * amp
			norm = norm + amp
			freq = freq * lacunarity
			amp = amp * gain
		end
		return sum / math.max(norm, 1e-9)
	end

	function Noise.billow(fn, x, y, opts)
		opts = opts or {}
		local v = Noise.fbm(function(px, py, s) return math.abs(fn(px, py, s)) * 2 - 1 end, x, y, opts)
		return v
	end

	function Noise.turbulence(fn, x, y, opts)
		opts = opts or {}
		return math.abs(Noise.fbm(fn, x, y, opts))
	end

	function Noise.domainWarp(fn, x, y, opts)
		opts = opts or {}
		local strength = opts.strength or 4.0
		local seed = opts.seed or 0
		local qx = fn(x + 0.0, y + 0.0, seed + 1)
		local qy = fn(x + 5.2, y + 1.3, seed + 2)
		return fn(x + strength * qx, y + strength * qy, seed)
	end

	function Noise.terrace(value, steps)
		local s = steps or 8
		return math.floor(value * s) / s
	end

	function Noise.derivative2D(fn, x, y, seed, eps)
		local e = eps or 0.01
		local dx = (fn(x + e, y, seed) - fn(x - e, y, seed)) / (2 * e)
		local dy = (fn(x, y + e, seed) - fn(x, y - e, seed)) / (2 * e)
		return dx, dy
	end

	function Noise.slope(fn, x, y, seed, eps)
		local dx, dy = Noise.derivative2D(fn, x, y, seed, eps)
		return math.sqrt(dx * dx + dy * dy)
	end

	function Noise.curl2D(fn, x, y, seed, eps)
		local dx, dy = Noise.derivative2D(fn, x, y, seed, eps)
		return dy, -dx
	end

	function Noise.field(kind)
		local map = {
			value = Noise.value2D, perlin = Noise.perlin2D, simplex = Noise.simplex2D,
			worley = function(x, y, s) local b = Noise.worley2D(x, y, s) return b * 2 - 1 end,
			cellular = function(x, y, s) local b, sec = Noise.worley2D(x, y, s) return sec - b end,
		}
		return map[kind] or Noise.perlin2D
	end

	return Noise

end
