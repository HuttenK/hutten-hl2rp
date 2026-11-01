"""Offline skinning of archived SD SMDs with production Lua bone callback output.
This checks bind-rig anatomy, not live Source animation blending or rendering.
"""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent.parent
source=Path('E:/Codex-Archives/HL2RP-2026-09-26/Desktop/SD-DClass-work/source/male04')
rig=json.loads((root/'tools/sectorial-hand-rig.json').read_text())['bones']
bind={}; pose={}
for b in rig:
 x,y,z=b['rotation'];cx,sx=math.cos(x),math.sin(x);cy,sy=math.cos(y),math.sin(y);cz,sz=math.cos(z),math.sin(z)
 m=np.eye(4);m[:3,:3]=np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])@np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])@np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
 m[:3,3]=b['position'];bind[b['id']]=bind[b['parent']]@m if b['parent']>=0 else m
for line in (root/'docs/pda-pose-matrices.csv').read_text().splitlines():
 a=list(map(float,line.split(',')));m=np.eye(4);m[:3,3]=a[1:4];m[:3,:3]=np.array(a[4:]).reshape(3,3).T;pose[int(a[0])]=m
delta={i:pose[i]@np.linalg.inv(m) for i,m in bind.items()}
triangles=[]
for filename,color in [('torso_jacket_1.smd',(92,116,128)),('legs_jeans.smd',(64,77,91)),('hands_1.smd',(204,165,133)),('male_04_reference.smd',(179,146,119))]:
 lines=(source/filename).read_text().split('triangles\n')[1].splitlines()
 for i in range(0,len(lines)-3,4):
  vertices=[]
  for line in lines[i+1:i+4]:
   a=list(map(float,line.split()));v=np.array(a[1:4]+[1]);links=int(a[9]) if len(a)>9 else 0
   weights=[(int(a[10+j*2]),a[11+j*2]) for j in range(links)] if links else [(int(a[0]),1)]
   vertices.append(sum((delta[b]@v)*w for b,w in weights)[:3])
  triangles.append((np.array(vertices),np.array(color)))
# A tablet occupies the measured display frame used by the world-model code.
corners=np.array([(x,y,z,1) for z in (-.6,0) for y in (-4.4,4.4) for x in (-3.2,3.2)])
corners=(pose[-1]@corners.T).T[:,:3]
for ids in [(4,5,7),(4,7,6),(0,2,3),(0,3,1),(0,1,5),(0,5,4),(2,6,7),(2,7,3),(0,4,6),(0,6,2),(1,3,7),(1,7,5)]:
 triangles.append((corners[list(ids)],np.array((35,193,187) if ids[0]==4 else (29,43,50))))
w,h=600,760;canvas=Image.new('RGB',(w*3,h+75),(11,19,27));draw=ImageDraw.Draw(canvas)
for panel,(yaw,label) in enumerate([(0,'FRONT / SD bind rig'),(80,'SIDE / SD bind rig'),(35,'THREE QUARTER / SD bind rig')]):
 a=math.radians(yaw);view=np.array([math.cos(a),math.sin(a),.23]);view/=np.linalg.norm(view)
 right=np.cross([0,0,1],view);right/=np.linalg.norm(right);up=np.cross(view,right)
 rgb=np.full((h,w,3),[21,31,42],dtype=np.uint8);depth=np.full((h,w),-np.inf)
 center=np.array([6,0,40]);scale=10
 for v,col in triangles:
  relative=v-center;x=w/2-relative@right*scale;y=h/2-relative@up*scale;z=relative@view
  xmin=max(0,int(np.floor(x.min())));xmax=min(w-1,int(np.ceil(x.max())));ymin=max(0,int(np.floor(y.min())));ymax=min(h-1,int(np.ceil(y.max())))
  if xmin>xmax or ymin>ymax:continue
  den=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
  if abs(den)<1e-8:continue
  yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1];xx=xx+.5;yy=yy+.5
  aa=((y[1]-y[2])*(xx-x[2])+(x[2]-x[1])*(yy-y[2]))/den;bb=((y[2]-y[0])*(xx-x[2])+(x[0]-x[2])*(yy-y[2]))/den;cc=1-aa-bb
  zz=aa*z[0]+bb*z[1]+cc*z[2];region=depth[ymin:ymax+1,xmin:xmax+1];mask=(aa>=0)&(bb>=0)&(cc>=0)&(zz>region)
  normal=np.cross(v[1]-v[0],v[2]-v[0]);normal/=max(np.linalg.norm(normal),1e-8)
  light=.5+.5*abs(normal@np.array([.6,-.4,.68]));rgb[ymin:ymax+1,xmin:xmax+1][mask]=np.clip(col*light,0,255).astype(np.uint8);region[mask]=zz[mask]
 canvas.paste(Image.fromarray(rgb),(panel*w,45));draw.text((panel*w+20,15),label,fill=(185,227,230))
draw.text((20,h+53),'Offline production pose on original SD skin weights; neutral bind body. Engine animation still requires an in-game check.',fill=(185,227,230))
output=root/'docs/pda-pose-validation.png';canvas.save(output);print(output)
