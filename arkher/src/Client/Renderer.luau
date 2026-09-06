--!strict
-- Roblox materialization adapter. Scene state lives in Core, never in these Instances.
local Package = script.Parent.Parent
local CoreFolder=Package:WaitForChild("Core")
local Transform = require(CoreFolder:WaitForChild("Transform"))
local Util = require(CoreFolder:WaitForChild("Util"))
local Renderer = {}
Renderer.__index = Renderer
local materials={stone=Enum.Material.Slate,soil=Enum.Material.Ground,grass=Enum.Material.Grass,sand=Enum.Material.Sand,wood=Enum.Material.Wood,metal=Enum.Material.Metal,glass=Enum.Material.Glass,water=Enum.Material.Glass,neon=Enum.Material.Neon,asphalt=Enum.Material.Asphalt}
local lightingKeys={"ClockTime","Brightness","Ambient","OutdoorAmbient","FogEnd","FogStart","FogColor","GlobalShadows"}
local function cframe(position, rotation)
	return CFrame.new(position.x,position.y,position.z,table.unpack(rotation))
end

function Renderer.new(workspaceService, lighting)
	local root=Instance.new("Model");root.Name="ARKHER_MATERIALIZATION";root.Parent=workspaceService
	local self=setmetatable({root=root,workspace=workspaceService,lighting=lighting,parts={},pool={},targets={},descriptors={},dirty=true,
		metrics={rendered=0,available=0,terrainError=0},savedLighting={},lastLighting={}},Renderer)
	for _,key in ipairs(lightingKeys) do self.savedLighting[key]=lighting[key] end
	local highlight=Instance.new("Highlight");highlight.Name="ARKHER_SELECTION";highlight.FillTransparency=.86;highlight.OutlineColor=Color3.fromRGB(104,239,218);highlight.FillColor=highlight.OutlineColor;highlight.Parent=root
	self.highlight=highlight
	return self
end

function Renderer:setState(state)
	self.state=Util.copy(state);self.environment=nil;self.dirty=true
end

function Renderer:previewTransform(id, transform)
	if self.state and self.state.nodes[id] then self.state.nodes[id].transform=Util.copy(transform);self.dirty=true end
end

function Renderer:applyFrame(frame)
	if not self.state then return end
	for id,position in pairs(frame.positions or {}) do
		if self.state.nodes[id] then self.state.nodes[id].transform.position=position end
	end
	self.environment=frame.environment
	self.dirty=true
end

function Renderer:rebuild(budget)
	local state=self.state
	if not state then return end
	local descriptors,cache={},{}
	local terrains=0
	for _,id in ipairs(state.order) do if state.nodes[id].kind=="terrain" then terrains+=1 end end
	local errorMaximum=0
	self.metrics.unsupported=0
	local function emit(key,node,position,size,rotation,errorValue)
		if size.x<.05 or size.y<.05 or size.z<.05 or size.x>2048 or size.y>2048 or size.z>2048
			or math.abs(position.x)>1000000 or math.abs(position.y)>1000000 or math.abs(position.z)>1000000 then
			self.metrics.unsupported+=1;return -- retained in Core; needs another representation, never silently clamped
		end
		table.insert(descriptors,{key=key,id=node.id,node=node,position=position,size=size,rotation=rotation,error=errorValue or 0})
	end
	for _,id in ipairs(state.order) do
		local node=state.nodes[id]
		local pose=Transform.world(state,id,cache)
		if node.kind=="terrain" then
			local terrain=node.terrain
			local stride=1
			local allowance=math.max(16,math.floor(budget*.7/math.max(1,terrains)))
			while math.ceil(terrain.width/stride)*math.ceil(terrain.depth/stride)>allowance and stride<8 do stride*=2 end
			for row=1,terrain.depth,stride do for col=1,terrain.width,stride do
				local width=math.min(stride,terrain.width-col+1);local depth=math.min(stride,terrain.depth-row+1)
				local sum,count,low,high=0,0,math.huge,-math.huge
				for dz=0,depth-1 do for dx=0,width-1 do
					local height=terrain.heights[(row+dz-1)*terrain.width+col+dx]
					sum+=height;count+=1;low=math.min(low,height);high=math.max(high,height)
				end end
				local height=sum/count
				local approximation=math.max(high-height,height-low)*pose.scale
				errorMaximum=math.max(errorMaximum,approximation)
				local localPosition={x=(col-1+width/2-terrain.width/2)*terrain.cell,y=(height+terrain.base)/2,z=(row-1+depth/2-terrain.depth/2)*terrain.cell}
				local offset=Transform.rotate(pose.rotation,{x=localPosition.x*pose.scale,y=localPosition.y*pose.scale,z=localPosition.z*pose.scale})
				emit(id..":"..row..":"..col,node,{x=pose.position.x+offset.x,y=pose.position.y+offset.y,z=pose.position.z+offset.z},
					{x=width*terrain.cell*pose.scale,y=(height-terrain.base)*pose.scale,z=depth*terrain.cell*pose.scale},pose.rotation,approximation)
			end end
		elseif node.kind~="group" then
			local size=node.transform.size
			if node.kind=="light" then size={x=1,y=1,z=1} end
			emit(id,node,pose.position,{x=size.x*pose.scale,y=size.y*pose.scale,z=size.z*pose.scale},pose.rotation)
		end
	end
	self.descriptors=descriptors;self.metrics.available=#descriptors;self.metrics.terrainError=errorMaximum;self.dirty=false
