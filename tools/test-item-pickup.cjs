const fs=require('fs'),path=require('path');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const root=path.resolve(__dirname,'..');
 const hands=fs.readFileSync(path.join(root,'helix/entities/weapons/ix_hands.lua'),'utf8');
 const canHold=normalize(hands.slice(hands.indexOf('function SWEP:CanHoldObject'),hands.indexOf('function SWEP:IsHoldingObject')));
 const itemClass=fs.readFileSync(path.join(root,'helix/gamemode/game/items/sh_item.class.lua'),'utf8');
 const take=normalize(itemClass.slice(itemClass.indexOf('local ITEM_TAKE_ACTION'),itemClass.indexOf('function ITEM:Init')))+'\ntakeAction=ITEM_TAKE_ACTION';
 const setup=`
 ENT={};SWEP={};MOVETYPE_VPHYSICS=6;SOLID_VPHYSICS=6;SIMPLE_USE=1
 FSOLID_CUSTOMRAYTEST=1;FSOLID_CUSTOMBOXTEST=2;bit={bor=function(a,b) return a|b end}
 function AddCSLuaFile() end;function Color() return {} end
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 function V.__unm(a) return Vector(-a.x,-a.y,-a.z) end
 function V.__mul(a,n) return Vector(a.x*n,a.y*n,a.z*n) end
 function V.__eq(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
 function V:LengthSqr() return self.x*self.x+self.y*self.y+self.z*self.z end
 function V:DistToSqr(b) return (self-b):LengthSqr() end
 vector_origin=Vector();shapes={}
 function CreatePhysCollideBox(low,high)
  local s={valid=true,low=low,high=high};shapes[#shapes+1]=s
  function s:Destroy() self.valid=false;self.destroyed=true end
  -- Geometry double, not an engine VPhysics test. Includes yaw and hull extents.
  function s:TraceBox(pos,angle,start,finish,mins,maxs)
   self.rayMins,self.rayMaxs=mins,maxs
   local function localPoint(p)
    p=p-pos;local c,s=math.cos(angle),math.sin(angle)
    return Vector(p.x*c+p.y*s,-p.x*s+p.y*c,p.z)
   end
   local a,b=localPoint(start),localPoint(finish);local d=b-a;local first,last=0,1
   for _,axis in ipairs({'x','y','z'}) do
    local lo,hi=self.low[axis]-maxs[axis],self.high[axis]-mins[axis]
    if math.abs(d[axis])<.00001 then if a[axis]<lo or a[axis]>hi then return false end
    else
     local t,u=(lo-a[axis])/d[axis],(hi-a[axis])/d[axis]
     first=math.max(first,math.min(t,u));last=math.min(last,math.max(t,u))
     if first>last then return false end
    end
   end
   return start+(finish-start)*first,Vector(0,0,1),first
  end
  return s
 end
 function newPhysics(mass)
  local p={valid=true,mass=mass}
  function p:GetMass() return self.mass end;function p:SetMass(v) self.mass=v end
  function p:EnableMotion(v) self.motion=v end;function p:IsMoveable() return self.motion end
  function p:Wake() self.awake=true end
  return p
 end
 function ENT:NetworkVar(kind,slot,key)
  self['Set'..key]=function(s,v) s.net[key]=v end
  self['Get'..key]=function(s) local v=s.net[key];if v~=nil then return v end
   if kind=='Bool' then return false elseif kind=='Vector' then return Vector() else return '' end end
 end
 function ENT:GetModel() return self.model end
 function ENT:SetModel(v) self.model=v end
 function ENT:GetModelScale() return self.scale or 1 end
 function ENT:SetModelScale(v,time) eq(time,0);self.scale=v end
 function ENT:GetModelBounds() return self.low,self.high end
 function ENT:GetPos() return self.pos or Vector() end
 function ENT:GetAngles() return self.angle or 0 end
 function ENT:GetClass() return 'ix_item' end
 function ENT:SetCollisionBounds(a,b) self.collision={a,b} end
 function ENT:EnableCustomCollisions() self.custom=true end
 function ENT:RemoveSolidFlags() self.custom=false end
 function ENT:SetSolid(v) self.solid=v end;function ENT:SetMoveType(v) self.move=v end
 function ENT:SetUseType(v) self.use=v end;function ENT:SetHealth(v) self.health=v end
 function ENT:SetSkin() end
 function ENT:PhysicsInit()
  assert(SERVER,'Client must not create VPhysics')
  self.physics=self.hasPHY and newPhysics(self.mass or 3) or nil
 end
 function ENT:PhysicsInitBox(a,b)
  assert(SERVER);self.box={a,b};self.physics=newPhysics(99)
 end
 function ENT:GetPhysicsObject() return self.physics end
 function ENT:Remove() self:OnRemove();self.valid=false end
 ix.Item={instances={},PerformItemEntityAction=function(_,p,item,entity,action)
  eq(action,'take');item.player=p;local result=takeAction.OnRun(item);item.player=nil;return result end}
 ix.shuttingDown=true
 function newItemEntity(id,kind)
  local e=setmetatable({valid=true,net={},low=Vector(-40,-1,-5),high=Vector(16,1,6)}, {__index=ENT})
  e:SetupDataTables()
  local item={id=id,isWeapon=true,class=kind or 'aoc_longsword',functions={take=takeAction},
   model='models/weapons/ageofchivalry/w_longsword.mdl'}
  function item:GetModel() return self.model end;function item:GetMaterial() end
  function item:GetSkin() return 0 end;function item:SetEntity(e) self.entity=e end
  function item:GetEntity() return self.entity end
  ix.Item.instances[id]=item;e:SetItem(id);e:Initialize();item:SetEntity(e)
  return e,item
 end
 function SWEP:GetOwner() return self.owner end
 function SWEP:IsHoldingObject() return self.holding end
 hook.Add('CanPlayerHoldObject','default',function(_,e) return e:GetClass()=='ix_item' end)
 timer.Exists=function() return false end
 p={valid=true,inventory={}}
 function p:IsPlayer() return true end;function p:GetCharacter() return {} end
 function p:GetInventory() return self.inventory end;function p:GetBackpack() end
 function p:SteamID() return 'test' end
 function p.inventory:AddItem(item) if self.full then return false,'full' end self.item=item;return true end
 function p.inventory:Sync() self.synced=true end
 function p:NotifyLocalized(msg) self.notice=msg end;function p:EmitSound() end
 function p:PerformInteraction(duration,e,callback) eq(duration,.5);self.callback=callback;self.ixInteractionTarget=e end
 `+take+'\n'+canHold;
 const files=['helix/entities/entities/ix_item.lua','ixhl2rp/plugins/aoc_compat/sv_pickups.lua'];
 suite('Rope uses one-tenth world size and matching pickup physics across spawn and reload',
  [...files,'ixhl2rp/schema/items/ziptie.lua','ixhl2rp/plugins/recipes_crafting/recipes/rope.lua'],`
   eq(ITEM.worldModelScale,.1);eq(ITEM.model,'models/props/tools/humans/rope_rigging_big_c.mdl')
   eq(RECIPE.results.ziptie,1);eq(RECIPE.requirements.mat_cloth,2)
   local e,item=newItemEntity(3,'rope')
   for k,v in pairs(ITEM) do if k~='functions' then item[k]=v end end
   e.low=Vector(-100,-40,-20);e.high=Vector(120,60,40)
   e.hasPHY=true;e.mass=100
   for i=1,3 do
    e:SetItem(3);e:Initialize()
    near(e:GetModelScale(),.1);eq(e.physics:GetMass(),1)
    eq(e:GetItemBoxMins(),Vector(-10,-4,-2));eq(e:GetItemBoxMaxs(),Vector(12,6,4))
    assert(e:TestCollision(Vector(0,0,40),Vector(0,0,-80),false,Vector()))
    eq(e:TestCollision(Vector(80,0,40),Vector(0,0,-80),false,Vector()),nil)
   end
   local h=setmetatable({owner=p},{__index=SWEP});assert(h:CanHoldObject(e))
   e:Use(p,p);p.callback(p);eq(p.inventory.item,item);eq(e.valid,false)
   local ordinary=newItemEntity(4,'ordinary');eq(ordinary:GetModelScale(),1)
  `,setup+'\nITEM={functions={}};RECIPE={}');
 const wire=`hook.Add('GetItemPhysicsBounds','aoc',function(...) return PLUGIN:GetItemPhysicsBounds(...) end)`;
 suite('Dropped AoC item can be targeted at blade, held with hands, and taken once; full bags retain it',files,wire+`
  local e,item=newItemEntity(1);local h=setmetatable({owner=p},{__index=SWEP})
  assert(e:GetItemBoxPhysics() and e.physics.awake and e.physics.motion and e.custom)
  eq(e.physics:GetMass(),4);eq(e.box[1],Vector(-40,-2,-5));eq(e.box[2],Vector(16,2,6))
  local hit=e:TestCollision(Vector(-32,0,60),Vector(0,0,-80),false,Vector())
  assert(hit and hit.Fraction>0 and hit.Fraction<1,'Visible blade beyond old +/-8 box must hit')
  eq(e:TestCollision(Vector(80,0,60),Vector(0,0,-80),false,Vector()),nil)
  assert(h:CanHoldObject(e));e.ixHeldOwner=p;eq(h:CanHoldObject(e),false);e.ixHeldOwner=nil
  e.physics:EnableMotion(false);eq(h:CanHoldObject(e),false);e.physics:EnableMotion(true)
  p.inventory.full=true;e:Use(p,p);p.callback(p);eq(p.notice,'full');assert(e.valid);eq(item.player,nil)
  p.inventory.full=false;e:Use(p,p);p.callback(p)
  eq(p.inventory.item,item);eq(p.inventory.synced,true);eq(e.valid,false);eq(item.entity,nil)
  for _,shape in ipairs(shapes) do eq(shape.destroyed,true) end
 `,setup);
 suite('AoC override keeps native mass; other items retain native physics; missing meshes have a traceable fallback',files,wire+`
  local e,item=newItemEntity(2);e.hasPHY=true;e.mass=12;e:Initialize()
  eq(e.physics:GetMass(),12);eq(e.box[1].x,-40)
  item.class='ordinary_weapon';e.box=nil;e:Initialize()
  eq(e:GetItemBoxPhysics(),false);eq(e.box,nil);eq(e.custom,false);eq(e.physics:GetMass(),12)
  e.hasPHY=false;e:Initialize();assert(e:GetItemBoxPhysics());eq(e.box[1],Vector(-8,-8,-8))
  assert(e:TestCollision(Vector(0,0,60),Vector(0,0,-80),false,Vector()))
  item.class='aoc_longsword';e.low=Vector(0,0,0);e.high=Vector(0,0,0)
  eq(PLUGIN:GetItemPhysicsBounds(e,item),nil)
  e.high=Vector(10000,2,2);eq(PLUGIN:GetItemPhysicsBounds(e,item),nil)
  e.low=Vector(-40,-1,-5);e.high=Vector(16,1,6);e.model='models/other.mdl'
  eq(PLUGIN:GetItemPhysicsBounds(e,item),nil)
 `,setup);
 suite('Client trace matches networked box, survives PVS delay/rotation, and frees cached collision shape',
  ['helix/entities/entities/ix_item.lua'],`
   local old=setmetatable({valid=true},{__index=ENT});old:Think();eq(#shapes,0)
   local e=setmetatable({valid=true,net={},pos=Vector(100,50,20),angle=math.pi/2},{__index=ENT})
   e:SetupDataTables();e:SetItemBoxPhysics(true);e:Think();eq(#shapes,0)
   e:SetItemBoxMins(Vector(-40,-2,-5));e:SetItemBoxMaxs(Vector(16,2,6));e:Think()
   eq(#shapes,1);assert(e.custom)
   local hit=e:TestCollision(Vector(100,18,80),Vector(0,0,-80),false,Vector())
   assert(hit and hit.HitPos.z==26)
   for i=1,10 do e:Think() end;eq(#shapes,1)
   local extent=Vector(1,1,3)
   e:TestCollision(Vector(100,18,80),Vector(0,0,-80),true,extent)
   eq(shapes[1].rayMins,-extent);eq(shapes[1].rayMaxs,extent);eq(extent,Vector(1,1,3))
   e:SetItemBoxMaxs(Vector(20,3,8));e:Think();eq(#shapes,2);eq(shapes[1].destroyed,true)
   e:SetItemBoxPhysics(false);e:Think();eq(shapes[2].destroyed,true);eq(e.custom,false)
   e:SetItemBoxPhysics(true);e:Think();e:OnRemove();eq(shapes[3].destroyed,true)
  `,setup+'\nSERVER=false;CLIENT=true');
};
