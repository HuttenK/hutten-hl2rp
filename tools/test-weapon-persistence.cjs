const fs=require('fs');
const {normalize}=require('./glua.cjs');
function section(file,start,end) {
 const source=fs.readFileSync(__dirname+'/../'+file,'utf8');
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 if(a<0||b<0)throw Error('Missing production section '+start);
 return normalize(source.slice(a,b));
}
const methods=section('ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua','function Item:Equip(','\nif CLIENT then');
const save=section('helix/gamemode/game/items/sh_item.class.lua','function ITEM:Save()','function ITEM:CollectSyncData');
const shutdown=section('helix/gamemode/core/hooks/sv_hooks.lua','function GM:ShutDown()','function GM:GetGameDescription');
const presave=section('helix/gamemode/core/hooks/sv_hooks.lua','function GM:CharacterPreSave(character)','timer.Create("ixLifeGuard"');
const snapshot=section('ixhl2rp/plugins/pushcart/sv_plugin.lua','function P:Snapshot(entity)','function PLUGIN:SaveData()');
module.exports=suite=>suite('Shutdown with a gun in a cargo crate saves all three weapon slots and the worn helmet, then restores their saved locations',
 ['tools/fixtures/arc9-inventory.lua','tools/fixtures/weapon-slots.lua',
  'ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua','ixhl2rp/plugins/ammo_cringe/sh_arc9.lua',
  'ixhl2rp/plugins/ammo_cringe/sh_plugin.lua','helix/gamemode/game/inventory/sh_inventory.class.lua',
  'helix/gamemode/game/inventory/sh_player.lua','helix/gamemode/game/inventory/sv_player.lua'],`
 local insert=table.insert;function table.insert(t,v) insert(t,v);return #t end
 function table.IsEmpty(t) return next(t)==nil end
 function table.Add(t,other) for _,v in ipairs(other) do insert(t,v) end return t end
 function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end return false end
 local db,encoded={},{}
 local encode=util.TableToJSON
 util.TableToJSON=function(data) local s=encode(data);if istable(data) then encoded[s]=table.Copy(data) end return s end
 mysql={Update=function(_,name)
  eq(name,'ix_items');local q={row={}}
  function q:Update(k,v) self.row[k]=v end
  function q:Where(k,v) eq(k,'item_id');self.id=v end
  function q:Execute() db[self.id]=self.row end
  return q
 end}
 ix.config.Save=function() end
 GM={};P={};ITEM=Item
 `+save+shutdown+presave+snapshot+`
 function Item:GetID() return self.id end
 function Item:Call(name,...) return self[name](self,...) end
 function Item:SaveLoadedAmmoType(w) ix.WeaponSlots.Save(self,w) end
 function p:Health() return 100 end
 function p:SaveData() self.playerSaved=true end
 local char=p:GetCharacter()
 function char:GetPlayer() return p end
 function char:SetSavedItems(ids) self.saved=table.Copy(ids) end
 function char:GetSavedItems() return self.saved end
 function char:SetData() end
 function char:Save() GM:CharacterPreSave(self);self.savedCharacter=true end
 -- The production shutdown now uses the isolated hook dispatcher. This test
 -- supplies a minimal engine hook table, so forward its successful hooks.
 hook.SafeRun=hook.Run
 player.GetAll=function() return {p} end
 local I=ix.meta.Inventory
 function I:SendDeltaTransfer() end
 local function inventories()
  p.inventories={};ix.Inventory.stored={}
  inv=I:New();inv.type='main';inv.owner=p;inv:SetSize(6,4);p.inventories.main=inv
  hook.Run('CreatePlayerInventories',p,p.inventories)
  local head=I:New();head.type='head';head.multislot=false;head:SetSize(1,1);p.inventories.head=head
  for _,v in pairs(p.inventories) do v.owner=p end
 end
 inventories();p.GetItems=nil -- use the real all-inventories enumeration
 local function add(id,where)
  local item=newItem(id);item.inventory_id=nil;item.width=3;item.height=2;item.stackable=false
  item.vars_id={'ammo','ammo2','equip','arc9_atts'};item.vars={}
  for _,k in ipairs(item.vars_id) do item.vars[k]={} end
  assert(where:AddItem(item,1,1,nil,true));return item
 end
 local a=add(1,p:GetInventory('weapon1'));local b=add(2,p:GetInventory('weapon2'))
 local c=add(3,p:GetInventory('weapon3'));c.weaponCategory='sidearm'
 local helmet=add(4,p:GetInventory('head'));helmet.isWeapon=false;helmet.OnSave=false;helmet.data.equip=true
 local crate={valid=true,IsPlayer=function() return false end,isCargoCrate=true,cargoUID='test'}
 function crate:GetClass() return 'ix_cargo_crate' end
 function crate:GetPos() return {x=0,y=0,z=0} end;function crate:GetAngles() return {p=0,y=0,r=0} end
 function crate:GetCartSlot() return 0 end
 local cargo=I:New();cargo.type='cargo_test';cargo.owner=crate;cargo:SetSize(4,4)
 function crate:GetInventory() return cargo end
 local stored=add(5,cargo);stored.data.ammo=13;stored.data.arc9_atts={{Installed='stored_attachment'}}
 eq(ix.WeaponSlots.Live(crate,stored),nil);eq(ix.WeaponSlots.Owns(crate,stored),false)
 eq(ix.WeaponSlots.Live(nil,stored),nil);ix.WeaponSlots.Release(crate,stored)
 assert(ix.WeaponSlots.Activate(p,a,true));ix.WeaponSlots.Live(p,a).clip=3
 b.data.ammo=9;c.data.ammo=6
 local cargoRecord
 hook.Add('SaveData','cargo-test',function() cargoRecord=P:Snapshot(crate) end)
 -- This is the reported call order, including the actual item OnSave.
 GM:ShutDown()
 assert(p.playerSaved and char.savedCharacter);eq(#char.saved,4);eq(cargoRecord.items[1],5)
 eq(db[1].inventory_type,'weapon1');eq(db[2].inventory_type,'weapon2');eq(db[3].inventory_type,'weapon3')
 eq(db[4].inventory_type,'head');eq(db[5].inventory_type,'cargo_test')
 eq(encoded[db[1].data].ammo,3);eq(encoded[db[2].data].ammo,9);eq(encoded[db[3].data].ammo,6)
 eq(encoded[db[5].data].ammo,13);eq(encoded[db[5].data].arc9_atts[1].Installed,'stored_attachment')
 -- Hydrate saved rows into a new session through the production loader and
 -- real inventory slot placement. The SQL transport is the only mock here.
 inventories();ix.Item.instances={};p.items={};p.weapons={}
 ix.Item.LoadInstanceByID=function(_,ids,onItem,done)
  for _,id in ipairs(ids) do
   local row=db[id];local item=newItem(id);item.inventory_id=nil
   item.width=3;item.height=2;item.stackable=false;item.rotated=row.rotated
   item.x=row.x;item.y=row.y;item.inventory_type=row.inventory_type;item.data=table.Copy(encoded[row.data])
   if id==3 then item.weaponCategory='sidearm' end
   if id==4 then item.isWeapon=false end
   onItem(item)
  end
  done()
 end
 p:LoadInventories(function() hook.Run('PlayerInventoriesLoaded',p) end)
 for slot=1,3 do eq(ix.WeaponSlots.Item(p,slot).id,slot) end
 eq(p:GetInventory('head'):GetFirstAtSlot(1,1),4);eq(#inv:GetItems(),0)
 eq(ix.WeaponSlots.Item(p,1).data.ammo,3);eq(ix.WeaponSlots.Item(p,2).data.ammo,9)
 eq(ix.Item.instances[5],nil) -- crate content is not duplicated onto the character
 `,'Item={}\n'+methods);