end

function Renderer:part(descriptor)
	local part=self.parts[descriptor.key]
	if not part then
		part=table.remove(self.pool) or Instance.new("Part")
		part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true
		part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
		part.Parent=self.root;self.parts[descriptor.key]=part
	end
	local node=descriptor.node
	part.Name=node.name;part:SetAttribute("ArkherNodeId",node.id)
	part.Shape=if node.kind=="sphere" or node.kind=="light" then Enum.PartType.Ball elseif node.kind=="cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Size=Vector3.new(descriptor.size.x,descriptor.size.y,descriptor.size.z)
	local surface=node.surface
	part.Material=if node.kind=="light" then Enum.Material.Neon else materials[surface.material] or Enum.Material.Slate
	part.Color=Color3.new(surface.color.r,surface.color.g,surface.color.b)
	part.Transparency=surface.transparency;part.Reflectance=surface.reflectance
	local light=part:FindFirstChild("ARKHER_LIGHT")
	if node.kind=="light" then
		if not light then light=Instance.new("PointLight");light.Name="ARKHER_LIGHT";light.Parent=part end
		light.Color=part.Color;light.Brightness=node.light.intensity;light.Range=node.light.range;light.Shadows=true
	elseif light then light:Destroy() end
	local target=cframe(descriptor.position,descriptor.rotation)
	if not self.targets[descriptor.key] then part.CFrame=target end
	self.targets[descriptor.key]=target
	return part
end

function Renderer:updateLighting()
	local environment=self.environment or (self.state and self.state.environment)
	if not environment then return end
	local night=environment.timeOfDay<6 or environment.timeOfDay>19
	local values={ClockTime=environment.timeOfDay,Brightness=if night then 1.4 else 2.5,
		Ambient=if night then Color3.fromRGB(40,49,68) else Color3.fromRGB(91,101,116),
		OutdoorAmbient=Color3.fromRGB(112,121,132),FogEnd=1800-(environment.fog or 0)*1550,FogStart=30,
		FogColor=if night then Color3.fromRGB(20,29,48) else Color3.fromRGB(153,177,190),GlobalShadows=true}
	for key,value in pairs(values) do
		if self.lastLighting[key]~=value then
			local ok=pcall(function() self.lighting[key]=value end)
			if ok then self.lastLighting[key]=value end
		end
	end
	-- LightingStyle/PrioritizeLightingQuality are NOT written by scripts.
end

function Renderer:render(cameraPosition, budget, selected, dt)
	if not self.state then return end
	budget=math.max(64,math.floor(budget))
	if self.dirty or self.lastBudget~=budget then self:rebuild(budget);self.lastBudget=budget end
	local candidates=table.clone(self.descriptors)
	local function score(d)
		local p=d.position
		return (p.x-cameraPosition.X)^2+(p.y-cameraPosition.Y)^2+(p.z-cameraPosition.Z)^2-(if d.id==selected then 1e12 else 0)
	end
	table.sort(candidates,function(a,b) local sa,sb=score(a),score(b);return if sa==sb then a.key<b.key else sa<sb end)
	local kept,selectedPart={},nil
	for i=1,math.min(#candidates,budget) do
		local descriptor=candidates[i];kept[descriptor.key]=true
		local part=self:part(descriptor)
		part.CFrame=part.CFrame:Lerp(self.targets[descriptor.key],math.min(1,dt*22))
		if descriptor.id==selected and not selectedPart then selectedPart=part end
	end
	local count=0
	for key,part in pairs(self.parts) do
		if not kept[key] then
			self.parts[key]=nil;self.targets[key]=nil;part.Parent=nil
			local light=part:FindFirstChild("ARKHER_LIGHT");if light then light:Destroy() end
			if #self.pool<128 then table.insert(self.pool,part) else part:Destroy() end
		else count+=1 end
	end
	self.highlight.Adornee=selectedPart;self.metrics.rendered=count
	self:updateLighting()
end

function Renderer:pick(camera,x,y)
	local ray=camera:ScreenPointToRay(x,y)
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={self.root}
	local hit=self.workspace:Raycast(ray.Origin,ray.Direction*10000,params)
	if hit then return hit.Instance:GetAttribute("ArkherNodeId"),hit.Position end
	return nil,nil
end

function Renderer:destroy()
	self.root:Destroy()
	for _,part in ipairs(self.pool) do part:Destroy() end
	for key,value in pairs(self.lastLighting) do
		pcall(function() if self.lighting[key]==value then self.lighting[key]=self.savedLighting[key] end end)
	end
end
return Renderer
