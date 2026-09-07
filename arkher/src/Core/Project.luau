--!strict
local Util = require(script.Parent:WaitForChild("Util"))
local Schema = require(script.Parent:WaitForChild("Schema"))
local Procedural = require(script.Parent:WaitForChild("Procedural"))
local Graph = require(script.Parent:WaitForChild("Graph"))
local Project = {}
Project.__index = Project

local function draft(state)
	local nextState = table.clone(state)
	nextState.nodes, nextState.order = table.clone(state.nodes), table.clone(state.order)
	nextState.environment, nextState.settings, nextState.graphs = table.clone(state.environment), table.clone(state.settings), table.clone(state.graphs)
	return nextState
end

function Project.new(name, options)
	local self = setmetatable({},Project)
	self.maxEntities, self.historyLimit = (options or {}).maxEntities or 2000, (options or {}).historyLimit or 32
	self.state, self.undoStack, self.redoStack = Util.freeze(Schema.empty(name)), {}, {}
	return self
end

function Project:snapshot()
	return Util.copy(self.state)
end

function Project:_apply(state, operations)
	local created, changed = {}, {}
	local function edit(id)
		assert(state.nodes[id], "Entidade não encontrada: "..tostring(id))
		if not changed[id] then state.nodes[id] = Util.copy(state.nodes[id]);changed[id]=true end
		return state.nodes[id]
	end
	local function add(raw)
		local id
		local attempts=0
		repeat
			attempts+=1;assert(attempts<=self.maxEntities+1 and state.nextId<=999999999,"Sequência de identidade excedida")
			id=string.format("e%08d",state.nextId);state.nextId+=1
		until not state.nodes[id]
		local node = Schema.node(raw,id)
		state.nodes[id]=node;table.insert(state.order,id);table.insert(created,id);changed[id]=true
		assert(#state.order<=self.maxEntities,"Orçamento de entidades excedido")
		return id
	end
	local apply
	apply = function(operation)
		local op = operation.op
		if op=="add" then add(assert(operation.node,"Entidade ausente"))
		elseif op=="transform" then
			local node = edit(operation.id)
			for _, key in ipairs({"position","rotation","size","scale"}) do
				if operation[key]~=nil then node.transform[key]=Util.copy(operation[key]) end
			end
			state.nodes[node.id]=Schema.node(node,node.id)
		elseif op=="surface" or op=="body" then
			local node=edit(operation.id)
			assert(type(operation.patch)=="table","Patch obrigatório")
			for key,value in pairs(operation.patch) do node[op][key]=Util.copy(value) end
			state.nodes[node.id]=Schema.node(node,node.id)
		elseif op=="npc" then
			local node=edit(operation.id);assert(node.kind=="npc","Selecione um NPC")
			for key,value in pairs(operation.patch or {}) do node.npc[key]=Util.copy(value) end
			state.nodes[node.id]=Schema.node(node,node.id)
		elseif op=="light" then
			local node=edit(operation.id);assert(node.kind=="light","Selecione uma luz")
			for key,value in pairs(operation.patch or {}) do node.light[key]=value end
			state.nodes[node.id]=Schema.node(node,node.id)
		elseif op=="rename" then edit(operation.id).name=Util.text(operation.name,"",100)
		elseif op=="parent" then
			local node=edit(operation.id);node.parent=Util.text(operation.parent,"",80)
			assert((not node.body.dynamic and node.kind~="npc") or node.parent=="","Corpo dinâmico/NPC deve ficar na raiz")
		elseif op=="delete" then
			assert(state.nodes[operation.id],"Entidade inexistente")
			local removed={[operation.id]=true}
			local again=true
			while again do
				again=false
				for id,node in pairs(state.nodes) do
					if removed[node.parent] and not removed[id] then removed[id]=true;again=true end
				end
			end
			local order={}
			for _,id in ipairs(state.order) do if removed[id] then state.nodes[id]=nil else table.insert(order,id) end end
			state.order=order
		elseif op=="duplicate" then
			local root=assert(state.nodes[operation.id],"Selecione uma entidade")
			local selected, mapping = {[root.id]=true}, {}
			local again=true
			while again do
				again=false
				for id,node in pairs(state.nodes) do if selected[node.parent] and not selected[id] then selected[id]=true;again=true end end
			end
			local oldOrder=table.clone(state.order)
			for _,id in ipairs(oldOrder) do if selected[id] then
				local copy=Util.copy(state.nodes[id]);copy.name ..= " · cópia";copy.parent=""
				mapping[id]=add(copy)
			end end
			for oldId,newId in pairs(mapping) do
				local node=state.nodes[newId]
				node.parent=mapping[state.nodes[oldId].parent] or state.nodes[oldId].parent
				if oldId==root.id then node.transform.position.x+=5;node.transform.position.z+=5 end
			end
		elseif op=="terrain" then
			local node=Procedural.terrain(operation.options or {})
			if operation.position then node.transform={position=operation.position} end
			add(node)
		elseif op=="brush" then Procedural.brush(edit(operation.id),operation.options or {})
		elseif op=="city" then
			local group=add({name="Cidade procedural",kind="group",transform={position=operation.position or {x=0,y=0,z=0}}})
			for _,node in ipairs(Procedural.city(operation.options or {})) do node.parent=group;add(node) end
		elseif op=="environment" then
			local patch=assert(operation.patch,"Ambiente ausente")
			for key,value in pairs(patch) do
				if key=="weather" then assert(value=="clear" or value=="rain" or value=="storm","Clima inválido");state.environment[key]=value
				elseif key=="timeOfDay" then state.environment[key]=Util.number(value,14,0,24)
				elseif key=="gravity" then state.environment[key]=Util.number(value,28,0,196.2)
				elseif key=="fog" then state.environment[key]=Util.number(value,.08,0,1)
				elseif key=="timeScale" then state.environment[key]=Util.number(value,1,0,60)
				else error("Propriedade de ambiente não suportada") end
			end
		elseif op=="settings" then
			local patch=operation.patch or {}
			if patch.targetFrameMs then state.settings.targetFrameMs=Util.number(patch.targetFrameMs,33.3,10,100) end
			if patch.maxRenderParts then state.settings.maxRenderParts=math.floor(Util.number(patch.maxRenderParts,600,32,2000)) end
		elseif op=="graph" then
			local id=Util.text(operation.id,"main",80)
			Graph.compile(operation.graph)
			state.graphs[id]=Util.copy(operation.graph)
			assert(#Util.keys(state.graphs)<=16,"Orçamento de grafos excedido")
		elseif op=="removeGraph" then state.graphs[operation.id]=nil
		elseif op=="runGraph" then
			local graph=assert(state.graphs[operation.id],"Grafo inexistente")
			local ops=Graph.evaluate(state,graph,Util.number(operation.time,0,0,1e9))
			for _,action in ipairs(ops) do apply(action) end
		else error("Comando não implementado: "..tostring(op)) end
	end
	for _,operation in ipairs(operations) do apply(operation) end
	Schema.validate(state,self.maxEntities)
	return created
end

function Project:preview(operations, expectedRevision)
	assert(expectedRevision==self.state.revision,"Projeto mudou; atualize a prévia")
	Util.data(operations,24000)
	assert(#operations>=1 and #operations<=64,"Transação exige 1..64 comandos")
	local nextState=draft(self.state)
	local created=self:_apply(nextState,operations)
	return {state=nextState,created=created,baseRevision=expectedRevision,operationCount=#operations}
end

function Project:execute(operations, expectedRevision)
	local preview=self:preview(operations,expectedRevision)
	table.insert(self.undoStack,self.state)
	if #self.undoStack>self.historyLimit then table.remove(self.undoStack,1) end
	self.redoStack={}
	preview.state.revision=self.state.revision+1
	self.state=Util.freeze(preview.state)
	return {revision=self.state.revision,created=preview.created,operations=preview.operationCount}
end

function Project:undo(expectedRevision)
	assert(expectedRevision==self.state.revision,"Revisão desatualizada")
	assert(#self.undoStack>0,"Nada para desfazer")
	local state=draft(table.remove(self.undoStack))
	state.revision=self.state.revision+1;state.nextId=math.max(state.nextId,self.state.nextId)
	table.insert(self.redoStack,self.state);self.state=Util.freeze(state)
	return self.state.revision
end

function Project:redo(expectedRevision)
	assert(expectedRevision==self.state.revision,"Revisão desatualizada")
	assert(#self.redoStack>0,"Nada para refazer")
	local state=draft(table.remove(self.redoStack))
	state.revision=self.state.revision+1;state.nextId=math.max(state.nextId,self.state.nextId)
	table.insert(self.undoStack,self.state);self.state=Util.freeze(state)
	return self.state.revision
end

function Project:replace(raw, expectedRevision)
	assert(expectedRevision==self.state.revision,"Revisão desatualizada")
	Util.data(raw,600000)
	assert(raw.format==Schema.Format,"Versão de projeto incompatível")
	local nextState=Util.copy(raw)
	for id,node in pairs(nextState.nodes or {}) do nextState.nodes[id]=Schema.node(node,id) end
	for _,graph in pairs(nextState.graphs or {}) do Graph.compile(graph) end
	Schema.validate(nextState,self.maxEntities)
	table.insert(self.undoStack,self.state)
	if #self.undoStack>self.historyLimit then table.remove(self.undoStack,1) end
	nextState.revision=self.state.revision+1;nextState.nextId=math.max(nextState.nextId,self.state.nextId)
	self.redoStack={};self.state=Util.freeze(nextState)
end

function Project.example()
	local self=Project.new("ARKHER · Laboratório de criação")
	self:execute({
		{op="terrain",options={width=12,depth=12,cell=6,seed=42,amplitude=6}},
		{op="add",node={name="Corpo A",kind="box",transform={position={x=-9,y=14,z=0}},body={dynamic=true},surface={material="metal",color={r=.24,g=.75,b=.83}}}},
		{op="add",node={name="Corpo B",kind="sphere",transform={position={x=7,y=18,z=2}},body={dynamic=true},surface={material="stone",color={r=.9,g=.52,b=.28}}}},
		{op="add",node={name="Luz principal",kind="light",transform={position={x=0,y=20,z=0}},surface={color={r=.8,g=.94,b=1}}}},
		{op="city",position={x=72,y=0,z=0},options={blocks=3,seed=137}},
		{op="add",node={name="Explorador A",kind="npc",transform={position={x=-18,y=8,z=12}},npc={seed=7,fov=200}}},
		{op="add",node={name="Explorador B",kind="npc",transform={position={x=12,y=8,z=-12}},npc={seed=19,hunger=.75}}},
		{op="add",node={name="Alimento",kind="box",body={collidable=false},transform={position={x=18,y=8,z=0},size={x=2,y=2,z=2}},surface={material="neon",color={r=.9,g=.72,b=.2}},metadata={food=true,foodAmount=5}}},
	},0)
	self.undoStack={}
	return self
end

return Project
