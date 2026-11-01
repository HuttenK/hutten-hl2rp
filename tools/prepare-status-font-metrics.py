"""Use installed Tahoma glyph widths in the offline SVG recorder."""
from pathlib import Path
from PIL import ImageFont
import json
metrics={}
codes=list(range(32,127))+list(range(0x400,0x500))+[0x2014,0x2013,0x2026]
for name,file in [('normal','tahoma.ttf'),('bold','tahomabd.ttf')]:
    for size in range(14,37):
        font=ImageFont.truetype(str(Path('C:/Windows/Fonts')/file),size)
        metrics[name+str(size)]={str(code):round(font.getlength(chr(code)),3) for code in codes}
root=Path(__file__).resolve().parent.parent
(root/'tools/status-font-metrics.json').write_text(json.dumps(metrics),encoding='utf8')
