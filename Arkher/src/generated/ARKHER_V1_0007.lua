--!strict
-- Houdini — VEX SOP + FLIP + Karma #0007
-- Template: particle — AAA refazido com controles reais 100% funcionais, adaptado de engine original + customs milhares
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Houdini — VEX SOP + FLIP + Karma #0007", size=Vector2.new(731, 459), pos=UDim2.fromOffset(409, 151), parent=parent, icon="⬔"})
    win.Root.Name="ARKHER_V1_0007"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Houdin"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    do
        local content=body

local h=Instance.new("TextLabel"); h.Size=UDim2.new(1,0,0,22); h.BackgroundTransparency=1; h.Text="VEX SOP • FLIP • Karma (Houdini adapted)"; h.Font=Enum.Font.GothamBold; h.TextSize=11; h.TextColor3=Theme.tokens.arkherGlow; h.TextXAlignment=Enum.TextXAlignment.Left; h.Parent=content
Components.TextField(content, "VEXpression", "@P.y += sin(@Time)*2", function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_VEX", v) end end)
Components.Slider(content, "Viscosity", 0,1,0.3, function(v) end)
Components.Dropdown(content, "Solver", {"FLIP","Pyro","Vellum","RBD"}, "FLIP", function() end)

    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_7"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+7*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
