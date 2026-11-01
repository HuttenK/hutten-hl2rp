"""Small scoped delivery wrapper; reuses the verified preceding delivery helpers.

No game writes without --install with an exact, already reviewed package directory.
The author baseline and all historical manifests remain immutable.
"""
from pathlib import Path
import argparse
import datetime as dt
import importlib.util
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TAG = 'equipment-model-actions'
spec = importlib.util.spec_from_file_location('prior_equipment_delivery', ROOT / 'tools/deploy-bodycam-water-interactions.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.BASE_DIR = ROOT / ('.runtime/' + TAG + '-20261009')
d.BASELINES = tuple(d.BASE_DIR / name for name in ('before-actions-beds.json', 'before-camera-models.json', 'before-cart-generator.json'))
d.FROZEN_SCOPE = d.BASE_DIR / 'frozen-scope.json'
d.PRIVATE_BASELINE = d.BASE_DIR / 'pose-data-before.json'
d.GUIDE_BASELINE = d.BASE_DIR / 'guide-before-manifest.json'
d.PREVIOUS += ((ROOT / 'docs/bodycam-water-interactions-deployment.json', 7), (ROOT / 'docs/contextual-equipment-use-deployment.json', 12))
d.EVIDENCE = ROOT / ('docs/' + TAG + '-validation.json')
CONFIG = d.BASE_DIR / 'delivery-config.json'


# New authors share a single immutable before/ directory, unlike older deliveries.
_read_baseline_rows = d.read_baseline_rows
def read_baseline_rows():
    return {rel: (row, d.BASE_DIR / 'before') for rel, (row, _) in _read_baseline_rows().items()}
d.read_baseline_rows = read_baseline_rows

def previous_manifest():
    files, manifests = {}, []
    for path, count in d.PREVIOUS:
        previous = d.load(path)
        d.require(previous.get('installed') is True and len(previous['files']) == count,
                  'Previous installed manifest is incomplete: ' + str(path))
        d.require(previous['liveRoot'] == str(d.LIVE) and previous['sourceRoot'] == str(ROOT), 'Previous roots differ')
        d.require(d.load(Path(previous['archiveRoot']) / 'manifest.json') == previous, 'Historical manifest changed')
        d.require(d.file_hash(Path(previous['archive'])) == previous['archiveSHA256'], 'Historical ZIP changed')
        manifests.append({'path': str(path), 'sha256': d.sha(path), 'archiveSHA256': previous['archiveSHA256'], 'count': count})
        for row in previous['files']:
            if row['path'] in files:
                d.require(row.get('sourceBeforeSHA256') == files[row['path']]['sha256'], 'Historical superseding baseline differs')
            files[row['path']] = row
    d.require(len(files) == 120, 'Historical unique file count differs')
    return {'files': list(files.values()), 'manifests': manifests}
d.previous_manifest = previous_manifest

AUTHOR_MANIFESTS = tuple(d.BASE_DIR / name for name in (
    'after-actions-beds.json', 'after-camera-models.json', 'cart-generator-final-manifest.json'))
def verify_authors():
    runtime = {}
    for path in AUTHOR_MANIFESTS:
        author = d.load(path)
        d.require(Path(author['root']).resolve() == ROOT.resolve(), 'Author freeze belongs to another checkout')
        for row in author['files']:
            rel = row['path']
            d.require(d.file_hash(d.inside(ROOT, rel)) == row['sha256'], 'Author freeze changed: ' + rel)
            if row.get('runtime'):
                d.require(rel not in runtime, 'Authors overlap: ' + rel)
                runtime[rel] = row['sha256']
    d.require(len(runtime) == 30 and sorted(runtime) == d.runtime_paths(d.read_baseline_rows()), 'Author runtime scope differs')
    return runtime

_freeze_scope, _collect_scope = d.freeze_scope, d.collect_scope
def freeze_scope():
    verify_authors()
    return _freeze_scope()
def collect_scope():
    verify_authors()
    return _collect_scope()
d.freeze_scope, d.collect_scope = freeze_scope, collect_scope


def private_data_check():
    """Observe user-owned saves; an intervening game save never authorizes restoring it."""
    baseline = d.load(d.PRIVATE_BASELINE)
    d.require(Path(baseline['path']).resolve() == d.PRIVATE_DATA.resolve() and baseline['contentCopied'] is False,
              'Saved-pose metadata baseline is invalid')
    return {'path': str(d.PRIVATE_DATA), 'sha256': d.file_hash(d.PRIVATE_DATA),
            'bytes': d.PRIVATE_DATA.stat().st_size if d.PRIVATE_DATA.exists() else None,
            'contentCopied': False, 'modifiedByDelivery': False,
            'unchangedFromStart': d.file_hash(d.PRIVATE_DATA) == baseline['sha256']}


d.private_data_check = private_data_check


def config():
    value = d.load(CONFIG)
    d.require(value['tests'] and value['review'], 'Final author tests and review are required')
    for rel in value['tests'] + value.get('support', []) + [value['review']]:
        d.require(d.inside(ROOT, rel).is_file(), 'Missing delivery support: ' + rel)
    return value


def support_hashes():
    paths = set(config()['tests']) | set(config().get('support', [])) | {
        'tools/deploy-equipment-model-actions.py', 'tools/deploy-bodycam-water-interactions.py',
        'tools/deploy-device-ui-redesign.py', 'tools/glua.cjs', 'tools/fixture.lua',
        'tools/restored-test-runner.cjs', 'tools/test.cjs',
        '.runtime/equipment-model-actions-20261009/delivery-config.json'}
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'tools/fixtures').rglob('*') if p.is_file())
    # The broad runner imports sibling suites; bind those too, not only entrypoints.
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'tools').glob('*.cjs')
                 if p.name.startswith(('test-', 'preview-')))
    return {rel: d.sha(d.inside(ROOT, rel)) for rel in sorted(paths)}


