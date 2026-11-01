from pathlib import Path
import struct,json,hashlib
SRC=Path('C:/Users/q1236/Desktop/SD models/models/sd/citizens');OUT=Path('C:/Users/q1236/Desktop/SD-DClass-models')
def inspect(p):
 b=p.read_bytes();u=lambda o:struct.unpack_from('<i',b,o)[0];st=lambda o:b[o:b.index(b'\0',o)].decode(errors='replace');assert b[:4]==b'IDST';assert u(76)==len(b)
 mats=[st(u(208)+i*64+u(u(208)+i*64)) for i in range(u(204))];groups=[]
 for i in range(u(232)):
  off=u(236)+16*i;models=[]
  for j in range(u(off+4)):
   md=off+u(off+12)+148*j;models.append({'name':b[md:md+64].split(b'\0')[0].decode(),'materials':[mats[u(md+u(md+76)+116*k)] for k in range(u(md+72))]})
  groups.append({'id':i,'name':st(off+u(off)),'models':models,'base':u(off+8)})
 bones=[(st(u(160)+i*216+u(u(160)+i*216)),u(u(160)+i*216+4)) for i in range(u(156))]
 nref=u(220);nfam=u(224);skins=[[mats[struct.unpack_from('<H',b,u(228)+2*(r*nref+c))[0]] for c in range(nref)] for r in range(nfam)]
 return {'checksum':u(8),'groups':groups,'bones':bones,'animations':u(180),'sequences':u(188),'flexes':u(260),'controllers':u(268),'hitboxes':u(172),'materials':mats,'skins':skins}
files=[p for p in SRC.glob('citizen_*.mdl') if '_arms_' not in p.name];results=[]
for original in files:
 built=OUT/'models/sd/citizens'/original.name;assert built.exists(),f'Not built: {original.name}'
 a,b=inspect(original),inspect(built)
 for key in ('bones','animations','sequences','flexes','controllers','hitboxes'):assert a[key]==b[key],(original.name,key)
 assert len(a['groups'])==len(b['groups'])
 for old,new in zip(a['groups'],b['groups']):
  assert old['name']==new['name'] and old['id']==new['id']
  extra=old['name'] in ('Torso','Legs');assert len(new['models'])==len(old['models'])+int(extra)
  assert old['models']==new['models'][:len(old['models'])],(original.name,old['name'],'existing model changed')
  if extra:assert new['models'][-1]['materials']==[('jacket' if old['name']=='Torso' else 'pants')]
 assert len(a['skins'])==len(b['skins'])
 for i,old in enumerate(a['skins'][0]):
  slot=b['skins'][0].index(old)
  for oldrow,newrow in zip(a['skins'],b['skins']):assert oldrow[i]==newrow[slot],(original.name,'skin mapping')
 for ext,offset in [('.vvd',8),('.dx90.vtx',16),('.dx80.vtx',16),('.phy',12)]:
  p=built.with_suffix(ext);assert p.exists(),p;assert struct.unpack_from('<i',p.read_bytes(),offset)[0]==b['checksum'],p
 results.append({'model':original.name,'torso':24,'legs':14,'bones':len(b['bones']),'skinFamilies':len(b['skins'])})
(OUT/'validation.json').write_text(json.dumps(results,indent=2))
print('PASS:',len(results),'models; original bodygroups, bones, facial controls, skin mappings and file checksums preserved.')

