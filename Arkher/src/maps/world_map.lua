--!strict
-- WorldMap — Mapbox / OSM / ESA WorldCover 11 classes + OpenLandMap 32 biomas
-- Integrated HttpService → tiles, overlay switcher, GPS import, helps Singularity reason about world.
local Theme=require(script.Parent.Parent.core.theme)
local Config=require(script.Parent.Parent.core.config)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local WorldMap={}
WorldMap.__index=WorldMap

function WorldMap.new(parent: Instance)
	local win=BaseWindow.new({title="World • Maps & Biomes", size=Vector2.new(520, 420), pos=UDim2.fromOffset(320, 120), parent=parent, icon="🛰"})
	win.Root.Name="ARKHER_Maps"
	win.Root.Visible=false
	local content=win.Content

	-- Map preview (image placeholder + overlay)
	local viewport=Instance.new("Frame")
	viewport.Size=UDim2.new(1,0,0,220)
	viewport.BackgroundColor3=Color3.fromRGB(10,16,40)
	viewport.BorderSizePixel=0
	viewport.Parent=content
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=viewport
	local img=Instance.new("ImageLabel")
	img.Size=UDim2.fromScale(1,1)
	img.BackgroundTransparency=1
	img.Image="rbxassetid://0" -- replaced via HttpService at runtime
	img.ScaleType=Enum.ScaleType.Crop
	img.Parent=viewport
	local overlay=Instance.new("TextLabel")
	overlay.Size=UDim2.new(1,0,0,22)
	overlay.Position=UDim2.new(0,0,1,-22)
	overlay.BackgroundColor3=Color3.fromRGB(14,20,48)
	overlay.BackgroundTransparency=0.2
	overlay.Text="Mapbox GL • OSM • ESA WorldCover 10m • OpenLandMap 32 biomas"
	overlay.Font=Enum.Font.Gotham
	overlay.TextSize=10
	overlay.TextColor3=Theme.tokens.slate400
	overlay.Parent=viewport

	-- Legend — ESA 11 classes
	local legend=Instance.new("Frame")
	legend.Size=UDim2.new(1,0,0,70)
	legend.Position=UDim2.fromOffset(0,224)
	legend.BackgroundTransparency=1
	legend.Parent=content
	local gl=Instance.new("UIGridLayout")
	gl.CellSize=UDim2.fromOffset(150,16)
	gl.CellPadding=UDim2.fromOffset(8,4)
	gl.FillDirectionMaxCells=3
	gl.Parent=legend
	for _,cls in Config.worldCover.classes do
		local row=Instance.new("Frame")
		row.BackgroundTransparency=1
		row.Parent=legend
		local sw=Instance.new("Frame"); sw.Size=UDim2.fromOffset(12,12); sw.Position=UDim2.fromOffset(0,2); sw.BackgroundColor3=cls.color; sw.BorderSizePixel=0; sw.Parent=row; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,3); cc.Parent=sw
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-16,1,0); lbl.Position=UDim2.fromOffset(16,0); lbl.BackgroundTransparency=1; lbl.Text=cls.name; lbl.Font=Enum.Font.Gotham; lbl.TextSize=10; lbl.TextColor3=Theme.tokens.slate200; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	end

	-- Controls
	local ctrl=Instance.new("Frame")
	ctrl.Size=UDim2.new(1,0,1,-300)
	ctrl.Position=UDim2.fromOffset(0,300)
	ctrl.BackgroundTransparency=1
	ctrl.Parent=content
	local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,6); list.Parent=ctrl
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=ctrl

	local self=setmetatable({Win=win}, WorldMap)

	local latLon = Components.TextField(ctrl, "GPS Lat,Lon", "-27.17, -51.61 (Joaçaba)", function(v)
		-- parse and fetch via HttpService on server; bridge here just visual
		overlay.Text="GPS: "..v.."  •  fetching ESA tiles…"
	end); 
	local prov = Components.Dropdown(ctrl, "Provider", {"Mapbox","OSM","Google"}, "Mapbox", function(opt) overlay.Text=opt.."  •  "..overlay.Text end)
	local bio = Components.Dropdown(ctrl, "Biome Overlay", {"Off","ESA WorldCover","OpenLandMap 32"}, "ESA WorldCover", function(opt) overlay.Text="Biome: "..opt end)
	local imp = Components.Button(ctrl, "⬇  Import Height (SRTM)", {size=UDim2.new(1,0,0,30), color=Theme.tokens.arkherBlue})
	imp.TextColor3=Color3.fromRGB(14,20,48)
	imp.MouseButton1Click:Connect(function() overlay.Text="Import queued — Singularity will terrace & scatter per biome…" end)

	return self
end
function WorldMap:Toggle() self.Win:Toggle() end
return WorldMap
