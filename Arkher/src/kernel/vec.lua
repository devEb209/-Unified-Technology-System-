-- ARKHER KERNEL :: Linear Algebra
-- Platform-independent Vector2/3/4, Quaternion, Matrix4 and Transform used by every
-- ARKHER framework. Converted to Roblox types only at the adapter boundary.
--@arkher-module
return function(A)
	local Mathx = A:import("arkher/kernel/mathx")
	local V = {}

	------------------------------------------------------------------ Vector3
	local Vec3 = {}
	Vec3.__index = Vec3
	local function v3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vec3) end
	V.vec3 = v3
	Vec3.__add = function(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
	Vec3.__sub = function(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
	Vec3.__unm = function(a) return v3(-a.x, -a.y, -a.z) end
	Vec3.__mul = function(a, b)
		if type(a) == "number" then return v3(a * b.x, a * b.y, a * b.z) end
		if type(b) == "number" then return v3(a.x * b, a.y * b, a.z * b) end
		return v3(a.x * b.x, a.y * b.y, a.z * b.z)
	end
	Vec3.__div = function(a, b)
		if type(b) == "number" then return v3(a.x / b, a.y / b, a.z / b) end
		return v3(a.x / b.x, a.y / b.y, a.z / b.z)
	end
	Vec3.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	Vec3.__tostring = function(a) return string.format("(%.4f, %.4f, %.4f)", a.x, a.y, a.z) end
	function Vec3:dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
	function Vec3:cross(b) return v3(self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x) end
	function Vec3:lengthSq() return self.x ^ 2 + self.y ^ 2 + self.z ^ 2 end
	function Vec3:length() return math.sqrt(self:lengthSq()) end
	function Vec3:unit()
		local l = self:length()
		if l < 1e-12 then return v3(0, 0, 0) end
		return v3(self.x / l, self.y / l, self.z / l)
	end
	function Vec3:distance(b) return (self - b):length() end
	function Vec3:distanceSq(b) return (self - b):lengthSq() end
	function Vec3:lerp(b, t) return v3(Mathx.lerp(self.x, b.x, t), Mathx.lerp(self.y, b.y, t), Mathx.lerp(self.z, b.z, t)) end
	function Vec3:abs() return v3(math.abs(self.x), math.abs(self.y), math.abs(self.z)) end
	function Vec3:min(b) return v3(math.min(self.x, b.x), math.min(self.y, b.y), math.min(self.z, b.z)) end
	function Vec3:max(b) return v3(math.max(self.x, b.x), math.max(self.y, b.y), math.max(self.z, b.z)) end
	function Vec3:floor() return v3(math.floor(self.x), math.floor(self.y), math.floor(self.z)) end
	function Vec3:clampMagnitude(m)
		local l = self:length()
		if l <= m or l < 1e-12 then return v3(self.x, self.y, self.z) end
		return self * (m / l)
	end
	function Vec3:reflect(n) return self - n * (2 * self:dot(n)) end
	function Vec3:project(n) local d = n:dot(n) if d < 1e-12 then return v3() end return n * (self:dot(n) / d) end
	function Vec3:angleTo(b)
		local d = self:unit():dot(b:unit())
		return math.acos(Mathx.clamp(d, -1, 1))
	end
	function Vec3:isFinite() return self.x == self.x and self.y == self.y and self.z == self.z end
	function Vec3:toArray() return { self.x, self.y, self.z } end
	V.Vec3 = Vec3
	V.ZERO3 = v3(0, 0, 0)
	V.ONE3 = v3(1, 1, 1)
	V.UP = v3(0, 1, 0)
	V.RIGHT = v3(1, 0, 0)
	V.FORWARD = v3(0, 0, -1)

	------------------------------------------------------------------ Vector2
	local Vec2 = {}
	Vec2.__index = Vec2
	local function v2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec2) end
	V.vec2 = v2
	Vec2.__add = function(a, b) return v2(a.x + b.x, a.y + b.y) end
	Vec2.__sub = function(a, b) return v2(a.x - b.x, a.y - b.y) end
	Vec2.__mul = function(a, b)
		if type(a) == "number" then return v2(a * b.x, a * b.y) end
		if type(b) == "number" then return v2(a.x * b, a.y * b) end
		return v2(a.x * b.x, a.y * b.y)
	end
	function Vec2:dot(b) return self.x * b.x + self.y * b.y end
	function Vec2:length() return math.sqrt(self.x ^ 2 + self.y ^ 2) end
	function Vec2:unit() local l = self:length() if l < 1e-12 then return v2() end return v2(self.x / l, self.y / l) end
	function Vec2:rotate(a)
		local c, s = math.cos(a), math.sin(a)
		return v2(self.x * c - self.y * s, self.x * s + self.y * c)
	end
	function Vec2:perp() return v2(-self.y, self.x) end
	V.Vec2 = Vec2

	------------------------------------------------------------------ Quaternion
	local Quat = {}
	Quat.__index = Quat
	local function q(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w == nil and 1 or w }, Quat) end
	V.quat = q
	Quat.__mul = function(a, b)
		if type(b) == "table" and b.w == nil then -- rotate vector
			local u = v3(a.x, a.y, a.z)
			local s = a.w
			return u * (2 * u:dot(b)) + b * (s * s - u:dot(u)) + u:cross(b) * (2 * s)
		end
		return q(
			a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
			a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
			a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
			a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
	end
	function Quat:conjugate() return q(-self.x, -self.y, -self.z, self.w) end
	function Quat:length() return math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2 + self.w ^ 2) end
	function Quat:unit()
		local l = self:length()
		if l < 1e-12 then return q(0, 0, 0, 1) end
		return q(self.x / l, self.y / l, self.z / l, self.w / l)
	end
	function Quat:dot(b) return self.x * b.x + self.y * b.y + self.z * b.z + self.w * b.w end
	function Quat:slerp(b, t)
		local d = self:dot(b)
		local bb = b
		if d < 0 then bb = q(-b.x, -b.y, -b.z, -b.w) d = -d end
		if d > 0.9995 then
			return q(Mathx.lerp(self.x, bb.x, t), Mathx.lerp(self.y, bb.y, t), Mathx.lerp(self.z, bb.z, t), Mathx.lerp(self.w, bb.w, t)):unit()
		end
		local theta = math.acos(Mathx.clamp(d, -1, 1))
		local st = math.sin(theta)
		local a1 = math.sin((1 - t) * theta) / st
		local a2 = math.sin(t * theta) / st
		return q(self.x * a1 + bb.x * a2, self.y * a1 + bb.y * a2, self.z * a1 + bb.z * a2, self.w * a1 + bb.w * a2)
	end
	function V.quatFromAxisAngle(axis, angle)
		local a = axis:unit()
		local h = angle * 0.5
		local s = math.sin(h)
		return q(a.x * s, a.y * s, a.z * s, math.cos(h))
	end
	function V.quatFromEuler(pitch, yaw, roll)
		local cp, sp = math.cos(pitch * 0.5), math.sin(pitch * 0.5)
		local cy, sy = math.cos(yaw * 0.5), math.sin(yaw * 0.5)
		local cr, sr = math.cos(roll * 0.5), math.sin(roll * 0.5)
		return q(sp * cy * cr - cp * sy * sr, cp * sy * cr + sp * cy * sr, cp * cy * sr - sp * sy * cr, cp * cy * cr + sp * sy * sr)
	end
	function Quat:toEuler()
		local sinr = 2 * (self.w * self.x + self.y * self.z)
		local cosr = 1 - 2 * (self.x * self.x + self.y * self.y)
		local roll = Mathx.atan2(sinr, cosr)
		local sinp = 2 * (self.w * self.y - self.z * self.x)
		local pitch
		if math.abs(sinp) >= 1 then pitch = (sinp > 0 and 1 or -1) * math.pi / 2 else pitch = math.asin(sinp) end
		local siny = 2 * (self.w * self.z + self.x * self.y)
		local cosy = 1 - 2 * (self.y * self.y + self.z * self.z)
		local yaw = Mathx.atan2(siny, cosy)
		return pitch, yaw, roll
	end
	V.Quat = Quat

	------------------------------------------------------------------ Matrix4 (row-major)
	local Mat4 = {}
	Mat4.__index = Mat4
	local function m4(t) return setmetatable({ m = t }, Mat4) end
	function V.identity4()
		return m4({ 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 })
	end
	Mat4.__mul = function(a, b)
		local r = {}
		for i = 0, 3 do
			for j = 0, 3 do
				local s = 0
				for k = 0, 3 do s = s + a.m[i * 4 + k + 1] * b.m[k * 4 + j + 1] end
				r[i * 4 + j + 1] = s
			end
		end
		return m4(r)
	end
	function Mat4:transformPoint(p)
		local m = self.m
		return v3(
			m[1] * p.x + m[2] * p.y + m[3] * p.z + m[4],
			m[5] * p.x + m[6] * p.y + m[7] * p.z + m[8],
			m[9] * p.x + m[10] * p.y + m[11] * p.z + m[12])
	end
	function Mat4:transformVector(p)
		local m = self.m
		return v3(m[1] * p.x + m[2] * p.y + m[3] * p.z,
			m[5] * p.x + m[6] * p.y + m[7] * p.z,
			m[9] * p.x + m[10] * p.y + m[11] * p.z)
	end
	function Mat4:transpose()
		local m = self.m
		return m4({ m[1],m[5],m[9],m[13], m[2],m[6],m[10],m[14], m[3],m[7],m[11],m[15], m[4],m[8],m[12],m[16] })
	end
	function V.translation(x, y, z) return m4({ 1,0,0,x, 0,1,0,y, 0,0,1,z, 0,0,0,1 }) end
	function V.scaling(x, y, z) return m4({ x,0,0,0, 0,y,0,0, 0,0,z,0, 0,0,0,1 }) end
	function V.fromQuat(qq)
		local x, y, z, w = qq.x, qq.y, qq.z, qq.w
		return m4({
			1 - 2*(y*y + z*z), 2*(x*y - z*w), 2*(x*z + y*w), 0,
			2*(x*y + z*w), 1 - 2*(x*x + z*z), 2*(y*z - x*w), 0,
			2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x*x + y*y), 0,
			0, 0, 0, 1 })
	end
	function V.perspective(fovY, aspect, near, far)
		local f = 1 / math.tan(fovY / 2)
		return m4({ f / aspect,0,0,0, 0,f,0,0, 0,0,(far + near) / (near - far),(2 * far * near) / (near - far), 0,0,-1,0 })
	end
	function V.lookAt(eye, target, up)
		local zaxis = (eye - target):unit()
		local xaxis = up:cross(zaxis):unit()
		local yaxis = zaxis:cross(xaxis)
		return m4({
			xaxis.x, xaxis.y, xaxis.z, -xaxis:dot(eye),
			yaxis.x, yaxis.y, yaxis.z, -yaxis:dot(eye),
			zaxis.x, zaxis.y, zaxis.z, -zaxis:dot(eye),
			0, 0, 0, 1 })
	end
	V.Mat4 = Mat4
	V.mat4 = m4

	------------------------------------------------------------------ Transform
	local Transform = {}
	Transform.__index = Transform
	function V.transform(pos, rot, scale)
		return setmetatable({ position = pos or v3(), rotation = rot or q(), scale = scale or v3(1, 1, 1) }, Transform)
	end
	function Transform:toMatrix()
		return V.translation(self.position.x, self.position.y, self.position.z) * V.fromQuat(self.rotation) * V.scaling(self.scale.x, self.scale.y, self.scale.z)
	end
	function Transform:apply(p) return self.position + (self.rotation * v3(p.x * self.scale.x, p.y * self.scale.y, p.z * self.scale.z)) end
	function Transform:lerp(other, t)
		return V.transform(self.position:lerp(other.position, t), self.rotation:slerp(other.rotation, t), self.scale:lerp(other.scale, t))
	end
	function Transform:inverse()
		local invRot = self.rotation:conjugate()
		local invScale = v3(1 / self.scale.x, 1 / self.scale.y, 1 / self.scale.z)
		local invPos = invRot * (-self.position)
		return V.transform(v3(invPos.x * invScale.x, invPos.y * invScale.y, invPos.z * invScale.z), invRot, invScale)
	end
	V.Transform = Transform

	return V

end
