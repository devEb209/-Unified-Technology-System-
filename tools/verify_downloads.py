#!/usr/bin/env python3
"""Verify the exact four public, immutable raw downloads AFTER a successful Git push.

Usage: python3 tools/verify_downloads.py <40-character-commit-sha>
No server, preview link, API token, HTML page or third-party upload is used.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'downloads' / '2026-09-06'
ALLOWED = {'UTS_MAXIMO_RECUPERADO.rbxm', 'ARKHE_MAXIMO_RECUPERADO.rbxm',
           'AUTO_ORGANIZER_MAXIMO.rbxm', '3_MAXIMOS_RECUPERADOS.zip'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('commit')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.commit):
        parser.error('Provide the full immutable commit SHA, not a branch or a guessed URL')
    manifest = json.loads((RELEASE / 'MANIFEST.json').read_text())
    if {entry['file'] for entry in manifest['artifacts']} != ALLOWED:
        raise ValueError('Unexpected release artifact names')
    results = []
    for entry in manifest['artifacts']:
        url = ('https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/'
               + args.commit + '/downloads/2026-09-06/' + urllib.parse.quote(entry['file'], safe=''))
        request = urllib.request.Request(url, headers={'User-Agent': 'UTS-Recovery-Validation/1', 'Accept-Encoding': 'identity'})
        digest, count = hashlib.sha256(), 0
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 200:
                raise ValueError(f'Not a complete HTTP 200 response: {url}')
            mime = response.headers.get_content_type()
            if mime.startswith('text/'):
                raise ValueError(f'Expected a binary download, received {mime}: {url}')
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                count += len(block)
                digest.update(block)
            result = {'file': entry['file'], 'url': url, 'status': response.status,
                      'contentType': mime, 'contentDisposition': response.headers.get('Content-Disposition'),
                      'bytes': count, 'sha256': digest.hexdigest()}
        if count != entry['bytes'] or digest.hexdigest() != entry['sha256']:
            raise ValueError(f'Download hash/size mismatch: {entry["file"]}')
        results.append(result)
        print(f'OK {entry["file"]}: HTTP 200, {count} bytes, SHA-256 matched', flush=True)
    report = {'commit': args.commit, 'verification': 'downloaded every byte; compared size and SHA-256', 'downloads': results}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
