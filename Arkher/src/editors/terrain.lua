--!strict
-- Terrain — Gaea + WorldMachine + Terragen hybrid (non-destructive, Tiled Builds)
-- Left: Device palette (180+ Gaea nodes / 100+ WM devices), Center: Node graph + Erosion strokes, Right: Preview 3D + Splat
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local Terrain={}
Terrain.__index=Terrain

function Terrain.new(parent: Instance)
	local win=BaseWindow.new({title="Terrain  —  Gaea / WorldMachine Nodes", size=Vector2.new(860,540), pos=UDim2.fromOffset(100,80), parent=parent, icon="⛰"})
	win.Root.Name="ARKHER_Terrain"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void

	-- Device palette left
	local palette=Instance.new("ScrollingFrame")
	palette.Size=UDim2.new(0,180,1,-32)
	palette.BackgroundColor3=Theme.tokens.slate900
	palette.BorderSizePixel=0; palette.ScrollBarThickness=6; palette.CanvasSize=UDim2.new(0,0,0,0); palette.AutomaticCanvasSize=Enum.AutomaticSize.Y
	palette.Parent=content
	local pl=Instance.new("UIListLayout"); pl.Padding=UDim.new(0,4); pl.Parent=palette
	Instance.new("UIPadding", palette).PaddingLeft=UDim.new(0,6)
	local cats={"Primitive","Noise","Erosion","Flow","Stratify","Thermal","Snow","River","Coast","Biome","Mask","Combine","Transform","Output"}
	for _,cat in cats do
		local sec=Instance.new("TextLabel"); sec.Size=UDim2.new(1,0,0,16); sec.BackgroundTransparency=1; sec.Text=cat; sec.Font=Enum.Font.GothamBold; sec.TextSize=10; sec.TextColor3=Theme.tokens.arkherBlue; sec.TextXAlignment=Enum.TextXAlignment.Left; sec.Parent=palette
		for i=1,3 do
			local dev=Instance.new("TextButton"); dev.Size=UDim2.new(1,0,0,22); dev.BackgroundColor3=Theme.tokens.slate800; dev.Text=cat.." "..i; dev.Font=Enum.Font.Gotham; dev.TextSize=10; dev.TextColor3=Theme.tokens.slate200; dev.Parent=palette; local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(0,4); dc.Parent=dev
		end
	end

	-- Graph center
	local graph=Instance.new("Frame")
	graph.Size=UDim2.new(1,-380,1,-32)
	graph.Position=UDim2.fromOffset(180,0)
	graph.BackgroundColor3=Color3.fromRGB(14,20,48)
	graph.BorderSizePixel=0
	graph.Parent=content
	local function tNode(pos: Vector2, name:string, col: Color3)
		local n=Instance.new("Frame"); n.Size=UDim2.fromOffset(110,56); n.Position=UDim2.fromOffset(pos.X,pos.Y); n.BackgroundColor3=Theme.tokens.slate800; n.BorderSizePixel=0; n.Parent=graph; local nc=Instance.new("UICorner"); nc.CornerRadius=UDim.new(0,8); nc.Parent=n; local ns=Instance.new("UIStroke"); ns.Color=col; ns.Thickness=1.5; ns.Parent=n
		local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,16); t.BackgroundColor3=col; t.Text=name; t.Font=Enum.Font.GothamBold; t.TextSize=9; t.TextColor3=Color3.new(1,1,1); t.Parent=n; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=t
		local th=Instance.new("Frame"); th.Size=UDim2.new(1, -8,0,28); th.Position=UDim2.fromOffset(4,20); th.BackgroundColor3=Color3.fromRGB(22,30,70); th.BorderSizePixel=0; th.Parent=n; local thc=Instance.new("UICorner"); thc.CornerRadius=UDim.new(0,4); thc.Parent=th
		return n
	end
	tNode(Vector2.new(20,30),"Mountain",Color3.fromRGB(80,120,80))
	tNode(Vector2.new(150,60),"Erosion",Color3.fromRGB(120,90,40))
	tNode(Vector2.new(280,30),"Stratify",Color3.fromRGB(100,100,140))
	tNode(Vector2.new(410,60),"River",Theme.tokens.arkherBlue)
	-- wires
	for _,x in {130,260,390} do local w=Instance.new("Frame"); w.Size=UDim2.new(0,20,0,2); w.Position=UDim2.fromOffset(x,58); w.BackgroundColor3=Theme.tokens.slate400; w.BorderSizePixel=0; w.Parent=graph end

	-- Right preview + splat
	local right=Instance.new("Frame")
	right.Size=UDim2.new(0,200,1,-32)
	right.Position=UDim2.new(1,-200,0,0)
	right.BackgroundColor3=Theme.tokens.slate800
	right.BorderSizePixel=0
	right.Parent=content
	local prev=Instance.new("Frame"); prev.Size=UDim2.new(1,-12,0,160); prev.Position=UDim2.fromOffset(6,6); prev.BackgroundColor3=Color3.fromRGB(22,30,70); prev.BorderSizePixel=0; prev.Parent=right; local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,8); pc.Parent=prev
	local plbl=Instance.new("TextLabel"); plbl.Size=UDim2.new(1,0,0,14); plbl.BackgroundTransparency=1; plbl.Text="3D Preview  •  2K  •  Non-destructive"; plbl.Font=Enum.Font.Gotham; plbl.TextSize=9; plbl.TextColor3=Theme.tokens.slate400; plbl.Parent=prev
	-- fake height bands
	for i=1,5 do local band=Instance.new("Frame"); band.Size=UDim2.new(1,-16,0,6); band.Position=UDim2.fromOffset(8, 24 + i*18); band.BackgroundColor3=Theme.ramp({Color3.fromRGB(20,60,20), Color3.fromRGB(120,100,60), Color3.fromRGB(240,240,240)},5)[i]; band.BorderSizePixel=0; band.Parent=prev; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=band end
	local props=Instance.new("ScrollingFrame"); props.Size=UDim2.new(1,-8,1,-174); props.Position=UDim2.fromOffset(4,174); props.BackgroundTransparency=1; props.BorderSizePixel=0; props.ScrollBarThickness=6; props.CanvasSize=UDim2.new(0,0,0,0); props.AutomaticCanvasSize=Enum.AutomaticSize.Y; props.Parent=right
	local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,6); prl.Parent=props
	Components.Slider(props, "Erosion", 0,1,0.62, function() end)
	Components.Slider(props, "Sediment", 0,1,0.3, function() end)
	Components.Dropdown(props, "Output", {"Heightmap","Splat","Mesh","Tiled Build 4K"}, "Tiled Build 4K", function() end)
	local build=Components.Button(props, "▶  Build Tiles", {size=UDim2.new(1,0,0,30), color=Theme.tokens.arkherBlue}); build.TextColor3=Color3.fromRGB(14,20,48)

	-- Bottom bar: Tiled Builds
	local bottom=Instance.new("Frame"); bottom.Size=UDim2.new(1,0,0,32); bottom.Position=UDim2.new(0,0,1,-32); bottom.BackgroundColor3=Theme.tokens.slate900; bottom.BorderSizePixel=0; bottom.Parent=content
	local bl=Instance.new("UIListLayout"); bl.FillDirection=Enum.FillDirection.Horizontal; bl.Padding=UDim.new(0,8); bl.VerticalAlignment=Enum.VerticalAlignment.Center; bl.Parent=bottom
	Instance.new("UIPadding", bottom).PaddingLeft=UDim.new(0,8)
	local info=Instance.new("TextLabel"); info.Size=UDim2.fromOffset(260,22); info.BackgroundTransparency=1; info.Text="Gaea 180+ nodes  •  WM Tiled Builds  •  ESA → biome splat"; info.Font=Enum.Font.Gotham; info.TextSize=10; info.TextColor3=Theme.tokens.slate400; info.Parent=bottom
	local imp=Instance.new("TextButton"); imp.Size=UDim2.fromOffset(110,22); imp.BackgroundColor3=Theme.tokens.slate800; imp.Text="Import SRTM"; imp.Font=Enum.Font.Gotham; imp.TextSize=11; imp.TextColor3=Theme.tokens.slate200; imp.Parent=bottom; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,6); ic.Parent=imp

	return setmetatable({Win=win}, Terrain)
end
function Terrain:Toggle() self.Win:Toggle() end
return Terrain
