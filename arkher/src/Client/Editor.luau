--!strict
-- Native ARKHER experience editor. Widgets only dispatch commands; Core owns state/history.
local Editor = {}
Editor.__index = Editor
local colors={bg=Color3.fromRGB(10,15,24),panel=Color3.fromRGB(16,23,35),field=Color3.fromRGB(25,35,49),line=Color3.fromRGB(43,59,76),text=Color3.fromRGB(224,233,242),muted=Color3.fromRGB(139,157,177),accent=Color3.fromRGB(104,239,218),danger=Color3.fromRGB(255,134,142)}
local function make(class,properties,parent)
	local instance=Instance.new(class)
	for key,value in pairs(properties) do instance[key]=value end
	instance.Parent=parent
	return instance
end
local function corner(parent,radius) make("UICorner",{CornerRadius=UDim.new(0,radius or 6)},parent) end
local function label(parent,text,size)
	return make("TextLabel",{BackgroundTransparency=1,Text=text,TextColor3=colors.text,Font=Enum.Font.Gotham,TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,24),TextTruncate=Enum.TextTruncate.AtEnd},parent)
end
local function button(parent,text,fn,width)
	local b=make("TextButton",{Text=text,TextColor3=colors.text,Font=Enum.Font.GothamMedium,TextSize=12,BackgroundColor3=colors.field,BorderSizePixel=0,Size=UDim2.fromOffset(width or 88,32),AutoButtonColor=true},parent)
	corner(b,5);b.Activated:Connect(fn);return b
end
local function field(parent,placeholder,text)
	local box=make("TextBox",{Text=text or "",PlaceholderText=placeholder,PlaceholderColor3=colors.muted,TextColor3=colors.text,Font=Enum.Font.Code,TextSize=13,BackgroundColor3=colors.field,BorderSizePixel=0,ClearTextOnFocus=false,Size=UDim2.new(1,0,0,32),TextXAlignment=Enum.TextXAlignment.Left},parent)
	corner(box,5);make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},box)
	return box
end
local function horizontal(parent,padding)
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,padding or 5),VerticalAlignment=Enum.VerticalAlignment.Center},parent)
end

