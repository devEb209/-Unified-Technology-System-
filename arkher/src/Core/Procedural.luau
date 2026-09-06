--!strict
local Util = require(script.Parent:WaitForChild("Util"))
local Procedural = {}

local function sample(seed, x, z)
	local value = (seed + x*374761 + z*668265) % 2147483647
	return ((value*16807)%2147483647)/2147483647
end
local function noise(seed, x, z)
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x-ix, z-iz
	fx, fz = fx*fx*(3-2*fx), fz*fz*(3-2*fz)
	local a, b = sample(seed,ix,iz), sample(seed,ix+1,iz)
	local c, d = sample(seed,ix,iz+1), sample(seed,ix+1,iz+1)
	return (a+(b-a)*fx)*(1-fz)+(c+(d-c)*fx)*fz
end

function Procedural.terrain(options)
	local width = Util.number(options.width,12,2,32)
	local depth = Util.number(options.depth,width,2,32)
	assert(width%1==0 and depth%1==0, "Dimensões inteiras obrigatórias")
	local seed = math.floor(Util.number(options.seed,42,1,2147483646))
	local amplitude = Util.number(options.amplitude,8,0,64)
	local heights = {}
	for z=1,depth do
		for x=1,width do
			heights[(z-1)*width+x] = 1 + amplitude*(0.7*noise(seed,x/5,z/5)+0.3*noise(seed+17,x/2,z/2))
		end
	end
	return {name="Terreno · seed "..seed,kind="terrain",surface={material="grass",color={r=0.31,g=0.47,b=0.34}},
		terrain={width=width,depth=depth,cell=options.cell or 6,seed=seed,heights=heights},metadata={generator="heightfield",seed=seed}}
end

function Procedural.brush(node, options)
	assert(node.kind=="terrain", "Selecione um terreno")
	local t = node.terrain
	local radius = Util.number(options.radius,12,0.5,128)
	local strength = Util.number(options.strength,2,0.01,32)
	local x = Util.number(options.x,0,-1000000,1000000)
	local z = Util.number(options.z,0,-1000000,1000000)
	local mode = options.mode or "raise"
	assert(mode=="raise" or mode=="lower" or mode=="smooth" or mode=="flatten", "Pincel desconhecido")
	local old = table.clone(t.heights)
	local changed = 0
	for row=1,t.depth do
		for col=1,t.width do
			local cx, cz = (col-0.5-t.width/2)*t.cell, (row-0.5-t.depth/2)*t.cell
			local distance = math.sqrt((cx-x)^2+(cz-z)^2)
			if distance <= radius then
				local index, weight = (row-1)*t.width+col, 1-distance/radius
				local height = old[index]
				if mode=="raise" then height += strength*weight
				elseif mode=="lower" then height -= strength*weight
				elseif mode=="flatten" then height += ((options.height or 3)-height)*math.min(1,strength*weight/4)
				else
					local sum, count = 0, 0
					for dz=-1,1 do for dx=-1,1 do
						local rx, rz = col+dx, row+dz
						if rx>=1 and rx<=t.width and rz>=1 and rz<=t.depth then sum += old[(rz-1)*t.width+rx];count += 1 end
					end end
					height += (sum/count-height)*math.min(1,strength*weight/4)
				end
				t.heights[index] = math.clamp(height,-15,128)
				changed += 1
			end
		end
	end
	return changed
end

function Procedural.city(options)
	local blocks = Util.number(options.blocks,3,1,6)
	assert(blocks%1==0,"Número inteiro de quarteirões obrigatório")
	local seed = math.floor(Util.number(options.seed,42,1,2147483646))
	local random, nodes = Util.rng(seed), {}
	local spacing = 18
	local extent = blocks*spacing+10
	table.insert(nodes,{name="Base urbana",kind="box",transform={position={x=0,y=-0.5,z=0},size={x=extent,y=1,z=extent}},surface={material="soil",color={r=.2,g=.24,b=.23}}})
	for i=0,blocks do
		local at = (i-blocks/2)*spacing
		table.insert(nodes,{name="Via norte-sul "..i,kind="box",transform={position={x=at,y=.04,z=0},size={x=5,y=.1,z=extent}},surface={material="asphalt",color={r=.10,g=.13,b=.17}}})
		table.insert(nodes,{name="Via leste-oeste "..i,kind="box",transform={position={x=0,y=.04,z=at},size={x=extent,y=.1,z=5}},surface={material="asphalt",color={r=.10,g=.13,b=.17}}})
	end
	for row=1,blocks do for col=1,blocks do
		local x, z = (col-.5-blocks/2)*spacing, (row-.5-blocks/2)*spacing
		local height = 7 + math.floor(random()*22)
		local tone = .32+random()*.26
		table.insert(nodes,{name="Edifício "..row.."."..col,kind="box",transform={position={x=x,y=height/2,z=z},size={x=10,y=height,z=10}},surface={material="stone",color={r=tone,g=tone+.04,b=tone+.09}},metadata={generator="city",seed=seed}})
		table.insert(nodes,{name="Fachada "..row.."."..col,kind="box",body={collidable=false},transform={position={x=x,y=height/2+1,z=z-5.06},size={x=7,y=math.max(2,height-4),z=.12}},surface={material="glass",color={r=.13,g=.34,b=.42},reflectance=.15}})
	end end
	return nodes
end

return Procedural
