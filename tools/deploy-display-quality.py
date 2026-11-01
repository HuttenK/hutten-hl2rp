from pathlib import Path
import shutil,datetime,json,hashlib,subprocess
ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
DESKTOP=Path('C:/Users/q1236/Desktop')
BACKUP=DESKTOP/('display-quality-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
SRC=ROOT/'addons/sd_dclass_companion'
OUT=DESKTOP/'SD-DClass-companion'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def backup(p):
 target=BACKUP/p.drive.replace(':','')/p.relative_to(p.anchor)
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
# Only obsolete, self-generated assets in the three known companion copies.
retired=[]
for base in (SRC,OUT,LIVE/'addons/sd_dclass_companion'):
 base=base.resolve()
 for rel in ('materials/sd_dclass_companion/jacket.png','materials/sd_dclass_companion/pants.png','clothing-preview.png'):
  p=(base/rel).resolve();assert p.is_relative_to(base)
  if p.exists():backup(p);p.unlink();retired.append(str(p))
subprocess.run(['py','-3',str(ROOT/'tools/build-sd-companion.py')],check=True)
changed=['helix/entities/entities/ix_item.lua','helix/gamemode/game/items/sh_preview.lua',
 'helix/gamemode/game/inventory/ui/cl_inventory_item.lua',
 'ixhl2rp/plugins/holsteredweapons.lua','ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua',
 'ixhl2rp/plugins/arccw_item_atts/sh_plugin.lua','ixhl2rp/plugins/arccw_item_atts/cl_preview.lua',
 'ixhl2rp/plugins/arccw_item_atts/cl_display.lua']
records=[]
for rel in changed:
 target=LIVE/'gamemodes'/rel
 if target.exists():backup(target)
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target)
 assert sha(ROOT/rel)==sha(target)
 records.append({'path':str(target),'sha256':sha(target)})
for source in SRC.rglob('*'):
 if not source.is_file():continue
 target=LIVE/'addons/sd_dclass_companion'/source.relative_to(SRC)
 if target.exists():backup(target)
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
 assert sha(source)==sha(target)
 records.append({'path':str(target),'sha256':sha(target)})
(ROOT/'docs/display-quality-deployment.json').write_text(json.dumps({'backup':str(BACKUP),'deployed':records,'retired':retired},indent=2))
print('Deployed',len(records),'files; backup:',BACKUP)
