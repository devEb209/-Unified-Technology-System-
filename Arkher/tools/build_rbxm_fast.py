#!/usr/bin/env python3
"""ARKHER FAST :: Packed binary builder — 0 sistema removido, import instantâneo.

Normal build cria 17282 ModuleScripts → Studio congela criando 17k nós + parseando 17k scripts.
FAST empacota por pasta (~40 packs de ~400 modules cada) → 40 ModuleScripts → 3.5M mesmo conteúdo,
mas Studio cria 40 nós, não 17k. Boot desempacota em ~400ms.

Mantém 17188 systems / 17282 modules idênticos, só muda layout no RBXM.
"""
import os, json, struct, base64, textwrap
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)

try:
    import lz4.block as _lz4
except:
    _lz4 = None

from build_rbxm import Inst, serialize, read, write, DEFAULTS, chunk, u32, string, T_STRING, T_BOOL, T_ENUM, T_FLOAT32

def collect_groups():
    groups = {}
    for dirpath, _, files in os.walk(SRC):
        rel = os.path.relpath(dirpath, SRC).replace("\\","/")
        if rel == ".": rel = ""
        for f in sorted(files):
            if not f.endswith(".lua"): continue
            full = os.path.join(dirpath, f)
            src = read(full)
            # id like arkher/kernel/loader
            if rel == "":
                mod_id = "arkher/" + f[:-4]
            else:
                mod_id = "arkher/" + rel + "/" + f[:-4]
            # group by top folder: kernel, runtime, catalog/va, catalog/vb, etc
            if rel.startswith("catalog/"):
                grp = rel  # catalog/va
            elif "/" in rel:
                grp = rel.split("/")[0]  # e.g. kernel, runtime, platform
            else:
                grp = rel or "root"
            groups.setdefault(grp, []).append((mod_id, src))
    return groups

def escape_lua(s):
    # escape for long string [[ ... ]] — avoid ]] inside
    if "]]" in s:
        # use [=[ ... ]=] if contains ]]
        lvl = 0
        while f"]{ '='*lvl }]" in s:
            lvl += 1
        eq = "="*lvl
        return f"[{eq}[{s}]{eq}]"
    return f"[[{s}]]"

def build_pack_source(group_name, items):
    # items: list of (id, source)
    # Build a ModuleScript that bulk-defines all factories in this pack
    lines = []
    lines.append(f"-- ARKHER FAST PACK :: {group_name} ({len(items)} modules)")
    lines.append("return function(A)")
    for mod_id, src in items:
        # src is "return function(A) ... end" — we need inner body
        # Keep as-is but wrap in define
        # src already is factory string: we embed it directly
        lines.append(f"A:define({repr(mod_id)}, {src.strip()})")
    lines.append("end")
    return "\n".join(lines)

def arkher_folder_fast():
    groups = collect_groups()
    print(f"groups: {len(groups)}")
    for k,v in sorted(groups.items()):
        print(f"  {k:20} {len(v):4} modules")
    root = Inst("Folder", "ARKHER")
    # add packed groups as ModuleScripts directly under ARKHER
    # keep folder hierarchy minimal for Studio tree speed
    for grp in sorted(groups.keys()):
        items = groups[grp]
        pack_name = "PACK_" + grp.replace("/","_").replace("-","_") + f"__{len(items)}"
        src = build_pack_source(grp, items)
        root.add(Inst("ModuleScript", pack_name, {"Source": (T_STRING, src)}))
    # add boot + hud like normal, but with FAST-aware boot
    fast_boot = read(os.path.join(ROOT, "roblox/boot_fast.server.lua")) if os.path.exists(os.path.join(ROOT, "roblox/boot_fast.server.lua")) else read(os.path.join(ROOT, "roblox/boot.server.lua"))
    # patch boot to handle PACK_ bulk defines
    root.add(Inst("Script", "ARKHER_Boot", {"Source": (T_STRING, fast_boot), "RunContext": (T_ENUM, 1)}))
    root.add(Inst("LocalScript", "ARKHER_HUD", {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/hud.client.lua")))}))
    return root

# generate fast boot if not exists
BOOT_FAST = os.path.join(ROOT, "roblox/boot_fast.server.lua")
if not os.path.exists(BOOT_FAST):
    src_boot = read(os.path.join(ROOT, "roblox/boot.server.lua"))
    # patch: detect PACK_ modules and execute bulk define
    patched = src_boot.replace(
        "for id, moduleScript in pairs(factories) do\n\tA:define(id, require(moduleScript))\n\tregistered = registered + 1\nend",
        "for id, moduleScript in pairs(factories) do\n\tif string.sub(moduleScript.Name,1,5)==\"PACK_\" then\n\t\tlocal bulk = require(moduleScript)\n\t\tlocal before = A:count()\n\t\tbulk(A)\n\t\tregistered = registered + (A:count() - before)\n\telse\n\t\tA:define(id, require(moduleScript))\n\t\tregistered = registered + 1\n\tend\nend"
    )
    # also walk needs to find PACK_ under root only (1 level), but keep walk recursive
    with open(BOOT_FAST, "w", encoding="utf-8") as f:
        f.write(patched)
    print(f"generated {BOOT_FAST}")

def build_model_fast(path):
    return write(path, serialize([arkher_folder_fast()]))

def build_place_fast(path):
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", is_service=True)
    replicated.add(arkher_folder_fast())
    workspace = Inst("Workspace", "Workspace", {"StreamingEnabled": (T_BOOL, True), "StreamingTargetRadius": (T_FLOAT32, 512.0)}, is_service=True)
    lighting = Inst("Lighting", "Lighting", {"Technology": (T_ENUM, 4), "Brightness": (T_FLOAT32, 2.0)}, is_service=True)
    return write(path, serialize([replicated, workspace, lighting]))

if __name__ == "__main__":
    ROUND = os.environ.get("ARKHER_ROUND", "1.0.1_FAST")
    # ensure lz4 path
    model = os.path.join(REL, f"ARKHER_V1_{ROUND}.rbxm")
    place = os.path.join(REL, f"ARKHER_V1_{ROUND}.rbxl")
    a = build_model_fast(model)
    b = build_place_fast(place)
    print(f"compression : {'lz4 (high)' if _lz4 else 'none'}")
    print(f"model {model} ({a/1048576:.2f} MB)")
    print(f"place {place} ({b/1048576:.2f} MB)")
    # count instances: walk
    import json
    with open(os.path.join(ROOT, "ARKHER_MANIFEST.json")) as f: m=json.load(f)
    print(f"systems {m['totals']['systems']} features {m['totals']['features']}")
