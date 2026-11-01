"""Delivery safety checks use temporary source/live trees; never access the game."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('bed_deploy', Path(__file__).with_name('deploy-bed-sleep.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DeliverySafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='foundation-bed-delivery-test-')
        self.root = Path(self.temp.name)
        self.saved = {name: getattr(delivery, name) for name in ('ROOT', 'LIVE', 'BASELINE', 'BEFORE', 'PREVIOUS', 'ARCHIVES')}
        delivery.ROOT = self.root / 'source'
        delivery.LIVE = self.root / 'live'
        delivery.BASELINE = delivery.ROOT / '.runtime/before-manifest.json'
        delivery.BEFORE = delivery.BASELINE.parent / 'before'
        delivery.PREVIOUS = delivery.ROOT / 'docs/restored-systems-deployment.json'
        delivery.ARCHIVES = self.root / 'archives'
        baseline = {'root': str(delivery.ROOT), 'files': []}
        for rel in delivery.RUNTIME:
            self.put(delivery.ROOT / rel, '-- new bed file\n')
            baseline['files'].append({'path': rel, 'existed': False, 'sha256': None})
        delivery.write(delivery.BASELINE, baseline)
        old = {'sourceRoot': str(delivery.ROOT), 'liveRoot': str(delivery.LIVE), 'installed': True,
               'archiveRoot': str(self.root / 'prior-archive'), 'files': []}
        for i in range(58):
            rel = f'ixhl2rp/plugins/prior/file{i}.lua'
            for parent in (delivery.ROOT, delivery.LIVE): self.put(parent / rel, '-- previous\n')
            old['files'].append({'path': rel, 'sha256': delivery.sha(delivery.ROOT / rel)})
        delivery.write(delivery.PREVIOUS, old)
        delivery.write(self.root / 'prior-archive/manifest.json', old)

    def tearDown(self):
        for name, value in self.saved.items(): setattr(delivery, name, value)
        self.temp.cleanup()

    def put(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf8')

    def test_clean_scope_four_new_and_prior_58_verified(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        self.assertEqual(len(records), 4)
        self.assertEqual(len(delivery.evidence_hashes(records)), 62)
        self.assertFalse(report['conflicts'])
        self.assertTrue(report['previousRestoration']['verified'])
        self.assertEqual({r['status'] for r in report['files']}, {'new'})

    def test_unrelated_installed_change_blocks(self):
        self.put(delivery.LIVE / 'ixhl2rp/plugins/prior/file0.lua', '-- external change\n')
        report = delivery.plan(delivery.collect_scope())
        self.assertEqual(len(report['conflicts']), 1)
        self.assertFalse(report['previousRestoration']['verified'])

    def test_unrelated_source_change_blocks(self):
        self.put(delivery.ROOT / 'ixhl2rp/plugins/prior/file0.lua', '-- external source change\n')
        self.assertFalse(delivery.previous_check(delivery.collect_scope())['verified'])

    def test_new_live_collision_and_unscoped_plugin_file_block(self):
        self.put(delivery.LIVE / delivery.RUNTIME[0], '-- someone else installed a plugin\n')
        self.put(delivery.LIVE / delivery.PLUGIN / 'other.lua', '-- preserve me\n')
        self.assertEqual(len(delivery.plan(delivery.collect_scope())['conflicts']), 2)

    def test_changed_after_plan_and_path_escape_rejected(self):
        report = delivery.plan(delivery.collect_scope())
        self.put(delivery.LIVE / delivery.RUNTIME[0], '-- changed after backup\n')
        with self.assertRaisesRegex(RuntimeError, 'changed since backup'):
            delivery.verify_unchanged(report['files'])
        with self.assertRaisesRegex(RuntimeError, 'escapes root'):
            delivery.inside(delivery.ROOT, '../outside.lua')

    def test_zip_rejects_unscoped_previous_runtime(self):
        records = delivery.collect_scope()
        archive = self.root / 'payload.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for r in records: z.write(delivery.ROOT / r['path'], 'garrysmod/gamemodes/' + r['path'])
        delivery.verify_zip(archive, records, {})
        with zipfile.ZipFile(archive, 'a') as z:
            z.writestr('garrysmod/gamemodes/ixhl2rp/plugins/prior/file0.lua', '-- previous\n')
        with self.assertRaisesRegex(RuntimeError, 'unscoped runtime'):
            delivery.verify_zip(archive, records, {})

    def test_failed_install_rolls_back_only_own_bytes(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        out = delivery.ARCHIVES / 'HL2RP-bed-sleep-20261008-fixture'
        for record in records:
            self.put(out / 'package/garrysmod/gamemodes' / record['path'], '-- new bed file\n')
        backup = out / 'source-backup/before-manifest.json'
        backup.parent.mkdir(parents=True)
        delivery.shutil.copy2(delivery.BASELINE, backup)
        archive = out / 'Foundation-Bed-Sleep.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for r in records: z.write(delivery.ROOT / r['path'], 'garrysmod/gamemodes/' + r['path'])
        delivery.write(out / 'manifest.json', {**report, 'supportHashes': {}, 'archiveSHA256': delivery.sha(archive)})
        real_copy = delivery.shutil.copy2
        concurrent = delivery.LIVE / (delivery.PLUGIN + '/cl_sleep.lua')
        def injected_copy(source, destination, *args, **kwargs):
            if Path(destination).name.startswith('sv_sleep.lua.bed-sleep-stage-'):
                self.put(concurrent, '-- concurrent external change\n')
                raise OSError('simulated copy failure')
            return real_copy(source, destination, *args, **kwargs)
        with patch.object(delivery, 'validate_evidence', return_value={}), patch.object(delivery.shutil, 'copy2', side_effect=injected_copy):
            with self.assertRaisesRegex(OSError, 'simulated copy failure'):
                delivery.install(out)
        self.assertEqual(concurrent.read_text(), '-- concurrent external change\n')
        for rel in delivery.RUNTIME:
            if not rel.endswith('/cl_sleep.lua'): self.assertFalse((delivery.LIVE / rel).exists())
        self.assertTrue(delivery.previous_check(records)['verified'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
