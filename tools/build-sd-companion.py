"""Package only original companion artwork, procedural maps and runtime code."""
from pathlib import Path
import json, shutil, hashlib
ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'addons/sd_dclass_companion'
OUT = Path('C:/Users/q1236/Desktop/SD-DClass-companion')
GEN = Path('C:/Users/q1236/.codex/generated_images/01a0af77-7b63-7de0-8e91-c3f54d495190')
REPAIR = Path('C:/Users/q1236/Desktop/SD-material-repair')
maps = json.loads((REPAIR / 'generated-maps.json').read_text())
for item in maps:
    p = SRC / item['path']; p.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(REPAIR / item['path'], p)
resources = SRC / 'lua/sd_dclass_companion/resources.lua'
resources.parent.mkdir(parents=True, exist_ok=True)
resources.write_text('-- Original procedural shader maps only.\n' + ''.join(
    'resource.AddFile("' + item['path'] + '")\n' for item in maps) + ''.join(
    'resource.AddFile("' + p.relative_to(SRC).as_posix() + '")\n' for p in (SRC/'materials').rglob('*.vmt')))
(SRC / 'addon.json').write_text(json.dumps({'title': 'D-Class Clothing - SD Companion',
    'type': 'model', 'tags': ['roleplay'],
    'ignore': ['*.md', '*.json', 'workshop-thumbnail.png', 'clothing-preview.png']}, indent=2))
# Promotional PNGs are kept outside the companion package.
(SRC / 'README.md').write_text('''# D-Class Clothing - SD Companion

Requires the original SectorialDistrict 4 Citizen Playermodels Pack on server and clients.
Install this folder alongside that original pack. Do not install SD-DClass-models,
the earlier full replacement build. Restart GMod to clear cached models/materials.

Use the existing bodygroup editor: Torso group 4, value 11 for the orange jacket;
Legs group 7, value 4 for orange trousers. Values are zero-based. These two existing
choices gain orange appearances; no additional bodygroups are added. Both sexes
are supported. Other bodygroup choices restore their original submaterials.
Existing gameplay permissions for changing bodygroups are unchanged.

Contains no MDL/VVD/VTX/PHY files and no original SD textures or copied material scripts. Two original material definitions resolve bags: the satchel references installed SD textures; the backpack uses a generic fabric fallback.
Version 3 preserves the installed original diffuse and matching normal maps at up
to 4096 resolution. Orange color is applied by a private runtime shader and the D
is drawn smaller from original vector geometry, sampling cloth shading through the ink. No low-resolution replacement atlas is used.
The twenty included detail/normal/specular/Phong maps are our procedural replacements.
During rendering, selected clothing regions are recolored in memory. Shoes and
unaffected regions retain their original texture. Nothing is exported.
Original models, animations and facial features remain provided by the original addon.

The missing APF diffuse uses the installed city_suit texture as a visual fallback;
this is not a reconstruction of the author's APF design. The old DX8 eye fallback
is not reconstructed. Original missing animation libraries are not supplied here.

The thumbnail is promotional artwork, not an in-game screenshot. Packaging and
offline checks passed; in-game lighting, multiplayer and ragdoll visuals require testing.
No determination of the SD author's license terms is made by this packaging.
Before publishing, confirm that the author allows independently supplied compatibility addons.

Rendering reference: https://wiki.facepunch.com/gmod/render.PushRenderTarget
''', encoding='utf8')
assert not any(p.suffix.lower() in ('.mdl', '.vvd', '.vtx', '.phy', '.smd', '.qc') for p in SRC.rglob('*'))
assert len(list((SRC / 'materials').rglob('*.vtf'))) == 20
assert len(list((SRC / 'materials').rglob('*.vmt'))) == 2
assert not list(SRC.rglob('*.png'))
shutil.copytree(SRC, OUT, dirs_exist_ok=True)
files = [{'path': p.relative_to(SRC).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
         for p in SRC.rglob('*') if p.is_file()]
(ROOT / 'docs/sd-companion-package.json').write_text(json.dumps({'output': str(OUT), 'files': files}, indent=2))
print('Packaged', len(files), 'files at', OUT)