function Editor.new(playerGui, callbacks)
	local self=setmetatable({callbacks=callbacks,connections={},treeButtons={},collapsed={},fields={},selected=nil,mode="edit",tool="select",provider="local",brush={mode="raise",radius=12,strength=2}},Editor)
	self.gui=make("ScreenGui",{Name="ARKHER_STUDIOS",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
	self.root=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},self.gui)
	self.header=make("Frame",{BackgroundColor3=colors.bg,BorderSizePixel=0,Size=UDim2.new(1,0,0,48)},self.root)
	local brand=label(self.header,"ARKHER  /  STUDIOS",19);brand.Font=Enum.Font.GothamBold;brand.TextColor3=colors.accent;brand.Position=UDim2.fromOffset(16,12);brand.Size=UDim2.fromOffset(250,25)
	self.badge=label(self.header,"G1  ·  V1 EM DESENVOLVIMENTO",11);self.badge.TextColor3=colors.muted;self.badge.TextXAlignment=Enum.TextXAlignment.Right;self.badge.AnchorPoint=Vector2.new(1,0);self.badge.Position=UDim2.new(1,-14,0,14);self.badge.Size=UDim2.fromOffset(310,22)
	self.toolbar=make("ScrollingFrame",{BackgroundColor3=colors.panel,BorderSizePixel=0,Position=UDim2.fromOffset(0,48),Size=UDim2.new(1,0,0,43),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=2},self.root)
	make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},self.toolbar);horizontal(self.toolbar,5)
	button(self.toolbar,"Novo",function() callbacks.request("new") end,58)
	button(self.toolbar,"Salvar",function() callbacks.request("save") end,65)
	button(self.toolbar,"Carregar",function() callbacks.request("load") end,78)
	button(self.toolbar,"Exportar",function() callbacks.export() end,76)
	button(self.toolbar,"Checkpoint",function() callbacks.request("checkpoint") end,95)
	button(self.toolbar,"Retomar",function() self:dialog("Retomar checkpoint","O checkpoint vira o novo estado base. Parar retorna a essas poses; Undo preserva o projeto anterior.","",function(text) callbacks.resume(text) end) end,80)
	button(self.toolbar,"Importar",function() self:dialog("Importar projeto","Cole um projeto arkher.project/1 completo. A importação é validada e pode ser desfeita.","",function(text) callbacks.import(text) end) end,78)
	for _,entry in ipairs({{"select","Selecionar"},{"move","Mover"},{"rotate","Girar"},{"scale","Escalar"}}) do
		button(self.toolbar,entry[2],function() self.tool=entry[1];self.mobilePanel=nil;self:layout();callbacks.tool(entry[1]);self:status("Ferramenta: "..entry[2]) end,entry[1]=="select" and 86 or 66)
	end
	self.undoButton=button(self.toolbar,"Desfazer",function() callbacks.request("undo") end,78)
	self.redoButton=button(self.toolbar,"Refazer",function() callbacks.request("redo") end,74)
	self.playButton=button(self.toolbar,"Simular",function() callbacks.request(self.mode=="edit" and "play" or "stop") end,82)
	self.playButton.BackgroundColor3=Color3.fromRGB(32,84,76)
	button(self.toolbar,"Hierarquia",function() self.mobilePanel=self.mobilePanel=="left" and nil or "left";self:layout() end,88)
	button(self.toolbar,"Inspector",function() self.mobilePanel=self.mobilePanel=="right" and nil or "right";self:layout() end,86)
	button(self.toolbar,"Progresso",function() callbacks.progress() end,86)
	button(self.toolbar,"Ajuda",function() self:dialog("ARKHER / controles", "Editor da experiência, não plugin do Studio.",
		"Câmera: botão direito arrasta para orbitar; botão do meio move; roda aproxima. WASD move quando o cursor está no viewport.\n\nTouch: arraste para orbitar, dois dedos para zoom; toque curto seleciona.\n\nGamepad: analógicos movem/orbitam; R2/L2 aproximam; A seleciona o centro.\n\nEdição: selecione no viewport ou hierarquia. Use gizmos ou números no inspector. Ctrl+Z/Y desfaz/refaz. F enquadra. Delete remove com undo.\n\nSimular executa um fork; Parar restaura o estado autorado.\n\nIA local = regras explícitas, não LLM. Provider externo só é usado se configurado no servidor e selecionado aqui. Planos exigem prévia + confirmação.\n\nDataStore: desativado por padrão; Exportar JSON funciona sem serviço externo.\n\nEsta implementação ainda não cumpre o escopo integral de 10K/100K da V1.",nil) end,58)
	self.viewport=make("Frame",{Name="ViewportInput",BackgroundTransparency=1,Active=false},self.root)
	self.viewHint=label(self.viewport,"UES / cena autoritativa  ·  Roblox / materialização",11);self.viewHint.Position=UDim2.fromOffset(14,10);self.viewHint.TextColor3=colors.muted;self.viewHint.TextStrokeTransparency=.45
	self.left=make("Frame",{BackgroundColor3=colors.panel,BackgroundTransparency=.04,BorderSizePixel=0,Active=true},self.root)
	local title=label(self.left,"SCENE GRAPH",12);title.Font=Enum.Font.GothamBold;title.Position=UDim2.fromOffset(12,8)
	self.search=field(self.left,"Buscar entidade...","");self.search.Position=UDim2.fromOffset(8,36);self.search.Size=UDim2.new(1,-16,0,30)
	self.tree=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,73),Size=UDim2.new(1,0,1,-117),CanvasSize=UDim2.new(),ScrollBarThickness=3},self.left)
	self.tree:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:drawTree() end)
	self.search:GetPropertyChangedSignal("Text"):Connect(function() self:refreshTree() end)
	local create=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,8,1,-40),Size=UDim2.new(1,-16,0,32)},self.left);horizontal(create,4)
	button(create,"+ Corpo",function() callbacks.add("box") end,86)
	button(create,"+ Grupo",function() callbacks.add("group") end,86)
	self.right=make("Frame",{BackgroundColor3=colors.panel,BackgroundTransparency=.04,BorderSizePixel=0,Active=true},self.root)
	local inspectorTitle=label(self.right,"INSPECTOR",12);inspectorTitle.Font=Enum.Font.GothamBold;inspectorTitle.Position=UDim2.fromOffset(12,8)
	self.closeInspector=button(self.right,"X",function() self.mobilePanel=nil;self:layout() end,26);self.closeInspector.Position=UDim2.new(1,-33,0,5);self.closeInspector.Size=UDim2.fromOffset(26,26)
	self.closeTree=button(self.left,"X",function() self.mobilePanel=nil;self:layout() end,26);self.closeTree.Position=UDim2.new(1,-33,0,5);self.closeTree.Size=UDim2.fromOffset(26,26)
	self.inspector=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(10,40),Size=UDim2.new(1,-20,1,-48),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3},self.right)
	self.dock=make("Frame",{BackgroundColor3=colors.bg,BorderSizePixel=0},self.root)
	local aiTitle=label(self.dock,"SINGULARITY  /  planos verificáveis",12);aiTitle.Font=Enum.Font.GothamBold;aiTitle.Position=UDim2.fromOffset(12,7)
	self.providerButton=button(self.dock,"Local · regras",function()
		if self.provider=="local" then
			if not self.providerConfigured then self:status("Provider externo não configurado no servidor",true);return end
			self.provider="remote";self:status("Modo externo: pedido e resumo da cena serão enviados ao provider configurado")
		else self.provider="local" end
		self.providerButton.Text=self.provider=="local" and "Local · regras" or "Provider externo"
	end,135);self.providerButton.AnchorPoint=Vector2.new(1,0);self.providerButton.Position=UDim2.new(1,-10,0,3);self.providerButton.Size=UDim2.fromOffset(135,26)
	self.prompt=field(self.dock,"Ex.: crie uma cidade 3x3 seed 42","");self.prompt.Position=UDim2.fromOffset(10,39);self.prompt.Size=UDim2.new(1,-110,0,34)
	self.planButton=button(self.dock,"Planejar",function() callbacks.plan(self.prompt.Text,self.provider) end,84);self.planButton.AnchorPoint=Vector2.new(1,0);self.planButton.Position=UDim2.new(1,-10,0,40)
	self.quick=make("ScrollingFrame",{BackgroundTransparency=1,Position=UDim2.fromOffset(10,83),Size=UDim2.new(1,-20,0,31),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=1,BorderSizePixel=0},self.dock);horizontal(self.quick,5)
	button(self.quick,"Terreno",function() callbacks.execute({{op="terrain",options={width=12,seed=42}}}) end,80)
	button(self.quick,"Cidade",function() callbacks.execute({{op="city",options={blocks=3,seed=42}}}) end,75)
	button(self.quick,"Esfera",function() callbacks.add("sphere") end,72)
	button(self.quick,"Luz",function() callbacks.add("light") end,58)
	button(self.quick,"NPC",function() callbacks.add("npc") end,62)
	button(self.quick,"Alimento",function() callbacks.stimulus("food") end,80)
	button(self.quick,"Perigo",function() callbacks.stimulus("hazard") end,72)
	button(self.quick,"Noite",function() callbacks.execute({{op="environment",patch={timeOfDay=22}}}) end,67)
	button(self.quick,"Dia",function() callbacks.execute({{op="environment",patch={timeOfDay=14}}}) end,55)
	self.footer=make("Frame",{BackgroundColor3=colors.field,BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,27)},self.root)
	self.statusLabel=label(self.footer,"Conectando à sessão...",11);self.statusLabel.Position=UDim2.fromOffset(10,2);self.statusLabel.Size=UDim2.new(.65,-12,1,-4)
	self.statsLabel=label(self.footer,"",10);self.statsLabel.TextXAlignment=Enum.TextXAlignment.Right;self.statsLabel.Position=UDim2.new(.65,0,0,2);self.statsLabel.Size=UDim2.new(.35,-10,1,-4)
	self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	self:layout();self:inspectorFor(nil)
	return self
