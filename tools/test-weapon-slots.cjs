const fs = require('fs');
const {normalize} = require('./glua.cjs');
const source = fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua','utf8');
const methods = source.slice(source.indexOf('function Item:Equip('), source.indexOf('\nif CLIENT then'));
const files = ['tools/fixtures/arc9-inventory.lua','tools/fixtures/weapon-slots.lua',
 'ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','ixhl2rp/plugins/ammo_cringe/sh_arc9.lua','ixhl2rp/plugins/ammo_cringe/sh_plugin.lua'];
const setup = 'Item={}\n'+normalize(methods);
module.exports = suite => {
 suite('Empty slot selection holsters the rifle without removing its equipment or ammunition',files,`
 local W=ix.WeaponSlots;local rifle=newItem(1);assert(W.Equip(p,rifle,1))
 local gun=W.Live(p,rifle);gun.clip=11;gun.Attachments={{Installed='scope'}}
 local hands=p:Give('ix_hands',true)
 local function select(slot,id)
  p.ixNextWeaponSlot=nil;local values={slot,id}
  net.ReadUInt=function() return table.remove(values,1) end
  net.handlers.ixWeaponSlotDraw(34,p)
 end
 select(2,0);eq(p:GetActiveWeapon(),hands)
 eq(W.Item(p,1),rifle);eq(W.Live(p,rifle),gun);eq(gun:Clip1(),11);eq(gun.Attachments[1].Installed,'scope')
 assert(W.Activate(p,rifle));eq(p:GetActiveWeapon(),gun);eq(gun:Clip1(),11)
 -- Stale or forged empty-slot requests must not override a populated slot.
 select(1,0);eq(p:GetActiveWeapon(),gun)
 select(0,0);eq(p:GetActiveWeapon(),gun)
 select(2,rifle.id);eq(p:GetActiveWeapon(),gun)
 eq(W.Holster(p,4),false);eq(W.Holster(p,1.5),false)
 gun.reloading=true;select(2,0);eq(p:GetActiveWeapon(),gun);gun.reloading=false
 gun.primed=true;select(2,0);eq(p:GetActiveWeapon(),gun);gun.primed=false
 gun.nextFire=clock+1;select(2,0);eq(p:GetActiveWeapon(),gun);gun.nextFire=0
 for _,flag in ipairs({'dead','restricted','bUsingMedical'}) do
  p[flag]=true;eq(W.Holster(p,2),false);eq(p:GetActiveWeapon(),gun);p[flag]=nil
 end
 local inventory=p.inventories.weapon2;inventory.owner={};eq(W.Holster(p,2),false);inventory.owner=p
 p.inventories.weapon2=nil;eq(W.Holster(p,2),false);p.inventories.weapon2=inventory
 hands.valid=false;eq(W.Holster(p,2),false);eq(p:GetActiveWeapon(),gun)
 `,setup);

 suite('Empty slots use the server-approved predicted hands switch and reject a changed slot or entity',files,`
 local W=ix.WeaponSlots;local rifle=newItem(1);assert(W.Equip(p,rifle,1))
 local gun=W.Live(p,rifle);local hands=p:Give('ix_hands',true);function hands:EntIndex() return 42 end
 function p:IsBot() return false end
 local sent={};net.Start=function(name) eq(name,'ixWeaponSlotReady') end
 net.WriteUInt=function(value) sent[#sent+1]=value end;net.Send=function(client) eq(client,p) end
 assert(W.Holster(p,2));eq(p:GetActiveWeapon(),gun);eq(sent[1],42);eq(sent[2],2);eq(sent[3],0)
 SERVER=false;CLIENT=true
 local function loadClient()
 `+normalize(fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','utf8'))+`
 end
 loadClient()
 function RealTime() return clock end;function LocalPlayer() return p end
 local visible=false;function Entity(index) eq(index,42);return visible and hands or nil end
 local draws=0;input={SelectWeapon=function(w) eq(w,hands);draws=draws+1 end}
 net.ReadUInt=function() return table.remove(sent,1) end
 net.handlers.ixWeaponSlotReady();hook.Run('Think');eq(draws,0)
 visible=true;hands.class='weapon_physgun';hook.Run('Think');eq(draws,0);hands.class='ix_hands'
 local other=newItem(2);other.inventory_id=p.inventories.weapon2.id
 hook.Run('Think');eq(draws,0);other.inventory_id=inv.id
 hook.Run('Think');eq(draws,1);eq(W.pendingDraw,nil);eq(W.Live(p,rifle),gun)
 -- Confirming an empty selector entry sends id zero instead of doing nothing.
 sent={};net.Start=function(name) eq(name,'ixWeaponSlotDraw') end;net.SendToServer=function() end
 W.Select(W.Choices(p)[2]);eq(sent[1],2);eq(sent[2],0)
 W.pendingDraw={entity=42,slot=2,id=0,expires=clock-1};hook.Run('Think');eq(draws,1);eq(W.pendingDraw,nil)
 `,setup);

 suite('Weapon slots enforce two long weapons and one pistol or small melee through equip and direct transfers',files,`
 local W=ix.WeaponSlots;local a,b,c,pistol,knife=newItem(1),newItem(2),newItem(3),newItem(4),newItem(5)
 pistol.weaponCategory='sidearm';knife.weaponCategory='melee'
 assert(W.Equip(p,a,1,true));assert(W.Equip(p,b,2,true));eq(W.Equip(p,c,3,true),false)
 eq(inv:Transfer(c.id,p:GetInventory('weapon3')),false);eq(W.Equip(p,pistol,1,true),false)
 eq(inv:Transfer(knife.id,p:GetInventory('weapon1')),false);assert(W.Equip(p,pistol,nil,true))
 eq(inv:Transfer(knife.id,p:GetInventory('weapon3')),false)
 eq(pistol.inventory_type,'weapon3');eq(c.inventory_type,'main')
 assert(W.Unequip(p,pistol));assert(inv:Transfer(knife.id,p:GetInventory('weapon3')));assert(knife:IsEquipped())
 eq(knife.inventory_type,'weapon3');eq(W.Equip(p,pistol,nil,true),false)
 assert(W.Unequip(p,a));assert(W.Equip(p,c,nil,true));eq(c.inventory_type,'weapon1')
 `,setup);
 suite('Three-AK migration preserves full-bag overflow as a visible but disabled recovery item',files,`
 local W=ix.WeaponSlots;local a,b,c=newItem(1),newItem(2),newItem(3)
 assert(W.Equip(p,a,1,true));assert(W.Equip(p,b,2,true))
 c.inventory_id=p:GetInventory('weapon3').id;c.inventory_type='weapon3';c.data.equip=true
 c.data.ammo=19;c.data.arc9_atts={{Installed='saved'}};p.full=true
 W.Restore(p);eq(W.Item(p,3),c);eq(c:IsEquipped(),false);eq(W.Activate(p,c),false)
 eq(p.netvars.ixWeaponSlots.items[3],nil);eq(c.data.ammo,19);eq(c.data.arc9_atts[1].Installed,'saved')
 eq(W.Unequip(p,c),false);eq(W.Item(p,3),c)
 p.full=false;W.Restore(p);eq(c.inventory_type,'main');eq(W.Item(p,3),nil);eq(c.data.ammo,19)
 `,setup);
 suite('Grenades and utility devices remain usable inventory equipment without consuming weapon slots',files,`
 local W=ix.WeaponSlots;local item=newItem(1);item.weaponCategory='utility';item.isGrenade=true
 assert(W.Equip(p,item));eq(item.inventory_type,'main');assert(item:IsEquipped());assert(W.Live(p,item))
 eq(W.Item(p,1),nil);eq(W.Item(p,3),nil)
 W.Live(p,item).reloading=true;eq(W.Unequip(p,item),false);W.Live(p,item).reloading=false
 assert(W.Unequip(p,item));eq(item:IsEquipped(),false);eq(W.Live(p,item),nil)
 assert(W.Equip(p,item));W.Suspend(p,item);item:OnLoadout(p);assert(W.Live(p,item))
 `,setup);

 suite('Two-handed melee competes with rifles and small melee competes with pistols, with full-bag unequip protection',files,`
 local W=ix.WeaponSlots;local rifle,large,knife,extra=newItem(1),newItem(2),newItem(3),newItem(4)
 large.weaponCategory='melee';large.twoHanded=true;large.class='arc9_eft_heavy_melee'
 knife.weaponCategory='melee';knife.twoHanded=false;knife.class='arc9_eft_knife'
 extra.weaponCategory='melee';extra.twoHanded=true;extra.class=large.class
 eq(W.Kind(large),'long');eq(W.Kind(knife),'pistol')
 assert(W.Equip(p,rifle,1,true));assert(W.Equip(p,large,nil,true));eq(large.inventory_type,'weapon2')
 assert(W.Equip(p,knife,nil,true));eq(knife.inventory_type,'weapon3')
 eq(W.Equip(p,extra),false);eq(inv:Transfer(extra.id,p:GetInventory('weapon3')),false)
 eq(p.netvars.ixWeaponSlots.items[2].id,large.id);eq(p.netvars.ixWeaponSlots.items[3].id,knife.id)
 assert(W.Activate(p,knife));p.full=true;eq(W.Unequip(p,knife),false);assert(knife:IsEquipped());assert(W.Live(p,knife))
 p.full=false;assert(W.Unequip(p,knife));eq(W.Live(p,knife),nil);eq(knife.inventory_type,'main')
 assert(W.Unequip(p,rifle));assert(W.Equip(p,extra,nil,true));eq(extra.inventory_type,'weapon1')
 `,setup);

 suite('Legacy inventory-equipped melee migrates to a free slot or stays safely unequipped when slots are full',files,`
 local W=ix.WeaponSlots;local knife=newItem(1);knife.class='arc9_eft_knife';knife.weaponCategory='utility'
 assert(W.Equip(p,knife));assert(W.Live(p,knife));knife.weaponCategory='melee';knife.twoHanded=false
 local pistol=newItem(2);pistol.weaponCategory='sidearm';assert(W.Equip(p,pistol,3,true))
 knife.data.customName='Saved knife';p.full=true;W.Restore(p)
 eq(knife.inventory_type,'main');eq(knife:IsEquipped(),false);eq(W.Live(p,knife),nil);eq(knife.data.customName,'Saved knife')
 eq(W.Activate(p,knife),false);eq(W.Item(p,3),pistol)
 p.full=false;assert(W.Unequip(p,pistol));knife.data.equip=true;W.Restore(p)
 eq(W.Item(p,3),knife);eq(knife:IsEquipped(),true)
 local heavy=newItem(3);heavy.weaponCategory='melee';heavy.twoHanded=true;heavy.data.equip=true
 W.Restore(p);eq(heavy.inventory_type,'weapon1');assert(heavy:IsEquipped())
 `,setup);

 const meleeNames=['6x5','crowbar','gladius','hultafors','kukri'];
 const meleeFiles=meleeNames.map(name=>
  fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/items/weapon/sh_selected_eft_melee_'+name+'.lua','utf8'));
 suite('Installed Tarkov melee definitions use the same handedness rule as equip and drag-drop',files,
  meleeFiles.map((source,index)=>`do\nITEM={isWeapon=true}\n${normalize(source)}\neq(ITEM.twoHanded,${!['6x5','kukri'].includes(meleeNames[index])})\n`+
   `eq(ITEM.weaponCategory,'melee');eq(ix.WeaponSlots.Accepts(ITEM,3),not ITEM.twoHanded);eq(ix.WeaponSlots.Accepts(ITEM,1),ITEM.twoHanded==true)\nend`).join('\n'),setup);

 suite('Reclassified melee leaves the hip for a free back slot, or is retained safely if all storage is full',files,`
 local W=ix.WeaponSlots;local crowbar=newItem(1);crowbar.class='arc9_eft_melee_crowbar'
 crowbar.weaponCategory='melee';crowbar.twoHanded=false;crowbar.data.customName='My crowbar'
 assert(W.Equip(p,crowbar,3));crowbar.twoHanded=true
 W.Restore(p);eq(W.Item(p,1),crowbar);eq(W.Item(p,3),nil);assert(crowbar:IsEquipped())
 assert(W.Unequip(p,crowbar));crowbar.twoHanded=false;assert(W.Equip(p,crowbar,3))
 local a,b=newItem(2),newItem(3);assert(W.Equip(p,a,1,true));assert(W.Equip(p,b,2,true))
 crowbar.twoHanded=true;p.full=true;W.Restore(p)
 eq(W.Item(p,3),crowbar);eq(crowbar:IsEquipped(),false);eq(W.Activate(p,crowbar),false)
 eq(crowbar.data.customName,'My crowbar');eq(p.netvars.ixWeaponSlots.items[3],nil)
 p.full=false;W.Restore(p);eq(crowbar.inventory_type,'main');eq(W.Item(p,3),nil)
 `,setup);

 const networking=normalize(fs.readFileSync(__dirname+'/../helix/gamemode/core/sh_networking.lua','utf8'));
 const registrations=fs.readFileSync(__dirname+'/../helix/gamemode/shared.lua','utf8').split('\n').filter(line=>line.startsWith('ix.Net:AddPlayerVar(')).join('\n');
 suite('Holster state uses production registered networking and automatically synchronizes late observers',files,`
 local metas={Entity={},Player={}}
 function FindMetaTable(name) return metas[name] end
 function ix.util.Lib(name,initial) ix[name]=initial;return initial end
 function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 net.WriteUInt=function() end;net.WriteTable=function(data) sentData=data end
 net.ReadTable=function() end;net.WriteBool=function() end;net.ReadBool=function() end
 net.WriteType=function() end;net.ReadType=function() end
 net.Start=function(name) sentName=name end;net.Broadcast=function() broadcasts=(broadcasts or 0)+1 end
 net.Send=function(receiver) sentTo=receiver end
 do
 `+networking+`
 end
 `+registrations+`
 function p:EntIndex() return 1 end
 p.SetNetVar=metas.Player.SetNetVar;p.GetNetVar=metas.Player.GetNetVar;p.ClearNetVar=metas.Player.ClearNetVar
 local a,b=newItem(1),newItem(2);assert(ix.WeaponSlots.Equip(p,a,1,true));assert(ix.WeaponSlots.Equip(p,b,2,true))
 assert(broadcasts>0);eq(sentName,'rp.net.player');eq(sentData.items[1].id,1);eq(sentData.items[2].id,2)
 eq(p:GetNetVar('ixWeaponSlots').character,p:GetCharacter():GetID())
 local viewer={EntIndex=function() return 2 end};function Entity(id) return id==1 and p or viewer end
 metas.Player.SyncVars(viewer);eq(sentTo,viewer);eq(sentData.items[2].id,2)
 `,setup);

 suite('FIELDLINK equipment builds real weapon inventory panels before clothing and keeps drag/drop destinations',
 ['helix/gamemode/game/ui/legends.workspace.lua'],`
 local screen=setmetatable({body=panel(),character={}},{__index=workspace})
 local seen={};function screen:AddInventory(parent,inventory,title,size) seen[#seen+1]={id=inventory.id,title=title} end
 function screen:UpdateBackpack() end
 screen:Equipment();eq(seen[1].id,'weapon1');eq(seen[2].id,'weapon2');eq(seen[3].id,'weapon3')
 eq(seen[3].title,'Pistol');eq(seen[4].id,'head')
 local main=false;for _,row in ipairs(seen) do if row.id=='main' then main=true end end;assert(main)
 `,`
 SERVER=false;CLIENT=true
 local noop=function() end
 function panel() return setmetatable({},{__index=function(_,key) if key=='Add' then return function() return panel() end end return noop end}) end
 ix.InterfaceOS={T=function(en) return en end,Scroll=function() return panel() end,Label=noop}
 ix.Legends={Scale=function(n) return n end}
 ix.WeaponSlots={count=3,Label=function(n) return n==3 and 'Pistol' or 'Long '..n end,Description=function() return 'Weapon slot' end}
 vgui={GetControlTable=function() return {} end,Register=function(_,p) workspace=p end}
 function ScrW() return 1920 end;function L(s) return s end
 function LocalPlayer() return {GetInventory=function(_,kind) return {id=kind} end} end
 `);
 suite('Two identical rifles and a pistol preserve separate magazines, modules and identity',files,`
 local W=ix.WeaponSlots
 local a,b,c,d=newItem(1),newItem(2),newItem(3),newItem(4)
 c.weaponCategory="sidearm";c.class="arc9_eft_pistol"
 a.data.ammo=2;b.data.ammo=9;c.data.ammo=15
 a.data.arc9_atts={{Installed='a'}};b.data.arc9_atts={{Installed='b'}};c.data.arc9_atts={{Installed='c'}}
 a.data.customName='First';b.data.customName='Second';c.data.customName='Third'
 for i,item in ipairs({a,b,c}) do assert(W.Equip(p,item,i));eq(item.inventory_type,'weapon'..i);assert(item:IsEquipped()) end
 eq(#inv:GetItems(),1);eq(W.Equip(p,d),false);eq(d.inventory_type,'main')
 local expected={[a]=2,[b]=9,[c]=15}
 for i,item in ipairs({a,b,c,a,c,b}) do
  local weapon=W.Activate(p,item);assert(weapon);eq(weapon.ixItem,item)
  eq(weapon:Clip1(),expected[item]);eq(weapon.Attachments[1].Installed,item.data.arc9_atts[1].Installed)
  weapon.clip=weapon.clip-1;expected[item]=expected[item]-1
 end
 W.Release(p,b);W.Release(p,c);eq(a.data.ammo,0);eq(b.data.ammo,7);eq(c.data.ammo,13)
 eq(a.data.customName,'First');eq(b.data.customName,'Second');eq(c.data.customName,'Third')
 `,setup);
 suite('Full inventory and occupied equipment preserve exact items; dropping an undrawn duplicate leaves the drawn gun',files,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2)
 assert(W.Equip(p,a,1));assert(W.Equip(p,b,2));local weapon=W.Live(p,b)
 p.full=true;eq(a:Unequip(p,true),false);eq(a.inventory_type,'weapon1');assert(a:IsEquipped())
 eq(W.Equip(p,a,2),false);eq(W.Item(p,2),b)
 a:OnDrop(p,p:GetInventory('weapon1'));assert(weapon.valid);eq(weapon.ixItem,b)
 p.full=false;assert(b:Unequip(p,true));eq(b.inventory_type,'main');eq(b:IsEquipped(),false);eq(weapon.valid,false)
 `,setup);
 suite('Weapon switches reject reloading, primed grenades, firing cooldowns and pending transfers',files,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2)
 assert(W.Equip(p,a,1));assert(W.Equip(p,b,2,true));local weapon=W.Live(p,a)
 for _,key in ipairs({'reloading','primed'}) do weapon[key]=true;eq(W.Activate(p,b),false);assert(weapon.valid);weapon[key]=false end
 weapon.nextFire=clock+1;eq(W.Activate(p,b),false);eq(a:Unequip(p,true),false);weapon.nextFire=0
 ix.Inventory.pendingTransfers.item_2=9;eq(W.Activate(p,b),false);eq(W.Equip(p,b,3),false)
 ix.Inventory.pendingTransfers.item_2=nil;assert(W.Activate(p,b));eq(W.Live(p,a),nil)
 `,setup);
 suite('Weapon slot requests reject forged item IDs, invalid slots, restrictions, stale moves and borrowed inventories',files,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2);assert(W.Equip(p,a,1,true));assert(W.Equip(p,b,2,true))
 local function draw(slot,id) clock=clock+1;local q={slot,id};net.ReadUInt=function() return table.remove(q,1) end;net.handlers.ixWeaponSlotDraw(34,p) end
 draw(1,b.id);eq(#p.weapons,0);draw(0,a.id);eq(#p.weapons,0)
 p.restricted=true;draw(1,a.id);eq(#p.weapons,0);p.restricted=false
 assert(W.Unequip(p,b));assert(W.Equip(p,a,2,true));draw(1,a.id);eq(#p.weapons,0);draw(2,a.id);eq(W.Live(p,a).ixItem,a)
 p:GetInventory('weapon2').owner={valid=true};eq(W.Activate(p,b),false)
 `,setup);
 suite('Failed duplicate restoration rolls back the previous live weapon and retains both equipped items',files,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2)
 assert(W.Equip(p,a,1));assert(W.Equip(p,b,2,true));local old=W.Live(p,a);old.clip=4
 b.data.arc9_atts={{Installed='missing'}};ARC9={GetAttTable=function(name) return name~='missing' and {} or nil end}
 eq(W.Activate(p,b),false);eq(W.Live(p,a):Clip1(),4);eq(a.inventory_type,'weapon1');eq(b.inventory_type,'weapon2')
 eq(b.data.arc9_atts[1].Installed,'missing');eq(b.data.ammo,7)
 `,setup);
 suite('Legacy equipment migrates deterministically; reconnect keeps slot identity and does not need free bag space',files,`
 local W=ix.WeaponSlots;local items={newItem(4),newItem(3),newItem(2),newItem(1)}
 for _,item in ipairs(items) do item.data.equip=true end
 items[2].weaponCategory='sidearm'
 W.Restore(p)
 for i=1,3 do eq(W.Item(p,i).id,i) end
 eq(items[1].inventory_type,'main');eq(items[1].data.equip,false)
 local a=W.Item(p,1);assert(W.Activate(p,a));W.Live(p,a).clip=3
 hook.Run('PlayerLoadout',p);p.weapons={};p.full=true;W.Restore(p)
 eq(W.Item(p,1),a);eq(a.data.ammo,3);assert(W.Activate(p,a));eq(W.Live(p,a).clip,3)
 `,setup);
 suite('Knockdown suspends only live entities and cannot restore a looted item or lose a full-inventory weapon',files,`
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2);assert(W.Equip(p,a,1));assert(W.Equip(p,b,2,true))
 p.full=true;W.Live(p,a).clip=2;W.Suspend(p,a)
 eq(a.inventory_type,'weapon1');eq(a.data.equip,true);eq(a.data.ammo,2);eq(W.Live(p,a),nil)
 assert(W.Activate(p,a,true));eq(W.Live(p,a).clip,2)
 W.Suspend(p,a);a.inventory_id=1;a.inventory_type='main';eq(W.Activate(p,a),false)
 eq(W.Item(p,2),b)
 `,setup);
 suite('Public holster state has all three item IDs, including duplicates, and hides only the live active item',files,`
 local W=ix.WeaponSlots;local a,b,c=newItem(1),newItem(2),newItem(3)
 c.weaponCategory='sidearm';c.class='arc9_eft_pistol'
 assert(W.Equip(p,a,1));assert(W.Equip(p,b,2));assert(W.Equip(p,c,3))
 W.Publish(p);local data=p.netvars.ixWeaponSlots
 eq(data.items[1].id,1);eq(data.items[2].id,2);eq(data.items[3].id,3);eq(data.active,3)
 p.selected='ix_hands';W.Publish(p);eq(p.netvars.ixWeaponSlots.active,nil)
 assert(W.Activate(p,b));W.Publish(p);eq(p.netvars.ixWeaponSlots.active,2)
 `,setup);
 suite('Client selector includes three stable numbered slots and separates identical item selections from tools',files,`
 local a,b=newItem(1),newItem(2);b.weaponCategory='sidearm';assert(ix.WeaponSlots.Equip(p,a,1));assert(ix.WeaponSlots.Equip(p,b,3,true))
 p:Give('ix_hands',true)
 SERVER=false;CLIENT=true
 local function loadClient()
 `+normalize(fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','utf8'))+`
 end
 loadClient()
 local choices=ix.WeaponSlots.Choices(p)
 eq(#choices,4);eq(choices[1].itemID,a.id);eq(choices[2].itemID,0);eq(choices[3].itemID,b.id);eq(choices[4]:GetClass(),'ix_hands')
 local sent={};net.Start=function(name) eq(name,'ixWeaponSlotDraw') end
 net.WriteUInt=function(value) sent[#sent+1]=value end;net.SendToServer=function() end
 ix.WeaponSlots.Select(choices[3]);eq(sent[1],3);eq(sent[2],b.id)
 `,setup);
 suite('Native inventory transfers shrink weapon footprints only in slots, reject other equipment and preserve full-bag failures',
 [...files,'helix/gamemode/game/inventory/sh_inventory.class.lua'],`
 local insert=table.insert
 function table.insert(t,v) insert(t,v);return #t end
 function table.IsEmpty(t) return next(t)==nil end
 function table.RemoveByValue(t,v) for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end end
 function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end return false end
 local I=ix.meta.Inventory
 function I:SendDeltaTransfer() self.synced=true end
 ix.Inventory.stored={}
 inv=I:New();inv.type='main';inv.owner=p;inv:SetSize(6,2)
 p.inventories={main=inv};hook.Run('CreatePlayerInventories',p,p.inventories)
 for _,v in pairs(p.inventories) do v.owner=p end
 local function make(id)
  local item=newItem(id);item.width=3;item.height=2;item.rotated=false;item.stackable=false
  item.inventory_id=nil;assert(inv:AddItem(item));return item
 end
 local a,b=make(1),make(2);eq(#inv:GetItems(),2)
 assert(ix.WeaponSlots.Equip(p,a,1,true));eq(#inv:GetItems(),1)
 local slot=p:GetInventory('weapon1');eq(slot:GetItemSize(a),1);eq(slot:GetFirstAtSlot(1,1),a.id)
 local c=make(3);eq(a:Unequip(p,true),false);eq(slot:GetFirstAtSlot(1,1),a.id)
 local hat=I:New();hat.type='head';hat.owner=p;hat.isEquipment=true;hat:SetSize(1,1);hat.multislot=false
 eq(slot:Transfer(a.id,hat),false)
 assert(ix.WeaponSlots.Equip(p,b,2,true));assert(a:Unequip(p,true));eq(inv:GetItemSize(a),3)
 eq(slot:GetFirstAtSlot(1,1),nil);eq(a.data.equip,false);eq(a.inventory_type,'main')
 -- A delayed transfer from a stale source cannot duplicate the moved item.
 eq(slot:Transfer(a.id,p:GetInventory('weapon3')),false);eq(a.inventory_type,'main')
 `,setup);
 suite('ARC9 safety and fire mode stay with their own item across duplicate switches',files,`
 local create=newWeapon
 function newWeapon()
  local w=create();w.values.Firemodes={{Mode=1},{Mode=-1}};w.mode=1;w.safe=false
  function w:GetFiremode() return self.mode end;function w:SetFiremode(n) self.mode=n end
  function w:GetSafe() return self.safe end;function w:SetSafe(v) self.safe=v end
  return w
 end
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2)
 assert(W.Equip(p,a,1));W.Live(p,a):SetFiremode(2);W.Live(p,a):SetSafe(true)
 assert(W.Equip(p,b,2));eq(W.Live(p,b):GetFiremode(),1);eq(W.Live(p,b):GetSafe(),false)
 assert(W.Activate(p,a));eq(W.Live(p,a):GetFiremode(),2);eq(W.Live(p,a):GetSafe(),true)
 `,setup);
 suite('Non-ARC9 rifles share the two long-gun slots without sharing magazines',files,`
 local create=newWeapon
 function newWeapon()
  local w=create();w.ARC9=false
  function w:GetPrimaryAmmoType() return 0 end;function w:GetSecondaryAmmoType() return -1 end
  return w
 end
 game.GetAmmoName=function(id) return id==0 and 'pistol' or nil end
 local W=ix.WeaponSlots;local a,b=newItem(1),newItem(2);a.class='weapon_ar2';b.class=a.class
 a.data.ammo=3;b.data.ammo=12
 assert(W.Equip(p,a,1));eq(W.Live(p,a):Clip1(),3);W.Live(p,a).clip=1
 assert(W.Equip(p,b,2));eq(W.Live(p,b):Clip1(),12)
 assert(W.Activate(p,a));eq(W.Live(p,a):Clip1(),1);eq(b.data.ammo,12)
 `,setup);
 suite('Holstered duplicates use separate models, retain stable mounts and clean up only the removed item',
 ['ixhl2rp/plugins/holsteredweapons.lua','ixhl2rp/plugins/ammo_cringe/cl_weapon_holsters.lua'],`
 local W=ix.WeaponSlots;local rows={{id=1,class='gun',model='gun.mdl'},{id=2,class='gun',model='gun.mdl'},{id=3,class='gun',model='gun.mdl'}}
 local data={character=1,items=rows}
 local client={valid=true,GetNetVar=function() return data end,GetCharacter=function() return {GetID=function() return 1 end} end,
  GetActiveWeapon=function() return active end,GetModel=function() return 'sd.mdl' end,GetModelScale=function() return 1 end,LookupBone=function() return 1 end,
  GetBoneMatrix=function() return {GetTranslation=function() return Vector(0,0,0) end,GetAngles=function() return Angle() end} end}
 local plugin=PLUGIN;function plugin:HolsterBoneFrame() return Angle() end
 ix.arc9Inventory.IsClass=function() return true end
 ix.WeaponAssembly={Get=function(host) return host end,Center=function() return Vector() end,
  Draw=function(model,pos,ang) model.pos=pos;model.ang=ang;model:DrawModel() end,Remove=function() end}
 W.DrawHolsters(plugin,client);eq(created,3);eq(draws,3)
 local lookups=0;local get=ix.WeaponAssembly.Get
 ix.WeaponAssembly.Get=function(...) lookups=lookups+1;return get(...) end
 ix.RenderBudget={Interval=function() return .2 end}
 clock=11;W.DrawHolsters(plugin,client);eq(lookups,3)
 local beforeDraws=draws
 for i=1,19 do clock=11+i*.01;W.DrawHolsters(plugin,client) end
 eq(lookups,3);eq(draws-beforeDraws,19*3) -- models keep following/drawing each frame
 data.items[1]={id=1,class='gun',model='gun.mdl'};clock=11.191;W.DrawHolsters(plugin,client);eq(lookups,4)
 clock=11.21;W.DrawHolsters(plugin,client);eq(lookups,6)
 data.items[1]=rows[1];ix.RenderBudget=nil

 -- Separate upright shoulder mounts; giant hidden-arm bounds cannot spread
 -- them across the room. Hip and authored legacy profiles stay unchanged.
 eq(models[1].pos.x,-3.5);eq(models[1].pos.y,-5.5);eq(models[1].pos.z,9)
 eq(models[1].ang.p,-90);eq(models[1].ang.y,90)
 eq(models[2].pos.y,5.5);eq(models[2].pos.z,9);eq(models[2].ang.p,-90);eq(models[2].ang.y,-90);eq(models[2].ang.r,0)
 eq(models[3].pos.x,0);eq(models[3].pos.y,-8);eq(models[3].pos.z,-4);eq(models[3].ang.p,90)
 active={valid=true,GetNWInt=function() return 2 end};draws=0;W.DrawHolsters(plugin,client);eq(created,3);eq(draws,2)
 eq(models[1].pos.y,-5.5);data.backpack=true;W.DrawHolsters(plugin,client);eq(models[1].pos.x,-3.5)
 -- Legacy profiles use their authored bone-local origin, not a new mesh centre.
 active=nil;ix.WeaponAssembly=nil
 rows[1].class='arccw_ar2';W.DrawHolsters(plugin,client)
 eq(models[1].pos.x,-4);eq(models[1].pos.y,-5);eq(models[1].pos.z,-3)
 active={valid=true,GetNWInt=function() return 2 end}
 data.items[1]=nil;draws=0;W.DrawHolsters(plugin,client);eq(removed,1);eq(draws,1)
 W.ClearHolsters(client);eq(removed,3)
 `,`
 SERVER=false;CLIENT=true;ix.WeaponSlots={count=3};ix.arc9Inventory={IsClass=function() return false end}
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 V.__mul=function(a,b) if type(a)=='number' then a,b=b,a end return Vector(a.x*b,a.y*b,a.z*b) end
 function Angle(p,y,r) return {p=p or 0,y=y or 0,r=r or 0,Right=function() return Vector(0,-1,0) end,
  Forward=function() return Vector(1,0,0) end,Up=function() return Vector(0,0,1) end,RotateAroundAxis=function() end} end
 angle_zero=Angle();vector_origin=Vector()
 function LocalToWorld(p,a,origin) return p+origin,a end
 function WorldToLocal(p,a,origin) return p-origin,a end
 function util.IsValidModel(path) return path=='gun.mdl' end
 hook.Add=function() end;created=0;removed=0;draws=0;models={}
 function ClientsideModel()
  created=created+1;local model={valid=true};models[created]=model
  function model:SetNoDraw() end;function model:SetModelScale() end;function model:SetPos(pos) self.pos=pos end
  function model:SetAngles() end;function model:SetupBones() end
  function model:GetRenderBounds() return Vector(-128,-128,-128),Vector(128,128,128) end
  function model:DrawModel() draws=draws+1 end
  function model:Remove() self.valid=false;removed=removed+1 end
  return model
 end
 `);

 suite('Inventory load completion restores equipment only for the same character and inventory set',
 [...files,'helix/gamemode/game/inventory/sv_player.lua'],`
 local callbacks={};ix.Item.LoadInstanceByID=function(self,ids,add,done) callbacks={add=add,done=done} end
 p.character.GetSavedItems=function() return {1} end
 local a=newItem(1);a.inventory_type='weapon2';a.x=1;a.y=1
 local slot=p:GetInventory('weapon2');local adds=0;function slot:AddItem(item) adds=adds+1;item.inventory_id=self.id end
 local completed=0;p:LoadInventories(function() completed=completed+1 end)
 local old=callbacks;p.character={GetID=function() return 2 end,GetSavedItems=function() return {} end}
 old.add(a);old.done();eq(adds,0);eq(completed,0)
 p:LoadInventories(function() completed=completed+1 end);callbacks.add(a);callbacks.done();eq(adds,1);eq(completed,1)
 p:LoadInventories(function() completed=completed+1 end);p.inventories={};callbacks.add(a);callbacks.done();eq(adds,1);eq(completed,1)
 `,setup);

 suite('Draw acknowledgement waits for the correct replicated entity and uses predicted client selection',files,`
 local W=ix.WeaponSlots;local a=newItem(1);assert(W.Equip(p,a,2,true))
 function p:IsBot() return false end
 local make=newWeapon;function newWeapon() local w=make();function w:EntIndex() return 42 end;return w end
 local sent={};net.Start=function(name) eq(name,'ixWeaponSlotReady') end
 net.WriteUInt=function(value) sent[#sent+1]=value end;net.Send=function(client) eq(client,p) end
 local weapon=W.Activate(p,a);eq(sent[1],42);eq(sent[2],2);eq(sent[3],a.id);eq(p.selected,nil)
 SERVER=false;CLIENT=true
 local function loadClient()
 `+normalize(fs.readFileSync(__dirname+'/../ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','utf8'))+`
 end
 loadClient()
 function RealTime() return clock end;function LocalPlayer() return p end
 local visible=false;function Entity(index) eq(index,42);return visible and weapon or nil end
 local draws=0;input={SelectWeapon=function(w) eq(w,weapon);draws=draws+1 end}
 net.ReadUInt=function() return table.remove(sent,1) end
 net.handlers.ixWeaponSlotReady();hook.Run('Think');eq(draws,0)
 visible=true;weapon.net.ixWeaponItem=999;hook.Run('Think');eq(draws,0)
 weapon.net.ixWeaponItem=a.id;hook.Run('Think');eq(draws,1);eq(W.pendingDraw,nil)
 W.pendingDraw={entity=42,slot=1,id=a.id,expires=clock+3};hook.Run('Think');eq(draws,1)
 clock=clock+4;hook.Run('Think');eq(W.pendingDraw,nil);eq(draws,1)
 `,setup);

};
