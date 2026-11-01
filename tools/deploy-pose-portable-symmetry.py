"""Narrow Pose Studio update. Stage and install are separate explicit operations."""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
BASE = ROOT / '.runtime/pose-portable-symmetry-20261009'
ARCHIVES = Path('E:/Codex-Archives')
TAG = 'pose-portable-symmetry'
PRIVATE = LIVE.parent / 'data/helix/ixhl2rp/pose_studio.txt'
AUTHORS = ('after-portable-reference.json', 'after-live-symmetry.json')
BEFORE = ('before-portable-reference.json', 'before-live-symmetry.json')
HISTORY = ('restored-systems', 'bed-sleep', 'facility-upgrades', 'cctv-recognition-salute',
           'device-ui-redesign', 'bodycam-water-interactions', 'contextual-equipment-use',
           'equipment-model-actions', 'cart-entity-model', 'cart-client-init')
REVIEW = 'docs/pose-portable-symmetry-review.md'
TESTS = ('tools/test-pose-reference-loader.cjs', 'tools/test-pose-embedded-reference.cjs',
         'tools/test-pose-live-symmetry.cjs', 'tools/test-restored-pose-tools.cjs',
         'tools/test-animation-upgrades.cjs', 'tools/test.cjs')

def require(ok, message):
    if not ok: raise RuntimeError(message)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).is_file() else None

def load(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def now(): return dt.datetime.now(dt.timezone.utc).isoformat()
def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def inside(root, rel):
    target = (root / rel).resolve()
    require(not Path(rel).is_absolute() and target.is_relative_to(root.resolve()), 'Unsafe path: ' + rel)
    return target

def private_metadata():
    return {'path': str(PRIVATE), 'bytes': PRIVATE.stat().st_size if PRIVATE.exists() else None,
            'sha256': sha(PRIVATE), 'contentCopied': False, 'modifiedByDelivery': False}

def baseline():
    rows = {}
    for name in BEFORE:
        data = load(BASE / name)
        for row in data if isinstance(data, list) else data['files']:
            require(row['path'] not in rows, 'Duplicate baseline')
            rows[row['path']] = row
            if row.get('sha256'):
                require(sha(inside(BASE / 'before', row['path'])) == row['sha256'], 'Bad source backup: ' + row['path'])
    return rows

def authors():
    files = {}
    for name in AUTHORS:
        author = load(BASE / name)
        require(author['status'] == 'FROZEN', 'Unfrozen author')
        for row in author['files']:
            rel = row['path']
            require(rel not in files, 'Authors overlap: ' + rel)
            require(sha(inside(ROOT, rel)) == row['sha256'], 'Author file changed: ' + rel)
            files[rel] = row
    runtime = {r: v for r, v in files.items() if v.get('runtime')}
    require(len(runtime) == 7 and all(r.startswith('ixhl2rp/plugins/pose_studio/') and r.endswith('.lua') for r in runtime), 'Unexpected runtime scope')
    before = baseline()
    require(set(runtime) == {r for r in before if r.startswith('ixhl2rp/')}, 'Baseline runtime scope differs')
    return files, runtime

def previous(runtime, installed=False):
    latest, manifests = {}, []
    for tag in HISTORY:
        path = ROOT / ('docs/' + tag + '-deployment.json')
        data = load(path)
        require(data['installed'] and data['sourceRoot'] == str(ROOT) and data['liveRoot'] == str(LIVE), 'Bad previous delivery: ' + tag)
        require(sha(data['archive']) == data['archiveSHA256'], 'Historical archive changed: ' + tag)
        manifests.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path), 'archiveSHA256': data['archiveSHA256']})
        for row in data['files']:
            rel = row['path']
            if rel in latest:
                require(row.get('sourceBeforeSHA256', row.get('previousLocalSHA256')) == latest[rel]['sha256'], 'Broken previous chain: ' + rel)
            latest[rel] = row
    before = baseline()
    for rel, row in latest.items():
        source_expected = runtime.get(rel, row)['sha256']
        live_expected = runtime[rel]['sha256'] if installed and rel in runtime else row['sha256']
        if rel in runtime: require(before[rel]['sha256'] == row['sha256'], 'Prior source baseline differs: ' + rel)
        require(sha(inside(ROOT, rel)) == source_expected, 'Historical source drift: ' + rel)
        require(sha(inside(LIVE, rel)) == live_expected, 'Historical local drift: ' + rel)
    return {'verified': True, 'uniqueRuntimeFiles': len(latest), 'manifests': manifests}

