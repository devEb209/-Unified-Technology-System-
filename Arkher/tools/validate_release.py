#!/usr/bin/env python3
"""Validate the shipped Roblox files: parse them back, confirm every ModuleScript
source survived escaping byte-for-byte, and confirm the boot/HUD scripts are present."""
import os, sys, xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

def collect_sources():
    out = {}
    for dirpath, _, files in os.walk(SRC):
        for f in files:
            if f.endswith(".lua"):
                rel = os.path.relpath(os.path.join(dirpath, f), SRC).replace("\\", "/")
                out[rel[:-4]] = open(os.path.join(dirpath, f), encoding="utf-8").read()
    return out

def walk(item, prefix, found):
    name = None
    for prop in item.findall("./Properties/string[@name='Name']"):
        name = prop.text or ""
    cls = item.get("class")
    path = name if prefix == "" else prefix + "/" + name
    if cls == "ModuleScript":
        src = item.find("./Properties/ProtectedString[@name='Source']")
        found[path] = src.text if src is not None and src.text else ""
    elif cls in ("Script", "LocalScript"):
        found["!" + (name or "")] = True
    for child in item.findall("./Item"):
        walk(child, "" if cls in ("ReplicatedStorage",) else path, found)

def validate(path, expect_place=False):
    tree = ET.parse(path)
    root = tree.getroot()
    found = {}
    for item in root.findall("./Item"):
        walk(item, "", found)
    sources = collect_sources()
    modules = {k: v for k, v in found.items() if not k.startswith("!")}
    # strip the ARKHER/ prefix
    normalized = {}
    for k, v in modules.items():
        parts = k.split("/")
        while parts and parts[0] == "ARKHER":
            parts = parts[1:]
        normalized["/".join(parts)] = v
    missing = [k for k in sources if k not in normalized]
    mismatched = [k for k in sources if k in normalized and normalized[k] != sources[k]]
    print("%s" % os.path.basename(path))
    print("  modules in file : %d" % len(normalized))
    print("  modules on disk : %d" % len(sources))
    print("  missing         : %d" % len(missing))
    print("  byte mismatches : %d" % len(mismatched))
    print("  boot script     : %s" % ("yes" if found.get("!ARKHER_Boot") else "NO"))
    print("  hud script      : %s" % ("yes" if found.get("!ARKHER_HUD") else "NO"))
    print("  plugin host     : %s" % ("yes" if found.get("!ARKHER") else "-"))
    scripts_ok = (found.get("!ARKHER_Boot") and found.get("!ARKHER_HUD")) or found.get("!ARKHER")
    ok = not missing and not mismatched and scripts_ok
    if missing[:3]: print("  e.g. missing:", missing[:3])
    if mismatched[:3]: print("  e.g. mismatch:", mismatched[:3])
    return ok

ROUND = os.environ.get("ARKHER_ROUND", "ROUND4")
allok = True
for f, place in (("ARKHER_V1_%s.rbxmx" % ROUND, False), ("ARKHER_V1_%s.rbxlx" % ROUND, True),
                 ("ARKHER_V1_STUDIO_PLUGIN.rbxmx", False)):
    allok = validate(os.path.join(ROOT, "Releases", f), place) and allok
print("RELEASE VALIDATION:", "PASS" if allok else "FAIL")
sys.exit(0 if allok else 1)
