"""Scoped voluntary bed-rest delivery; --plan never writes to the game.

After independent review: node tools/audit.cjs, then
node tools/test-bed-sleep-delivery.cjs, then --validate-guide, --package.
Install is separate: --install E:/Codex-Archives/<exact-package-directory>.
The 58 previously installed restoration files are checked, never repackaged.
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
BASELINE = ROOT / '.runtime/bed-sleep-20261008/before-manifest.json'
BEFORE = BASELINE.parent / 'before'
PREVIOUS = ROOT / 'docs/restored-systems-deployment.json'
PLUGIN = 'ixhl2rp/plugins/sleep'
RUNTIME = tuple(PLUGIN + '/' + name for name in ('sh_plugin.lua', 'sh_beds.lua', 'sv_sleep.lua', 'cl_sleep.lua'))
EVIDENCE = ROOT / 'docs/bed-sleep-validation.json'
GUIDE = ROOT / 'docs/restored-systems-guide.html'
DESKTOP_GUIDE = ROOT.parent / 'Foundation-Restored-Systems-Guide.html'
TEST_FILES = ('tools/test-bed-sleep.cjs', 'tools/test-restored-engineering.cjs',
              'tools/test-restored-furniture.cjs', 'tools/test-restored-carts.cjs',
              'tools/test-restored-quests.cjs', 'tools/test-restored-pose-tools.cjs')
DOCS = ('docs/bed-sleep.md', 'docs/bed-sleep-sources.json', 'docs/bed-sleep-delivery.md', 'docs/restored-systems-guide.html',
        'docs/bed-sleep-deployment-plan.json', 'docs/bed-sleep-file-list.txt',
        'docs/bed-sleep-guide-validation.json', 'docs/bed-sleep-validation.json',
        'docs/source-audit.json')


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


def collect_scope():
    baseline = load(BASELINE)
    require(Path(baseline['root']).resolve() == ROOT, 'Baseline belongs to another checkout')
    rows = {e['path']: e for e in baseline['files']}
    require(len(rows) == len(baseline['files']), 'Duplicate baseline paths')
    records = []
    for rel in sorted(RUNTIME):
        require(rel in rows, 'Runtime file lacks captured baseline: ' + rel)
        row = rows[rel]
        require(row['existed'] == (row['sha256'] is not None), 'Inconsistent baseline: ' + rel)
        backup = inside(BEFORE, rel)
        if row['existed']:
            require(file_hash(backup) == row['sha256'], 'Source backup mismatch: ' + rel)
        source = inside(ROOT, rel)
        require(source.is_file(), 'Implementation is not complete: ' + rel)
        records.append({'path': rel, 'sha256': sha(source), 'sourceBeforeSHA256': row['sha256'],
                        'sourceBackup': str(backup) if row['existed'] else None})
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / PLUGIN).rglob('*') if p.is_file()}
    require(actual == set(RUNTIME), 'Plugin file scope changed; review delivery scope: ' + str(sorted(actual ^ set(RUNTIME))))
    return records


def previous_manifest():
    previous = load(PREVIOUS)
    require(previous.get('installed') is True and len(previous['files']) == 58, 'Previous installed restoration manifest is incomplete')
    require(previous['liveRoot'] == str(LIVE) and previous['sourceRoot'] == str(ROOT), 'Previous restoration roots differ')
    archived = Path(previous['archiveRoot']) / 'manifest.json'
    require(load(archived) == previous, 'Historical restoration manifest differs from its archived original')
    return previous


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
            conflicts.append({**record, 'reason': 'Prior restoration differs outside the allowed bed-rest baseline'})
    return {'manifest': str(PREVIOUS), 'manifestSHA256': sha(PREVIOUS), 'count': len(results),
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
    if (LIVE / PLUGIN).exists():
        for path in (LIVE / PLUGIN).rglob('*'):
            if path.is_file() and path.relative_to(LIVE).as_posix() not in RUNTIME:
                conflicts.append({'path': path.relative_to(LIVE).as_posix(), 'reason': 'Unscoped installed plugin file; not overwritten'})
    previous = previous_check(records)
    conflicts.extend(previous['conflicts'])
    return {'createdUTC': now(), 'sourceRoot': str(ROOT), 'liveRoot': str(LIVE), 'files': results,
            'baselineSHA256': sha(BASELINE), 'previousRestoration': previous, 'conflicts': conflicts,
            'gameLaunched': False, 'installed': False}


def validate_evidence(records):
    evidence = load(EVIDENCE)
    require(evidence.get('success') is True and evidence.get('sourceHashes') == evidence_hashes(records), 'Final test evidence is stale/incomplete')
    require(evidence.get('sourceUnchanged') and evidence.get('auditUnchanged'), 'Sources/audit changed during tests')
    require(evidence.get('deliveryToolsUnchanged') and evidence.get('deliveryToolSHA256') == sha(ROOT / 'tools/deploy-bed-sleep.py')
            and evidence.get('aggregateRunnerSHA256') == sha(ROOT / 'tools/test-bed-sleep-delivery.cjs'), 'Delivery tools changed after final safety checks')
    audit_path = ROOT / 'docs/source-audit.json'
    require(evidence.get('auditSHA256') == sha(audit_path), 'Syntax audit differs from final test evidence')
    audit = load(audit_path)
    require(not audit['syntaxFailures'], 'Syntax audit has failures')
    audited = {e['path']: e['sha256'] for e in audit['entries']}
    for rel, digest in evidence_hashes(records).items():
        require(audited.get(rel) == digest, 'Source audit is stale: ' + rel)
    require({t['script'] for t in evidence.get('tests', [])} == set(TEST_FILES), 'Six focused test scripts are required')
    require(evidence.get('deliverySafety', {}).get('script') == 'tools/test-bed-sleep-deploy.py', 'Delivery safety checks are missing')
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
    require('sleep' in parser.ids, 'Guide bed-rest section missing')
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
    write(ROOT / 'docs/bed-sleep-guide-validation.json', report)
    if strict: require(report['allLinksExist'], 'Guide document links not ready; see bed-sleep-guide-validation.json')
    return report


def verify_unchanged(records):
    for record in records:
        require(file_hash(inside(ROOT, record['path'])) == record['sha256'], 'Source changed during delivery: ' + record['path'])
        require(file_hash(inside(LIVE, record['path'])) == record['previousLocalSHA256'], 'Installed file changed since backup: ' + record['path'])
    require(previous_check(records)['verified'], 'Previous restoration changed during delivery')


def package(records):
    report = plan(records)
    write(ROOT / 'docs/bed-sleep-deployment-plan.json', report)
    (ROOT / 'docs/bed-sleep-file-list.txt').write_text('\n'.join(r['status'] + '  ' + r['path'] for r in report['files']) + '\n', encoding='utf8')
    require(not report['conflicts'], 'Baseline conflicts: see docs/bed-sleep-deployment-plan.json')
    evidence = validate_evidence(records)
    guide = validate_guide()
    support = set(DOCS) | set(TEST_FILES) | {'tools/test-bed-sleep-delivery.cjs', 'tools/deploy-bed-sleep.py', 'tools/test-bed-sleep-deploy.py',
                '.runtime/bed-sleep-20261008/before-manifest.json', 'docs/restored-systems-deployment.json',
                '.runtime/bed-sleep-20261008/restored-systems-guide.before.html', '.runtime/bed-sleep-20261008/desktop-guide.before.html'}
    support.update('docs/' + row['path'] for row in guide['documents'])
    support.update(t['log'] for t in evidence['tests'] + [evidence['regression'], evidence['deliverySafety']])
    support.update(path.relative_to(ROOT).as_posix() for path in (ROOT / 'docs').glob('bed-sleep*review*.md'))
    for rel in support: require(inside(ROOT, rel).is_file(), 'Required delivery document missing: ' + rel)
    support_hashes = {rel: sha(inside(ROOT, rel)) for rel in sorted(support)}
    out = ARCHIVES / ('HL2RP-bed-sleep-20261008-' + dt.datetime.now().strftime('%H%M%S-%f'))
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
    shutil.copy2(BASELINE, out / 'source-backup/before-manifest.json')
    write(out / 'local-backup/before-manifest.json', {'liveRoot': str(LIVE), 'files': [
        {'path': r['path'], 'existed': r['previousLocalSHA256'] is not None, 'sha256': r['previousLocalSHA256']} for r in report['files']]})
    for rel in sorted(support):
        target = inside(staged, rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(inside(ROOT, rel), target)
        require(sha(target) == support_hashes[rel], 'Support file changed while staging: ' + rel)
    (staged / 'README.md').write_text(
        '# Foundation: добровольный отдых и сон\n\nОткройте docs/restored-systems-guide.html, раздел «Отдых на койке».\n\n'
        'Исполняемый пакет содержит только четыре файла нового плагина sleep. Ранее установленные 58 файлов '
        'проверяются по историческому манифесту и не входят в полезную нагрузку. Прогрессия, лечение и обязательная усталость не добавлены.\n\n'
        'Этап реализации и независимой проверки не устанавливал плагин. Итог установки отражает manifest.json рядом с ZIP '
        'и docs/bed-sleep-deployment.json исходного проекта. Манифест внутри ZIP описывает момент упаковки до установки. '
        'Предыдущие отчёты о пяти системах — исторические свидетельства, а не подтверждение установки сна.\n\n'
        'local-backup и source-backup содержат резервные копии и манифесты отсутствующих до установки файлов. '
        'Установка выполняется отдельно: deploy-bed-sleep.py --install <точная папка архива>. '
        'Инструменты и тесты запускаются из полного исходного проекта.\n\n'
        'Игра не запускалась. Сетевое поведение, поза, камера и выход с койки требуют проверки в GMod. '
        'HTML проверен структурно; визуальный просмотр запрещён политикой браузера для file URL.\n', encoding='utf8')
    manifest = {**report, 'archiveRoot': str(out), 'evidence': evidence, 'supportHashes': support_hashes, 'engineTested': False}
    write(staged / 'manifest.json', manifest)
    archive = out / 'Foundation-Bed-Sleep.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipout:
        for path in sorted(staged.rglob('*')):
            if path.is_file(): zipout.write(path, path.relative_to(staged).as_posix())
    verify_zip(archive, records, support_hashes)
    verify_unchanged(report['files'])
    require(sha(BASELINE) == report['baselineSHA256'], 'Baseline changed while packaging')
    for rel, digest in support_hashes.items(): require(sha(inside(ROOT, rel)) == digest, 'Support changed while packaging: ' + rel)
    manifest.update(archive=str(archive), archiveSHA256=sha(archive))
    write(out / 'manifest.json', manifest)
    write(ROOT / 'docs/bed-sleep-package.json', manifest)
    return {'packaged': True, 'installed': False, 'files': len(records), 'previousFilesVerified': 58,
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
    require(out.is_relative_to(ARCHIVES.resolve()) and out.name.startswith('HL2RP-bed-sleep-20261008-'), 'Unexpected archive root')
    manifest = load(out / 'manifest.json')
    require(manifest['liveRoot'] == str(LIVE) and manifest['sourceRoot'] == str(ROOT), 'Manifest roots differ')
    require(not manifest.get('installed'), 'Package already installed; inspect hashes instead of retrying')
    require(not manifest['conflicts'], 'Package contains conflicts')
    records, current = manifest['files'], collect_scope()
    require({r['path']: r['sha256'] for r in current} == {r['path']: r['sha256'] for r in records}, 'Source scope changed after packaging')
    require(sha(BASELINE) == manifest['baselineSHA256'], 'Baseline changed after packaging')
    require(sha(PREVIOUS) == manifest['previousRestoration']['manifestSHA256'], 'Historical manifest changed')
    validate_evidence(current)
    require(not plan(current)['conflicts'], 'Installed files changed after packaging')
    archive = out / 'Foundation-Bed-Sleep.zip'
    require(sha(archive) == manifest['archiveSHA256'], 'ZIP changed after packaging')
    verify_zip(archive, records, manifest['supportHashes'])
    for record in records:
        require(sha(inside(out / 'package/garrysmod/gamemodes', record['path'])) == record['sha256'], 'Staged runtime changed')
        if record['previousLocalSHA256'] is not None:
            require(sha(inside(out / 'local-backup', record['path'])) == record['previousLocalSHA256'], 'Local backup changed')
        if record['sourceBeforeSHA256'] is not None:
            require(sha(inside(out / 'source-backup', record['path'])) == record['sourceBeforeSHA256'], 'Source backup changed')
    require(sha(out / 'source-backup/before-manifest.json') == manifest['baselineSHA256'], 'Archived source baseline changed')
    for rel, digest in manifest['supportHashes'].items():
        require(sha(inside(ROOT, rel)) == digest and sha(inside(out / 'package', rel)) == digest, 'Support file changed: ' + rel)
    verify_unchanged(records)
    written = []
    try:
        for record in records:
            destination = inside(LIVE, record['path'])
            require(file_hash(destination) == record['previousLocalSHA256'], 'Destination changed immediately before copy')
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_name(destination.name + '.bed-sleep-stage-' + str(os.getpid()))
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
    write(ROOT / 'docs/bed-sleep-deployment.json', manifest)
    write(ROOT / 'docs/bed-sleep-final-verification.json', verification)
    return {'installed': True, 'files': len(records), 'previousFilesVerified': 58, 'archive': str(archive),
            'backup': str(out / 'local-backup'), 'manifest': str(out / 'manifest.json')}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--plan', action='store_true')
    group.add_argument('--scope-json', action='store_true', help='Read-only current source hashes: bed scope plus previous 58 files')
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
            write(ROOT / 'docs/bed-sleep-deployment-plan.json', result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try: main()
    except (RuntimeError, OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
