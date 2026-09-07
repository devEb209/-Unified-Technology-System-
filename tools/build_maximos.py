#!/usr/bin/env python3
"""Reproducible recovery bundles; preserves data without pretending templates are physics.

Requires Python 3.11+, Node 22+, npm ci in tools/roblox-package (see docs).
The pinned Git snapshot is read through git cat-file, never through mutable source paths.
No 100K-file extraction, server, credential, remote asset or code execution from the archive.
"""
from __future__ import annotations

import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE_COMMIT = "d9087f9ba26bf171fe175d274d925b4cd5f911f2"
VERSION = "2026.09.06-recovered.1"
OUT = ROOT / "downloads" / "2026-09-06"
STAGE = ROOT / "build" / "maximos"
MAX_VALUE_BYTES = 180_000
FRAGMENT_CHARACTERS = 8192


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_text(value) -> str:
    # ASCII JSON also avoids XML/control-character and UTF-8 byte/character limit ambiguity.
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)


def safe_path(name: str) -> str:
    path = PurePosixPath(name)
    if (not name or name.startswith("/") or "\\" in name or "\x00" in name
            or any(p in ("", ".", "..", ".git") for p in name.split("/"))
            or any(":" in p for p in path.parts) or len(name) > 2048):
        raise ValueError(f"Unsafe archive path: {name!r}")
    return name


def read_baseline() -> tuple[dict[str, bytes], dict]:
    tree = subprocess.check_output(["git", "ls-tree", "-r", "-z", BASE_COMMIT], cwd=ROOT)
    objects = []
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        header, raw_path = entry.split(b"\t", 1)
        mode, kind, oid = header.split()
        name = safe_path(raw_path.decode("utf-8"))
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise ValueError(f"Unexpected source object: {name}")
        if name.endswith(".zip") and name != "ARKHE_100K_SINGLE_FILE.zip":
            continue  # the three other ZIPs duplicate the unpacked UTS/DsOS source trees
        objects.append((name, oid))
    sources, legacy_bytes = {}, None
    process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=ROOT,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for name, oid in objects:
            process.stdin.write(oid + b"\n")
            process.stdin.flush()
            header = process.stdout.readline().split()
            if len(header) != 3 or header[1] != b"blob":
                raise ValueError(f"Cannot read source blob: {name}")
            data = process.stdout.read(int(header[2]))
            if len(data) != int(header[2]) or process.stdout.read(1) != b"\n":
                raise ValueError(f"Truncated source blob: {name}")
            if name == "ARKHE_100K_SINGLE_FILE.zip":
                legacy_bytes = data
            else:
                sources["repository/" + name] = data
    finally:
        process.stdin.close()
        process.stdout.close()
        if process.wait() != 0:
            raise RuntimeError("git cat-file failed")
    if legacy_bytes is None:
        raise ValueError("The baseline lacks the legacy archive")
    baseline_count = len(sources)
    with zipfile.ZipFile(io.BytesIO(legacy_bytes)) as archive:
        if archive.testzip() is not None:
            raise ValueError("Legacy ZIP CRC validation failed")
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = "legacy/" + safe_path(info.filename)
            if name in sources:
                raise ValueError(f"Duplicate legacy entry: {name}")
            sources[name] = archive.read(info)
    provenance = {
        "baseCommit": BASE_COMMIT, "baselineFilesPreserved": baseline_count,
        "legacyZip": "ARKHE_100K_SINGLE_FILE.zip", "legacyZipSha256": sha256(legacy_bytes),
        "legacyFilesPreserved": len(sources) - baseline_count,
        "redundantZipsOmitted": ["UTS_5K_MOST_POWERFUL_AI.zip", "DsOS_5K_DIVINE_OS.zip", "UTS_DsOS_10K_SINGLE.zip"],
        "priorLocalCommit961ee39": "not available locally or via GitHub commit lookup",
        "prior138080FilesClaim": "not recovered; not certified",
        "physicalSystemsClaim": "not measured; legacy counters are not evidence of physical simulation",
    }
    return sources, provenance


