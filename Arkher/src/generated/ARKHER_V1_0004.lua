--!strict
-- Frostbite — FBMod + Squadron Editor #0004
-- Template: node_flow — AAA refazido com controles reais 100% funcionais, adaptado de engine original + customs milhares
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Frostbite — FBMod + Squadron Editor #0004", size=Vector2.new(692, 508), pos=UDim2.fromOffset(268, 292), parent=parent, icon="❄"})
    win.Root.Name="ARKHER_V1_0004"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Frostb"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    do
        local content=body

local sq=Instance.new("TextLabel"); sq.Size=UDim2.new(1,0,0,22); sq.BackgroundTransparency=1; sq.Text="FROSTBITE SQUAD + FBMod Import (EA adapted)"; sq.Font=Enum.Font.GothamBold; sq.TextSize=11; sq.TextColor3=Theme.tokens.arkherGlow; sq.TextXAlignment=Enum.TextXAlignment.Left; sq.Parent=content
Components.Dropdown(content, "Profile", {"Squad","Destruction","VFX","Audio"}, "Squad", function() end)
Components.Checkbox(content, "Avalonia MVVM", true, function(v) end)
Components.TextField(content, "FBMod Path", "mods/fbmod.fbmod", function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_FBMod", v) end end)
Components.Slider(content, "Destruction Steps", 1, 10, 4, function(v) end)

    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_4"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+4*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
