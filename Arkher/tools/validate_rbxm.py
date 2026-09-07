#!/usr/bin/env python3
"""ARKHER V1 :: binary .rbxm/.rbxl reader + release validator.

This is a from-scratch parser (it shares no code with the writer beyond the constants of
the file format) whose only job is to prove that the binaries in Releases/ really are
valid Roblox binary files and that every byte of ARKHER made it inside:

  * header magic, version, class count and instance count are re-derived and compared;
  * every chunk is decompressed (LZ4 block) or read raw and must consume exactly its
    declared uncompressed length;
  * INST/PROP/PRNT are decoded back into an instance tree;
  * every ModuleScript Source is compared byte-for-byte with the file on disk;
  * the tree layout is compared with the directory layout of Arkher/src.

Usage: python3 tools/validate_rbxm.py [files...]   (defaults to the ROUND artifacts)
"""
import os, sys, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
REL = os.path.join(ROOT, "Releases")

try:
    import lz4.block as _lz4
except Exception:                                    # pragma: no cover - optional
    _lz4 = None

MAGIC = b"<roblox!" + b"\x89\xff\x0d\x0a\x1a\x0a"
T_STRING, T_BOOL, T_FLOAT32, T_ENUM = 0x01, 0x02, 0x04, 0x12


class Reader(object):
    def __init__(self, data):
        self.data = data
        self.pos = 0

    def take(self, count):
        out = self.data[self.pos:self.pos + count]
        if len(out) != count:
            raise ValueError("truncated read of %d bytes at %d" % (count, self.pos))
        self.pos += count
        return out

    def u8(self):
        return self.take(1)[0]

    def u16(self):
        return struct.unpack("<H", self.take(2))[0]

    def u32(self):
        return struct.unpack("<I", self.take(4))[0]

    def i32(self):
        return struct.unpack("<i", self.take(4))[0]

    def string(self):
        return self.take(self.u32())

    def done(self):
        return self.pos >= len(self.data)


def deinterleave(payload, count):
    if len(payload) != count * 4:
        raise ValueError("interleaved array of %d values needs %d bytes, got %d"
                         % (count, count * 4, len(payload)))
    out = []
    for index in range(count):
        out.append((payload[index] << 24) | (payload[count + index] << 16)
                   | (payload[count * 2 + index] << 8) | payload[count * 3 + index])
    return out


def unzigzag(value):
    return (value >> 1) ^ (-(value & 1))


def referents(payload, count):
    out, previous = [], 0
    for value in deinterleave(payload, count):
        previous += unzigzag(value)
        out.append(previous)
    return out


def floats(payload, count):
    out = []
    for value in deinterleave(payload, count):
        bits = ((value >> 1) | ((value & 1) << 31)) & 0xFFFFFFFF
        out.append(struct.unpack("<f", struct.pack("<I", bits))[0])
    return out


class Node(object):
    __slots__ = ("cls", "ref", "props", "children", "parent", "is_service")

    def __init__(self, cls, ref, is_service):
        self.cls = cls
        self.ref = ref
        self.props = {}
        self.children = []
        self.parent = None
        self.is_service = is_service

    @property
    def name(self):
        return self.props.get("Name", "?")


def parse(path):
    data = open(path, "rb").read()
    reader = Reader(data)
    if reader.take(len(MAGIC)) != MAGIC:
        raise ValueError("bad magic")
    version = reader.u16()
    class_count = reader.u32()
    instance_count = reader.u32()
    if reader.take(8) != b"\x00" * 8:
        raise ValueError("header tail not zero")
    if version != 0:
        raise ValueError("unexpected version %d" % version)

    nodes = {}
    classes = {}
    roots = []
    metadata = {}
    seen_end = False
    chunks = 0

    while not reader.done():
        name = reader.take(4)
        compressed_length = reader.u32()
        uncompressed_length = reader.u32()
        reader.u32()
        raw = reader.take(compressed_length if compressed_length else uncompressed_length)
        if compressed_length:
            if _lz4 is None:
                raise RuntimeError("file uses LZ4 chunks but python-lz4 is unavailable")
            payload = _lz4.decompress(raw, uncompressed_size=uncompressed_length)
        else:
            payload = raw
        if len(payload) != uncompressed_length:
            raise ValueError("chunk %r length mismatch" % name)
        chunks += 1
        body = Reader(payload)

        if name == b"META":
            for _ in range(body.u32()):
                key = body.string().decode("utf-8")
                metadata[key] = body.string().decode("utf-8")
        elif name == b"INST":
            class_index = body.u32()
            class_name = body.string().decode("utf-8")
            object_format = body.u8()
            count = body.u32()
            refs = referents(body.take(count * 4), count)
            if object_format == 1:
                markers = body.take(count)
                if any(marker != 1 for marker in markers):
                    raise ValueError("bad service marker in %s" % class_name)
            elif object_format != 0:
                raise ValueError("unknown object format %d" % object_format)
            classes[class_index] = (class_name, refs)
            for ref in refs:
                if ref in nodes:
                    raise ValueError("duplicate referent %d" % ref)
                nodes[ref] = Node(class_name, ref, object_format == 1)
        elif name == b"PROP":
            class_index = body.u32()
            prop = body.string().decode("utf-8")
            kind = body.u8()
            class_name, refs = classes[class_index]
            count = len(refs)
            if kind == T_STRING:
                values = [body.string() for _ in range(count)]
                if prop in ("Name", "Source"):
                    values = [value.decode("utf-8") for value in values]
            elif kind == T_BOOL:
                values = [byte == 1 for byte in body.take(count)]
            elif kind == T_FLOAT32:
                values = floats(body.take(count * 4), count)
            elif kind == T_ENUM:
                values = deinterleave(body.take(count * 4), count)
            else:
                raise ValueError("unsupported type 0x%02x for %s.%s"
                                 % (kind, class_name, prop))
            for ref, value in zip(refs, values):
                nodes[ref].props[prop] = value
        elif name == b"PRNT":
            if body.u8() != 0:
                raise ValueError("unexpected PRNT version")
            count = body.u32()
            children = referents(body.take(count * 4), count)
            parents = referents(body.take(count * 4), count)
            for child, parent in zip(children, parents):
                if parent == -1:
                    roots.append(nodes[child])
                else:
                    nodes[child].parent = nodes[parent]
                    nodes[parent].children.append(nodes[child])
        elif name == b"END\x00":
            if payload != b"</roblox>":
                raise ValueError("bad END payload")
            seen_end = True
        else:
            raise ValueError("unknown chunk %r" % name)
        if not body.done() and name != b"END\x00":
            raise ValueError("chunk %r has %d trailing bytes"
                             % (name, len(payload) - body.pos))

    if not seen_end:
        raise ValueError("missing END chunk")
    if len(nodes) != instance_count:
        raise ValueError("header says %d instances, found %d" % (instance_count, len(nodes)))
    if len(classes) != class_count:
        raise ValueError("header says %d classes, found %d" % (class_count, len(classes)))
    orphans = [n for n in nodes.values() if n.parent is None and n not in roots]
    if orphans:
        raise ValueError("%d instances have no parent" % len(orphans))
    return {"roots": roots, "nodes": nodes, "metadata": metadata,
            "classes": [classes[i][0] for i in sorted(classes)], "chunks": chunks,
            "bytes": len(data)}


