"""Deploy the v7.7 hidden-site and map files with backups and a verified server ZIP."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
raw = (ROOT/'docs/hidden-sites-test-run.txt').read_bytes()
log = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
passed = re.search(r'(\d+) regression suites passed\.', log)
assert passed and int(passed.group(1)) >= 211
OUT = Path('E:/Codex-Archives')/('HL2RP-hidden-sites-v7.7-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
OUT.mkdir(parents=True, exist_ok=False)
PACKAGE, BACKUP = OUT/'package', OUT/'before-local'
files = ['ixhl2rp/plugins/foundation_network/cl_map.lua',
         'ixhl2rp/plugins/foundation_network/cl_network.lua',
         'ixhl2rp/plugins/foundation_network/sv_web.lua']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
records = []
for rel in files:
    src, destrel = (ROOT/rel).resolve(), Path('gamemodes')/rel
    target = (LIVE/destrel).resolve()
    assert src.is_relative_to(ROOT) and target.is_relative_to(LIVE)
    entry = next(e for e in audit['entries'] if e['path'] == rel)
    assert entry['sha256'] == sha(src), 'Syntax audit is stale'
    existed = target.exists()
    if existed:
        backup = BACKUP/destrel
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup)
        assert sha(target) == sha(backup)
    staged = PACKAGE/'garrysmod'/destrel
    staged.parent.mkdir(parents=True, exist_ok=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    shutil.copy2(src, target)
    assert sha(src) == sha(staged) == sha(target)
    records.append({'path':str(destrel).replace('\\','/'), 'sha256':sha(src), 'bytes':src.stat().st_size, 'previouslyExisted':existed})
shutil.copy2(ROOT/'docs/hidden-sites-v7.7.md', PACKAGE/'README.md')
manifest = {'localInstall':str(LIVE), 'backup':str(BACKUP), 'files':records,
            'tests':int(passed.group(1)), 'syntaxFiles':audit['files'], 'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
archive = OUT/'HL2RP-hidden-sites-v7.7.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in PACKAGE.rglob('*'):
        if p.is_file(): z.write(p,p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for record in records:
        assert hashlib.sha256(z.read('garrysmod/'+record['path'])).hexdigest() == record['sha256']
manifest.update(archive=str(archive),archiveSHA256=sha(archive))
(ROOT/'docs/hidden-sites-v7.7-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps({'files':len(records), 'archive':str(archive), 'backup':str(BACKUP), 'sha256':sha(archive)},indent=2))




