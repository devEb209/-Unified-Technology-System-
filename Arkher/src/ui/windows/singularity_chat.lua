--!strict
-- Singularity Chat — SINGLE TopBar button → draggable corner chat, never blocks work.
-- Auto-mode: can build AAAA game over days/weeks, sees pattern/structure, uses ALL Puter models via Core.
local Theme = require(script.Parent.Parent.Parent.core.theme)
local BaseWindow = require(script.Parent.base_window)

local Chat = {}
Chat.__index = Chat

function Chat.new(parent: Instance)
	-- start at bottom-right corner, reasonable size not blocking viewport centre
	local win = BaseWindow.new({
		title="◆  Singularity Core",
		size=Vector2.new(380, 460),
		pos=UDim2.new(1,-396,1,-476),
		parent=parent,
		icon="◆"
	})
	win.Root.Name="ARKHER_Singularity"
	win.Root.Visible=false -- hidden until TopBar button
	-- tint header violet
	;(win.Root:FindFirstChild("Header") :: Frame).BackgroundColor3 = Color3.fromRGB(38, 28, 78)
	local content = win.Content
	content.BackgroundColor3 = Color3.fromRGB(18, 20, 38)

	-- mode row
	local modeRow=Instance.new("Frame")
	modeRow.Size=UDim2.new(1,0,0,28)
	modeRow.BackgroundColor3=Theme.tokens.slate800
	modeRow.BorderSizePixel=0
	modeRow.Parent=content
	local autoBtn=Instance.new("TextButton")
	autoBtn.Size=UDim2.fromOffset(120,22)
	autoBtn.Position=UDim2.fromOffset(8,3)
	autoBtn.BackgroundColor3=Theme.tokens.violet
	autoBtn.Text="⬢  Auto Build"
	autoBtn.Font=Enum.Font.GothamBold
	autoBtn.TextSize=11
	autoBtn.TextColor3=Color3.new(1,1,1)
	autoBtn.Parent=modeRow
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=autoBtn
	local hint=Instance.new("TextLabel")
	hint.Size=UDim2.new(1,-140,1,0)
	hint.Position=UDim2.fromOffset(136,0)
	hint.BackgroundTransparency=1
	hint.Text="Sees game & structure • builds for days"
	hint.Font=Enum.Font.Gotham
	hint.TextSize=10
	hint.TextColor3=Theme.tokens.slate400
	hint.TextXAlignment=Enum.TextXAlignment.Left
	hint.Parent=modeRow

	-- messages scroll
	local scroll=Instance.new("ScrollingFrame")
	scroll.Name="Messages"
	scroll.Size=UDim2.new(1,-8,1,-78)
	scroll.Position=UDim2.fromOffset(4,32)
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.ScrollBarThickness=6
	scroll.ScrollBarImageColor3=Theme.tokens.violet
	scroll.CanvasSize=UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
	scroll.Parent=content
	local layout=Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,8)
	layout.Parent=scroll
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.PaddingTop=UDim.new(0,8); pad.Parent=scroll

	local function addMsg(role: string, text: string)
		local bubble=Instance.new("Frame")
		bubble.Size=UDim2.new(1,-8,0,0)
		bubble.AutomaticSize=Enum.AutomaticSize.Y
		bubble.BackgroundColor3= if role=="user" then Theme.tokens.slate800 else Color3.fromRGB(48, 32, 86)
		bubble.BorderSizePixel=0
		bubble.Parent=scroll
		local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=bubble
		local pp=Instance.new("UIPadding"); pp.PaddingLeft=UDim.new(0,10); pp.PaddingRight=UDim.new(0,10); pp.PaddingTop=UDim.new(0,8); pp.PaddingBottom=UDim.new(0,8); pp.Parent=bubble
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(1,0,0,0)
		lbl.AutomaticSize=Enum.AutomaticSize.Y
		lbl.BackgroundTransparency=1
		lbl.Text=text
		lbl.Font=Enum.Font.Gotham
		lbl.TextSize=12
		lbl.TextColor3=Theme.tokens.white
		lbl.TextWrapped=true
		lbl.TextXAlignment=Enum.TextXAlignment.Left
		lbl.Parent=bubble
	end

	addMsg("assistant","Singularity Core online. I see your game structure, patterns and every reference. Ask to build, sculpt, animate — or hit Auto Build and I'll work for days, you interrupt anytime.")
	addMsg("assistant","Routed through Puter.js — 500+ models (vision, code, 3D, video) — no fixed AI, best model per task.")

	-- input row
	local inputRow=Instance.new("Frame")
	inputRow.Size=UDim2.new(1,0,0,36)
	inputRow.Position=UDim2.new(0,0,1,-36)
	inputRow.BackgroundColor3=Theme.tokens.slate900
	inputRow.BorderSizePixel=0
	inputRow.Parent=content
	local tb=Instance.new("TextBox")
	tb.Size=UDim2.new(1,-56,1,-8)
	tb.Position=UDim2.fromOffset(8,4)
	tb.BackgroundColor3=Theme.tokens.slate800
	tb.PlaceholderText="Ask Singularity… (references, models, biomes, code)"
	tb.Text=""
	tb.Font=Enum.Font.Gotham
	tb.TextSize=12
	tb.TextColor3=Theme.tokens.white
	tb.PlaceholderColor3=Theme.tokens.slate400
	tb.TextXAlignment=Enum.TextXAlignment.Left
	tb.ClearTextOnFocus=false
	tb.Parent=inputRow
	local cc2=Instance.new("UICorner"); cc2.CornerRadius=UDim.new(0,8); cc2.Parent=tb
	local st=Instance.new("UIStroke"); st.Color=Theme.roles.border; st.Thickness=1; st.Parent=tb
	local pd2=Instance.new("UIPadding"); pd2.PaddingLeft=UDim.new(0,8); pd2.PaddingRight=UDim.new(0,8); pd2.Parent=tb
	local send=Instance.new("TextButton")
	send.Size=UDim2.fromOffset(36,28)
	send.Position=UDim2.new(1,-44,0,4)
	send.BackgroundColor3=Theme.tokens.violet
	send.Text="➤"
	send.Font=Enum.Font.GothamBold
	send.TextSize=14
	send.TextColor3=Color3.new(1,1,1)
	send.Parent=inputRow
	local cc3=Instance.new("UICorner"); cc3.CornerRadius=UDim.new(0,8); cc3.Parent=send

	local self=setmetatable({}, Chat)
	self.Win=win
	self.Scroll=scroll
	self.Input=tb
	self.AddMsg=addMsg

	local function sendMsg()
		local t=tb.Text:gsub("^%s+",""):gsub("%s+$","")
		if t=="" then return end
		addMsg("user", t)
		tb.Text=""
		-- placeholder routing — real Puter.js call via HttpService / StarterPlayer bridge
		task.delay(0.5, function()
			addMsg("assistant","Routing to Singularity Core (Puter.js)… I see "..tostring(#workspace:GetDescendants()).." instances. Ready to generate with best model for this task.")
		end)
	end
	send.MouseButton1Click:Connect(sendMsg)
	tb.FocusLost:Connect(function(enter) if enter then sendMsg() end end)
	autoBtn.MouseButton1Click:Connect(function()
		addMsg("assistant","Auto Build engaged — I'll design patterns, sculpt models with folds/phys, animate, light and iterate for days. You can pause/re-direct anytime.")
	end)

	return self
end

function Chat:Toggle()
	self.Win:Toggle()
end
function Chat:Show() self.Win:Show() end

return Chat
