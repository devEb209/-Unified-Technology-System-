--!strict
local Util = require(script.Parent:WaitForChild("Util"))
local Navigation = {}
Navigation.__index = Navigation
local directions={{1,0},{0,1},{-1,0},{0,-1}}
local function key(x,z) return x..","..z end
local function better(a,b) return a.f<b.f or (a.f==b.f and (a.g<b.g or (a.g==b.g and a.key<b.key))) end
local function push(heap,item)
	table.insert(heap,item);local i=#heap
	while i>1 do local p=math.floor(i/2);if not better(heap[i],heap[p]) then break end;heap[i],heap[p]=heap[p],heap[i];i=p end
end
local function pop(heap)
	local first=heap[1];local last=table.remove(heap)
	if #heap>0 then
		heap[1]=last;local i=1
		while i*2<=#heap do
			local child=i*2;if child+1<=#heap and better(heap[child+1],heap[child]) then child+=1 end
			if not better(heap[child],heap[i]) then break end
			heap[i],heap[child]=heap[child],heap[i];i=child
		end
	end
	return first
end

function Navigation.new(query, options)
	options=options or {}
	return setmetatable({query=query,cell=Util.number(options.cell,4,1,16),cache={},cacheCount=0,requests=0,expanded=0,failed=0},Navigation)
end

function Navigation:sample(x,z,radius,height)
	local cacheKey=key(x,z)..":"..radius..":"..height
	local value=self.cache[cacheKey]
	if value then return value end
	local wx,wz=x*self.cell,z*self.cell
	local ok,y=self.query:walkable(wx,wz,radius,height)
	value={walkable=ok,height=y,x=wx,z=wz,cx=x,cz=z,key=key(x,z)}
	if self.cacheCount<12000 then self.cache[cacheKey]=value;self.cacheCount+=1 end
	return value
end

function Navigation:nearest(position, radius, height, searchRadius)
	local cx,cz=math.floor(position.x/self.cell+.5),math.floor(position.z/self.cell+.5)
	local best,bestDistance=nil,math.huge
	for dz=-searchRadius,searchRadius do for dx=-searchRadius,searchRadius do
		local cell=self:sample(cx+dx,cz+dz,radius,height)
		local distance=(cell.x-position.x)^2+(cell.z-position.z)^2
		if cell.walkable and (distance<bestDistance or (distance==bestDistance and cell.key<(best and best.key or "~"))) then best,bestDistance=cell,distance end
	end end
	return best
end

function Navigation:find(start, target, options)
	options=options or {};self.requests+=1
	local radius=Util.number(options.radius,1,.2,4)
	local height=Util.number(options.height,4,1,12)
	local maxStep=Util.number(options.maxStep,3,0,12)
	local budget=math.floor(Util.number(options.maxExpanded,1024,1,4096))
	start=Util.vector(start,{x=0,y=0,z=0},-1e6,1e6);target=Util.vector(target,{x=0,y=0,z=0},-1e6,1e6)
	local first=self:nearest(start,radius,height,1)
	local last=self:nearest(target,radius,height,options.snapTarget==false and 0 or 2)
	if not first or not last then self.failed+=1;return nil,{reason="no_walkable_endpoint",expanded=0} end
	local heap,g,came,cells={}, {[first.key]=0}, {}, {[first.key]=first}
	local function estimate(cell) return (math.abs(cell.cx-last.cx)+math.abs(cell.cz-last.cz))*self.cell end
	push(heap,{key=first.key,cell=first,g=0,f=estimate(first)})
	local expanded=0
	while #heap>0 and expanded<budget do
		local current=pop(heap)
		if current.g==g[current.key] then
			if current.key==last.key then
				local reverse={}
				local at=current.key
				while at do
					local cell=cells[at]
					table.insert(reverse,{x=cell.x,y=cell.height,z=cell.z});at=came[at]
				end
				local path={}
				for i=#reverse,1,-1 do table.insert(path,reverse[i]) end
				self.expanded+=expanded
				return path,{reason="found",expanded=expanded,cost=current.g,resolvedTarget={x=last.x,y=last.height,z=last.z}}
			end
			expanded+=1
			for _,direction in ipairs(directions) do
				local nextCell=self:sample(current.cell.cx+direction[1],current.cell.cz+direction[2],radius,height)
				if nextCell.walkable and math.abs(nextCell.height-current.cell.height)<=maxStep then
					local tentative=current.g+self.cell+math.abs(nextCell.height-current.cell.height)*.3
					if tentative<(g[nextCell.key] or math.huge) then
						g[nextCell.key]=tentative;came[nextCell.key]=current.key;cells[nextCell.key]=nextCell
						push(heap,{key=nextCell.key,cell=nextCell,g=tentative,f=tentative+estimate(nextCell)})
					end
				end
			end
		end
	end
	self.expanded+=expanded;self.failed+=1
	return nil,{reason=if #heap>0 then "budget_exhausted" else "unreachable",expanded=expanded}
end
return Navigation