def find(node, name):
    for child in node.children:
        if child.name == name:
            return child
    return None


def disk_tree(directory):
    out = {}
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            out[entry] = disk_tree(path)
        elif entry.endswith(".lua"):
            out[entry[:-4]] = path
    return out


def compare(node, tree, trail, problems):
    seen = set()
    for child in node.children:
        if child.name in ("ARKHER_Boot", "ARKHER_HUD"):
            continue
        seen.add(child.name)
        expected = tree.get(child.name)
        path = trail + "/" + child.name
        if expected is None:
            problems.append("extra instance %s" % path)
        elif isinstance(expected, dict):
            if child.cls != "Folder":
                problems.append("%s should be a Folder, is %s" % (path, child.cls))
            else:
                compare(child, expected, path, problems)
        else:
            if child.cls != "ModuleScript":
                problems.append("%s should be a ModuleScript, is %s" % (path, child.cls))
            elif child.props.get("Source") != open(expected, encoding="utf-8").read():
                problems.append("source mismatch at %s" % path)
    for missing in set(tree) - seen:
        problems.append("missing %s/%s" % (trail, missing))


def validate(path):
    print("== %s" % os.path.basename(path))
    result = parse(path)
    problems = []
    print("   bytes      : %d (%.1f MB)" % (result["bytes"], result["bytes"] / 1048576))
    print("   chunks     : %d" % result["chunks"])
    print("   classes    : %s" % ", ".join(sorted(result["classes"])))
    print("   instances  : %d" % len(result["nodes"]))
    print("   roots      : %s" % ", ".join("%s(%s)" % (r.name, r.cls) for r in result["roots"]))

    arkher = None
    for root in result["roots"]:
        if root.name == "ARKHER" and root.cls == "Folder":
            arkher = root
        else:
            candidate = find(root, "ARKHER")
            if candidate is not None:
                arkher = candidate
    if arkher is None:
        problems.append("no ARKHER folder found")
    else:
        compare(arkher, disk_tree(SRC), "ARKHER", problems)
        for required, cls in (("ARKHER_Boot", "Script"), ("ARKHER_HUD", "LocalScript")):
            child = find(arkher, required)
            if child is None or child.cls != cls:
                problems.append("missing %s (%s)" % (required, cls))
            elif not child.props.get("Source"):
                problems.append("%s has empty Source" % required)

    modules = [n for n in result["nodes"].values() if n.cls == "ModuleScript"]
    scripts = [n for n in result["nodes"].values() if n.cls in ("Script", "LocalScript")]
    source_bytes = sum(len(n.props.get("Source", "")) for n in result["nodes"].values())
    print("   modules    : %d" % len(modules))
    print("   scripts    : %d" % len(scripts))
    print("   lua source : %d bytes" % source_bytes)
    for problem in problems[:20]:
        print("   FAIL %s" % problem)
    if problems:
        print("   %d problem(s)" % len(problems))
    else:
        print("   OK  every instance, name and source matches the tree on disk")
    return not problems


if __name__ == "__main__":
    targets = sys.argv[1:]
    if not targets:
        round_name = os.environ.get("ARKHER_ROUND", "ROUND8")
        targets = [os.path.join(REL, "ARKHER_V1_%s.rbxm" % round_name),
                   os.path.join(REL, "ARKHER_V1_%s.rbxl" % round_name),
                   os.path.join(REL, "ARKHER_V1_STUDIO_PLUGIN.rbxm")]
    ok = all(validate(target) for target in targets)
    print("\n%s" % ("ALL BINARIES VALID" if ok else "VALIDATION FAILED"))
    sys.exit(0 if ok else 1)
