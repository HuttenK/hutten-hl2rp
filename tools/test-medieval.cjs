const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');let passed=0;
function suite(name,files,assertions,setup=''){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const prelude=fs.readFileSync(path.join(__dirname,'fixtures/medieval.lua'),'utf8');
 const source=[prelude,setup,...files.map(f=>`do\n${normalize(fs.readFileSync(path.join(root,f),'utf8'))}\nend`),assertions].join('\n');
 const code=lauxlib.luaL_dostring(L,to_luastring(source));
 if(code!==lua.LUA_OK){fs.mkdirSync(path.join(root,'.runtime'),{recursive:true});fs.writeFileSync(path.join(root,'.runtime/failed-test.lua'),source);throw new Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));}
 passed++;console.log('PASS '+name);
}
const src=fs.readFileSync(path.join(root,'ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua'),'utf8');
const methods='Item={}\n'+normalize(src.slice(src.indexOf('function Item:Equip('),src.indexOf('\nif CLIENT then')));
const weapons=['tools/fixtures/medieval-weapons.lua','tools/fixtures/weapon-slots.lua','ixhl2rp/plugins/ammo_cringe/sh_ammo.lua','ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','ixhl2rp/plugins/ammo_cringe/sh_plugin.lua'];
suite('Empty slot draws hands and preserves the equipped item and loaded bolt',weapons,`
 local W=ix.WeaponSlots;local a=newItem(1);assert(W.Equip(p,a,1));local w=W.Live(p,a)
 local hands=p:Give('ix_hands',true);assert(W.Holster(p,2));eq(p:GetActiveWeapon(),hands)
 eq(W.Item(p,1),a);eq(W.Live(p,a),w);eq(w:Clip1(),1)
 assert(W.Activate(p,a));eq(p:GetActiveWeapon(),w)
 eq(W.Holster(p,1),false);eq(W.Holster(p,1.5),false)
 p.bUsingMedical=true;eq(W.Holster(p,2),false)
`,methods);
suite('Duplicate SWEP classes keep separate saved clips; full bags refuse unequip',weapons,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2);b.data.ammo=0
 assert(W.Equip(p,a,1));assert(W.Equip(p,b,2));eq(a:GetData('ammo'),1);eq(W.Live(p,b):Clip1(),0)
 assert(W.Activate(p,a));eq(W.Live(p,a):Clip1(),1);eq(b:GetData('ammo'),0)
 local w=W.Live(p,a);p.full=true;eq(W.Unequip(p,a),false);eq(W.Live(p,a),w)
 p.full=false;assert(W.Unequip(p,a));eq(W.Live(p,a),nil);eq(a:GetData('ammo'),1)
`,methods);
suite('Slot transfers enforce size and ownership and refuse weapons busy with an action',weapons,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2);b.weaponCategory='melee'
 eq(W.Equip(p,a,3),false);eq(W.Equip(p,b,1),false);assert(W.Equip(p,b,3));assert(W.Equip(p,a,1))
 local w=W.Live(p,a);w.nextFire=clock+1;eq(W.Unequip(p,a),false);w.nextFire=0
 local owner=p.inventories.weapon2.owner;p.inventories.weapon2.owner={}
 eq(W.Transfer(p,a,p.inventories.weapon2),false);p.inventories.weapon2.owner=owner
 p.dead=true;eq(W.Activate(p,a),false)
`,methods);
suite('A reload followed by inventory recount cannot duplicate ammunition',weapons,`
 local item=ammoItem(8);p:AddItem(item);local a=newItem(1);assert(ix.WeaponSlots.Equip(p,a,1))
 p:CalculateAmmo();eq(p:GetAmmoCount(0),8)
 p:SetAmmo(7,0);p:CalculateAmmo();eq(item:GetValue(),7);eq(p:GetAmmoCount(0),7)
 p:CalculateAmmo();eq(item:GetValue(),7)
 p:SetAmmo(99,0);p:CalculateAmmo();eq(item:GetValue(),7);eq(p:GetAmmoCount(0),7)
`,methods);
suite('Ammo return preserves overflow and rejects unknown ammo without inventing an item',weapons,`
 p.full=true;assert(ix.weaponInventory.ReturnAmmo(p,'XBowBolt',13));eq(#dropped,2)
 eq(dropped[1]:GetValue()+dropped[2]:GetValue(),13)
 eq(ix.weaponInventory.ReturnAmmo(p,'missing_type',1),false);eq(#dropped,2)
`,methods);
suite('Bandages stop bleeding on the selected limb; splints target fractures only',
 ['ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sv_treatment.lua'],`
 local M=ix.Medicine
 local diffs={}
 local health={body={parts={[1]={hitgroup=4},[2]={hitgroup=6}}}}
 function health:GetHediffs() return ipairs(diffs) end
 function health:RemoveHediffByID(id) self.removed=id end
 function health:OnUpdateDiffs() end;function health:GetBleedRate() return 0 end
 local char={Health=function() return health end};local target={GetCharacter=function() return char end}
 local function injury(id,part,fracture)
  local d={id=id,part=part,isInjury=true,isFracture=fracture,severity=5,bleedRate=1,tended_time=-1}
  function d:GetSeverity() return self.severity end;function d:SetSeverity(n) self.severity=n end
  return d
 end
 diffs={injury(1,1,false),injury(2,2,false),injury(3,2,true)}
 M.Sync=function() end
 assert(M.Eligible({uniqueID='bandage'},target,4))
 M.Apply({uniqueID='bandage'},target,nil,4);eq(diffs[1].tended_time,0);eq(diffs[2].tended_time,-1)
 eq(diffs[3].tended_time,-1);eq(M.Eligible({uniqueID='splint'},target,4),false)
 M.Apply({uniqueID='splint'},target,nil,6);eq(health.removed,3)
 eq(M.Eligible({uniqueID='adrenaline'},target,0),false)
`);
suite('Context poses depend only on valid treatment or owned cargo, without device services',
 ['ixhl2rp/plugins/action_animations/sv_actions.lua'],`
 local A=ix.ActionAnimations
 local character={};local crate={valid=true,GetClass=function() return 'ix_cargo_crate' end}
 local p={valid=true,GetCharacter=function() return character end,GetLocalVar=function() return crate end}
 eq(A.Select(p),'');crate.ixHeldOwner=p;eq(A.Select(p),'carry')
 local patient={valid=true};p.ixMedicalSession={emoteStarted=true,character=character,target=patient}
 local kind,target=A.Select(p);eq(kind,'medical');eq(target,patient)
 p.ixMedicalSession.finishing=true;eq(A.Select(p),'carry')
 A.enabled=false;eq(A.Select(p),'')
 `,`
 ix.ActionAnimations={enabled=true,Conflict=function() return false end,WeaponAllows=function() return true end}
 ix.Medicine={ValidSession=function() return true end}
 `);
require('./test-sd-creation.cjs')(suite);
require('./test-medieval-ui.cjs')(suite);
console.log(`${passed} medieval behavioral suites passed. Engine rendering/network timing still require GMod.`);
