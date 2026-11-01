"""Check which bones/materials actually skin SD worn headwear; no game required."""
import json, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
INDEX = ROOT / '.runtime/weapon-slots-followup/sd-index.json'
GEAR = {'hats', 'hlvr_consthat', 'helmet_spetsnaz', 'helmet_a_col'}

def cstring(f):
    result = bytearray()
    while True:
        b = f.read(1)
        if not b: raise EOFError()
        if b == b'\0': return result.decode('utf-8', errors='replace')
        result.extend(b)

def archive(path, wanted):
    with open(path, 'rb') as f:
        assert f.read(4) == b'GMAD'
        version = f.read(1)[0]; f.read(16)
        if version > 1:
            while cstring(f): pass
        for _ in range(3): cstring(f)
        f.read(4); offset = 0; matches = []
        while struct.unpack('<I', f.read(4))[0]:
            name = cstring(f).lower(); size = struct.unpack('<Q', f.read(8))[0]; f.read(4)
            if name in wanted: matches.append((name, offset, size))
            offset += size
        base = f.tell(); result = {}
        for name, offset, size in matches:
            f.seek(base + offset); result[name] = f.read(size)
        return result

def inspect(mdl, vvd):
    def i(offset): return struct.unpack_from('<i', mdl, offset)[0]
    def s(offset): return mdl[offset:mdl.index(b'\0', offset)].decode()
    bones = [s(i(160)+n*216+i(i(160)+n*216)) for n in range(i(156))]
    materials = [s(i(208)+n*64+i(i(208)+n*64)) for n in range(i(204))]
    skinrefs = struct.unpack_from('<'+'H'*i(220), mdl, i(228))
    vertexbase = struct.unpack_from('<I', vvd, 56)[0]
    result = []
    for b in range(i(232)):
        part = i(236) + b*16
        for m in range(i(part+4)):
            model = part+i(part+12)+m*148
            for meshnum in range(i(model+72)):
                mesh = model+i(model+76)+meshnum*116
                material = materials[skinrefs[i(mesh)]]
                if material not in GEAR: continue
                used = set()
                for vertex in range(i(mesh+8)):
                    offset = vertexbase + i(model+84) + (i(mesh+12)+vertex)*48
                    weights = struct.unpack_from('<3f', vvd, offset)
                    for n in range(vvd[offset+15]):
                        if weights[n] > .0001: used.add(bones[vvd[offset+12+n]])
                result.append({'group': b, 'value': m, 'material': material, 'bones': sorted(used)})
    return result

if __name__ == '__main__':
    rows = [r for r in json.loads(INDEX.read_text()) if r['name'].startswith('models/sd/citizens/citizen_')]
    sources = {}
    for r in rows: sources.setdefault(r['source'], []).append(r['name'])
    report = {}
    for source, models in sources.items():
        data = archive(source, set(models) | {p[:-4]+'.vvd' for p in models})
        for model in models:
            vvd = data.get(model[:-4]+'.vvd')
            if vvd: report[model] = inspect(data[model], vvd)
    output = ROOT / '.runtime/character-height-20261013/headwear-audit.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2))
    bad = [(model, row) for model, rows in report.items() for row in rows
           if row['group'] != 1 or row['bones'] != ['ValveBiped.Bip01_Head1']]
    print(json.dumps({'models': len(report), 'headwearMeshes': sum(map(len, report.values())), 'exceptions': bad}, indent=2))
