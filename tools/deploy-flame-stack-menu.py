"""Deploy a scoped fix to the local installation and supplied flame addon source."""
from pathlib import Path
import hashlib,json,re,shutil,zipfile

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
out=Path((ROOT/'docs/flame-stack-menu-archive-path.txt').read_text().strip()).resolve()
assert out.is_relative_to(Path('E:/Codex-Archives').resolve()) and out.is_dir()
files=[
 'helix/gamemode/items/base/stackable.lua',
 'helix/gamemode/game/items/sh_item.lua',
 'ixhl2rp/plugins/ammo_cringe/items/base/ammo.lua',
 'ixhl2rp/plugins/ammo_cringe/items/weapon/sh_flamethrower_m2.lua',
 'ixhl2rp/plugins/ammo_cringe/items/weapon/sh_flamethrower_fm35.lua',
 'ixhl2rp/plugins/scp610_control/items/thermal_fuel.lua',
 'ixhl2rp/plugins/zz_legends_interface/cl_menu.lua',
 'helix/gamemode/game/ui/mainmenu.title.lua',
 'addons/foundation_flamethrower/lua/weapons/arc9_codww2_flamethrower.lua',
 'addons/foundation_flamethrower/lua/weapons/arc9_codww2_flammenwerfer35.lua',
]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited={e['path']:e['sha256'] for e in audit['entries']}
for name in files:assert audited[name]==sha(ROOT/name),f'Stale audit: {name}'
raw=(ROOT/'docs/flame-stack-menu-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
assert re.search(r'237 regression suites passed\.',log)
archive=out/'HL2RP-flame-stack-menu.zip';assert not archive.exists()
for name in files:
 if name.startswith('addons/'):
  external=Path('E:/flamethrower/lua/weapons')/Path(name).name
  assert sha(external)==sha(out/'before-addon'/external.name),'External source changed since inspection'
records=[]
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 z.write(ROOT/'docs/flame-stack-menu-update.md','README.md')
 for name in files:
  src=ROOT/name;relative=Path(name) if name.startswith('addons/') else Path('gamemodes')/name
  target=(LIVE/relative).resolve();assert target.is_relative_to(LIVE) and target.exists()
  backup=out/'before-local'/relative;backup.parent.mkdir(parents=True,exist_ok=True);assert not backup.exists()
  shutil.copy2(target,backup);assert sha(backup)==sha(target)
  z.write(src,'garrysmod/'+relative.as_posix())
  shutil.copy2(src,target);assert sha(src)==sha(target)
  if name.startswith('addons/'):
   external=Path('E:/flamethrower/lua/weapons')/src.name
   shutil.copy2(src,external);assert sha(external)==sha(src)
  records.append(dict(path=relative.as_posix(),sha256=sha(src)))
 z.writestr('files.json',json.dumps(records,indent=2))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for entry in records:assert hashlib.sha256(z.read('garrysmod/'+entry['path'])).hexdigest()==entry['sha256']
shutil.copy2(ROOT/'docs/flame-stack-menu-update.md',out/'README.md')
result=dict(archive=str(archive),sha256=sha(archive),files=records,localInstall=str(LIVE),tests=237,syntaxFiles=audit['files'],engineTested=False)
for target in (out/'deployment.json',ROOT/'docs/flame-stack-menu-deployment.json'):
 target.write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps(dict(archive=str(archive),sha256=sha(archive),files=len(records),bytes=archive.stat().st_size),indent=2))
