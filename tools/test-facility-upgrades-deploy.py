"""Scoped delivery tests run against temporary trees, never the actual game."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('upgrade_deploy', Path(__file__).with_name('deploy-facility-upgrades.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DeliverySafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='foundation-upgrade-delivery-test-')
        self.root = Path(self.temp.name)
        names = ('ROOT', 'LIVE', 'BASE_DIR', 'BASELINES', 'PREVIOUS', 'ARCHIVES', 'GUIDE', 'DESKTOP_GUIDE')
        self.saved = {name: getattr(delivery, name) for name in names}
        delivery.ROOT = self.root / 'source'
        delivery.LIVE = self.root / 'live'
        delivery.BASE_DIR = delivery.ROOT / '.runtime/facility-upgrades-20261008'
        delivery.BASELINES = tuple(delivery.BASE_DIR / (name + '-before-manifest.json') for name in ('animations', 'bodycams', 'decon-water'))
        delivery.PREVIOUS = ((delivery.ROOT / 'docs/restored-systems-deployment.json', 58),
                             (delivery.ROOT / 'docs/bed-sleep-deployment.json', 4))
        delivery.ARCHIVES = self.root / 'archives'
        delivery.GUIDE = delivery.ROOT / 'docs/restored-systems-guide.html'
        delivery.DESKTOP_GUIDE = self.root / 'guide.html'
        for path in (delivery.GUIDE, delivery.DESKTOP_GUIDE): self.put(path, '<html>guide</html>')
        self.scoped_old = {'ixhl2rp/plugins/pose_studio/sh_plugin.lua', 'ixhl2rp/plugins/pose_studio/cl_editor.lua'}
        groups = [[] for _ in range(3)]
        for rel in delivery.RUNTIME:
            old = rel in self.scoped_old
            self.put(delivery.ROOT / rel, '-- new upgrade file\n')
            group = 0 if '/action_animations/' in rel or '/pose_studio/' in rel or rel.endswith('/turning.lua') else 1 if '/bodycams/' in rel or '/cctv/' in rel else 2
            baseline = delivery.BASELINES[group]
            before = baseline.with_name(baseline.name.replace('-before-manifest.json', '-before'))
            if old:
                for parent in (delivery.LIVE, before): self.put(parent / rel, '-- previous\n')
            groups[group].append({'path': rel, 'existed': old, 'sha256': delivery.file_hash(delivery.LIVE / rel)})
        for baseline, rows in zip(delivery.BASELINES, groups):
            delivery.write(baseline, {'root': str(delivery.ROOT), 'files': rows})
        for index, (path, count) in enumerate(delivery.PREVIOUS):
            old = {'sourceRoot': str(delivery.ROOT), 'liveRoot': str(delivery.LIVE), 'installed': True,
                   'archiveRoot': str(self.root / f'prior-archive-{index}'), 'files': []}
            for i in range(count):
                rel = sorted(self.scoped_old)[i] if index == 0 and i < 2 else f'ixhl2rp/plugins/prior{index}/file{i}.lua'
                if rel not in self.scoped_old:
                    for parent in (delivery.ROOT, delivery.LIVE): self.put(parent / rel, '-- previous\n')
                old['files'].append({'path': rel, 'sha256': delivery.sha(delivery.LIVE / rel)})
            archive = Path(old['archiveRoot']) / 'previous.zip'
            self.put(archive, 'Historical archive fixture, immutable.\n')
            old.update(archive=str(archive), archiveSHA256=delivery.sha(archive))
            delivery.write(path, old)
            delivery.write(Path(old['archiveRoot']) / 'manifest.json', old)

    def tearDown(self):
        for name, value in self.saved.items(): setattr(delivery, name, value)
        resolved = Path(self.temp.name).resolve()
        intended_parent = Path(tempfile.gettempdir()).resolve()
        self.assertEqual(resolved, self.root.resolve())
        self.assertTrue(resolved.is_relative_to(intended_parent) and resolved != intended_parent)
        self.assertTrue(resolved.name.startswith('foundation-upgrade-delivery-test-'))
        self.temp.cleanup()

    @staticmethod
    def put(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf8')

    def fixture_package(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        out = delivery.ARCHIVES / 'HL2RP-facility-upgrades-20261008-fixture'
        for row in records:
            rel = row['path']
            self.put(out / 'package/garrysmod/gamemodes' / rel, (delivery.ROOT / rel).read_text())
            if row['sourceBeforeSHA256']:
                self.put(out / 'source-backup' / rel, Path(row['sourceBackup']).read_text())
                self.put(out / 'local-backup' / rel, (delivery.LIVE / rel).read_text())
        for baseline in delivery.BASELINES:
            self.put(out / 'source-backup' / baseline.name, baseline.read_text())
        archive = out / 'Foundation-Facility-Upgrades.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for row in records: z.write(delivery.ROOT / row['path'], 'garrysmod/gamemodes/' + row['path'])
        delivery.write(out / 'manifest.json', {**report, 'supportHashes': {}, 'archiveSHA256': delivery.sha(archive)})
        return out, records

    def test_exact_32_scope_and_62_historical_with_two_authorized_updates(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        self.assertEqual(len(records), 32)
        self.assertEqual(len(delivery.evidence_hashes(records)), 92)
        self.assertFalse(report['conflicts'])
        self.assertTrue(report['previousRestoration']['verified'])
        self.assertEqual(report['previousRestoration']['count'], 62)
        self.assertEqual(sum(r['scopedUpdate'] for r in report['previousRestoration']['files']), 2)
        self.assertEqual({r['status'] for r in report['files']}, {'new', 'baseline-match'})

    def test_unscoped_source_or_live_changes_block(self):
        self.put(delivery.LIVE / 'ixhl2rp/plugins/prior0/file2.lua', '-- external installed change\n')
        self.put(delivery.ROOT / 'ixhl2rp/plugins/prior1/file0.lua', '-- external source change\n')
        report = delivery.plan(delivery.collect_scope())
        self.assertEqual(len(report['conflicts']), 2)
        self.assertFalse(report['previousRestoration']['verified'])

    def test_new_live_collision_and_unscoped_new_plugin_file_block(self):
        self.put(delivery.LIVE / delivery.RUNTIME[0], '-- collision\n')
        self.put(delivery.LIVE / delivery.NEW_PLUGINS[0] / 'other.lua', '-- preserve\n')
        self.assertEqual(len(delivery.plan(delivery.collect_scope())['conflicts']), 2)

    def test_extra_runtime_or_duplicate_baseline_rejected(self):
        path = delivery.BASELINES[0]
        data = delivery.load(path)
        data['files'].append({'path': 'ixhl2rp/plugins/action_animations/extra.lua', 'existed': False, 'sha256': None})
        delivery.write(path, data)
        with self.assertRaisesRegex(RuntimeError, 'scope differs'): delivery.collect_scope()
        data['files'][-1] = data['files'][0]
        delivery.write(path, data)
        with self.assertRaisesRegex(RuntimeError, 'Duplicate baseline'): delivery.collect_scope()

    def test_source_backup_tampering_rejected(self):
        record = next(r for r in delivery.collect_scope() if r['sourceBackup'])
        self.put(Path(record['sourceBackup']), '-- changed backup\n')
        with self.assertRaisesRegex(RuntimeError, 'Source backup mismatch'): delivery.collect_scope()

    def test_historical_manifest_or_archive_changes_rejected(self):
        previous_path = delivery.PREVIOUS[0][0]
        data = delivery.load(previous_path)
        data['unapproved'] = True
        delivery.write(previous_path, data)
        with self.assertRaisesRegex(RuntimeError, 'archived original'): delivery.previous_manifest()
        data.pop('unapproved')
        delivery.write(previous_path, data)
        self.put(Path(data['archive']), 'changed historical archive')
        with self.assertRaisesRegex(RuntimeError, 'Historical ZIP changed'): delivery.previous_manifest()

    def test_changed_after_plan_and_path_escape_rejected(self):
        report = delivery.plan(delivery.collect_scope())
        self.put(delivery.LIVE / delivery.RUNTIME[0], '-- late change\n')
        with self.assertRaisesRegex(RuntimeError, 'changed since backup'): delivery.verify_unchanged(report['files'])
        with self.assertRaisesRegex(RuntimeError, 'escapes root'): delivery.inside(delivery.ROOT, '../outside.lua')

    def test_zip_runtime_is_strict_and_hash_verified(self):
        out, records = self.fixture_package()
        archive = out / 'Foundation-Facility-Upgrades.zip'
        delivery.verify_zip(archive, records, {})
        with zipfile.ZipFile(archive, 'a') as z: z.writestr('garrysmod/gamemodes/ixhl2rp/unscoped.lua', '-- extra\n')
        with self.assertRaisesRegex(RuntimeError, 'unscoped runtime'): delivery.verify_zip(archive, records, {})

    def test_successful_install_matches_all_32_and_preserves_historical_manifests(self):
        before = {p: delivery.sha(p) for p, _ in delivery.PREVIOUS}
        out, records = self.fixture_package()
        with patch.object(delivery, 'validate_evidence', return_value={}): result = delivery.install(out)
        self.assertTrue(result['installed'])
        self.assertEqual({p: delivery.sha(p) for p, _ in delivery.PREVIOUS}, before)
        self.assertTrue(delivery.previous_check(records, installed=True)['verified'])
        for record in records: self.assertEqual(delivery.sha(delivery.LIVE / record['path']), record['sha256'])

    def test_failed_install_rolls_back_old_and_new_files_preserving_external_change(self):
        out, records = self.fixture_package()
        real_copy = delivery.shutil.copy2
        concurrent = delivery.LIVE / delivery.RUNTIME[0]
        last = Path(delivery.RUNTIME[-1]).name
        def injected_copy(source, destination, *args, **kwargs):
            if Path(destination).name.startswith(last + '.facility-upgrades-stage-'):
                self.put(concurrent, '-- concurrent external change\n')
                raise OSError('simulated copy failure')
            return real_copy(source, destination, *args, **kwargs)
        with patch.object(delivery, 'validate_evidence', return_value={}), patch.object(delivery.shutil, 'copy2', side_effect=injected_copy):
            with self.assertRaisesRegex(OSError, 'simulated copy failure'): delivery.install(out)
        self.assertEqual(concurrent.read_text(), '-- concurrent external change\n')
        for record in records:
            if delivery.LIVE / record['path'] != concurrent:
                self.assertEqual(delivery.file_hash(delivery.LIVE / record['path']), record['sourceBeforeSHA256'])
        self.assertTrue(delivery.previous_check(records)['verified'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
