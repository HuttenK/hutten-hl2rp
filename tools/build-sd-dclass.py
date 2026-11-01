from pathlib import Path
import subprocess,concurrent.futures,re,json,struct,io,shutil
from PIL import Image
WORK=Path('C:/Users/q1236/Desktop/SD-DClass-work'); SRC=Path('C:/Users/q1236/Desktop/SD models'); OUT=Path('C:/Users/q1236/Desktop/SD-DClass-models'); OUT.mkdir(exist_ok=True)
CROW=WORK/'tools/crowbar/CrowbarDecompiler(1.1).exe';COMP=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/bin/studiomdl.exe')
GEN=Path('C:/Users/q1236/.codex/generated_images/01a0af77-7b63-7de0-8e91-c3f54d495190')
for name,file,normal in [('jacket','exec-7ad13091-a62b-4503-b41e-5a6dd451a141.png','city_top3_n'),('pants','exec-34ea8df0-71e6-4acd-be4c-05d1deec1ee0.png','city_top_n')]:
 shutil.copy2(GEN/file,WORK/'textures'/('dclass_'+name+'.png'))
 im=Image.open(GEN/file).convert('RGB').resize((2048,2048),Image.Resampling.LANCZOS);levels=[];sizes=[]
 while True:
  buf=io.BytesIO();im.save(buf,format='DDS',pixel_format='DXT1');payload=buf.getvalue()[128:];assert len(payload)==max(1,(im.width+3)//4)*max(1,(im.height+3)//4)*8
  levels.append(payload);sizes.append(im.size)
  if im.width==1:break
  im=im.resize((max(1,im.width//2),max(1,im.height//2)),Image.Resampling.BOX)
 h=bytearray(80);h[:4]=b'VTF\0';struct.pack_into('<III',h,4,7,2,80);struct.pack_into('<HHIHH',h,16,2048,2048,0,1,0);struct.pack_into('<fff',h,32,.5,.5,.5);struct.pack_into('<fI',h,48,1,13);h[56]=len(levels);struct.pack_into('<I',h,57,0xffffffff);struct.pack_into('<H',h,63,1)
 mat=OUT/'materials/models/legends/dclass';mat.mkdir(parents=True,exist_ok=True);(mat/(name+'.vtf')).write_bytes(h+b''.join(reversed(levels)))
 (mat/(name+'.vmt')).write_text('"VertexLitGeneric"\n{\n "$basetexture" "models/legends/dclass/'+name+'"\n "$bumpmap" "models/sectorialdistrict/citizens/'+normal+'"\n "$detail" "models/sectorialdistrict/metropolice/detail_cloth"\n "$detailscale" "12"\n "$detailblendfactor" "0.25"\n "$detailblendmode" "0"\n "$phong" "1"\n "$phongexponent" "8"\n "$phongboost" "0.08"\n "$phongfresnelranges" "[0.1 0.3 0.8]"\n}\n')
models=sorted((SRC/'models/sd/citizens').glob('citizen_*.mdl'));models=[p for p in models if '_arms_' not in p.name]
logs=WORK/'logs';logs.mkdir(exist_ok=True)
def build(model):
 folder=WORK/'source'/model.stem;folder.mkdir(parents=True,exist_ok=True)
 qc=folder/(model.stem+'.qc')
 if not qc.exists():
  r=subprocess.run([str(CROW),str(model),str(folder)],capture_output=True,creationflags=0x08000000)
  (logs/(model.stem+'-decompile.log')).write_bytes(r.stdout+r.stderr)
 if not qc.exists():raise RuntimeError('Decompile failed '+model.name)
 existing=OUT/'models/sd/citizens'/model.name
 expected=(folder/'legs_jeans.smd').read_text()
 expected=re.sub(r'(?m)^city_top\s*$','pants',expected)
 if existing.exists() and existing.stat().st_mtime>=qc.stat().st_mtime and (folder/'legs_dclass.smd').exists() and (folder/'legs_dclass.smd').read_text()==expected:
  return model.name+' (verified current build reused)'
 s=qc.read_text();s=re.sub(r'\$modelname\s+"[^"]+"',f'$modelname "sd/citizens/{model.name}"',s)
 for group,source,dest,material in [('Torso','torso_jacket_1.smd','torso_dclass.smd','jacket'),('Legs','legs_jeans.smd','legs_dclass.smd','pants')]:
  smd=(folder/source).read_text();smd=re.sub(r'(?m)^city_top3\s*$', 'jacket',smd) if material=='jacket' else re.sub(r'(?m)^city_top\s*$','pants',smd)
  (folder/dest).write_text(smd)
  pattern=r'(\$bodygroup "'+group+r'"\s*\{)([^}]*)(\})'
  def append(m):return m[1]+m[2].replace('\tstudio "'+dest+'"\n','')+'\tstudio "'+dest+'"\n'+m[3]
  s,n=re.subn(pattern,append,s);assert n==1,(model,group)
 sex='f' if 'female' in model.name else 'm'
 s=re.sub(r'\$includemodel "cellar/[^"\n]+"',f'$includemodel "player/{sex}_anm.mdl"',s)
 s=s.replace('$includemodel "sd/shared_customanims.mdl"','// This library is not included in the supplied SD addon.')
 if '$cdmaterials "models/legends/dclass/"' not in s:s+='\n$cdmaterials "models/legends/dclass/"\n'
 qc.write_text(s)
 r=subprocess.run([str(COMP),'-nop4','-game',str(WORK/'game'),str(qc)],capture_output=True,creationflags=0x08000000)
 text=(r.stdout+r.stderr).decode(errors='replace');(logs/(model.stem+'-compile.log')).write_text(text)
 if r.returncode!=0 or 'ERROR:' in text or 'Completed "' not in text:raise RuntimeError('Compile failed '+model.name+' see log')
 dest=OUT/'models/sd/citizens';dest.mkdir(parents=True,exist_ok=True)
 files=list((WORK/'game/models/sd/citizens').glob(model.stem+'.*'));assert len(files)>=4
 for p in files:shutil.copy2(p,dest/p.name)
 return model.name
# First validate one male and female compile before the full batch.
first=[next(p for p in models if p.name=='citizen_male_04_hair4.mdl'),next(p for p in models if p.name=='citizen_female_01_hair1.mdl')]
for p in first:print('BUILT',build(p),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for result in pool.map(build,[p for p in models if p not in first]):print('BUILT',result,flush=True)
(OUT/'addon.json').write_text(json.dumps({'title':'SD Citizens - D-Class Clothing','type':'model','tags':['roleplay'],'ignore':['*.md','*.json','clothing-preview.png']},indent=2))
print('COMPLETE',len(models),'models',flush=True)
