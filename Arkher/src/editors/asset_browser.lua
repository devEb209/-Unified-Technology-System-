--!strict
-- Asset Browser — Quixel Bridge + PolyHaven + SpeedTree hybrid
-- Search, filters (LOD, UDIM, 2K-8K), grid, import
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local AssetBrowser={}
AssetBrowser.__index=AssetBrowser
function AssetBrowser.new(parent: Instance)
	local win=BaseWindow.new({title="Assets  —  Megascans / PolyHaven / SpeedTree", size=Vector2.new(820,480), pos=UDim2.fromOffset(120,90), parent=parent, icon="⬢"})
	win.Root.Name="ARKHER_Assets"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void
	local top=Instance.new("Frame"); top.Size=UDim2.new(1,0,0,32); top.BackgroundColor3=Theme.tokens.slate900; top.BorderSizePixel=0; top.Parent=content
	local search=Instance.new("TextBox"); search.Size=UDim2.new(0,220,0,22); search.Position=UDim2.fromOffset(8,5); search.BackgroundColor3=Theme.tokens.slate800; search.PlaceholderText="Search Quixel / PolyHaven…"; search.Text=""; search.Font=Enum.Font.Gotham; search.TextSize=11; search.TextColor3=Theme.tokens.white; search.PlaceholderColor3=Theme.tokens.slate400; search.Parent=top; local sc=Instance.new("UICorner"); sc.CornerRadius=UDim.new(0,6); sc.Parent=search; local st=Instance.new("UIStroke"); st.Color=Theme.roles.border; st.Thickness=1; st.Parent=search
	for _,f in {"Surface","3D","Plant","Atlas"} do local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(64,22); b.Position=UDim2.fromOffset(236 + ({Surface=0,["3D"]=1,Plant=2,Atlas=3}[f])*70,5); b.BackgroundColor3=Theme.tokens.slate800; b.Text=f; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Theme.tokens.slate400; b.Parent=top; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=b end
	local grid=Instance.new("ScrollingFrame"); grid.Size=UDim2.new(1,0,1,-32); grid.Position=UDim2.fromOffset(0,32); grid.BackgroundColor3=Color3.fromRGB(14,20,48); grid.BorderSizePixel=0; grid.ScrollBarThickness=6; grid.CanvasSize=UDim2.new(0,0,0,0); grid.AutomaticCanvasSize=Enum.AutomaticSize.Y; grid.Parent=content
	local gl=Instance.new("UIGridLayout"); gl.CellSize=UDim2.fromOffset(140,110); gl.CellPadding=UDim2.fromOffset(8,8); gl.Parent=grid; Instance.new("UIPadding", grid).PaddingLeft=UDim.new(0,8)
	for i=1,12 do
		local card=Instance.new("Frame"); card.BackgroundColor3=Theme.tokens.slate800; card.BorderSizePixel=0; card.Parent=grid; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=card
		local thumb=Instance.new("Frame"); thumb.Size=UDim2.new(1,0,0,70); thumb.BackgroundColor3=Theme.categoryColor("asset"..i); thumb.BorderSizePixel=0; thumb.Parent=card; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=thumb
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-8,0,14); lbl.Position=UDim2.fromOffset(4,74); lbl.BackgroundTransparency=1; lbl.Text="Asset "..i.."  •  4K LOD0-2"; lbl.Font=Enum.Font.Gotham; lbl.TextSize=9; lbl.TextColor3=Theme.tokens.slate200; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=card
		local imp=Instance.new("TextButton"); imp.Size=UDim2.new(1,-8,0,16); imp.Position=UDim2.fromOffset(4,90); imp.BackgroundColor3=Theme.tokens.arkherBlue; imp.Text="Import"; imp.Font=Enum.Font.GothamBold; imp.TextSize=9; imp.TextColor3=Color3.fromRGB(14,20,48); imp.Parent=card; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,4); ic.Parent=imp
	end
	return setmetatable({Win=win}, AssetBrowser)
end
function AssetBrowser:Toggle() self.Win:Toggle() end
return AssetBrowser
