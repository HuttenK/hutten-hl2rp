"""Render authored starter poses on original SD mesh weights, without GMod."""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent.parent
source=Path('E:/Codex-Archives/HL2RP-2026-09-26/Desktop/SD-DClass-work/source/male04')
rig=json.loads((ROOT/'tools/sectorial-hand-rig.json').read_text())['bones']
bind={}
for b in rig:
    x,y,z=b['rotation'];cx,sx=math.cos(x),math.sin(x);cy,sy=math.cos(y),math.sin(y);cz,sz=math.cos(z),math.sin(z)
    m=np.eye(4);m[:3,:3]=np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])@np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])@np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    m[:3,3]=b['position'];bind[b['id']]=bind[b['parent']]@m if b['parent']>=0 else m
mesh=[]
for filename,color in [('torso_jacket_1.smd',(92,116,128)),('legs_jeans.smd',(64,77,91)),('hands_1.smd',(204,165,133)),('male_04_reference.smd',(179,146,119))]:
    lines=(source/filename).read_text().split('triangles\n')[1].splitlines()
    for i in range(0,len(lines)-3,4):
        vertices=[]
        for line in lines[i+1:i+4]:
            a=list(map(float,line.split()));v=np.array(a[1:4]+[1]);links=int(a[9]) if len(a)>9 else 0
            weights=[(int(a[10+j*2]),a[11+j*2]) for j in range(links)] if links else [(int(a[0]),1)]
            vertices.append((v,weights))
        mesh.append((vertices,np.array(color)))
w,h=280,440
poses=json.loads((ROOT/'docs/pose-starter-matrices.json').read_text())
canvas=Image.new('RGB',(w*8,h*2+70),(11,19,27));draw=ImageDraw.Draw(canvas)
for idx,pose in enumerate(poses):
    delta={i:np.array(pose['world'][str(i)])@np.linalg.inv(m) for i,m in bind.items()}
    triangles=[(np.array([sum((delta[b]@v)*weight for b,weight in weights)[:3] for v,weights in vertices]),color) for vertices,color in mesh]
    for panel,yaw in enumerate([25,145]):
        a=math.radians(yaw);view=np.array([math.cos(a),math.sin(a),.18]);view/=np.linalg.norm(view)
        right=np.cross([0,0,1],view);right/=np.linalg.norm(right);up=np.cross(view,right)
        rgb=np.full((h,w,3),[21,31,42],dtype=np.uint8);depth=np.full((h,w),-np.inf)
        center=np.array([4,0,35]);scale=5.5
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
        canvas.paste(Image.fromarray(rgb),(idx*w,35+panel*h))
    draw.text((idx*w+10,12),pose['label'],fill=(185,227,230))
draw.text((15,h*2+45),'OFFLINE SD MESH STUDY / front and rear / no textures / live model and clothing checks still required',fill=(185,227,230))
path=ROOT/'docs/pose-starter-preview.png';canvas.save(path);print(path)