def pack_sources(sources: dict[str, bytes]) -> dict:
    pages, page, page_size = [], [], 2
    fragments = 0
    inventory = hashlib.sha256()
    for name, data in sorted(sources.items()):
        safe_path(name)
        if not isinstance(data, bytes):
            raise TypeError("Archive input must be bytes")
        digest = sha256(data)
        inventory.update((name + "\0" + digest + "\n").encode("utf-8"))
        try:
            content, encoding = data.decode("utf-8"), "utf-8"
        except UnicodeDecodeError:
            content, encoding = base64.b64encode(data).decode("ascii"), "base64"
        pieces = [content[i:i + FRAGMENT_CHARACTERS] for i in range(0, len(content), FRAGMENT_CHARACTERS)] or [""]
        for number, piece in enumerate(pieces, 1):
            record = {"path": name, "bytes": len(data), "encoding": encoding,
                      "sha256": digest, "part": number, "parts": len(pieces), "content": piece}
            serialized = json_text(record)
            if len(serialized) + 2 > MAX_VALUE_BYTES:
                raise ValueError("Fragment exceeds StringValue budget")
            required = len(serialized) + (1 if page else 0)
            if page_size + required > MAX_VALUE_BYTES:
                pages.append(page)
                page, page_size, required = [], 2, len(serialized)
            page.append(record)
            page_size += required
            fragments += 1
    if page:
        pages.append(page)
    encoded_pages, index = {}, []
    for number, records in enumerate(pages, 1):
        name, content = f"{number:06d}", json_text(records)
        encoded_pages[name] = content
        index.append({"name": name, "first": records[0]["path"], "last": records[-1]["path"],
                      "records": len(records), "sha256": sha256(content.encode("ascii"))})
    indexes, batch = {}, []
    for entry in index:
        if batch and len(json_text(batch + [entry])) > MAX_VALUE_BYTES:
            indexes[f"{len(indexes) + 1:06d}"] = json_text(batch)
            batch = []
        batch.append(entry)
    if batch:
        indexes[f"{len(indexes) + 1:06d}"] = json_text(batch)
    result = {
        "manifest": {"format": "uts-source-archive/1", "files": len(sources),
                     "bytes": sum(map(len, sources.values())), "fragments": fragments, "pages": len(pages),
                     "inventorySha256": inventory.hexdigest(), "status": "preserved data, not executed or certified as functional"},
        "pages": encoded_pages, "index": indexes,
    }
    verify_packed(result, sources)
    return result


def verify_packed(packed: dict, originals: dict[str, bytes]) -> None:
    recovered, inventory = {}, hashlib.sha256()
    for text in packed["pages"].values():
        assert len(text.encode("utf-8")) <= MAX_VALUE_BYTES
        for record in json.loads(text):
            current = recovered.setdefault(record["path"], {"info": record, "pieces": {}})
            assert record["part"] not in current["pieces"], "Duplicate fragment"
            assert 1 <= record["part"] <= record["parts"]
            for key in ("sha256", "bytes", "parts", "encoding"):
                assert record[key] == current["info"][key]
            current["pieces"][record["part"]] = record["content"]
    assert recovered.keys() == originals.keys(), "Missing or unexpected sources"
    for name, item in sorted(recovered.items()):
        info, pieces = item["info"], item["pieces"]
        assert len(pieces) == info["parts"]
        text = "".join(pieces[i] for i in range(1, info["parts"] + 1))
        data = text.encode("utf-8") if info["encoding"] == "utf-8" else base64.b64decode(text, validate=True)
        assert data == originals[name] and len(data) == info["bytes"] and sha256(data) == info["sha256"]
        inventory.update((name + "\0" + info["sha256"] + "\n").encode("utf-8"))
    assert inventory.hexdigest() == packed["manifest"]["inventorySha256"]
    assert len(recovered) == packed["manifest"]["files"]


def instance(cls: str, name: str, children=(), value=None) -> dict:
    result = {"className": cls, "name": name, "children": list(children)}
    if value is not None:
        result["properties"] = {"Source" if cls == "ModuleScript" else "Value": {"String": value}}
    return result


def string(name, value):
    return instance("StringValue", name, value=value)


def folder(name, children=()):
    return instance("Folder", name, children)


def module(name: str, relative: str) -> dict:
    return instance("ModuleScript", name, value=(ROOT / relative).read_text(encoding="utf-8"))


def archive_folder(name: str, packed: dict) -> dict:
    return folder(name, [string("Manifest", json_text(packed["manifest"])),
                         folder("Index", [string(k, v) for k, v in packed["index"].items()]),
                         folder("Pages", [string(k, v) for k, v in packed["pages"].items()])])


