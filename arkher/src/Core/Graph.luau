--!strict
-- A small, executable visual dataflow language, never loadstring or arbitrary Lua.
local Util = require(script.Parent:WaitForChild("Util"))
local Graph = {}
local arity = {number=0,time=0,position=0,add=2,multiply=2,sine=1,vector=3,setPosition=1}

function Graph.compile(graph)
	Util.data(graph,8000)
	assert(type(graph.nodes)=="table" and #graph.nodes>=1 and #graph.nodes<=128,"Grafo deve ter 1..128 nós nesta execução")
	local byId, visiting, visited, order = {}, {}, {}, {}
	for _, node in ipairs(graph.nodes) do
		assert(type(node.id)=="string" and #node.id>0 and #node.id<=64 and not byId[node.id],"ID de nó duplicado/inválido")
		assert(arity[node.op]~=nil,"Operador não implementado: "..tostring(node.op))
		assert(type(node.inputs or {})=="table" and #(node.inputs or {})==arity[node.op],"Aridade inválida")
		if node.op=="number" then Util.number(node.value,0,-1000000,1000000) end
		byId[node.id] = node
	end
	local function visit(id)
		assert(byId[id],"Dependência de grafo inexistente")
		assert(not visiting[id],"Ciclo no grafo")
		if visited[id] then return end
		visiting[id] = true
		for _, input in ipairs(byId[id].inputs or {}) do visit(input) end
		visiting[id], visited[id] = nil, true
		table.insert(order, byId[id])
	end
	for _, node in ipairs(graph.nodes) do visit(node.id) end
	return order
end

function Graph.evaluate(state, graph, time, compiled)
	local order, values, operations = compiled or Graph.compile(graph), {}, {}
	for _, node in ipairs(order) do
		local inputs = node.inputs or {}
		local a, b = values[inputs[1]], values[inputs[2]]
		if node.op=="number" then values[node.id]=node.value or 0
		elseif node.op=="time" then values[node.id]=time
		elseif node.op=="position" then values[node.id]=Util.copy(assert(state.nodes[node.entity],"Entidade do grafo inexistente").transform.position)
		elseif node.op=="add" then values[node.id]=Util.number(a,0,-1e12,1e12)+Util.number(b,0,-1e12,1e12)
		elseif node.op=="multiply" then values[node.id]=Util.number(a,0,-1e12,1e12)*Util.number(b,0,-1e12,1e12)
		elseif node.op=="sine" then values[node.id]=math.sin(Util.number(a,0,-1e12,1e12))
		elseif node.op=="vector" then values[node.id]={x=Util.number(a,0,-1e6,1e6),y=Util.number(b,0,-1e6,1e6),z=Util.number(values[inputs[3]],0,-1e6,1e6)}
		elseif node.op=="setPosition" then
			assert(state.nodes[node.entity],"Destino do grafo inexistente")
			local position = Util.vector(a,{x=0,y=0,z=0},-1e6,1e6)
			table.insert(operations,{op="transform",id=node.entity,position=position})
			values[node.id]=position
		end
	end
	return operations, values
end

function Graph.oscillator(entity, position)
	return {name="Oscilação vertical",enabled=true,nodes={
		{id="clock",op="time"},{id="wave",op="sine",inputs={"clock"}},
		{id="gain",op="number",value=3},{id="offset",op="multiply",inputs={"wave","gain"}},
		{id="base",op="number",value=position.y},{id="height",op="add",inputs={"base","offset"}},
		{id="x",op="number",value=position.x},{id="z",op="number",value=position.z},
		{id="point",op="vector",inputs={"x","height","z"}},
		{id="move",op="setPosition",inputs={"point"},entity=entity},
	}}
end

return Graph
