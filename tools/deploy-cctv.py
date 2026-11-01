"""Package and deploy CCTV with audited hashes and existing-file backups."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
OUT = Path((ROOT/'docs/cctv-archive-path.txt').read_text(encoding='utf-8-sig').strip()).resolve()
assert OUT.is_relative_to(Path('E:/Codex-Archives').resolve()) and OUT.is_dir()
PACKAGE = OUT/'package'
ARCHIVE = OUT/'HL2RP-CCTV.zip'
assert not PACKAGE.exists() and not ARCHIVE.exists(), 'Inspect existing outputs before rerunning deployment'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited = {entry['path']: entry['sha256'] for entry in audit['entries']}
passed = re.search(r'(\d+) regression suites passed\.', (ROOT/'docs/cctv-regression.log').read_text(encoding='utf-8-sig'))
assert passed and int(passed.group(1)) >= 352

new_files = sorted(path.relative_to(ROOT) for path in (ROOT/'ixhl2rp/plugins/cctv').rglob('*.lua'))
assert len(new_files) == 13
compatibility_files = [Path('ixhl2rp/plugins/tv_screen')/name for name in ['cl_render.lua', 'sv_plugin.lua']]
records = []
for rel in new_files + compatibility_files:
    src, target, backup = ROOT/rel, LIVE/rel, OUT/'local-backup'/rel
    if rel in new_files:
        assert not target.exists(), 'New CCTV file already exists locally: '+str(rel)
    else:
        assert (OUT/'source-backup'/rel).is_file(), 'Source backup missing: '+str(rel)
        assert sha(target) == sha(backup), 'Local file changed since backup: '+str(rel)
    digest = sha(src)
    assert audited[rel.as_posix()] == digest, 'Syntax audit is stale: '+str(rel)
    records.append({'path': rel.as_posix(), 'sha256': digest,
                    'previousLocalSHA256': sha(backup) if backup.exists() else None})

for record in records:
    staged = PACKAGE/'garrysmod/gamemodes'/record['path']
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT/record['path'], staged)
    assert sha(staged) == record['sha256']

shutil.copy2(ROOT/'docs/cctv-plugin.md', PACKAGE/'README.md')
manifest = {'files': records, 'localInstall': str(LIVE), 'backup': str(OUT/'local-backup'),
            'tests': int(passed.group(1)), 'syntaxFiles': audit['files'], 'engineTested': False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
with zipfile.ZipFile(ARCHIVE, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(PACKAGE.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(PACKAGE))
with zipfile.ZipFile(ARCHIVE) as archive:
    assert archive.testzip() is None
    for record in records:
        assert hashlib.sha256(archive.read('garrysmod/gamemodes/'+record['path'])).hexdigest() == record['sha256']

# Validate all destinations before making the first live change.
for record in records:
    target = LIVE/record['path']
    assert (sha(target) if target.exists() else None) == record['previousLocalSHA256'], 'Local file changed during packaging'
for record in records:
    target = LIVE/record['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACKAGE/'garrysmod/gamemodes'/record['path'], target)
    assert sha(target) == record['sha256']

manifest.update(archive=str(ARCHIVE), archiveSHA256=sha(ARCHIVE))
(ROOT/'docs/cctv-deployment.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
print(json.dumps({'files': len(records), 'archive': str(ARCHIVE), 'backup': str(OUT/'local-backup'),
                  'tests': manifest['tests'], 'syntaxFiles': manifest['syntaxFiles'], 'sha256': sha(ARCHIVE)}, indent=2))
