const fs=require('fs');
const {normalize}=require('./glua.cjs');
const source=fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua','utf8');
const methods=source.slice(source.indexOf('function Item:Equip('),source.indexOf('\nif CLIENT then'));
module.exports=suite=>{
 suite('Legacy broken weapon condition migrates without losing identity; repeated wear cannot break it', [], `
 local item=setmetatable({id=42,durability=100,data={value=0,durability=5,regid='existing'}},{__index=Item})
 function item:GetData(k) return self.data[k] end
 function item:SetData(k,v) self.data[k]=v end
 function item:OnRemoved() error('weapon destroyed') end
 item:OnInstanced(false); eq(item.data.value,100); eq(item.data.durability,4); eq(item.data.regid,'existing')
 for i=1,1000 do item:AddDurability(-100) end
 eq(item.data.value,100); eq(item.data.durability,4)
 item.isFlamethrower=true;item:OnInstanced(true);eq(item.data.ammo,1000);eq(item.data.ammoType,'arc9_napalm')
 item.data.ammo=0;item:OnInstanced(false);eq(item.data.ammo,0)
 `,'Item={}\n'+normalize(source.slice(source.indexOf('function Item:AddDurability('),source.indexOf('function Item:Equip('))));

 const files=['tools/fixtures/arc9-inventory.lua','tools/fixtures/weapon-slots.lua','ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','ixhl2rp/plugins/ammo_cringe/sh_arc9.lua','ixhl2rp/plugins/ammo_cringe/sh_plugin.lua'];
 const setup='Item={}\n'+normalize(methods);
 suite('Flamethrower tanks persist empty across equip and only new items receive initial fuel',files,`
 local item=newItem();item.isFlamethrower=true;item.data.ammo=0;item.data.ammo2=0
 assert(item:Equip(p));local w=p:GetWeapon(item.class);eq(w.ARC9CODWW2FuelInitialized,true);eq(w:Clip1(),0)
 item:Unequip(p,false);assert(item:Equip(p));eq(p:GetWeapon(item.class):Clip1(),0)
 `,setup);
 suite('Disposable EFT item receives one shot and is removed only after firing completes',files,`
 local item=newItem(); item.isDisposableEFT=true; item.data.ammo=nil; item.data.ammo2=0
 assert(item:Equip(p)); local w=p:GetWeapon(item.class); eq(w:Clip1(),1)
 w:TakeAmmo(); eq(item.data.arc9Spent,true); eq(item.data.ammo,0)
 eq(ix.Item.instances[item.id],item); assert(w.valid)
 w:TakeAmmo(); flush(); eq(ix.Item.instances[item.id],nil); eq(w.valid,false)
 eq(item:Equip(p),false)
 `,setup);
 suite('ARC9 item equip restores both magazines and attachments without initialization grants',files,`
 local item=newItem(); item.data.arc9_atts={{Installed='custom',SubAttachments={{Installed='optic',ToggleNum=2}}}}
 p.carryWeapons.sidearm={valid=false}
 local rifle=newItem(2); rifle.weaponCategory='primary'; rifle.data.equip=true
 assert(item:Equip(p)); local w=p:GetWeapon(item.class)
 eq(w.clip,7); eq(w.clip2,1); eq(w.loaded,7); eq(w.ixItem,item); eq(item.data.equip,true)
 eq(w.Attachments[1].SubAttachments[1].Installed,'optic'); eq(w.sent,true)
 w:PostModify(); flush(); eq(w.clip,7)
 w:InitialDefaultClip(); eq(p:GetAmmoCount(0),0)
 eq(w:GetInfiniteAmmo(),false)
 w.clip=4; w.clip2=0; item:Unequip(p,false)
 eq(item.data.ammo,4); eq(item.data.ammo2,0); eq(item.data.equip,false)
 assert(item:Equip(p)); eq(p:GetWeapon(item.class).clip,4)
 `,setup);
 suite('Weapon slots keep failed grants and spent items safe without clearing another gun',files,`
 local item=newItem(); p.failGive=true; assert(item:Equip(p)); eq(item.inventory_type,'weapon1'); eq(#p.weapons,0)
 p.failGive=false; assert(ix.WeaponSlots.Activate(p,item)); local w=p:GetWeapon(item.class)
 item.data.arc9Spent=true; eq(item:Equip(p),false); assert(w.valid)
 local other=newItem(2); assert(other:Equip(p)); eq(item.data.arc9Spent,true)
 local external=p:Give('external',true); other.class='external'; eq(ix.WeaponSlots.Activate(p,other),false); assert(external.valid)
 `,setup);
 suite('ARC9 reserve settlement consumes exact stacks, handles ammo ID zero and prevents recount duplication',files,`
 local item=newItem(); local a=ammoItem('pistol',30); p:AddItem(a); assert(item:Equip(p))
 eq(p:GetAmmoCount(0),30)
 p.reserve[0]=23 -- seven rounds entered a magazine
 p:CalculateAmmo(); eq(a.data.stack,23); eq(p.reserve[0],23)
 p:CalculateAmmo(); eq(a.data.stack,23)
 p.reserve[0]=20; p:AddItem(ammoItem('pistol',10)); eq(p.reserve[0],30)
 p.reserve[0]=999; PLUGIN:PlayerTick(p); eq(p.reserve[0],30)
 item:Unequip(p,false); eq(p.reserve[0],30)
 p.dead=true; p.reserve[0]=0; PLUGIN:PlayerTick(p); eq(a.data.stack,20)
 `,setup);
 suite('ARC9 unload returns bounded item stacks and preserves ammunition when inventory is full',files,`
 local item=newItem(); assert(item:Equip(p)); local w=p:GetWeapon(item.class)
 w.clip=65; p.full=true; w:Unload('pistol')
 eq(w.clip,0); eq(w.loaded,0); eq(#dropped,3)
 eq(dropped[1].data.stack,30); eq(dropped[2].data.stack,30); eq(dropped[3].data.stack,5)
 w.clip=5; w:Unload('unsupported'); eq(w.clip,5)
 p.full=false; w.clip2=1; w.LastUBGLAmmo='smg1_grenade'; w.values.UBGL=false; w:PostModify()
 eq(w.clip2,0); eq(p:GetAmmoCount(2),1)
 `,setup);
 suite('ARC9 dropped weapons save their previous owner state and cannot strip an unrelated weapon',files,`
 local item=newItem(); assert(item:Equip(p)); local w=p:GetWeapon(item.class); w.clip=3
 function item:GetOwner() return nil end
 item:OnDrop(p,inv); eq(w.valid,false); eq(item.data.ammo,3); eq(item.data.equip,false)
 local unrelated=p:Give(item.class,true); item:OnRemoved(); eq(unrelated.valid,true)
 `,setup);
 suite('ARC9 grenade consumption blocks re-equip immediately and waits for projectile creation',files,`
 local item=newItem(); item.isGrenade=true; item.weaponCategory='grenade'; assert(item:Equip(p))
 local w=p:GetWeapon(item.class); eq(w.clip,1)
 PLUGIN:ARC9_Hook_GrenadeThrown(w,{delay=.4})
 eq(item.data.arc9Spent,true); eq(item:Equip(p),false); eq(w.valid,true)
 local n=#timers; PLUGIN:ARC9_Hook_GrenadeThrown(w,{delay=.4}); eq(#timers,n)
 PLUGIN:ARC9_Hook_GrenadeCreated(w); eq(#timers,n+1)
 flush(); eq(ix.Item.instances[item.id],nil); eq(w.valid,false)
 `,setup);
 suite('ARC9 character switches discard the previous reserve ledger and ignore stale load callbacks',files,`
 local item=newItem(); p:AddItem(ammoItem('pistol',30)); assert(item:Equip(p))
 local nextCharacter={}; p.character=nextCharacter; p.items={ammoItem('pistol',12)}; p.reserve[0]=0
 p:CalculateAmmo(); eq(p.reserve[0],12); eq(p.items[1].data.stack,12)
 PLUGIN:PlayerLoadedCharacter(p,nextCharacter)
 local third={}; p.character=third; p.items={ammoItem('pistol',8)}
 flush(); eq(p.ixAmmoReady,false)
 p:CalculateAmmo(); eq(p.reserve[0],8); eq(p.items[1].data.stack,8)
 `,setup);
 suite('ARC9 class or magazine changes refund old-caliber and excess rounds instead of converting them',files,`
 local item=newItem(); item.data.ammo=40; assert(item:Equip(p))
 local w=p:GetWeapon(item.class); eq(w.clip,17); eq(p:GetAmmoCount(0),23)
 item:Unequip(p,false); item.data.ammo=5; item.data.ammoType='buckshot'
 assert(item:Equip(p)); eq(p:GetWeapon(item.class).clip,0); eq(p:GetAmmoCount(1),5)
 item:Unequip(p,false); item.data.ammo=5; item.data.ammoType='unregistered_ammo'
 assert(item:Equip(p)); eq(ix.WeaponSlots.Activate(p,item),false); eq(item.data.ammo,5); eq(item.data.equip,true)
 `,setup);
 suite('ARC9 converted caliber survives a fresh weapon, delayed PostModify, relog and transfer without affecting another item',files,`
 local give=p.Give
 function p:Give(class,noAmmo)
  local w=give(self,class,noAmmo)
  local original=w.GetValue
  function w:GetValue(key)
   if self.Attachments[1] and self.Attachments[1].Installed=='conversion' then
    if key=='Ammo' then return 'buckshot' elseif key=='ClipSize' then return 8 end
   end
   return original(self,key)
  end
  w.GetProcessedValue=w.GetValue
  function w:GetCapacity(secondary) return secondary and 1 or self:GetValue('ClipSize') end
  function w:PruneAttachments() error('Saved item must not be pruned against another owner') end
  function w:FillIntegralSlots() error('Saved item must not receive defaults') end
  function w:PostModify()
   timer.Simple(0,function()
    if self.LastAmmo~=self:GetValue('Ammo') or self.LastClipSize~=self:GetValue('ClipSize') then self:Unload(self.LastAmmo) end
    self.LastAmmo=self:GetValue('Ammo'); self.LastClipSize=self:GetValue('ClipSize')
   end)
  end
  return w
 end
 local a=newItem(1); a.data.arc9_atts={{Installed='conversion',ToggleNum=2,SubAttachments={{Installed='optic'}}}}
 a.data.ammoType='buckshot'; a.data.ammo=6
 assert(a:Equip(p)); local w=p:GetWeapon(a.class); eq(w.clip,6); eq(w:GetValue('Ammo'),'buckshot')
 w:PostModify(); flush(); eq(w.clip,6)
 w.clip=4; a:Unequip(p,false); local saved=table.Copy(a.data)
 local b=newItem(2); assert(b:Equip(p)); eq(p:GetWeapon(b.class):GetValue('Ammo'),'pistol'); b:Unequip(p,false)
 a.data=table.Copy(saved); p.character={GetID=function() return 99 end}; assert(a:Equip(p))
 w=p:GetWeapon(a.class); eq(w.clip,4); eq(w:GetValue('Ammo'),'buckshot'); eq(w.Attachments[1].ToggleNum,2)
 w:PostModify(); flush(); eq(w.clip,4); eq(w.Attachments[1].SubAttachments[1].Installed,'optic')
 w.Attachments[1].SubAttachments[1].Installed='changed'; eq(saved.arc9_atts[1].SubAttachments[1].Installed,'optic')
 `,setup);
 suite('ARC9 missing attachment content refuses equip without destroying stored parts or converted rounds',files,`
 ARC9={GetAttTable=function() return nil end}
 local item=newItem(); item.data.arc9_atts={{Installed='missing_conversion'}}
 item.data.ammoType='buckshot'; item.data.ammo=5
 assert(item:Equip(p)); eq(ix.WeaponSlots.Activate(p,item),false); eq(item.data.ammo,5); eq(item.data.ammoType,'buckshot')
 eq(item.data.arc9_atts[1].Installed,'missing_conversion'); eq(#dropped,0)
 `,setup);
};
