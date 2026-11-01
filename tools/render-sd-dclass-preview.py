from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
work=Path('C:/Users/q1236/Desktop/SD-DClass-work')
tex={k:np.asarray(Image.open(work/'textures'/('dclass_'+k+'.png')).convert('RGB')) for k in ('jacket','pants')}
def tris(p):
 lines=p.read_text().split('triangles\n')[1].splitlines()
 for i in range(0,len(lines)-3,4):yield np.array([list(map(float,v.split()[:9])) for v in lines[i+1:i+4]])
w,h=400,660;canvas=Image.new('RGB',(w*4,h+65),(17,19,22));d=ImageDraw.Draw(canvas)
for panel,(sex,side) in enumerate([('male04',-1),('male04',1),('female01',-1),('female01',1)]):
 rgb=np.full((h,w,3),[28,30,34],dtype=np.uint8);depth=np.full((h,w),-np.inf)
 for kind,filename in [('jacket','torso_jacket_1.smd'),('pants','legs_jeans.smd')]:
  t=tex[kind]
  for v in tris(work/'source'/sex/filename):
   x=w/2-side*v[:,1]*7.7;y=h-25-v[:,3]*8.5;z=side*v[:,2]
   xmin=max(0,int(np.floor(x.min())));xmax=min(w-1,int(np.ceil(x.max())));ymin=max(0,int(np.floor(y.min())));ymax=min(h-1,int(np.ceil(y.max())))
   if xmin>xmax or ymin>ymax:continue
   den=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
   if abs(den)<1e-8:continue
   yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1];xx=xx+.5;yy=yy+.5
   a=((y[1]-y[2])*(xx-x[2])+(x[2]-x[1])*(yy-y[2]))/den;b=((y[2]-y[0])*(xx-x[2])+(x[0]-x[2])*(yy-y[2]))/den;c=1-a-b
   zz=a*z[0]+b*z[1]+c*z[2];region=depth[ymin:ymax+1,xmin:xmax+1];mask=(a>=0)&(b>=0)&(c>=0)&(zz>region)
   if not mask.any():continue
   u=a*v[0,7]+b*v[1,7]+c*v[2,7];vv=a*v[0,8]+b*v[1,8]+c*v[2,8]
   tx=np.clip((u*t.shape[1]).astype(int),0,t.shape[1]-1);ty=np.clip(((1-vv)*t.shape[0]).astype(int),0,t.shape[0]-1)
   normals=v[:,4:7].mean(axis=0);lighting=.67+.33*max(0,float(normals@np.array([.2,side*.7,.6])))
   col=np.clip(t[ty,tx]*lighting,0,255).astype(np.uint8);rgb[ymin:ymax+1,xmin:xmax+1][mask]=col[mask];region[mask]=zz[mask]
 canvas.paste(Image.fromarray(rgb),(panel*w,50));d.text((panel*w+20,15),('MALE' if sex=='male04' else 'FEMALE')+(' / FRONT' if side<0 else ' / BACK'),fill=(230,225,215))
canvas.save(work/'dclass-mesh-preview.png');print(work/'dclass-mesh-preview.png')