def validate_guides():
    d.guide_backups_check()
    results = []
    for source, desktop in d.guide_pairs():
        parser = d.GuideParser()
        parser.feed(source.read_text(encoding='utf-8-sig'))
        d.require(len(parser.ids) == len(set(parser.ids)) and set(parser.anchors).issubset(parser.ids),
                  'Guide IDs or anchors are invalid: ' + source.name)
        d.require(d.sha(source) == d.sha(desktop), 'Desktop guide differs: ' + source.name)
        for rel in parser.documents:
            d.require(d.inside(ROOT / 'docs', rel).is_file(), 'Guide document missing: ' + rel)
        results.append({'path': source.relative_to(ROOT).as_posix(), 'sha256': d.sha(source),
                        'desktopIdentical': True, 'browserTested': False})
    return results


def validate_evidence(records):
    evidence = d.load(d.EVIDENCE)
    d.require(evidence['success'] and evidence['sourceHashes'] == d.evidence_hashes(records), 'Stale or failing final evidence')
    d.require(evidence['supportHashes'] == support_hashes(), 'Test support changed after validation')
    prior = d.load(d.BASE_DIR / 'prior-evidence-before.json')
    d.require(all(d.file_hash(d.inside(ROOT, rel)) == digest for rel, digest in prior.items()), 'Historical evidence changed')
    for result in evidence['results']:
        d.require(result['exitCode'] == 0 and result['scriptUnchanged']
                  and d.sha(d.inside(ROOT, result['script'])) == result['scriptSHA256']
                  and d.sha(d.inside(ROOT, result['log'])) == result['logSHA256'], 'Test script or log differs or failed')
    expected = set(config()['tests']) | {'tools/test.cjs', 'tools/test-equipment-model-actions-deploy.py'}
    d.require(expected.issubset({r['script'] for r in evidence['results']}), 'Required test results missing')
    audit = d.load(ROOT / ('docs/' + TAG + '-source-audit.json'))
    d.require(not audit['syntaxFailures'], 'Syntax errors remain')
    entries = {entry['path']: entry['sha256'] for entry in audit['entries']}
    d.require(all(entries.get(rel) == digest for rel, digest in d.evidence_hashes(records).items()), 'Source audit is stale')
    review = d.inside(ROOT, config()['review']).read_text(encoding='utf-8-sig')
    d.require(re.search(r'^Status:\s*\*\*PASS\b[^\r\n]*\*\*', review, re.M)
              and 'PENDING' not in review and 'CHANGES REQUESTED' not in review, 'Independent review is not approved')
    return evidence


