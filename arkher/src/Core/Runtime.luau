--!strict
-- Own deterministic simulation of the project fork; Roblox is not the state store.
-- Current collision model: conservative AABBs + upright heightfields, not a complete rigid-body solver.
local Util = require(script.Parent:WaitForChild("Util"))
local Transform = require(script.Parent:WaitForChild("Transform"))
local Graph = require(script.Parent:WaitForChild("Graph"))
local Runtime = {}
Runtime.__index = Runtime
local axes = {"x","y","z"}

local function terrainHeight(state,node,x,z,cache)
	local world=Transform.world(state,node.id,cache)
	local r,p=world.rotation,world.position
	local dx,dz=x-p.x,z-p.z
	local lx=(r[1]*dx+r[7]*dz)/world.scale
	local lz=(r[3]*dx+r[9]*dz)/world.scale
	local t=node.terrain
	local col=math.floor(lx/t.cell+t.width/2)+1
	local row=math.floor(lz/t.cell+t.depth/2)+1
	if col<1 or col>t.width or row<1 or row>t.depth then return nil end
	return p.y+t.heights[(row-1)*t.width+col]*world.scale
end

function Runtime.new(state, options)
	local self=setmetatable({state=Util.copy(state),time=0,ticks=0,contacts=0,candidates=0,graphs={},errors={}},Runtime)
	local dynamics=0
	for _,id in ipairs(state.order) do
		local node=state.nodes[id]
		if node.body.dynamic then dynamics+=1 end
		if node.kind=="terrain" then
			local r=Transform.world(state,id).rotation
			assert(math.abs(r[2])+math.abs(r[8])+math.abs(r[5]-1)<.00001,"O solver atual exige heightfields verticais; inclinação pendente")
		end
	end
	assert(dynamics<=((options or {}).maxDynamics or 128),"Corpos ativos excedem orçamento desta sessão")
	for _,id in ipairs(Util.keys(state.graphs)) do
		local graph=state.graphs[id]
		if graph.enabled~=false then table.insert(self.graphs,{graph=graph,compiled=Graph.compile(graph)}) end
	end
	return self
end

local function broadphase(colliders)
	local cells, large = {}, {}
	for _,collider in ipairs(colliders) do
		local p,h=collider.position,collider.half
		local low={x=math.floor((p.x-h.x)/16),y=math.floor((p.y-h.y)/16),z=math.floor((p.z-h.z)/16)}
		local high={x=math.floor((p.x+h.x)/16),y=math.floor((p.y+h.y)/16),z=math.floor((p.z+h.z)/16)}
		collider.low,collider.high=low,high
		if (high.x-low.x+1)*(high.y-low.y+1)*(high.z-low.z+1)>64 then table.insert(large,collider)
		else
			for x=low.x,high.x do for y=low.y,high.y do for z=low.z,high.z do
				local key=x..","..y..","..z
				cells[key]=cells[key] or {};table.insert(cells[key],collider)
			end end end
		end
	end
	return cells,large
end

