--!strict
local Editor = require(script.Parent:WaitForChild("Editor"))
local Renderer = require(script.Parent:WaitForChild("Renderer"))
local Camera = require(script.Parent:WaitForChild("Camera"))
local CoreFolder = script.Parent.Parent:WaitForChild("Core")
local Transform = require(CoreFolder:WaitForChild("Transform"))
local Graph = require(CoreFolder:WaitForChild("Graph"))
local Util = require(CoreFolder:WaitForChild("Util"))
local Budget = require(CoreFolder:WaitForChild("Budget"))
local Progress = require(CoreFolder:WaitForChild("Progress"))
local Entry = {}

function Entry.start(package,player)
	local run=game:GetService("RunService")
	local input=game:GetService("UserInputService")
	local lighting=game:GetService("Lighting")
	local http=game:GetService("HttpService")
	local vr=game:GetService("VRService")
	local remotes=package:WaitForChild("Remotes")
	local requestRemote=remotes:WaitForChild("Request")
	local eventRemote=remotes:WaitForChild("Event")
	local currentCamera=workspace.CurrentCamera
	while not currentCamera do workspace:GetPropertyChangedSignal("CurrentCamera"):Wait();currentCamera=workspace.CurrentCamera end
	local state={packet=nil,selected=nil,busy=false,tool="select",destroyed=false,drag=nil,lastDrag=-100,frameMs=33.3,serverMs=0}
	local renderer=Renderer.new(workspace,lighting)
	local ui,controller,budget,handles,arcs
	local connections={}
	local function connect(signal,fn) local c=signal:Connect(fn);table.insert(connections,c);return c end
	local function node() return state.packet and state.packet.state.nodes[state.selected] end
	local function select(id)
		state.selected=id
		if state.packet and id and not state.packet.state.nodes[id] then state.selected=nil end
		ui:select(state.selected)
	end
	local function accept(packet)
		if packet.kind~="snapshot" then return end
		if state.packet and packet.state.revision<state.packet.state.revision then return end
		state.packet=packet
		state.lastAuthorSnapshot=Util.copy(packet)
		if state.selected and not packet.state.nodes[state.selected] then state.selected=nil end
		renderer:setState(packet.state)
		local maximum=math.min(packet.state.settings.maxRenderParts,input.TouchEnabled and 280 or 900)
		budget=Budget.new(maximum,packet.state.settings.targetFrameMs)
		ui:update(packet,state.selected)
	end
	local function request(action,payload,baseRevision)
		if state.busy then ui:status("Há um pedido em andamento; aguarde",true);return end
		state.busy=true;ui:status("Executando: "..action)
		payload=payload or {}
		payload.revision=baseRevision or (state.packet and state.packet.state.revision) or 0
		payload.epoch=state.packet and state.packet.epoch or 0
		task.spawn(function()
			local ok,response=pcall(function() return requestRemote:InvokeServer(action,payload) end)
			state.busy=false
			if state.destroyed then return end
			if not ok or not response.ok then
				if ok and response.snapshot then accept(response.snapshot) elseif state.lastAuthorSnapshot then accept(Util.copy(state.lastAuthorSnapshot)) end
				ui:status(ok and response.error or "Falha de comunicação com a sessão",true);return
			end
			local result=response.result
			if result.kind=="snapshot" then accept(result) elseif result.snapshot then accept(result.snapshot) end
			if result.receipt and result.receipt.created[1] then select(result.receipt.created[1]) end
			if action=="plan" then ui:showPlan(result);ui:status("Prévia pronta. Nenhuma alteração executada.")
			elseif action=="export" then
				local text=http:JSONEncode(result.state)
				if #text>200000 then ui:status("Projeto grande para copiar no editor; use DataStore",true);return end
				ui:dialog("Exportar projeto ARKHER","JSON completo do estado autorado, não do fork de simulação.",text,nil)
			elseif action=="inspectNpc" then
				ui:dialog("NMN / "..result.id,"Estado real do agente no Core: necessidades, memórias, fontes percebidas, causa e trajeto.",http:JSONEncode(result.brain),nil)
			elseif action=="checkpoint" then
				local text=http:JSONEncode(result.checkpoint)
				if #text>200000 then ui:status("Checkpoint excede orçamento de cópia do editor; dados continuam no servidor",true);return end
				ui:dialog("Checkpoint da simulação","Inclui poses, necessidades, memória, decisões e RNG dos NPCs. Guarde o JSON para retomar.",text,nil)
			elseif action=="save" then ui:status("DataStore: revisão "..result.savedRevision.." salva; versão "..result.storageVersion)
			else ui:status("Concluído: "..action.." · revisão "..tostring(state.packet and state.packet.state.revision or 0)) end
		end)
	end
	local function execute(operations,revision) request("execute",{operations=operations},revision) end
	local function add(kind)
		local target=controller and controller.target or Vector3.new(0,0,0)
		execute({{op="add",node={kind=kind,name=kind=="group" and "Grupo" or "Nova entidade",transform={position={x=math.floor(target.X),y=math.max(7,math.floor(target.Y)),z=math.floor(target.Z)}}}}})
	end
	local function focus(id)
		if state.packet and state.packet.state.nodes[id] and controller then
			local p=Transform.world(state.packet.state,id).position
			if math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))>1000000 then ui:status("Entidade requer um adapter de coordenadas maiores",true);return end
			controller:focus(p)
		end
	end
	ui=Editor.new(player:WaitForChild("PlayerGui"),{
		request=request,execute=execute,select=select,add=add,focus=focus,
		inspectNpc=function(id) request("inspectNpc",{id=id}) end,
		progress=function() ui:dialog("Progresso da V1 / evidências","Cobertura não equivale a conclusão. Os alvos de 10K sistemas e 100K funcionalidades permanecem não certificados.",Progress.explanation,nil) end,
		resume=function(text)
			if #text>200000 then ui:status("Checkpoint excede orçamento do editor",true);return end
			local ok,checkpoint=pcall(http.JSONDecode,http,text)
			if not ok then ui:status("JSON de checkpoint inválido",true);return end
			request("resumeSimulation",{checkpoint=checkpoint,confirm=true})
		end,
		stimulus=function(kind)
			local target=controller and controller.target or Vector3.new(0,2,0)
			execute({{op="add",node={name=kind=="food" and "Recurso de alimento" or "Zona de perigo",kind="box",body={collidable=false},
				transform={position={x=target.X,y=math.max(2,target.Y),z=target.Z},size={x=2,y=2,z=2}},
				surface={material="neon",color=kind=="food" and {r=.95,g=.72,b=.22} or {r=.95,g=.22,b=.27}},
				metadata=kind=="food" and {food=true,foodAmount=5} or {hazard=true}}}})
		end,
		tool=function(tool) state.tool=tool end,
		plan=function(prompt,provider) request("plan",{prompt=prompt,provider=provider}) end,
		applyPlan=function(token) request("applyPlan",{token=token,confirm=true}) end,
		export=function() request("export") end,
		import=function(text)
			if #text>200000 then ui:status("Importação pelo editor limitada a 200 KB por operação",true);return end
			local ok,decoded=pcall(http.JSONDecode,http,text)
			if not ok then ui:status("JSON inválido; projeto atual preservado",true);return end
			request("replace",{state=decoded})
		end,
		animate=function(id)
			local n=node();if not n then return end
			local operations={{op="body",id=id,patch={dynamic=false}}}
			if n.kind=="npc" then table.insert(operations,{op="npc",id=id,patch={enabled=false}}) end
			table.insert(operations,{op="graph",id="motion_"..id,graph=Graph.oscillator(id,n.transform.position)});execute(operations)
		end,
		graph=function(id)
			local n=node();if not n then return end
			local graphId="motion_"..id
			local graph=state.packet.state.graphs[graphId] or Graph.oscillator(id,n.transform.position)
			local revision=state.packet.state.revision
			ui:dialog("Programação visual / grafo JSON","Operadores: number, time, position, add, multiply, sine, vector, setPosition. Dependências e ciclos são validados.",http:JSONEncode(graph),function(text)
				if #text>50000 then ui:status("Grafo excede orçamento",true);return end
				local ok,data=pcall(http.JSONDecode,http,text)
				if not ok then ui:status("JSON inválido",true);return end
				local compiled,message=pcall(Graph.compile,data)
				if not compiled then ui:status(tostring(message),true);return end
				execute({{op="graph",id=graphId,graph=data}},revision)
			end)
		end,
	})
	if not vr.VREnabled then
		controller=Camera.new(currentCamera,input,ui.viewport,function(x,y)
			if state.busy or state.drag or ui.modal or os.clock()-state.lastDrag<.12 then return end
			local id,hit=renderer:pick(currentCamera,x,y)
			if state.tool=="brush" and id and state.packet and state.packet.mode=="edit" then
				local n=state.packet.state.nodes[id]
				if n and n.kind=="terrain" then
					local pose=Transform.world(state.packet.state,id);local r,p=pose.rotation,pose.position
					local dx,dy,dz=hit.X-p.x,hit.Y-p.y,hit.Z-p.z
					local options=table.clone(ui.brush)
					options.x=(r[1]*dx+r[4]*dy+r[7]*dz)/pose.scale
					options.z=(r[3]*dx+r[6]*dy+r[9]*dz)/pose.scale
					execute({{op="brush",id=id,options=options}});return
				end
			end
			select(id)
		end)
	else ui:status("VR não validado: câmera orbital desativada",true) end

	handles=Instance.new("Handles");handles.Name="ARKHER_TRANSFORM";handles.Color3=Color3.fromRGB(104,239,218);handles.Faces=Faces.new(Enum.NormalId.Right,Enum.NormalId.Left,Enum.NormalId.Top,Enum.NormalId.Bottom,Enum.NormalId.Front,Enum.NormalId.Back);handles.Parent=player:WaitForChild("PlayerGui")
	arcs=Instance.new("ArcHandles");arcs.Name="ARKHER_ROTATION";arcs.Color3=Color3.fromRGB(104,239,218);arcs.Axes=Axes.new(Enum.Axis.X,Enum.Axis.Y,Enum.Axis.Z);arcs.Parent=player:WaitForChild("PlayerGui")
	local function startDrag()
		local n=node()
		if not n or not state.packet or state.packet.mode~="edit" or state.busy then return end
		state.drag={id=n.id,transform=Util.copy(n.transform),revision=state.packet.state.revision}
		if controller then controller.blocked=true end
	end
	local function finishDrag()
		local drag=state.drag
		if not drag then return end
		local n=state.packet.state.nodes[drag.id]
		state.drag=nil;state.lastDrag=os.clock();if controller then controller.blocked=false end
		if n then execute({{op="transform",id=n.id,position=n.transform.position,rotation=n.transform.rotation,size=n.transform.size,scale=n.transform.scale}},drag.revision) end
	end
	connect(handles.MouseButton1Down,startDrag);connect(arcs.MouseButton1Down,startDrag)
	connect(handles.MouseButton1Up,finishDrag);connect(arcs.MouseButton1Up,finishDrag)
	local normals={
		[Enum.NormalId.Right]={axis="x",sign=1},[Enum.NormalId.Left]={axis="x",sign=-1},
		[Enum.NormalId.Top]={axis="y",sign=1},[Enum.NormalId.Bottom]={axis="y",sign=-1},
		[Enum.NormalId.Back]={axis="z",sign=1},[Enum.NormalId.Front]={axis="z",sign=-1},
	}
	connect(handles.MouseDrag,function(face,distance)
		local drag=state.drag;if not drag then return end
		local n=state.packet.state.nodes[drag.id];if not n then return end
		local normal=normals[face];if not normal then return end
		n.transform=Util.copy(drag.transform)
		if state.tool=="move" then
			local pose=Transform.world(state.packet.state,n.id)
			local axis={x=0,y=0,z=0};axis[normal.axis]=normal.sign*distance
			local worldDelta=Transform.rotate(pose.rotation,axis)
			local delta=worldDelta
			if n.parent~="" then
				local parent=Transform.world(state.packet.state,n.parent);local r=parent.rotation
				delta={x=(r[1]*worldDelta.x+r[4]*worldDelta.y+r[7]*worldDelta.z)/parent.scale,y=(r[2]*worldDelta.x+r[5]*worldDelta.y+r[8]*worldDelta.z)/parent.scale,z=(r[3]*worldDelta.x+r[6]*worldDelta.y+r[9]*worldDelta.z)/parent.scale}
			end
			for _,key in ipairs({"x","y","z"}) do n.transform.position[key]+=delta[key] end
		elseif n.kind=="group" or n.kind=="terrain" then n.transform.scale=math.clamp(drag.transform.scale*(1+distance/20),.01,100)
		else
			local pose=Transform.world(state.packet.state,n.id)
			n.transform.size[normal.axis]=math.clamp(drag.transform.size[normal.axis]+2*distance/pose.scale,.1,1024)
		end
		renderer:previewTransform(n.id,n.transform)
	end)
	connect(arcs.MouseDrag,function(axis,angle)
		local drag=state.drag;if not drag then return end
		local n=state.packet.state.nodes[drag.id];if not n then return end
		local key=axis==Enum.Axis.X and "x" or axis==Enum.Axis.Y and "y" or "z"
		n.transform.rotation=table.clone(drag.transform.rotation);n.transform.rotation[key]+=math.deg(angle);renderer:previewTransform(n.id,n.transform)
	end)
	connect(input.InputEnded,function(event)
		if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then finishDrag() end
	end)
	connect(input.InputBegan,function(event,processed)
		if processed or input:GetFocusedTextBox() or ui.modal then return end
		local control=input:IsKeyDown(Enum.KeyCode.LeftControl) or input:IsKeyDown(Enum.KeyCode.RightControl)
		if control and event.KeyCode==Enum.KeyCode.Z then request("undo")
		elseif control and event.KeyCode==Enum.KeyCode.Y then request("redo")
		elseif event.KeyCode==Enum.KeyCode.F and state.selected then focus(state.selected)
		elseif event.KeyCode==Enum.KeyCode.Delete and state.selected then execute({{op="delete",id=state.selected}}) end
	end)
	connect(eventRemote.OnClientEvent,function(packet)
		if state.destroyed then return end
		if packet.kind=="snapshot" then
			if state.drag then state.drag=nil;if controller then controller.blocked=false end end
			accept(packet)
		elseif packet.kind=="frame" and state.packet and state.packet.mode=="play" and packet.epoch==state.packet.epoch then
			renderer:applyFrame(packet);state.serverMs=packet.cpuMs or 0
			if state.selected then ui:agentStatus(renderer.agentStates[state.selected]) end
		end
	end)
	local statElapsed=0
	connect(run.RenderStepped,function(dt)
		if state.destroyed then return end
		if controller then controller:step(dt) end
		if state.packet and budget then
			state.frameMs+=(dt*1000-state.frameMs)*.08
			local maximum=budget:sample(dt*1000,dt)
			renderer:render(currentCamera.CFrame.Position,maximum,state.selected,dt)
			local adornee
			for _,part in pairs(renderer.parts) do if part:GetAttribute("ArkherNodeId")==state.selected then adornee=part;break end end
			local n=node()
			if n and (n.kind=="group" or n.kind=="terrain") then
				if not renderer.pivot then
					local pivot=Instance.new("Part");pivot.Name="ARKHER_EDITOR_PIVOT";pivot.Anchored=true;pivot.CanCollide=false;pivot.CanTouch=false;pivot.CanQuery=false;pivot.Transparency=1;pivot.Size=Vector3.new(4,4,4);pivot.Parent=renderer.root;renderer.pivot=pivot
				end
				local pose=Transform.world(state.packet.state,n.id)
				if math.max(math.abs(pose.position.x),math.abs(pose.position.y),math.abs(pose.position.z))<=1000000 then
					renderer.pivot.CFrame=CFrame.new(pose.position.x,pose.position.y,pose.position.z,table.unpack(pose.rotation));adornee=renderer.pivot
				else adornee=nil end
			end
			local active=state.packet.mode=="edit" and not ui.modal and not vr.VREnabled and not (ui.mobile and ui.mobilePanel)
			handles.Adornee=adornee;arcs.Adornee=adornee
			handles.Visible=active and (state.tool=="move" or state.tool=="scale") and adornee~=nil
			handles.Style=state.tool=="scale" and Enum.HandlesStyle.Resize or Enum.HandlesStyle.Movement
			arcs.Visible=active and state.tool=="rotate" and adornee~=nil
			statElapsed+=dt
			if statElapsed>.3 then
				statElapsed=0
				ui:stats(string.format("%.1f ms · %d/%d partes · CPU sim %.2f",state.frameMs,renderer.metrics.rendered,renderer.metrics.available,state.serverMs)..(renderer.metrics.terrainError>.01 and string.format(" · Δh≤%.1f",renderer.metrics.terrainError) or ""))
				if renderer.metrics.unsupported>0 then ui:status(renderer.metrics.unsupported.." representações exigem outro adapter; dados preservados",true) end
			end
		end
	end)
	request("state")
	return function()
		state.destroyed=true
		for _,connection in ipairs(connections) do connection:Disconnect() end
		if controller then controller:destroy() end
		handles:Destroy();arcs:Destroy();renderer:destroy();ui:destroy()
	end
end
return Entry
