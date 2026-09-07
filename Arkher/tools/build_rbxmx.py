#!/usr/bin/env python3
"""ARKHER V1 :: Roblox model/place builder.

Produces REAL Roblox XML files (.rbxmx model and .rbxlx place) containing every ARKHER
module as a ModuleScript, the boot Script and the HUD LocalScript. No binary guessing:
the XML format is the documented, Studio-native one, and the output is parsed back and
validated before it is written to Releases/.
"""
import os, sys, json, xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)

_ref = [0]
def ref():
    _ref[0] += 1
    return "ARK%d" % _ref[0]

def esc(text):
    out = []
    for ch in text:
        o = ord(ch)
        if ch == "&": out.append("&amp;")
        elif ch == "<": out.append("&lt;")
        elif ch == ">": out.append("&gt;")
        elif o < 32 and ch not in "\n\t\r": out.append(" ")
        else: out.append(ch)
    return "".join(out)

def module_item(name, source, out):
    out.append('<Item class="ModuleScript" referent="%s">' % ref())
    out.append('<Properties>')
    out.append('<string name="Name">%s</string>' % esc(name))
    out.append('<ProtectedString name="Source">%s</ProtectedString>' % esc(source))
    out.append('</Properties>')
    out.append('</Item>')

def script_item(cls, name, source, out, run_context=None):
    out.append('<Item class="%s" referent="%s">' % (cls, ref()))
    out.append('<Properties>')
    out.append('<bool name="Disabled">false</bool>')
    out.append('<string name="Name">%s</string>' % esc(name))
    if run_context is not None:
        out.append('<token name="RunContext">%d</token>' % run_context)
    out.append('<ProtectedString name="Source">%s</ProtectedString>' % esc(source))
    out.append('</Properties>')
    out.append('</Item>')

def folder_open(name, out):
    out.append('<Item class="Folder" referent="%s">' % ref())
    out.append('<Properties><string name="Name">%s</string></Properties>' % esc(name))

def folder_close(out):
    out.append('</Item>')

def emit_tree(directory, out):
    entries = sorted(os.listdir(directory))
    for e in entries:
        p = os.path.join(directory, e)
        if os.path.isdir(p):
            folder_open(e, out)
            emit_tree(p, out)
            folder_close(out)
        elif e.endswith(".lua"):
            module_item(e[:-4], open(p, encoding="utf-8").read(), out)

def arkher_folder(out):
    folder_open("ARKHER", out)
    emit_tree(SRC, out)
    script_item("Script", "ARKHER_Boot",
                open(os.path.join(ROOT, "roblox/boot.server.lua"), encoding="utf-8").read(), out, run_context=1)
    script_item("LocalScript", "ARKHER_HUD",
                open(os.path.join(ROOT, "roblox/hud.client.lua"), encoding="utf-8").read(), out)
    folder_close(out)

HEADER = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

def build_model(path):
    out = [HEADER]
    arkher_folder(out)
    out.append("</roblox>")
    data = "\n".join(out)
    ET.fromstring(data)  # validate: must be well-formed XML or we do not ship it
    open(path, "w", encoding="utf-8").write(data)
    return len(data)

def build_place(path):
    out = [HEADER]
    out.append('<Item class="ReplicatedStorage" referent="%s">' % ref())
    out.append('<Properties><string name="Name">ReplicatedStorage</string></Properties>')
    arkher_folder(out)
    out.append('</Item>')
    out.append('<Item class="Workspace" referent="%s">' % ref())
    out.append('<Properties><string name="Name">Workspace</string>'
               '<bool name="StreamingEnabled">true</bool>'
               '<float name="StreamingTargetRadius">512</float></Properties>')
    out.append('</Item>')
    out.append('<Item class="Lighting" referent="%s">' % ref())
    out.append('<Properties><string name="Name">Lighting</string>'
               '<token name="Technology">4</token>'
               '<float name="Brightness">2</float></Properties>')
    out.append('</Item>')
    out.append("</roblox>")
    data = "\n".join(out)
    ET.fromstring(data)
    open(path, "w", encoding="utf-8").write(data)
    return len(data)

def count_modules():
    n = 0
    for dirpath, _, files in os.walk(SRC):
        n += len([f for f in files if f.endswith(".lua")])
    return n

def build_plugin(path):
    """ARKHER STUDIO plugin payload.

    The ROOT instance is the plugin Script itself (Roblox runs the root of a local
    plugin model), and the whole ARKHER runtime hangs underneath it as children.
    Studio is only the display adapter - the engine and the IDE are ARKHER's own.
    """
    out = [HEADER]
    source = open(os.path.join(ROOT, "roblox/plugin.server.lua"), encoding="utf-8").read()
    out.append('<Item class="Script" referent="%s">' % ref())
    out.append('<Properties>')
    out.append('<bool name="Disabled">false</bool>')
    out.append('<string name="Name">ARKHER</string>')
    out.append('<ProtectedString name="Source">%s</ProtectedString>' % esc(source))
    out.append('</Properties>')
    arkher_folder(out)
    out.append('</Item>')
    out.append("</roblox>")
    data = "\n".join(out)
    ET.fromstring(data)
    open(path, "w", encoding="utf-8").write(data)
    return len(data)


ROUND = os.environ.get("ARKHER_ROUND", "ROUND2")

if __name__ == "__main__":
    mpath = os.path.join(REL, "ARKHER_V1_%s.rbxmx" % ROUND)
    ppath = os.path.join(REL, "ARKHER_V1_%s.rbxlx" % ROUND)
    gpath = os.path.join(REL, "ARKHER_V1_STUDIO_PLUGIN.rbxmx")
    a = build_model(mpath)
    b = build_place(ppath)
    c = build_plugin(gpath)
    manifest = json.load(open(os.path.join(ROOT, "ARKHER_MANIFEST.json")))
    print("modules embedded : %d" % count_modules())
    print("systems          : %d" % manifest["totals"]["systems"])
    print("features         : %d" % manifest["totals"]["features"])
    print("model  %s  (%.1f MB)" % (mpath, a / 1048576))
    print("place  %s  (%.1f MB)" % (ppath, b / 1048576))
    print("plugin %s  (%.1f MB)" % (gpath, c / 1048576))
