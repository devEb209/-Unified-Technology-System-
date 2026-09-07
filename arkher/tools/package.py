#!/usr/bin/env python3
"""Package only ARKHER, its exact brief, rebuild tools and validation evidence."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'arkher/releases/g1-development'
NAME = 'ARKHER_STUDIOS_G1_DEV.zip'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    validation = json.loads((OUTPUT / 'VALIDACAO.json').read_text())
    for source in validation['sources']:
        if digest((ROOT / 'arkher/src' / source['file']).read_bytes()) != source['sha256']:
            raise ValueError('Source changed after binary compilation: ' + source['file'])
    tests = (ROOT / 'build/arkher/tests.json').read_bytes()
    if json.loads(tests)['failed'] != 0:
        raise ValueError('Tests did not pass')
    (OUTPUT / 'TESTES.json').write_bytes(tests)
    entries = {
        'LEIA_ME.md': (ROOT / 'arkher/README.md').read_bytes(),
        'REQUISITOS_V1.md': (ROOT / 'arkher/V1_SCOPE.md').read_bytes(),
        'BRIEF_ORIGINAL.txt': (ROOT / 'ARKHER STUDIOS👑').read_bytes(),
        'VALIDACAO.json': (OUTPUT / 'VALIDACAO.json').read_bytes(),
        'TESTES.json': tests,
        'PROGRESSO.md': (ROOT / 'arkher/progress/README.md').read_bytes(),
        'PROGRESSO.json': (ROOT / 'arkher/progress/REPORT.json').read_bytes(),
        'LICENSE': (ROOT / 'LICENSE').read_bytes(),
        'LICENSE-COMMERCIAL': (ROOT / 'LICENSE-COMMERCIAL').read_bytes(),
        'LICENSE-LEGAL': (ROOT / 'LICENSE-LEGAL').read_bytes(),
    }
    for artifact in validation['artifacts']:
        data = (OUTPUT / artifact['file']).read_bytes()
        if len(data) != artifact['bytes'] or digest(data) != artifact['sha256']:
            raise ValueError('Artifact changed after binary validation')
        entries[artifact['file']] = data
    for folder in ['arkher/src', 'arkher/tests', 'arkher/tools', 'arkher/progress']:
        for path in sorted((ROOT / folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                entries['SOURCE/' + path.relative_to(ROOT).as_posix()] = path.read_bytes()
    for file in ['arkher/package.json', 'arkher/README.md', 'arkher/V1_SCOPE.md',
                 'tools/roblox-package/package.json', 'tools/roblox-package/package-lock.json']:
        entries['SOURCE/' + file] = (ROOT / file).read_bytes()
    entries['SOURCE/ARKHER STUDIOS👑'] = entries['BRIEF_ORIGINAL.txt']
    for name in ['LICENSE','LICENSE-COMMERCIAL','LICENSE-LEGAL']:
        entries['SOURCE/' + name] = entries[name]
    entries['SHA256_MODELOS.txt'] = ''.join(a['sha256'] + '  ' + a['file'] + '\n' for a in validation['artifacts']).encode()
    with zipfile.ZipFile(OUTPUT / NAME, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            if name.startswith('/') or '..' in name.split('/'):
                raise ValueError('Unsafe ZIP entry')
            info = zipfile.ZipInfo(name, date_time=(2026, 9, 6, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with zipfile.ZipFile(OUTPUT / NAME) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(set(archive.namelist())) == len(entries)
        for name, expected in entries.items():
            assert archive.read(name) == expected
    artifacts = [{k: a[k] for k in ('file', 'bytes', 'sha256')} for a in validation['artifacts']]
    data = (OUTPUT / NAME).read_bytes()
    artifacts.append({'file': NAME, 'bytes': len(data), 'sha256': digest(data)})
    manifest = {'product': 'ARKHER STUDIOS', 'generation': 1, 'version': validation['version'],
                'status': 'DEVELOPMENT_NOT_COMPLETE_V1', 'zipEntries': len(entries),
                'zipCrcAndContents': 'passed', 'artifacts': artifacts,
                'robloxStudio': 'NOT_TESTED', 'formal10000Systems': 'NOT_CERTIFIED',
                'formal100000Features': 'NOT_CERTIFIED'}
    (OUTPUT / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (OUTPUT / 'SHA256SUMS.txt').write_text(''.join(a['sha256'] + '  ' + a['file'] + '\n' for a in artifacts))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
