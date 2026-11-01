"""Package scoped admin-permission changes with verified local backups."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, zipfile

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
files=[
    'helix/gamemode/core/sh_commands.lua',
    'helix/gamemode/game/items/cl_spawn.items.lua',
    'helix/gamemode/game/items/sv_spawn.items.lua',
    'ixhl2rp/plugins/z_intro/sh_plugin.lua',
    'ixhl2rp/plugins/z_ending/sh_plugin.lua',
    'ixhl2rp/plugins/z_endingnotext/sh_plugin.lua',
    'ixhl2rp/plugins/status_display/sh_plugin.lua',
    'ixhl2rp/plugins/status_display/sv_status.lua',
    'ixhl2rp/plugins/status_display/cl_status.lua',
]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited={e['path']:e['sha256'] for e in audit['entries']}
for path in files: assert audited[path]==sha(ROOT/path),f'Stale syntax audit: {path}'
raw=(ROOT/'docs/admin-permissions-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
passed=re.search(r'(\d+) regression suites passed\.',log)
assert passed and int(passed.group(1))>=230
out=Path('E:/Codex-Archives')/('HL2RP-admin-permissions-corrected-20261002-'+datetime.datetime.now().strftime('%H%M%S'))
out.mkdir(parents=True,exist_ok=False)
archive=out/'HL2RP-admin-permissions-corrected.zip';backup=out/'before-local';records=[]
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(ROOT/'docs/admin-permissions-update.md','README.md')
    for path in files:
        src=ROOT/path;relative=Path('gamemodes')/path;target=(LIVE/relative).resolve()
        assert target.is_relative_to(LIVE)
        existed=target.exists()
        if existed:
            old=backup/relative;old.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(target,old);assert sha(old)==sha(target)
        z.write(src,'garrysmod/'+relative.as_posix())
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target);assert sha(src)==sha(target)
        records.append(dict(path=relative.as_posix(),sha256=sha(src),previouslyExisted=existed))
    z.writestr('files.json',json.dumps(records,indent=2))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for row in records: assert hashlib.sha256(z.read('garrysmod/'+row['path'])).hexdigest()==row['sha256']
result=dict(archive=str(archive),sha256=sha(archive),files=records,localInstall=str(LIVE),backup=str(backup),
            tests=int(passed.group(1)),syntaxFiles=audit['files'],engineTested=False)
for path in (out/'deployment.json',ROOT/'docs/admin-permissions-deployment.json'):
    path.write_text(json.dumps(result,indent=2),encoding='utf8')
shutil.copy2(ROOT/'docs/admin-permissions-update.md',out/'README.md')
print(json.dumps(dict(archive=str(archive),sha256=sha(archive),files=len(records),bytes=archive.stat().st_size,backup=str(backup)),indent=2))
