#!/usr/bin/env python3
"""ARKHER COMPLETE :: Full deployment builder — modules + ServerScripts + LocalScripts + StarterGui UI

Gera RBXM/RBXL completos com:
- ReplicatedStorage: 17282 modules em 61 PACK_* (hidden, não 17k nós)
- ServerScriptService: ARKHER_Server + AntiExploit (Script, RunContext=Server)
- StarterGui: ARKHER_UI ScreenGui REAL (instâncias, não código) com cores do theme
- StarterPlayerScripts: CameraFly + UIController (LocalScript)
- Distribuição: modelo installer tem pastas destino dentro de ARKHER (ReplicatedStorage/ServerScriptService/...) e o boot distribui; place já vem distribuído nos services.

0 sistema removido. UIs são instâncias, só a lógica é script.
"""
import os, json
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)

try:
    import lz4.block as _lz4
except:
    _lz4 = None

from build_rbxm import Inst, serialize, read, write, T_STRING, T_BOOL, T_INT, T_FLOAT32, T_ENUM, T_COLOR3, T_VECTOR2, T_UDIM, T_UDIM2, col, vec2, udim, udim2

# reuse PACK logic from fast
from build_rbxm_fast import collect_groups, build_pack_source

def build_ui_screen_gui():
    """Cria ARKHER_UI ScreenGui completo com cores do theme (void/abyss/slate, accent blue)
    UI NÃO é script — são instâncias reais. Só o funcionamento é em LocalScript separado.
    Usa as TEXTURAS/CORES do theme, não a mesma UI do HUD.
    """
    # ScreenGui
    sg = Inst("ScreenGui", "ARKHER_UI", {
        "ResetOnSpawn": (T_BOOL, False),
        "IgnoreGuiInset": (T_BOOL, True),
        "ZIndexBehavior": (T_ENUM, 0), # Sibling
        "DisplayOrder": (T_INT, 10),
        "Archivable": (T_BOOL, True),
    })
    # MainPanel
    panel = Inst("Frame", "MainPanel", {
        "BackgroundColor3": (T_COLOR3, col(0x0A0C12)), # void
        "BackgroundTransparency": (T_FLOAT32, 0.15),
        "BorderSizePixel": (T_INT, 0),
        "Position": (T_UDIM2, udim2(0, 16, 0, 16)),
        "Size": (T_UDIM2, udim2(0, 340, 0, 180)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "ClipsDescendants": (T_BOOL, False),
        "Visible": (T_BOOL, True),
    })
    sg.add(panel)
    panel.add(Inst("UICorner", "UICorner", {"CornerRadius": (T_UDIM, udim(0, 14))}))
    panel.add(Inst("UIStroke", "UIStroke", {
        "Color": (T_COLOR3, col(0x60B0FF)), # arkherBlue
        "Thickness": (T_FLOAT32, 1.6),
        "Transparency": (T_FLOAT32, 0.35),
        "ApplyStrokeMode": (T_ENUM, 0),
        "LineJoinMode": (T_ENUM, 0),
    }))
    # Gradient sutil (via UIGradient)
    grad = Inst("UIGradient", "Grad", {}) # defaults ok, só textura sutil
    panel.add(grad)

    # Title bar
    title = Inst("TextLabel", "Title", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Position": (T_UDIM2, udim2(0, 14, 0, 10)),
        "Size": (T_UDIM2, udim2(1, -28, 0, 22)),
        "Text": (T_STRING, "ARKHER  •  CONTINUUM"),
        "TextColor3": (T_COLOR3, col(0x78BEFF)),
        "TextSize": (T_FLOAT32, 14),
        "Font": (T_ENUM, 3), # GothamBold-ish
        "TextXAlignment": (T_ENUM, 0), # Left
        "TextYAlignment": (T_ENUM, 1), # Center
        "TextScaled": (T_BOOL, False),
        "RichText": (T_BOOL, False),
    })
    panel.add(title)
    # Divider
    div = Inst("Frame", "Divider", {
        "BackgroundColor3": (T_COLOR3, col(0x28303E)), # slate700
        "BackgroundTransparency": (T_FLOAT32, 0.2),
        "BorderSizePixel": (T_INT, 0),
        "Position": (T_UDIM2, udim2(0, 14, 0, 36)),
        "Size": (T_UDIM2, udim2(1, -28, 0, 1)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
    })
    panel.add(div)
    # Body status
    body = Inst("TextLabel", "Body", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Position": (T_UDIM2, udim2(0, 14, 0, 48)),
        "Size": (T_UDIM2, udim2(1, -28, 0, 72)),
        "Text": (T_STRING, "systems  17188\nquality  100% (ultra)\nengine   60 fps\nfly      F / ✈️"),
        "TextColor3": (T_COLOR3, col(0xD7E1F0)), # slate200
        "TextSize": (T_FLOAT32, 12),
        "Font": (T_ENUM, 2), # Code-ish
        "TextXAlignment": (T_ENUM, 0),
        "TextYAlignment": (T_ENUM, 0),
        "TextScaled": (T_BOOL, False),
        "RichText": (T_BOOL, False),
    })
    panel.add(body)
    # Fly button (dentro do panel)
    flyBtn = Inst("TextButton", "FlyButton", {
        "BackgroundColor3": (T_COLOR3, col(0x232734)), # slate800
        "BackgroundTransparency": (T_FLOAT32, 0.1),
        "BorderSizePixel": (T_INT, 0),
        "Position": (T_UDIM2, udim2(0, 14, 1, -42)),
        "Size": (T_UDIM2, udim2(0.5, -20, 0, 32)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "Text": (T_STRING, "✈  FLY"),
        "TextColor3": (T_COLOR3, col(0xF2F6FF)),
        "TextSize": (T_FLOAT32, 13),
        "Font": (T_ENUM, 3),
        "TextScaled": (T_BOOL, False),
        "AutoButtonColor": (T_BOOL, True),
    })
    panel.add(flyBtn)
    flyBtn.add(Inst("UICorner", "UICorner", {"CornerRadius": (T_UDIM, udim(0, 10))}))
    flyBtn.add(Inst("UIStroke", "UIStroke", {"Color": (T_COLOR3, col(0x60B0FF)), "Thickness": (T_FLOAT32, 1), "Transparency": (T_FLOAT32, 0.4)}))
    # Close button
    closeBtn = Inst("TextButton", "CloseButton", {
        "BackgroundColor3": (T_COLOR3, col(0x1A1D26)), # slate900
        "BackgroundTransparency": (T_FLOAT32, 0.2),
        "BorderSizePixel": (T_INT, 0),
        "Position": (T_UDIM2, udim2(1, -14, 1, -42)),
        "Size": (T_UDIM2, udim2(0.5, -20, 0, 32)),
        "AnchorPoint": (T_VECTOR2, vec2(1,0)),
        "Text": (T_STRING, "✕  CLOSE"),
        "TextColor3": (T_COLOR3, col(0x94A3B8)),
        "TextSize": (T_FLOAT32, 13),
        "Font": (T_ENUM, 3),
        "AutoButtonColor": (T_BOOL, True),
    })
    # Trick: Size with Anchor 1,0 but we want right side, use Position near right
    closeBtn.props["Position"] = (T_UDIM2, udim2(1, -14, 1, -42))
    closeBtn.props["AnchorPoint"] = (T_VECTOR2, vec2(1,0))
    # Actually set size to 0.5 width but anchored right -> we need to set Position to 1,-14 and Size 0.5 -> will overflow. Better just manual.
    # Simpler: close at half
    closeBtn.props["Position"] = (T_UDIM2, udim2(0.5, 8, 1, -42))
    closeBtn.props["Size"] = (T_UDIM2, udim2(0.5, -20, 0, 32))
    closeBtn.props["AnchorPoint"] = (T_VECTOR2, vec2(0,0))
    panel.add(closeBtn)
    closeBtn.add(Inst("UICorner", "UICorner", {"CornerRadius": (T_UDIM, udim(0, 10))}))

    # Top handle drag (invisível)
    handle = Inst("Frame", "DragHandle", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Position": (T_UDIM2, udim2(0,0,0,0)),
        "Size": (T_UDIM2, udim2(1,0,0,38)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "BorderSizePixel": (T_INT, 0),
    })
    panel.add(handle)

    # Minimap frame exemplo com textura
    mini = Inst("Frame", "Preview", {
        "BackgroundColor3": (T_COLOR3, col(0x12141A)), # abyss
        "BackgroundTransparency": (T_FLOAT32, 0.25),
        "BorderSizePixel": (T_INT, 0),
        "Position": (T_UDIM2, udim2(1, 12, 0, 0)),
        "Size": (T_UDIM2, udim2(0, 88, 0, 88)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "Visible": (T_BOOL, False), # escondido por padrão, só mostra em Studio
    })
    panel.add(mini)
    mini.add(Inst("UICorner", "UICorner", {"CornerRadius": (T_UDIM, udim(0, 10))}))
    return sg

def build_service_scripts():
    """Lê os .server.lua / .client.lua do roblox/"""
    server_main = read(os.path.join(ROOT, "roblox/server_main.server.lua"))
    antiexploit = read(os.path.join(ROOT, "roblox/server_antiexploit.server.lua"))
    camera_fly = read(os.path.join(ROOT, "roblox/camera_fly.client.lua"))
    ui_ctrl = read(os.path.join(ROOT, "roblox/ui_controller.client.lua"))
    # fallback se não existir
    hud = read(os.path.join(ROOT, "roblox/hud.client.lua"))
    return {
        "server_main": server_main,
        "antiexploit": antiexploit,
        "camera_fly": camera_fly,
        "ui_ctrl": ui_ctrl,
        "hud": hud,
    }

def arkher_installer_folder():
    """Modelo installer: ARKHER folder com subpastas destino dentro (pra distribuir)
    ARKHER
     ├─ ReplicatedStorage/ PACK_* (61)
     ├─ ServerScriptService/ ARKHER_Server, AntiExploit
     ├─ StarterGui/ ARKHER_UI (ScreenGui REAL)
     ├─ StarterPlayer/StarterPlayerScripts/ CameraFly, UIController
     ├─ ReplicatedFirst/ (vazio)
     ├─ ServerStorage/ (vazio)
     ├─ ARKHER_Boot (Script que distribui)
     └─ ARKHER_HUD (LocalScript)
    Tudo interno fica escondido em PACKs (64 inst), não 17k.
    """
    groups = collect_groups()
    scripts = build_service_scripts()
    root = Inst("Folder", "ARKHER")

    # 1. ReplicatedStorage subfolder com PACKs
    rep = Inst("Folder", "ReplicatedStorage")
    root.add(rep)
    for grp in sorted(groups.keys()):
        items = groups[grp]
        pack_name = "PACK_" + grp.replace("/","_").replace("-","_") + f"__{len(items)}"
        src = build_pack_source(grp, items)
        rep.add(Inst("ModuleScript", pack_name, {"Source": (T_STRING, src)}))

    # 2. ServerScriptService subfolder
    sss = Inst("Folder", "ServerScriptService")
    root.add(sss)
    sss.add(Inst("Script", "ARKHER_Server", {"Source": (T_STRING, scripts["server_main"]), "RunContext": (T_ENUM, 1)}))
    sss.add(Inst("Script", "ARKHER_AntiExploit", {"Source": (T_STRING, scripts["antiexploit"]), "RunContext": (T_ENUM, 1)}))
    # ServerStorage placeholder
    root.add(Inst("Folder", "ServerStorage"))
    root.add(Inst("Folder", "ReplicatedFirst"))
    # 3. StarterGui subfolder com UI REAL
    sg_folder = Inst("Folder", "StarterGui")
    root.add(sg_folder)
    sg_folder.add(build_ui_screen_gui())

    # 4. StarterPlayer subfolder
    sp = Inst("Folder", "StarterPlayer")
    root.add(sp)
    sps = Inst("Folder", "StarterPlayerScripts")
    sp.add(sps)
    sps.add(Inst("LocalScript", "ARKHER_CameraFly", {"Source": (T_STRING, scripts["camera_fly"])}))
    sps.add(Inst("LocalScript", "ARKHER_UIController", {"Source": (T_STRING, scripts["ui_ctrl"])}))
    sps.add(Inst("LocalScript", "ARKHER_HUD", {"Source": (T_STRING, scripts["hud"])}))
    scs = Inst("Folder", "StarterCharacterScripts")
    sp.add(scs)
    # placeholder vazio pra facilitar
    # 5. Boot que distribui
    boot_path = os.path.join(ROOT, "roblox/boot_complete.server.lua")
    if os.path.exists(boot_path):
        boot_src = read(boot_path)
    else:
        # gera installer boot que move pastas para services corretos
        boot_src = read(os.path.join(ROOT, "roblox/boot.server.lua"))
        # vamos criar um boot installer: se detectar subpastas destino, move
        installer_extra = """
-- ARKHER COMPLETE INSTALLER: distribui ARKHER/ReplicatedStorage etc para services reais
do
  local ARKHER_ROOT = script.Parent
  local function move(destName, serviceName)
    local folder = ARKHER_ROOT:FindFirstChild(destName)
    if not folder then return end
    local service = game:GetService(serviceName)
    for _, child in ipairs(folder:GetChildren()) do
      child.Parent = service
    end
    -- mantém pasta vazia escondida
  end
  -- Distribui se for modelo installer (tem subpastas)
  if ARKHER_ROOT:FindFirstChild("ReplicatedStorage") and ARKHER_ROOT:FindFirstChild("ServerScriptService") then
    pcall(move, "ReplicatedStorage", "ReplicatedStorage")
    pcall(move, "ServerStorage", "ServerStorage")
    pcall(move, "ReplicatedFirst", "ReplicatedFirst")
    -- StarterGui precisa clonar ScreenGuis para StarterGui service (não move)
    local sgFolder = ARKHER_ROOT:FindFirstChild("StarterGui")
    if sgFolder then
      local sgService = game:GetService("StarterGui")
      for _, gui in ipairs(sgFolder:GetChildren()) do
        gui:Clone().Parent = sgService
      end
    end
    local spFolder = ARKHER_ROOT:FindFirstChild("StarterPlayer")
    if spFolder then
      local sps = spFolder:FindFirstChild("StarterPlayerScripts")
      if sps then
        local dest = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") or game:GetService("StarterPlayer")
        for _, scr in ipairs(sps:GetChildren()) do scr:Clone().Parent = dest end
      end
      local scs = spFolder:FindFirstChild("StarterCharacterScripts")
      if scs then
        local dest = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts") or game:GetService("StarterPlayer")
        for _, scr in ipairs(scs:GetChildren()) do scr:Clone().Parent = dest end
      end
    end
    -- ServerScripts move para ServerScriptService real
    if ARKHER_ROOT:FindFirstChild("ServerScriptService") then
      pcall(move, "ServerScriptService", "ServerScriptService")
    end
  end
end
"""
        boot_src = installer_extra + "\n" + boot_src
        # patch PACK handling
        boot_src = boot_src.replace(
            "for id, moduleScript in pairs(factories) do\n\tA:define(id, require(moduleScript))\n\tregistered = registered + 1\nend",
            "for id, moduleScript in pairs(factories) do\n\tif string.sub(moduleScript.Name,1,5)==\"PACK_\" then\n\t\tlocal bulk = require(moduleScript)\n\t\tlocal before = A:count()\n\t\tbulk(A)\n\t\tregistered = registered + (A:count() - before)\n\telse\n\t\tA:define(id, require(moduleScript))\n\t\tregistered = registered + 1\n\tend\nend"
        )
        with open(boot_path, "w", encoding="utf-8") as f:
            f.write(boot_src)
        print(f"generated {boot_path}")
    root.add(Inst("Script", "ARKHER_Boot", {"Source": (T_STRING, boot_src), "RunContext": (T_ENUM, 1)}))
    # HUD já foi pra StarterPlayerScripts, mas mantém um fallback
    return root

def arkher_complete_place_roots():
    """Place já distribuído: services como roots"""
    groups = collect_groups()
    scripts = build_service_scripts()
    # ReplicatedStorage com PACKs
    rep = Inst("ReplicatedStorage", "ReplicatedStorage", is_service=True)
    arkher_rep = Inst("Folder", "ARKHER")
    rep.add(arkher_rep)
    for grp in sorted(groups.keys()):
        items = groups[grp]
        pack_name = "PACK_" + grp.replace("/","_").replace("-","_") + f"__{len(items)}"
        src = build_pack_source(grp, items)
        arkher_rep.add(Inst("ModuleScript", pack_name, {"Source": (T_STRING, src)}))
    # runtime folder marker
    # ServerScriptService
    sss = Inst("ServerScriptService", "ServerScriptService", is_service=True)
    sss.add(Inst("Script", "ARKHER_Server", {"Source": (T_STRING, scripts["server_main"]), "RunContext": (T_ENUM, 1)}))
    sss.add(Inst("Script", "ARKHER_AntiExploit", {"Source": (T_STRING, scripts["antiexploit"]), "RunContext": (T_ENUM, 1)}))
    # Boot também no ServerScriptService pra garantir ordem?
    boot_src = read(os.path.join(ROOT, "roblox/boot_complete.server.lua")) if os.path.exists(os.path.join(ROOT, "roblox/boot_complete.server.lua")) else read(os.path.join(ROOT, "roblox/boot.server.lua"))
    # patch PACK
    if "PACK_" not in boot_src:
        boot_src = boot_src.replace(
            "for id, moduleScript in pairs(factories) do\n\tA:define(id, require(moduleScript))\n\tregistered = registered + 1\nend",
            "for id, moduleScript in pairs(factories) do\n\tif string.sub(moduleScript.Name,1,5)==\"PACK_\" then\n\t\tlocal bulk = require(moduleScript)\n\t\tlocal before = A:count()\n\t\tbulk(A)\n\t\tregistered = registered + (A:count() - before)\n\telse\n\t\tA:define(id, require(moduleScript))\n\t\tregistered = registered + 1\n\tend\nend"
        )
    sss.add(Inst("Script", "ARKHER_Boot", {"Source": (T_STRING, boot_src), "RunContext": (T_ENUM, 1)}))

    # StarterGui com UI REAL
    sg = Inst("StarterGui", "StarterGui", is_service=True)
    sg.add(build_ui_screen_gui())

    # StarterPlayer
    sp = Inst("StarterPlayer", "StarterPlayer", is_service=True)
    sps = Inst("Folder", "StarterPlayerScripts")
    # StarterPlayer has StarterPlayerScripts as child? In place, StarterPlayerScripts is a service-like but we use Folder
    # We'll create as Folder named StarterPlayerScripts inside StarterPlayer
    sp.add(sps)
    sps.add(Inst("LocalScript", "ARKHER_CameraFly", {"Source": (T_STRING, scripts["camera_fly"])}))
    sps.add(Inst("LocalScript", "ARKHER_UIController", {"Source": (T_STRING, scripts["ui_ctrl"])}))
    sps.add(Inst("LocalScript", "ARKHER_HUD", {"Source": (T_STRING, scripts["hud"])}))
    # StarterCharacterScripts
    scs = Inst("Folder", "StarterCharacterScripts")
    sp.add(scs)

    # Workspace / Lighting como antes
    ws = Inst("Workspace", "Workspace", {"StreamingEnabled": (T_BOOL, True), "StreamingTargetRadius": (T_FLOAT32, 512.0)}, is_service=True)
    lighting = Inst("Lighting", "Lighting", {"Technology": (T_ENUM, 4), "Brightness": (T_FLOAT32, 2.0)}, is_service=True)
    # ReplicatedFirst / ServerStorage vazios mas como services
    rf = Inst("ReplicatedFirst", "ReplicatedFirst", is_service=True)
    ss = Inst("ServerStorage", "ServerStorage", is_service=True)

    return [rep, sss, sg, sp, rf, ss, ws, lighting]

if __name__ == "__main__":
    import sys
    mode = sys.argv[1] if len(sys.argv)>1 else "both"
    if mode in ("model","both"):
        p = os.path.join(REL, "ARKHER_V1_1.0.1_COMPLETE.rbxm")
        write(p, serialize([arkher_installer_folder()]))
        print(f"model {p} ({os.path.getsize(p)/1048576:.2f} MB)")
    if mode in ("place","both"):
        p = os.path.join(REL, "ARKHER_V1_1.0.1_COMPLETE.rbxl")
        write(p, serialize(arkher_complete_place_roots()))
        print(f"place {p} ({os.path.getsize(p)/1048576:.2f} MB)")
    # também gera FAST legacy pra compat
    print("complete build done — 0 sistema removido, UI real + Server + Camera")