end

function Editor:layout()
	local size=self.root.AbsoluteSize
	self.mobile=size.X<850
	local left=if self.mobile then 0 else 220
	local right=if self.mobile then 0 else 258
	local dockHeight=if size.Y<520 then 116 else 127
	self.viewport.Position=UDim2.fromOffset(left,91)
	self.viewport.Size=UDim2.new(1,-left-right,1,-91-dockHeight-27)
	self.left.Position=UDim2.fromOffset(0,91);self.left.Size=UDim2.new(0,220,1,-91-27)
	self.right.AnchorPoint=Vector2.new(1,0);self.right.Position=UDim2.new(1,0,0,91);self.right.Size=UDim2.new(0,258,1,-91-27)
	self.left.Visible=not self.mobile or self.mobilePanel=="left"
	self.right.Visible=not self.mobile or self.mobilePanel=="right"
	self.left.ZIndex=if self.mobile then 8 else 2;self.right.ZIndex=self.left.ZIndex
	self.dock.Position=UDim2.new(0,left,1,-27-dockHeight);self.dock.Size=UDim2.new(1,-left-right,0,dockHeight)
	self.badge.Visible=size.X>650
	if self.closeInspector then self.closeInspector.Visible=self.mobile;self.closeTree.Visible=self.mobile end
	self:drawTree()
