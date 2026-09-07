-- ARKHER KERNEL :: Extended Math
-- Numeric utilities used across rendering, physics, terrain, AI and D-O15.
--@arkher-module
return function(A)
	local Bits = A:import("arkher/kernel/bits")
	local Mathx = {}

	local floor, sqrt, abs, exp, log = math.floor, math.sqrt, math.abs, math.exp, math.log
	local pi = math.pi

	Mathx.PI = pi
	Mathx.TAU = pi * 2
	Mathx.EPS = 1e-9
	Mathx.DEG2RAD = pi / 180
	Mathx.RAD2DEG = 180 / pi
	Mathx.GOLDEN = (1 + sqrt(5)) / 2

	function Mathx.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
	function Mathx.saturate(v) return Mathx.clamp(v, 0, 1) end
	function Mathx.lerp(a, b, t) return a + (b - a) * t end
	function Mathx.unlerp(a, b, v) if abs(b - a) < Mathx.EPS then return 0 end return (v - a) / (b - a) end
	function Mathx.remap(v, a1, b1, a2, b2) return Mathx.lerp(a2, b2, Mathx.unlerp(a1, b1, v)) end
	function Mathx.sign(v) if v > 0 then return 1 elseif v < 0 then return -1 end return 0 end
	function Mathx.approx(a, b, eps) return abs(a - b) <= (eps or 1e-6) end
	function Mathx.smoothstep(t) t = Mathx.saturate(t) return t * t * (3 - 2 * t) end
	function Mathx.smootherstep(t) t = Mathx.saturate(t) return t * t * t * (t * (t * 6 - 15) + 10) end
	function Mathx.step(edge, x) if x < edge then return 0 end return 1 end
	function Mathx.pingpong(t, len) local m = t % (len * 2) if m > len then return len * 2 - m end return m end
	function Mathx.repeatv(t, len) return t - floor(t / len) * len end
	function Mathx.wrapAngle(a) a = (a + pi) % (2 * pi) if a < 0 then a = a + 2 * pi end return a - pi end
	function Mathx.lerpAngle(a, b, t) return a + Mathx.wrapAngle(b - a) * t end
	function Mathx.moveTowards(cur, target, maxDelta)
		local d = target - cur
		if abs(d) <= maxDelta then return target end
		return cur + Mathx.sign(d) * maxDelta
	end
	function Mathx.damp(cur, target, lambda, dt) return Mathx.lerp(cur, target, 1 - exp(-lambda * dt)) end
	function Mathx.springDamp(cur, vel, target, stiffness, damping, dt)
		local force = (target - cur) * stiffness - vel * damping
		local nv = vel + force * dt
		return cur + nv * dt, nv
	end
	function Mathx.round(v, places)
		local m = 10 ^ (places or 0)
		return floor(v * m + 0.5) / m
	end
	function Mathx.snap(v, grid) if grid <= 0 then return v end return floor(v / grid + 0.5) * grid end
	function Mathx.isPow2(n) return Bits.isPow2(n) end
	function Mathx.nextPow2(n)
		local p = 1
		while p < n do p = p * 2 end
		return p
	end
	function Mathx.log2(n) return log(n) / log(2) end
	function Mathx.gcd(a, b) while b ~= 0 do a, b = b, a % b end return a end
	function Mathx.lcm(a, b) return abs(a * b) / Mathx.gcd(a, b) end
	function Mathx.mean(t)
		if #t == 0 then return 0 end
		local s = 0
		for _, v in ipairs(t) do s = s + v end
		return s / #t
	end
	function Mathx.variance(t)
		if #t < 2 then return 0 end
		local m = Mathx.mean(t)
		local s = 0
		for _, v in ipairs(t) do s = s + (v - m) ^ 2 end
		return s / (#t - 1)
	end
	function Mathx.stddev(t) return sqrt(Mathx.variance(t)) end
	function Mathx.median(t)
		local c = {}
		for i, v in ipairs(t) do c[i] = v end
		table.sort(c)
		local n = #c
		if n == 0 then return 0 end
		if n % 2 == 1 then return c[(n + 1) // 2] end
		return (c[n // 2] + c[n // 2 + 1]) / 2
	end
	function Mathx.percentile(t, p)
		local c = {}
		for i, v in ipairs(t) do c[i] = v end
		table.sort(c)
		if #c == 0 then return 0 end
		local idx = Mathx.clamp(floor(p / 100 * #c + 0.5), 1, #c)
		return c[idx]
	end
	function Mathx.ema(prev, value, alpha) return prev + alpha * (value - prev) end
	function Mathx.softmax(t, temperature)
		local temp = temperature or 1
		local mx = -math.huge
		for _, v in ipairs(t) do if v > mx then mx = v end end
		local sum, out = 0, {}
		for i, v in ipairs(t) do
			out[i] = exp((v - mx) / temp)
			sum = sum + out[i]
		end
		for i in ipairs(out) do out[i] = out[i] / sum end
		return out
	end
	function Mathx.sigmoid(x) return 1 / (1 + exp(-x)) end
	function Mathx.relu(x) if x > 0 then return x end return 0 end
	function Mathx.tanh(x)
		local e2 = exp(2 * x)
		return (e2 - 1) / (e2 + 1)
	end
	function Mathx.solveQuadratic(a, b, c)
		local disc = b * b - 4 * a * c
		if disc < 0 then return nil end
		local s = sqrt(disc)
		return (-b - s) / (2 * a), (-b + s) / (2 * a)
	end
	function Mathx.barycentric(px, py, ax, ay, bx, by, cx, cy)
		local v0x, v0y = cx - ax, cy - ay
		local v1x, v1y = bx - ax, by - ay
		local v2x, v2y = px - ax, py - ay
		local dot00 = v0x * v0x + v0y * v0y
		local dot01 = v0x * v1x + v0y * v1y
		local dot02 = v0x * v2x + v0y * v2y
		local dot11 = v1x * v1x + v1y * v1y
		local dot12 = v1x * v2x + v1y * v2y
		local denom = dot00 * dot11 - dot01 * dot01
		if abs(denom) < Mathx.EPS then return 0, 0, 1 end
		local u = (dot11 * dot02 - dot01 * dot12) / denom
		local v = (dot00 * dot12 - dot01 * dot02) / denom
		return u, v, 1 - u - v
	end
	function Mathx.triangleArea(ax, ay, bx, by, cx, cy)
		return abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) * 0.5
	end
	function Mathx.hermite(p0, m0, p1, m1, t)
		local t2 = t * t
		local t3 = t2 * t
		return (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * m1
	end
	function Mathx.gaussian(x, mu, sigma)
		local d = (x - mu) / sigma
		return exp(-0.5 * d * d) / (sigma * sqrt(2 * pi))
	end
	function Mathx.hash01(n)
		local x = Bits.add32(Bits.mul32(n, 374761393), 668265263)
		x = Bits.mul32(Bits.bxor(x, Bits.rshift(x, 13)), 1274126177)
		return Bits.bxor(x, Bits.rshift(x, 16)) / 4294967296
	end
	-- portable two-argument arctangent (Luau exposes math.atan2, 5.4 folds it into math.atan)
	Mathx.atan2 = math.atan2 or math.atan

	return Mathx

end
