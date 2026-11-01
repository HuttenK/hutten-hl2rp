"""Deliver the single-file HUD clipping fix with a verified local backup."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
relative=Path('gamemodes/ixhl2rp/plugins/status_display/cl_status.lua')
source=ROOT/'ixhl2rp/plugins/status_display/cl_status.lua'
target=(LIVE/relative).resolve()
assert target.is_relative_to(LIVE) and target.is_file()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
assert next(e['sha256'] for e in audit['entries'] if e['path']==source.relative_to(ROOT).as_posix())==sha(source)
raw=(ROOT/'docs/status-hud-clipping-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
passed=re.search(r'(\d+) regression suites passed\.',log)
assert passed and int(passed.group(1))>=228
out=Path('E:/Codex-Archives')/('HL2RP-HUD-clipping-fix-20261002-'+datetime.datetime.now().strftime('%H%M%S'))
out.mkdir(parents=True,exist_ok=False)
backup=out/'before-local'/relative;backup.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(target,backup);assert sha(backup)==sha(target)
archive=out/'HL2RP-HUD-clipping-fix.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(source,'garrysmod/'+relative.as_posix())
    z.write(ROOT/'docs/status-hud-clipping-fix.md','README.md')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert hashlib.sha256(z.read('garrysmod/'+relative.as_posix())).hexdigest()==sha(source)
shutil.copy2(source,target);assert sha(target)==sha(source)
result=dict(archive=str(archive),sha256=sha(archive),sourceSHA256=sha(source),localInstall=str(target),backup=str(backup),
            tests=int(passed.group(1)),syntaxFiles=audit['files'],engineTested=False)
for path in (out/'deployment.json',ROOT/'docs/status-hud-clipping-deployment.json'):
    path.write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps(result,indent=2))
