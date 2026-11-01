const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const stackFiles=['helix/gamemode/items/base/stackable.lua','ixhl2rp/plugins/ammo_cringe/items/base/ammo.lua','helix/gamemode/game/items/sh_item.lua'];
 const stackSetup=`
 local originalClass=class
 function class(name) local c=originalClass(name);function c:implements() return self end;return c end
 function implements() setmetatable(ix.meta.ItemAmmo,{__index=ix.meta.ItemStackable}) end
 ix.util={Include=function() end,Lib=function(name,t) ix[name]=t;return t end};ix.flag={Add=function() end};ix.transmit={owner=1}
 inserts={};mysql={module='test',Insert=function()
  local q={values={}};function q:Insert(k,v) self.values[k]=v end
  function q:Execute() inserts[#inserts+1]=self.values end;return q
 end}
 util.TableToJSON=function(t) return table.Copy(t) end
 function ErrorNoHalt(msg) error(msg) end
 inventories={};ix.Inventory={pendingTransfers={},Get=function(_,id) return inventories[id] end}
 function inventory(id)
  local inv={id=id,slots={},access=true}
  function inv:OnCheckAccess() return self.access end
  function inv:GetSlot(x,y) return self.slots[x] end
  function inv:AddItem(item,x,y)
   if self.full or self.slots[x] then return false end
   self.slots[x]={item.id};item.inventory_id=self.id;item.x=x;item.y=y;return true
  end
  function inv:Sync() end;inventories[id]=inv;return inv
 end
 function setPacket(values) net.values=values;net.pos=0 end
 function read() net.pos=net.pos+1;return net.values[net.pos] end
 net.ReadUInt=read;net.ReadBool=read
 `;
 const stackHelpers=`
 ix.Item.idsReady=true
 local base=ix.meta.ItemStackable
 function base:GetData(k,d) local v=self.data[k];if v~=nil then return v end;return d end
 function base:SetData(k,v) self.data[k]=v end
 function base:Remove()
  self.removed=true;ix.Item.instances[self.id]=nil
  local inv=inventories[self.inventory_id];if inv then inv.slots[self.x]=nil end
 end
 function register(id,ammo)
  local definition=setmetatable({uniqueID=id,ammoAmount=ammo},{__index=ammo and ix.meta.ItemAmmo or base})
  if ammo then definition:OnRegistered() end
  ix.Item.stored[id]=definition;return definition
 end
 function spawn(id,quantity,inv,x)
  local data={tag='keep me'};data.stack=quantity
  local item=ix.Item:Instance(id,data,nil,7,'player');assert(inv:AddItem(item,x,1));return item
 end
 function total()
  local count=0;for _,item in pairs(ix.Item.instances) do count=count+item:GetValue() end;return count
 end
 function split(source,target,item,x,amount)
  setPacket({source.id,target.id,item.x,item.y,x,1,true,amount or 0,false})
  net.handlers['item.legacy.stack.create'](0,{})
 end
 `;
 suite('Ctrl/Shift stack splitting conserves generic and ammo quantities through real creation and repeated requests',stackFiles,stackHelpers+`
 register('generic');register('ammo',90)
 for _,kind in ipairs({'generic','ammo'}) do
  local inv=inventory(1);local fresh=spawn(kind,nil,inv,1)
  eq(fresh:GetValue(),kind=='ammo' and 90 or 16);fresh:Remove()
  for _,quantity in ipairs({2,3,7,16,30}) do
   for _,amount in ipairs({0,1,9999}) do
    inv=inventory(1);local source=spawn(kind,quantity,inv,1);local before=total()
    split(inv,inv,source,2,amount);eq(total(),before)
    local moved=ix.Item.instances[inv.slots[2][1]]
    eq(moved:GetValue(),amount==0 and math.floor(quantity/2) or math.min(amount,quantity))
    eq(moved.data.tag,'keep me');eq(moved.characterID,7);eq(moved.playerID,'player')
    eq(inserts[#inserts].data.stack,moved:GetValue())
    -- Repeated packets into an occupied destination cannot mint another box.
    split(inv,inv,source,2,amount);eq(total(),before)
    ix.Item.instances={}
   end
  end
 end
 local sourceInv=inventory(1);local targetInv=inventory(2);local ammo=spawn('ammo',19,sourceInv,1)
 split(sourceInv,targetInv,ammo,2);eq(ammo:GetValue(),10);eq(total(),19)
 local moved=ix.Item.instances[targetInv.slots[2][1]];eq(moved:GetValue(),9)
 -- A custom initializer that still fills its box cannot override a split.
 local custom=register('custom',30);custom.OnInstanced=function(item) item:SetData('stack',30) end
 local item=spawn('custom',nil,sourceInv,3);item:SetData('stack',10)
 local before=total();split(sourceInv,targetInv,item,4);eq(total(),before)
 eq(ix.Item.instances[targetInv.slots[4][1]]:GetValue(),5)
 `,stackSetup);
 suite('Failed, locked and unauthorized splits leave the source unchanged and delete temporary instances',stackFiles,stackHelpers+`
 register('ammo',90);local a=inventory(1);local b=inventory(2);local item=spawn('ammo',19,a,1)
 b.full=true;split(a,b,item,2);eq(item:GetValue(),19);eq(total(),19)
 local live=0;for _ in pairs(ix.Item.instances) do live=live+1 end;eq(live,1)
 b.full=false;b.access=false;local count=#inserts;split(a,b,item,2);eq(#inserts,count);eq(total(),19)
 b.access=true;ix.Inventory.pendingTransfers['item_'..item.id]=42
 split(a,b,item,2);eq(#inserts,count);eq(total(),19)
 ix.Inventory.pendingTransfers={};item:SetData('stack',1);split(a,b,item,2);eq(item:GetValue(),1);eq(#inserts,count)
 `,stackSetup);

 const upstream=normalize(fs.readFileSync(__dirname+'/fixtures/arc9-upstream/sh_reload.lua','utf8').replace(/\r\n?/g,'\n'));
 const ast=require('luaparse').parse(upstream,{luaVersion:'5.2',ranges:true});
 const ammoMethods=ast.body.filter(n=>n.type==='FunctionDeclaration' && ['TakeAmmo','HasAmmoInClip'].includes(n.identifier?.identifier?.name))
  .map(n=>upstream.slice(...n.range).replace('function SWEP:','function AmmoBase:')).join('\n');
 for (const name of ['arc9_codww2_flamethrower','arc9_codww2_flammenwerfer35']) {
  suite(name+' fires continuously for 2 minutes using installed ARC9 ammo methods, including saved empty tanks',[
   'addons/foundation_flamethrower/lua/weapons/'+name+'.lua'],`
  eq(SWEP.AmmoPerShot,0);eq(SWEP.ARC9CODWW2UnlimitedFuel,true)
  function SWEP:GetProcessedValue(k) return self[k] end
  function SWEP:GetValue(k) return self[k] end
  function SWEP:GetUBGL() return false end
  function SWEP:GetInfiniteAmmo() return false end -- inventory binding disables the global cheat
  function SWEP:Clip1() return self.clip end
  function SWEP:TakePrimaryAmmo(n) self.clip=self.clip-n end
  function SWEP:GetOwner() return owner end
  function SWEP:GetShootPos() return 0,{Forward=function() return 0 end} end
  SWEP.TakeAmmo=AmmoBase.TakeAmmo;SWEP.HasAmmoInClip=AmmoBase.HasAmmoInClip
  for _,initial in ipairs({0,1000}) do
   SWEP.clip=initial;SWEP.ARC9CODWW2CooldownEnd=999999
   for shot=1,1800 do
    clock=shot/15;assert(SWEP:HasAmmoInClip());assert(not SWEP:HookP_BlockFire())
    SWEP:Hook_PrimaryAttack();SWEP:TakeAmmo();SWEP:Hook_Think();eq(SWEP.clip,initial)
   end
  end
  blocked=true;eq(SWEP:HookP_BlockFire(),true);eq(SWEP:CanReload(),false)
  `,`SWEP={};AmmoBase={};${ammoMethods}
  function AddCSLuaFile() end;function Vector() return 0 end;function Angle() return 0 end
  util.TraceLine=function() return {HitWorld=blocked} end
  owner={valid=true,IsPlayer=function() return true end,SetAmmo=function(_,v) eq(v,0) end}
  `);
 }
};
