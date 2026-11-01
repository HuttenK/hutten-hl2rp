"""Ship only the two changed terminal server files, with backups and hash checks."""
from pathlib import Path
import hashlib, json, re, shutil, zipfile

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
out=Path((ROOT/'docs/terminal-roleplay-archive-path.txt').read_text().strip()).resolve()
assert out.is_relative_to(Path('E:/Codex-Archives').resolve()) and out.is_dir()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
files=['ixhl2rp/plugins/foundation_network/sv_catalog.lua','ixhl2rp/plugins/foundation_network/sv_web.lua']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited={entry['path']:entry['sha256'] for entry in audit['entries']}
for path in files: assert audited[path]==sha(ROOT/path),f'Stale audit: {path}'
raw=(ROOT/'docs/terminal-roleplay-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
passed=re.search(r'(\d+) regression suites passed\.',log)
assert passed and int(passed.group(1))>=232
archive=out/'HL2RP-terminal-roleplay.zip'
assert not archive.exists()
records=[]
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(ROOT/'docs/terminal-roleplay-update.md','README.md')
    for path in files:
        src=ROOT/path;relative=Path('gamemodes')/path;target=(LIVE/relative).resolve()
        assert target.is_relative_to(LIVE)
        if target.exists():
            old=out/'before-local'/relative;old.parent.mkdir(parents=True,exist_ok=True)
            assert not old.exists()
            shutil.copy2(target,old);assert sha(old)==sha(target)
        z.write(src,'garrysmod/'+relative.as_posix())
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
        assert sha(target)==sha(src)
        records.append(dict(path=relative.as_posix(),sha256=sha(src)))
    z.writestr('files.json',json.dumps(records,indent=2))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for row in records: assert hashlib.sha256(z.read('garrysmod/'+row['path'])).hexdigest()==row['sha256']
result=dict(archive=str(archive),sha256=sha(archive),files=records,localInstall=str(LIVE),
            tests=int(passed.group(1)),syntaxFiles=audit['files'],engineTested=False)
for path in (out/'deployment.json',ROOT/'docs/terminal-roleplay-deployment.json'):
    path.write_text(json.dumps(result,indent=2),encoding='utf8')
shutil.copy2(ROOT/'docs/terminal-roleplay-update.md',out/'README.md')
print(json.dumps(dict(archive=str(archive),sha256=sha(archive),files=len(records),bytes=archive.stat().st_size),indent=2))
