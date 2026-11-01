"""Deploy only the reviewed gamemode files; preserve and verify all addon files."""
from pathlib import Path
import hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
OUT = Path((ROOT/'docs/map-layers-archive-path.txt').read_text(encoding='utf-8-sig').strip()).resolve()
assert OUT.is_relative_to(Path('E:/Codex-Archives').resolve()) and OUT.is_dir()
BACKUP, PACKAGE = OUT/'local-backup', OUT/'package'
assert not PACKAGE.exists(), 'Inspect the existing package before rerunning deployment'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
protected = json.loads((OUT/'unchanged-addons-before.json').read_text(encoding='utf-8-sig'))
protected_roots = [Path('E:/map'), ROOT/'addons/foundation_map_renderer', LIVE/'addons/foundation_map_renderer']

def verify_addons():
    before = {str(Path(r['path']).resolve()).casefold():r['sha256'].lower() for r in protected}
    now = {str(p.resolve()).casefold():sha(p) for folder in protected_roots for p in folder.rglob('*') if p.is_file()}
    assert before == now, 'Protected addon content changed'

verify_addons()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited = {e['path']:e['sha256'] for e in audit['entries']}
log = (ROOT/'docs/map-layers-regression.log').read_text(encoding='utf-8-sig')
passed = re.search(r'(\d+) regression suites passed\.', log)
assert passed and int(passed.group(1)) >= 327

files = ['ixhl2rp/plugins/foundation_network/'+name for name in ['cl_map3d.lua','cl_map.lua','cl_network.lua','cl_surface.lua']]
files.append('ixhl2rp/plugins/tv_screen/cl_controls.lua')
records = []
for source_rel in files:
    src = ROOT/source_rel
    rel = Path('gamemodes')/source_rel
    target = (LIVE/rel).resolve()
    assert target.is_relative_to(LIVE/'gamemodes')
    assert sha(target) == sha(BACKUP/rel), 'Local file changed since backup: '+source_rel
    digest = sha(src)
    assert audited[source_rel] == digest, 'Syntax audit is stale'
    staged = PACKAGE/'garrysmod'/rel
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    assert sha(staged) == digest
    records.append({'path':rel.as_posix(), 'sha256':digest, 'bytes':src.stat().st_size})

shutil.copy2(ROOT/'docs/terminal-layers-tv-precision.md', PACKAGE/'README.md')
manifest = {'localInstall':str(LIVE), 'backup':str(BACKUP), 'files':records, 'nativeAddonRequired':True,
            'tests':int(passed.group(1)), 'syntaxFiles':audit['files'], 'engineTested':False, 'unchangedAddonFiles':len(protected)}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
archive = OUT/'HL2RP-terminal-layers-TV-precision.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for p in sorted(PACKAGE.rglob('*')):
        if p.is_file(): z.write(p, p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert not any('/addons/' in n for n in z.namelist())
    for r in records:
        assert hashlib.sha256(z.read('garrysmod/'+r['path'])).hexdigest() == r['sha256']

for r in records:
    target = LIVE/r['path']
    shutil.copy2(PACKAGE/'garrysmod'/r['path'], target)
    assert sha(target) == r['sha256']
verify_addons()
manifest.update(archive=str(archive), archiveSHA256=sha(archive))
(ROOT/'docs/terminal-layers-tv-deployment.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
print(json.dumps({'files':len(records), 'unchangedAddonFiles':len(protected), 'archive':str(archive), 'backup':str(BACKUP), 'sha256':sha(archive)}, indent=2))
