"""Read SD Workshop model metadata to map clothing props to bodygroup names."""
import argparse
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def cstring(stream):
    data = bytearray()
    while True:
        char = stream.read(1)
        if not char:
            raise EOFError('Truncated GMA header')
        if char == b'\0':
            return data.decode('utf-8', errors='replace')
        data.extend(char)


def metadata(data):
    assert data[:4] == b'IDST'
    def integer(offset):
        return struct.unpack_from('<i', data, offset)[0]
    def name(offset):
        return data[offset:data.index(b'\0', offset)].decode('utf-8', errors='replace')
    groups = []
    for index in range(integer(232)):
        part = integer(236) + index * 16
        models = [name(part + integer(part+12) + value*148) for value in range(integer(part+4))]
        groups.append({'id': index, 'name': name(part+integer(part)), 'values': models})
    return {'skins': integer(224), 'bodygroups': groups}


def audit(archive):
    models = {}
    with archive.open('rb') as stream:
        assert stream.read(4) == b'GMAD'
        version = stream.read(1)[0]; stream.read(16)
        if version > 1:
            while cstring(stream):
                pass
        title = cstring(stream); cstring(stream); cstring(stream); stream.read(4)
        matches = []; offset = 0
        while struct.unpack('<I', stream.read(4))[0]:
            path = cstring(stream).lower()
            size = struct.unpack('<Q', stream.read(8))[0]; stream.read(4)
            if path.startswith('models/sd/citizens/') and path.endswith('.mdl'):
                matches.append((path, offset, size))
            offset += size
        base = stream.tell()
        for path, offset, size in matches:
            stream.seek(base+offset); models[path] = metadata(stream.read(size))
    props = {path: row for path, row in models.items() if '/props/' in path}
    characters = {path: row for path, row in models.items() if '/props/' not in path and '_arms_' not in path}
    targets = {}
    for path, row in characters.items():
        for group in row['bodygroups']:
            for value, part in enumerate(group['values']):
                key = Path(part).stem.lower()
                if key in ('blank', ''):
                    continue
                targets.setdefault(key, []).append({'model': path, 'group': group['name'], 'id': group['id'], 'value': value})
    matches = []
    for path, row in props.items():
        key = Path(path).stem
        matches.append({'prop': path, 'skins': row['skins'], 'matches': targets.get(key, [])})
    return {'archive': str(archive), 'title': title, 'note': 'Names and indices from original mounted-addon archive; visual variants still require comparison.',
            'characters': characters, 'props': props, 'exactNameCandidates': matches}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    report = audit(args.archive)
    destination = ROOT / '.runtime/cctv-interactive-20261016/sd-clothing-audit.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    matched = [row for row in report['exactNameCandidates'] if row['matches']]
    print(json.dumps({'title': report['title'], 'characterModels': len(report['characters']), 'props': len(report['props']),
                     'exactNameCandidates': len(matched), 'sample': [{'prop': row['prop'], 'firstMatch': row['matches'][0]} for row in matched[:8]]}, indent=2))
