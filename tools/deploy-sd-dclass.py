from pathlib import Path
import subprocess,json,shutil,datetime,hashlib
ROOT=Path(__file__).resolve().parent.parent; OUT=Path('C:/Users/q1236/Desktop/SD-DClass-models');LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
# Refuse partial deployment: all model checks must pass first.
subprocess.run(['py','-3',str(ROOT/'tools/validate-sd-dclass.py')],check=True)
models=[p for p in (OUT/'models/sd/citizens').glob('citizen_*.mdl') if '_arms_' not in p.name];assert len(models)==47
backup=Path('C:/Users/q1236/Desktop')/('sd-dclass-live-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'));records=[]
paths=[]
for model in models:
 paths.extend(model.with_suffix(ext) for ext in ('.mdl','.vvd','.dx90.vtx','.dx80.vtx','.phy'))
paths.extend((OUT/'materials/models/legends/dclass').glob('*'))
for source in paths:
 rel=source.relative_to(OUT);dest=(LIVE/rel).resolve();assert dest.is_relative_to(LIVE)
 if dest.exists():
  b=backup/rel;b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,b)
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(source)==sha(dest)
 records.append({'path':rel.as_posix(),'sha256':sha(dest)})
plugin=ROOT/'ixhl2rp/plugins/sd_material_repair/sh_plugin.lua';b=backup/'gamemode-source'/plugin.relative_to(ROOT);b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(plugin,b)
s=plugin.read_text(encoding='utf8').split('-- D-Class bodygroup assets')[0]
s+='\n-- D-Class bodygroup assets\nif SERVER then\n'+''.join(' resource.AddFile("'+r['path']+'")\n' for r in records)+'end\n';plugin.write_text(s,encoding='utf8')
dest=LIVE/'gamemodes'/plugin.relative_to(ROOT)
if dest.exists():
 b=backup/'gamemodes'/plugin.relative_to(ROOT);b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,b)
shutil.copy2(plugin,dest);assert plugin.read_bytes()==dest.read_bytes()
m=json.loads((OUT/'addon.json').read_text());m['ignore']=list(dict.fromkeys(m.get('ignore',[])+['clothing-preview.png']));(OUT/'addon.json').write_text(json.dumps(m,indent=2))
report={'backup':str(backup),'addon':str(OUT),'deployed':records,'modelCount':47,'bodygroups':{'Torso':{'id':4,'value':24},'Legs':{'id':7,'value':14}}}
(ROOT/'docs/sd-dclass-deployment.json').write_text(json.dumps(report,indent=2));print('Deployed',len(records),'files; backup',backup)
