"""Back up known destinations, deploy this update, and build a matching server ZIP."""
from pathlib import Path
import datetime, hashlib, json, shutil, zipfile
ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
OUT=Path('E:/Codex-Archives')/('HL2RP-terminal-pda-music-v6-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
OUT.mkdir(parents=True,exist_ok=False)
PACKAGE=OUT/'package';BACKUP=OUT/'before-local'
folders=['ixhl2rp/plugins/foundation_network','ixhl2rp/plugins/site_pda','addons/foundation_terminal_assets','addons/fieldlink_pda']
files=['ixhl2rp/plugins/ambientmusic/sh_plugin.lua','ixhl2rp/plugins/zz_legends_interface/cl_menu.lua',
 'ixhl2rp/plugins/!character/derma/cl_character.lua','ixhl2rp/schema/sh_configs.lua',
 'helix/gamemode/core/derma/cl_character.lua','helix/gamemode/core/hooks/sh_hooks.lua']
for folder in folders:
 files.extend(str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/folder).rglob('*') if p.is_file())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
records=[]
for rel in sorted(set(files)):
 src=(ROOT/rel).resolve();assert src.is_relative_to(ROOT)
 destrel=Path(rel) if rel.startswith('addons/') else Path('gamemodes')/rel
 target=(LIVE/destrel).resolve();assert target.is_relative_to(LIVE)
 existed=target.exists()
 if existed:
  backup=BACKUP/destrel;backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,backup)
 staged=PACKAGE/'garrysmod'/destrel;staged.parent.mkdir(parents=True,exist_ok=True)
 target.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(src,staged);shutil.copy2(src,target)
 assert sha(src)==sha(staged)==sha(target)
 records.append({'path':str(destrel).replace('\\','/'),'sha256':sha(src),'bytes':src.stat().st_size,'previouslyExisted':existed})
shutil.copy2(ROOT/'docs/terminal-pda-music-v6.md',PACKAGE/'README.md')
manifest={'localInstall':str(LIVE),'backup':str(BACKUP),'files':records,'tests':203,'syntaxFiles':2412,'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
archive=OUT/'HL2RP-terminal-pda-music-v6.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in PACKAGE.rglob('*'):
  if p.is_file():z.write(p,p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for record in records:
  assert hashlib.sha256(z.read('garrysmod/'+record['path'])).hexdigest()==record['sha256']
manifest.update(archive=str(archive),archiveSHA256=sha(archive))
(ROOT/'docs/terminal-v6-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps({'files':len(records),'archive':str(archive),'backup':str(BACKUP),'sha256':sha(archive)},indent=2))