function Runtime:step(dt)
	Util.number(dt,.05,.001,.1)
	self.time+=dt;self.ticks+=1;self.contacts=0;self.candidates=0;self.changed={}
	local state=self.state
	state.environment.timeOfDay=(state.environment.timeOfDay+dt*state.environment.timeScale/60)%24
	for _,entry in ipairs(self.graphs) do
		local ok,operations=pcall(Graph.evaluate,state,entry.graph,self.time,entry.compiled)
		if ok then for _,op in ipairs(operations) do state.nodes[op.id].transform.position=op.position;self.changed[op.id]=true end
		else table.insert(self.errors,tostring(operations));if #self.errors>16 then table.remove(self.errors,1) end end
	end
	local terrain, moving, previous = {}, {}, {}
	for _,id in ipairs(state.order) do
		local node=state.nodes[id]
		if node.kind=="terrain" and node.body.collidable then table.insert(terrain,node) end
		if node.body.dynamic then
			table.insert(moving,node);previous[id]=node.transform.position.y;self.changed[id]=true
			node.body.velocity.y-=state.environment.gravity*dt
			for _,axis in ipairs(axes) do node.transform.position[axis]+=node.body.velocity[axis]*dt end
			if node.transform.position.y < -10000 then node.body.dynamic=false;node.body.velocity={x=0,y=0,z=0};table.insert(self.errors,"Corpo fora da região simulada: "..id) end
		end
	end
	for iteration=1,2 do
		local cache,colliders={},{}
		for _,id in ipairs(state.order) do
			local node=state.nodes[id]
			if node.body.collidable and (node.kind=="box" or node.kind=="sphere" or node.kind=="cylinder") then
				local p,h=Transform.bounds(state,node,cache)
				table.insert(colliders,{node=node,position=p,half=h})
			end
		end
		local cells,large=broadphase(colliders)
		local resolved={}
		for _,a in ipairs(colliders) do if a.node.body.dynamic then
			local candidates,seen={},{}
			local function collect(b)
				if b.node.id~=a.node.id and not seen[b.node.id] then seen[b.node.id]=true;table.insert(candidates,b) end
			end
			local l,h=a.low,a.high
			if (h.x-l.x+1)*(h.y-l.y+1)*(h.z-l.z+1)>64 then for _,b in ipairs(colliders) do collect(b) end
			else
				for x=l.x,h.x do for y=l.y,h.y do for z=l.z,h.z do
					for _,b in ipairs(cells[x..","..y..","..z] or {}) do collect(b) end
				end end end
				for _,b in ipairs(large) do collect(b) end
			end
			table.sort(candidates,function(b,c) return b.node.id<c.node.id end)
			for _,b in ipairs(candidates) do
				local pair=if a.node.id<b.node.id then a.node.id.."/"..b.node.id else b.node.id.."/"..a.node.id
				if not resolved[pair] then
					resolved[pair]=true;self.candidates+=1
					local overlap,axis,amount=true,"y",math.huge
					for _,key in ipairs(axes) do
						local penetration=a.half[key]+b.half[key]-math.abs(a.position[key]-b.position[key])
						if penetration<=0 then overlap=false;break end
						if penetration<amount then amount=penetration;axis=key end
					end
					if overlap then
						self.contacts+=1
						local normal=if a.position[axis]>=b.position[axis] then 1 else -1
						local invA=1/a.node.body.mass
						local invB=if b.node.body.dynamic then 1/b.node.body.mass else 0
						a.node.transform.position[axis]+=normal*amount*invA/(invA+invB)
						if invB>0 then b.node.transform.position[axis]-=normal*amount*invB/(invA+invB) end
						local relative=(a.node.body.velocity[axis]-b.node.body.velocity[axis])*normal
						if relative<0 then
							local impulse=-(1+math.min(a.node.body.restitution,b.node.body.restitution))*relative/(invA+invB)
							a.node.body.velocity[axis]+=impulse*invA*normal
							if invB>0 then b.node.body.velocity[axis]-=impulse*invB*normal end
						end
					end
				end
			end
		end end
	end
	local cache={}
	for _,body in ipairs(moving) do
		local p,h=Transform.bounds(state,body,cache)
		for _,ground in ipairs(terrain) do
			local height=terrainHeight(state,ground,p.x,p.z,cache)
			if height and p.y-h.y<height and (p.y+h.y>height-16 or previous[body.id]-h.y>=height) then
				body.transform.position.y=height+h.y
				if body.body.velocity.y<0 then body.body.velocity.y=-body.body.velocity.y*body.body.restitution end
				self.contacts+=1
			end
		end
	end
	return self:frame()
end

function Runtime:frame()
	local transforms={}
	for id in pairs(self.changed or {}) do transforms[id]=table.clone(self.state.nodes[id].transform.position) end
	return {time=self.time,tick=self.ticks,positions=transforms,environment=table.clone(self.state.environment),contacts=self.contacts,candidates=self.candidates,errors=table.clone(self.errors)}
end

return Runtime
