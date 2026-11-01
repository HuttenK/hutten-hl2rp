from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parent.parent
archive=Path('E:/Codex-Archives/HL2RP-powerbox-calibration-cables-20261008')
live=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
paths=['ixhl2rp/plugins/blackout/'+s+'.lua' for s in ['sh_plugin','sv_plugin','entities/entities/ix_blackout_fusebox']]
paths+=['ixhl2rp/plugins/facility_utilities/'+s+'.lua' for s in ['sh_core','sv_repair','cl_repair','sv_jobs','sv_connections','cl_connections','sv_power']]
for rel in paths:
 for source,folder in [(ROOT,'source-backup'),(live,'local-backup')]:
  target=archive/folder/rel
  if not target.exists() and (source/rel).exists():
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/rel,target)
(ROOT/'docs/powerbox-calibration-archive-path.txt').write_text(str(archive))
# Extract only stock material evidence. Never modify mounted game assets.
script=(ROOT/'tools/inspect-powerbox.py').read_text(encoding='utf-8')
script=script.replace("TARGET='models/props_c17/powerbox'","TARGET='materials/sprites/glow04_noz'")
script=script.replace("OUT=ROOT/'docs/powerbox-inspection'","OUT=ROOT/'docs/powerbox-glow'")
exec(compile(script,str(ROOT/'tools/inspect-powerbox.py'),'exec'))