def model(kind: str, packed=None) -> dict:
    names = {"UTS": "UTS_MAXIMO_RECUPERADO", "ARKHE": "ARKHE_MAXIMO_RECUPERADO", "AUTO_ORGANIZER": "AUTO_ORGANIZER_MAXIMO"}
    notice = ("Reconstrucao " + VERSION + ". Modelo/biblioteca, nao um mapa nem aplicativo Android/PC. "
              "Importe em um place aberto usando Inserir de arquivo e veja o Explorer. "
              "Nao de Play antes de organizar: a biblioteca deve ficar no ServerStorage. "
              "Legado preservado como dados; nao e prova de sistemas fisicos funcionais. "
              "Binary/round-trip testados fora do Studio; importacao e runtime no Studio NAO testados.")
    children = [string("PackageFormat", "uts-recovery/1"), string("PackageKind", kind),
                string("PackageVersion", VERSION), string("LEIA_ME", notice)]
    if kind == "AUTO_ORGANIZER":
        children += [folder("Runtime", [module("Organizer", "roblox/AutoOrganizer/Organizer.luau"),
                                         module("Studio", "roblox/AutoOrganizer/Studio.luau")]),
                     string("COMANDOS", 'Selecione apenas UTS e/ou ARKHE no Explorer.\n'
                            'local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); s.Preview()\n'
                            'Apos conferir o Output, rode:\n'
                            'local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); print(s.Apply("INSTALAR"))\n'
                            'Para reverter nesta sessao, mantendo as embalagens importadas:\n'
                            'local s = require(workspace.AUTO_ORGANIZER_MAXIMO.Runtime.Studio); print(s.Undo("DESFAZER"))')]
    else:
        runtime = [module("BudgetScheduler", "roblox/UTS/BudgetScheduler.luau"),
                   module("SourceArchive", "roblox/UTS/SourceArchive.luau")]
        if kind == "ARKHE":
            runtime += [module("VisualProfile", "roblox/Arkhe/VisualProfile.luau"),
                        module("SceneAudit", "roblox/Arkhe/SceneAudit.luau")]
        destination = "UTS" if kind == "UTS" else "Arkhe"
        children += [folder("Payload", [
            folder("ServerStorage", [archive_folder(destination + "_SourceArchive", packed)]),
            folder("ReplicatedStorage", [folder(destination, [folder("Runtime", runtime), string("NOTICE", notice)])]),
        ])]
    return {"className": "DataModel", "children": [instance("Model", names[kind], children)]}


