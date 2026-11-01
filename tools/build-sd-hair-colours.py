"""Build neutral, tintable SD hair atlases without editing the Workshop addon.

Uses its existing strand alpha/UV layout; SD still supplies models and normal
maps. Pillow is required. Run with the path to the original gmpublisher.gma.
"""
import argparse
import importlib.util
import io
import struct
from pathlib import Path
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parent.parent
PREFIX = 'materials/models/sectorialdistrict/citizens/'
SOURCES = {
    'haircurly': 'haircurly_white', 'haircurly2': 'haircurly2_white',
    'haircurly3': 'haircurly3_white', 'hairshort01': 'hairshort01_white',
    'hairlong01': 'hairlong01_blonde', 'hairshaved': 'hairshaved_white',
    'hairshaved04': 'hairshaved04', 'hairshaved06': 'hairshaved06',
}


def decode(data):
    w, h = struct.unpack_from('<HH', data, 16)
    fmt = struct.unpack_from('<I', data, 52)[0]
    if fmt == 12:
        return Image.frombytes('RGBA', (w, h), data[-w*h*4:], 'raw', 'BGRA')
    if fmt not in (13, 14, 15):
        raise ValueError(f'Unsupported VTF format {fmt}')
    size = max(1, (w+3)//4)*max(1, (h+3)//4)*(8 if fmt == 13 else 16)
    header = b'DDS '+struct.pack('<7I', 124, 0x81007, h, w, size, 0, 0)+bytes(44)
    header += struct.pack('<2I', 32, 4)+{13:b'DXT1', 14:b'DXT3', 15:b'DXT5'}[fmt]+bytes(20)
    header += struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    return Image.open(io.BytesIO(header+data[-size:])).convert('RGBA')


def encode(image):
    # VTF 7.2, full mip chain, BGRA8888. Lossless alpha avoids changing the
    # authored cutouts on closely shaved hair. No thumbnails or resource table.
    levels = [image]
    while levels[-1].size != (1, 1):
        w, h = levels[-1].size
        levels.append(levels[-1].resize((max(1, w//2), max(1, h//2)), Image.Resampling.LANCZOS))
    header = bytearray(80)
    struct.pack_into('<4sIIIHHIHH', header, 0, b'VTF\0', 7, 2, 80,
                     *image.size, 0x2000 | 0x10 | 0x20, 1, 0)
    struct.pack_into('<3f', header, 32, .5, .5, .5)
    struct.pack_into('<fIBI', header, 48, 1., 12, len(levels), 0xFFFFFFFF)
    struct.pack_into('<H', header, 63, 1)
    return bytes(header)+b''.join(im.tobytes('raw', 'BGRA') for im in reversed(levels))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sd_archive', ROOT/'tools/audit-character-headwear.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    paths = {PREFIX+name+'.vtf' for name in SOURCES.values()}
    files = module.archive(args.archive, paths)
    destination = ROOT/'ixhl2rp/content/materials/models/hutten/sd_hair'
    destination.mkdir(parents=True, exist_ok=True)
    for family, name in SOURCES.items():
        original = decode(files[PREFIX+name+'.vtf'])
        alpha = original.getchannel('A')
        luminance = original.convert('L')
        mask = alpha.point(lambda x: 255 if x > 192 else 0)
        mean = max(1., ImageStat.Stat(luminance, mask).mean[0])
        # Neutralise baked brown/blond colour, preserving strand variation.
        # A floor keeps almost-black shaved atlases tintable without emission.
        grey = luminance.point(lambda x: round(max(110, min(230, 190*(max(x, .5)/mean)**.35))))
        neutral = Image.merge('RGBA', (grey, grey, grey, alpha))
        data = encode(neutral)
        restored = decode(data)
        assert restored.size == original.size
        assert restored.getchannel('A').tobytes() == alpha.tobytes()
        assert restored.getchannel('R').tobytes() == restored.getchannel('B').tobytes()
        (destination/(family+'.vtf')).write_bytes(data)
        print(f'{family}: {original.width}x{original.height}, {len(data)} bytes, alpha verified')


if __name__ == '__main__':
    main()