def preserved():
    data = load(BASE / 'preserved-before.json')
    for rel, digest in data['reports'].items():
        require(sha(inside(ROOT, rel)) == digest, 'Historical report changed: ' + rel)
    for row in data['guides']:
        require(sha(row['path']) == row['sha256'], 'Guide changed unexpectedly: ' + row['path'])
    return {'reportsUnchanged': len(data['reports']), 'guidesUnchanged': len(data['guides'])}

def support_hashes():
    files, _ = authors()
    paths = {r for r, v in files.items() if not v.get('runtime')}
    paths.update('.runtime/pose-portable-symmetry-20261009/' + n for n in (*AUTHORS, *BEFORE, 'pose-data-before.json', 'preserved-before.json'))
    paths.update((REVIEW, 'docs/pose-portable-symmetry.md', 'tools/deploy-pose-portable-symmetry.py',
                  'tools/test-pose-portable-symmetry-delivery.cjs', 'tools/fixture.lua', 'tools/glua.cjs', 'tools/restored-test-runner.cjs'))
    # The broad runner imports suites and fixtures; bind all of their test dependencies.
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'tools').glob('*.cjs') if p.name.startswith('test'))
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'tools/fixtures').rglob('*') if p.is_file())
    require(all(inside(ROOT, rel).is_file() for rel in paths), 'Missing support file')
    return {rel: sha(inside(ROOT, rel)) for rel in sorted(paths)}

def plan(installed=False):
    _, runtime = authors()
    before = baseline()
    rows = []
    for rel in sorted(runtime):
        digest = before[rel].get('sha256')
        require(sha(inside(LIVE, rel)) == (runtime[rel]['sha256'] if installed else digest), 'Installed baseline conflict: ' + rel)
        rows.append({'path': rel, 'sha256': runtime[rel]['sha256'], 'sourceBeforeSHA256': digest,
                     'previousLocalSHA256': digest})
    return {'sourceRoot': str(ROOT), 'liveRoot': str(LIVE), 'files': rows, 'installed': False,
            'conflicts': [], 'previousRestoration': previous(runtime, installed), 'preserved': preserved(),
            'authorManifestHashes': {n: sha(BASE / n) for n in AUTHORS},
            'baselineHashes': {n: sha(BASE / n) for n in BEFORE}, 'privatePose': private_metadata()}

def prepare():
    require(not (BASE / 'preserved-before.json').exists(), 'Already prepared')
    _, runtime = authors()
    # Validate before taking any delivery snapshots.
    previous(runtime)
    for rel in runtime:
        require(sha(inside(LIVE, rel)) == baseline()[rel]['sha256'], 'Live baseline differs: ' + rel)
    write(BASE / 'pose-data-before.json', private_metadata())
    excluded = {r for r in authors()[0] if r.startswith('docs/')}
    reports = {p.relative_to(ROOT).as_posix(): sha(p) for p in (ROOT / 'docs').rglob('*')
               if p.is_file() and p.relative_to(ROOT).as_posix() not in excluded and not p.name.startswith(TAG)}
    guides = [ROOT / 'docs/restored-systems-guide.html', ROOT / 'docs/Foundation-Facilities-Guide.html',
              ROOT.parent / 'Foundation-Restored-Systems-Guide.html', ROOT.parent / 'Foundation-Facilities-Guide.html']
    write(BASE / 'preserved-before.json', {'reports': reports, 'guides': [{'path': str(p), 'sha256': sha(p)} for p in guides]})
    return plan()

