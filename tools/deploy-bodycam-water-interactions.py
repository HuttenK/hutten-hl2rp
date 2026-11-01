"""Scoped terminal bodycam viewer and distinct water-action animation delivery; --plan never writes to the game.

After independent review: node tools/audit-bodycam-water-interactions.cjs, then
node tools/test-bodycam-water-interactions-delivery.cjs, then --validate-guide, --package.
Install is separate: --install E:/Codex-Archives/<exact-package-directory>.
The 117 unique previously installed files are checked; only explicit scoped updates are repackaged.
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
BASE_DIR = ROOT / '.runtime/bodycam-water-interactions-20261009'
BASELINES = (ROOT / '.runtime/bodycam-terminal-viewer-20261009/before-manifest.json',
             ROOT / '.runtime/water-action-animations-20261009/before-manifest.json')
FROZEN_SCOPE = BASE_DIR / 'frozen-scope.json'
PRIVATE_BASELINE = BASE_DIR / 'pose-data-before.json'
PRIVATE_DATA = LIVE.parent / 'data/helix/ixhl2rp/pose_studio.txt'
PREVIOUS = ((ROOT / 'docs/restored-systems-deployment.json', 58),
            (ROOT / 'docs/bed-sleep-deployment.json', 4),
            (ROOT / 'docs/facility-upgrades-deployment.json', 32),
            (ROOT / 'docs/cctv-recognition-salute-deployment.json', 9),
            (ROOT / 'docs/device-ui-redesign-deployment.json', 35))
EVIDENCE = ROOT / 'docs/bodycam-water-interactions-validation.json'
GUIDE = ROOT / 'docs/restored-systems-guide.html'
DESKTOP_GUIDE = ROOT.parent / 'Foundation-Restored-Systems-Guide.html'
FACILITIES_GUIDE = ROOT / 'docs/Foundation-Facilities-Guide.html'
DESKTOP_FACILITIES_GUIDE = ROOT.parent / 'Foundation-Facilities-Guide.html'
GALLERY = ROOT / 'docs/bodycam-water-interactions-previews.html'
GUIDE_BASELINE = BASE_DIR / 'guide-before-manifest.json'

TEST_FILES = ('tools/test-bodycam-terminal-viewer.cjs', 'tools/test-water-action-animations.cjs', 'tools/test-cctv.cjs', 'tools/test-cctv-recognition.cjs', 'tools/test-bodycams.cjs', 'tools/test-bodycam-usability.cjs', 'tools/test-animation-upgrades.cjs', 'tools/test-water-sources.cjs', 'tools/test-clean-water.cjs', 'tools/test-sink-registry.cjs')
REVIEWS = ('docs/bodycam-water-interactions-review.md',)
DOCS = ('docs/bodycam-water-interactions-delivery.md', 'docs/restored-systems-guide.html',
        'docs/Foundation-Facilities-Guide.html', 'docs/bodycam-water-interactions-previews.html',
        'docs/bodycam-terminal-viewer.md', 'docs/water-action-animations.md',
        'docs/water-action-animations-source-manifest.json', 'docs/bodycam-water-interactions-preview-index.json',
        'docs/water-action-animations-contact.png', 'docs/water-action-animations-contact.svg',
        'docs/bodycam-water-interactions-deployment-plan.json', 'docs/bodycam-water-interactions-file-list.txt',
        'docs/bodycam-water-interactions-guide-validation.json', 'docs/bodycam-water-interactions-validation.json',
        'docs/bodycam-water-interactions-source-audit.json') + REVIEWS


# The previous delivered tool is immutable; its hash is bound as a test-support dependency.
import importlib.util
_helper_spec = importlib.util.spec_from_file_location('foundation_delivery_helpers', ROOT / 'tools/deploy-device-ui-redesign.py')
_helpers = importlib.util.module_from_spec(_helper_spec)
_helper_spec.loader.exec_module(_helpers)
require, sha, load, write, now = (_helpers.require, _helpers.sha, _helpers.load, _helpers.write, _helpers.now)
inside, file_hash, GuideParser = (_helpers.inside, _helpers.file_hash, _helpers.GuideParser)


def baseline_hashes():
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in BASELINES}


def read_baseline_rows():
    rows = {}
    for baseline_path in BASELINES:
        require(baseline_path.resolve().is_relative_to((ROOT / '.runtime').resolve()), 'Baseline escapes task directory')
        baseline = load(baseline_path)
        if isinstance(baseline, dict):
            require(Path(baseline['root']).resolve() == ROOT.resolve(), 'Baseline belongs to another checkout')
            values = baseline['files']
        else:
            require(isinstance(baseline, list), 'Unsupported baseline schema')
            values = baseline
        before = baseline_path.parent / 'before' if baseline_path.name == 'before-manifest.json' else baseline_path.with_name(baseline_path.name.replace('-before-manifest.json', '-before'))
        for original in values:
            rel = original['path']
            require(rel not in rows, 'Duplicate baseline paths: ' + rel)
            inside(ROOT, rel)
            digest = original.get('sha256', original.get('beforeSHA256'))
            existed = original.get('existed', not original.get('new', False))
            require(isinstance(existed, bool) and existed == (digest is not None), 'Inconsistent baseline: ' + rel)
            require(digest is None or re.fullmatch(r'[0-9a-f]{64}', digest), 'Invalid baseline hash: ' + rel)
            row = {'path': rel, 'existed': existed, 'sha256': digest}
            if 'bytes' in original:
                row['bytes'] = original['bytes']
            rows[rel] = (row, before)
    return rows


def runtime_paths(rows):
    paths = sorted(rel for rel in rows if rel.startswith(('ixhl2rp/', 'helix/')))
    require(paths and all(rel.endswith('.lua') and '/data/' not in rel and '/models/' not in rel for rel in paths),
            'Only explicitly captured Lua runtime files may be delivered')
    return paths


def private_data_check():
    baseline = load(PRIVATE_BASELINE)
    require(Path(baseline['path']).resolve() == PRIVATE_DATA.resolve(), 'Saved-pose data path differs')
    require(baseline.get('contentCopied') is False, 'Private data baseline must contain metadata only')
    current = file_hash(PRIVATE_DATA)
    require(current == baseline['sha256'] and PRIVATE_DATA.stat().st_size == baseline['bytes'],
            'Saved pose data changed; delivery will not modify or restore it')
    return {'path': str(PRIVATE_DATA), 'sha256': current, 'bytes': baseline['bytes'],
            'unchanged': True, 'contentCopied': False}


def freeze_scope():
    require(not FROZEN_SCOPE.exists(), 'Scope is already frozen; inspect before replacing it')
    private_data_check()
    value = {'root': str(ROOT), 'createdUTC': now(), 'runtime': runtime_paths(read_baseline_rows()),
             'baselineHashes': baseline_hashes(), 'privateBaselineSHA256': sha(PRIVATE_BASELINE)}
    write(FROZEN_SCOPE, value)
    return {'frozen': True, 'files': len(value['runtime']), 'path': str(FROZEN_SCOPE)}


def collect_scope():
    rows = read_baseline_rows()
    frozen = load(FROZEN_SCOPE)
    require(Path(frozen['root']).resolve() == ROOT.resolve(), 'Frozen scope belongs to another checkout')
    require(frozen['baselineHashes'] == baseline_hashes(), 'Baseline changed after scope freeze')
    require(frozen['privateBaselineSHA256'] == sha(PRIVATE_BASELINE), 'Private data baseline changed')
    require(frozen['runtime'] == runtime_paths(rows), 'Runtime baseline scope differs from reviewed frozen scope')
    private_data_check()
    records = []
    for rel in frozen['runtime']:
        row, before = rows[rel]
        require(row['existed'] == (row['sha256'] is not None), 'Inconsistent baseline: ' + rel)
        backup = inside(before, rel)
        if row['existed']:
            require(file_hash(backup) == row['sha256'], 'Source backup mismatch: ' + rel)
            if 'bytes' in row: require(backup.stat().st_size == row['bytes'], 'Source backup size mismatch: ' + rel)
        source = inside(ROOT, rel)
        require(source.is_file(), 'Implementation is not complete: ' + rel)
        records.append({'path': rel, 'sha256': sha(source), 'sourceBeforeSHA256': row['sha256'],
                        'sourceBackup': str(backup) if row['existed'] else None})
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
            if row['path'] in files:
                require(row.get('sourceBeforeSHA256') == files[row['path']]['sha256'],
                        'Historical superseding baseline differs: ' + row['path'])
            files[row['path']] = row
    require(len(files) == 117, 'Historical unique file count differs')
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


def test_support_hashes():
    paths = {'tools/audit-bodycam-water-interactions.cjs', 'tools/deploy-device-ui-redesign.py', 'tools/glua.cjs', 'tools/fixture.lua', 'tools/restored-test-runner.cjs',
             'tools/test-pose-portability.cjs'}
    paths.update(rel for rel in read_baseline_rows() if rel.startswith('tools/') and rel not in TEST_FILES)
    paths.update(path.relative_to(ROOT).as_posix() for path in (ROOT / 'tools/fixtures').rglob('*') if path.is_file())
    paths.update(path.relative_to(ROOT).as_posix() for path in (ROOT / 'tools').glob('*.cjs') if path.name.startswith(('test-', 'preview-')) and path.relative_to(ROOT).as_posix() not in TEST_FILES)
    return {rel: sha(inside(ROOT, rel)) for rel in sorted(paths)}


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
    previous = previous_check(records)
    conflicts.extend(previous['conflicts'])
    return {'createdUTC': now(), 'sourceRoot': str(ROOT), 'liveRoot': str(LIVE), 'files': results,
            'baselineHashes': baseline_hashes(), 'frozenScopeSHA256': sha(FROZEN_SCOPE),
            'privateData': private_data_check(), 'previousRestoration': previous, 'conflicts': conflicts,
            'gameLaunched': False, 'installed': False}


def validate_evidence(records):
    evidence = load(EVIDENCE)
    require(evidence.get('success') is True and evidence.get('sourceHashes') == evidence_hashes(records), 'Final test evidence is stale/incomplete')
    require(evidence.get('sourceUnchanged') and evidence.get('auditUnchanged'), 'Sources/audit changed during tests')
    require(evidence.get('testSupportUnchanged') and evidence.get('testSupportHashes') == test_support_hashes(),
            'Imported test modules or fixtures changed after final tests')
    prior_evidence = load(BASE_DIR / 'prior-evidence-before.json')
    require(evidence.get('priorEvidenceUnchanged') and evidence.get('priorEvidenceHashes') == prior_evidence,
            'Historical evidence guard is missing or stale')
    for rel, digest in prior_evidence.items():
        require(file_hash(inside(ROOT, rel)) == digest, 'Historical evidence changed: ' + rel)
    require(evidence.get('deliveryToolsUnchanged') and evidence.get('deliveryToolSHA256') == sha(ROOT / 'tools/deploy-bodycam-water-interactions.py')
            and evidence.get('aggregateRunnerSHA256') == sha(ROOT / 'tools/test-bodycam-water-interactions-delivery.cjs'), 'Delivery tools changed after final safety checks')
    audit_path = ROOT / 'docs/bodycam-water-interactions-source-audit.json'
    require(evidence.get('auditSHA256') == sha(audit_path), 'Syntax audit differs from final test evidence')
    audit = load(audit_path)
    require(not audit['syntaxFailures'], 'Syntax audit has failures')
    audited = {e['path']: e['sha256'] for e in audit['entries']}
    for rel, digest in evidence_hashes(records).items():
        require(audited.get(rel) == digest, 'Source audit is stale: ' + rel)
    require({t['script'] for t in evidence.get('tests', [])} == set(TEST_FILES), 'All focused test scripts are required')
    require(evidence.get('deliverySafety', {}).get('script') == 'tools/test-bodycam-water-interactions-deploy.py', 'Delivery safety checks are missing')
    for test in evidence['tests'] + [evidence.get('regression', {}), evidence['deliverySafety']]:
        require(test.get('exitCode') == 0 and test.get('scriptUnchanged') and test.get('log') and test.get('script'), 'Missing final test result')
        require(sha(inside(ROOT, test['script'])) == test['scriptSHA256'], 'Test script changed: ' + test['script'])
        require(file_hash(inside(ROOT, test['log'])) == test['logSHA256'], 'Final log missing or changed: ' + test['log'])
    require(evidence['regression']['script'] == 'tools/test.cjs', 'Wrong broad regression script')
    result = re.search(r'(\d+) regression suites passed\.', inside(ROOT, evidence['regression']['log']).read_text(encoding='utf-8-sig'))
    require(result and int(result.group(1)) >= 424, 'Broad regression completion marker missing')
    return evidence


def guide_pairs():
    return ((GUIDE, DESKTOP_GUIDE), (FACILITIES_GUIDE, DESKTOP_FACILITIES_GUIDE))


def guide_backups_check():
    rows = load(GUIDE_BASELINE)
    require(len(rows) == 4, 'Both guide pairs must have byte backups')
    expected = {str(p.resolve()) for pair in guide_pairs() for p in pair}
    require({str(Path(row['path']).resolve()) for row in rows} == expected, 'Guide baseline paths differ')
    for row in rows:
        backup = Path(row['backup']).resolve()
        require(backup.is_relative_to(BASE_DIR.resolve()), 'Guide backup escapes task directory')
        require(file_hash(backup) == row['sha256'] and backup.stat().st_size == row['bytes'], 'Guide backup changed')
    return rows


def validate_guide(strict=True):
    import base64
    guide_backups_check()
    reports, documents = [], {}
    for source, desktop in (*guide_pairs(), (GALLERY, None)):
        content = source.read_text(encoding='utf-8-sig')
        parser = GuideParser()
        parser.feed(content)
        require(len(parser.ids) == len(set(parser.ids)), 'Duplicate guide IDs: ' + source.name)
        require(set(parser.anchors).issubset(parser.ids), 'Broken guide anchor: ' + source.name)
        if source == GUIDE:
            require({'sleep', 'water', 'decon', 'bodycams', 'animation', 'recognition'}.issubset(parser.ids), 'Guide upgrade sections missing')
        if source == FACILITIES_GUIDE:
            require({'start', 'intercom', 'power', 'repair', 'setup', 'access', 'help', 'verification'}.issubset(parser.ids), 'Facilities sections missing')
        for asset in parser.assets:
            match = re.fullmatch(r'data:image/(png|svg\+xml);base64,([A-Za-z0-9+/=\s]+)', asset)
            require(match, 'Guide depends on external asset: ' + source.name)
            decoded = base64.b64decode(match.group(2), validate=True)
            require(bool(decoded), 'Empty embedded image')
            if match.group(1) == 'png': require(decoded.startswith(b'\x89PNG\r\n\x1a\n'), 'Bad embedded PNG')
            else: require(b'<svg' in decoded, 'Bad embedded SVG')
        require(not re.search(r'url\s*\(|@import', content, re.I), 'External CSS assets are not permitted')
        if desktop:
            require(desktop.is_file() and sha(desktop) == sha(source), 'Desktop guide differs: ' + source.name)
            require("file:///C:/Users/q1236/Desktop/hutten-hl2rp-2/docs/" in content, 'Desktop document link resolver missing')
        for rel in parser.documents:
            documents[rel] = {'path': rel, 'exists': inside(ROOT / 'docs', rel).is_file()}
        reports.append({'path': source.relative_to(ROOT).as_posix(), 'sha256': sha(source), 'sections': parser.sections,
                        'anchorLinks': len(parser.anchors), 'embeddedImages': len(parser.assets), 'externalAssets': 0,
                        'desktopIdentical': sha(source) == sha(desktop) if desktop else None})
    report = {'checkedUTC': now(), 'guides': reports, 'documents': list(documents.values()),
              'allLinksExist': all(row['exists'] for row in documents.values()), 'visualBrowserVerification': False,
              'visualLimit': 'Browser security policy rejected file protocol. No alternate surface was attempted. Production callback previews are offline composition evidence, not Source rendering.'}
    write(ROOT / 'docs/bodycam-water-interactions-guide-validation.json', report)
    if strict: require(report['allLinksExist'], 'Guide document links not ready; see bodycam-water-interactions-guide-validation.json')
    return report


def verify_unchanged(records):
    for record in records:
        require(file_hash(inside(ROOT, record['path'])) == record['sha256'], 'Source changed during delivery: ' + record['path'])
        require(file_hash(inside(LIVE, record['path'])) == record['previousLocalSHA256'], 'Installed file changed since backup: ' + record['path'])
    require(previous_check(records)['verified'], 'Previous restoration changed during delivery')
    private_data_check()


def package(records):
    report = plan(records)
    write(ROOT / 'docs/bodycam-water-interactions-deployment-plan.json', report)
    (ROOT / 'docs/bodycam-water-interactions-file-list.txt').write_text('\n'.join(r['status'] + '  ' + r['path'] for r in report['files']) + '\n', encoding='utf8')
    require(not report['conflicts'], 'Baseline conflicts: see docs/bodycam-water-interactions-deployment-plan.json')
    evidence = validate_evidence(records)
    guide = validate_guide()
    support = set(DOCS) | set(TEST_FILES) | {
        'tools/test-bodycam-water-interactions-delivery.cjs', 'tools/deploy-bodycam-water-interactions.py', 'tools/test-bodycam-water-interactions-deploy.py',
        'tools/fixtures/bodycams.lua', 'tools/restored-test-runner.cjs', 'tools/test.cjs', 'docs/restored-systems-deployment.json',
        'docs/bed-sleep-deployment.json', 'docs/facility-upgrades-deployment.json',
        'docs/cctv-recognition-salute-deployment.json', 'docs/device-ui-redesign-deployment.json'}
    support.update(Path(row['backup']).relative_to(ROOT).as_posix() for row in guide_backups_check())
    support.update({'tools/preview-bodycam-terminal-viewer.cjs', 'tools/preview-water-actions.cjs'})
    viewer_before = ROOT / '.runtime/bodycam-terminal-viewer-20261009/support-before-manifest.json'
    before_data = load(viewer_before)
    require(Path(before_data['root']).resolve() == ROOT.resolve(), 'Viewer support baseline belongs to another checkout')
    support.add(viewer_before.relative_to(ROOT).as_posix())
    for row in before_data['files']:
        require(row['path'].startswith('tools/') and row['existed'], 'Unexpected viewer support baseline')
        backup = inside(viewer_before.parent / 'before', row['path'])
        require(file_hash(backup) == row['sha256'], 'Original viewer test backup changed: ' + row['path'])
        support.add(backup.relative_to(ROOT).as_posix())
    support.add('.runtime/bodycam-terminal-viewer-20261009/after-manifest.json')
    support.add('.runtime/bodycam-water-interactions-20261009/prior-evidence-before.json')
    support.update(path.relative_to(ROOT).as_posix() for path in (ROOT / '.runtime/bodycam-terminal-viewer-20261009/previews').glob('*') if path.suffix in ('.png', '.svg'))
    support.update(path.relative_to(ROOT).as_posix() for path in (*BASELINES, FROZEN_SCOPE, PRIVATE_BASELINE, GUIDE_BASELINE))
    support.update(rel for rel in read_baseline_rows() if rel.startswith(('docs/', 'tools/')))
    support.update(evidence['testSupportHashes'])
    support.update('docs/' + row['path'] for row in guide['documents'])
    support.update(t['log'] for t in evidence['tests'] + [evidence['regression'], evidence['deliverySafety']])
    support.update(path.relative_to(ROOT).as_posix() for path in (ROOT / 'docs').glob('bodycam-water-interactions*review*.md'))
    for rel in support: require(inside(ROOT, rel).is_file(), 'Required delivery document missing: ' + rel)
    support_hashes = {rel: sha(inside(ROOT, rel)) for rel in sorted(support)}
    out = ARCHIVES / ('HL2RP-bodycam-water-interactions-20261009-' + dt.datetime.now().strftime('%H%M%S-%f'))
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
        destination = inside(out / 'source-backup', baseline.relative_to(ROOT).as_posix())
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(baseline, destination)
    write(out / 'local-backup/before-manifest.json', {'liveRoot': str(LIVE), 'files': [
        {'path': r['path'], 'existed': r['previousLocalSHA256'] is not None, 'sha256': r['previousLocalSHA256']} for r in report['files']]})
    for rel in sorted(support):
        target = inside(staged, rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(inside(ROOT, rel), target)
        require(sha(target) == support_hashes[rel], 'Support file changed while staging: ' + rel)
    (staged / 'README.md').write_text(
        '# Foundation: просмотр камер на шлемах и действия с водой\n\n'
        'Начните с docs/restored-systems-guide.html. Полезная нагрузка включает только Lua-файлы '
        'зафиксированного состава. Пять прежних поставок проверяются по последнему хэшу каждого '
        'из 117 уникальных файлов; исторические манифесты и архивы не изменены.\n\n'
        'Сохранённые пользовательские позы не копируются, не перезаписываются и не входят в архив. '
        'Проверяется только неизменность их размера и SHA256. Модели и извлечённый контент не поставляются.\n\n'
        'Установка отделена от упаковки. Фактический результат отражает внешний manifest.json рядом с ZIP '
        'и docs/bodycam-water-interactions-deployment.json исходного проекта. Встроенный манифест описывает момент упаковки. '
        'local-backup и source-backup содержат прежние Lua-файлы и манифесты отсутствовавших файлов.\n\n'
        'Игра не запускалась. Изображение CCTV, распознавание и анимации требуют проверки в GMod. '
        'HTML проверен структурно: браузер запретил file URL, обход не применялся.\n', encoding='utf8')
    manifest = {**report, 'archiveRoot': str(out), 'evidence': evidence, 'supportHashes': support_hashes, 'engineTested': False}
    write(staged / 'manifest.json', manifest)
    archive = out / 'Foundation-Bodycam-Water-Interactions.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipout:
        for path in sorted(staged.rglob('*')):
            if path.is_file(): zipout.write(path, path.relative_to(staged).as_posix())
    verify_zip(archive, records, support_hashes)
    verify_unchanged(report['files'])
    require(baseline_hashes() == report['baselineHashes'], 'Baseline changed while packaging')
    require(sha(FROZEN_SCOPE) == report['frozenScopeSHA256'], 'Frozen scope changed while packaging')
    for rel, digest in support_hashes.items(): require(sha(inside(ROOT, rel)) == digest, 'Support changed while packaging: ' + rel)
    manifest.update(archive=str(archive), archiveSHA256=sha(archive))
    write(out / 'manifest.json', manifest)
    write(ROOT / 'docs/bodycam-water-interactions-package.json', manifest)
    return {'packaged': True, 'installed': False, 'files': len(records), 'previousFilesVerified': 117,
            'archive': str(archive), 'archiveRoot': str(out)}


def verify_zip(archive, records, support_hashes):
    with zipfile.ZipFile(archive) as zipin:
        require(zipin.testzip() is None, 'ZIP CRC verification failed')
        require(not any('/data/' in name or name.endswith('pose_studio.txt') or name.lower().endswith(('.mdl', '.vtx', '.vvd', '.phy')) for name in zipin.namelist()), 'ZIP contains private data or model assets')
        payload = {name.removeprefix('garrysmod/gamemodes/') for name in zipin.namelist() if name.startswith('garrysmod/gamemodes/')}
        require(payload == {r['path'] for r in records}, 'ZIP contains unscoped runtime files')
        for name, digest in {**{'garrysmod/gamemodes/' + r['path']: r['sha256'] for r in records}, **support_hashes}.items():
            require(hashlib.sha256(zipin.read(name)).hexdigest() == digest, 'ZIP hash mismatch: ' + name)


def install(directory):
    out = Path(directory).resolve()
    require(out.is_relative_to(ARCHIVES.resolve()) and out.name.startswith('HL2RP-bodycam-water-interactions-20261009-'), 'Unexpected archive root')
    manifest = load(out / 'manifest.json')
    require(manifest['liveRoot'] == str(LIVE) and manifest['sourceRoot'] == str(ROOT), 'Manifest roots differ')
    require(not manifest.get('installed'), 'Package already installed; inspect hashes instead of retrying')
    require(not manifest['conflicts'], 'Package contains conflicts')
    records, current = manifest['files'], collect_scope()
    require({r['path']: r['sha256'] for r in current} == {r['path']: r['sha256'] for r in records}, 'Source scope changed after packaging')
    require(baseline_hashes() == manifest['baselineHashes'], 'Baseline changed after packaging')
    require(sha(FROZEN_SCOPE) == manifest['frozenScopeSHA256'], 'Frozen scope changed after packaging')
    require(private_data_check() == manifest['privateData'], 'Private data verification changed')
    require(previous_manifest()['manifests'] == manifest['previousRestoration']['manifests'], 'Historical manifests changed')
    validate_evidence(current)
    require(not plan(current)['conflicts'], 'Installed files changed after packaging')
    archive = out / 'Foundation-Bodycam-Water-Interactions.zip'
    require(sha(archive) == manifest['archiveSHA256'], 'ZIP changed after packaging')
    verify_zip(archive, records, manifest['supportHashes'])
    for record in records:
        require(sha(inside(out / 'package/garrysmod/gamemodes', record['path'])) == record['sha256'], 'Staged runtime changed')
        if record['previousLocalSHA256'] is not None:
            require(sha(inside(out / 'local-backup', record['path'])) == record['previousLocalSHA256'], 'Local backup changed')
        if record['sourceBeforeSHA256'] is not None:
            require(sha(inside(out / 'source-backup', record['path'])) == record['sourceBeforeSHA256'], 'Source backup changed')
    for baseline in BASELINES:
        require(sha(inside(out / 'source-backup', baseline.relative_to(ROOT).as_posix())) == manifest['baselineHashes'][baseline.relative_to(ROOT).as_posix()], 'Archived baseline changed')
    for rel, digest in manifest['supportHashes'].items():
        require(sha(inside(ROOT, rel)) == digest and sha(inside(out / 'package', rel)) == digest, 'Support file changed: ' + rel)
    verify_unchanged(records)
    written = []
    try:
        for record in records:
            destination = inside(LIVE, record['path'])
            require(file_hash(destination) == record['previousLocalSHA256'], 'Destination changed immediately before copy')
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_name(destination.name + '.bodycam-water-interactions-stage-' + str(os.getpid()))
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
        require(all(sha(source) == sha(desktop) for source, desktop in guide_pairs()), 'Desktop guides changed during installation')
        guide_backups_check()
        private_data_check()
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
                    'desktopGuidesIdentical': all(sha(source) == sha(desktop) for source, desktop in guide_pairs()), 'engineTested': False,
                    'privateData': private_data_check(),
                    'files': [{'path': r['path'], 'sha256': r['sha256']} for r in records]}
    manifest.update(installed=True, installedUTC=now(), finalVerification=verification)
    write(out / 'manifest.json', manifest)
    write(out / 'final-verification.json', verification)
    write(ROOT / 'docs/bodycam-water-interactions-deployment.json', manifest)
    write(ROOT / 'docs/bodycam-water-interactions-final-verification.json', verification)
    return {'installed': True, 'files': len(records), 'previousFilesVerified': 117, 'archive': str(archive),
            'backup': str(out / 'local-backup'), 'manifest': str(out / 'manifest.json')}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--plan', action='store_true')
    group.add_argument('--freeze-scope', action='store_true', help='Only after author freeze and root approval')
    group.add_argument('--scope-json', action='store_true', help='Read-only current source hashes: current scope plus previous 117 unique files')
    group.add_argument('--test-support-json', action='store_true', help='Read-only imported test modules and fixtures')
    group.add_argument('--validate-guide', action='store_true', help='Static HTML/link/Desktop checks, no browser')
    group.add_argument('--package', action='store_true')
    group.add_argument('--install', metavar='ARCHIVE_DIRECTORY')
    args = parser.parse_args()
    if args.freeze_scope: result = freeze_scope()
    elif args.install: result = install(args.install)
    elif args.validate_guide: result = validate_guide()
    elif args.test_support_json: result = test_support_hashes()
    else:
        records = collect_scope()
        if args.scope_json: result = evidence_hashes(records)
        elif args.package: result = package(records)
        else:
            result = plan(records)
            write(ROOT / 'docs/bodycam-water-interactions-deployment-plan.json', result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try: main()
    except (RuntimeError, OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
