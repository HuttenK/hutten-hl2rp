"""Deploy the scoped terminal renderer after tests; preserve the verified baseline."""
from pathlib import Path
import hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
OUT = Path((ROOT/'docs/map3d-archive-path.txt').read_text(encoding='utf-8-sig').strip()).resolve()
assert OUT.is_relative_to(Path('E:/Codex-Archives').resolve()) and OUT.is_dir()
BACKUP = OUT/'local-backup'
PACKAGE = OUT/'package'
assert not PACKAGE.exists(), 'Package already exists; inspect deployment before rerunning'
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
log = (ROOT/'docs/map3d-regression.log').read_text(encoding='utf-8-sig')
passed = re.search(r'(\d+) regression suites passed\.', log)
assert passed and int(passed.group(1)) >= 320
audited = {e['path']: e['sha256'] for e in audit['entries']}

folder = 'ixhl2rp/plugins/foundation_network/'
previous = ['sh_plugin.lua', 'cl_map.lua', 'cl_network.lua']
for name in previous:
    before = BACKUP/'gamemodes'/folder/name
    target = LIVE/'gamemodes'/folder/name
    assert before.is_file() and sha(before) == sha(target), f'Runtime changed since backup: {target}'
assert not (LIVE/'gamemodes'/folder/'cl_map3d.lua').exists()
assert not (LIVE/'addons/foundation_map_renderer').exists()

# Stage and verify every file before changing the runtime. The plugin entrypoint
# is installed last, after all newly referenced client files are present.
files = [(p, p.relative_to(ROOT)) for p in sorted((ROOT/'addons/foundation_map_renderer').rglob('*')) if p.is_file()]
files += [(ROOT/folder/name, Path('gamemodes')/folder/name) for name in ['cl_map3d.lua','cl_map.lua','cl_network.lua','sh_plugin.lua']]
records = []
for src, rel in files:
    assert src.resolve().is_relative_to(ROOT)
    target = (LIVE/rel).resolve()
    assert target.is_relative_to(LIVE)
    digest = sha(src)
    if src.suffix == '.lua':
        assert audited.get(src.relative_to(ROOT).as_posix()) == digest, f'Stale audit: {src}'
    staged = PACKAGE/'garrysmod'/rel
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    assert sha(staged) == digest
    records.append({'path': rel.as_posix(), 'sha256': digest, 'bytes': src.stat().st_size, 'previouslyExisted': target.exists()})

shutil.copy2(ROOT/'docs/terminal-map3d-update.md', PACKAGE/'README.md')
manifest = {'localInstall':str(LIVE),'backup':str(BACKUP),'files':records,
            'tests':int(passed.group(1)),'syntaxFiles':audit['files'],'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
archive = OUT/'HL2RP-terminal-map3d.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(PACKAGE.rglob('*')):
        if p.is_file(): z.write(p,p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for record in records:
        assert hashlib.sha256(z.read('garrysmod/'+record['path'])).hexdigest() == record['sha256']

for record in records:
    target = LIVE/record['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACKAGE/'garrysmod'/record['path'], target)
    assert sha(target) == record['sha256']

manifest.update(archive=str(archive),archiveSHA256=sha(archive))
(ROOT/'docs/terminal-map3d-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps({'files':len(records),'archive':str(archive),'backup':str(BACKUP),'sha256':sha(archive)},indent=2))
