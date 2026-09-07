--!strict
-- Platform-neutral rigid transforms + uniform hierarchical scale.
local Transform = {}
local function multiply(a, b)
	local c = {}
	for row = 0, 2 do
		for col = 0, 2 do
			local value = 0
			for k = 0, 2 do value += a[row * 3 + k + 1] * b[k * 3 + col + 1] end
			c[row * 3 + col + 1] = value
		end
	end
	return c
end

function Transform.rotation(v)
	local x, y, z = math.rad(v.x), math.rad(v.y), math.rad(v.z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return {cy*cz, -cy*sz, sy, sx*sy*cz+cx*sz, -sx*sy*sz+cx*cz, -sx*cy, -cx*sy*cz+sx*sz, cx*sy*sz+sx*cz, cx*cy}
end

function Transform.rotate(matrix, point)
	return {
		x = matrix[1]*point.x + matrix[2]*point.y + matrix[3]*point.z,
		y = matrix[4]*point.x + matrix[5]*point.y + matrix[6]*point.z,
		z = matrix[7]*point.x + matrix[8]*point.y + matrix[9]*point.z,
	}
end

function Transform.world(state, id, cache)
	cache = cache or {}
	if cache[id] then return cache[id] end
	local node = assert(state.nodes[id], "Entidade inexistente")
	local t = node.transform
	local result = {position = {x=t.position.x,y=t.position.y,z=t.position.z}, rotation = Transform.rotation(t.rotation), scale = t.scale}
	if node.parent ~= "" then
		local parent = Transform.world(state, node.parent, cache)
		local offset = Transform.rotate(parent.rotation, {x=t.position.x*parent.scale,y=t.position.y*parent.scale,z=t.position.z*parent.scale})
		result.position = {x=parent.position.x+offset.x,y=parent.position.y+offset.y,z=parent.position.z+offset.z}
		result.rotation = multiply(parent.rotation, result.rotation)
		result.scale *= parent.scale
	end
	cache[id] = result
	return result
end

function Transform.bounds(state, node, cache)
	local world = Transform.world(state, node.id, cache)
	local r, s = world.rotation, node.transform.size
	local x, y, z = s.x*world.scale/2, s.y*world.scale/2, s.z*world.scale/2
	return world.position, {
		x=math.abs(r[1])*x+math.abs(r[2])*y+math.abs(r[3])*z,
		y=math.abs(r[4])*x+math.abs(r[5])*y+math.abs(r[6])*z,
		z=math.abs(r[7])*x+math.abs(r[8])*y+math.abs(r[9])*z,
	}
end

Transform.multiplyRotation = multiply
return Transform
