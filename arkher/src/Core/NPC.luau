--!strict
-- NMN development layer: perception, episodic memory, needs, utility goals and navigation.
-- Simulated behavior, not consciousness or an LLM per character.
local Util = require(script.Parent:WaitForChild("Util"))
local Transform = require(script.Parent:WaitForChild("Transform"))
local WorldQuery = require(script.Parent:WaitForChild("WorldQuery"))
local Navigation = require(script.Parent:WaitForChild("Navigation"))
local NPC = {}
NPC.__index = NPC
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function random(brain)
	brain.rng=brain.rng*16807%2147483647
	return (brain.rng-1)/2147483646
end
local function remember(brain,kind,sourceId,at)
	brain.summary[kind]=(brain.summary[kind] or 0)+1
	table.insert(brain.memory,{kind=kind,sourceId=sourceId or "",at=at})
	if #brain.memory>32 then table.remove(brain.memory,1) end
end

function NPC.new(state, options)
	options=options or {}
	assert(type(options.thinkBudget or 8)=="number" and (options.thinkBudget or 8)%1==0 and (options.thinkBudget or 8)>=1 and (options.thinkBudget or 8)<=32,"Orçamento de decisões inválido")
	local self=setmetatable({state=state,ids={},brains={},cursor=1,resourceChanges={},thinkBudget=options.thinkBudget or 8,perceived=0,thinking=0,cells={}},NPC)
	for _,id in ipairs(state.order) do
		local node=state.nodes[id]
		if node.kind=="npc" and node.npc.enabled then
			table.insert(self.ids,id)
			local seed=(node.npc.seed+(tonumber(string.match(id,"%d+")) or #self.ids))%2147483646+1
			self.brains[id]={rng=seed,mode="idle",goal="",goalTarget=nil,path={},waypoint=1,nextThink=0,nextWander=0,
				needs={hunger=node.npc.hunger,energy=node.npc.energy},stress=0,memory={},summary={},known={},lastCause="",lastError="",phase=0,home=Util.copy(node.transform.position)}
		end
	end
	assert(#self.ids<=(options.maxNPCs or 64),"NPCs ativos excedem orçamento desta sessão")
	self:refreshGeometry()
	return self
end

function NPC:refreshGeometry()
	self.query=WorldQuery.new(self.state)
	self.navigation=Navigation.new(self.query)
end

function NPC:index()
	self.cells={}
	local cache={}
	for _,id in ipairs(self.state.order) do
		local node=self.state.nodes[id]
		if node.kind~="group" and node.kind~="terrain" then
			local position=Transform.world(self.state,id,cache).position
			local key=math.floor(position.x/16)..","..math.floor(position.z/16)
			self.cells[key]=self.cells[key] or {}
			table.insert(self.cells[key],{node=node,position=position})
		end
	end
end

function NPC:perceive(id, now)
	local node,brain=self.state.nodes[id],self.brains[id]
	local position=node.transform.position
	local sight=node.npc.sight
	local range=math.max(sight,node.npc.hearing)
	local yaw=math.rad(node.transform.rotation.y)
	local forward={x=math.sin(yaw),z=math.cos(yaw)}
	local threshold=math.cos(math.rad(node.npc.fov/2))
	local visible,heard={},{}
	for z=math.floor((position.z-range)/16),math.floor((position.z+range)/16) do
		for x=math.floor((position.x-range)/16),math.floor((position.x+range)/16) do
			for _,entry in ipairs(self.cells[x..","..z] or {}) do
				if entry.node.id~=id then
					self.perceived+=1
					local d=distance(position,entry.position)
					if d<=range then
						local eye={x=position.x,y=position.y+node.transform.size.y*.3,z=position.z}
						local dot=if d<.001 then 1 else ((entry.position.x-position.x)*forward.x+(entry.position.z-position.z)*forward.z)/d
						local canSee=d<=sight and dot>=threshold and self.query:visible(eye,entry.position,entry.node.id)
						local noise=entry.node.metadata.noiseRadius
						local canHear=type(noise)=="number" and noise>=d and noise>0 and d<=node.npc.hearing
						if canSee then table.insert(visible,entry) end
						if canHear then table.insert(heard,entry) end
						if canSee or canHear then
							local previous=brain.known[entry.node.id]
							brain.known[entry.node.id]={position=Util.copy(entry.position),at=now,hazard=entry.node.metadata.hazard==true,food=entry.node.metadata.food==true and (entry.node.metadata.foodAmount or 0)>0}
							if not previous then remember(brain,canSee and "seen" or "heard",entry.node.id,now) end
						end
					end
				end
			end
		end
	end
	local known=Util.keys(brain.known)
	if #known>128 then
		table.sort(known,function(a,b) local aa,bb=brain.known[a].at,brain.known[b].at;return aa<bb or (aa==bb and a<b) end)
		for i=1,#known-128 do brain.known[known[i]]=nil end
	end
	return visible,heard
end

function NPC:planPath(id,target,goal,now,cause)
	local node,brain=self.state.nodes[id],self.brains[id]
	local path,report=self.navigation:find(node.transform.position,target,{radius=math.max(node.transform.size.x,node.transform.size.z)*node.transform.scale/2,height=node.transform.size.y*node.transform.scale,maxStep=node.npc.maxStep,maxExpanded=768})
	brain.lastCause=cause or ""
	brain.goal=goal;brain.goalTarget=Util.copy(target);brain.lastError=path and "" or report.reason
	brain.path=path or {};brain.waypoint=1;brain.mode=path and (goal=="flee" and "fleeing" or "walking") or "blocked"
	if not path then brain.nextWander=now+1 end
	remember(brain,path and "planned" or "path-blocked",cause,now)
end

function NPC:think(id,now)
	local node,brain=self.state.nodes[id],self.brains[id]
	local visible,heard=self:perceive(id,now)
	local threat,threatDistance=nil,math.huge
	for _,list in ipairs({visible,heard}) do for _,entry in ipairs(list) do
		if entry.node.metadata.hazard==true then
			local d=distance(node.transform.position,entry.position)
			if d<threatDistance then threat,threatDistance=entry,d end
		end
	end end
	if threat then
		brain.stress=math.clamp(brain.stress+.35*(1-node.npc.bravery*.6),0,1)
		if brain.goal~="flee" or #brain.path==0 then
			local p=node.transform.position
			local dx,dz=p.x-threat.position.x,p.z-threat.position.z
			local length=math.max(.01,math.sqrt(dx*dx+dz*dz));if length<.1 then dx,dz,length=1,0,1 end
			self:planPath(id,{x=p.x+dx/length*16,y=p.y,z=p.z+dz/length*16},"flee",now,threat.node.id)
		end
		return
	end
	brain.stress=math.max(0,brain.stress-.08)
	if brain.needs.energy<.18 then
		if brain.mode~="resting" then remember(brain,"rest",nil,now) end
		brain.mode="resting";brain.goal="rest";brain.path={};return
	elseif brain.mode=="resting" and brain.needs.energy<.85 then return end
	if brain.needs.hunger>.65 then
		local food
		for _,knownId in ipairs(Util.keys(brain.known)) do
			local known=brain.known[knownId]
			if known.food and self.state.nodes[knownId] then food={id=knownId,position=known.position};break end
		end
		if food then
			if distance(node.transform.position,food.position)<6 then
				local resource=self.state.nodes[food.id]
				if (resource.metadata.foodAmount or 0)>0 then
					resource.metadata.foodAmount-=1;self.resourceChanges[food.id]=resource.metadata.foodAmount
					brain.needs.hunger=math.max(0,brain.needs.hunger-.6);remember(brain,"ate",food.id,now)
				else brain.known[food.id].food=false;remember(brain,"food-depleted",food.id,now) end
				brain.path={};brain.goal=""
			elseif brain.goal~="food" or #brain.path==0 then self:planPath(id,food.position,"food",now,food.id) end
			return
		end
	end
	if #brain.path>0 then return end
	if node.npc.behavior=="goTo" then
		if brain.goal=="arrived" then return end
		self:planPath(id,node.npc.target,"target",now,"assigned-target")
	elseif now>=brain.nextWander then
		local angle=random(brain)*math.pi*2
		local radius=6+random(brain)*node.npc.roamRadius
		self:planPath(id,{x=brain.home.x+math.sin(angle)*radius,y=brain.home.y,z=brain.home.z+math.cos(angle)*radius},"wander",now,"context-and-seed")
		brain.nextWander=now+2+random(brain)*3
	end
end

function NPC:step(dt,now)
	self:index();self.thinking=0;self.perceived=0;self.resourceChanges={}
	local count=#self.ids
	for offset=0,count-1 do
		local index=(self.cursor+offset-1)%math.max(1,count)+1
		local id=self.ids[index];local brain=self.brains[id]
		if brain.nextThink<=now and self.thinking<self.thinkBudget then
			self:think(id,now);brain.nextThink=now+.35;self.thinking+=1
		end
	end
	if count>0 then self.cursor=self.cursor%count+1 end
	local changed={}
	for _,id in ipairs(self.ids) do
		local node,brain=self.state.nodes[id],self.brains[id]
		brain.needs.hunger=math.min(1,brain.needs.hunger+dt*.004)
		brain.needs.energy=math.clamp(brain.needs.energy+dt*(brain.mode=="resting" and .08 or -.004),0,1)
		local target=brain.path[brain.waypoint]
		if target then
			local p=node.transform.position
			local d=distance(p,target)
			local step=math.min(d,node.npc.speed*dt)
			if d>.001 then
				local nextPosition={x=p.x+(target.x-p.x)/d*step,z=p.z+(target.z-p.z)/d*step}
				local valid,ground=self.query:walkable(nextPosition.x,nextPosition.z,math.max(node.transform.size.x,node.transform.size.z)*node.transform.scale/2,node.transform.size.y*node.transform.scale)
				if valid then
					node.transform.position={x=nextPosition.x,y=ground+node.transform.size.y*node.transform.scale/2,z=nextPosition.z}
					node.transform.rotation.y=math.deg(math.atan2(target.x-p.x,target.z-p.z))
					brain.phase+=step;brain.needs.energy=math.max(0,brain.needs.energy-dt*.008);changed[id]=true
				else brain.path={};brain.mode="blocked";brain.lastError="segment_blocked" end
			end
			if d<.15 or step>=d then
				brain.waypoint+=1
				if brain.waypoint>#brain.path then brain.path={};brain.mode="idle";if brain.goal=="target" then brain.goal="arrived" end;remember(brain,"arrived",brain.lastCause,now) end
			end
		else
			local ground=self.query:height(node.transform.position.x,node.transform.position.z)
			if ground then node.transform.position.y=ground+node.transform.size.y*node.transform.scale/2;changed[id]=true end
		end
	end
	return changed
end

function NPC:summary()
	local result={}
	for _,id in ipairs(self.ids) do
		local brain=self.brains[id]
		result[id]={mode=brain.mode,goal=brain.goal,hunger=brain.needs.hunger,energy=brain.needs.energy,stress=brain.stress,memoryCount=#brain.memory,lastCause=brain.lastCause,lastError=brain.lastError,phase=brain.phase}
	end
	return result
end

function NPC:snapshot() return {cursor=self.cursor,brains=Util.copy(self.brains)} end
function NPC:restore(saved)
	Util.data(saved,100000)
	assert(type(saved)=="table" and type(saved.brains)=="table","Memória de NPC inválida")
	local brains={}
	for _,id in ipairs(self.ids) do
		local b=assert(saved.brains[id],"Checkpoint sem memória de NPC")
		assert(type(b.needs)=="table" and type(b.summary)=="table","Estado interno de NPC ausente")
		assert(b.mode=="idle" or b.mode=="walking" or b.mode=="fleeing" or b.mode=="resting" or b.mode=="blocked","Modo de NPC inválido")
		Util.text(b.goal,"",40);Util.text(b.lastCause,"",100);Util.text(b.lastError,"",200)
		Util.vector(b.home,{x=0,y=0,z=0},-1e6,1e6)
		Util.number(b.phase,0,0,1e12);Util.number(b.stress,0,0,1)
		if b.goalTarget then Util.vector(b.goalTarget,{x=0,y=0,z=0},-1e6,1e6) end
		Util.number(b.rng,1,1,2147483646);assert(b.rng%1==0,"RNG inválido")
		Util.number(b.needs.hunger,0,0,1);Util.number(b.needs.energy,1,0,1)
		Util.number(b.nextThink,0,0,1e12);Util.number(b.nextWander,0,0,1e12)
		assert(type(b.path)=="table" and #b.path<=4096 and type(b.memory)=="table" and #b.memory<=32 and type(b.known)=="table" and #Util.keys(b.known)<=128,"Orçamento de memória de NPC inválido")
		assert(type(b.waypoint)=="number" and b.waypoint%1==0 and b.waypoint>=1 and b.waypoint<=#b.path+1,"Waypoint inválido")
		for _,p in ipairs(b.path) do Util.vector(p,{x=0,y=0,z=0},-1e6,1e6) end
		for key,count in pairs(b.summary) do Util.text(key,"",50);Util.number(count,0,0,1e12) end
		for _,event in ipairs(b.memory) do Util.text(event.kind,"",50);Util.text(event.sourceId,"",100);Util.number(event.at,0,0,1e12) end
		for knownId,fact in pairs(b.known) do
			assert(self.state.nodes[knownId],"Fato de entidade inexistente")
			Util.vector(fact.position,{x=0,y=0,z=0},-1e6,1e6);Util.number(fact.at,0,0,1e12)
			assert(type(fact.food)=="boolean" and type(fact.hazard)=="boolean","Fato inválido")
		end
		brains[id]=Util.copy(b)
	end
	for id in pairs(saved.brains) do assert(brains[id],"Memória de entidade inexistente") end
	self.brains=brains
	self.cursor=math.floor(Util.number(saved.cursor,1,1,math.max(1,#self.ids)))
end
return NPC
