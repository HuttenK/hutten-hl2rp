"""Rasterize recorded native drawing commands; this is not an in-engine screenshot."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

data = json.loads(Path('docs/tv-status-draw.json').read_text(encoding='utf-8'))
fonts = {name: ImageFont.truetype('C:/Windows/Fonts/tahomabd.ttf' if v['weight'] >= 600 else 'C:/Windows/Fonts/tahoma.ttf', v['size']) for name, v in data['fonts'].items()}
def color(c): return (c['r'], c['g'], c['b'])
images = []
for f in data['frames']:
    im = Image.new('RGB', (f['w'], f['h'])); d = ImageDraw.Draw(im)
    boxes = []
    for op in f['ops']:
        kind, *v = op
        if kind == 'rect':
            x, y, w, h, c = v; d.rectangle((x, y, x+w, y+h), fill=color(c))
        elif kind == 'line':
            x, y, x2, y2, c = v; d.line((x, y, x2, y2), fill=color(c))
        elif kind == 'poly':
            pts, c = v; d.polygon([(p['x'], p['y']) for p in pts.values()], fill=color(c))
        elif kind == 'text':
            text, font, x, y, c, align = v; ft = fonts[font]
            w = d.textlength(text, font=ft)
            if align == 1: x -= w/2
            elif align == 2: x -= w
            box = (x, y, x+w, y+data['fonts'][font]['size'])
            assert x >= 0 and x+w <= f['w'] and box[3] <= f['h'], (f['status'], text, box)
            # GMod text coordinates refer to the top, including font metrics.
            d.text((x, y), text, fill=color(c), font=ft, anchor='lt')
            boxes.append(box)
    for i, a in enumerate(boxes):
        for b in boxes[i+1:]:
            assert not (a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]), (f['status'], a, b)
    if f['status'] == 'error' and f['w'] == 1024: im.save('docs/tv-status-preview.png')
    if f['w'] == 700: images.append(im)
sheet = Image.new('RGB', (1400, 960), (4, 8, 12))
for i, im in enumerate(images): sheet.paste(im, ((i % 2)*700, (i//2)*240))
sheet.save('docs/tv-status-contact-sheet.png')
print('PASS 14 status layouts: text bounds and overlap; offline PNG previews written.')
