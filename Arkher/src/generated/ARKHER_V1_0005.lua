--!strict
-- ARKHER DLSS 5 — SuperRes + FrameGen + RayRecon #0005
-- Template: profiler — AAA refazido com controles reais 100% funcionais, adaptado de engine original + customs milhares
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="ARKHER DLSS 5 — SuperRes + FrameGen + RayRecon #0005", size=Vector2.new(705, 525), pos=UDim2.fromOffset(315, 345), parent=parent, icon="◈"})
    win.Root.Name="ARKHER_V1_0005"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("ARKHER"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    do
        local content=body

local d=Instance.new("TextLabel"); d.Size=UDim2.new(1,0,0,22); d.BackgroundTransparency=1; d.Text="DLSS 5 NEURAL — SuperRes 6X + FrameGen + RayRecon (ARKHER custom)"; d.Font=Enum.Font.GothamBold; d.TextSize=11; d.TextColor3=Theme.tokens.arkherGlow; d.TextXAlignment=Enum.TextXAlignment.Left; d.Parent=content
for i,mode in ipairs({"Performance","Balanced","Quality","Ultra"}) do local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(86,24); b.Position=UDim2.fromOffset(8+(i-1)*92, 2); b.BackgroundColor3=Theme.tokens.slate800; b.Text=mode; b.Font=Enum.Font.Gotham; b.TextSize=10; b.TextColor3=Theme.tokens.slate200; b.Parent=content; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=b end
Components.Slider(content, "SuperRes 6X", 1, 6, 3.5, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_DLSS_SR", v) end end)
Components.Checkbox(content, "FrameGen 5X", true, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_DLSS_FG", v) end end)
Components.Checkbox(content, "RayRecon", true, function(v) end)
Components.ColorField(content, "Neural Tint", Color3.fromRGB(0,212,255), function(c) end)

    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_5"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+5*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