def approved():
    review = (ROOT / REVIEW).read_text(encoding='utf-8-sig')
    require(re.search(r'^Status:\s*\*\*PASS\b[^\r\n]*\*\*', review, re.M) and 'CHANGES REQUESTED' not in review and 'PENDING' not in review, 'Review is not PASS')

def validate():
    approved()
    result = plan()
    evidence = load(ROOT / ('docs/' + TAG + '-validation.json'))
    require(evidence['success'] and evidence['supportHashes'] == support_hashes(), 'Validation support changed or failed')
    require(evidence['sourceHashes'] == {r['path']: r['sha256'] for r in result['files']}, 'Validation source changed')
    require(set(r['script'] for r in evidence['results']) == set(TESTS), 'Required checks missing')
    for r in evidence['results']:
        require(r['exitCode'] == 0 and r['scriptUnchanged'] and sha(ROOT / r['script']) == r['scriptSHA256'] and sha(ROOT / r['log']) == r['logSHA256'], 'Bad validation log')
    audit = ROOT / ('docs/' + TAG + '-source-audit.json')
    require(sha(audit) == evidence['auditSHA256'] and not load(audit)['syntaxFailures'], 'Bad syntax audit')
    return result, evidence

def verify_zip(archive, manifest):
    with zipfile.ZipFile(archive) as z:
        require(z.testzip() is None and len(z.namelist()) == len(set(z.namelist())), 'Bad ZIP CRC/duplicates')
        expected = {'garrysmod/gamemodes/' + r['path']: r['sha256'] for r in manifest['files']}
        expected.update(manifest['supportHashes'])
        require(set(z.namelist()) == set(expected) | {'manifest.json'}, 'Unexpected ZIP contents')
        for rel, digest in expected.items():
            require(hashlib.sha256(z.read(rel)).hexdigest() == digest, 'ZIP file differs: ' + rel)
            require(not rel.lower().endswith(('.mdl', '.vvd', '.phy', '.vtx', 'pose_studio.txt')), 'Prohibited content')

