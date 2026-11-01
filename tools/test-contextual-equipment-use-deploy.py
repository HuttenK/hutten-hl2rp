"""Focused checks on the delivery wrapper; only isolated temporary files are mutated."""
from pathlib import Path
import hashlib
import importlib.util
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('contextual_delivery', Path(__file__).with_name('deploy-contextual-equipment-use.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)
d = delivery.d


class Safety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='foundation-contextual-delivery-test-')
        self.root = Path(self.temp.name)

    def tearDown(self):
        resolved = self.root.resolve()
        self.assertTrue(resolved.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.assertTrue(resolved.name.startswith('foundation-contextual-delivery-test-'))
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


if __name__ == '__main__': unittest.main()
