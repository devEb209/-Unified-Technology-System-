--!strict
-- ARKHER — Nuke/Houdini VFX Graph #0048
-- Template: particle — AAA TUDO + customs, 100% funcional adaptado
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="ARKHER — Nuke/Houdini VFX Graph #0048", size=Vector2.new(704, 536), pos=UDim2.fromOffset(236, 384), parent=parent, icon="⛰"})
    win.Root.Name="ARKHER_V1_0048"
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
local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,22); hdr.BackgroundTransparency=1; hdr.Text="ARKHER — Nuke/Houdini VFX Graph"; hdr.Font=Enum.Font.GothamBold; hdr.TextSize=11; hdr.TextColor3=Theme.tokens.arkherGlow; hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.Parent=content
Components.Slider(content, "Intensity", 0,1,0.6, function(v) local s=game:GetService("Selection"):Get()[1]; if s then game:GetService("ChangeHistoryService"):SetWaypoint("Intensity"); s:SetAttribute("ARKHER_I48", v); game:GetService("ChangeHistoryService"):SetWaypoint("Intensity") end end)
Components.Checkbox(content, "Enabled", true, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_E48", v) end end)
Components.Dropdown(content, "Mode", {"Auto","Manual","Hybrid"}, "Auto", function(v) end)
    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_48"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(1000000+48*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
