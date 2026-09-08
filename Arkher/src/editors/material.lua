--!strict
-- Material — Substance Painter + UE Material Graph hybrid
-- Left: Layer stack (UDIM, fill, paint, mask), Center: Node graph, Right: Preview + properties, Bottom: Brush
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local Material={}
Material.__index=Material

function Material.new(parent: Instance)
	local win=BaseWindow.new({title="Material  —  Layers & Nodes", size=Vector2.new(820,520), pos=UDim2.fromOffset(140,120), parent=parent, icon="⬣"})
	win.Root.Name="ARKHER_Material"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void

	-- Layers (left)
	local layers=Instance.new("ScrollingFrame")
	layers.Size=UDim2.new(0,200,1,-36)
	layers.BackgroundColor3=Theme.tokens.slate900
	layers.BorderSizePixel=0; layers.ScrollBarThickness=6; layers.CanvasSize=UDim2.new(0,0,0,0); layers.AutomaticCanvasSize=Enum.AutomaticSize.Y
	layers.Parent=content
	local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,2); ll.Parent=layers
	Instance.new("UIPadding", layers).PaddingTop=UDim.new(0,6)
	local lt=Instance.new("TextLabel"); lt.Size=UDim2.new(1,0,0,18); lt.BackgroundTransparency=1; lt.Text="Layer Stack  (UDIM)"; lt.Font=Enum.Font.GothamBold; lt.TextSize=11; lt.TextColor3=Theme.tokens.arkherBlue; lt.TextXAlignment=Enum.TextXAlignment.Left; lt.Parent=layers
	local layerNames={"Base Color","Roughness","Metallic","Normal","Height","Emissive","Opacity"}
	for _,nm in layerNames do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,28); row.BackgroundColor3=Theme.tokens.slate800; row.BorderSizePixel=0; row.Parent=layers; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=row
		local thumb=Instance.new("Frame"); thumb.Size=UDim2.fromOffset(28,20); thumb.Position=UDim2.fromOffset(6,4); thumb.BackgroundColor3=Theme.categoryColor(nm); thumb.BorderSizePixel=0; thumb.Parent=row; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,4); tc.Parent=thumb
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-44,1,0); lbl.Position=UDim2.fromOffset(40,0); lbl.BackgroundTransparency=1; lbl.Text=nm; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate200; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	end
	local addL=Instance.new("TextButton"); addL.Size=UDim2.new(1,0,0,26); addL.BackgroundColor3=Theme.tokens.arkherBlue; addL.Text="+ Fill / Paint / Mask"; addL.Font=Enum.Font.GothamBold; addL.TextSize=11; addL.TextColor3=Color3.fromRGB(14,20,48); addL.Parent=layers; local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,6); ac.Parent=addL

	-- Node graph (center)
	local graph=Instance.new("Frame")
	graph.Size=UDim2.new(1,-400,1,-36)
	graph.Position=UDim2.fromOffset(200,0)
	graph.BackgroundColor3=Color3.fromRGB(16,22,52)
	graph.BorderSizePixel=0
	graph.Parent=content
	-- grid dots
	local grid=Instance.new("Frame"); grid.Size=UDim2.fromScale(1,1); grid.BackgroundTransparency=1; grid.Parent=graph
	-- nodes
	local function node(pos: Vector2, title:string, col: Color3)
		local n=Instance.new("Frame"); n.Size=UDim2.fromOffset(120,68); n.Position=UDim2.fromOffset(pos.X,pos.Y); n.BackgroundColor3=Theme.tokens.slate800; n.BorderSizePixel=0; n.Parent=graph; local nc=Instance.new("UICorner"); nc.CornerRadius=UDim.new(0,8); nc.Parent=n; local ns=Instance.new("UIStroke"); ns.Color=col; ns.Thickness=2; ns.Parent=n
		local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,18); t.BackgroundColor3=col; t.Text=title; t.Font=Enum.Font.GothamBold; t.TextSize=10; t.TextColor3=Color3.new(1,1,1); t.Parent=n; local tc2=Instance.new("UICorner"); tc2.CornerRadius=UDim.new(0,8); tc2.Parent=t
		local fix=Instance.new("Frame"); fix.Size=UDim2.new(1,0,0,6); fix.Position=UDim2.new(0,0,1,-6); fix.BackgroundColor3=col; fix.BorderSizePixel=0; fix.Parent=t
		local out=Instance.new("Frame"); out.Size=UDim2.fromOffset(10,10); out.Position=UDim2.new(1,-6,0.5,-5); out.BackgroundColor3=col; out.BorderSizePixel=0; out.Parent=n; local oc=Instance.new("UICorner"); oc.CornerRadius=UDim.new(1,0); oc.Parent=out
		return n
	end
	node(Vector2.new(20,40),"Texture",Theme.tokens.arkherBlue)
	node(Vector2.new(170,80),"Multiply",Theme.tokens.aurora)
	node(Vector2.new(320,50),"PBR Master",Theme.tokens.violet)
	-- connections
	local conn=Instance.new("Frame"); conn.Size=UDim2.new(0,50,0,2); conn.Position=UDim2.fromOffset(140,74); conn.BackgroundColor3=Theme.tokens.slate400; conn.BorderSizePixel=0; conn.Parent=graph
	local conn2=Instance.new("Frame"); conn2.Size=UDim2.new(0,50,0,2); conn2.Position=UDim2.fromOffset(290,84); conn2.BackgroundColor3=Theme.tokens.slate400; conn2.BorderSizePixel=0; conn2.Parent=graph

	-- Preview + props (right)
	local right=Instance.new("Frame")
	right.Size=UDim2.new(0,200,1,-36)
	right.Position=UDim2.new(1,-200,0,0)
	right.BackgroundColor3=Theme.tokens.slate800
	right.BorderSizePixel=0
	right.Parent=content
	local preview=Instance.new("Frame"); preview.Size=UDim2.new(1,-16,0,160); preview.Position=UDim2.fromOffset(8,8); preview.BackgroundColor3=Color3.fromRGB(14,20,48); preview.BorderSizePixel=0; preview.Parent=right; local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,8); pc.Parent=preview
	local plbl=Instance.new("TextLabel"); plbl.Size=UDim2.new(1,0,0,16); plbl.BackgroundTransparency=1; plbl.Text="Preview  •  2K  —  LOD0"; plbl.Font=Enum.Font.Gotham; plbl.TextSize=10; plbl.TextColor3=Theme.tokens.slate400; plbl.Parent=preview
	local sphere=Instance.new("Frame"); sphere.Size=UDim2.fromOffset(80,80); sphere.Position=UDim2.new(0.5,-40,0.5,-28); sphere.BackgroundColor3=Theme.tokens.slate600; sphere.BorderSizePixel=0; sphere.Parent=preview; local sc=Instance.new("UICorner"); sc.CornerRadius=UDim.new(1,0); sc.Parent=sphere
	local props=Instance.new("ScrollingFrame"); props.Size=UDim2.new(1,-8,1,-176); props.Position=UDim2.fromOffset(4,176); props.BackgroundTransparency=1; props.BorderSizePixel=0; props.ScrollBarThickness=6; props.CanvasSize=UDim2.new(0,0,0,0); props.AutomaticCanvasSize=Enum.AutomaticSize.Y; props.Parent=right
	local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,6); prl.Parent=props
	Components.Slider(props, "Roughness", 0,1,0.45, function(v)
		local sel=game:GetService("Selection"):Get()[1]
		if sel and sel:IsA("BasePart") then sel:SetAttribute("ARKHER_Rough", v) end
	end)
	Components.Slider(props, "Metallic", 0,1,0.0, function() end)
	Components.ColorField(props, "Base Color", Color3.fromRGB(200,180,160), function(c)
		local sel=game:GetService("Selection"):Get()[1]
		if sel and sel:IsA("BasePart") then (sel :: BasePart).Color=c end
	end)
	Components.Dropdown(props, "UV", {"UDIM 1001","UDIM 1002","Triplanar"}, "UDIM 1001", function() end)

	-- Brush bar bottom
	local brush=Instance.new("Frame"); brush.Size=UDim2.new(1,0,0,36); brush.Position=UDim2.new(0,0,1,-36); brush.BackgroundColor3=Theme.tokens.slate900; brush.BorderSizePixel=0; brush.Parent=content
	local bl=Instance.new("UIListLayout"); bl.FillDirection=Enum.FillDirection.Horizontal; bl.Padding=UDim.new(0,8); bl.VerticalAlignment=Enum.VerticalAlignment.Center; bl.Parent=brush
	Instance.new("UIPadding", brush).PaddingLeft=UDim.new(0,8)
	for _,b in {"Brush","Eraser","Smudge","Clone","Stencil"} do
		local btn=Instance.new("TextButton"); btn.Size=UDim2.fromOffset(72,22); btn.BackgroundColor3=Theme.tokens.slate800; btn.Text=b; btn.Font=Enum.Font.Gotham; btn.TextSize=11; btn.TextColor3=Theme.tokens.slate200; btn.Parent=brush; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=btn
	end
	Components.Slider(brush, "Size", 4, 256, 32, function() end)

	return setmetatable({Win=win}, Material)
end
function Material:Toggle() self.Win:Toggle() end
return Material
