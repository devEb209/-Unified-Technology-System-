--!strict
-- CryEngine — RollupBar + CryTiling #0003
-- Template: layer_graph — AAA refazido com controles reais 100% funcionais, adaptado de engine original + customs milhares
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="CryEngine — RollupBar + CryTiling #0003", size=Vector2.new(679, 491), pos=UDim2.fromOffset(221, 239), parent=parent, icon="⬡"})
    win.Root.Name="ARKHER_V1_0003"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("CryEng"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    do
        local content=body

local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,22); t.BackgroundTransparency=1; t.Text="ROLLUPBAR + Qt EDITORCOMMON (CryEngine adapted)"; t.Font=Enum.Font.GothamBold; t.TextSize=11; t.TextColor3=Theme.tokens.arkherGlow; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=content
Components.Dropdown(content, "Material", {"CryRock","Ice","Vegetation","Plastic"}, "CryRock", function(v) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s::BasePart).Material=Enum.Material[v] or Enum.Material.Slate end end)
Components.Slider(content, "Tiling", 0.1, 10, 1, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_Cry_Tiling", v) end end)
Components.ColorField(content, "Albedo", Color3.fromRGB(180,180,180), function(c) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s::BasePart).Color=c end end)

    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_3"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+3*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
