"""Package the terminal/HUD update and verify backed-up local installation."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited={e['path']:e['sha256'] for e in audit['entries']}
raw=(ROOT/'docs/public-terminal-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
passed=re.search(r'(\d+) regression suites passed\.',log)
assert passed and int(passed.group(1))>=228
files=[]
for name in ('foundation_network','status_display'):
    for src in sorted((ROOT/'ixhl2rp/plugins'/name).rglob('*.lua')):
        assert audited[src.relative_to(ROOT).as_posix()]==sha(src),f'Stale syntax audit: {src}'
        files.append((src,Path('gamemodes')/src.relative_to(ROOT)))
assert any(src.name=='ix_foundation_public_terminal.lua' for src,_ in files)
assert any(src.name=='sv_public.lua' for src,_ in files)
OUT=Path('E:/Codex-Archives')/('HL2RP-public-terminal-hud-20261002-'+datetime.datetime.now().strftime('%H%M%S'))
OUT.mkdir(parents=True,exist_ok=False)
backup=OUT/'before-local'
archive=OUT/'HL2RP-public-terminal-hud.zip'
records=[]
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(ROOT/'docs/foundation-public-terminal-update.md','README.md')
    for src,relative in files:
        dest=(LIVE/relative).resolve()
        assert dest.is_relative_to(LIVE)
        previous=dest.exists()
        if previous:
            old=backup/relative;old.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(dest,old);assert sha(old)==sha(dest)
        z.write(src,'garrysmod/'+relative.as_posix())
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
        digest=sha(src);assert sha(dest)==digest
        records.append(dict(path=relative.as_posix(),sha256=digest,bytes=src.stat().st_size,previouslyExisted=previous))
    z.writestr('files.json',json.dumps(records,indent=2))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for row in records:
        assert hashlib.sha256(z.read('garrysmod/'+row['path'])).hexdigest()==row['sha256']
manifest=dict(archive=str(archive),sha256=sha(archive),files=records,localInstall=str(LIVE),backup=str(backup),
              tests=int(passed.group(1)),syntaxFiles=audit['files'],engineTested=False)
for path in (OUT/'deployment.json',ROOT/'docs/public-terminal-deployment.json'):
    path.write_text(json.dumps(manifest,indent=2),encoding='utf8')
shutil.copy2(ROOT/'docs/foundation-public-terminal-update.md',OUT/'README.md')
print(json.dumps(dict(archive=str(archive),sha256=sha(archive),files=len(files),bytes=archive.stat().st_size,backup=str(backup)),indent=2))
