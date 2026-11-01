"""Check the cumulative performance patch; --apply backs up, deploys and verifies it.

Only snapshot-different gamemode Lua and prior performance-delivery files qualify.
No addon, data, database, configuration or asset files are copied.
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
BEFORE = Path(r'C:\Users\q1236\AppData\Local\Temp\ix-performance-next-20261018')
OUT = ROOT / 'docs/performance-audit'
README = '''Cumulative performance patch: earlier batches plus the next optimization pass.
This is a patch for the current gamemode, not a complete installation.

DEPLOYMENT AND PERSISTENCE
Stop the server before deployment. Back up garrysmod/gamemodes/, garrysmod/data/,
and the server's garrysmod/sv.db with any sv.db-wal and sv.db-shm companions.
A live copy of just sv.db is not a consistent SQLite backup.
Merge helix/ and ixhl2rp/ into garrysmod/gamemodes/. Restart and reconnect clients.
Do NOT copy a developer PC's sv.db or data folder onto the live server.
The new record helper must be deployed together with all changed plugins.
CCTV, facility utilities, Foundation records and world placements migrate into
the server's local sv.db, even if character storage uses MySQL. The old JSON
files remain as pre-migration backups and become stale after subsequent edits.
Rollback requires a current legacy-format export or a consistent full checkpoint;
old JSON alone loses post-migration edits. Restoring an old whole sv.db also
rolls back other SQLite data. Keep normal consistent SQLite backups thereafter.

DEFAULTS AND CHECKS
Ordinary ARC9 bullets are hitscan; penetration and ricochets are disabled.
Explicit special projectiles retain their original behavior.
ARC9 indoor classification uses optimized mode 0; shot audio remains enabled.
Server/superadmin: ix_arc9_sound_mode baseline (A/B), optimized (restore).
Client: ix_render_budget_status; ix_render_budget_arms 0 for arm-only A/B;
ix_render_budget 0 disables the new distance presentation budget (1 restores).
Server console: ix_perf_server 60. Client console: ix_perf_client 60.
Captures are local in garrysmod/data/ix_performance/. Profiling adds overhead.
Test persistence across a clean restart, camera access, moved/blocked cables,
source depletion, remote poses and wall firing before a populated session.
Offline tests do not measure live Linux tick time, latency or visual quality.
No data, database, config, slides or addon contents are included or overwritten.
'''

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def runtime_hashes():
    return {p.relative_to(ROOT).as_posix(): sha(p)
            for root in ('helix', 'ixhl2rp', 'addons') for p in (ROOT / root).rglob('*.lua')}

def plan():
    originals = json.loads((BEFORE / 'manifest.json').read_text(encoding='utf-8-sig'))
    current = runtime_hashes()
    removed = sorted(set(originals) - set(current))
    if removed:
        raise RuntimeError('Unexpected removed runtime files: ' + ', '.join(removed))
    changed = sorted(k for k, value in current.items() if originals.get(k) != value)
    if any(not k.startswith(('helix/', 'ixhl2rp/')) for k in changed):
        raise RuntimeError('Addon Lua differs from the pass snapshot; refusing delivery')
    prior = json.loads((OUT / 'overall-delivery.json').read_text(encoding='utf-8-sig'))
    prior_files = {row['path']: row for row in prior['files']}
    rows = []
    for name in sorted(set(changed) | set(prior_files)):
        if not name.startswith(('helix/', 'ixhl2rp/')) or not name.endswith('.lua'):
            raise RuntimeError('Unexpected patch target: ' + name)
        destination = GAME / name
        destination.resolve().relative_to(GAME.resolve())
        (ROOT / name).resolve().relative_to(ROOT.resolve())
        before, after, local = originals.get(name), current[name], sha(destination)
        allowed = {before, after}
        if name in prior_files:
            allowed.update(prior_files[name].get(k) for k in ('beforeSHA256', 'afterSHA256'))
        state = 'current' if local == after else 'ready' if local in allowed else 'diverged'
        rows.append(dict(path=name, nextPass=name in changed, beforeSHA256=before,
                         afterSHA256=after, localBeforeSHA256=local, state=state))
    divergent = [row['path'] for row in rows if row['state'] == 'diverged']
    if divergent:
        raise RuntimeError('Local changes require review before copying: ' + ', '.join(divergent))
    return originals, current, changed, rows

def require_verification(current):
    result = json.loads((OUT / 'next-verification.json').read_text(encoding='utf-8-sig'))
    if result.get('exitCode') != 0 or result.get('runtimeHashes') != current:
        raise RuntimeError('Current runtime files have no matching successful combined verification')
    if result['tests']['focusedFailed'] or result['tests']['syntaxFailures'] or result['tests']['fullInventorySyntaxFailures']:
        raise RuntimeError('Verification contains failures')
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    originals, current, changed, rows = plan()
    if not args.apply:
        result = dict(mode='check', nextPassFiles=len(changed), cumulativeFiles=len(rows), files=rows)
        (OUT / 'next-deployment-check.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({key: value for key, value in result.items() if key != 'files'}, indent=2))
        return
    verification = require_verification(current)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(os.environ['TEMP']) / ('ix-performance-next-local-backup-' + stamp)
    backup.mkdir(exist_ok=False)
    # Back up every existing target before copying the first runtime file.
    for row in rows:
        destination = GAME / row['path']
        if sha(destination) != row['localBeforeSHA256']:
            raise RuntimeError('Local file changed during preparation: ' + row['path'])
        if destination.is_file():
            saved = backup / row['path']
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, saved)
            if sha(saved) != row['localBeforeSHA256']:
                raise RuntimeError('Backup verification failed: ' + row['path'])
    (backup / 'manifest.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    copied = []
    try:
        if runtime_hashes() != current:
            raise RuntimeError('Runtime sources changed after verification')
        for row in rows:
            destination = GAME / row['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            copied.append(row)
            shutil.copy2(ROOT / row['path'], destination)
            if sha(destination) != row['afterSHA256']:
                raise RuntimeError('Local verification failed: ' + row['path'])
        archive = OUT / 'optimization-next-gamemodes.zip'
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as package:
            for row in rows:
                package.write(ROOT / row['path'], row['path'])
            package.writestr('README-performance.txt', README)
        with zipfile.ZipFile(archive) as package:
            if package.testzip() is not None:
                raise RuntimeError('Archive CRC check failed')
            if set(package.namelist()) != {row['path'] for row in rows} | {'README-performance.txt'}:
                raise RuntimeError('Unexpected archive entries')
            for row in rows:
                if hashlib.sha256(package.read(row['path'])).hexdigest() != row['afterSHA256']:
                    raise RuntimeError('Archive source changed: ' + row['path'])
        if runtime_hashes() != current:
            raise RuntimeError('Runtime source changed during deployment')
    except Exception:
        for row in reversed(copied):
            destination = GAME / row['path']
            saved = backup / row['path']
            if saved.is_file():
                shutil.copy2(saved, destination)
            elif row['localBeforeSHA256'] is None and destination.is_file():
                destination.resolve().relative_to(GAME.resolve())
                destination.unlink()
        raise
    patch = []
    for name in changed:
        previous = BEFORE / name
        old = previous.read_text(encoding='utf-8').splitlines(True) if previous.exists() else []
        new = (ROOT / name).read_text(encoding='utf-8').splitlines(True)
        patch.extend(difflib.unified_diff(old, new, fromfile='before/' + name, tofile='after/' + name))
    (OUT / 'next-runtime.patch').write_text(''.join(patch), encoding='utf-8')
    result = dict(batch=3, generatedUTC=stamp, localGame=str(GAME), backup=str(backup), archive=str(archive),
                  archiveSHA256=sha(archive), nextPassFiles=len(changed), verified=len(rows), files=rows,
                  addonLuaUnchanged=True, noAddonOrDataWrites=True, remoteServerUpdated=False,
                  verificationGeneratedUTC=verification['generatedUTC'],
                  branchSync=dict(branch='master', committed=False, pushed=False,
                                  reason='Substantial unrelated pre-existing working-tree changes; snapshot-isolated file delivery only.'))
    (OUT / 'next-delivery.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in result.items() if key != 'files'}, indent=2))

if __name__ == '__main__':
    main()
