"""Build original procedural Source shader maps; never copy Autonomous content."""
from pathlib import Path
import math,struct,json,re,shutil
from PIL import Image,ImageDraw
repo=Path(__file__).resolve().parent.parent
manifest=json.loads((repo/'docs/autonomous-cleanup-deployment.json').read_text())
backup=Path(manifest['backup'])/'sd-materials'
src=Path('C:/Users/q1236/Desktop/SD models'); out=Path('C:/Users/q1236/Desktop/SD-material-repair')
have={p.relative_to(src/'materials').as_posix().lower() for p in (src/'materials').rglob('*') if p.is_file()}
have.difference_update(e['path'].removeprefix('materials/') for e in manifest.get('sdGeneratedMaps',[]))
keys={'$basetexture','$bumpmap','$detail','$phongwarptexture','$phongexponenttexture','$envmapmask','$lightwarptexture','$iris','$ambientoccltexture','$corneatexture'}
needed={};patched=[]
for p in backup.rglob('*.vmt'):
 s=p.read_text(encoding='utf8');lines=[]
 for line in s.splitlines():
  m=re.search(r'"?(\$\w+)"?\s+"([^"\n]+)"',line.split('//')[0])
  if m and m[1].lower() in keys:
   key=m[1].lower();ref=m[2].replace('\\','/').lower();ref=ref if ref.endswith('.vtf') else ref+'.vtf'
   if ref not in have:
    if key in ('$basetexture','$iris'):
     target='models/sectorialdistrict/citizens/city_suit' if 'combine_soldier_apf' in ref else 'models/sectorialdistrict/aliens/vortigaunt/eye_d'
     line=line.replace(m[2],target)
    else:needed[ref]=key
  lines.append(line)
 rel=p.relative_to(backup)
 for root in (src,out):
  target=root/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_text('\n'.join(lines)+'\n',encoding='utf8')
 patched.append(rel.as_posix())
def byte(v):return max(0,min(255,round(v)))
def pattern(name,x,y,n):
 u=x/n;v=y/n;wave=math.sin
 noise=wave(2*math.pi*(17*u+23*v))*wave(2*math.pi*(31*u-13*v))
 if 'leather' in name:return 128+8*noise+5*wave(2*math.pi*7*u)*wave(2*math.pi*9*v)
 if 'dirt' in name:return 128+7*noise+10*wave(2*math.pi*(3*u+2*v))*wave(2*math.pi*(u-3*v))
 if 'metal' in name:return 128+3*noise+7*wave(2*math.pi*47*v)
 return 128+6*noise+10*wave(2*math.pi*32*u)*wave(2*math.pi*32*v)+4*wave(2*math.pi*(16*u-16*v))
def vtf(path,im,normal=False,lut=False):
 levels=[im];w,h=im.size
 if not lut:
  while levels[-1].width>1 or levels[-1].height>1:
   prev=levels[-1];mip=prev.resize((max(1,prev.width//2),max(1,prev.height//2)),Image.Resampling.BOX)
   if normal:
    pixels=[]
    for r,g,b,a in mip.getdata():
     x,y,z=r/127.5-1,g/127.5-1,b/127.5-1;l=math.sqrt(x*x+y*y+z*z) or 1
     pixels.append((byte((x/l+1)*127.5),byte((y/l+1)*127.5),byte((z/l+1)*127.5),255))
    mip.putdata(pixels)
   levels.append(mip)
 header=bytearray(80);header[:4]=b'VTF\0';struct.pack_into('<III',header,4,7,2,80);struct.pack_into('<HHIHH',header,16,w,h,(128 if normal else 0)|(4|8|256|512 if lut else 0),1,0)
 struct.pack_into('<fff',header,32,.5,.5,.5);struct.pack_into('<fI',header,48,1,0);header[56]=len(levels);struct.pack_into('<I',header,57,0xffffffff);struct.pack_into('<H',header,63,1)
 path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(header+b''.join(level.tobytes() for level in reversed(levels)))
 # Header/payload validation independent of Source loading.
 assert path.stat().st_size==80+sum(t.width*t.height*4 for t in levels)
 return len(levels)
previews=[];generated=[]
for ref,key in sorted(needed.items()):
 name=Path(ref).stem;lut=key in ('$phongwarptexture','$lightwarptexture');normal=key=='$bumpmap';w,h=(256,16) if lut else (128,128)
 pixels=[]
 for y in range(h):
  for x in range(w):
   if lut:
    value=byte(255*(x/(w-1))**.85*(.8+.2*y/(h-1)));color=(value,value,value,255)
   elif normal:
    dx=(pattern('cloth',x+1,y,w)-pattern('cloth',x-1,y,w))*.002
    dy=(pattern('cloth',x,y+1,w)-pattern('cloth',x,y-1,w))*.002
    length=math.sqrt(dx*dx+dy*dy+1);color=(byte(127.5-dx/length*127.5),byte(127.5-dy/length*127.5),byte(127.5+127.5/length),255)
   else:
    value=byte(110+pattern(name,x,y,w)*.15 if key=='$phongexponenttexture' else pattern(name,x,y,w));color=(value,value,value,255)
   pixels.append(color)
 im=Image.new('RGBA',(w,h));im.putdata(pixels)
 rel='materials/'+ref;levels=vtf(out/rel,im,normal,lut);(src/rel).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(out/rel,src/rel)
 generated.append({'path':rel,'role':key,'size':[w,h],'mips':levels});previews.append((name,im))
canvas=Image.new('RGB',(768,math.ceil(len(previews)/4)*180),(20,20,24));d=ImageDraw.Draw(canvas)
for i,(name,im) in enumerate(previews):
 x=(i%4)*192;y=(i//4)*180;canvas.paste(im.resize((160,128)),(x+16,y+8));d.text((x+8,y+143),name[:27],fill=(225,220,218))
canvas.save(out/'shader-map-preview.png')
(out/'generated-maps.json').write_text(json.dumps(generated,indent=2))
(out/'README.md').write_text('SD material repair with original procedural shader maps. Includes tiling fabric, leather, dirt and brushed-metal details; soft Phong lookup; subtle generic normal maps and a neutral exponent map. Full mip chains for surface maps; clamped no-mip lookup texture. No Autonomous assets copied. Main clothing diffuse artwork stays unchanged. The absent APF diffuse uses the included city_suit texture as an approximation, not an authentic reconstruction. Patched SD models folder includes these files. Restart GMod after installation to clear cached materials.\n')
manifest['sdGeneratedMaps']=generated;(repo/'docs/autonomous-cleanup-deployment.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print('Generated',len(generated),'maps; restored',len(patched),'VMT definitions. Preview:',out/'shader-map-preview.png')

