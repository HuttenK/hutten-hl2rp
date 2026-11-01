"""Delivery tests use isolated temporary source/live/data trees, never the game."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('equipment_deploy', Path(__file__).with_name('deploy-device-ui-redesign.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DeliverySafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='foundation-equipment-delivery-test-')
        self.root = Path(self.temp.name)
        names = ('ROOT', 'LIVE', 'BASE_DIR', 'BASELINES', 'FROZEN_SCOPE', 'PRIVATE_DATA', 'PRIVATE_BASELINE',
                 'PREVIOUS', 'ARCHIVES', 'GUIDE', 'DESKTOP_GUIDE', 'FACILITIES_GUIDE', 'DESKTOP_FACILITIES_GUIDE', 'GUIDE_BASELINE')
        self.saved = {name: getattr(delivery, name) for name in names}
        delivery.ROOT = self.root / 'source'
        delivery.LIVE = self.root / 'live/gamemodes'
        delivery.BASE_DIR = delivery.ROOT / '.runtime/device-ui-redesign-20261009'
        delivery.BASELINES = tuple(delivery.BASE_DIR / (name + '-before-manifest.json') for name in ('electrical', 'surveillance', 'equipment', 'camera', 'water', 'sink-admin'))
        delivery.FROZEN_SCOPE = delivery.BASE_DIR / 'frozen-scope.json'
        delivery.PRIVATE_DATA = delivery.LIVE.parent / 'data/helix/ixhl2rp/pose_studio.txt'
        delivery.PRIVATE_BASELINE = delivery.BASE_DIR / 'pose-data-before.json'
        delivery.PREVIOUS = ((delivery.ROOT / 'docs/restored-systems-deployment.json', 58),
                             (delivery.ROOT / 'docs/bed-sleep-deployment.json', 4),
                             (delivery.ROOT / 'docs/facility-upgrades-deployment.json', 32),
                             (delivery.ROOT / 'docs/cctv-recognition-salute-deployment.json', 9))
        delivery.ARCHIVES = self.root / 'archives'
        delivery.GUIDE = delivery.ROOT / 'docs/restored-systems-guide.html'
        delivery.DESKTOP_GUIDE = self.root / 'guide.html'
        delivery.FACILITIES_GUIDE = delivery.ROOT / 'docs/Foundation-Facilities-Guide.html'
        delivery.DESKTOP_FACILITIES_GUIDE = self.root / 'facilities.html'
        delivery.GUIDE_BASELINE = delivery.BASE_DIR / 'guide-before-manifest.json'
        guide_rows = []
        for i, path in enumerate((*delivery.guide_pairs()[0], *delivery.guide_pairs()[1])):
            self.put(path, '<html>guide</html>')
            backup = delivery.BASE_DIR / ('guide-' + str(i) + '.before.html')
            self.put(backup, '<html>guide</html>')
            guide_rows.append({'path': str(path), 'backup': str(backup), 'sha256': delivery.sha(backup), 'bytes': backup.stat().st_size})
        delivery.write(delivery.GUIDE_BASELINE, guide_rows)
        self.put(delivery.PRIVATE_DATA, 'PRIVATE POSE CONTENT MUST NEVER BE PACKAGED\n')
        delivery.write(delivery.PRIVATE_BASELINE, {'path': str(delivery.PRIVATE_DATA),
            'sha256': delivery.sha(delivery.PRIVATE_DATA), 'bytes': delivery.PRIVATE_DATA.stat().st_size, 'contentCopied': False})
        self.superseded = ('ixhl2rp/plugins/pose_studio/sh_plugin.lua', 'ixhl2rp/plugins/pose_studio/cl_editor.lua')
        latest = {}
        for index, (path, count) in enumerate(delivery.PREVIOUS):
            old = {'sourceRoot': str(delivery.ROOT), 'liveRoot': str(delivery.LIVE), 'installed': True,
                   'archiveRoot': str(self.root / f'prior-archive-{index}'), 'files': []}
            for i in range(count):
                rel = (list(latest)[i] if index == 3 and i < 5 else
                       self.superseded[i] if index in (0, 2) and i < 2 else
                       'ixhl2rp/plugins/cctv/cl_render.lua' if index == 2 and i == 2 else
                       f'ixhl2rp/plugins/prior{index}/file{i}.lua')
                previous = latest.get(rel)
                for parent in (delivery.ROOT, delivery.LIVE): self.put(parent / rel, f'-- historical edition {index}\n')
                digest = delivery.sha(delivery.LIVE / rel)
                old['files'].append({'path': rel, 'sha256': digest, 'sourceBeforeSHA256': previous})
                latest[rel] = digest
            archive = Path(old['archiveRoot']) / 'previous.zip'
            self.put(archive, f'Historical archive {index}; immutable.\n')
            old.update(archive=str(archive), archiveSHA256=delivery.sha(archive))
            delivery.write(path, old)
            delivery.write(Path(old['archiveRoot']) / 'manifest.json', old)
        self.runtime = ('ixhl2rp/plugins/pose_studio/sh_plugin.lua', 'ixhl2rp/plugins/pose_studio/cl_saved.lua',
                        'ixhl2rp/plugins/cctv/cl_render.lua', 'ixhl2rp/plugins/cctv/cl_recognition.lua')
        groups = [[] for _ in delivery.BASELINES]
        for rel in self.runtime:
            group = 0 if '/pose_studio/' in rel else 1
            baseline = delivery.BASELINES[group]
            before = baseline.with_name(baseline.name.replace('-before-manifest.json', '-before'))
            old = delivery.file_hash(delivery.LIVE / rel)
            if old: self.put(before / rel, (delivery.LIVE / rel).read_text())
            self.put(delivery.ROOT / rel, '-- new equipment UI or camera action code\n')
            groups[group].append({'path': rel, 'existed': old is not None, 'sha256': old})
        for index, (baseline, rows) in enumerate(zip(delivery.BASELINES, groups)):
            if index == 0:
                data = {'root': str(delivery.ROOT), 'files': rows}
            elif index == 1:
                data = [{'path': row['path'], 'sha256': row['sha256'], 'new': not row['existed'],
                         **({'bytes': (delivery.LIVE / row['path']).stat().st_size} if row['existed'] else {})} for row in rows]
            else:
                data = [{'path': row['path'], 'existed': row['existed'], 'beforeSHA256': row['sha256']} for row in rows]
            delivery.write(baseline, data)
        delivery.freeze_scope()

    def tearDown(self):
        for name, value in self.saved.items(): setattr(delivery, name, value)
        resolved = Path(self.temp.name).resolve()
        intended_parent = Path(tempfile.gettempdir()).resolve()
        self.assertEqual(resolved, self.root.resolve())
        self.assertTrue(resolved.is_relative_to(intended_parent) and resolved != intended_parent)
        self.assertTrue(resolved.name.startswith('foundation-equipment-delivery-test-'))
        self.temp.cleanup()

    @staticmethod
    def put(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf8')

    def fixture_package(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        out = delivery.ARCHIVES / 'HL2RP-device-ui-redesign-20261009-fixture'
        for row in records:
            rel = row['path']
            self.put(out / 'package/garrysmod/gamemodes' / rel, (delivery.ROOT / rel).read_text())
            if row['sourceBeforeSHA256']:
                self.put(out / 'source-backup' / rel, Path(row['sourceBackup']).read_text())
                self.put(out / 'local-backup' / rel, (delivery.LIVE / rel).read_text())
        for baseline in delivery.BASELINES:
            self.put(out / 'source-backup' / baseline.name, baseline.read_text())
        archive = out / 'Foundation-Device-UI-Redesign.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for row in records: z.write(delivery.ROOT / row['path'], 'garrysmod/gamemodes/' + row['path'])
        delivery.write(out / 'manifest.json', {**report, 'supportHashes': {}, 'archiveSHA256': delivery.sha(archive)})
        return out, records

    def test_manifest_driven_scope_uses_latest_of_four_historical_deliveries(self):
        records = delivery.collect_scope()
        report = delivery.plan(records)
        self.assertEqual(len(records), 4)
        self.assertEqual(len(delivery.evidence_hashes(records)), 98)
        self.assertEqual(report['previousRestoration']['count'], 96)
        self.assertFalse(report['conflicts'])
        self.assertEqual({r['status'] for r in report['files']}, {'new', 'baseline-match'})
        self.assertTrue(report['privateData']['unchanged'])
        self.assertEqual(next(r for r in records if r['path'] == self.superseded[0])['sourceBeforeSHA256'],
                         delivery.sha(delivery.LIVE / self.superseded[0]))

    def test_unscoped_source_or_live_changes_block(self):
        self.put(delivery.LIVE / 'ixhl2rp/plugins/prior0/file2.lua', '-- external installed change\n')
        self.put(delivery.ROOT / 'ixhl2rp/plugins/prior1/file0.lua', '-- external source change\n')
        self.assertEqual(len(delivery.plan(delivery.collect_scope())['conflicts']), 2)

    def test_new_live_collision_blocks(self):
        self.put(delivery.LIVE / 'ixhl2rp/plugins/cctv/cl_recognition.lua', '-- collision\n')
        self.assertEqual(len(delivery.plan(delivery.collect_scope())['conflicts']), 1)

    def test_frozen_scope_cannot_silently_expand(self):
        path = delivery.BASELINES[0]
        data = delivery.load(path)
        data['files'].append({'path': 'ixhl2rp/plugins/pose_studio/extra.lua', 'existed': False, 'sha256': None})
        delivery.write(path, data)
        with self.assertRaisesRegex(RuntimeError, 'Baseline changed after scope freeze'): delivery.collect_scope()
        with self.assertRaisesRegex(RuntimeError, 'already frozen'): delivery.freeze_scope()

    def test_model_or_data_runtime_and_duplicate_baselines_rejected(self):
        rows = delivery.read_baseline_rows()
        rows['ixhl2rp/models/private.mdl'] = ({}, None)
        with self.assertRaisesRegex(RuntimeError, 'Only explicitly captured Lua'): delivery.runtime_paths(rows)
        data = delivery.load(delivery.BASELINES[0])
        data['files'].append(data['files'][0])
        delivery.write(delivery.BASELINES[0], data)
        with self.assertRaisesRegex(RuntimeError, 'Duplicate baseline'): delivery.read_baseline_rows()

    def test_mixed_manifest_aliases_and_bytes_are_normalized_without_rewriting(self):
        before = {path: delivery.sha(path) for path in delivery.BASELINES}
        rows = delivery.read_baseline_rows()
        self.assertEqual(set(rows), set(self.runtime))
        self.assertEqual({path: delivery.sha(path) for path in delivery.BASELINES}, before)
        # Explicit equipment/camera/water schema with a new file is accepted.
        path = delivery.BASELINES[4]
        delivery.write(path, [{'path': 'ixhl2rp/plugins/water/extra.lua', 'existed': False, 'beforeSHA256': None}])
        self.assertEqual(delivery.read_baseline_rows()['ixhl2rp/plugins/water/extra.lua'][0]['sha256'], None)

    def test_guide_backup_and_both_desktop_pairs_are_protected(self):
        self.assertEqual(len(delivery.guide_backups_check()), 4)
        rows = delivery.load(delivery.GUIDE_BASELINE)
        self.put(Path(rows[-1]['backup']), 'changed guide backup')
        with self.assertRaisesRegex(RuntimeError, 'Guide backup changed'): delivery.guide_backups_check()

    def test_source_backup_tampering_rejected(self):
        record = next(r for r in delivery.collect_scope() if r['sourceBackup'])
        self.put(Path(record['sourceBackup']), '-- changed backup\n')
        with self.assertRaisesRegex(RuntimeError, 'Source backup mismatch'): delivery.collect_scope()

    def test_historical_manifest_archive_and_bad_superseding_chain_rejected(self):
        path = delivery.PREVIOUS[2][0]
        data = delivery.load(path)
        data['files'][0]['sourceBeforeSHA256'] = 'wrong previous version'
        delivery.write(path, data)
        with self.assertRaisesRegex(RuntimeError, 'archived original'): delivery.previous_manifest()
        delivery.write(Path(data['archiveRoot']) / 'manifest.json', data)
        with self.assertRaisesRegex(RuntimeError, 'superseding baseline differs'): delivery.previous_manifest()
        self.put(Path(data['archive']), 'changed archive')
        with self.assertRaisesRegex(RuntimeError, 'Historical ZIP changed'): delivery.previous_manifest()

    def test_saved_pose_change_blocks_without_restoring_or_copying_it(self):
        self.put(delivery.PRIVATE_DATA, 'external new saved animation\n')
        with self.assertRaisesRegex(RuntimeError, 'Saved pose data changed'): delivery.collect_scope()
        self.assertEqual(delivery.PRIVATE_DATA.read_text(), 'external new saved animation\n')
        self.assertFalse(any(p.name == 'pose_studio.txt' for p in delivery.ROOT.rglob('*')))

    def test_changed_after_plan_and_path_escape_rejected(self):
        report = delivery.plan(delivery.collect_scope())
        self.put(delivery.LIVE / report['files'][0]['path'], '-- late change\n')
        with self.assertRaisesRegex(RuntimeError, 'changed since backup'): delivery.verify_unchanged(report['files'])
        with self.assertRaisesRegex(RuntimeError, 'escapes root'): delivery.inside(delivery.ROOT, '../outside.lua')

    def test_zip_rejects_unscoped_runtime(self):
        out, records = self.fixture_package()
        archive = out / 'Foundation-Device-UI-Redesign.zip'
        delivery.verify_zip(archive, records, {})
        with zipfile.ZipFile(archive, 'a') as z: z.writestr('garrysmod/gamemodes/ixhl2rp/unscoped.lua', '-- extra\n')
        with self.assertRaisesRegex(RuntimeError, 'unscoped runtime'): delivery.verify_zip(archive, records, {})

    def test_zip_rejects_saved_pose_content_even_outside_payload(self):
        out, records = self.fixture_package()
        archive = out / 'Foundation-Device-UI-Redesign.zip'
        with zipfile.ZipFile(archive, 'a') as z: z.writestr('private/pose_studio.txt', 'must not be copied')
        with self.assertRaisesRegex(RuntimeError, 'private data or model'): delivery.verify_zip(archive, records, {})

    def test_successful_install_preserves_all_history_and_private_data(self):
        before = {p: delivery.sha(p) for p, _ in delivery.PREVIOUS}
        saved = delivery.sha(delivery.PRIVATE_DATA)
        out, records = self.fixture_package()
        with patch.object(delivery, 'validate_evidence', return_value={}): result = delivery.install(out)
        self.assertTrue(result['installed'])
        self.assertEqual({p: delivery.sha(p) for p, _ in delivery.PREVIOUS}, before)
        self.assertEqual(delivery.sha(delivery.PRIVATE_DATA), saved)
        self.assertTrue(delivery.previous_check(records, installed=True)['verified'])
        for row in records: self.assertEqual(delivery.sha(delivery.LIVE / row['path']), row['sha256'])

    def test_failed_install_rolls_back_old_and_new_files_preserving_external_change(self):
        out, records = self.fixture_package()
        real_copy = delivery.shutil.copy2
        concurrent = delivery.LIVE / records[0]['path']
        last = Path(records[-1]['path']).name
        def injected_copy(source, destination, *args, **kwargs):
            if Path(destination).name.startswith(last + '.device-ui-redesign-stage-'):
                self.put(concurrent, '-- concurrent external change\n')
                raise OSError('simulated copy failure')
            return real_copy(source, destination, *args, **kwargs)
        with patch.object(delivery, 'validate_evidence', return_value={}), patch.object(delivery.shutil, 'copy2', side_effect=injected_copy):
            with self.assertRaisesRegex(OSError, 'simulated copy failure'): delivery.install(out)
        self.assertEqual(concurrent.read_text(), '-- concurrent external change\n')
        for row in records:
            if delivery.LIVE / row['path'] != concurrent:
                self.assertEqual(delivery.file_hash(delivery.LIVE / row['path']), row['sourceBeforeSHA256'])
        self.assertTrue(delivery.private_data_check()['unchanged'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
