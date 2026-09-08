--!strict
-- TopBar — organized, buttons separated, NOT cramped. Two rows: menu tabs + tool shelf.
-- Explorer/Properties toggles, primitive parts submenu, gizmo modes, fly toggle, maps, Singularity 1 button.
local Theme = require(script.Parent.Parent.Parent.core.theme)
local Config = require(script.Parent.Parent.Parent.core.config)

local TopBar = {}
TopBar.__index = TopBar

type Callbacks = {
	onToggleExplorer: ()->(),
	onToggleProperties: ()->(),
	onInsert: (string)->(),
	onGizmo: (string)->(),
	onToggleFly: ()->(),
	onOpenMaps: ()->(),
	onOpenSingularity: ()->(),
	onOpenEditor: (string)->(),
	onOpenPalette: ()->(),
}

local function corner(p: Instance, r: number)
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p; return c
end
local function stroke(p: Instance, col: Color3, t:number)
	local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=t; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end
local function mkBtn(parent: Instance, text: string, w: number, accent: boolean?): TextButton
	local b=Instance.new("TextButton")
	b.Size=UDim2.fromOffset(w, 28)
	b.BackgroundColor3= if accent then Theme.tokens.arkherBlue else Theme.tokens.slate800
	b.Text=text
	b.Font=Enum.Font.GothamMedium
	b.TextSize=12
	b.TextColor3= if accent then Color3.fromRGB(14,20,48) else Theme.tokens.slate200
	b.AutoButtonColor=true
	b.Parent=parent
	corner(b,8)
	stroke(b, if accent then Theme.tokens.arkherBlue else Theme.roles.border, 1)
	return b
end
local function mkIcon(parent: Instance, icon: string, tip: string): TextButton
	local b=Instance.new("TextButton")
	b.Size=UDim2.fromOffset(30,28)
	b.BackgroundColor3=Theme.tokens.slate800
	b.Text=icon
	b.Font=Enum.Font.GothamBold
	b.TextSize=13
	b.TextColor3=Theme.tokens.slate400
	b.AutoButtonColor=true
	b.Parent=parent
	corner(b,8)
	stroke(b,Theme.roles.border,1)
	return b
end

