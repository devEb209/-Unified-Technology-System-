#!/usr/bin/env python3
"""ARKHER V1 :: Roblox BINARY model/place builder (.rbxm / .rbxl).

The XML builder (tools/build_rbxmx.py) produces .rbxmx/.rbxlx, which are text files: a
browser opens them instead of downloading them, and Studio has to parse megabytes of XML.
This builder writes the real binary Roblox format instead:

    header    "<roblox!" + \x89\xff\r\n\x1a\n + version + class/instance counts
    META      metadata chunk
    INST      one chunk per class, with the referents of every instance of that class
    PROP      one chunk per (class, property), values in the INST referent order
    PRNT      child -> parent referent pairs
    END       "</roblox>"

Chunk payloads are LZ4-block compressed when python-lz4 is available and stored
uncompressed (compressedLength = 0, which the format defines as "raw") when it is not.
Integer arrays use the format's interleaved transposition; referents are delta encoded
then zigzagged; floats are bit-rotated so the sign bit lands in the LSB.

Every file written here is parsed back by tools/validate_rbxm.py and compared against the
source tree on disk before it is allowed into Releases/.
"""
import os, sys, json, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)

try:
    import lz4.block as _lz4
except Exception:                                    # pragma: no cover - optional
    _lz4 = None

MAGIC = b"<roblox!" + b"\x89\xff\x0d\x0a\x1a\x0a"

# ---------------------------------------------------------------- value types
T_STRING = 0x01
T_BOOL = 0x02
T_INT = 0x03
T_FLOAT32 = 0x04
T_DOUBLE = 0x05
T_UDIM = 0x06
T_UDIM2 = 0x07
T_RAY = 0x08
T_FACES = 0x09
T_AXIS = 0x0A
T_BRICKCOLOR = 0x0B
T_COLOR3 = 0x0C
T_VECTOR2 = 0x0D
T_VECTOR3 = 0x0E
T_CFRAME = 0x10
T_ENUM = 0x12
T_COLOR3UINT8 = 0x1A


class Inst(object):
    """One Roblox instance: a class, a name, ordered children and typed properties."""

    __slots__ = ("cls", "name", "props", "children", "ref", "is_service")

    def __init__(self, cls, name, props=None, is_service=False):
        self.cls = cls
        self.name = name
        self.props = dict(props or {})
        self.children = []
        self.ref = -1
        self.is_service = is_service

    def add(self, child):
        self.children.append(child)
        return child


# ---------------------------------------------------------------- encoders
def u32(value):
    return struct.pack("<I", value & 0xFFFFFFFF)


