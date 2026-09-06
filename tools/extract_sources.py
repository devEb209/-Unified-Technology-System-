#!/usr/bin/env python3
"""Verify/extract the inert recovered sources from the single release ZIP.

Examples:
  python EXTRAIR_FONTES.py 3_MAXIMOS_RECUPERADOS.zip --verify-only
  python EXTRAIR_FONTES.py 3_MAXIMOS_RECUPERADOS.zip --output fontes --package UTS
No network, dependencies, execution of archived code or overwriting of existing files.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import zipfile


def safe_name(name):
    if (not isinstance(name, str) or not name or name.startswith("/") or "\\" in name or "\x00" in name
            or len(name) > 2048 or any(p in ("", ".", "..", ".git") or ":" in p for p in name.split("/"))):
        raise ValueError(f"Unsafe source path: {name!r}")
    return name


def iter_sources(archive, package):
    prefix = f"FONTES/{package}/"
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError("Duplicate ZIP entries")
    manifest = json.loads(archive.read(prefix + "manifest.json"))
    if manifest["format"] != "uts-source-archive/1":
        raise ValueError("Unsupported source format")
    pages = sorted(n for n in names if re.fullmatch(re.escape(prefix) + r"pages/\d{6}\.json", n))
    if len(pages) != manifest["pages"] or len(pages) > 10000:
        raise ValueError("Page count mismatch or excessive page count")
    pending, parts, previous = None, [], ""
    files, total, inventory = 0, 0, hashlib.sha256()

    def finish(info, pieces):
        if len(pieces) != info["parts"]:
            raise ValueError("Missing fragments")
        content = "".join(pieces)
        if info["encoding"] == "utf-8":
            data = content.encode("utf-8")
        elif info["encoding"] == "base64":
            data = base64.b64decode(content, validate=True)
        else:
            raise ValueError("Unsupported source encoding")
        if len(data) != info["bytes"] or hashlib.sha256(data).hexdigest() != info["sha256"]:
            raise ValueError(f"Source integrity failure: {info['path']}")
        return info["path"], data

    for page in pages:
        if archive.getinfo(page).file_size > 180000:
            raise ValueError("Oversized source page")
        for record in json.loads(archive.read(page)):
            name = safe_name(record["path"])
            if not pending or name != pending["path"]:
                if pending:
                    path, data = finish(pending, parts)
                    files, total = files + 1, total + len(data)
                    inventory.update((path + "\0" + pending["sha256"] + "\n").encode("utf-8"))
                    yield path, data
                if name <= previous:
                    raise ValueError("Unsorted or duplicate sources")
                previous, pending, parts = name, record, []
                if not isinstance(record["parts"], int) or not 1 <= record["parts"] <= 32768:
                    raise ValueError("Invalid fragment count")
                if not isinstance(record["bytes"], int) or not 0 <= record["bytes"] <= 128 * 1024 * 1024:
                    raise ValueError("Invalid source size")
            if record["part"] != len(parts) + 1 or any(record[k] != pending[k] for k in ("parts", "encoding", "bytes", "sha256")):
                raise ValueError("Inconsistent/out-of-order fragments")
            parts.append(record["content"])
    if pending:
        path, data = finish(pending, parts)
        files, total = files + 1, total + len(data)
        inventory.update((path + "\0" + pending["sha256"] + "\n").encode("utf-8"))
        yield path, data
    if files != manifest["files"] or total != manifest["bytes"] or inventory.hexdigest() != manifest["inventorySha256"]:
        raise ValueError("Source manifest mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip", type=Path)
    parser.add_argument("--package", choices=("UTS", "ARKHE"), default="UTS")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not args.verify_only and args.output is None:
        parser.error("Use --verify-only or --output an empty directory")
    with zipfile.ZipFile(args.zip) as archive:
        # Exhaust the iterator: it verifies the final aggregate manifest after the last file.
        count = sum(1 for _ in iter_sources(archive, args.package))
        print(f"Verified {count:,} files byte-for-byte against their SHA-256 manifest ({args.package}).")
        if args.verify_only:
            return
        output = args.output.absolute()
        if any(p.is_symlink() for p in [output, *output.parents]):
            raise ValueError("Symlink output paths are not permitted")
        if output.exists() and (not output.is_dir() or any(output.iterdir())):
            raise ValueError("Output must be an empty directory; nothing will be overwritten")
        output.mkdir(parents=True, exist_ok=True)
        for name, data in iter_sources(archive, args.package):
            target = output.joinpath(*name.split("/"))
            # Refuse symlinks introduced after the initial output check as well.
            if any(p.is_symlink() for p in [target, *target.parents]):
                raise ValueError("Symlink encountered during extraction")
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(data)
        print(f"Extracted to {output}. These are preserved sources/data, not certified native applications.")


if __name__ == "__main__":
    main()