def package():
    records = d.collect_scope()
    report = d.plan(records)
    d.require(not report['conflicts'], 'Source or installed baseline conflict')
    evidence, guides = validate_evidence(records), validate_guides()
    support = set(support_hashes()) | set(config().get('support', [])) | {config()['review'],
        d.EVIDENCE.relative_to(ROOT).as_posix(), 'docs/' + TAG + '-source-audit.json',
        'docs/restored-systems-guide.html', 'docs/Foundation-Facilities-Guide.html'}
    support.update(row['log'] for row in evidence['results'])
    support.update(path.relative_to(ROOT).as_posix() for path in (*d.BASELINES, d.FROZEN_SCOPE, d.PRIVATE_BASELINE, d.GUIDE_BASELINE, d.BASE_DIR / 'prior-evidence-before.json'))
    support.update(path.relative_to(ROOT).as_posix() for path, _ in d.PREVIOUS)
    support.update(Path(row['backup']).relative_to(ROOT).as_posix() for row in d.guide_backups_check())
    hashes = {rel: d.sha(d.inside(ROOT, rel)) for rel in sorted(support)}
    out = d.ARCHIVES / ('HL2RP-' + TAG + '-20261009-' + dt.datetime.now().strftime('%H%M%S-%f'))
    d.require(not out.exists(), 'Archive already exists')
    for row in report['files']:
        for origin, target, digest in (
            (d.inside(ROOT, row['path']), d.inside(out / 'package/garrysmod/gamemodes', row['path']), row['sha256']),
            (d.inside(d.LIVE, row['path']), d.inside(out / 'local-backup', row['path']), row['previousLocalSHA256']),
            (Path(row['sourceBackup']) if row['sourceBackup'] else None, d.inside(out / 'source-backup', row['path']), row['sourceBeforeSHA256'])):
            if digest is None: continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origin, target)
            d.require(d.sha(target) == digest, 'Backup or staging changed: ' + row['path'])
    for rel, digest in hashes.items():
        target = d.inside(out / 'package', rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(d.inside(ROOT, rel), target)
        d.require(d.sha(target) == digest, 'Support changed while staging: ' + rel)
    manifest = {**report, 'archiveRoot': str(out), 'supportHashes': hashes, 'evidence': evidence, 'guides': guides, 'engineTested': False}
    d.write(out / 'local-backup/before-manifest.json', {'liveRoot': str(d.LIVE), 'files': [
        {'path': row['path'], 'existed': row['previousLocalSHA256'] is not None, 'sha256': row['previousLocalSHA256']} for row in report['files']]})
    d.write(out / 'package/manifest.json', manifest)
    archive = out / 'Foundation-Equipment-Models-Actions.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
        for path in sorted((out / 'package').rglob('*')):
            if path.is_file(): output.write(path, path.relative_to(out / 'package').as_posix())
    d.verify_zip(archive, records, hashes)
    d.verify_unchanged(report['files'])
    manifest.update(archive=str(archive), archiveSHA256=d.sha(archive))
    d.write(out / 'manifest.json', manifest)
    d.write(ROOT / ('docs/' + TAG + '-package.json'), manifest)
    return {'packaged': True, 'installed': False, 'files': len(records), 'archiveRoot': str(out), 'archiveSHA256': manifest['archiveSHA256']}


def install(directory):
    out = Path(directory).resolve()
    d.require(out.is_relative_to(d.ARCHIVES.resolve()) and out.name.startswith('HL2RP-' + TAG + '-20261009-'), 'Unexpected archive directory')
    manifest, records = d.load(out / 'manifest.json'), d.collect_scope()
    d.require(not manifest['installed'] and not manifest['conflicts'], 'Package was installed or has conflicts')
    d.require(manifest['sourceRoot'] == str(ROOT) and manifest['liveRoot'] == str(d.LIVE), 'Package roots differ')
    d.require({r['path']: r['sha256'] for r in records} == {r['path']: r['sha256'] for r in manifest['files']}, 'Reviewed scope changed')
    d.require(manifest['baselineHashes'] == d.baseline_hashes() and manifest['frozenScopeSHA256'] == d.sha(d.FROZEN_SCOPE), 'Frozen baseline changed')
    validate_evidence(records)
    validate_guides()
    archive = Path(manifest['archive'])
    d.require(archive.parent.resolve() == out and d.sha(archive) == manifest['archiveSHA256'], 'Archive differs')
    d.verify_zip(archive, records, manifest['supportHashes'])
    for rel, digest in manifest['supportHashes'].items():
        d.require(d.sha(d.inside(ROOT, rel)) == digest and d.sha(d.inside(out / 'package', rel)) == digest, 'Support differs: ' + rel)
    for row in manifest['files']:
        for parent, digest in ((out / 'package/garrysmod/gamemodes', row['sha256']), (out / 'local-backup', row['previousLocalSHA256']), (out / 'source-backup', row['sourceBeforeSHA256'])):
            if digest is not None: d.require(d.file_hash(d.inside(parent, row['path'])) == digest, 'Staging or backup differs: ' + row['path'])
    d.verify_unchanged(manifest['files'])
    written = []
    try:
        for row in manifest['files']:
            target = d.inside(d.LIVE, row['path'])
            d.require(d.file_hash(target) == row['previousLocalSHA256'], 'Live file changed before copy')
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_name(target.name + '.equipment-models-stage-' + str(os.getpid()))
            d.require(not temp.exists(), 'Staging file already exists')
            try:
                shutil.copy2(d.inside(out / 'package/garrysmod/gamemodes', row['path']), temp)
                d.require(d.sha(temp) == row['sha256'] and d.file_hash(target) == row['previousLocalSHA256'], 'File changed during copy')
                os.replace(temp, target)
                written.append(row)
            finally:
                if temp.exists(): temp.unlink()
        previous = d.previous_check(records, installed=True)
        d.require(previous['verified'], 'Previous installation changed during update')
        d.require(all(d.file_hash(d.inside(d.LIVE, row['path'])) == row['sha256'] for row in records), 'Final installed hash mismatch')
    except Exception:
        for row in reversed(written):
            target = d.inside(d.LIVE, row['path'])
            if d.file_hash(target) != row['sha256']: continue
            if row['previousLocalSHA256'] is None: target.unlink()
            else: shutil.copy2(d.inside(out / 'local-backup', row['path']), target)
        raise
    verification = {'runtimeFiles': len(records), 'sourceStageZipInstalledMatch': True, 'archiveSHA256': d.sha(archive),
                    'previousRestoration': previous, 'privateData': private_data_check(), 'engineTested': False}
    manifest.update(installed=True, installedUTC=d.now(), finalVerification=verification)
    for path in (out / 'manifest.json', ROOT / ('docs/' + TAG + '-deployment.json')): d.write(path, manifest)
    for path in (out / 'final-verification.json', ROOT / ('docs/' + TAG + '-final-verification.json')): d.write(path, verification)
    return {'installed': True, 'files': len(records), 'archiveRoot': str(out)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    for flag in ('freeze-scope', 'scope-json', 'support-json', 'plan', 'validate-guide', 'package'): group.add_argument('--' + flag, action='store_true')
    group.add_argument('--install')
    args = parser.parse_args()
    try:
        result = (d.freeze_scope() if args.freeze_scope else d.evidence_hashes(d.collect_scope()) if args.scope_json else
                  support_hashes() if args.support_json else d.plan(d.collect_scope()) if args.plan else
                  validate_guides() if args.validate_guide else package() if args.package else install(args.install))
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (RuntimeError, OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
