"""Focused checks on the delivery wrapper; only isolated temporary files are mutated."""
from pathlib import Path
import hashlib
import importlib.util
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('equipment_models_delivery', Path(__file__).with_name('deploy-equipment-model-actions.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)
d = delivery.d


class Safety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='foundation-equipment-models-test-')
        self.root = Path(self.temp.name)

    def tearDown(self):
        resolved = self.root.resolve()
        self.assertTrue(resolved.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.assertTrue(resolved.name.startswith('foundation-equipment-models-test-'))
        self.temp.cleanup()

    def test_paths_cannot_escape_destination(self):
        with self.assertRaises(RuntimeError): d.inside(self.root, '../outside.lua')

    def test_private_pose_changes_are_observed_without_restoring_or_copying(self):
        private = self.root / 'pose_studio.txt'
        private.write_bytes(b'old user save')
        baseline = self.root / 'metadata.json'
        d.write(baseline, {'path': str(private), 'sha256': d.sha(private), 'bytes': private.stat().st_size, 'contentCopied': False})
        private.write_bytes(b'new user save')
        with patch.object(d, 'PRIVATE_DATA', private), patch.object(d, 'PRIVATE_BASELINE', baseline):
            result = delivery.private_data_check()
        self.assertFalse(result['unchangedFromStart'])
        self.assertFalse(result['contentCopied'])
        self.assertFalse(result['modifiedByDelivery'])
        self.assertEqual(private.read_bytes(), b'new user save')

    def test_zip_accepts_only_exact_scoped_runtime(self):
        archive = self.root / 'package.zip'
        rel = 'ixhl2rp/plugins/example/cl.lua'
        payload = b'-- scoped'
        records = [{'path': rel, 'sha256': hashlib.sha256(payload).hexdigest()}]
        with zipfile.ZipFile(archive, 'w') as z: z.writestr('garrysmod/gamemodes/' + rel, payload)
        d.verify_zip(archive, records, {})
        with zipfile.ZipFile(archive, 'a') as z: z.writestr('garrysmod/gamemodes/ixhl2rp/unscoped.lua', b'-- no')
        with self.assertRaises(RuntimeError): d.verify_zip(archive, records, {})

    def test_zip_rejects_private_saved_pose_content(self):
        archive = self.root / 'private.zip'
        with zipfile.ZipFile(archive, 'w') as z: z.writestr('data/pose_studio.txt', b'private')
        with self.assertRaises(RuntimeError): d.verify_zip(archive, [], {})

    def test_zip_rejects_third_party_model_assets_even_when_listed_as_support(self):
        for extension in ('.mdl', '.vvd', '.vtx', '.phy'):
            archive = self.root / ('asset' + extension + '.zip')
            name = '.runtime/models/extracted' + extension
            payload = b'not distributable runtime'
            with zipfile.ZipFile(archive, 'w') as z: z.writestr(name, payload)
            with self.assertRaises(RuntimeError):
                d.verify_zip(archive, [], {name: hashlib.sha256(payload).hexdigest()})

    def test_three_author_baselines_share_only_immutable_before_directory(self):
        with patch.object(delivery, '_read_baseline_rows', return_value={
            'ixhl2rp/plugins/example.lua': ({'path':'ixhl2rp/plugins/example.lua'}, self.root/'incorrect')
        }), patch.object(d, 'BASE_DIR', self.root):
            row, before = delivery.read_baseline_rows()['ixhl2rp/plugins/example.lua']
        self.assertEqual(before, self.root/'before')
        self.assertEqual(row['path'], 'ixhl2rp/plugins/example.lua')

    def test_changed_author_payload_is_rejected_before_freeze(self):
        runtime = self.root/'cl.lua'
        runtime.write_text('-- changed', encoding='utf8')
        final = self.root/'final.json'
        d.write(final, {'root':str(self.root), 'files':[
            {'path':'cl.lua', 'sha256':'0'*64, 'runtime':True}]})
        with patch.object(delivery, 'ROOT', self.root), patch.object(delivery, 'AUTHOR_MANIFESTS', (final,)):
            with self.assertRaisesRegex(RuntimeError, 'Author freeze changed'):
                delivery.verify_authors()


if __name__ == '__main__': unittest.main()
