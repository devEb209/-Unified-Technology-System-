--!strict
local Util = require(script.Parent:WaitForChild("Util"))
local Schema = {}
Schema.Format = "arkher.project/1"
Schema.Kinds = {box=true,sphere=true,cylinder=true,group=true,light=true,terrain=true,npc=true}
Schema.Materials = {stone=true,soil=true,grass=true,sand=true,wood=true,metal=true,glass=true,water=true,neon=true,asphalt=true}
local zero, one = {x=0,y=0,z=0}, {x=1,y=1,z=1}

function Schema.node(raw, id)
	assert(type(raw) == "table", "Entidade inválida")
	local kind = Util.text(raw.kind, "box", 24)
	assert(Schema.Kinds[kind], "Tipo sem implementação: " .. kind)
	local t, surface, body = raw.transform or {}, raw.surface or {}, raw.body or {}
	assert(type(t)=="table" and type(surface)=="table" and type(body)=="table","Componentes inválidos")
	assert(body.dynamic==nil or type(body.dynamic)=="boolean","dynamic exige booleano")
	assert(body.collidable==nil or type(body.collidable)=="boolean","collidable exige booleano")
	assert(raw.metadata==nil or type(raw.metadata)=="table","Metadados devem ser dados estruturados")
	local color = surface.color or {r=0.48,g=0.68,b=0.72}
	assert(type(color)=="table","Cor RGB obrigatória")
	local material = Util.text(surface.material, "stone", 24)
	assert(Schema.Materials[material], "Material sem adapter")
	local node = {
		id=Util.text(id or raw.id, "", 80), name=Util.text(raw.name, kind, 100), kind=kind,
		parent=Util.text(raw.parent, "", 80),
		transform={position=Util.vector(t.position, zero, -1000000, 1000000), rotation=Util.vector(t.rotation, zero, -360000,360000), size=Util.vector(t.size,kind=="npc" and {x=2,y=4,z=2} or {x=4,y=4,z=4},0.1,1024), scale=Util.number(t.scale,1,0.01,100)},
		surface={material=material,color={r=Util.number(color.r,0.5,0,1),g=Util.number(color.g,0.7,0,1),b=Util.number(color.b,0.75,0,1)},transparency=Util.number(surface.transparency,0,0,1),reflectance=Util.number(surface.reflectance,0,0,1)},
		body={dynamic=body.dynamic == true,collidable=body.collidable ~= false,velocity=Util.vector(body.velocity,zero,-1000,1000),mass=Util.number(body.mass,1,0.01,100000),restitution=Util.number(body.restitution,0.12,0,1)},
		metadata=Util.copy(raw.metadata or {}),
	}
	assert(node.id ~= "", "ID vazio")
	if kind == "group" or kind == "light" or kind == "terrain" or kind == "npc" then node.body.dynamic = false end
	assert(not node.body.dynamic or node.parent == "", "Nesta implementação, corpos dinâmicos devem estar na raiz")
	if node.metadata.food==true then
		node.metadata.foodAmount=Util.number(node.metadata.foodAmount,5,0,1000)
		assert(node.metadata.foodAmount%1==0,"Quantidade de alimento deve ser inteira")
	end
	if node.metadata.noiseRadius~=nil then node.metadata.noiseRadius=Util.number(node.metadata.noiseRadius,0,0,120) end
	if kind == "npc" then
		assert(node.parent=="","NPCs desta implementação devem estar na raiz")
		assert(node.transform.size.x*node.transform.scale<=8 and node.transform.size.z*node.transform.scale<=8 and node.transform.size.y*node.transform.scale<=12 and node.transform.size.y*node.transform.scale>=1,"Dimensões fora do envelope atual de navegação")
		local npc=raw.npc or {}
		local behavior=Util.text(npc.behavior,"wander",24)
		assert(behavior=="wander" or behavior=="goTo","Comportamento não implementado")
		assert(npc.enabled==nil or type(npc.enabled)=="boolean","enabled exige booleano")
		node.npc={enabled=npc.enabled~=false,behavior=behavior,speed=Util.number(npc.speed,5,.5,12),
			sight=Util.number(npc.sight,32,4,80),hearing=Util.number(npc.hearing,40,0,80),fov=Util.number(npc.fov,140,30,360),
			bravery=Util.number(npc.bravery,.5,0,1),hunger=Util.number(npc.hunger,.15,0,1),energy=Util.number(npc.energy,1,0,1),
			maxStep=Util.number(npc.maxStep,3,0,8),roamRadius=Util.number(npc.roamRadius,18,4,40),
			seed=math.floor(Util.number(npc.seed,42,1,2147483646)),target=Util.vector(npc.target,node.transform.position,-1e6,1e6)}
	end
	if kind == "light" then
		local light = raw.light or {}
		node.light = {intensity=Util.number(light.intensity,3,0,20),range=Util.number(light.range,32,1,60)}
	end
	if kind == "terrain" then
		local terrain = assert(raw.terrain, "Dados de terreno ausentes")
		local width, depth = Util.number(terrain.width,12,2,32), Util.number(terrain.depth,12,2,32)
		assert(width % 1 == 0 and depth % 1 == 0 and #terrain.heights == width*depth, "Dimensões de heightfield inválidas")
		local heights = {}
		for i, height in ipairs(terrain.heights) do heights[i] = Util.number(height,0,-15,128) end
		node.terrain = {width=width,depth=depth,cell=Util.number(terrain.cell,6,1,32),heights=heights,base=-16,seed=terrain.seed or 1}
	end
	return node
end

function Schema.validate(state, maxEntities)
	Util.data(state,600000)
	assert(state.format == Schema.Format, "Formato/versão de projeto não suportado")
	Util.text(state.name,"",100)
	assert(type(state.nodes)=="table" and type(state.order)=="table", "Scene graph ausente")
	assert(#state.order <= (maxEntities or 2000), "Projeto excede orçamento de entidades desta sessão")
	assert(type(state.nextId)=="number" and state.nextId%1==0 and state.nextId>=1 and state.nextId<=999999999, "Sequência de IDs inválida")
	local listed, count = {}, 0
	for _, id in ipairs(state.order) do
		assert(not listed[id] and state.nodes[id] and state.nodes[id].id==id, "Identidade/ordem inconsistente")
		listed[id] = true
		local node = state.nodes[id]
		assert(Schema.Kinds[node.kind], "Tipo desconhecido")
		assert(node.parent=="" or state.nodes[node.parent], "Pai inexistente")
		local visited, parent, depth = {[id]=true}, node.parent, 0
		while parent ~= "" do
			depth += 1
			assert(depth<=48 and not visited[parent], "Ciclo ou profundidade excessiva na hierarquia")
			visited[parent] = true
			parent = state.nodes[parent].parent
		end
	end
	for id in pairs(state.nodes) do count += 1; assert(listed[id], "Entidade fora da ordem canônica") end
	assert(count==#state.order, "Inventário inconsistente")
	assert(type(state.environment)=="table", "Ambiente ausente")
	Util.number(state.environment.timeOfDay,12,0,24)
	Util.number(state.environment.gravity,28,0,196.2)
	assert(type(state.graphs)=="table" and type(state.settings)=="table", "Configuração ausente")
	Util.number(state.environment.fog,.08,0,1)
	Util.number(state.environment.timeScale,1,0,60)
	assert(state.environment.weather=="clear" or state.environment.weather=="rain" or state.environment.weather=="storm","Clima inválido")
	Util.number(state.settings.targetFrameMs,33.3,10,100)
	Util.number(state.settings.maxRenderParts,600,32,2000)
	return true
end

function Schema.empty(name)
	return {format=Schema.Format,name=name or "Meu projeto ARKHER",revision=0,nextId=1,nodes={},order={},graphs={},
		environment={timeOfDay=14,gravity=28,fog=0.08,weather="clear",timeScale=1},
		settings={targetFrameMs=33.3,maxRenderParts=600}}
end

return Schema
