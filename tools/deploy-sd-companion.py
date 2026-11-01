"""Retire only hash-verified files installed by our earlier SD deployment."""
from pathlib import Path
import datetime, hashlib, json, shutil
ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
DESKTOP=Path('C:/Users/q1236/Desktop')
BACKUP=DESKTOP/('sd-companion-transition-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
old=json.loads((ROOT/'docs/sd-dclass-deployment.json').read_text())
cleanup=json.loads((ROOT/'docs/autonomous-cleanup-deployment.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
actions=[]; skipped=[]
def backup(p):
    relative=Path(p.drive.replace(':',''))/p.relative_to(p.anchor)
    target=BACKUP/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
def retire(p,expected,restore=None):
    p=p.resolve()
    assert p.is_relative_to(LIVE) or p.is_relative_to(ROOT) or p.is_relative_to(DESKTOP/'SD models')
    if not p.exists(): return
    if sha(p)!=expected:
        skipped.append(str(p));return
    backup(p)
    if restore and restore.exists(): shutil.copy2(restore,p)
    else: p.unlink()  # exact manifest file only, never recursively remove content
    actions.append(str(p))
# Restore preexisting local copies if present; otherwise allow the installed original Workshop pack to resolve.
for record in old['deployed']:
    p=LIVE/record['path']
    retire(p,record['sha256'],Path(old['backup'])/record['path'])
# Retire our copied/edited SD material scripts, retaining the independently generated maps.
repair=DESKTOP/'SD-material-repair'
original=Path(cleanup['backup'])/'sd-materials'
for edited in (repair/'materials').rglob('*.vmt'):
    rel=edited.relative_to(repair)
    for p in (ROOT/'ixhl2rp/content'/rel,LIVE/'gamemodes/ixhl2rp/content'/rel,LIVE/rel):
        retire(p,sha(edited))
    retire(DESKTOP/'SD models'/rel,sha(edited),original/rel)
# Stop the schema from distributing recompiled models and modified SD scripts.
plugin=ROOT/'ixhl2rp/plugins/sd_material_repair/sh_plugin.lua'
backup(plugin)
plugin.write_text('PLUGIN.name = "SD Material Repair"\nPLUGIN.author = "Legends"\nPLUGIN.description = "Repairs are supplied by the SD-DClass-companion addon; original SD content is required."\n',encoding='utf8')
changed=['helix/plugins/realistic_visuals/cl_hooks.lua','helix/gamemode/game/ui/mainmenu.title.lua',
 'helix/gamemode/game/ui/mainmenu.create.lua','helix/gamemode/game/ui/tabmenu.lua',
 'helix/gamemode/game/cl_ui_utils.lua','ixhl2rp/plugins/sd_material_repair/sh_plugin.lua']
for rel in changed:
    dest=LIVE/'gamemodes'/rel
    if dest.exists():backup(dest)
    dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
    assert sha(dest)==sha(ROOT/rel)
addon=ROOT/'addons/sd_dclass_companion'
dest=LIVE/'addons/sd_dclass_companion'
assert dest.resolve().is_relative_to(LIVE/'addons')
for p in addon.rglob('*'):
    if not p.is_file():continue
    target=dest/p.relative_to(addon)
    if target.exists():backup(target)
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    assert sha(p)==sha(target)
(DESKTOP/'SD-DClass-models/DO-NOT-PUBLISH.md').write_text('Superseded private build. Contains modified original SD models and copied SD content. Do not publish or install alongside the original pack. Use SD-DClass-companion instead.\n')
report={'backup':str(BACKUP),'retiredOrRestored':actions,'skippedChangedFiles':skipped,'gamemodes':changed,'addon':str(dest)}
(ROOT/'docs/sd-companion-deployment.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'retiredOrRestored':len(actions),'skipped':skipped,'backup':str(BACKUP)}))
