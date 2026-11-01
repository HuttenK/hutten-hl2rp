"""Scoped facility upgrades delivery; --plan never writes to the game.

After independent review: node tools/audit.cjs, then
node tools/test-facility-upgrades-delivery.cjs, then --validate-guide, --package.
Install is separate: --install E:/Codex-Archives/<exact-package-directory>.
The 62 previously installed files are checked; only explicit scoped updates are repackaged.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
ARCHIVES = Path('E:/Codex-Archives')
BASE_DIR = ROOT / '.runtime/facility-upgrades-20261008'
BASELINES = tuple(BASE_DIR / (name + '-before-manifest.json') for name in ('animations', 'bodycams', 'decon-water'))
PREVIOUS = ((ROOT / 'docs/restored-systems-deployment.json', 58), (ROOT / 'docs/bed-sleep-deployment.json', 4))
NEW_PLUGINS = ('ixhl2rp/plugins/action_animations', 'ixhl2rp/plugins/bodycams',
               'ixhl2rp/plugins/water_sources', 'ixhl2rp/plugins/decontamination')
RUNTIME = tuple(sorted([
    'ixhl2rp/plugins/action_animations/' + name for name in ('sh_plugin.lua', 'sh_ik.lua', 'sv_actions.lua', 'cl_actions.lua')
] + [
    'ixhl2rp/plugins/pose_studio/' + name for name in ('cl_targets.lua', 'sh_plugin.lua', 'cl_editor.lua')
] + ['ixhl2rp/plugins/turning.lua'] + [
    'ixhl2rp/plugins/bodycams/' + name for name in ('sh_plugin.lua', 'sh_bodycams.lua', 'sv_bodycams.lua', 'cl_bodycams.lua', 'items/helmet_bodycam.lua')
] + [
    'ixhl2rp/plugins/cctv/' + name for name in ('sh_state.lua', 'sv_devices.lua', 'sv_network.lua', 'cl_render.lua', 'cl_controls.lua', 'cl_network.lua')
] + [
    'ixhl2rp/entities/entities/ix_sink_trigger.lua', 'ixhl2rp/entities/entities/ix_toilet_trigger.lua',
    'ixhl2rp/plugins/scp610_control/sv_control.lua', 'ixhl2rp/plugins/facility_utilities/cl_admin.lua'
] + [
    'ixhl2rp/plugins/water_sources/' + name for name in ('sh_plugin.lua', 'sh_water.lua', 'sv_water.lua', 'cl_water.lua')
] + [
    'ixhl2rp/plugins/decontamination/' + name for name in ('sh_plugin.lua', 'sv_decon.lua',
        'entities/entities/ix_facility_decon_shower.lua', 'entities/entities/ix_facility_decon_sensor.lua',
        'entities/entities/ix_facility_decon_disposal.lua')
]))
EVIDENCE = ROOT / 'docs/facility-upgrades-validation.json'
GUIDE = ROOT / 'docs/restored-systems-guide.html'
DESKTOP_GUIDE = ROOT.parent / 'Foundation-Restored-Systems-Guide.html'
TEST_FILES = ('tools/test-water-sources.cjs', 'tools/test-decon.cjs', 'tools/test-bodycams.cjs',
              'tools/test-animation-upgrades.cjs', 'tools/test-cctv.cjs', 'tools/test-bed-sleep.cjs',
              'tools/test-restored-engineering.cjs', 'tools/test-restored-furniture.cjs',
              'tools/test-restored-carts.cjs', 'tools/test-restored-quests.cjs', 'tools/test-restored-pose-tools.cjs')
REVIEWS = ('docs/facility-upgrades-bodycams-review.md', 'docs/facility-upgrades-decon-review.md',
           'docs/facility-upgrades-animation-review.md')
DOCS = ('docs/water-sources.md', 'docs/decontamination.md', 'docs/decon-water-sources.json',
        'docs/bodycams.md', 'docs/animation-upgrades.md', 'docs/animation-upgrades-sources.json',
        'docs/facility-upgrades-delivery.md', 'docs/restored-systems-guide.html',
        'docs/facility-upgrades-deployment-plan.json', 'docs/facility-upgrades-file-list.txt',
        'docs/facility-upgrades-guide-validation.json', 'docs/facility-upgrades-validation.json',
        'docs/source-audit.json') + REVIEWS


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf8')


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def inside(parent, rel):
    require(not Path(rel).is_absolute(), 'Absolute relative path: ' + str(rel))
    path = (parent / rel).resolve()
    require(path.is_relative_to(parent.resolve()), 'Path escapes root: ' + str(rel))
    return path


def file_hash(path):
    require(not path.exists() or path.is_file(), 'Expected file, found other object: ' + str(path))
    return sha(path) if path.is_file() else None


def baseline_hashes():
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in BASELINES}


def collect_scope():
    rows = {}
    for baseline_path in BASELINES:
        baseline = load(baseline_path)
        require(Path(baseline['root']).resolve() == ROOT.resolve(), 'Baseline belongs to another checkout')
        before = baseline_path.with_name(baseline_path.name.replace('-before-manifest.json', '-before'))
        for row in baseline['files']:
            rel = row['path']
            require(rel not in rows, 'Duplicate baseline paths: ' + rel)
            inside(ROOT, rel)
            rows[rel] = (row, before)
    actual_runtime = {rel for rel in rows if rel.startswith(('ixhl2rp/', 'helix/'))}
    require(actual_runtime == set(RUNTIME) and len(RUNTIME) == 32, 'Runtime baseline scope differs from the reviewed 32 files')
    records = []
    for rel in RUNTIME:
        row, before = rows[rel]
        require(row['existed'] == (row['sha256'] is not None), 'Inconsistent baseline: ' + rel)
        backup = inside(before, rel)
        if row['existed']:
            require(file_hash(backup) == row['sha256'], 'Source backup mismatch: ' + rel)
        source = inside(ROOT, rel)
        require(source.is_file(), 'Implementation is not complete: ' + rel)
        records.append({'path': rel, 'sha256': sha(source), 'sourceBeforeSHA256': row['sha256'],
                        'sourceBackup': str(backup) if row['existed'] else None})
    for plugin in NEW_PLUGINS:
        actual = {f.relative_to(ROOT).as_posix() for f in (ROOT / plugin).rglob('*') if f.is_file()}
        expected = {rel for rel in RUNTIME if rel.startswith(plugin + '/')}
        require(actual == expected, 'New plugin scope changed: ' + str(sorted(actual ^ expected)))
    return records


def previous_manifest():
    files, manifests = {}, []
    for path, count in PREVIOUS:
        previous = load(path)
        require(previous.get('installed') is True and len(previous['files']) == count,
                'Previous installed manifest is incomplete: ' + str(path))
        require(previous['liveRoot'] == str(LIVE) and previous['sourceRoot'] == str(ROOT), 'Previous roots differ')
        archived = Path(previous['archiveRoot']) / 'manifest.json'
        require(load(archived) == previous, 'Historical manifest differs from archived original: ' + str(path))
        archive = Path(previous['archive'])
        require(file_hash(archive) == previous['archiveSHA256'], 'Historical ZIP changed: ' + str(archive))
        manifests.append({'path': str(path), 'sha256': sha(path), 'archiveSHA256': previous['archiveSHA256'], 'count': count})
        for row in previous['files']:
            require(row['path'] not in files, 'Historical scopes overlap unexpectedly')
            files[row['path']] = row
    require(len(files) == 62, 'Historical file count differs')
    return {'files': list(files.values()), 'manifests': manifests}


def previous_check(records, installed=False):
    previous = previous_manifest()
    scoped = {r['path']: r for r in records}
    results, conflicts = [], []
    for row in previous['files']:
        rel, old = row['path'], row['sha256']
        change = scoped.get(rel)
        if change:
            require(change['sourceBeforeSHA256'] == old, 'Scoped integration baseline differs from previous installation: ' + rel)
        expected_source = change['sha256'] if change else old
        expected_live = change['sha256'] if change and installed else old
        current_source, current_live = file_hash(inside(ROOT, rel)), file_hash(inside(LIVE, rel))
        valid = current_source == expected_source and current_live == expected_live
        record = {'path': rel, 'previousSHA256': old, 'sourceSHA256': current_source,
                  'installedSHA256': current_live, 'scopedUpdate': bool(change), 'verified': valid}
        results.append(record)
        if not valid:
            conflicts.append({**record, 'reason': 'Prior source/install differs outside authorized upgrade scope'})
    return {'manifests': previous['manifests'], 'count': len(results),
            'verified': not conflicts, 'files': results, 'conflicts': conflicts}


def evidence_hashes(records):
    values = {r['path']: file_hash(inside(ROOT, r['path'])) for r in previous_manifest()['files']}
    values.update({r['path']: r['sha256'] for r in records})
    require(all(values.values()), 'A previous restoration source file is missing')
    return dict(sorted(values.items()))


def plan(records):
    results, conflicts = [], []
    for record in records:
        local = file_hash(inside(LIVE, record['path']))
        before, current = record['sourceBeforeSHA256'], record['sha256']
        status = ('already-current' if local == current else 'new' if before is None and local is None
                  else 'baseline-match' if local == before and before is not None else 'conflict')
        results.append({**record, 'previousLocalSHA256': local, 'status': status})
        if status == 'conflict':
            conflicts.append({'path': record['path'], 'reason': 'Installed file differs from captured baseline and proposed file',
                              'sourceBeforeSHA256': before, 'installedSHA256': local, 'proposedSHA256': current})
    for plugin in NEW_PLUGINS:
        for path in (LIVE / plugin).rglob('*'):
            if path.is_file() and path.relative_to(LIVE).as_posix() not in RUNTIME:
                conflicts.append({'path': path.relative_to(LIVE).as_posix(), 'reason': 'Unscoped installed plugin file; not overwritten'})
    previous = previous_check(records)
    conflicts.extend(previous['conflicts'])
    return {'createdUTC': now(), 'sourceRoot': str(ROOT), 'liveRoot': str(LIVE), 'files': results,
            'baselineHashes': baseline_hashes(), 'previousRestoration': previous, 'conflicts': conflicts,
            'gameLaunched': False, 'installed': False}


def validate_evidence(records):
    evidence = load(EVIDENCE)
    require(evidence.get('success') is True and evidence.get('sourceHashes') == evidence_hashes(records), 'Final test evidence is stale/incomplete')
    require(evidence.get('sourceUnchanged') and evidence.get('auditUnchanged'), 'Sources/audit changed during tests')
    require(evidence.get('deliveryToolsUnchanged') and evidence.get('deliveryToolSHA256') == sha(ROOT / 'tools/deploy-facility-upgrades.py')
            and evidence.get('aggregateRunnerSHA256') == sha(ROOT / 'tools/test-facility-upgrades-delivery.cjs'), 'Delivery tools changed after final safety checks')
    audit_path = ROOT / 'docs/source-audit.json'
    require(evidence.get('auditSHA256') == sha(audit_path), 'Syntax audit differs from final test evidence')
    audit = load(audit_path)
    require(not audit['syntaxFailures'], 'Syntax audit has failures')
    audited = {e['path']: e['sha256'] for e in audit['entries']}
    for rel, digest in evidence_hashes(records).items():
        require(audited.get(rel) == digest, 'Source audit is stale: ' + rel)
    require({t['script'] for t in evidence.get('tests', [])} == set(TEST_FILES), 'All eleven focused test scripts are required')
    require(evidence.get('deliverySafety', {}).get('script') == 'tools/test-facility-upgrades-deploy.py', 'Delivery safety checks are missing')
    for test in evidence['tests'] + [evidence.get('regression', {}), evidence['deliverySafety']]:
        require(test.get('exitCode') == 0 and test.get('scriptUnchanged') and test.get('log') and test.get('script'), 'Missing final test result')
        require(sha(inside(ROOT, test['script'])) == test['scriptSHA256'], 'Test script changed: ' + test['script'])
        require(file_hash(inside(ROOT, test['log'])) == test['logSHA256'], 'Final log missing or changed: ' + test['log'])
    require(evidence['regression']['script'] == 'tools/test.cjs', 'Wrong broad regression script')
    result = re.search(r'(\d+) regression suites passed\.', inside(ROOT, evidence['regression']['log']).read_text(encoding='utf-8-sig'))
    require(result and int(result.group(1)) >= 424, 'Broad regression completion marker missing')
    return evidence


class GuideParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.anchors, self.documents, self.assets = [], [], [], []
        self.sections = 0

    def handle_starttag(self, tag, attrs):
        attr = dict(attrs)
        if 'id' in attr: self.ids.append(attr['id'])
        if tag == 'section': self.sections += 1
        if tag == 'a':
            href = attr.get('href', '')
            if href.startswith('#'): self.anchors.append(href[1:])
            if 'data-local' in attr: self.documents.append(href)
        if tag in ('script', 'img', 'iframe', 'audio', 'video', 'source') and attr.get('src'):
            self.assets.append(attr['src'])
        if tag == 'link' and attr.get('href'): self.assets.append(attr['href'])


def validate_guide(strict=True):
    content = GUIDE.read_text(encoding='utf-8-sig')
    parser = GuideParser()
    parser.feed(content)
    require(len(parser.ids) == len(set(parser.ids)), 'Duplicate guide IDs')
    require(set(parser.anchors).issubset(parser.ids), 'Broken guide anchor')
    require({'sleep', 'water', 'decon', 'bodycams', 'animation'}.issubset(parser.ids), 'Guide upgrade sections missing')
    require(not parser.assets and not re.search(r'url\s*\(|@import', content, re.I), 'Guide depends on external assets')
    require(DESKTOP_GUIDE.is_file() and sha(DESKTOP_GUIDE) == sha(GUIDE), 'Desktop guide differs')
    require("location.pathname.endsWith('Foundation-Restored-Systems-Guide.html')" in content and
            "file:///C:/Users/q1236/Desktop/hutten-hl2rp-2/docs/" in content, 'Desktop document link resolver missing')
    documents = [{'path': rel, 'exists': inside(ROOT / 'docs', rel).is_file()} for rel in parser.documents]
    report = {'checkedUTC': now(), 'guideSHA256': sha(GUIDE), 'sections': parser.sections,
              'anchorLinks': len(parser.anchors), 'externalAssets': 0, 'desktopIdentical': True,
              'desktopLinksResolveTo': str(ROOT / 'docs'), 'documents': documents,
              'allLinksExist': all(row['exists'] for row in documents), 'visualBrowserVerification': False,
              'visualLimit': 'Browser security policy rejected file protocol. No alternate surface was attempted.'}
    write(ROOT / 'docs/facility-upgrades-guide-validation.json', report)
    if strict: require(report['allLinksExist'], 'Guide document links not ready; see facility-upgrades-guide-validation.json')
    return report


def verify_unchanged(records):
    for record in records:
        require(file_hash(inside(ROOT, record['path'])) == record['sha256'], 'Source changed during delivery: ' + record['path'])
        require(file_hash(inside(LIVE, record['path'])) == record['previousLocalSHA256'], 'Installed file changed since backup: ' + record['path'])
    require(previous_check(records)['verified'], 'Previous restoration changed during delivery')


def package(records):
    report = plan(records)
    write(ROOT / 'docs/facility-upgrades-deployment-plan.json', report)
    (ROOT / 'docs/facility-upgrades-file-list.txt').write_text('\n'.join(r['status'] + '  ' + r['path'] for r in report['files']) + '\n', encoding='utf8')
    require(not report['conflicts'], 'Baseline conflicts: see docs/facility-upgrades-deployment-plan.json')
    evidence = validate_evidence(records)
    guide = validate_guide()
    support = set(DOCS) | set(TEST_FILES) | {
        'tools/test-facility-upgrades-delivery.cjs', 'tools/deploy-facility-upgrades.py', 'tools/test-facility-upgrades-deploy.py',
        'tools/fixtures/bodycams.lua', 'tools/restored-test-runner.cjs', 'tools/test.cjs', 'docs/restored-systems-deployment.json', 'docs/bed-sleep-deployment.json',
        '.runtime/facility-upgrades-20261008/restored-systems-guide.before.html',
        '.runtime/facility-upgrades-20261008/desktop-guide.before.html'}
    support.update(path.relative_to(ROOT).as_posix() for path in BASELINES)
    support.update('docs/' + row['path'] for row in guide['documents'])
    support.update(t['log'] for t in evidence['tests'] + [evidence['regression'], evidence['deliverySafety']])
    support.update(path.relative_to(ROOT).as_posix() for path in (ROOT / 'docs').glob('facility-upgrades*review*.md'))
    for rel in support: require(inside(ROOT, rel).is_file(), 'Required delivery document missing: ' + rel)
    support_hashes = {rel: sha(inside(ROOT, rel)) for rel in sorted(support)}
    out = ARCHIVES / ('HL2RP-facility-upgrades-20261008-' + dt.datetime.now().strftime('%H%M%S-%f'))
    require(not out.exists(), 'Archive path already exists')
    out.mkdir(parents=True)
    (out / 'local-backup').mkdir()
    (out / 'source-backup').mkdir()
    staged = out / 'package'
    for record in report['files']:
        rel = record['path']
        if record['previousLocalSHA256'] is not None:
            backup = inside(out / 'local-backup', rel)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(inside(LIVE, rel), backup)
            require(sha(backup) == record['previousLocalSHA256'], 'Live file changed while backing up: ' + rel)
        if record['sourceBackup']:
            backup = inside(out / 'source-backup', rel)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(record['sourceBackup'], backup)
            require(sha(backup) == record['sourceBeforeSHA256'], 'Source backup changed: ' + rel)
        destination = inside(staged / 'garrysmod/gamemodes', rel)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(inside(ROOT, rel), destination)
        require(sha(destination) == record['sha256'], 'Staging hash mismatch: ' + rel)
    for baseline in BASELINES:
        shutil.copy2(baseline, out / 'source-backup' / baseline.name)
    write(out / 'local-backup/before-manifest.json', {'liveRoot': str(LIVE), 'files': [
        {'path': r['path'], 'existed': r['previousLocalSHA256'] is not None, 'sha256': r['previousLocalSHA256']} for r in report['files']]})
    for rel in sorted(support):
        target = inside(staged, rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(inside(ROOT, rel), target)
        require(sha(target) == support_hashes[rel], 'Support file changed while staging: ' + rel)
    (staged / 'README.md').write_text(
        '# Foundation: вода, деконтаминация, камеры на шлемах и анимации\n\n'
        'Начните с docs/restored-systems-guide.html. Полезная нагрузка ограничена 32 Lua-файлами. '
        '62 ранее установленных файла проверяются по неизменённым историческим манифестам; '
        'в эту поставку входят только явно перечисленные изменения прежних файлов.\n\n'
        'Установка отделена от упаковки. Фактический результат отражает внешний manifest.json рядом с ZIP '
        'и docs/facility-upgrades-deployment.json исходного проекта. Встроенный манифест описывает момент упаковки. '
        'local-backup и source-backup содержат прежние байты и манифесты отсутствовавших файлов.\n\n'
        'Игра не запускалась. Изображение CCTV, сетевые анимации, прицел и модели требуют проверки в GMod. '
        'HTML проверен структурно: браузер запретил file URL, обход не применялся.\n', encoding='utf8')
    manifest = {**report, 'archiveRoot': str(out), 'evidence': evidence, 'supportHashes': support_hashes, 'engineTested': False}
    write(staged / 'manifest.json', manifest)
    archive = out / 'Foundation-Facility-Upgrades.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipout:
        for path in sorted(staged.rglob('*')):
            if path.is_file(): zipout.write(path, path.relative_to(staged).as_posix())
    verify_zip(archive, records, support_hashes)
    verify_unchanged(report['files'])
    require(baseline_hashes() == report['baselineHashes'], 'Baseline changed while packaging')
    for rel, digest in support_hashes.items(): require(sha(inside(ROOT, rel)) == digest, 'Support changed while packaging: ' + rel)
    manifest.update(archive=str(archive), archiveSHA256=sha(archive))
    write(out / 'manifest.json', manifest)
    write(ROOT / 'docs/facility-upgrades-package.json', manifest)
    return {'packaged': True, 'installed': False, 'files': len(records), 'previousFilesVerified': 62,
            'archive': str(archive), 'archiveRoot': str(out)}


def verify_zip(archive, records, support_hashes):
    with zipfile.ZipFile(archive) as zipin:
        require(zipin.testzip() is None, 'ZIP CRC verification failed')
        payload = {name.removeprefix('garrysmod/gamemodes/') for name in zipin.namelist() if name.startswith('garrysmod/gamemodes/')}
        require(payload == {r['path'] for r in records}, 'ZIP contains unscoped runtime files')
        for name, digest in {**{'garrysmod/gamemodes/' + r['path']: r['sha256'] for r in records}, **support_hashes}.items():
            require(hashlib.sha256(zipin.read(name)).hexdigest() == digest, 'ZIP hash mismatch: ' + name)


def install(directory):
    out = Path(directory).resolve()
    require(out.is_relative_to(ARCHIVES.resolve()) and out.name.startswith('HL2RP-facility-upgrades-20261008-'), 'Unexpected archive root')
    manifest = load(out / 'manifest.json')
    require(manifest['liveRoot'] == str(LIVE) and manifest['sourceRoot'] == str(ROOT), 'Manifest roots differ')
    require(not manifest.get('installed'), 'Package already installed; inspect hashes instead of retrying')
    require(not manifest['conflicts'], 'Package contains conflicts')
    records, current = manifest['files'], collect_scope()
    require({r['path']: r['sha256'] for r in current} == {r['path']: r['sha256'] for r in records}, 'Source scope changed after packaging')
    require(baseline_hashes() == manifest['baselineHashes'], 'Baseline changed after packaging')
    require(previous_manifest()['manifests'] == manifest['previousRestoration']['manifests'], 'Historical manifests changed')
    validate_evidence(current)
    require(not plan(current)['conflicts'], 'Installed files changed after packaging')
    archive = out / 'Foundation-Facility-Upgrades.zip'
    require(sha(archive) == manifest['archiveSHA256'], 'ZIP changed after packaging')
    verify_zip(archive, records, manifest['supportHashes'])
    for record in records:
        require(sha(inside(out / 'package/garrysmod/gamemodes', record['path'])) == record['sha256'], 'Staged runtime changed')
        if record['previousLocalSHA256'] is not None:
            require(sha(inside(out / 'local-backup', record['path'])) == record['previousLocalSHA256'], 'Local backup changed')
        if record['sourceBeforeSHA256'] is not None:
            require(sha(inside(out / 'source-backup', record['path'])) == record['sourceBeforeSHA256'], 'Source backup changed')
    for baseline in BASELINES:
        require(sha(out / 'source-backup' / baseline.name) == manifest['baselineHashes'][baseline.relative_to(ROOT).as_posix()], 'Archived baseline changed')
    for rel, digest in manifest['supportHashes'].items():
        require(sha(inside(ROOT, rel)) == digest and sha(inside(out / 'package', rel)) == digest, 'Support file changed: ' + rel)
    verify_unchanged(records)
    written = []
    try:
        for record in records:
            destination = inside(LIVE, record['path'])
            require(file_hash(destination) == record['previousLocalSHA256'], 'Destination changed immediately before copy')
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_name(destination.name + '.facility-upgrades-stage-' + str(os.getpid()))
            require(not temporary.exists(), 'Existing staging file requires inspection: ' + str(temporary))
            try:
                shutil.copy2(inside(out / 'package/garrysmod/gamemodes', record['path']), temporary)
                require(sha(temporary) == record['sha256'], 'Temporary hash mismatch')
                require(file_hash(destination) == record['previousLocalSHA256'], 'Destination changed before atomic replacement')
                os.replace(temporary, destination)
                written.append(record)
            finally:
                if temporary.exists(): temporary.unlink()
            require(sha(destination) == record['sha256'], 'Installed hash mismatch')
        previous = previous_check(records, installed=True)
        require(previous['verified'], 'Previous restoration changed during installation')
        for record in records:
            for parent in (ROOT, LIVE, out / 'package/garrysmod/gamemodes'):
                require(sha(inside(parent, record['path'])) == record['sha256'], 'Final source/stage/installed hash mismatch: ' + record['path'])
        require(sha(archive) == manifest['archiveSHA256'], 'Archive changed during installation')
        verify_zip(archive, records, manifest['supportHashes'])
        require(sha(GUIDE) == sha(DESKTOP_GUIDE), 'Desktop guide changed during installation')
    except Exception:
        for record in reversed(written):
            destination = inside(LIVE, record['path'])
            if file_hash(destination) != record['sha256']:
                print('Rollback preserved a concurrent external change: ' + record['path'], file=sys.stderr)
                continue
            if record['previousLocalSHA256'] is None: destination.unlink()
            else: shutil.copy2(inside(out / 'local-backup', record['path']), destination)
        raise
    verification = {'checkedUTC': now(), 'runtimeFiles': len(records), 'sourceStageZipInstalledMatch': True,
                    'archiveSHA256': sha(archive), 'zipCRCVerified': True, 'previousRestoration': previous,
                    'desktopGuideIdentical': sha(GUIDE) == sha(DESKTOP_GUIDE), 'engineTested': False,
                    'files': [{'path': r['path'], 'sha256': r['sha256']} for r in records]}
    manifest.update(installed=True, installedUTC=now(), finalVerification=verification)
    write(out / 'manifest.json', manifest)
    write(out / 'final-verification.json', verification)
    write(ROOT / 'docs/facility-upgrades-deployment.json', manifest)
    write(ROOT / 'docs/facility-upgrades-final-verification.json', verification)
    return {'installed': True, 'files': len(records), 'previousFilesVerified': 62, 'archive': str(archive),
            'backup': str(out / 'local-backup'), 'manifest': str(out / 'manifest.json')}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--plan', action='store_true')
    group.add_argument('--scope-json', action='store_true', help='Read-only current source hashes: upgrade scope plus previous 62 files')
    group.add_argument('--validate-guide', action='store_true', help='Static HTML/link/Desktop checks, no browser')
    group.add_argument('--package', action='store_true')
    group.add_argument('--install', metavar='ARCHIVE_DIRECTORY')
    args = parser.parse_args()
    if args.install: result = install(args.install)
    elif args.validate_guide: result = validate_guide()
    else:
        records = collect_scope()
        if args.scope_json: result = evidence_hashes(records)
        elif args.package: result = package(records)
        else:
            result = plan(records)
            write(ROOT / 'docs/facility-upgrades-deployment-plan.json', result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try: main()
    except (RuntimeError, OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
