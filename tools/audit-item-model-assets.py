"""Read installed addon archive directories and model headers without launching GMod."""
from pathlib import Path
import json
import struct

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path(r'C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod')
WORKSHOP = LIVE.parents[2] / 'workshop/content/4000'
config = json.loads((ROOT / 'tools/item-model-replacements.json').read_text(encoding='utf-8'))
wanted = set(config['models'].values()) | {config['learningBookModel']}
found = {model: [] for model in sorted(wanted)}

def record(name, source, data):
    row = {'source': str(source)}
    if len(data) >= 232 and data[:4] == b'IDST':
        row.update(version=struct.unpack_from('<I', data, 4)[0], skins=struct.unpack_from('<I', data, 224)[0],
                   hullMin=struct.unpack_from('<3f', data, 104), hullMax=struct.unpack_from('<3f', data, 116))
    found[name].append(row)

def string(f):
    data=bytearray()
    while True:
        b=f.read(1)
        if not b: raise EOFError('truncated GMA header')
        if b==b'\0': return data.decode('utf-8', errors='replace')
        data.extend(b)

for folder in [LIVE, *[p for p in (LIVE / 'addons').iterdir() if p.is_dir()]]:
    for name in wanted:
        p=folder / name
        if p.is_file():
            with p.open('rb') as f: record(name,p,f.read(256))

archives=list(WORKSHOP.rglob('*.gma'))+list((LIVE / 'addons').glob('*.gma'))+list((LIVE / 'cache/workshop').glob('*.gma'))
for archive in archives:
    with archive.open('rb') as f:
        if f.read(4)!=b'GMAD': continue
        version=f.read(1)[0];f.read(16)
        if version > 1:
            while string(f): pass
        title,description,author=string(f),string(f),string(f)
        f.read(4);offset=0;matches=[]
        while struct.unpack('<I',f.read(4))[0]:
            name=string(f).lower();size=struct.unpack('<Q',f.read(8))[0];f.read(4)
            if name in wanted: matches.append((name,offset,size))
            offset+=size
        start=f.tell()
        for name,offset,size in matches:
            f.seek(start+offset);record(name,archive,f.read(min(size,256)))

stock_path=ROOT / '.runtime/stock-assets.json'
stock=set(json.loads(stock_path.read_text(encoding='utf-8-sig'))) if stock_path.exists() else set()
missing=[name for name,rows in found.items() if not rows and name not in stock]
report={'note':'Installed files, not live mount or rendering verification.', 'archives':len(archives), 'models':found,
        'stockModels':[name for name,rows in found.items() if not rows and name in stock], 'missing':missing}
out=ROOT / '.runtime/item-models-20261013/assets.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'requestedUniqueModels':len(wanted),'archives':len(archives),'missing':missing,
                  'juiceSkins':[row.get('skins') for row in found['models/illusion/eftcontainers/juice.mdl']]},indent=2))