end

function Editor:status(message,isError)
	self.statusLabel.Text=tostring(message)
	self.statusLabel.TextColor3=if isError then colors.danger else colors.text
end
function Editor:stats(text) self.statsLabel.Text=text end

function Editor:refreshTree()
	if not self.state then return end
	local children={}
	for _,id in ipairs(self.state.order) do local node=self.state.nodes[id];children[node.parent]=children[node.parent] or {};table.insert(children[node.parent],id) end
	local entries={};local query=string.lower(self.search.Text)
	local function visit(id,depth)
		local node=self.state.nodes[id]
		if query=="" or string.find(string.lower(node.name.." "..id),query,1,true) then table.insert(entries,{id=id,depth=depth,name=node.name,kind=node.kind,children=children[id]~=nil}) end
		if not self.collapsed[id] or query~="" then for _,child in ipairs(children[id] or {}) do visit(child,depth+1) end end
	end
	for _,id in ipairs(children[""] or {}) do visit(id,0) end
	self.treeEntries=entries;self.tree.CanvasSize=UDim2.fromOffset(0,#entries*30);self:drawTree()
end

function Editor:drawTree()
	if not self.treeEntries then return end
	local first=math.floor(self.tree.CanvasPosition.Y/30)+1
	local count=math.min(64,math.ceil(self.tree.AbsoluteSize.Y/30)+2)
	for slot=1,count do
		local entry=self.treeEntries[first+slot-1]
		local row=self.treeButtons[slot]
		if not row then
			row=button(self.tree,"",function()
				local id=self.treeButtons[slot]:GetAttribute("EntityId");if id then self.callbacks.select(id) end
			end);row.Size=UDim2.new(1,-6,0,29);row.TextXAlignment=Enum.TextXAlignment.Left;row.TextTruncate=Enum.TextTruncate.AtEnd
			self.treeButtons[slot]=row
		end
		row.Visible=entry~=nil
		if entry then
			row:SetAttribute("EntityId",entry.id);row.Position=UDim2.fromOffset(3,(first+slot-2)*30)
			row.Text=string.rep("  ",math.min(entry.depth,8))..(entry.children and "+ " or "  ")..entry.name
			row.BackgroundColor3=if entry.id==self.selected then Color3.fromRGB(34,77,79) else colors.panel
			row.TextColor3=if entry.id==self.selected then colors.accent else colors.text
		end
	end
	for slot=count+1,#self.treeButtons do self.treeButtons[slot].Visible=false end
end

function Editor:inspectorFor(id)
	self.rebuilding=true
	for _,child in ipairs(self.inspector:GetChildren()) do child:Destroy() end
	self.fields={};self.agentLabel=nil
	make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,7)},self.inspector)
	local node=self.state and self.state.nodes[id]
	if not node then
		label(self.inspector,"Selecione uma entidade",14)
		local info=label(self.inspector,"Dados próprios, não Instances como estado.",11);info.TextWrapped=true;info.Size=UDim2.new(1,0,0,50)
		self.rebuilding=false;return
	end
	local entityId=node.id
	local editRevision=self.state.revision
	local function execute(operations) self.callbacks.execute(operations,editRevision) end
	label(self.inspector,node.kind.."  /  "..entityId,11).TextColor3=colors.muted
	local name=field(self.inspector,"Nome",node.name)
	name.FocusLost:Connect(function() if not self.rebuilding and self.selected==entityId then execute({{op="rename",id=entityId,name=name.Text}}) end end)
	local function numberField(title,value,callback)
		label(self.inspector,title,11).TextColor3=colors.muted
		local box=field(self.inspector,title,string.format("%.3f",value))
		box.FocusLost:Connect(function()
			if self.rebuilding or self.selected~=entityId then return end
			local number=tonumber(string.gsub(box.Text,",","."))
			if not number then self:status("Informe um número válido",true);return end
			callback(number)
		end)
		return box
	end
	local function triple(title,value,callback)
		label(self.inspector,title,11).TextColor3=colors.muted
		local row=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,32)},self.inspector)
		local boxes={}
		for index,axis in ipairs({"x","y","z"}) do
			local box=field(row,string.upper(axis),string.format("%.2f",value[axis]))
			box.Position=UDim2.new((index-1)/3,2,0,0);box.Size=UDim2.new(1/3,-4,1,0);boxes[axis]=box
			box.FocusLost:Connect(function()
				if self.rebuilding or self.selected~=entityId then return end
				local values={}
				for key,input in pairs(boxes) do values[key]=tonumber(string.gsub(input.Text,",","."));if values[key]==nil then self:status("Vetor inválido",true);return end end
				callback(values)
			end)
		end
		return boxes
	end
	self.fields.position=triple("POSIÇÃO LOCAL · X / Y / Z",node.transform.position,function(value) execute({{op="transform",id=entityId,position=value}}) end)
	self.fields.rotation=triple("ROTAÇÃO · GRAUS",node.transform.rotation,function(value) execute({{op="transform",id=entityId,rotation=value}}) end)
	if node.kind~="group" and node.kind~="terrain" then self.fields.size=triple("DIMENSÕES",node.transform.size,function(value) execute({{op="transform",id=entityId,size=value}}) end) end
	numberField("ESCALA UNIFORME / HERANÇA",node.transform.scale,function(value) execute({{op="transform",id=entityId,scale=value}}) end)
	label(self.inspector,"PAI · ID OU VAZIO PARA RAIZ",11).TextColor3=colors.muted
	local parent=field(self.inspector,"Raiz",node.parent)
	parent.FocusLost:Connect(function() if not self.rebuilding and self.selected==entityId then execute({{op="parent",id=entityId,parent=parent.Text}}) end end)
	if node.kind~="group" then
		local palette={"stone","soil","grass","sand","wood","metal","glass","water","neon","asphalt"}
		button(self.inspector,"Material: "..node.surface.material,function()
			local current=table.find(palette,node.surface.material) or 1
			execute({{op="surface",id=entityId,patch={material=palette[current%#palette+1]}}})
		end,225)
		triple("COR · RGB NORMALIZADO",{x=node.surface.color.r,y=node.surface.color.g,z=node.surface.color.b},function(value)
			execute({{op="surface",id=entityId,patch={color={r=value.x,g=value.y,b=value.z}}}})
		end)
		numberField("TRANSPARÊNCIA",node.surface.transparency,function(value) execute({{op="surface",id=entityId,patch={transparency=value}}}) end)
	end
	if node.kind=="box" or node.kind=="sphere" or node.kind=="cylinder" then
		button(self.inspector,node.body.dynamic and "Dinâmica: ATIVA" or "Dinâmica: ESTÁTICA",function() execute({{op="body",id=entityId,patch={dynamic=not node.body.dynamic}}}) end,225)
		triple("VELOCIDADE INICIAL",node.body.velocity,function(value) execute({{op="body",id=entityId,patch={velocity=value}}}) end)
	end
	if node.kind=="npc" then
		label(self.inspector,"NMN / ESTADO NO CORE",11).TextColor3=colors.accent
		self.agentLabel=label(self.inspector,"Inicie a simulação para observar necessidades, memória e decisões.",11)
		self.agentLabel.TextWrapped=true;self.agentLabel.TextTruncate=Enum.TextTruncate.None;self.agentLabel.Size=UDim2.new(1,0,0,92)
		button(self.inspector,"Memória e trajeto / inspecionar",function() self.callbacks.inspectNpc(entityId) end,225)
		button(self.inspector,node.npc.enabled and "Cérebro: ATIVO" or "Cérebro: PAUSADO",function() execute({{op="npc",id=entityId,patch={enabled=not node.npc.enabled}}}) end,225)
		button(self.inspector,"Objetivo: "..node.npc.behavior,function() execute({{op="npc",id=entityId,patch={behavior=node.npc.behavior=="wander" and "goTo" or "wander"}}}) end,225)
		triple("DESTINO / goTo",node.npc.target,function(value) execute({{op="npc",id=entityId,patch={target=value}}}) end)
		for _,item in ipairs({{"VELOCIDADE","speed"},{"VISÃO / DISTÂNCIA","sight"},{"CAMPO DE VISÃO / GRAUS","fov"},{"AUDIÇÃO / ALCANCE","hearing"},{"CORAGEM / 0..1","bravery"},{"ENERGIA INICIAL / 0..1","energy"},{"FOME INICIAL / 0..1","hunger"}}) do
			numberField(item[1],node.npc[item[2]],function(value) execute({{op="npc",id=entityId,patch={[item[2]]=value}}}) end)
		end
	end
	if node.kind=="light" then
		numberField("INTENSIDADE DA LUZ",node.light.intensity,function(value) execute({{op="light",id=entityId,patch={intensity=value}}}) end)
		numberField("ALCANCE DA LUZ",node.light.range,function(value) execute({{op="light",id=entityId,patch={range=value}}}) end)
	end
	if node.kind=="terrain" then
		label(self.inspector,"HEIGHTFIELD / PINCEL",11).TextColor3=colors.accent
		for _,entry in ipairs({{"raise","Elevar"},{"lower","Rebaixar"},{"smooth","Suavizar"},{"flatten","Nivelar"}}) do
			button(self.inspector,entry[2].." · toque no terreno",function() self.brush.mode=entry[1];self.tool="brush";self.mobilePanel=nil;self:layout();self.callbacks.tool("brush");self:status("Pincel: "..entry[2]..". Clique/toque no terreno.") end,225)
		end
		numberField("RAIO DO PINCEL",self.brush.radius,function(value) self.brush.radius=math.clamp(value,.5,128) end)
		numberField("FORÇA DO PINCEL",self.brush.strength,function(value) self.brush.strength=math.clamp(value,.01,32) end)
	end
	button(self.inspector,"Enquadrar seleção · F",function() self.callbacks.focus(entityId) end,225)
	button(self.inspector,"Animar / criar grafo",function() self.callbacks.animate(entityId) end,225)
	button(self.inspector,"Editar grafo JSON",function() self.callbacks.graph(entityId) end,225)
	button(self.inspector,"Duplicar",function() execute({{op="duplicate",id=entityId}}) end,225)
	local remove=button(self.inspector,"Excluir · disponível no Undo",function() execute({{op="delete",id=entityId}}) end,225);remove.TextColor3=colors.danger
	self.rebuilding=false
end

function Editor:update(packet,selected)
	self.state=packet.state;self.mode=packet.mode;self.selected=selected;self.providerConfigured=packet.providerConfigured
	self.playButton.Text=self.mode=="edit" and "Simular" or "Parar"
	self.undoButton.TextColor3=packet.canUndo and colors.text or colors.muted
	self.redoButton.TextColor3=packet.canRedo and colors.text or colors.muted
	self:refreshTree();self:inspectorFor(selected)
end
function Editor:select(id)
	self.selected=id;self:drawTree();self:inspectorFor(id)
	if self.mobile then self.mobilePanel="right";self:layout() end
end

function Editor:dialog(title,description,text,onApply,readOnly)
	if self.modal then self.modal:Destroy() end
	local shade=make("Frame",{BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.25,Size=UDim2.fromScale(1,1),ZIndex=50,Active=true},self.root)
	self.modal=shade
	local panel=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.9,0,.8,0),BackgroundColor3=colors.panel,BorderSizePixel=0,ZIndex=51},shade);corner(panel,9)
	local name=label(panel,title,17);name.Font=Enum.Font.GothamBold;name.Position=UDim2.fromOffset(14,12);name.Size=UDim2.new(1,-85,0,26);name.ZIndex=52
	button(panel,"Fechar",function() shade:Destroy();self.modal=nil end,65).Position=UDim2.new(1,-78,0,10)
	local hint=label(panel,description,11);hint.Position=UDim2.fromOffset(14,43);hint.Size=UDim2.new(1,-28,0,38);hint.TextWrapped=true;hint.TextColor3=colors.muted;hint.ZIndex=52
	local scroll=make("ScrollingFrame",{BackgroundColor3=colors.bg,BorderSizePixel=0,Position=UDim2.fromOffset(14,86),Size=UDim2.new(1,-28,1,-143),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ZIndex=52},panel)
	local box=make("TextBox",{BackgroundTransparency=1,Text=text or "",ClearTextOnFocus=false,MultiLine=true,TextEditable=onApply~=nil and not readOnly,Font=Enum.Font.Code,TextSize=13,TextColor3=colors.text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,-14,0,180),Position=UDim2.fromOffset(7,7),ZIndex=53},scroll)
	if onApply then
		local apply=button(panel,"Validar e aplicar",function() onApply(box.Text);shade:Destroy();self.modal=nil end,160)
		apply.Position=UDim2.new(1,-175,1,-43);apply.ZIndex=53
	else
		local note=label(panel,"Selecione o texto para copiar. Não há execução de código livre.",11);note.Position=UDim2.new(0,14,1,-40);note.TextColor3=colors.muted;note.ZIndex=53
	end
	return panel
end

function Editor:showPlan(result)
	local lines={result.plan.label,"", "Origem: "..tostring(result.plan.origin),"Operações: "..result.proof.operations,"Entidades: "..result.proof.entitiesBefore.." → "..result.proof.entitiesAfter,"", "A execução só acontece após esta confirmação. Prévia válida por 90 segundos.",""}
	for index,operation in ipairs(result.plan.operations) do table.insert(lines,index..". "..tostring(operation.op).." "..tostring(operation.id or "")) end
	self:dialog("Prévia Singularity", "Plano validado contra a revisão atual. Você pode desfazer a transação depois.",table.concat(lines,"\n"),function() self.callbacks.applyPlan(result.token) end,true)
end

function Editor:agentStatus(summary)
	if self.agentLabel and summary then
		self.agentLabel.Text=string.format("%s / %s\nFome %.2f · energia %.2f · stress %.2f\nMemórias recentes: %d\nCausa: %s\n%s",summary.mode,summary.goal,summary.hunger,summary.energy,summary.stress,summary.memoryCount,summary.lastCause,summary.lastError)
	end
end

function Editor:destroy() self.gui:Destroy() end
return Editor
