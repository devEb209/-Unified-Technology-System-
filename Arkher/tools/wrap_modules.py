#!/usr/bin/env python3
"""ARKHER build tool: normalize kernel/catalog Lua sources into the ARKHER module
factory form so the exact same file loads in Roblox (via require(ModuleScript)(A))
and headless (via the Node/fengari harness). Idempotent."""
import sys, os, re

MARK = "--@arkher-module"

def wrap(path):
    src = open(path, encoding="utf-8").read()
    if MARK in src:
        return False
    lines = src.split("\n")
    head = []
    i = 0
    while i < len(lines) and (lines[i].startswith("--") or lines[i].strip() == ""):
        head.append(lines[i]); i += 1
    body = lines[i:]
    out = []
    out.extend(head)
    out.append(MARK)
    out.append("return function(A)")
    for ln in body:
        ln = re.sub(r'require\("([^"]+)"\)', r'A:import("\1")', ln)
        out.append(("\t" + ln) if ln.strip() else ln)
    out.append("end")
    open(path, "w", encoding="utf-8").write("\n".join(out).rstrip() + "\n")
    return True

def main():
    roots = sys.argv[1:] or ["src"]
    n = 0
    for root in roots:
        for dirpath, _, files in os.walk(root):
            for f in files:
                if f.endswith(".lua"):
                    if wrap(os.path.join(dirpath, f)):
                        n += 1
    print("wrapped %d modules" % n)

main()