def write_zip(path: Path, entries) -> None:
    seen = set()
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in entries:
            safe_path(name)
            if name in seen:
                raise ValueError(f"Duplicate output ZIP entry: {name}")
            seen.add(name)
            info = zipfile.ZipInfo(name, date_time=(2026, 9, 6, 0, 0, 0))
            info.compress_type, info.create_system = zipfile.ZIP_DEFLATED, 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, "Bundle CRC failure"
        assert set(archive.namelist()) == seen


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    STAGE.mkdir(parents=True, exist_ok=True)
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern="test_*.py", top_level_dir=str(ROOT))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise SystemExit("Python tests failed")
    subprocess.run(["node", str(ROOT / "tools/roblox-package/test-luau.mjs"), str(STAGE / "luau-tests.json")], check=True, cwd=ROOT)
    sources, provenance = read_baseline()
    print(f"Preserving {len(sources):,} available source/data files; no physical-system count inferred.", flush=True)
    packed_uts = pack_sources(sources)
    arkhe_docs = {"README.md", "LICENSE", "LICENSE-COMMERCIAL", "LICENSE-LEGAL", "ARKHE_GAPS_5000.txt",
                  "ARKHE_MASTER_EVOLUTION_100K_100M.txt", "TUDO_QUE_FIZ_UES_UTS_SNB_DsOS_SINGULARITY_ARKHE.txt"}
    arkhe_sources = {k: v for k, v in sources.items() if k.startswith("repository/ArkheRoblox/") or k.removeprefix("repository/") in arkhe_docs}
    packed_arkhe = pack_sources(arkhe_sources)
    reports, outputs = [], []
    for kind, packed in [("UTS", packed_uts), ("ARKHE", packed_arkhe), ("AUTO_ORGANIZER", None)]:
        spec = model(kind, packed)
        name = spec["children"][0]["name"]
        spec_path, target, report_path = STAGE / (name + ".json"), OUT / (name + ".rbxm"), STAGE / (name + ".validation.json")
        spec_path.write_text(json_text(spec), encoding="ascii")
        subprocess.run(["node", "--expose-gc", "--max-old-space-size=2200", str(ROOT / "tools/roblox-package/package-model.mjs"),
                        str(spec_path), str(target), str(report_path)], check=True, cwd=ROOT)
        reports.append(json.loads(report_path.read_text()))
        outputs.append(target)
    validation = {
        "version": VERSION, "provenance": provenance,
        "sourceArchives": {"UTS": packed_uts["manifest"], "ARKHE": packed_arkhe["manifest"]},
        "sourceByteForByteRecoveryAndSha256": "passed",
        "pythonUnitTests": {"passed": result.testsRun, "skipped": len(result.skipped)},
        "luauUnitTests": json.loads((STAGE / "luau-tests.json").read_text()),
        "models": reports, "robloxStudio": "NOT_TESTED", "hyperrealismBenchmark": "NOT_IMPLEMENTED / NOT_MEASURED",
        "notRecovered": ["961ee39", "the claimed 138080-file final build", "the former Auto Organizer source", "the claimed 620-folder/5580-module Roblox model"],
    }
    validation_text = json.dumps(validation, ensure_ascii=False, indent=2) + "\n"
    checksum_models = "".join(f"{r['sha256']}  {r['file']}\n" for r in reports)

    def entries():
        for path in outputs:
            yield path.name, path.read_bytes()
        yield "VALIDACAO.json", validation_text.encode("utf-8")
        yield "CHECKSUMS_MODELOS.sha256", checksum_models.encode("ascii")
        for source, dest in [("docs/MAXIMOS_RECUPERADOS.md", "LEIA_ME_PRIMEIRO.md"),
                             ("docs/HIPERREALISMO_UTS_ARKHE.md", "HIPERREALISMO_UTS_ARKHE.md"),
                             ("tools/extract_sources.py", "EXTRAIR_FONTES.py")]:
            yield dest, (ROOT / source).read_bytes()
        for name in ("LICENSE", "LICENSE-COMMERCIAL", "LICENSE-LEGAL"):
            yield name, sources["repository/" + name]
        for kind, packed in [("UTS", packed_uts), ("ARKHE", packed_arkhe)]:
            yield f"FONTES/{kind}/manifest.json", json_text(packed["manifest"]).encode("ascii")
            for category in ("index", "pages"):
                for name, text in packed[category].items():
                    yield f"FONTES/{kind}/{category}/{name}.json", text.encode("ascii")
        for base in ("roblox", "tests", "tools"):
            for path in sorted((ROOT / base).rglob("*")):
                if path.is_file() and not set(path.parts).intersection({"node_modules", "__pycache__"}):
                    yield "RECONSTRUCAO/" + path.relative_to(ROOT).as_posix(), path.read_bytes()

    bundle = OUT / "3_MAXIMOS_RECUPERADOS.zip"
    write_zip(bundle, entries())
    with zipfile.ZipFile(bundle) as archive:
        for path in outputs:
            assert archive.read(path.name) == path.read_bytes()
    (OUT / "VALIDACAO.json").write_text(validation_text, encoding="utf-8")
    artifacts = [{"file": p.name, "bytes": p.stat().st_size, "sha256": sha256(p.read_bytes())} for p in [*outputs, bundle]]
    manifest = {"version": VERSION, "scope": "all available baseline and legacy data; not a recovered copy of missing commit 961ee39",
                "artifacts": artifacts, "zipCrcAndModelBytes": "passed", "studioImport": "NOT_TESTED"}
    (OUT / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (OUT / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['file']}\n" for a in artifacts), encoding="ascii")
    size = sum(p.stat().st_size for p in OUT.iterdir() if p.is_file())
    if size > 120 * 1024 * 1024:
        raise SystemExit("Release exceeds patch-size budget; do not add it to Git")
    print(json.dumps(manifest, indent=2))
    print(f"Release bytes (all deliverables): {size:,}; Studio smoke test is still required.")


if __name__ == "__main__":
    main()