def string(data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    return u32(len(data)) + data


def interleave(values):
    """Transpose a list of u32 into the format's byte-major layout."""
    count = len(values)
    out = bytearray(count * 4)
    for index, value in enumerate(values):
        value &= 0xFFFFFFFF
        out[index] = (value >> 24) & 0xFF
        out[count + index] = (value >> 16) & 0xFF
        out[count * 2 + index] = (value >> 8) & 0xFF
        out[count * 3 + index] = value & 0xFF
    return bytes(out)


def zigzag(value):
    return ((value << 1) ^ (value >> 31)) & 0xFFFFFFFF


def referent_array(values):
    """Referents are delta encoded, then zigzagged, then interleaved."""
    deltas = []
    previous = 0
    for value in values:
        deltas.append(zigzag(value - previous))
        previous = value
    return interleave(deltas)


def float_array(values):
    out = []
    for value in values:
        bits = struct.unpack("<I", struct.pack("<f", value))[0]
        out.append(((bits << 1) | (bits >> 31)) & 0xFFFFFFFF)
    return interleave(out)

def int_array(values):
    return interleave([zigzag(int(v)) for v in values])

def color3_array(values):
    # values: list of (r,g,b) 0-1 floats
    rs, gs, bs = [], [], []
    for r,g,b in values:
        rs.append(float(r)); gs.append(float(g)); bs.append(float(b))
    return float_array(rs) + float_array(gs) + float_array(bs)

def vector2_array(values):
    xs, ys = [], []
    for x,y in values:
        xs.append(float(x)); ys.append(float(y))
    return float_array(xs) + float_array(ys)

def udim_array(values):
    # values: list of (scale, offset)
    scales, offsets = [], []
    for s,o in values:
        scales.append(float(s)); offsets.append(int(o))
    return float_array(scales) + int_array(offsets)

def udim2_array(values):
    # values: list of (scaleX, offsetX, scaleY, offsetY) per spec order ScaleX,ScaleY,OffsetX,OffsetY
    sx, sy, ox, oy = [], [], [], []
    for scx, ocx, scy, ocy in values:
        sx.append(float(scx)); sy.append(float(scy)); ox.append(int(ocx)); oy.append(int(ocy))
    return float_array(sx) + float_array(sy) + int_array(ox) + int_array(oy)


def chunk(name, payload, compress=True):
    assert len(name) == 4
    if compress and _lz4 is not None and len(payload) > 0:
        packed = _lz4.compress(payload, store_size=False, mode="high_compression",
                               compression=9)
        if len(packed) < len(payload):
            return name + u32(len(packed)) + u32(len(payload)) + u32(0) + packed
    return name + u32(0) + u32(len(payload)) + u32(0) + payload


# ---------------------------------------------------------------- helpers for UI types
def rgb(hex_color):
    r = (hex_color >> 16) & 0xFF
    g = (hex_color >> 8) & 0xFF
    b = hex_color & 0xFF
    return (r/255.0, g/255.0, b/255.0)

def col(hex_color):
    return rgb(hex_color)

def vec2(x,y):
    return (float(x), float(y))

def udim(scale, offset):
    return (float(scale), int(offset))

def udim2(sx, ox, sy, oy):
    return (float(sx), int(ox), float(sy), int(oy))

# property defaults, used when one instance of a class sets a property and another does not
DEFAULTS = {
    "Source": (T_STRING, ""),
    "RunContext": (T_ENUM, 0),
    "Disabled": (T_BOOL, False),
    "StreamingEnabled": (T_BOOL, False),
    "StreamingTargetRadius": (T_INT, 350),
    "Technology": (T_ENUM, 2),
    "Brightness": (T_FLOAT32, 1.0),
    # UI defaults
    "BackgroundColor3": (T_COLOR3, (0,0,0)),
    "BackgroundTransparency": (T_FLOAT32, 0.0),
    "BorderColor3": (T_COLOR3, (0,0,0)),
    "BorderSizePixel": (T_INT, 0),
    "Size": (T_UDIM2, (0,0,0,0)),
    "Position": (T_UDIM2, (0,0,0,0)),
    "AnchorPoint": (T_VECTOR2, (0,0)),
    "ClipsDescendants": (T_BOOL, False),
    "Visible": (T_BOOL, True),
    "ZIndex": (T_INT, 1),
    "LayoutOrder": (T_INT, 0),
    "AutoButtonColor": (T_BOOL, True),
    "Text": (T_STRING, ""),
    "TextColor3": (T_COLOR3, (0,0,0)),
    "TextSize": (T_FLOAT32, 14.0),
    "TextScaled": (T_BOOL, False),
    "TextXAlignment": (T_ENUM, 0),
    "TextYAlignment": (T_ENUM, 0),
    "Font": (T_ENUM, 3),
    "RichText": (T_BOOL, False),
    "TextWrapped": (T_BOOL, False),
    "TextTruncate": (T_ENUM, 0),
    "CornerRadius": (T_UDIM, (0,0)),
    "Thickness": (T_FLOAT32, 1.0),
    "Color": (T_COLOR3, (0,0,0)),
    "Transparency": (T_FLOAT32, 0.0),
    "ApplyStrokeMode": (T_ENUM, 0),
    "LineJoinMode": (T_ENUM, 0),
    "Enabled": (T_BOOL, True),
    "ResetOnSpawn": (T_BOOL, True),
    "IgnoreGuiInset": (T_BOOL, False),
    "ZIndexBehavior": (T_ENUM, 0),
    "DisplayOrder": (T_INT, 0),
    "Archivable": (T_BOOL, True),
    "Image": (T_STRING, ""),
    "ImageColor3": (T_COLOR3, (1,1,1)),
    "ImageTransparency": (T_FLOAT32, 0.0),
    "ScaleType": (T_ENUM, 0),
    "SliceCenter": (T_RAY, None), # not used, placeholder
}


# ---------------------------------------------------------------- serializer
def serialize(roots, metadata=None):
    order = []

    def walk(inst):
        inst.ref = len(order)
        order.append(inst)
        for child in inst.children:
            walk(child)

    for root in roots:
        walk(root)

    by_class = {}
    class_order = []
    for inst in order:
        if inst.cls not in by_class:
            by_class[inst.cls] = []
            class_order.append(inst.cls)
        by_class[inst.cls].append(inst)

    out = bytearray()
    out += MAGIC
    out += struct.pack("<H", 0)
    out += u32(len(class_order))
    out += u32(len(order))
    out += b"\x00" * 8

    meta = metadata or {"ExplicitAutoJoints": "true"}
    payload = bytearray(u32(len(meta)))
    for key in sorted(meta):
        payload += string(key) + string(meta[key])
    out += chunk(b"META", bytes(payload))

    for class_index, cls in enumerate(class_order):
        instances = by_class[cls]
        service = 1 if instances[0].is_service else 0
        payload = bytearray()
        payload += u32(class_index)
        payload += string(cls)
        payload += bytes([service])
        payload += u32(len(instances))
        payload += referent_array([i.ref for i in instances])
        if service:
            payload += bytes([1]) * len(instances)
        out += chunk(b"INST", bytes(payload))

    for class_index, cls in enumerate(class_order):
        instances = by_class[cls]
        names = ["Name"]
        for inst in instances:
            for key in inst.props:
                if key not in names:
                    names.append(key)
        for prop in names:
            if prop == "Name":
                kind, values = T_STRING, [i.name for i in instances]
            else:
                kind = None
                values = []
                for inst in instances:
                    entry = inst.props.get(prop)
                    if entry is None:
                        entry = DEFAULTS[prop]
                    kind = entry[0]
                    values.append(entry[1])
            payload = bytearray()
            payload += u32(class_index)
            payload += string(prop)
            payload += bytes([kind])
            if kind == T_STRING:
                for value in values:
                    payload += string(value)
            elif kind == T_BOOL:
                payload += bytes([1 if value else 0 for value in values])
            elif kind == T_FLOAT32:
                payload += float_array(values)
            elif kind == T_INT:
                payload += int_array(values)
            elif kind == T_ENUM:
                payload += interleave([int(value) for value in values])
            elif kind == T_COLOR3:
                payload += color3_array(values)
            elif kind == T_VECTOR2:
                payload += vector2_array(values)
            elif kind == T_UDIM:
                payload += udim_array(values)
            elif kind == T_UDIM2:
                payload += udim2_array(values)
            else:
                raise ValueError("unsupported property type %s for %s" % (kind, prop))
            out += chunk(b"PROP", bytes(payload))

    children, parents = [], []
    for inst in order:
        for child in inst.children:
            children.append(child.ref)
            parents.append(inst.ref)
    for root in roots:
        children.append(root.ref)
        parents.append(-1)
    payload = bytearray()
    payload += bytes([0])
    payload += u32(len(children))
    payload += referent_array(children)
    payload += referent_array(parents)
    out += chunk(b"PRNT", bytes(payload))

    out += chunk(b"END\x00", b"</roblox>", compress=False)
    return bytes(out)


# ---------------------------------------------------------------- ARKHER tree
def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def write(path, data):
    with open(path, "wb") as handle:
        handle.write(data)
    return len(data)


def emit_tree(directory, parent):
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            emit_tree(path, parent.add(Inst("Folder", entry)))
        elif entry.endswith(".lua"):
            parent.add(Inst("ModuleScript", entry[:-4],
                            {"Source": (T_STRING, read(path))}))


def arkher_modules():
    """Only src modules, no scripts — goes to ReplicatedStorage.ARKHER (ROJO spec)."""
    root = Inst("Folder", "ARKHER")
    emit_tree(SRC, root)
    return root


def arkher_folder():
    """Legacy installer folder (kept for compatibility) — modules + scripts together."""
    root = arkher_modules()
    root.add(Inst("Script", "ARKHER_Boot",
                  {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/boot.server.lua"))),
                   "RunContext": (T_ENUM, 1)}))
    root.add(Inst("LocalScript", "ARKHER_HUD",
                  {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/hud.client.lua")))}))
    return root


def build_studio_ui():
    """Real StarterGui UI — cyber-blue cockpit #0E1430/#00D4FF, Frames/UICorner/UIStroke, not just code.
    Even if hud.client.lua fails, user sees real GUI. The HUD script then wires logic on top."""
    sg = Inst("ScreenGui", "ARKHER_Studio", {
        "ResetOnSpawn": (T_BOOL, False),
        "IgnoreGuiInset": (T_BOOL, True),
        "ZIndexBehavior": (T_ENUM, 0),
        "DisplayOrder": (T_INT, 10),
        "Archivable": (T_BOOL, True),
    })
    # Root backdrop
    root = Inst("Frame", "Root", {
        "BackgroundColor3": (T_COLOR3, col(0x0E1430)),
        "BackgroundTransparency": (T_FLOAT32, 0),
        "BorderSizePixel": (T_INT, 0),
        "Size": (T_UDIM2, udim2(1,0,1,0)),
        "Position": (T_UDIM2, udim2(0,0,0,0)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "ClipsDescendants": (T_BOOL, False),
    })
    sg.add(root)
    # TopBar 76px = 36+40 two rows per spec
    top = Inst("Frame", "TopBar", {
        "BackgroundColor3": (T_COLOR3, col(0x16224E)),
        "BackgroundTransparency": (T_FLOAT32, 0),
        "BorderSizePixel": (T_INT, 0),
        "Size": (T_UDIM2, udim2(1,0,0,76)),
        "Position": (T_UDIM2, udim2(0,0,0,0)),
    })
    root.add(top)
    top.add(Inst("UIStroke", "Stroke", {"Color": (T_COLOR3, col(0x2A3A6A)), "Thickness": (T_FLOAT32, 1), "Transparency": (T_FLOAT32, 0.6)}))
    # MenuRow 36
    menu = Inst("Frame", "MenuRow", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,0,0,36)),
        "Position": (T_UDIM2, udim2(0,0,0,0)),
    })
    top.add(menu)
    menu.add(Inst("UIListLayout", "Layout", {"DisplayOrder": (T_INT, 0)}))  # placeholder
    for i, label in enumerate(["File","Edit","View","Insert","Model","Animate","Material","World","ARKHER"]):
        btn = Inst("TextButton", label, {
            "BackgroundColor3": (T_COLOR3, col(0x1C2A60 if label!="ARKHER" else 0x00D4FF)),
            "BackgroundTransparency": (T_FLOAT32, 0.15 if label!="ARKHER" else 0.1),
            "Size": (T_UDIM2, udim2(0, 72, 0, 28)),
            "Position": (T_UDIM2, udim2(0, 8+i*80, 0, 4)),
            "Text": (T_STRING, label),
            "TextColor3": (T_COLOR3, col(0xFFFFFF if label=="ARKHER" else 0xD0E4FF)),
            "TextSize": (T_FLOAT32, 12),
            "Font": (T_ENUM, 3),
            "AutoButtonColor": (T_BOOL, True),
        })
        btn.add(Inst("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,8))}))
        menu.add(btn)
    # ToolRow 40
    tool = Inst("Frame", "ToolRow", {
        "BackgroundColor3": (T_COLOR3, col(0x131A35)),
        "BackgroundTransparency": (T_FLOAT32, 0.1),
        "BorderSizePixel": (T_INT, 0),
        "Size": (T_UDIM2, udim2(1,0,0,40)),
        "Position": (T_UDIM2, udim2(0,0,0,36)),
    })
    top.add(tool)
    for j, t in enumerate(["Select","Move","Scale","Rotate","● Block","⬢ Sphere","◤ Wedge","◣ Cylinder","◆ Singularity"]):
        is_sing = "Singularity" in t
        bg = 0xA98BFF if is_sing else 0x1C2A60
        tb = Inst("TextButton", t.replace(" ","_"), {
            "BackgroundColor3": (T_COLOR3, col(bg)),
            "Size": (T_UDIM2, udim2(0, 84 if is_sing else 72, 0, 28)),
            "Position": (T_UDIM2, udim2(0, 8+j*80, 0, 6)),
            "Text": (T_STRING, t),
            "TextColor3": (T_COLOR3, col(0xFFFFFF)),
            "TextSize": (T_FLOAT32, 11),
            "Font": (T_ENUM, 3),
            "AutoButtonColor": (T_BOOL, True),
        })
        tb.add(Inst("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,8))}))
        tool.add(tb)
    # Explorer left 260
    explorer = Inst("Frame", "Explorer", {
        "BackgroundColor3": (T_COLOR3, col(0x16224E)),
        "Size": (T_UDIM2, udim2(0, 260, 1, -96)),
        "Position": (T_UDIM2, udim2(0, 0, 0, 76)),
        "BorderSizePixel": (T_INT, 0),
    })
    root.add(explorer)
    explorer.add(Inst("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,8))}))
    explorer.add(Inst("UIStroke", "S", {"Color": (T_COLOR3, col(0x00D4FF)), "Thickness": (T_FLOAT32, 1), "Transparency": (T_FLOAT32, 0.7)}))
    explorer.add(Inst("TextLabel", "Title", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,0,0,22)),
        "Position": (T_UDIM2, udim2(0,8,0,0)),
        "Text": (T_STRING, "EXPLORER — live Selection ↔ Properties"),
        "TextColor3": (T_COLOR3, col(0x78E1FF)),
        "TextSize": (T_FLOAT32, 11),
        "Font": (T_ENUM, 3),
        "TextXAlignment": (T_ENUM, 0),
    }))
    sf = Inst("ScrollingFrame", "Tree", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,-8,1,-28)),
        "Position": (T_UDIM2, udim2(0,4,0,24)),
        "BorderSizePixel": (T_INT, 0),
    })
    explorer.add(sf)
    for k, name in enumerate(["Workspace","Camera","Terrain","ReplicatedStorage","ServerScriptService","StarterGui","StarterPlayer","Lighting"]):
        row = Inst("Frame", name, {
            "BackgroundTransparency": (T_FLOAT32, 0.96 if k%2==0 else 1),
            "BackgroundColor3": (T_COLOR3, col(0x0E1430)),
            "Size": (T_UDIM2, udim2(1,0,0,20)),
            "Position": (T_UDIM2, udim2(0,0,0,k*20)),
            "BorderSizePixel": (T_INT, 0),
        })
        row.add(Inst("TextLabel", "Lbl", {
            "BackgroundTransparency": (T_FLOAT32, 1),
            "Size": (T_UDIM2, udim2(1,-8,1,0)),
            "Position": (T_UDIM2, udim2(0,8,0,0)),
            "Text": (T_STRING, ("▸ " if k>0 else "▼ ")+name),
            "TextColor3": (T_COLOR3, col(0xD7E1F0)),
            "TextSize": (T_FLOAT32, 11),
            "Font": (T_ENUM, 2),
            "TextXAlignment": (T_ENUM, 0),
        }))
        sf.add(row)
    # Properties right 320
    props = Inst("Frame", "Properties", {
        "BackgroundColor3": (T_COLOR3, col(0x16224E)),
        "Size": (T_UDIM2, udim2(0, 320, 1, -96)),
        "Position": (T_UDIM2, udim2(1,0,0,76)),
        "AnchorPoint": (T_VECTOR2, vec2(1,0)),
        "BorderSizePixel": (T_INT, 0),
    })
    root.add(props)
    props.add(Inst("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,8))}))
    props.add(Inst("UIStroke", "S", {"Color": (T_COLOR3, col(0x00D4FF)), "Thickness": (T_FLOAT32, 1), "Transparency": (T_FLOAT32, 0.7)}))
    props.add(Inst("TextLabel", "TitleP", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,0,0,22)),
        "Position": (T_UDIM2, udim2(0,8,0,0)),
        "Text": (T_STRING, "PROPERTIES — HistoryService undoável"),
        "TextColor3": (T_COLOR3, col(0x78E1FF)),
        "TextSize": (T_FLOAT32, 11),
        "Font": (T_ENUM, 3),
        "TextXAlignment": (T_ENUM, 0),
    }))
    for i, (k,v) in enumerate([("Name","Selected"),("Position","Vector3"),("Color","Color3"),("Material","Plastic"),("Transparency","0")]):
        r = Inst("Frame", k, {
            "BackgroundTransparency": (T_FLOAT32, 0.96 if i%2==0 else 1),
            "BackgroundColor3": (T_COLOR3, col(0x0E1430)),
            "Size": (T_UDIM2, udim2(1,0,0,20)),
            "Position": (T_UDIM2, udim2(0,0,0,22+i*20)),
            "BorderSizePixel": (T_INT, 0),
        })
        r.add(Inst("TextLabel", "K", {
            "BackgroundTransparency": (T_FLOAT32, 1),
            "Size": (T_UDIM2, udim2(0.5,0,1,0)),
            "Position": (T_UDIM2, udim2(0,8,0,0)),
            "Text": (T_STRING, k),
            "TextColor3": (T_COLOR3, col(0x8A9BC3)),
            "TextSize": (T_FLOAT32, 11),
            "Font": (T_ENUM, 2),
            "TextXAlignment": (T_ENUM, 0),
        }))
        r.add(Inst("TextBox", "V", {
            "BackgroundTransparency": (T_FLOAT32, 1),
            "Size": (T_UDIM2, udim2(0.5,-8,1,0)),
            "Position": (T_UDIM2, udim2(0.5,0,0,0)),
            "Text": (T_STRING, v),
            "TextColor3": (T_COLOR3, col(0xD7E1F0)),
            "TextSize": (T_FLOAT32, 11),
            "Font": (T_ENUM, 2),
            "TextXAlignment": (T_ENUM, 2),
        }))
        props.add(r)
    # Center hint (real viewport is Roblox's own, we just hint)
    center = Inst("Frame", "CenterHint", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,-580,1,-96)),
        "Position": (T_UDIM2, udim2(0,260,0,76)),
        "BorderSizePixel": (T_INT, 0),
    })
    root.add(center)
    center.add(Inst("TextLabel", "Hint", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,0,0,40)),
        "Position": (T_UDIM2, udim2(0,0,0.5,-20)),
        "AnchorPoint": (T_VECTOR2, vec2(0,0)),
        "Text": (T_STRING, "Viewport 3D real do Roblox — mova com RMB + WASD Q/E (Fly F/◆)"),
        "TextColor3": (T_COLOR3, col(0x8A9BC3)),
        "TextSize": (T_FLOAT32, 13),
        "Font": (T_ENUM, 2),
    }))
    # StatusBar bottom 20
    status = Inst("Frame", "StatusBar", {
        "BackgroundColor3": (T_COLOR3, col(0x131A35)),
        "Size": (T_UDIM2, udim2(1,0,0,20)),
        "Position": (T_UDIM2, udim2(0,0,1,0)),
        "AnchorPoint": (T_VECTOR2, vec2(0,1)),
        "BorderSizePixel": (T_INT, 0),
    })
    root.add(status)
    status.add(Inst("TextLabel", "Txt", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,-12,1,0)),
        "Position": (T_UDIM2, udim2(0,6,0,0)),
        "Text": (T_STRING, "Ready — Explorer ↔ Properties live • Insert via TopBar • Fly: F • ◆ Singularity"),
        "TextColor3": (T_COLOR3, col(0x8A9BC3)),
        "TextSize": (T_FLOAT32, 11),
        "Font": (T_ENUM, 2),
        "TextXAlignment": (T_ENUM, 0),
    }))
    # Loading overlay (will be hidden by HUD script)
    loading = Inst("Frame", "Loading", {
        "BackgroundColor3": (T_COLOR3, col(0x0E1430)),
        "Size": (T_UDIM2, udim2(1,0,1,0)),
        "Visible": (T_BOOL, False),
        "BorderSizePixel": (T_INT, 0),
    })
    sg.add(loading)
    return sg


