"""Install only the map-keycard plugin and its facility access bridge, with backups."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
AUDIT = ROOT / '.runtime/map-keycards-20261015'
BRIDGE = 'ixhl2rp/plugins/facility_utilities/sv_doors.lua'
FILES = [BRIDGE] + ['ixhl2rp/plugins/map_keycards/' + name for name in
                  ('sh_plugin.lua', 'sh_commands.lua', 'sv_access.lua', 'sv_tsade.lua')]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None


def deploy():
    previous = AUDIT / 'source-before/sv_doors.lua'
    rows = []
    for rel in FILES:
        source, target = ROOT / rel, LIVE / rel
        expected = sha(previous) if rel == BRIDGE else None
        actual = sha(target)
        current = sha(source)
        if not current or actual not in (expected, current):
            raise RuntimeError('Unexpected source/live state: ' + rel)
        rows.append({'path': rel, 'source_sha256': current, 'before_sha256': actual})
    if '--install' not in sys.argv:
        print(json.dumps({'mode': 'plan', 'files': rows}, indent=2))
        return
    for row in rows:
        rel = row['path']
        target = LIVE / rel
        if target.exists():
            backup = AUDIT / 'live-before' / rel
            if not backup.exists():
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        row['installed_sha256'] = sha(target)
        if row['installed_sha256'] != row['source_sha256']:
            raise RuntimeError('Installed hash mismatch: ' + rel)
    report = {'installed_utc': datetime.now(timezone.utc).isoformat(), 'files': rows,
              'gameplay_validation': 'Offline only; restart map for in-game validation.'}
    (AUDIT / 'deployment.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print('Installed and hash-verified ' + str(len(rows)) + ' runtime files. No addon modified.')


if __name__ == '__main__':
    deploy()
