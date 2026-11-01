"""Package and deploy the four-file TV playback fix with backup/hash checks."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
OUT = Path((ROOT/'docs/tv-world-playback-archive-path.txt').read_text(encoding='utf-8-sig').strip()).resolve()
assert OUT.is_relative_to(Path('E:/Codex-Archives').resolve()) and OUT.is_dir()
PACKAGE = OUT/'package'
ARCHIVE = OUT/'HL2RP-TV-world-playback-fix.zip'
assert not PACKAGE.exists() and not ARCHIVE.exists(), 'Inspect existing outputs before rerunning deployment'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited = {entry['path']: entry['sha256'] for entry in audit['entries']}
passed = re.search(r'(\d+) regression suites passed\.', (ROOT/'docs/tv-world-playback-regression.log').read_text(encoding='utf-8-sig'))
assert passed and int(passed.group(1)) >= 332

records = []
for name in ['cl_plugin.lua', 'cl_controls.lua', 'cl_preview.lua', 'sh_state.lua']:
    rel = Path('ixhl2rp/plugins/tv_screen')/name
    src, target, backup = ROOT/rel, LIVE/rel, OUT/'local-backup'/rel
    assert (OUT/'source-backup'/rel).is_file(), 'Source backup missing: '+name
    assert sha(target) == sha(backup), 'Local file changed since backup: '+name
    digest = sha(src)
    assert audited[rel.as_posix()] == digest, 'Syntax audit is stale: '+name
    records.append({'path': rel.as_posix(), 'sha256': digest, 'previousLocalSHA256': sha(backup)})

for record in records:
    staged = PACKAGE/'garrysmod/gamemodes'/record['path']
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT/record['path'], staged)
    assert sha(staged) == record['sha256']

shutil.copy2(ROOT/'docs/tv-world-playback-fix.md', PACKAGE/'README.md')
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

for record in records:
    target = LIVE/record['path']
    assert sha(target) == record['previousLocalSHA256'], 'Local file changed during packaging'
    shutil.copy2(PACKAGE/'garrysmod/gamemodes'/record['path'], target)
    assert sha(target) == record['sha256']

manifest.update(archive=str(ARCHIVE), archiveSHA256=sha(ARCHIVE))
(ROOT/'docs/tv-world-playback-deployment.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
print(json.dumps({'files': len(records), 'archive': str(ARCHIVE), 'backup': str(OUT/'local-backup'),
                  'tests': manifest['tests'], 'syntaxFiles': manifest['syntaxFiles'], 'sha256': sha(ARCHIVE)}, indent=2))
