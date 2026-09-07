import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('arkher_progress', ROOT / 'arkher/tools/progress.py')
progress = importlib.util.module_from_spec(spec)
spec.loader.exec_module(progress)


class ProgressTests(unittest.TestCase):
    def test_scope_has_every_family_and_stable_denominator(self):
        entries, families = progress.extract((ROOT / 'ARKHER STUDIOS👑').read_bytes())
        self.assertEqual(set(families), set('ABCDEFGHIJKLMNOPQRSTUVWXYZ'))
        self.assertEqual(len(entries), 860)
        self.assertEqual(sum(len(item['sourceMentions']) for item in entries), 872)

    def test_npc_aliases_are_not_counted_as_new_systems(self):
        entries, _ = progress.extract((ROOT / 'ARKHER STUDIOS👑').read_bytes())
        perception = [item for item in entries if item['id'] == 'K/NPC Perception']
        self.assertEqual(len(perception), 1)
        self.assertEqual(len(perception[0]['sourceMentions']), 2)
        self.assertFalse(any(item['id'] == 'K/perception' for item in entries))

    def test_external_reference_names_are_not_arkher_implementations(self):
        entries, _ = progress.extract((ROOT / 'ARKHER STUDIOS👑').read_bytes())
        self.assertFalse(any(item['name'] in ['DLSS', 'FSR', 'XeSS'] for item in entries))

    def test_changed_brief_requires_explicit_review(self):
        with self.assertRaises(ValueError):
            progress.extract((ROOT / 'ARKHER STUDIOS👑').read_bytes() + b'\nchanged')

    def test_partial_coverage_never_becomes_completion(self):
        report = json.loads((ROOT / 'arkher/progress/REPORT.json').read_text())
        self.assertEqual(report['partialWithEvidence'] + report['withoutImplementation'], report['explicitEntries'])
        self.assertEqual(report['completeValidated'], 0)
        self.assertEqual(report['validatedCompletionPercent'], 0)
        self.assertIsNone(report['effortRemainingPercent'])
        self.assertEqual(report['formalTargets']['status'], 'NOT_CERTIFIED')
        self.assertAlmostEqual(report['codeCoveragePercent'] + report['withoutImplementationPercent'], 100)
        self.assertTrue(all(item['status'] in ['partial', 'not_implemented'] for item in report['entries']))


if __name__ == '__main__':
    unittest.main()
