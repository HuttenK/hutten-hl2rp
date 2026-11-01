"""Deploy only this optimization batch, refusing to overwrite local divergence.

Default is read-only. --apply backs up, copies, hash-verifies and packages the
eleven runtime files. It never touches slides, Workshop addons, data or config.
"""
import argparse
import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r'C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\gamemodes')
BEFORE = Path(r'C:\Users\q1236\AppData\Local\Temp\ix-performance-batch1-20261018')
OUT = ROOT / 'docs/performance-audit'
FILES = [
    'helix/gamemode/game/items/sh_item.class.lua',
    'helix/entities/entities/ix_item.lua',
    'ixhl2rp/plugins/ammo_cringe/sh_arc9.lua',
    'ixhl2rp/plugins/proximity_voice/sv_filter.lua',
    'ixhl2rp/plugins/site_pda/cl_device.lua',
    'ixhl2rp/plugins/site_pda/sv_fieldlink.lua',
    'ixhl2rp/plugins/!healthsystem/cl_fx.lua',
    'ixhl2rp/plugins/medical/sv_treatment.lua',
    'ixhl2rp/plugins/gonews/entities/entities/ix_gonews_terminal.lua',
    'ixhl2rp/plugins/taskboard/entities/entities/ix_taskboard.lua',
    'ixhl2rp/plugins/performance_monitor/sh_plugin.lua',
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    rows = []
    for name in FILES:
        source, local, previous = ROOT/name, GAME/name, BEFORE/name
        assert source.is_file(), name
        before, after, installed = sha(previous), sha(source), sha(local)
        assert before is not None or 'performance_monitor/' in name, f'Missing original backup: {name}'
        state = 'current' if installed == after else 'ready' if installed == before else 'diverged'
        rows.append(dict(path=name, beforeSHA256=before, afterSHA256=after, localBeforeSHA256=installed, state=state))
    diverged = [row['path'] for row in rows if row['state'] == 'diverged']
    if diverged:
        raise SystemExit('Local changes must be merged before deployment: '+', '.join(diverged))
    if not args.apply:
        print(json.dumps({'mode':'check', 'files':len(rows), 'states':rows}, indent=2))
        return
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(os.environ['TEMP'])/('ix-performance-local-backup-'+stamp)
    backup.mkdir(exist_ok=False)
    for row in rows:
        name = row['path']
        destination = GAME/name
        if destination.is_file():
            saved = backup/name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, saved)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/name, destination)
        assert sha(destination) == row['afterSHA256'], name
    archive = OUT/'optimization-batch1-gamemodes.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as package:
        for name in FILES:
            package.write(ROOT/name, name)
        package.writestr('README-batch1.txt', 'Merge helix/ and ixhl2rp/ into the current server garrysmod/gamemodes folder.\n'
                          'This is a patch for the current gamemode, not a complete installation. Restart the server and reconnect clients.\n'
                          'Workshop content, saved data, config and slide files are not included or modified.\n'
                          'Server console: ix_perf_server 60. Client console: ix_perf_client 60. Reports: garrysmod/data/ix_performance/.\n')
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        for row in rows:
            assert hashlib.sha256(package.read(row['path'])).hexdigest() == row['afterSHA256']
    result = dict(batch=1,generatedUTC=stamp,localGame=str(GAME),backup=str(backup),archive=str(archive),
                  files=rows,verified=len(rows),remoteServerUpdated=False)
    (OUT/'batch1-delivery.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    patch = []
    for name in FILES:
        old = (BEFORE/name).read_text(encoding='utf-8').splitlines(True) if (BEFORE/name).exists() else []
        new = (ROOT/name).read_text(encoding='utf-8').splitlines(True)
        patch.extend(difflib.unified_diff(old,new,fromfile='before/'+name,tofile='after/'+name))
    (OUT/'batch1-runtime.patch').write_text(''.join(patch),encoding='utf-8')
    print(json.dumps({key:value for key,value in result.items() if key!='files'},indent=2))

if __name__ == '__main__':
    main()
