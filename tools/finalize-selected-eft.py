from pathlib import Path
import json,hashlib,shutil
OUT=Path(r'E:\tarkov_selected_server'); SRC=Path(r'E:\tarkov guns')
r=json.loads((OUT/'selection-manifest.json').read_text(encoding='utf-8'))
ammos={'rifle':'XBowBolt','smg':'SMG1','shotgun':'Buckshot','pistol':'Pistol','flare':'ix_eft_flare','launcher':'SMG1_Grenade','disposable':'','grenade':'Grenade','melee':'','device':''}
classes={x['class']:ammos[x['type']] for x in r['selected']}
for e in r['selected']:
 p=OUT/'lua/weapons'/(e['class']+'.lua');s=p.read_text(encoding='utf-8').split('-- IX selected pack ammunition policy')[0]
 s+='\n-- IX selected pack ammunition policy\nSWEP.Ammo = '+json.dumps(classes[e['class']])+'\n'
 if e['type']=='disposable':s+='SWEP.BottomlessClip = false\nSWEP.ClipSize = 1\nSWEP.ChamberSize = 0\nSWEP.SupplyLimit = 0\n'
 p.write_text(s,encoding='utf-8')
helper='''if SERVER then AddCSLuaFile() end
-- Generic categories intentionally stay fixed through caliber conversions.
local ammoByClass = %s
game.AddAmmoType({name="ix_eft_flare",dmgtype=DMG_GENERIC,tracer=TRACER_NONE,plydmg=0,npcdmg=0,force=0,maxcarry=24})
if CLIENT then language.Add("ix_eft_flare_ammo","Сигнальные патроны 26×75 мм") end
hook.Add("ARC9_AmmoHook","ixSelectedEFTAmmo",function(weapon)
 return ammoByClass[weapon:GetClass()]
end)
''' % ('{\n'+''.join(' ["'+k+'"]='+json.dumps(v)+',\n' for k,v in classes.items())+'}')
p=OUT/'lua/autorun/ix_selected_eft_ammo.lua';p.parent.mkdir(exist_ok=True);p.write_text(helper,encoding='utf-8')
s=SRC/'lua/effects/eft_explosion_round';d=OUT/'lua/effects/eft_explosion_round';shutil.copytree(s,d,dirs_exist_ok=True)
(OUT/'addon.json').write_text(json.dumps({'title':'Selected EFT Weapons - Legends','type':'weapon','tags':['realism','roleplay'],'ignore':['*.md','selection-manifest.json','dependency-audit.json']},indent=2),encoding='utf-8')
entries=[]
for p in OUT.rglob('*'):
 if p.is_file() and p.suffix not in ('.json','.md'):
  entries.append({'path':p.relative_to(OUT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
r['files']=sorted(entries,key=lambda x:x['path']);r['bytes']=sum(x['bytes'] for x in entries);r['ammo']=classes
(OUT/'selection-manifest.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
print('Final files',len(entries),'GB',round(r['bytes']/1e9,3))
