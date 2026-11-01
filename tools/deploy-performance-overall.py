"""Check, then --apply the performance changes with backups and hash verification.

Patches only runtime files that differ from this pass's recorded snapshot, plus
the previous batch's files. Refuses unrelated local divergence. No addon edits.
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
BEFORE = Path(r'C:\Users\q1236\AppData\Local\Temp\ix-performance-overall-20261018')
OUT = ROOT / 'docs/performance-audit'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    originals = json.loads((BEFORE/'manifest.json').read_text(encoding='utf-8'))
    current = {p.relative_to(ROOT).as_posix(): sha(p) for root in ('helix','ixhl2rp','addons')
               for p in (ROOT/root).rglob('*.lua')}
    removed = set(originals)-set(current)
    assert not removed, f'Unexpected removed runtime files: {removed}'
    changed = sorted(k for k,v in current.items() if originals.get(k)!=v)
    assert all(k.startswith(('helix/','ixhl2rp/')) for k in changed), 'Addon contents must stay unchanged'
    prior = json.loads((OUT/'batch1-delivery.json').read_text(encoding='utf-8'))
    prior_files = {row['path']: row for row in prior['files']}
    names = sorted(set(changed)|set(prior_files))
    rows = []
    for name in names:
        before, after, local = originals.get(name), current[name], sha(GAME/name)
        allowed = {before,after}
        if name in prior_files:
            allowed.update([prior_files[name]['beforeSHA256'], prior_files[name]['afterSHA256']])
        state = 'current' if local==after else 'ready' if local in allowed else 'diverged'
        rows.append(dict(path=name,pass2=name in changed,beforeSHA256=before,afterSHA256=after,
                         localBeforeSHA256=local,state=state))
    divergent = [r['path'] for r in rows if r['state']=='diverged']
    if divergent:
        raise SystemExit('Local changes require review before copying: '+', '.join(divergent))
    if not args.apply:
        print(json.dumps(dict(mode='check',pass2Files=len(changed),cumulativeFiles=len(rows),files=rows),indent=2))
        return
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(os.environ['TEMP'])/('ix-performance-overall-local-backup-'+stamp)
    backup.mkdir(exist_ok=False)
    for row in rows:
        name = row['path']; destination = GAME/name
        if destination.is_file():
            saved = backup/name; saved.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(destination,saved)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/name,destination)
        assert sha(destination)==row['afterSHA256'], name
    archive = OUT/'optimization-overall-gamemodes.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as package:
        for name in names: package.write(ROOT/name,name)
        package.writestr('README-performance.txt',
            'Cumulative performance patch: includes batch 1 and the overall pass.\n'
            'Merge helix/ and ixhl2rp/ into the current server garrysmod/gamemodes directory.\n'
            'This is a patch for the current gamemode, not a complete installation. Back up the server files first.\n'
            'Restart the server and reconnect clients. No Workshop addon update is needed for this patch.\n'
            'Normal ARC9 firearm and shotgun bullet travel physics are disabled automatically; explicit special projectiles remain.\n'
            'No data, config, slides or addon contents are included or overwritten.\n'
            'Server console: ix_perf_server 60. Client console: ix_perf_client 60. Reports: garrysmod/data/ix_performance/.\n'
            'Offline regression tests passed; live Linux tick time, latency and client rendering still require measurement.\n')
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        for row in rows:
            assert hashlib.sha256(package.read(row['path'])).hexdigest()==row['afterSHA256']
    patch=[]
    for name in changed:
        previous=BEFORE/name
        old=previous.read_text(encoding='utf-8').splitlines(True) if previous.exists() else []
        new=(ROOT/name).read_text(encoding='utf-8').splitlines(True)
        patch.extend(difflib.unified_diff(old,new,fromfile='before/'+name,tofile='after/'+name))
    (OUT/'overall-runtime.patch').write_text(''.join(patch),encoding='utf-8')
    result=dict(batch=2,generatedUTC=stamp,localGame=str(GAME),backup=str(backup),archive=str(archive),
                archiveSHA256=sha(archive),pass2Files=len(changed),verified=len(rows),files=rows,
                addonsUnchanged=True,remoteServerUpdated=False)
    (OUT/'overall-delivery.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))

if __name__=='__main__': main()
