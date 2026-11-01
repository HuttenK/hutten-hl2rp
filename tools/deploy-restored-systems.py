"""Scoped restoration delivery. Default/--plan never writes to the game.

Workflow after independent review:
  node tools/audit.cjs
  node tools/test-restored-systems.cjs --with-regression
  python tools/deploy-restored-systems.py --plan
  python tools/deploy-restored-systems.py --package
  python tools/deploy-restored-systems.py --install E:/Codex-Archives/<package-dir>

Packaging requires final test evidence and rejects divergent installed baselines.
Install is a separate explicit operation; it verifies every destination first.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
ARCHIVES = Path('E:/Codex-Archives')
BEFORE = ROOT / '.runtime/systems-restoration-20261008/before'
BASELINE = ROOT / '.runtime/systems-restoration-20261008/before.json'
NEW_DIRS = ('ixhl2rp/plugins/furnishing', 'ixhl2rp/plugins/pushcart', 'ixhl2rp/plugins/quest_director')
NEW_FILES = tuple('ixhl2rp/plugins/facility_utilities/' + n + '.lua' for n in
                  ('sh_engineering_games', 'sh_engineering', 'sv_engineering', 'cl_engineering')) + (
                  'ixhl2rp/plugins/pose_studio/cl_pose_tools.lua',)
HEALTH = 'ixhl2rp/plugins/!healthsystem/sh_movement.lua'
HEALTH_BACKUP = ROOT / 'docs/restored-carts-backup/sh_movement.before.lua'
ITEM_CORE = 'helix/gamemode/game/items/sh_item.lua'
ITEM_CORE_BACKUP = ROOT / '.runtime/systems-restoration-20261008/sh_item.before-independent-review.lua'
DOCS = ('docs/restored-systems-guide.html', 'docs/restored-furniture-repairs.md',
        'docs/restored-carts.md', 'docs/restored-quests.md', 'docs/restored-pose-tools.md',
        'docs/restored-systems-sources.json', 'docs/restored-carts-sources.json',
        'docs/restored-quests-sources.json', 'docs/restored-systems-deployment-plan.json',
        'docs/restoration-independent-review.md', 'docs/restored-systems-file-list.txt',
        'docs/restored-systems-guide-validation.json')
TEST_FILES = ('tools/test-restored-engineering.cjs', 'tools/test-restored-furniture.cjs',
              'tools/test-restored-carts.cjs', 'tools/test-restored-quests.cjs',
              'tools/test-restored-pose-tools.cjs')
EVIDENCE = ROOT / 'docs/restored-systems-validation.json'


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


def inside(parent, rel):
    require(not Path(rel).is_absolute(), 'Absolute relative path: ' + str(rel))
    path = (parent / rel).resolve()
    require(path.is_relative_to(parent.resolve()), 'Path escapes root: ' + str(rel))
    return path


def collect_scope():
    baseline = {e['path']: e['sha256'] for e in load(BASELINE)}
    selected = {}
    for rel, digest in baseline.items():
        backup = inside(BEFORE, rel)
        src = inside(ROOT, rel)
        require(backup.is_file() and sha(backup) == digest, 'Source-before backup mismatch: ' + rel)
        require(src.is_file(), 'Source file removed; deletion needs explicit review: ' + rel)
        if sha(src) != digest:
            selected[rel] = {'sourceBeforeSHA256': digest, 'sourceBackup': str(backup)}
    for folder in NEW_DIRS:
        require((ROOT / folder).is_dir(), 'New plugin missing: ' + folder)
        for src in sorted((ROOT / folder).rglob('*')):
            if src.is_file():
                require(src.suffix == '.lua', 'Unexpected plugin payload; review scope: ' + str(src))
                selected[src.relative_to(ROOT).as_posix()] = {'sourceBeforeSHA256': None, 'sourceBackup': None}
    for rel in NEW_FILES:
        require((ROOT / rel).is_file(), 'Required new file missing: ' + rel)
        require(rel not in baseline, 'New file was present in baseline: ' + rel)
        selected[rel] = {'sourceBeforeSHA256': None, 'sourceBackup': None}
    require(HEALTH_BACKUP.is_file(), 'Health movement backup missing')
    selected[HEALTH] = {'sourceBeforeSHA256': sha(HEALTH_BACKUP), 'sourceBackup': str(HEALTH_BACKUP)}
    require(ITEM_CORE_BACKUP.is_file() and sha(ITEM_CORE_BACKUP) == '1845a3af837e6027498537c9944f6b8ffff1eef71d14923e129e93d0ee17ebb1', 'Reviewed item-core baseline missing or changed')
    selected[ITEM_CORE] = {'sourceBeforeSHA256': sha(ITEM_CORE_BACKUP), 'sourceBackup': str(ITEM_CORE_BACKUP)}
    return [{'path': rel, 'sha256': sha(inside(ROOT, rel)), **info} for rel, info in sorted(selected.items())]


def plan(records):
    results, conflicts = [], []
    for record in records:
        target = inside(LIVE, record['path'])
        local = sha(target) if target.is_file() else None
        before, current = record['sourceBeforeSHA256'], record['sha256']
        status = 'already-current' if local == current else ('new' if before is None and local is None
                 else 'baseline-match' if local == before and before is not None else 'conflict')
        row = {**record, 'previousLocalSHA256': local, 'status': status}
        results.append(row)
        if status == 'conflict':
            conflicts.append({'path': record['path'], 'reason': 'Installed file differs from source-before and proposed file',
                              'sourceBeforeSHA256': before, 'installedSHA256': local, 'proposedSHA256': current})
    scope = {r['path'] for r in records}
    for folder in NEW_DIRS:
        if (LIVE / folder).exists():
            for file in (LIVE / folder).rglob('*'):
                if file.is_file() and file.relative_to(LIVE).as_posix() not in scope:
                    conflicts.append({'path': file.relative_to(LIVE).as_posix(), 'reason': 'Unscoped installed file in new plugin; left untouched'})
    return {'createdUTC': dt.datetime.now(dt.timezone.utc).isoformat(), 'liveRoot': str(LIVE),
            'sourceRoot': str(ROOT), 'files': results, 'conflicts': conflicts, 'gameLaunched': False, 'installed': False}


def validate_evidence(records):
    require(EVIDENCE.is_file(), 'Run the final aggregate tests with --with-regression first')
    evidence = load(EVIDENCE)
    expected = {r['path']: r['sha256'] for r in records}
    require(evidence.get('success') is True and evidence.get('sourceHashes') == expected, 'Test evidence is stale or incomplete')
    audit_path = ROOT / 'docs/source-audit.json'
    require(evidence.get('auditSHA256') == sha(audit_path), 'Syntax audit differs from final test evidence')
    audit = load(audit_path)
    require(not audit['syntaxFailures'], 'Syntax audit has failures')
    audited = {e['path']: e['sha256'] for e in audit['entries']}
    for rel, digest in expected.items():
        require(audited.get(rel) == digest, 'Source audit is stale: ' + rel)
    tests = evidence.get('tests', [])
    require({t['script'] for t in tests} == set(TEST_FILES), 'Five required focused suites are not represented')
    for test in tests + [evidence.get('regression', {})]:
        require(test.get('exitCode') == 0 and test.get('log') and test.get('script'), 'Missing final test result')
        require(sha(inside(ROOT, test['script'])) == test['scriptSHA256'], 'Test script changed: ' + test['script'])
        log_path = inside(ROOT, test['log'])
        require(log_path.is_file() and sha(log_path) == test['logSHA256'], 'Final log missing or changed: ' + test['log'])
        require(test.get('docLog') and sha(inside(ROOT, test['docLog'])) == test['docLogSHA256'], 'Linked documentation log missing or changed')
    regression_text = inside(ROOT, evidence['regression']['log']).read_text(encoding='utf-8-sig')
    result = re.search(r'(\d+) regression suites passed\.', regression_text)
    require(result and int(result.group(1)) >= 424, 'Broad regression completion marker missing')
    return evidence


def verify_unchanged(records):
    for record in records:
        require(sha(inside(ROOT, record['path'])) == record['sha256'], 'Source changed during delivery: ' + record['path'])
        dst = inside(LIVE, record['path'])
        require((sha(dst) if dst.is_file() else None) == record['previousLocalSHA256'], 'Installed file changed since plan/backup: ' + record['path'])


def package(records):
    report = plan(records)
    write(ROOT / 'docs/restored-systems-deployment-plan.json', report)
    (ROOT / 'docs/restored-systems-file-list.txt').write_text('\n'.join(r['status'] + '  ' + r['path'] for r in report['files']) + '\n', encoding='utf8')
    require(not report['conflicts'], 'Installed baseline conflicts: see docs/restored-systems-deployment-plan.json')
    evidence = validate_evidence(records)
    guide_check = load(ROOT / 'docs/restored-systems-guide-validation.json')
    for link in guide_check['documents']:
        link['exists'] = inside(ROOT / 'docs', link['path']).is_file()
        require(link['exists'], 'Guide document link is missing: ' + link['path'])
    write(ROOT / 'docs/restored-systems-guide-validation.json', guide_check)
    for rel in DOCS:
        require((ROOT / rel).is_file(), 'Required delivery document missing: ' + rel)
    out = ARCHIVES / ('HL2RP-restored-systems-20261008-' + dt.datetime.now().strftime('%H%M%S-%f'))
    require(not out.exists(), 'Archive path already exists')
    out.mkdir(parents=True)
    staged = out / 'package'
    for record in report['files']:
        rel = record['path']
        target = inside(LIVE, rel)
        if target.is_file():
            backup = inside(out / 'local-backup', rel)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
            require(sha(backup) == record['previousLocalSHA256'], 'Live file changed while backing up: ' + rel)
        if record['sourceBackup']:
            backup = inside(out / 'source-backup', rel)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(record['sourceBackup'], backup)
            require(sha(backup) == record['sourceBeforeSHA256'], 'Source backup changed: ' + rel)
        destination = inside(staged / 'garrysmod/gamemodes', rel)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, destination)
        require(sha(destination) == record['sha256'], 'Staging hash mismatch: ' + rel)
    support = list(DOCS) + list(TEST_FILES) + ['tools/test-restored-systems.cjs', 'tools/deploy-restored-systems.py',
              'docs/restored-systems-validation.json', 'docs/source-audit.json']
    support += [t['log'] for t in evidence['tests']] + [evidence['regression']['log']]
    support += [t['docLog'] for t in evidence['tests']] + [evidence['regression']['docLog']]
    for rel in support:
        dst = inside(staged, rel)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, dst)
    (staged / 'README.md').write_text(
        '# Foundation: восстановленные системы\n\nОткройте docs/restored-systems-guide.html.\n\n'
        'В пакете только выбранные изменения: ремонт, мебель, Pose Studio, грузовые тележки и Quest Director. '
        'Тактическая карта, криминалистика и температура исключены.\n\n'
        'Локальная установка выполняется отдельно инструментом deploy-restored-systems.py --install <папка архива>. '
        'Он сверяет все исходные и установленные файлы с проверенными хэшами. '
        'Резервные копии исходников и прежней локальной установки находятся рядом с ZIP. '
        'Итог установки отражён в manifest.json рядом с ZIP и docs/restored-systems-deployment.json исходного проекта; '
        'манифест внутри ZIP описывает момент упаковки до установки. '
        'Инструменты/тесты в архиве — сопроводительные материалы, их запускают из полного исходного проекта.\n\n'
        'Офлайн-проверки пройдены; GMod/сервер не запускался. Реальные физика, графика, SQL и сеть требуют проверки.\n', encoding='utf8')
    manifest = {**report, 'archiveRoot': str(out), 'evidence': evidence, 'engineTested': False}
    write(staged / 'manifest.json', manifest)
    archive = out / 'Foundation-Restored-Systems.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipout:
        for file in sorted(staged.rglob('*')):
            if file.is_file(): zipout.write(file, file.relative_to(staged).as_posix())
    with zipfile.ZipFile(archive) as zipin:
        require(zipin.testzip() is None, 'ZIP CRC verification failed')
        for record in records:
            blob = zipin.read('garrysmod/gamemodes/' + record['path'])
            require(hashlib.sha256(blob).hexdigest() == record['sha256'], 'ZIP payload mismatch: ' + record['path'])
    verify_unchanged(report['files'])
    manifest.update(archive=str(archive), archiveSHA256=sha(archive))
    write(out / 'manifest.json', manifest)
    write(ROOT / 'docs/restored-systems-package.json', manifest)
    return {'packaged': True, 'installed': False, 'files': len(records), 'archive': str(archive), 'archiveRoot': str(out)}


def install(directory):
    out = Path(directory).resolve()
    require(out.is_relative_to(ARCHIVES.resolve()) and out.name.startswith('HL2RP-restored-systems-20261008-'), 'Unexpected archive root')
    manifest = load(out / 'manifest.json')
    require(manifest['liveRoot'] == str(LIVE) and manifest['sourceRoot'] == str(ROOT), 'Manifest belongs to another checkout/install')
    require(not manifest.get('installed'), 'Package already installed; inspect current hashes before retrying')
    records = manifest['files']
    require(not manifest['conflicts'], 'Package has unresolved installed changes')
    current = collect_scope()
    require({r['path']: r['sha256'] for r in current} == {r['path']: r['sha256'] for r in records}, 'Delivery scope changed since packaging')
    validate_evidence(current)
    require(not plan(current)['conflicts'], 'Installed files or extra plugin files changed since packaging')
    archive = out / 'Foundation-Restored-Systems.zip'
    require(sha(archive) == manifest['archiveSHA256'], 'ZIP changed after packaging')
    for record in records:
        staged = inside(out / 'package/garrysmod/gamemodes', record['path'])
        require(sha(staged) == record['sha256'], 'Staged file changed: ' + record['path'])
        if record['previousLocalSHA256'] is not None:
            require(sha(inside(out / 'local-backup', record['path'])) == record['previousLocalSHA256'], 'Backup changed: ' + record['path'])
    verify_unchanged(records)
    written = []
    try:
        for record in records:
            destination = inside(LIVE, record['path'])
            require((sha(destination) if destination.is_file() else None) == record['previousLocalSHA256'], 'Destination changed immediately before copy: ' + record['path'])
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_name(destination.name + '.restored-stage-' + str(os.getpid()))
            require(not temporary.exists(), 'Existing staging file requires inspection: ' + str(temporary))
            try:
                shutil.copy2(inside(out / 'package/garrysmod/gamemodes', record['path']), temporary)
                require(sha(temporary) == record['sha256'], 'Temporary hash mismatch: ' + record['path'])
                require((sha(destination) if destination.is_file() else None) == record['previousLocalSHA256'], 'Destination changed before atomic replacement: ' + record['path'])
                os.replace(temporary, destination)
                written.append(record)
            finally:
                if temporary.exists(): temporary.unlink()
            require(sha(destination) == record['sha256'], 'Installed hash mismatch: ' + record['path'])
    except Exception:
        # No recursive removal. Restore only exact files touched by this attempt.
        for record in reversed(written):
            destination = inside(LIVE, record['path'])
            if not destination.is_file() or sha(destination) != record['sha256']:
                print('Rollback preserved a concurrent external change: ' + record['path'], file=sys.stderr)
                continue
            if record['previousLocalSHA256'] is None:
                if destination.is_file(): destination.unlink()
            else: shutil.copy2(inside(out / 'local-backup', record['path']), destination)
        raise
    manifest.update(installed=True, installedUTC=dt.datetime.now(dt.timezone.utc).isoformat())
    write(out / 'manifest.json', manifest)
    write(ROOT / 'docs/restored-systems-deployment.json', manifest)
    return {'installed': True, 'files': len(records), 'archive': str(archive), 'backup': str(out / 'local-backup')}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--plan', action='store_true')
    group.add_argument('--scope-json', action='store_true', help='Read-only scoped source hashes for the test runner')
    group.add_argument('--package', action='store_true')
    group.add_argument('--install', metavar='ARCHIVE_DIRECTORY')
    args = parser.parse_args()
    if args.install:
        result = install(args.install)
    else:
        records = collect_scope()
        if args.scope_json:
            result = {r['path']: r['sha256'] for r in records}
        elif args.package:
            result = package(records)
        else:
            result = plan(records)
            write(ROOT / 'docs/restored-systems-deployment-plan.json', result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try: main()
    except (RuntimeError, OSError, KeyError, ValueError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
