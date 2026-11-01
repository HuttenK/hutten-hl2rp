"""Reproducible selected EFT addon export. Source pack is read-only."""
from pathlib import Path
import re,json,struct,shutil,hashlib,collections
SRC=Path(r'E:\tarkov guns')
OUT=Path(r'E:\tarkov_selected_server')
BASE=Path(r'C:\Users\q1236\Desktop\EFT base true')
ARC=Path(r'C:\Users\q1236\Desktop\arc9')
selected={
'ak12':('AK-12','rifle'),'ak74m':('AK-74M','rifle'),'m4a1':('M4A1','rifle'),'asval':('AS VAL','rifle'),'ash12':('ASh-12','rifle'),
'mp7a1':('MP7A1','smg'),'sr2m':('SR-2M','smg'),'pp1901':('PP-19-01 Vityaz','smg'),
'ai_axmc':('AI AXMC','rifle'),'mxlr':('Marlin MXLR','rifle'),'sv98':('SV-98','rifle'),
'mr153':('MP-153','shotgun'),'saiga12k':('Saiga-12K','shotgun'),'mr43_sawedoff':('Обрез MP-43','shotgun'),'aa12':('AA-12','shotgun'),
'deagle_xix':('Desert Eagle Mark XIX','pistol'),'glock17':('Glock 17','pistol'),'m1911':('M1911A1','pistol'),'pm':('ПМ','pistol'),'mp443':('MP-443 Грач','pistol'),'rsh12':('RSh-12','pistol'),
'm60e4':('M60E4','rifle'),'pkp':('ПКП Печенег','rifle'),'rangefinder':('Vortex Ranger 1500','device'),
'rsp30_red':('Сигнальный огонь — красный','disposable'),'rsp30_yellow':('Сигнальный огонь — жёлтый','disposable'),'rsp30_green':('Сигнальный огонь — зелёный','disposable'),
'sp81':('СП-81','flare'),'m32a1':('Milkor M32A1','launcher'),'rshg2':('РШГ-2','disposable'),
'zarya':('Заря','grenade'),'rgd5':('РГД-5','grenade'),'m67':('M67','grenade'),'m18y':('M18 — жёлтый дым','grenade'),
'melee_6x5':('6Х5','melee'),'melee_gladius':('TWG — APOK Gladius','melee'),'melee_kukri':('M48 Tactical Kukri','melee'),'melee_hultafors':('Dead Blow — Superfors DB 2020','melee'),'melee_crowbar':('Монтировка Freeman','melee')}
index={p.relative_to(SRC).as_posix().lower():p for p in SRC.rglob('*') if p.is_file()}
extindex={p.relative_to(root).as_posix().lower():str(root) for root in (BASE,ARC) for p in root.rglob('*') if p.is_file()}
strings=lambda s: re.findall(r'[\"\']([^\"\'\r\n]+)[\"\']',s)
def categories(s):
 return set(v for m in re.finditer(r'\bCategory\s*=\s*(\{[^}]*\}|[\"\'][^\"\']+[\"\'])',s) for v in strings(m.group(1)))
lua={k:p.read_text(encoding='utf-8-sig',errors='replace') for k,p in index.items() if k.endswith('.lua')}
bulks={k:(set(v for m in re.finditer(r'ATT\.Category\s*=\s*(\{[^}]*\}|[\"\'][^\"\']+[\"\'])',s) for v in strings(m.group(1))),s) for k,s in lua.items() if '/attachments_bulk/' in k}
keep=set();queue=collections.deque(); external=set();missing=set();why={}
def add(k,reason):
 k=k.replace('\\','/').lower().lstrip('/')
 if k in index:
  if k not in keep:keep.add(k);queue.append(k);why[k]=reason
  return True
 if k in extindex:external.add(k);return True
 return False
for key in selected:
 assert add('lua/weapons/arc9_eft_'+key+'.lua','selected weapon'),key
# ARC9 auto-loads these support scripts before weapon definitions. Their tables
# are referenced as globals, not include() paths (e.g. ARC9EFT.AK_Anims).
# Retain shared support modules even when no string-literal dependency finds them.
for k in lua:
 if re.fullmatch(r'lua/arc9/common/[^/]+\.lua', k):
  add(k, 'ARC9 auto-loaded shared support')
