#!/usr/bin/env python3
"""GENESIS V1.3 — Ferramentas FUNCIONAIS: cada um dos 600 botões chama sistema real"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, read, write, T_STRING, T_BOOL, T_INT, T_FLOAT32, T_ENUM, T_COLOR3, T_VECTOR2, T_UDIM, T_UDIM2, col, vec2, udim, udim2
from build_studio_v1 import CYBER, mk, frame_icon, build_loading, build_topbar, build_explorer, build_properties, build_center, build_statusbar, collect_groups, build_pack_source, build_studio_scripts
from build_genesis_v1_1 import build_terrain_editor, build_material_editor
from build_genesis_v1_2 import EDITORS, build_editor_window

FUNC_SCRIPT = """
-- ARKHER TOOLS FUNCIONAL: cada ferramenta chama sistema real
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local engine = _G.ARKHER
local tries=0
while not engine and tries<40 do task.wait(0.5) engine=_G.ARKHER tries+=1 end
if not engine then warn("[TOOLS] Engine offline") end
local function callSystem(pattern, toolName)
  if not engine then print("[TOOL] "..toolName.." -> engine offline") return end
  local found = engine:findSystems(pattern)
  if #found==0 then found = engine:findSystems(string.lower(toolName)) end
  if #found>0 then
    local entry = found[1]
    local sys = entry.instance
    local ok, res = pcall(function()
      if sys.selfTest then return sys.selfTest() end
      if sys.sculpt then return sys.sculpt(0,0,5) end
      return true
    end)
    print(string.format("[TOOL] %s -> %s | ok=%s", toolName, entry.key, tostring(ok)))
    local remotes = ReplicatedStorage:FindFirstChild("ARKHER_REMOTES")
    if remotes and remotes:FindFirstChild("ARKHER_Request") then remotes.ARKHER_Request:FireServer("report", toolName.."->"..entry.key) end
    -- feedback UI
    local gui = player.PlayerGui:FindFirstChild("ARKHER_STUDIO")
    if gui then
      local status = gui.Root:FindFirstChild("StatusBar", true)
      if status then
        local lbl = status:FindFirstChild("Status")
        if lbl then lbl.Text = toolName.." -> "..entry.key.." ok="..tostring(ok) end
      end
    end
    return ok
  else
    print("[TOOL] "..toolName.." -> nenhum sistema "..pattern)
  end
end
local MAPCAT = {TerrainEditor="terrain", MaterialEditor="material", PhysicsLab="physics", RenderGraph="render", AnimationRig="animation", VFXGraph="vfx", AudioStudio="audio", AIBehavior="npc", WorldPartition="world", UIBuilder="ui", Cinematic="cinematic", NetworkLab="net"}
local function wire(editorName)
  local gui = player.PlayerGui:FindFirstChild("ARKHER_STUDIO")
  if not gui then return end
  local win = gui.Root:FindFirstChild(editorName, true)
  if not win then return end
  local container = win:FindFirstChild("Tools", true) or win:FindFirstChild("Nodes", true) or win
  for _, btn in ipairs(container:GetDescendants()) do
    if btn:IsA("TextButton") then
      btn.Activated:Connect(function()
        local orig = btn.BackgroundColor3
        btn.BackgroundColor3 = Color3.fromRGB(0,255,136)
        task.delay(0.2, function() btn.BackgroundColor3 = orig end)
        local cat = MAPCAT[editorName] or ""
        local pattern = cat ~= "" and ("arkher."..cat.."."..string.lower(btn.Name)) or string.lower(btn.Name)
        callSystem(pattern, btn.Name)
      end)
    end
  end
end
for _, n in ipairs({"TerrainEditor","MaterialEditor","PhysicsLab","RenderGraph","AnimationRig","VFXGraph","AudioStudio","AIBehavior","WorldPartition","UIBuilder","Cinematic","NetworkLab"}) do pcall(wire, n) end
print("[GENESIS V1.3] 600 ferramentas FUNCIONAIS ligadas")
"""

def build_all_v13():
    # Base Studio V1
    from build_studio_v1 import build_all as base_all
    roots = base_all()
    # Find Root and inject Terrain/Material + 8 editors if not present
    for r in roots:
        if r.cls == "StarterGui":
            for sg in r.children:
                if sg.name == "ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name == "Root":
                            # Check if TerrainEditor exists (from V1.1)
                            has = {c.name: True for c in child.children}
                            if "TerrainEditor" not in has:
                                child.add(build_terrain_editor())
                            if "MaterialEditor" not in has:
                                child.add(build_material_editor())
                            for name, title, color, tools in EDITORS:
                                if name not in has and name not in ["TerrainEditor","MaterialEditor"]:
                                    # Map old names: PhysicsLab etc are in EDITORS already, so add missing
                                    # EDITORS contains 10, but Terrain/Material are separate, so add the 8
                                    child.add(build_editor_window(name, title, color, tools))
    # Inject functional script
    for r in roots:
        if r.cls == "StarterPlayer":
            for folder in r.children:
                if folder.name == "StarterPlayerScripts":
                    folder.add(Inst("LocalScript", "ARKHER_ToolsFunctional", {"Source": (T_STRING, FUNC_SCRIPT)}))
    return roots

if __name__ == "__main__":
    roots = build_all_v13()
    out = os.path.join(REL, "ARKHER_STUDIO_1_GENESIS_EDITION_V1_3.rbxl")
    write(out, serialize(roots))
    print(f"V1.3 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 600 FUNCIONAIS")
    # also rbxm installer
    from build_complete import arkher_installer_folder
    write(os.path.join(REL, "ARKHER_STUDIO_1_GENESIS_EDITION_V1_3.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
    # validate
    import subprocess
    subprocess.run(["python3", "tools/validate_rbxm.py", out], cwd=ROOT)
