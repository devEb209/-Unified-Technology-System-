import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from tools.build_maximos import (MAX_VALUE_BYTES, FRAGMENT_CHARACTERS, pack_sources, verify_packed,
                                safe_path, write_zip, model, json_text)
from tools.extract_sources import iter_sources, safe_name


class RecoveryTests(unittest.TestCase):
    def test_empty_archive(self):
        packed = pack_sources({})
        self.assertEqual(packed['manifest']['files'], 0)
        self.assertEqual(packed['pages'], {})

    def test_byte_exact_utf8_controls_binary_and_empty(self):
        originals = {'source/acentos-👑.txt': 'Olá\r\n<xml>&\x00]]>⚜️'.encode(),
                     'source/binary.bin': bytes(range(256)), 'source/empty': b''}
        packed = pack_sources(originals)
        verify_packed(packed, originals)
        self.assertEqual(packed['manifest']['files'], 3)
        self.assertTrue(all(v.isascii() for v in packed['pages'].values()))

    def test_large_unicode_is_fragmented_under_studio_value_budget(self):
        packed = pack_sources({'source/huge.txt': ('👑' * (FRAGMENT_CHARACTERS * 8)).encode()})
        self.assertGreater(len(packed['pages']), 1)
        self.assertTrue(all(len(v.encode()) <= MAX_VALUE_BYTES for v in packed['pages'].values()))
        self.assertTrue(all(len(v.encode()) <= MAX_VALUE_BYTES for v in packed['index'].values()))

    def test_deterministic_sorted_sources(self):
        self.assertEqual(pack_sources({'b': b'2', 'a': b'1'}), pack_sources({'a': b'1', 'b': b'2'}))

    def test_tampering_is_detected(self):
        originals = {'a': b'original'}
        packed = pack_sources(originals)
        page = json.loads(packed['pages']['000001'])
        page[0]['content'] = 'changed'
        packed['pages']['000001'] = json_text(page)
        with self.assertRaises(AssertionError):
            verify_packed(packed, originals)

    def test_missing_fragment_is_detected(self):
        originals = {'a': b'x' * (FRAGMENT_CHARACTERS + 1)}
        packed = pack_sources(originals)
        page = json.loads(packed['pages']['000001'])
        page.pop()
        packed['pages']['000001'] = json_text(page)
        with self.assertRaises(AssertionError):
            verify_packed(packed, originals)

    def test_duplicate_fragment_is_detected(self):
        originals = {'a': b'data'}
        packed = pack_sources(originals)
        page = json.loads(packed['pages']['000001'])
        packed['pages']['000001'] = json_text(page + page)
        with self.assertRaises(AssertionError):
            verify_packed(packed, originals)

    def test_unsafe_paths_rejected_by_both_tools(self):
        for path in ['', '/a', '../a', 'a/../b', 'a//b', './x', 'C:/x', 'a\\b', 'a\x00b', '.git/config']:
            with self.subTest(path=path):
                for validator in (safe_path, safe_name):
                    with self.assertRaises(ValueError): validator(path)

    def test_zip_is_deterministic_and_crc_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / '1.zip', Path(directory) / '2.zip'
            entries = [('model.rbxm', b'bytes'), ('fontes/acentos.txt', 'Olá'.encode())]
            write_zip(first, entries)
            write_zip(second, entries)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(archive.read('model.rbxm'), b'bytes')

    def test_zip_rejects_duplicates(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                write_zip(Path(directory) / 'x.zip', [('a', b''), ('a', b'')])

    def test_zip_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                write_zip(Path(directory) / 'x.zip', [('../escape', b'')])

    def test_all_model_specs_are_inert_and_names_unique(self):
        packed = pack_sources({'a': b'data'})
        for kind in ('UTS', 'ARKHE', 'AUTO_ORGANIZER'):
            spec = model(kind, packed)
            def walk(node):
                self.assertIn(node['className'], ('DataModel', 'Model', 'Folder', 'ModuleScript', 'StringValue'))
                children = node.get('children', [])
                self.assertEqual(len(children), len({c['name'] for c in children}))
                for child in children: walk(child)
            walk(spec)
            self.assertEqual(len(spec['children']), 1)
            self.assertEqual(spec['children'][0]['className'], 'Model')

    def test_extractor_round_trip_and_final_manifest(self):
        originals = {'a.txt': b'x' * 9000, 'binary.dat': b'\xff\xfe', 'z.txt': 'Olá'.encode()}
        packed = pack_sources(originals)
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, 'w') as z:
            z.writestr('FONTES/UTS/manifest.json', json_text(packed['manifest']))
            for name, page in packed['pages'].items():
                z.writestr(f'FONTES/UTS/pages/{name}.json', page)
        with zipfile.ZipFile(io.BytesIO(raw.getvalue())) as z:
            self.assertEqual(dict(iter_sources(z, 'UTS')), originals)

    def test_extractor_detects_truncated_inventory(self):
        packed = pack_sources({'a': b'data'})
        manifest = copy.deepcopy(packed['manifest'])
        manifest['files'] += 1
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, 'w') as z:
            z.writestr('FONTES/UTS/manifest.json', json_text(manifest))
            for name, page in packed['pages'].items():
                z.writestr(f'FONTES/UTS/pages/{name}.json', page)
        with zipfile.ZipFile(io.BytesIO(raw.getvalue())) as z:
            with self.assertRaises(ValueError): list(iter_sources(z, 'UTS'))


if __name__ == '__main__':
    unittest.main()
