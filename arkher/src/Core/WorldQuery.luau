--!strict
-- Geometry queries over ARKHER data, independent of Roblox raycasts/pathfinding.
local Transform = require(script.Parent:WaitForChild("Transform"))
local WorldQuery = {}
WorldQuery.__index = WorldQuery

local function upright(rotation)
	return math.abs(rotation[2])+math.abs(rotation[8])+math.abs(rotation[5]-1)<.00001
end

function WorldQuery.new(state)
	local self=setmetatable({surfaces={},terrains={},obstacles={},bounds=nil,samples=0,cache={}},WorldQuery)
	local cache={}
	local function bounds(x,z,hx,hz)
		if not self.bounds then self.bounds={minX=x-hx,maxX=x+hx,minZ=z-hz,maxZ=z+hz}
		else
			self.bounds.minX=math.min(self.bounds.minX,x-hx);self.bounds.maxX=math.max(self.bounds.maxX,x+hx)
			self.bounds.minZ=math.min(self.bounds.minZ,z-hz);self.bounds.maxZ=math.max(self.bounds.maxZ,z+hz)
		end
	end
	for _,id in ipairs(state.order) do
		local node=state.nodes[id]
		if node.kind=="terrain" and node.body.collidable then
			local pose=Transform.world(state,id,cache)
			assert(upright(pose.rotation),"Navegação atual exige heightfields verticais")
			table.insert(self.terrains,{node=node,pose=pose})
			local radius=math.sqrt(node.terrain.width^2+node.terrain.depth^2)*node.terrain.cell*pose.scale/2
			bounds(pose.position.x,pose.position.z,radius,radius)
		elseif node.body.collidable and not node.body.dynamic and (node.kind=="box" or node.kind=="sphere" or node.kind=="cylinder") then
			local p,h=Transform.bounds(state,node,cache)
			local pose=Transform.world(state,id,cache)
			local item={id=id,p=p,h=h}
			local walkable=node.kind=="box" and upright(pose.rotation) and h.y<=1.1 and h.x>=3 and h.z>=3
			if walkable then table.insert(self.surfaces,item);bounds(p.x,p.z,h.x,h.z)
			else table.insert(self.obstacles,item) end
		end
	end
	return self
end

function WorldQuery:height(x,z)
	local best=nil
	for _,entry in ipairs(self.terrains) do
		local p,r,t=entry.pose.position,entry.pose.rotation,entry.node.terrain
		local dx,dz=x-p.x,z-p.z
		local lx=(r[1]*dx+r[7]*dz)/entry.pose.scale
		local lz=(r[3]*dx+r[9]*dz)/entry.pose.scale
		local col=math.floor(lx/t.cell+t.width/2)+1
		local row=math.floor(lz/t.cell+t.depth/2)+1
		if col>=1 and col<=t.width and row>=1 and row<=t.depth then
			local h=p.y+t.heights[(row-1)*t.width+col]*entry.pose.scale
			best=if best then math.max(best,h) else h
		end
	end
	for _,item in ipairs(self.surfaces) do
		if math.abs(x-item.p.x)<=item.h.x and math.abs(z-item.p.z)<=item.h.z then
			local h=item.p.y+item.h.y;best=if best then math.max(best,h) else h
		end
	end
	return best
end

function WorldQuery:walkable(x,z,radius,height)
	self.samples+=1
	local ground=self:height(x,z)
	if not ground then return false,nil end
	for _,item in ipairs(self.obstacles) do
		if math.abs(x-item.p.x)<item.h.x+radius and math.abs(z-item.p.z)<item.h.z+radius
			and item.p.y+item.h.y>ground+.35 and item.p.y-item.h.y<ground+height then return false,ground end
	end
	return true,ground
end

local function segmentBox(a,b,item)
	local low,high=0,1
	for _,axis in ipairs({"x","y","z"}) do
		local d=b[axis]-a[axis]
		local minimum,maximum=item.p[axis]-item.h[axis],item.p[axis]+item.h[axis]
		if math.abs(d)<.000001 then
			if a[axis]<minimum or a[axis]>maximum then return false end
		else
			local p,q=(minimum-a[axis])/d,(maximum-a[axis])/d
			if p>q then p,q=q,p end
			low,high=math.max(low,p),math.min(high,q)
			if low>high then return false end
		end
	end
	return high>.001 and low<.999
end

function WorldQuery:visible(a,b,targetId)
	for _,item in ipairs(self.obstacles) do if item.id~=targetId and segmentBox(a,b,item) then return false end end
	local distance=math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
	local steps=math.min(24,math.max(2,math.ceil(distance/3)))
	for i=1,steps-1 do
		local alpha=i/steps
		local ground=self:height(a.x+(b.x-a.x)*alpha,a.z+(b.z-a.z)*alpha)
		if ground and ground>a.y+(b.y-a.y)*alpha+.1 then return false end
	end
	return true
end
return WorldQuery
