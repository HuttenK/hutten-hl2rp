"""Package and optionally deploy only this update, with a saved-baseline guard."""
import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = Path((ROOT / 'docs/facility-utilities-archive-path.txt').read_text().strip())
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
OUTPUT = ROOT.parent / 'HL2RP-Facility-Utilities-20261008.zip'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    args = argparse.ArgumentParser()
    args.add_argument('--deploy', action='store_true')
    deploy = args.parse_args().deploy
    before = ARCHIVE / 'source-backup'
    candidates = set()
    for name in ['facility_utilities', 'foundation_network', 'site_pda', 'blackout', 'proximity_voice']:
        candidates.update(p.relative_to(ROOT) for p in (ROOT / 'ixhl2rp/plugins' / name).rglob('*.lua'))
    candidates.update(Path('ixhl2rp/plugins/cctv') / name for name in ['cl_network.lua', 'sv_network.lua'])
    changed = sorted(p for p in candidates if not (before / p).exists() or digest(ROOT / p) != digest(before / p))
    audit = json.loads((ROOT / 'docs/source-audit.json').read_text(encoding='utf-8'))
    hashes = {v['path']: v for v in audit['entries']}
    manifest = []
    for relative in changed:
        source = ROOT / relative
        current_hash = digest(source)
        entry = hashes.get(relative.as_posix())
        if not entry or entry['syntax'] != 'pass' or entry['sha256'] != current_hash:
            raise RuntimeError(f'Source differs from passing syntax audit: {relative}')
        target, baseline = LIVE / relative, ARCHIVE / 'local-backup' / relative
        if target.exists() and (not baseline.exists() or digest(target) != digest(baseline)):
            # Rerunning after an already completed deploy is harmless.
            if digest(target) != current_hash:
                raise RuntimeError(f'Local file changed since backup; refusing overwrite: {target}')
        elif baseline.exists() and not target.exists():
            raise RuntimeError(f'Local baseline file disappeared: {target}')
        manifest.append({'path': relative.as_posix(), 'sha256': current_hash,
                         'previousLocalSha256': digest(baseline) if baseline.exists() else None})
    log = (ROOT / 'docs/facility-utilities-regression.log').read_text(encoding='utf-8-sig')
    if '379 regression suites passed.' not in log:
        raise RuntimeError('Missing complete regression pass')
    metadata = {'backup': str(ARCHIVE), 'live': str(LIVE), 'files': manifest,
                'validation': '379 mocked-engine suites; 2548 Lua files parsed; game not launched'}
    manifest_path = ROOT / 'docs/facility-utilities-manifest.json'
    manifest_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as package:
        for row in manifest:
            package.write(ROOT / row['path'], 'gamemodes/' + row['path'])
        package.write(ROOT / 'docs/facility-utilities.md', 'README-facility-utilities.md')
        package.write(manifest_path, 'manifest.json')
    with zipfile.ZipFile(OUTPUT) as package:
        if package.testzip() is not None:
            raise RuntimeError('ZIP integrity check failed')
        for row in manifest:
            if hashlib.sha256(package.read('gamemodes/' + row['path'])).hexdigest() != row['sha256']:
                raise RuntimeError('ZIP content differs from audited source')
    shutil.copy2(manifest_path, ARCHIVE / 'update-manifest.json')
    if deploy:
        for row in manifest:
            target = LIVE / row['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / row['path'], target)
        for row in manifest:
            if digest(LIVE / row['path']) != row['sha256']:
                raise RuntimeError(f'Copy verification failed: {row["path"]}')
        (ROOT / 'docs/facility-utilities-deployment.json').write_text(json.dumps({
            'verifiedFiles': len(manifest), 'zip': str(OUTPUT), 'zipSha256': digest(OUTPUT),
            'backup': str(ARCHIVE), 'target': str(LIVE), 'gameLaunched': False
        }, indent=2), encoding='utf-8')
    print(json.dumps({'files': len(manifest), 'zip': str(OUTPUT), 'zipSha256': digest(OUTPUT),
                      'deployedAndVerified': deploy, 'backup': str(ARCHIVE)}, indent=2))
    for row in manifest:
        print(row['path'])


if __name__ == '__main__':
    main()
