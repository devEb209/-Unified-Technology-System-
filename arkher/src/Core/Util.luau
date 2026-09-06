--!strict
-- Data-only boundaries shared by editor, simulation and platform adapters.
local Util = {}

function Util.number(value, fallback, low, high)
	local n = if value == nil then fallback else value
	assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Número finito obrigatório")
	assert(n >= low and n <= high, "Número fora do orçamento permitido")
	return n
end

function Util.text(value, fallback, maximum)
	local s = if value == nil then fallback else value
	assert(type(s) == "string" and #s <= maximum and not string.find(s, "\0", 1, true), "Texto inválido")
	return s
end

function Util.data(value, maximum)
	local seen, count = {}, 0
	local function visit(item, depth)
		count += 1
		assert(count <= (maximum or 120000) and depth <= 32, "Dados excedem orçamento estrutural")
		local t = type(item)
		if t == "table" then
			assert(not seen[item] and getmetatable(item) == nil, "Ciclo ou metatable não permitido")
			seen[item] = true
			for key, child in pairs(item) do
				assert(type(key) == "string" or (type(key) == "number" and key >= 1 and key % 1 == 0), "Chave inválida")
				assert(key ~= "__proto__", "Chave reservada")
				visit(child, depth + 1)
			end
			seen[item] = nil
		elseif t == "number" then
			assert(item == item and math.abs(item) < math.huge, "Número não finito")
		elseif t == "string" then
			assert(#item <= 1048576, "Texto excessivo")
		else
			assert(t == "boolean" or t == "nil", "Somente dados; código e Instances não são aceitos")
		end
	end
	visit(value, 0)
end

function Util.copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = Util.copy(child) end
	return result
end

function Util.freeze(value)
	if type(value) ~= "table" or table.isfrozen(value) then return value end
	for _, child in pairs(value) do Util.freeze(child) end
	return table.freeze(value)
end

function Util.vector(value, fallback, low, high)
	local v = value or fallback
	assert(type(v) == "table", "Vetor obrigatório")
	return {
		x = Util.number(v.x, fallback.x, low, high),
		y = Util.number(v.y, fallback.y, low, high),
		z = Util.number(v.z, fallback.z, low, high),
	}
end

function Util.keys(t)
	local result = {}
	for key in pairs(t) do table.insert(result, key) end
	table.sort(result)
	return result
end

function Util.rng(seed)
	local state = math.floor(Util.number(seed, 1, 1, 2147483646))
	return function()
		state = state * 16807 % 2147483647
		return (state - 1) / 2147483646
	end
end

return Util
