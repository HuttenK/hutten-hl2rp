"""Cumulative utilities package; guarded deployment of the entity follow-up only."""
import argparse
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = Path((ROOT / 'docs/facility-entities-archive-path.txt').read_text().strip())
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
OUTPUT = ROOT.parent / 'HL2RP-Facility-Utilities-Entities-20261008.zip'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--deploy', action='store_true')
    args = parser.parse_args()
    baseline = ARCHIVE / 'source-backup'
    candidates = [p.relative_to(ROOT) for name in ['facility_utilities', 'foundation_network']
                  for p in (ROOT / 'ixhl2rp/plugins' / name).rglob('*.lua')]
    changed = sorted(p for p in candidates if not (baseline / p).exists() or sha(ROOT / p) != sha(baseline / p))
    previous = json.loads((ROOT / 'docs/facility-utilities-manifest.json').read_text(encoding='utf-8'))
    package_paths = sorted({Path(row['path']) for row in previous['files']} | set(changed))
    audit = json.loads((ROOT / 'docs/source-audit.json').read_text(encoding='utf-8'))
    audited = {row['path']: row for row in audit['entries']}
    log = (ROOT / 'docs/facility-entities-regression.log').read_text(encoding='utf-8-sig')
    passed = re.search(r'(\d+) regression suites passed\.', log)
    if not passed or int(passed.group(1)) < 382:
        raise RuntimeError('Complete regression result missing')
    entries = []
    for relative in package_paths:
        source, target = ROOT / relative, LIVE / relative
        checksum = sha(source)
        result = audited.get(relative.as_posix())
        if not result or result['syntax'] != 'pass' or result['sha256'] != checksum:
            raise RuntimeError(f'File changed since successful syntax audit: {relative}')
        old = ARCHIVE / 'local-backup' / relative
        if relative in changed:
            if target.exists() and sha(target) != checksum and (not old.exists() or sha(target) != sha(old)):
                raise RuntimeError(f'Local file differs from saved baseline: {relative}')
            if old.exists() and not target.exists():
                raise RuntimeError(f'Baseline file disappeared: {relative}')
        elif not target.exists() or sha(target) != checksum:
            raise RuntimeError(f'Unrelated local/source difference: {relative}')
        entries.append({'path': relative.as_posix(), 'sha256': checksum, 'deploy': relative in changed,
                        'previousLocalSha256': sha(old) if old.exists() else None})
    metadata = {'backup': str(ARCHIVE), 'previousBackup': previous['backup'], 'target': str(LIVE),
                'files': entries, 'regressionSuites': int(passed.group(1)), 'syntaxFiles': audit['files'],
                'gameLaunched': False}
    manifest = ROOT / 'docs/facility-entities-manifest.json'
    manifest.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as package:
        for entry in entries:
            package.write(ROOT / entry['path'], 'gamemodes/' + entry['path'])
        package.write(manifest, 'manifest.json')
        package.write(ROOT / 'docs/facility-utilities.md', 'README-facility-utilities.md')
    with zipfile.ZipFile(OUTPUT) as package:
        assert package.testzip() is None
        for entry in entries:
            assert hashlib.sha256(package.read('gamemodes/' + entry['path'])).hexdigest() == entry['sha256']
    shutil.copy2(manifest, ARCHIVE / 'update-manifest.json')
    if args.deploy:
        for relative in changed:
            target = LIVE / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        for entry in entries:
            if sha(LIVE / entry['path']) != entry['sha256']:
                raise RuntimeError(f'Deployment verification failed: {entry["path"]}')
    report = {'copiedFiles': len(changed), 'verifiedPackageFiles': len(entries), 'zip': str(OUTPUT),
              'zipSha256': sha(OUTPUT), 'backup': str(ARCHIVE), 'deployed': args.deploy,
              'regressionSuites': int(passed.group(1)), 'syntaxFiles': audit['files'], 'gameLaunched': False}
    if args.deploy:
        (ROOT / 'docs/facility-entities-deployment.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    for relative in changed:
        print(relative.as_posix())


if __name__ == '__main__':
    main()
