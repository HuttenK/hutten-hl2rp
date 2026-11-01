"""Back up scoped local files, deploy the terminal catalogue, and verify its ZIP."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures'], 'Fix syntax failures before deployment'
testbytes = (ROOT/'docs/catalog-test-run.txt').read_bytes()
testlog = testbytes.decode('utf-16' if testbytes.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
passed = re.search(r'(\d+) regression suites passed\.', testlog)
assert passed, 'A completed regression run is required'
OUT = Path('E:/Codex-Archives')/('HL2RP-terminal-catalog-v7-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
OUT.mkdir(parents=True, exist_ok=False)
PACKAGE = OUT/'package'
BACKUP = OUT/'before-local'
folders = ['ixhl2rp/plugins/foundation_network', 'addons/foundation_terminal_assets']
files = sorted(str(p.relative_to(ROOT)).replace('\\','/') for folder in folders for p in (ROOT/folder).rglob('*') if p.is_file())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
records = []
for rel in files:
    src = (ROOT/rel).resolve()
    assert src.is_relative_to(ROOT)
    destrel = Path(rel) if rel.startswith('addons/') else Path('gamemodes')/rel
    target = (LIVE/destrel).resolve()
    assert target.is_relative_to(LIVE)
    existed = target.exists()
    if existed:
        backup = BACKUP/destrel
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup)
    staged = PACKAGE/'garrysmod'/destrel
    staged.parent.mkdir(parents=True, exist_ok=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    shutil.copy2(src, target)
    assert sha(src) == sha(staged) == sha(target)
    records.append({'path':str(destrel).replace('\\','/'), 'sha256':sha(src), 'bytes':src.stat().st_size, 'previouslyExisted':existed})
shutil.copy2(ROOT/'docs/terminal-catalog-v7.md', PACKAGE/'README.md')
(PACKAGE/'artwork').mkdir()
for name in ['terminal-catalog-prompts.json','terminal-vhs-prompts.json']:
    shutil.copy2(ROOT/'artwork'/name, PACKAGE/'artwork'/name)
manifest = {'localInstall':str(LIVE), 'backup':str(BACKUP), 'files':records,
            'tests':int(passed.group(1)), 'syntaxFiles':audit['files'], 'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
archive = OUT/'HL2RP-terminal-catalog-v7.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in PACKAGE.rglob('*'):
        if p.is_file():
            z.write(p,p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for record in records:
        assert hashlib.sha256(z.read('garrysmod/'+record['path'])).hexdigest() == record['sha256']
manifest.update(archive=str(archive),archiveSHA256=sha(archive))
(ROOT/'docs/terminal-v7-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps({'files':len(records), 'archive':str(archive), 'backup':str(BACKUP), 'sha256':sha(archive)},indent=2))
