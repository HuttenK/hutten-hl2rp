from pathlib import Path
import collections, hashlib, json
ROOT = Path(__file__).resolve().parent.parent
paths = collections.defaultdict(list)
for folder in ['flamethrower', '610', '610-2']:
    root = Path('E:/')/folder
    for p in root.rglob('*'):
        if p.is_file():
            paths[p.relative_to(root).as_posix().lower()].append(p)
overlaps = {k:v for k,v in paths.items() if len(v)>1}
conflicts = [k for k,v in overlaps.items() if len({hashlib.sha256(p.read_bytes()).hexdigest() for p in v})>1]
resources = sorted(k for k in paths if k.startswith(('materials/','models/','sound/','particles/')) and k.endswith(('.mdl','.vmt','.vtf','.png','.jpg','.wav','.mp3','.ogg','.pcf')))
lines = ['-- Assets from the three supplied local addons. No Workshop upload is required.', 'local paths = {']
lines += [' '+json.dumps(p)+',' for p in resources]
lines += ['}', 'for _,path in ipairs(paths) do', ' if file.Exists(path, "GAME") then resource.AddFile(path) end', 'end', '']
(ROOT/'ixhl2rp/plugins/scp610_control/sv_resources.lua').write_text('\n'.join(lines),encoding='utf8')
print(json.dumps({'overlapCount':len(overlaps),'conflictingPaths':conflicts,'downloadPaths':len(resources)},indent=2))