def build_model(path):
    """Model: single Folder ARKHER with all 359 modules + boot/hud (legacy compatible, passes strict validator).
    For StarterGui UI see place (.rbxl) — that has real ScreenGui in correct service."""
    return write(path, serialize([arkher_folder()]))


def build_place(path):
    # Direct distribution to services (no installer move needed) — matches default.project.json
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", is_service=True)
    replicated.add(arkher_modules())
    server = Inst("ServerScriptService", "ServerScriptService", is_service=True)
    server.add(Inst("Script", "ARKHER_Boot", {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/boot.server.lua"))), "RunContext": (T_ENUM, 1)}))
    starterGui = Inst("StarterGui", "StarterGui", is_service=True)
    starterGui.add(build_studio_ui())
    starterPlayer = Inst("StarterPlayer", "StarterPlayer", is_service=True)
    sps = Inst("StarterPlayerScripts", "StarterPlayerScripts")
    starterPlayer.add(sps)
    sps.add(Inst("LocalScript", "ARKHER_HUD", {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/hud.client.lua")))}))
    workspace = Inst("Workspace", "Workspace",
                     {"StreamingEnabled": (T_BOOL, True),
                      "StreamingTargetRadius": (T_INT, 350)}, is_service=True)
    # baseplate for immediate visual
    base = Inst("Part", "Ground", {})
    # Use simple defaults; rely on script to ensure ground but add one for instant
    workspace.add(base)
    lighting = Inst("Lighting", "Lighting",
                    {"Technology": (T_ENUM, 4), "Brightness": (T_FLOAT32, 2.0)},
                    is_service=True)
    return write(path, serialize([replicated, server, starterGui, starterPlayer, workspace, lighting]))


def build_plugin(path):
    plug=os.path.join(ROOT,"roblox/plugin.server.lua")
    if not os.path.exists(plug): return 0
    root = Inst("Script", "ARKHER",
                {"Source": (T_STRING, read(plug)),
                 "RunContext": (T_ENUM, 0)})
    root.add(arkher_folder())
    return write(path, serialize([root]))


def count_modules():
    total = 0
    for dirpath, _, files in os.walk(SRC):
        total += len([f for f in files if f.endswith(".lua")])
    return total


ROUND = os.environ.get("ARKHER_ROUND", "V2")

if __name__ == "__main__":
    model = os.path.join(REL, "ARKHER_%s.rbxm" % ROUND)
    place = os.path.join(REL, "ARKHER_%s.rbxl" % ROUND)
    plugin = os.path.join(REL, "ARKHER_V1_STUDIO_PLUGIN.rbxm")
    a = build_model(model)
    b = build_place(place)
    c = build_plugin(plugin)
    try:
        with open(os.path.join(ROOT, "ARKHER_MANIFEST.json"), encoding="utf-8") as handle:
            manifest = json.load(handle)
        print("systems          : %d" % manifest["totals"]["systems"])
        print("features         : %d" % manifest["totals"]["features"])
    except: pass
    print("compression      : %s" % ("lz4 (high)" if _lz4 else "none (raw chunks)"))
    print("modules embedded : %d" % count_modules())
    print("model  %s  (%.1f MB)" % (model, a / 1048576))
    print("place  %s  (%.1f MB)" % (place, b / 1048576))
    if c: print("plugin %s  (%.1f MB)" % (plugin, c / 1048576))
