"""Package and deploy the TV preview correction, preserving prior local files."""
from pathlib import Path
import hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
OUT = Path((ROOT/'docs/tv-preview-archive-path.txt').read_text(encoding='utf-8-sig').strip()).resolve()
assert OUT.is_relative_to(Path('E:/Codex-Archives').resolve()) and OUT.is_dir()
PACKAGE = OUT/'package'
assert not PACKAGE.exists(), 'Inspect the existing package before rerunning deployment'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited = {e['path']:e['sha256'] for e in audit['entries']}
passed = re.search(r'(\d+) regression suites passed\.', (ROOT/'docs/tv-preview-regression.log').read_text(encoding='utf-8-sig'))
assert passed and int(passed.group(1)) >= 330

records = []
for name in ['cl_plugin.lua','cl_controls.lua','cl_preview.lua','sh_plugin.lua']:
    rel = Path('ixhl2rp/plugins/tv_screen')/name
    src, target, backup = ROOT/rel, LIVE/rel, OUT/'local-backup'/rel
    if name == 'cl_preview.lua':
        assert not target.exists(), 'New preview file already exists locally'
    else:
        assert sha(target) == sha(backup), 'Local file changed since backup: '+name
    digest = sha(src)
    assert audited[rel.as_posix()] == digest, 'Syntax audit is stale'
    staged = PACKAGE/'garrysmod/gamemodes'/rel
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    assert sha(staged) == digest
    records.append({'path':rel.as_posix(), 'sha256':digest, 'new':name=='cl_preview.lua'})

shutil.copy2(ROOT/'docs/tv-placement-preview-fix.md', PACKAGE/'README.md')
manifest = {'files':records, 'localInstall':str(LIVE), 'backup':str(OUT/'local-backup'),
            'tests':int(passed.group(1)), 'syntaxFiles':audit['files'], 'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
archive = OUT/'HL2RP-TV-placement-preview-fix.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for p in sorted(PACKAGE.rglob('*')):
        if p.is_file(): z.write(p, p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for r in records:
        assert hashlib.sha256(z.read('garrysmod/gamemodes/'+r['path'])).hexdigest() == r['sha256']
for r in records:
    target = LIVE/r['path']
    shutil.copy2(PACKAGE/'garrysmod/gamemodes'/r['path'], target)
    assert sha(target) == r['sha256']
manifest.update(archive=str(archive), archiveSHA256=sha(archive))
(ROOT/'docs/tv-preview-deployment.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
print(json.dumps({'files':len(records), 'archive':str(archive), 'backup':str(OUT/'local-backup'), 'sha256':sha(archive)}, indent=2))
