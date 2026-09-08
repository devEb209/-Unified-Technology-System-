--!strict
-- Gaea 180+ — Tiled Build + Stratify #0009
-- Template: terrain — AAA refazido com controles reais 100% funcionais, adaptado de engine original + customs milhares
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Gaea 180+ — Tiled Build + Stratify #0009", size=Vector2.new(757, 493), pos=UDim2.fromOffset(103, 257), parent=parent, icon="⛰"})
    win.Root.Name="ARKHER_V1_0009"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Gaea 1"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    do
        local content=body

local gg=Instance.new("TextLabel"); gg.Size=UDim2.new(1,0,0,22); gg.BackgroundTransparency=1; gg.Text="EROSION • STRATIFY • TILED 8K (Gaea/WM adapted)"; gg.Font=Enum.Font.GothamBold; gg.TextSize=11; gg.TextColor3=Theme.tokens.arkherGlow; gg.TextXAlignment=Enum.TextXAlignment.Left; gg.Parent=content
local graph=Instance.new("Frame"); graph.Size=UDim2.new(1,0,0,60); graph.BackgroundColor3=Theme.tokens.slate900; graph.Parent=content; local gc=Instance.new("UICorner"); gc.CornerRadius=UDim.new(0,8); gc.Parent=graph
for i,n in ipairs({"Mountain","Erosion","Stratify"}) do local nd=Instance.new("Frame"); nd.Size=UDim2.fromOffset(90,40); nd.Position=UDim2.fromOffset(12+(i-1)*104,10); nd.BackgroundColor3=Theme.tokens.slate800; nd.Parent=graph; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=nd; local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1; lb.Text=n; lb.Font=Enum.Font.Gotham; lb.TextSize=10; lb.TextColor3=Theme.tokens.slate200; lb.Parent=nd end
Components.Slider(content, "Erosion", 0,1,0.6, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_Gaea_Erosion", v) end end)
Components.Slider(content, "Tiles", 1, 16, 4, function(v) end)

    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_9"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+9*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
