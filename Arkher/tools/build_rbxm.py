#!/usr/bin/env python3
"""ARKHER V1 :: Roblox BINARY model/place builder (.rbxm / .rbxl).

The XML builder (tools/build_rbxmx.py) produces .rbxmx/.rbxlx, which are text files: a
browser opens them instead of downloading them, and Studio has to parse megabytes of XML.
This builder writes the real binary Roblox format instead:

    header    "<roblox!" + \\x89\\xff\\r\\n\\x1a\\n + version + class/instance counts
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
T_FLOAT32 = 0x04
T_ENUM = 0x12


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


def chunk(name, payload, compress=True):
    assert len(name) == 4
    if compress and _lz4 is not None and len(payload) > 0:
        packed = _lz4.compress(payload, store_size=False, mode="high_compression",
                               compression=9)
        if len(packed) < len(payload):
            return name + u32(len(packed)) + u32(len(payload)) + u32(0) + packed
    return name + u32(0) + u32(len(payload)) + u32(0) + payload


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
            elif kind == T_ENUM:
                payload += interleave([int(value) for value in values])
            else:
                raise ValueError("unsupported property type %s" % kind)
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


# property defaults, used when one instance of a class sets a property and another does not
DEFAULTS = {
    "Source": (T_STRING, ""),
    "RunContext": (T_ENUM, 0),
    "Disabled": (T_BOOL, False),
    "StreamingEnabled": (T_BOOL, False),
    "StreamingTargetRadius": (T_FLOAT32, 1024.0),
    "Technology": (T_ENUM, 2),
    "Brightness": (T_FLOAT32, 1.0),
}


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


def arkher_folder():
    root = Inst("Folder", "ARKHER")
    emit_tree(SRC, root)
    root.add(Inst("Script", "ARKHER_Boot",
                  {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/boot.server.lua"))),
                   "RunContext": (T_ENUM, 1)}))
    root.add(Inst("LocalScript", "ARKHER_HUD",
                  {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/hud.client.lua")))}))
    return root


def build_model(path):
    return write(path, serialize([arkher_folder()]))


def build_place(path):
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", is_service=True)
    replicated.add(arkher_folder())
    workspace = Inst("Workspace", "Workspace",
                     {"StreamingEnabled": (T_BOOL, True),
                      "StreamingTargetRadius": (T_FLOAT32, 512.0)}, is_service=True)
    lighting = Inst("Lighting", "Lighting",
                    {"Technology": (T_ENUM, 4), "Brightness": (T_FLOAT32, 2.0)},
                    is_service=True)
    return write(path, serialize([replicated, workspace, lighting]))


def build_plugin(path):
    root = Inst("Script", "ARKHER",
                {"Source": (T_STRING, read(os.path.join(ROOT, "roblox/plugin.server.lua"))),
                 "RunContext": (T_ENUM, 0)})
    root.add(arkher_folder())
    return write(path, serialize([root]))


def count_modules():
    total = 0
    for dirpath, _, files in os.walk(SRC):
        total += len([f for f in files if f.endswith(".lua")])
    return total


ROUND = os.environ.get("ARKHER_ROUND", "ROUND8")

if __name__ == "__main__":
    model = os.path.join(REL, "ARKHER_V1_%s.rbxm" % ROUND)
    place = os.path.join(REL, "ARKHER_V1_%s.rbxl" % ROUND)
    plugin = os.path.join(REL, "ARKHER_V1_STUDIO_PLUGIN.rbxm")
    a = build_model(model)
    b = build_place(place)
    c = build_plugin(plugin)
    with open(os.path.join(ROOT, "ARKHER_MANIFEST.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    print("compression      : %s" % ("lz4 (high)" if _lz4 else "none (raw chunks)"))
    print("modules embedded : %d" % count_modules())
    print("systems          : %d" % manifest["totals"]["systems"])
    print("features         : %d" % manifest["totals"]["features"])
    print("model  %s  (%.1f MB)" % (model, a / 1048576))
    print("place  %s  (%.1f MB)" % (place, b / 1048576))
    print("plugin %s  (%.1f MB)" % (plugin, c / 1048576))