def package():
    manifest, evidence = validate()
    support = support_hashes()
    for rel in ['docs/' + TAG + '-validation.json', 'docs/' + TAG + '-source-audit.json'] + [r['log'] for r in evidence['results']]:
        support[rel] = sha(ROOT / rel)
    out = ARCHIVES / ('HL2RP-' + TAG + '-20261009-' + dt.datetime.now().strftime('%H%M%S-%f'))
    require(not out.exists(), 'Archive path exists')
    for row in manifest['files']:
        for source, target, digest in ((ROOT / row['path'], out / 'package/garrysmod/gamemodes' / row['path'], row['sha256']),
                                      (LIVE / row['path'], out / 'local-backup' / row['path'], row['previousLocalSHA256']),
                                      (BASE / 'before' / row['path'], out / 'source-backup' / row['path'], row['sourceBeforeSHA256'])):
            if digest is None: continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            require(sha(target) == digest, 'Stage/backup mismatch')
    for rel, digest in support.items():
        target = inside(out / 'package', rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        require(sha(target) == digest, 'Support changed during copy')
    manifest.update(createdUTC=now(), archiveRoot=str(out), supportHashes=support, evidence=evidence, engineTested=False, gameLaunched=False)
    write(out / 'package/manifest.json', manifest)
    archive = out / 'Foundation-Pose-Portable-Symmetry.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted((out / 'package').rglob('*')):
            if p.is_file(): z.write(p, p.relative_to(out / 'package').as_posix())
    verify_zip(archive, manifest)
    plan()
    manifest.update(archive=str(archive), archiveSHA256=sha(archive))
    write(out / 'manifest.json', manifest)
    write(ROOT / ('docs/' + TAG + '-package.json'), manifest)
    return {'staged': True, 'installed': False, 'runtimeFiles': len(manifest['files']), 'archiveRoot': str(out), 'archiveSHA256': sha(archive), 'supportFiles': len(support)}

def install(directory):
    out = Path(directory).resolve()
    require(out.is_relative_to(ARCHIVES.resolve()) and out.name.startswith('HL2RP-' + TAG + '-20261009-'), 'Invalid archive directory')
    manifest = load(out / 'manifest.json')
    current, _ = validate()
    require(not manifest['installed'] and manifest['files'] == current['files'], 'Already installed or changed scope')
    require(manifest['authorManifestHashes'] == current['authorManifestHashes'] and manifest['baselineHashes'] == current['baselineHashes'], 'Frozen manifests changed')
    require(sha(manifest['archive']) == manifest['archiveSHA256'], 'Archive changed')
    verify_zip(manifest['archive'], manifest)
    for rel, digest in manifest['supportHashes'].items():
        require(sha(ROOT / rel) == digest and sha(out / 'package' / rel) == digest, 'Support changed: ' + rel)
    for row in manifest['files']:
        for folder, digest in (('package/garrysmod/gamemodes', row['sha256']), ('local-backup', row['previousLocalSHA256']), ('source-backup', row['sourceBeforeSHA256'])):
            require(sha(out / folder / row['path']) == digest, 'Staged/backup content changed')
    written = []
    try:
        for row in manifest['files']:
            target = LIVE / row['path']
            require(sha(target) == row['previousLocalSHA256'], 'Live changed before copy')
            temp = target.with_name(target.name + '.pose-delivery-' + str(os.getpid()))
            require(not temp.exists(), 'Unexpected temporary file')
            try:
                shutil.copy2(out / 'package/garrysmod/gamemodes' / row['path'], temp)
                require(sha(temp) == row['sha256'] and sha(target) == row['previousLocalSHA256'], 'Concurrent write')
                os.replace(temp, target)
                written.append(row)
            finally:
                if temp.exists(): temp.unlink()
        final = plan(installed=True)
    except Exception:
        for row in reversed(written):
            target = LIVE / row['path']
            if sha(target) == row['sha256']: shutil.copy2(out / 'local-backup' / row['path'], target)
        raise
    verify = {'sourceStageZipInstalledMatch': True, 'runtimeFiles': len(manifest['files']), 'engineTested': False,
              'archiveSHA256': sha(manifest['archive']), 'previousRestoration': final['previousRestoration'], 'preserved': preserved(),
              'privatePose': {'before': load(BASE / 'pose-data-before.json'), 'after': private_metadata(),
                              'unchangedDuringDelivery': load(BASE / 'pose-data-before.json')['sha256'] == sha(PRIVATE), 'modifiedByDelivery': False}}
    manifest.update(installed=True, installedUTC=now(), finalVerification=verify)
    for p in (out / 'manifest.json', ROOT / ('docs/' + TAG + '-deployment.json')): write(p, manifest)
    for p in (out / 'final-verification.json', ROOT / ('docs/' + TAG + '-final-verification.json')): write(p, verify)
    return {'installed': True, 'runtimeFiles': len(manifest['files']), 'archiveRoot': str(out), 'verification': verify}

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    g = p.add_mutually_exclusive_group(required=True)
    for flag in ('prepare', 'plan', 'scope-json', 'support-json', 'package'): g.add_argument('--' + flag, action='store_true')
    g.add_argument('--install')
    a = p.parse_args()
    try:
        result = prepare() if a.prepare else plan() if a.plan else {r: v['sha256'] for r, v in authors()[1].items()} if a.scope_json else support_hashes() if a.support_json else package() if a.package else install(a.install)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (RuntimeError, OSError, KeyError, ValueError, zipfile.BadZipFile) as e:
        print('STOP: ' + str(e), file=sys.stderr)
        sys.exit(1)