function TopBar.new(parent: Instance, cb: Callbacks)
	local self=setmetatable({}, TopBar)
	self.Callbacks=cb

	local bar=Instance.new("Frame")
	bar.Name="ARKHER_TopBar"
	bar.Size=UDim2.new(1,0,0, 76) -- 36 menu + 4 gap + 36 tools
	bar.Position=UDim2.fromOffset(0,0)
	bar.BackgroundColor3=Theme.tokens.void
	bar.BorderSizePixel=0
	bar.ZIndex=20
	bar.Parent=parent
	self.Root=bar

	-- top accent line
	local line=Instance.new("Frame")
	line.Size=UDim2.new(1,0,0,2)
	line.Position=UDim2.fromOffset(0,0)
	line.BackgroundColor3=Theme.tokens.arkherBlue
	line.BorderSizePixel=0
	line.ZIndex=21
	line.Parent=bar

	-- ROW 1 — brand + menu tabs (separated)
	local row1=Instance.new("Frame")
	row1.Name="MenuRow"
	row1.Size=UDim2.new(1,-16,0,36)
	row1.Position=UDim2.fromOffset(8,6)
	row1.BackgroundTransparency=1
	row1.Parent=bar
	local l1=Instance.new("UIListLayout")
	l1.FillDirection=Enum.FillDirection.Horizontal
	l1.Padding=UDim.new(0,12)
	l1.VerticalAlignment=Enum.VerticalAlignment.Center
	l1.Parent=row1

	-- Brand
	local brand=Instance.new("TextLabel")
	brand.Size=UDim2.fromOffset(110,28)
	brand.BackgroundColor3=Theme.tokens.slate900
	brand.Text=" ARKHER™"
	brand.Font=Enum.Font.GothamBold
	brand.TextSize=13
	brand.TextColor3=Theme.tokens.arkherGlow
	brand.Parent=row1
	corner(brand,8)
	stroke(brand,Theme.roles.border,1)
	local ver=Instance.new("TextLabel")
	ver.Size=UDim2.fromOffset(52,28)
	ver.BackgroundTransparency=1
	ver.Text="V2  •  AAA"
	ver.Font=Enum.Font.Gotham
	ver.TextSize=10
	ver.TextColor3=Theme.tokens.slate400
	ver.Parent=row1

	local function tab(name: string, icon: string, onClick: ()->())
		local b=mkBtn(row1, icon.."  "..name, 108)
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	tab("Explorer","≡", cb.onToggleExplorer)
	tab("Properties","⚙", cb.onToggleProperties)
	-- separator
	local sep1=Instance.new("Frame"); sep1.Size=UDim2.fromOffset(1,20); sep1.BackgroundColor3=Theme.roles.border; sep1.BorderSizePixel=0; sep1.Parent=row1
	-- Editors dropdown placeholder buttons (spaced)
	local eds={"Modeler","Animator","Material","Terrain","VFX","Audio","Sequencer","Maps"}
	for _,ed in eds do
		local b=mkBtn(row1, ed, 86)
		b.TextSize=11
		b.MouseButton1Click:Connect(function() cb.onOpenEditor(ed) end)
	end
	local allBtn=mkBtn(row1, "▣  All 332", 92)
	allBtn.BackgroundColor3=Theme.tokens.slate700
	allBtn.TextColor3=Theme.tokens.white
	allBtn.MouseButton1Click:Connect(cb.onOpenPalette)

	-- right side: Singularity single button (violet) — ONLY AI entry
	local sing=mkBtn(row1, "◆  Singularity", 132, false)
	sing.BackgroundColor3=Theme.tokens.violet
	sing.TextColor3=Color3.new(1,1,1)
	sing.LayoutOrder=100
	sing.MouseButton1Click:Connect(cb.onOpenSingularity)
	-- push to right via flex: add spacer
	local spacer=Instance.new("Frame"); spacer.Size=UDim2.new(1,0,1,0); spacer.BackgroundTransparency=1; spacer.LayoutOrder=99; spacer.Parent=row1
	-- reorder: move spacer before sing via LayoutOrder trick — use UIListLayout with spacer flexible
	-- simpler: keep as is; UIListLayout will leave sing at end with gap

	-- ROW 2 — tool shelf (well separated)
	local row2=Instance.new("Frame")
	row2.Name="ToolRow"
	row2.Size=UDim2.new(1,-16,0,30)
	row2.Position=UDim2.fromOffset(8,42)
	row2.BackgroundColor3=Theme.tokens.slate900
	row2.BorderSizePixel=0
	row2.Parent=bar
	corner(row2,8)
	stroke(row2,Theme.roles.border,1)
	local pad2=Instance.new("UIPadding"); pad2.PaddingLeft=UDim.new(0,8); pad2.PaddingRight=UDim.new(0,8); pad2.PaddingTop=UDim.new(0,2); pad2.PaddingBottom=UDim.new(0,2); pad2.Parent=row2
	local l2=Instance.new("UIListLayout")
	l2.FillDirection=Enum.FillDirection.Horizontal
	l2.Padding=UDim.new(0,12)
	l2.VerticalAlignment=Enum.VerticalAlignment.Center
	l2.Parent=row2

	-- Primitive parts submenu (Block/Sphere/Cylinder/Wedge/Corner)
	local function partBtn(label:string, icon:string)
		local b=mkIcon(row2, icon, label)
		b.MouseButton1Click:Connect(function() cb.onInsert(label) end)
		-- tooltip via hover color
		b.MouseEnter:Connect(function() b.BackgroundColor3=Theme.tokens.slate700 end)
		b.MouseLeave:Connect(function() b.BackgroundColor3=Theme.tokens.slate800 end)
		return b
	end
	local lblParts=Instance.new("TextLabel")
	lblParts.Size=UDim2.fromOffset(52,28); lblParts.BackgroundTransparency=1; lblParts.Text="Insert ▸"; lblParts.Font=Enum.Font.GothamBold; lblParts.TextSize=11; lblParts.TextColor3=Theme.tokens.slate400; lblParts.Parent=row2
	partBtn("Block","▭"); partBtn("Sphere","●"); partBtn("Cylinder","⬢"); partBtn("Wedge","◤"); partBtn("CornerWedge","◣")

	local sep2=Instance.new("Frame"); sep2.Size=UDim2.fromOffset(1,20); sep2.BackgroundColor3=Theme.roles.border; sep2.BorderSizePixel=0; sep2.Parent=row2

	-- Gizmo modes
	local function gizmoBtn(mode:string, icon:string)
		local b=mkIcon(row2, icon, mode)
		b.MouseButton1Click:Connect(function() cb.onGizmo(mode) end)
		return b
	end
	local lblGizmo=Instance.new("TextLabel"); lblGizmo.Size=UDim2.fromOffset(52,28); lblGizmo.BackgroundTransparency=1; lblGizmo.Text="Gizmo ▸"; lblGizmo.Font=Enum.Font.GothamBold; lblGizmo.TextSize=11; lblGizmo.TextColor3=Theme.tokens.slate400; lblGizmo.Parent=row2
	gizmoBtn("Select","↖"); gizmoBtn("Move","✥"); gizmoBtn("Rotate","↻"); gizmoBtn("Scale","⤢")

	local sep3=Instance.new("Frame"); sep3.Size=UDim2.fromOffset(1,20); sep3.BackgroundColor3=Theme.roles.border; sep3.BorderSizePixel=0; sep3.Parent=row2

	local fly=mkBtn(row2,"✈  Fly  (F)", 92)
	fly.MouseButton1Click:Connect(cb.onToggleFly)
	local maps=mkBtn(row2,"🛰  Maps / Biomes", 128)
	maps.MouseButton1Click:Connect(cb.onOpenMaps)

	-- status hint
	local hint=Instance.new("TextLabel")
	hint.Size=UDim2.fromOffset(220,28)
	hint.BackgroundTransparency=1
	hint.Text="Tip: Select in Explorer → edit in Properties (Ctrl+Z)"
	hint.Font=Enum.Font.Gotham
	hint.TextSize=10
	hint.TextColor3=Theme.tokens.slate400
	hint.TextXAlignment=Enum.TextXAlignment.Right
	hint.Parent=row2

	return self
end

return TopBar
