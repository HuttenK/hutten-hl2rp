from pathlib import Path
import shutil, struct
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
archive = Path('E:/Codex-Archives/HL2RP-skills-powerbox-20261008')
live = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes')
paths = ['helix/gamemode/game/ui/legends.workspace.lua',
 'ixhl2rp/plugins/blackout/sv_plugin.lua',
 'ixhl2rp/plugins/blackout/entities/entities/ix_blackout_fusebox.lua',
 'ixhl2rp/plugins/facility_utilities/sv_jobs.lua',
 'ixhl2rp/plugins/facility_utilities/sv_devices.lua']
for rel in paths:
 for source, folder in [(ROOT, 'source-backup'), (live, 'local-backup')]:
  dest = archive / folder / rel
  if dest.exists(): continue
  if (source / rel).exists():
   dest.parent.mkdir(parents=True, exist_ok=True)
   shutil.copy2(source / rel, dest)
(ROOT / 'docs/skills-powerbox-archive-path.txt').write_text(str(archive))
b = (ROOT / 'docs/powerbox-materials/1/powerbox_sheet.vtf').read_bytes()
w,h = struct.unpack_from('<HH', b, 16)
fmt = struct.unpack_from('<I', b, 52)[0]
four = {13:b'DXT1', 14:b'DXT3', 15:b'DXT5'}[fmt]
size = ((w+3)//4)*((h+3)//4)*(8 if fmt==13 else 16)
header = b'DDS ' + struct.pack('<7I',124,0x81007,h,w,size,0,0) + bytes(44)
header += struct.pack('<2I',32,4)+four+bytes(20)+struct.pack('<5I',0x1000,0,0,0,0)
p = ROOT / 'docs/powerbox-materials/sheet.dds'; p.write_bytes(header+b[-size:])
Image.open(p).save(p.with_suffix('.png'))
print('Backup ready; texture', w,h,fmt)