cats=set()
while True:
 while queue:
  k=queue.popleft();p=index[k]
  if k.endswith('.lua'):
   s=lua[k];cats.update(categories(s))
   parent=re.search(r'(?:SWEP|ENT)\.Base\s*=\s*[\"\']([^\"\']+)',s)
   if parent:
    add('lua/weapons/'+parent[1]+'.lua',k);add('lua/entities/'+parent[1]+'.lua',k)
   for v in strings(s):
    v=v.replace('\\','/'); low=v.lower().lstrip(')^(#@')
    if low.startswith(('arc9_eft_','sent_eft_')):
     add('lua/entities/'+low+'.lua',k)
    add('lua/effects/'+low+'/init.lua',k)
    for candidate in (low,'sound/'+low,'materials/'+low,'materials/'+low+'.vmt','lua/'+low):
     if add(candidate,k):break
    else:
     if low.endswith(('.mdl','.wav','.ogg','.mp3','.png','.vmt','.vtf')):missing.add(low)
     elif '/' in low and len(low)>8 and not ' ' in low:
      # Concatenated sound/material sequences: retain files sharing the literal prefix.
      for prefix in (low,'sound/'+low,'materials/'+low):
       for path in index:
        if path.startswith(prefix):add(path,k+' (dynamic prefix)')
  elif k.endswith('.mdl'):
   b=p.read_bytes()
   stem=k[:-4]
   for suffix in ('.vvd','.dx90.vtx','.dx80.vtx','.sw.vtx','.phy','.ani'):add(stem+suffix,k)
   if b[:4]!=b'IDST':raise ValueError(k)
   n,at,nd,dt=struct.unpack_from('<4i',b,204)
   def z(pos):return b[pos:b.find(b'\0',pos)].decode('utf-8',errors='replace').replace('\\','/')
   dirs=[z(struct.unpack_from('<i',b,dt+i*4)[0]) for i in range(nd)]
   for i in range(n):
    off=at+i*64;name=z(off+struct.unpack_from('<i',b,off)[0])
    found=False
    for d in dirs:
     found=add('materials/'+d.rstrip('/')+'/'+name+'.vmt',k) or found
    if not found:missing.add('model-material:'+k+':'+name)
   ni,ii=struct.unpack_from('<2i',b,336)
   for i in range(ni):
    off=ii+i*8; name=z(off+struct.unpack_from('<i',b,off+4)[0])
    if not add(name if name.startswith('models/') else 'models/'+name,k):missing.add(name)
  elif k.endswith('.vmt'):
   s=p.read_text(errors='replace')
   # VMT textures, patch includes and fallback materials; skip numeric values.
   for key,v in re.findall(r'"?([\w$]+)"?\s+"([^"\r\n]+)"',s):
    v=v.replace('\\','/').lower()
    if '/' not in v:continue
    if not any(add('materials/'+v+(ext if not v.endswith(('.vmt','.vtf','.png')) else ''),k) for ext in ('.vtf','.vmt','.png')):
     if 'texture' in key.lower() or key.lower()=='include':missing.add('materials/'+v)
 added=False
 for k,(c,s) in bulks.items():
  # File-level retention preserves helpers shared by registrations in a bulk file.
  if k not in keep and cats.intersection(c):add(k,'compatible attachment categories');added=True
 if not added:break
OUT.mkdir(exist_ok=True)
if (OUT/'selection-manifest.json').exists():
 old=json.loads((OUT/'selection-manifest.json').read_text(encoding='utf-8'))
 for entry in old['files']:
  if entry['path'] not in keep:
   obsolete=(OUT/entry['path']).resolve()
   assert obsolete.is_relative_to(OUT.resolve())
   if obsolete.is_file():obsolete.unlink()
manifest=[]
for k in sorted(keep):
 dest=OUT/k;dest.parent.mkdir(parents=True,exist_ok=True)
 if k.startswith('lua/weapons/') and Path(k).stem not in {'arc9_eft_'+v for v in selected}:
  dest.write_text(lua[k]+'\n-- Internal parent of selected weapons only.\nSWEP.Spawnable = false\n',encoding='utf-8')
 else:
  if not dest.exists() or dest.stat().st_size!=index[k].stat().st_size or dest.stat().st_mtime!=index[k].stat().st_mtime:shutil.copy2(index[k],dest)
 manifest.append({'path':k,'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'reason':why[k]})
shutil.copy2(SRC/'addon.json',OUT/'addon.json')
report={'selected':[{'class':'arc9_eft_'+k,'name':v[0],'type':v[1]} for k,v in selected.items()], 'files':manifest,'external':sorted(external),'unresolved':sorted(missing),'bytes':sum(x['bytes'] for x in manifest)}
(OUT/'selection-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'weapons':len(selected),'files':len(keep),'GB':report['bytes']/1e9,'external':len(external),'unresolved':len(missing)}))
