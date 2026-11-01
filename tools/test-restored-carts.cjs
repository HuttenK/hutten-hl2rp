// Standalone offline behavior checks. The real native Inventory class and
// recovered kinematics/IK run in Fengari; physics/network/DB remain fixtures.
const fs=require('fs'),path=require('path'),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs'),parse=require('luaparse').parse;
const root=path.resolve(__dirname,'..'),base='ixhl2rp/plugins/pushcart/';
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const source=f=>'do\n'+normalize(read(f))+'\nend\n';
const fixture=read('tools/fixture.lua')+source('tools/fixtures/sharedposes.lua')+source('tools/fixtures/pose-gizmo.lua')+`
SERVER=true;CLIENT=false;ENT={};NULL={};angle_zero=Angle();MASK_SOLID=1;MASK_PLAYERSOLID=1
MOVETYPE_WALK=2;MOVETYPE_NONE=0;MOVETYPE_VPHYSICS=6;SOLID_VPHYSICS=6;SIMPLE_USE=3
IN_USE=32;IN_SPEED=1;IN_JUMP=2;IN_DUCK=4;IN_ATTACK=8;IN_ATTACK2=16;IN_WALK=64
COLLISION_GROUP_NONE=0;COLLISION_GROUP_WEAPON=11;COLLISION_GROUP_DEBRIS=1;COLLISION_GROUP_DEBRIS_TRIGGER=2;COLLISION_GROUP_INTERACTIVE_DEBRIS=3
bit={bor=function(...) local r=0;for _,v in ipairs({...}) do r=r|v end;return r end,band=function(a,b) return a&b end,bnot=function(a) return ~a end}
function AddCSLuaFile() end; function include() end;function Lerp(t,a,b) return a+(b-a)*t end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a} end
function SysTime() return clock end;function isvector(v) return getmetatable(v)==getmetatable(Vector()) end
function math.Approach(a,b,s) return a<b and math.min(a+s,b) or math.max(a-s,b) end
function table.IsEmpty(t) return next(t)==nil end;function table.Add(a,b) for _,v in ipairs(b) do a[#a+1]=v end end
local luaInsert=table.insert;function table.insert(t,...) local a={...};luaInsert(t,...);return #a==1 and #t or a[1] end
function table.RemoveByValue(t,v) for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end end
function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end;return false end
function CreateClientConVar() return {GetBool=function() return false end} end
function ErrorNoHalt(s) errors[#errors+1]=s end;errors={}
local V=getmetatable(Vector());function V:LengthSqr() return self:Dot(self) end
function V:DistToSqr(b) return (self-b):LengthSqr() end;function V:Distance(b) return (self-b):Length() end
function V:Length2D() return math.sqrt(self.x*self.x+self.y*self.y) end
function V:Normalize() local l=self:Length();if l>0 then self.x=self.x/l;self.y=self.y/l;self.z=self.z/l end end
function V:SetUnpacked(x,y,z) self.x=x;self.y=y;self.z=z end
function V:AngleEx(up)
 local f=self:GetNormalized();local left=up:Cross(f):GetNormalized();local a=f:Angle()
 a.r=math.deg(math.atan(left.z,up.z));return a
end
function LocalToWorld(v,a,p,ang)
 local function rotate(v) return ang:Forward()*v.x-ang:Right()*v.y+ang:Up()*v.z end
 return p+rotate(v),rotate(a:Forward()):AngleEx(rotate(a:Up()))
end
function util.CRC(s) return s end; function util.IsValidModel() return false end
util.TraceLine=function(d) return {Hit=false,Entity=NULL,Fraction=1,HitPos=d.endpos,HitNormal=Vector(0,0,1)} end
util.TraceHull=function(d) return {Hit=false,StartSolid=false,Fraction=1,HitPos=d.endpos,HitNormal=Vector(0,0,1)} end
util.IntersectRayWithOBB=function() return nil end
timer.queued={};timer.Simple=function(_,fn) timer.queued[#timer.queued+1]=fn end
function flush() local q=timer.queued;timer.queued={};for _,f in ipairs(q) do f() end end
net.WriteUInt=function() end;net.WriteEntity=function() end;net.WriteString=function() end;net.Send=function() end;net.Start=function() end
engine={TickInterval=function() return 1/66 end}; game={SinglePlayer=function() return false end}
ix.util={Include=function() end}; ix.allowedHoldableClasses={};ix.Item={instances={},entities={}};ix.Inventory={stored={},pendingTransfers={}};ix.storage={}
function ix.Inventory:Get(id) return self.stored[id] end
function ix.Inventory:CancelTransfer(id) local t=self.pendingTransfers[id];local inv=self:Get(t.to_id);if inv then inv:UnreserveSlots(id) end;self.pendingTransfers[id]=nil end
function ix.storage.InUse(i) return i.busy==true end
function ix.storage.Open(c,i,info) i.storageInfo=info;i.receivers[c]=c;c.ixOpenStorage=i end
function ix.storage.RemoveReceiver(c,i) i.receivers[c]=nil;c.ixOpenStorage=nil end
function PLUGIN:SetData(data) self.saved=data end;function PLUGIN:GetData() return self.saved end
local seq=100
function item(w,h)
 seq=seq+1;local i={id=seq,width=w or 1,height=h or 1,model='crate.mdl',data={}}
 function i:SetEntity(e) self.entity=e end;function i:GetEntity() return self.entity end;function i:GetData(k,d) return self.data[k] or d end
 function i:Save() self.saved=(self.saved or 0)+1 end
 function i:Remove(del) local inv=ix.Inventory:Get(self.inventory_id);if inv then inv:TakeItemTable(self) end;if del then ix.Item.instances[self.id]=nil;self.deleted=true end end
 ix.Item.instances[seq]=i;return i
end
ix.Item.Instance=function() local i=item();ix.Item.latest=i;return i end
function ix.Item:LoadInstanceByID(ids,each,done) self.loader={ids=ids,each=each,done=done} end
local classes={};function register(name) if ENT.Base and classes[ENT.Base] then setmetatable(ENT,{__index=classes[ENT.Base]}) end;classes[name]=ENT;ENT={} end
function ents.Create(class)
 local e={valid=true,pos=Vector(),ang=Angle(),class=class,parent=NULL};setmetatable(e,{__index=classes[class]})
 function e:NetworkVar(kind,_,name) self['Get'..name]=function(s) local v=s[name];if v~=nil then return v end;return kind=='Entity' and NULL or (kind=='Bool' and false or 0) end;self['Set'..name]=function(s,v) s[name]=v end end
 e:SetupDataTables()
 function e:GetClass() return self.class end;function e:GetPos() return self.pos end;function e:SetPos(v) self.pos=v end
 function e:GetAngles() return self.ang end;function e:SetAngles(v) self.ang=v end
 function e:GetNW2Entity(k) return self.nw and self.nw[k] end
 function e:SetNW2Entity(k,v) self.nw=self.nw or {};self.nw[k]=v end
 function e:GetParent() return self.parent end;function e:SetParent(p) self.parent=p end
 function e:GetChildren() local found={};for _,other in pairs(ix.PushCart.entities or {}) do if IsValid(other) and other:GetParent()==self then found[#found+1]=other end end;return found end
 function e:LocalToWorld(v) local a=self:GetAngles();return self:GetPos()+a:Forward()*v.x-a:Right()*v.y+a:Up()*v.z end
 function e:WorldToLocal(v) local d=v-self:GetPos();local a=self:GetAngles();return Vector(d:Dot(a:Forward()),-d:Dot(a:Right()),d:Dot(a:Up())) end
 function e:WorldSpaceCenter() return self:GetPos()+Vector(0,0,11) end
 function e:ForcePlayerDrop() self.engineDrop=true end;function e:EmitSound(s) self.lastSound=s end
 function e:SetLocalPos(v) self.pos=v end;function e:SetLocalAngles(v) self.ang=v end
 function e:GetLocalPos() return self.pos end;function e:GetLocalAngles() return self.ang end
 function e:SetModel(m) self.model=m end;function e:GetModel() return self.model end
 function e:NearestPoint() return self.pos end;function e:SetCollisionGroup(v) self.group=v end
 function e:Spawn() self:Initialize() end
 function e:Remove() self.valid=false;self:OnRemove() end
 function e:PhysicsInitMultiConvex(h) self.hulls=h end
 function e:SetCollisionBounds(a,b) self.mins=a;self.maxs=b end
 function e:OBBMins() return self.mins end;function e:OBBMaxs() return self.maxs end
 function e:GetPhysicsObject() self.phys=self.phys or {valid=true,SetMass=function(s,v) s.mass=v end,EnableMotion=function(s,v) s.motion=v end,Wake=function() end,SetPos=function() end,SetAngles=function() end};return self.phys end
 for _,n in ipairs({'PhysicsInit','EnableCustomCollisions','SetMoveType','SetSolid','SetUseType','SetCustomCollisionCheck','NextThink','SetNotSolid','PhysicsInitBox'}) do e[n]=function() end end
 return e
end
function playerFixture()
 local c={valid=true,pos=Vector(),nw={},localVars={},character={}}
 function c:IsPlayer() return true end;function c:Alive() return not self.dead end;function c:GetCharacter() return not self.nochar and self.character or nil end
 function c:GetMoveType() return MOVETYPE_WALK end;function c:InVehicle() return false end
 function c:GetNetVar(k,d) return d end;function c:IsProne() return false end
 function c:GetPos() return self.pos end;function c:GetShootPos() return self.pos end;function c:GetAimVector() return Vector(1,0,0) end
 function c:GetLocalVar(k) return self.localVars[k] end;function c:SetLocalVar(k,v) self.localVars[k]=v end
 function c:SetNW2Entity(k,v) self.nw[k]=v end;function c:GetNW2Entity(k) return self.nw[k] end
 function c:Notify(t) self.notice=t end;function c:EyeAngles() return Angle() end
 function c:KeyDown() return false end;function c:GetWeapon() return self.hands or NULL end
 function c:GetActiveWeapon() return self.hands or NULL end;function c:SelectWeapon() end
 function c:AddItem(i) if self.full then return false end;self.given=i;return true end
 return c
end
`;
const inventory=source('helix/gamemode/game/inventory/sh_inventory.class.lua');
const server=source(base+'libs/sh_bootstrap.lua')+source(base+'sh_plugin.lua')+source(base+'sh_kinematics.lua')+source(base+'sh_drive.lua')+source(base+'sh_interaction.lua')+source(base+'sv_plugin.lua')+source(base+'sv_interaction.lua')+source(base+'sv_legacy.lua')+
source(base+'entities/entities/ix_pushcart/shared.lua')+source(base+'entities/entities/ix_pushcart/init.lua')+`register('ix_pushcart')\n`+
source(base+'entities/entities/ix_medical_gurney.lua')+`register('ix_medical_gurney')\n`+
source(base+'entities/entities/ix_medical_wheelchair.lua')+`register('ix_medical_wheelchair')\n`+
source(base+'entities/entities/ix_cargo_crate.lua')+`register('ix_cargo_crate')\n`;
let count=0;
function run(name,code,extra='',startup=server){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const status=lauxlib.luaL_dostring(L,to_luastring(fixture+inventory+startup+extra+code));
 if(status!==lua.LUA_OK)throw new Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 count++;console.log('PASS '+name);
}
run('Entity uses the requested mesh even when model validation is false, with native cargo and load weight',`
 local c=ents.Create('ix_pushcart');c:Spawn();eq(c:GetComposite(),false);eq(#c.hulls,11)
 eq(c.Model,'models/props_silo/pushcart.mdl');eq(c:GetModel(),c.Model)
 local inv=c:GetInventory();eq(inv.width,6);eq(inv.height,6);assert(inv.type:find('cargo_'))
 local i=item(3,3);assert(inv:AddItem(i));c:UpdateLoad();near(c:GetCargoLoad(),0)
 local snapshot=ix.PushCart:Snapshot(c);eq(snapshot.items[1],i.id);assert(i.saved>0)
`);
run('Admin spawn-menu cart uses the entity model and calibrated floor origin',`
 local user=playerFixture();function user:IsAdmin() return true end
 local class=ents.Create('ix_pushcart')
 local c=class:SpawnFunction(user,{Hit=true,HitPos=Vector(20,30,0),HitNormal=Vector(0,0,1)})
 assert(IsValid(c));eq(c:GetModel(),'models/props_silo/pushcart.mdl');eq(c:GetComposite(),false)
 near(c:GetPos().z+ix.PushCart.Kin.WHEEL_BOTTOM,2);eq(#c.hulls,11)
 function user:IsAdmin() return false end
 eq(class:SpawnFunction(user,{Hit=true}),nil)
`);
run('Requested cart mesh, collision, eight crate footprints and hand targets share the raised model origin',`
 local oldValid=util.IsValidModel;util.IsValidModel=function() return true end
 local c=ents.Create('ix_pushcart');c:Spawn();eq(c:GetComposite(),false);eq(c:GetModel(),'models/props_silo/pushcart.mdl')
 eq(#c.hulls,11);near(c:OBBMins().z,-15.96365);near(c:OBBMaxs().z,36.24)
 for n=1,8 do local box=ents.Create('ix_cargo_crate');box:Spawn();assert(c:AttachCrate(box)) end
 for n,box in ipairs(c.crates) do
  local p=box:GetLocalPos();assert(p.x-10.5>=c.BedMinX and p.x+10.5<=c.BedMaxX)
  assert(math.abs(p.y)+10.5<c.BedHalfY);near(p.z,c.BedZ+math.floor((n-1)/4)*22)
  for j=1,n-1 do local q=c.crates[j]:GetLocalPos();assert(math.abs(p.x-q.x)>=21 or math.abs(p.y-q.y)>=21 or math.abs(p.z-q.z)>=22) end
 end
 near(c:GetBodyTop(),c.BedZ+44-ix.PushCart.Kin.WHEEL_BOTTOM)
 local pos=ix.PushCart:PoseTransform(ix.PushCart.Kin.Rest(0,0,0,0));near(pos.z,15.96365)
 near(pos.z+ix.PushCart.Kin.GRIP_Z,51.19965);near(ix.PushCart.Kin.REACH-ix.PushCart.Kin.HANDLE_X,17.994)
 util.IsValidModel=oldValid
`);
run('Legacy cart migration preserves the ground plane and handle side once without replacing cargo inventories',`
 local c=ents.Create('ix_pushcart');c:Spawn();c:SetPos(Vector(100,20,34.5));c:SetAngles(Angle(0,30,0))
 local inv=c:GetInventory();local i=item();assert(inv:AddItem(i))
 local rec=ix.PushCart:Snapshot(c);eq(rec.geometryVersion,3);rec.geometryVersion=nil;rec.pos=Vector(100,20,0)
 ix.PushCart.entities[rec.uid]=nil;inv.owner=nil;c.valid=false
 local loaded=ix.PushCart:RestoreRecord(rec,inv);near(loaded:GetPos().z,16.46365);near(loaded:GetAngles().y,210);eq(loaded:GetInventory(),inv);assert(table.HasValue(inv:GetItems(),i))
 eq(loaded:GetModel(),'models/props_silo/pushcart.mdl');eq(loaded:GetComposite(),false)
 local nextRec=ix.PushCart:Snapshot(loaded);ix.PushCart.entities[nextRec.uid]=nil;inv.owner=nil;loaded.valid=false
 local again=ix.PushCart:RestoreRecord(nextRec,inv);near(again:GetPos().z,16.46365);near(again:GetAngles().y,210);eq(again:GetInventory(),inv)
`);
run('Taking a tilted cart handle reconstructs the same wheel plane, origin and orientation without a sideways jump',`
 local P,K=ix.PushCart,ix.PushCart.Kin;local c=ents.Create('ix_pushcart');c:Spawn();local user=playerFixture()
 local original=K.FindFree;local captured
 K.FindFree=function(_,pose) captured=pose;return nil end
 for _,angles in ipairs({Angle(30,0,0),Angle(0,90,20),Angle(25,57,18),Angle(-28,-110,-17)}) do
  local origin=Vector(10,20,34);c:SetPos(origin);c:SetAngles(angles);captured=nil
  eq(c:StartPush(user),false);assert(captured)
  local support=origin+angles:Up()*K.WHEEL_BOTTOM
  vectorNear(Vector(captured.x,captured.y,captured.z0),support)
  local restored,orientation=P:PoseTransform(captured)
  vectorNear(restored,origin);vectorNear(orientation:Forward(),angles:Forward());vectorNear(orientation:Up(),angles:Up())
 end
 K.FindFree=original
`);
run('Version 2 EP2 migration preserves tilted support, cargo identity and handle side without migrating twice',`
 local P,K=ix.PushCart,ix.PushCart.Kin
 for _,angle in ipairs({Angle(0,0,0),Angle(23,87,-15),Angle(-20,-110,17)}) do
  local c=ents.Create('ix_pushcart');c:Spawn();c:SetPos(Vector(10,20,50));c:SetAngles(angle)
  local box=ents.Create('ix_cargo_crate');box:Spawn();local content=item();assert(box:GetInventory():AddItem(content));assert(c:AttachCrate(box))
  local inv,boxInv=c:GetInventory(),box:GetInventory();local rec=P:Snapshot(c);rec.geometryVersion=2
  local support=rec.pos+angle:Up()*-34
  P.entities[c.cargoUID]=nil;P.entities[box.cargoUID]=nil;c.valid=false;box.valid=false;inv.owner=nil;boxInv.owner=nil
  local loaded=P:RestoreRecord(rec,inv)
  vectorNear(loaded:GetPos()+loaded:GetAngles():Up()*K.WHEEL_BOTTOM,support)
  vectorNear(loaded:GetAngles():Forward(),-angle:Forward());vectorNear(loaded:GetAngles():Up(),angle:Up())
  eq(loaded.crates[1]:GetInventory(),boxInv);assert(table.HasValue(boxInv:GetItems(),content))
  near(loaded.crates[1]:GetLocalPos().z,loaded.BedZ)
  local saved=P:Snapshot(loaded);local point,rotation=saved.pos,saved.ang;eq(saved.geometryVersion,3)
  P.entities[loaded.cargoUID]=nil;loaded.valid=false;inv.owner=nil
  local again=P:RestoreRecord(saved,inv)
  vectorNear(again:GetPos(),point);vectorNear(again:GetAngles():Forward(),rotation:Forward())
 end
`);
run('Saving an old live cart after code refresh retains its old origin version until restoration',`
 local P=ix.PushCart;local cart=ents.Create('ix_pushcart');cart:Spawn()
 cart.cartGeometryVersion=nil;cart:SetModel('models/props_junk/pushcart02a.mdl');cart:SetPos(Vector(0,0,34))
 local rec=P:Snapshot(cart);eq(rec.geometryVersion,2)
 P.entities[cart.cargoUID]=nil;cart.valid=false;cart:GetInventory().owner=nil
 local restored=P:RestoreRecord(rec,cart:GetInventory());near(restored:GetPos().z,15.96365)
 eq(P:Snapshot(restored).geometryVersion,3)
`);
run('EP2 asymmetric axle probes fit sloped ground without shifting the model origin',`
 local K=ix.PushCart.Kin
 for _,yaw in ipairs({0,57,180,-130}) do
  local prev=K.Rest(10,20,4,yaw,.22,-.12)
  local function slope(d)
   local z=K.PlaneAt(prev,d.start.x,d.start.y)
   return {Hit=true,StartSolid=false,HitPos={z=z},HitNormal={x=0,y=0,z=1}}
  end
  local pose=K.EvalPose(slope,10,20,yaw,prev,{})
  assert(pose);near(pose.z0,prev.z0);near(pose.a,prev.a);near(pose.b,prev.b)
  local midX,midY=0,0
  for i=1,4 do midX=midX+pose.wx[i]/4;midY=midY+pose.wy[i]/4 end
  near(midX,10+K.WHEEL_CENTER_X*prev.cp*prev.c);near(midY,20+K.WHEEL_CENTER_X*prev.cp*prev.s)
 end
`);
run('Eight crates maximum; detaching selects the exact crate and preserves its inventory',`
 local cart=ents.Create('ix_pushcart');cart:Spawn();local p=playerFixture();local crates={}
 for n=1,9 do local c=ents.Create('ix_cargo_crate');c:Spawn();crates[n]=c;eq(cart:AttachCrate(c),n<=8) end
 eq(cart:GetCrateCount(),8);near(cart:GetCargoLoad(),0.5);eq(crates[5].cartColumn,1)
 local i=item(4,4);assert(crates[5]:GetInventory():AddItem(i));crates[5]:UpdateLoad();cart:UpdateLoad();near(cart:GetCargoLoad(),0.5625)
 local inv=crates[5]:GetInventory();local chosen=crates[1]:GetInventory()
 assert(cart:UnloadCrate(p,crates[1]));eq(cart:GetCrateCount(),7)
 eq(crates[1]:GetParent(),NULL);eq(crates[1]:GetInventory(),chosen);eq(crates[1].ixAutoLoadBlockedCart,cart)
 eq(crates[5]:GetParent(),cart);eq(crates[5]:GetInventory(),inv);eq(i.inventory_id,inv.id)
`);
run('Pack rollback deletes only failed newly-created item; loaded/busy/pending storage remains intact',`
 local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture();p.full=true
 eq(ix.PushCart:Pack(p,c,'pushcart'),false);eq(c.valid,true);eq(ix.Item.latest.deleted,true)
 p.full=false;local i=item();assert(c:GetInventory():AddItem(i));eq(ix.PushCart:Pack(p,c,'pushcart'),false);eq(i.deleted,nil)
 c:GetInventory():TakeItemTable(i);c:GetInventory().busy=true;eq(ix.PushCart:Pack(p,c,'pushcart'),false)
 c:GetInventory().busy=false;ix.Inventory.pendingTransfers[1]={from_id=999,to_id=c:GetInventoryID()};eq(ix.PushCart:Pack(p,c,'pushcart'),false)
 ix.Inventory.pendingTransfers={};assert(ix.PushCart:Pack(p,c,'pushcart'));eq(c.valid,false);assert(p.given)
`);
run('Pending transfers are cancelled with their target reservations even after UI receiver vanished',`
 local c=ents.Create('ix_cargo_crate');c:Spawn();local inv=c:GetInventory()
 inv:ReserveSlots(1,1,1,1,17);ix.Inventory.pendingTransfers[17]={from_id=999,to_id=inv.id}
 assert(ix.PushCart:PendingTransfers(inv));ix.PushCart:CloseInventory(c)
 eq(ix.Inventory.pendingTransfers[17],nil);eq(inv.reservedSlots,nil)
`);
run('Restore reuses detached live item once, rejects foreign inventory type, and retains failed placements',`
 local live=item();live.inventory_type='cargo_restore';live.x=1;live.y=1
 local foreign=item();foreign.inventory_type='main'
 local big=item(8,8);big.inventory_type='cargo_restore';big.x=1;big.y=1
 local record={uid='restore',inventoryType='cargo_restore',items={live.id,foreign.id,big.id},width=4,height=4,pos=Vector(),class='ix_cargo_crate'}
 local c=ix.PushCart:RestoreRecord(record);eq(live.inventory_id,c:GetInventoryID());eq(foreign.inventory_id,nil)
 eq(c.unplacedItems[1],big.id);eq(ix.PushCart:Snapshot(c).items[2],big.id)
 eq(ix.PushCart:RestoreRecord(record),c);eq(#c:GetInventory():GetItemsID(),1)
`);
run('Async DB restore and removal keep pending items on the surviving recovery inventory',`
 local record={uid='async',inventoryType='cargo_async',items={42},width=4,height=4,pos=Vector(),class='ix_cargo_crate'}
 local c=ix.PushCart:RestoreRecord(record);eq(c.cargoLoading,true);local inv=c:GetInventory()
 c:Remove();flush();local restored=ix.PushCart.entities.async;assert(IsValid(restored));eq(restored:GetInventory(),inv);eq(restored.cargoLoading,true)
 local i=item();ix.Item.instances[i.id]=nil;i.id=42;ix.Item.instances[42]=i;i.inventory_type='cargo_async';i.x=1;i.y=1
 ix.Item.loader.each(i);ix.Item.loader.done();eq(restored.cargoLoading,nil);eq(i.inventory_id,inv.id)
`);
run('Missing SQL item callbacks retain saved IDs and recovery hydrates them without cloning live cargo',`
 local record={uid='missing',inventoryType='cargo_missing',items={42},width=4,height=4,pos=Vector(),class='ix_cargo_crate'}
 local c=ix.PushCart:RestoreRecord(record);ix.Item.loader.done()
 eq(c.cargoLoading,nil);eq(c.unplacedItems[1],42);eq(ix.PushCart:Snapshot(c).items[1],42);assert(ix.PushCart:HasContents(c))
 local result;ix.PushCart:RetryUnplaced(c,function(n,left) result={n,left} end);eq(c.cargoLoading,true)
 local i=item();ix.Item.instances[i.id]=nil;i.id=42;ix.Item.instances[42]=i;i.inventory_type='cargo_missing'
 ix.Item.loader.each(i);ix.Item.loader.done()
 eq(result[1],1);eq(result[2],0);eq(c.unplacedItems,nil);eq(i.inventory_id,c:GetInventoryID());eq(i.deleted,nil)
`);
run('Map cleanup restores live cargo and attached crates without DB cloning',`
 local c=ents.Create('ix_pushcart');c:Spawn();local i=item();c:GetInventory():AddItem(i);local inv=c:GetInventory();local uid=c.cargoUID
 local crate=ents.Create('ix_cargo_crate');crate:Spawn();c:AttachCrate(crate);local cuid=crate.cargoUID
 PLUGIN:PreCleanupMap();c:Remove();crate:Remove();PLUGIN:PostCleanupMap()
 local restored=ix.PushCart.entities[uid];eq(restored:GetInventory(),inv);eq(i.inventory_id,inv.id);eq(restored:GetCrateCount(),1)
 eq(ix.PushCart.entities[cuid]:GetParent(),restored);eq(ix.Item.loader,nil)
`);
run('Deploy consumes exactly one native item after a valid spawn; blocked placement and foreign ownership do not consume',`
 local p=playerFixture();local inv=ix.meta.Inventory:New();inv:SetSize(6,6);inv.type='main';inv.owner=p
 local i=item();i.player=p;assert(inv:AddItem(i));local before=#inv:GetItemsID()
 util.TraceLine=function(d) return {Hit=true,HitPos=Vector(70,0,0),HitNormal=Vector(0,0,1)} end
 util.TraceHull=function() return {Hit=true,StartSolid=true} end
 eq(ix.PushCart:Deploy(i,'ix_pushcart'),false);eq(i.deleted,nil);eq(#inv:GetItemsID(),before)
 util.TraceHull=function() return {Hit=false,StartSolid=false} end
 inv.owner=NULL;eq(ix.PushCart:Deploy(i,'ix_pushcart'),false);eq(i.deleted,nil);inv.owner=p
 assert(ix.PushCart:Deploy(i,'ix_pushcart'));eq(i.deleted,true);eq(#inv:GetItemsID(),0)
`);
run('Deployment failures explain the problem and preserve the folded item',`
 local p=playerFixture();local inv=ix.meta.Inventory:New();inv:SetSize(6,6);inv.owner=p
 local i=item();i.player=p;assert(inv:AddItem(i));local P=ix.PushCart
 p.GetMoveType=function() return 8 end
 eq(P:Deploy(i,'ix_pushcart'),false);assert(p.notice);eq(i.deleted,nil)
 p.GetMoveType=function() return MOVETYPE_WALK end;p.notice=nil;inv.owner=NULL
 eq(P:Deploy(i,'ix_pushcart'),false);assert(p.notice);eq(i.deleted,nil);inv.owner=p
 util.TraceLine=function() return {Hit=true,HitPos=Vector(70,0,0),HitNormal=Vector(0,0,1)} end
 local create=ents.Create
 ents.Create=function() return NULL end;p.notice=nil
 eq(P:Deploy(i,'ix_pushcart'),false);assert(p.notice);eq(i.deleted,nil)
 local failed
 ents.Create=function(class)
  failed=create(class);failed.Spawn=function() end
  failed.Remove=function(self) self.valid=false end;return failed
 end;p.notice=nil
 eq(P:Deploy(i,'ix_pushcart'),false);assert(p.notice);eq(i.deleted,nil)
 eq(failed.valid,false);eq(failed.cargoConsumed,true);eq(#inv:GetItemsID(),1)
 ents.Create=create
`);
run('Crate loading validates holder, storage reservations, capacity and cart operator before dropping held cargo',`
 local c=ents.Create('ix_pushcart');c:Spawn();local crate=ents.Create('ix_cargo_crate');crate:Spawn();local p=playerFixture()
 local drops=0;p.hands={valid=true,heldEntity=crate,DropObject=function() drops=drops+1;crate.ixHeldOwner=nil end}
 eq(c:LoadCrate(p,crate),false);eq(drops,0);crate.ixHeldOwner=p
 ix.Inventory.pendingTransfers[17]={from_id=crate:GetInventoryID(),to_id=999}
 eq(c:LoadCrate(p,crate),false);eq(drops,0);ix.Inventory.pendingTransfers={}
 assert(c:LoadCrate(p,crate));eq(drops,1);eq(crate:GetParent(),c)
 eq(c:LoadCrate(p,crate),false);eq(drops,1)
`);
run('Unplaced native item can be recovered after room is made, without deleting or cloning it',`
 local c=ents.Create('ix_cargo_crate');c:Spawn();local inv=c:GetInventory();local full=item(4,4);assert(inv:AddItem(full))
 local extra=item();extra.inventory_type=inv.type;c.unplacedItems={extra.id};inv.unplacedItems=c.unplacedItems
 eq(ix.PushCart:RetryUnplaced(c),0);eq(extra.inventory_id,nil);eq(c.unplacedItems[1],extra.id)
 inv:TakeItemTable(full);eq(ix.PushCart:RetryUnplaced(c),1);eq(extra.inventory_id,inv.id);eq(c.unplacedItems,nil);eq(extra.deleted,nil)
`);
run('Push state links, death/teleport flags and stale sprint state release correctly',`
 local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture();p.pos=Vector(-52,0,0)
 local K=ix.PushCart.Kin;K.FindFree=function(_,pose) return pose end
 assert(c:StartPush(p));eq(ix.PushCart:GetPushedCart(p),c);eq(p.nw.ixPushCart,c)
 local mv={limit=999};function mv:GetButtons() return 31 end;function mv:SetButtons(b) self.buttons=b end
 function mv:SetMaxClientSpeed(v) self.limit=v end;function mv:GetMaxClientSpeed() return self.limit end;function mv:SetMaxSpeed(v) self.max=v end;function mv:GetVelocity() return Vector() end
 assert(ix.PushCart:LimitMovement(p,mv,100));assert(mv.limit<13);eq(mv.max,mv.limit);eq(mv.buttons,0)
 c.releaseFlag=true;assert(c:ShouldRelease());c:StopPush();eq(ix.PushCart:GetPushedCart(p),nil);eq(p.nw.ixPushCart,NULL)
 assert(c:StartPush(p));p.dead=true;assert(c:ShouldRelease());PLUGIN:PlayerDeath(p);eq(c:GetPusher(),NULL)
`);
run('Kinematic movement is deterministic, load slows turning, void support rejects acquisition',`
 local K=ix.PushCart.Kin
 local function flat(d)
  if d.start.z+d.mins.z>=0 and d.endpos.z+d.mins.z<0 then return {Hit=true,StartSolid=false,Fraction=d.start.z/(d.start.z-d.endpos.z),HitPos={z=0},HitNormal={x=0,y=0,z=1}} end
  return {Hit=false,StartSolid=false,Fraction=1}
 end
 local pose=K.FindFree(flat,K.Rest(0,0,0,0),0,K.BODY_TOP_EMPTY);assert(pose)
 local s={pose=pose,rate=0,hx=54,hy=0,load=0,top=K.BODY_TOP_EMPTY}
 local input={p0x=54,p0y=0,p0z=0,p1x=53,p1y=0,p1z=0,eyeYaw=180,dt=1/66}
 local a,ax,ay=K.Step(flat,s,input);local b,bx,by=K.Step(flat,s,input);near(a.pose.x,b.pose.x);near(ax,bx);near(ay,by);near(ax,-1)
 local empty=K.TurnTowards(0,0,90,0.1,0);local full=K.TurnTowards(0,0,90,0.1,1);assert(empty>full)
 eq(K.FindFree(function() return {Hit=false,StartSolid=false} end,K.Rest(0,0,0,0),0,K.BODY_TOP_EMPTY),nil)
`);
run('Procedural arm IK preserves limb lengths, reaches targets, and safely handles unreachable grips',`
 local shoulder,elbow,wrist=Vector(),Vector(10,0,0),Vector(10,10,0)
 local e,w=ix.PushCart.SolveArm(shoulder,elbow,wrist,Vector(8,12,0),Vector(0,0,-1))
 near(e:Distance(shoulder),10);near(w:Distance(e),10);near(w:Distance(Vector(8,12,0)),0)
 e,w=ix.PushCart.SolveArm(shoulder,elbow,wrist,Vector(100,0,0),Vector(0,0,-1));assert(w:Length()<20);near(e:Distance(w),10)
 eq(ix.PushCart.GRIP_RIGHT.x,-ix.PushCart.Kin.HANDLE_X);eq(ix.PushCart.GRIP_LEFT.z,ix.PushCart.Kin.GRIP_Z)
`,source(base+'cl_ik.lua'));
const clientSource=`SERVER=false;CLIENT=true;ENT={};function Matrix() return {} end;function Material() return {} end\n`+
 source(base+'entities/entities/ix_pushcart/cl_init.lua')+`
 local ClientCart=ENT
 function clientCart()
  SERVER=true;CLIENT=false
  local c=ents.Create('ix_pushcart');c:Spawn();c.compositePhysics=nil;c.cargoRevision=c:GetCargoRev()
  SERVER=false;CLIENT=true
  c.ClientInitialize=ClientCart.Initialize;c.Think=ClientCart.Think;c.OnRemove=ClientCart.OnRemove;c.ClearCargoModels=ClientCart.ClearCargoModels
  c.renderWrites=0
  function c:SetRenderBounds(a,b) self.renderMins=a;self.renderMaxs=b;self.renderWrites=self.renderWrites+1 end
  return c
 end
 function LocalPlayer() return NULL end
`;
run('Client initialization and Think work without helper lookup on a stale entity table',`
 local c=clientCart();eq(c.PadRenderBounds,nil)
 c:ClientInitialize();eq(c.renderWrites,1);eq(ix.PushCart.carts[c],true)
 vectorNear(c.renderMins,Vector(-70,-55,-47.96365));vectorNear(c.renderMaxs,Vector(71.72,55,68.24))
 c:Think();eq(c.compositePhysics,true);eq(c.renderWrites,2);eq(c:GetPhysicsObject().motion,false)
 c:Think();eq(c.renderWrites,2)
 c:OnRemove();eq(ix.PushCart.carts[c],nil);eq(c.renderPadded,nil)
 c.cargoRevision=c:GetCargoRev();c:Think();eq(ix.PushCart.carts[c],true);eq(c.renderWrites,3)
`,clientSource);
run('Client bounds retry when the model arrives after initialization',`
 local c=clientCart();c.compositePhysics=true;c.mins=Vector();c.maxs=Vector()
 c:ClientInitialize();eq(c.renderWrites,0);eq(c.renderPadded,nil)
 c.mins=Vector(-38,-23,-15.96365);c.maxs=Vector(39.72,23,36.24)
 c:Think();eq(c.renderWrites,1);eq(c.renderPadded,true)
`,clientSource);
run('Automatic loading releases hand and engine holds, preserves contents, and snaps into a calibrated slot',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:SetPos(Vector(0,0,15.96365));c:Spawn()
 local crate=ents.Create('ix_cargo_crate');crate:Spawn();crate:SetPos(Vector(0,32,20))
 local i=item();assert(crate:GetInventory():AddItem(i));local inv=crate:GetInventory()
 local p=playerFixture();p.hands={valid=true,heldEntity=crate,DropObject=function(self) self.dropped=true;self.heldEntity=nil;crate.ixHeldOwner=nil end}
 crate.ixHeldOwner=p
 assert(crate:Think());eq(p.hands.dropped,true);eq(crate.engineDrop,true)
 eq(crate:GetParent(),c);eq(crate:GetInventory(),inv);eq(i.inventory_id,inv.id)
 vectorNear(crate:GetLocalPos(),c:CrateSlot(1));eq(c:GetCrateCount(),1)
 eq(P:TryAutoLoad(crate),false);eq(c:GetCrateCount(),1)
`);
run('Loading rejects walls, full or moving carts, active storage and transfers without dropping the held crate',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:SetPos(Vector(0,0,15.96365));c:Spawn()
 local crate=ents.Create('ix_cargo_crate');crate:Spawn();crate:SetPos(Vector(0,0,20))
 local p=playerFixture();p.hands={valid=true,heldEntity=crate,DropObject=function() error('Must not release rejected cargo') end};crate.ixHeldOwner=p
 util.TraceHull=function() return {Hit=true,StartSolid=false} end;eq(P:TryAutoLoad(crate),false)
 util.TraceHull=function() return {Hit=false,StartSolid=false} end
 for _,entity in ipairs({crate,c}) do
  entity:GetInventory().busy=true;eq(P:TryAutoLoad(crate),false);entity:GetInventory().busy=false
  entity.cargoLoading=true;eq(P:TryAutoLoad(crate),false);entity.cargoLoading=nil
  ix.Inventory.pendingTransfers[42]={from_id=entity:GetInventoryID(),to_id=999};eq(P:TryAutoLoad(crate),false);ix.Inventory.pendingTransfers={}
 end
 c:SetPusher(p);eq(P:TryAutoLoad(crate),false);c:SetPusher(NULL)
 for n=1,8 do local full=ents.Create('ix_cargo_crate');full:Spawn();assert(c:AttachCrate(full)) end
 eq(P:TryAutoLoad(crate),false);eq(crate:GetParent(),NULL);eq(crate.engineDrop,nil)
`);
run('Detaching a selected lower crate does not immediately reload it; leaving the zone rearms loading',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:SetPos(Vector(0,0,15.96365));c:Spawn()
 local crate=ents.Create('ix_cargo_crate');crate:Spawn();assert(c:AttachCrate(crate))
 local p=playerFixture();assert(c:UnloadCrate(p,crate));eq(crate:GetParent(),NULL);eq(crate:GetPhysicsObject().motion,true)
 crate:SetPos(Vector(0,0,20));eq(P:TryAutoLoad(crate),false);eq(crate:GetParent(),NULL)
 local record=P:Snapshot(crate);eq(record.autoLoadBlockedUID,c.cargoUID)
 local inv=crate:GetInventory();P.entities[crate.cargoUID]=nil;P.crates[crate]=nil;crate.valid=false
 crate=P:RestoreRecord(record,inv);eq(crate.ixAutoLoadBlockedUID,c.cargoUID);eq(P:TryAutoLoad(crate),false)
 crate:SetPos(Vector(300,0,20));eq(P:TryAutoLoad(crate),false);eq(crate.ixAutoLoadBlockedCart,nil)
 crate:SetPos(Vector(0,0,20));assert(P:TryAutoLoad(crate));eq(crate:GetParent(),c)
`);
run('Detach searches beside the player if the cart blocks the front; fully blocked unloading leaves cargo intact',`
 local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture()
 local crate=ents.Create('ix_cargo_crate');crate:Spawn();assert(c:AttachCrate(crate))
 local inv=crate:GetInventory();local calls=0
 util.TraceHull=function() calls=calls+1;return {Hit=calls==1,StartSolid=false} end
 assert(c:UnloadCrate(p,crate));eq(calls,2);eq(crate:GetInventory(),inv);eq(crate:GetParent(),NULL)
 assert(c:AttachCrate(crate));util.TraceHull=function() return {Hit=true,StartSolid=true} end
 eq(c:UnloadCrate(p,crate),false);eq(crate:GetParent(),c);eq(c:GetCrateCount(),1);eq(crate:GetInventory(),inv)
`);
run('Loading zone follows a rotated cart and does not collect distant, overhead or below-floor crates',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:SetPos(Vector(300,200,15.96365));c:SetAngles(Angle(0,90,0));c:Spawn()
 local crate=ents.Create('ix_cargo_crate');crate:Spawn()
 local function place(localPoint) crate:SetPos(c:LocalToWorld(localPoint)-Vector(0,0,11)) end
 place(Vector(0,0,0));assert(P:InLoadingZone(c,crate))
 for _,point in ipairs({Vector(100,0,0),Vector(0,90,0),Vector(0,0,100),Vector(0,0,-80)}) do
  place(point);eq(P:InLoadingZone(c,crate),false);eq(P:TryAutoLoad(crate),false)
 end
`);
run('E opens choices without pushing, packing or detaching; action tickets are checked and consumed once',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture()
 util.TraceLine=function() return {Hit=true,Entity=c,Fraction=.5,HitPos=c:GetPos()} end
 PLUGIN:KeyPress(p,IN_USE);assert(p.ixCartMenu);eq(c:GetPusher(),NULL);eq(p.given,nil)
 local token=p.ixCartMenu.token;c:Use(p);eq(p.ixCartMenu.token,token)
 assert(table.HasValue(p.ixCartMenu.options,'push'));eq(table.HasValue(p.ixCartMenu.options,'open'),false)
 eq(P:PerformInteraction(p,c,token,'open'),false);eq(p.ixOpenStorage,nil)
 eq(P:PerformInteraction(p,c,token,'open'),false)
 ix.storage.RemoveReceiver(p,c:GetInventory());clock=clock+1
 c:Use(p);token=p.ixCartMenu.token;p.character={};eq(P:PerformInteraction(p,c,token,'pack'),false);eq(c.valid,true)
 clock=clock+1;c:Use(p);token=p.ixCartMenu.token;clock=clock+16
 eq(P:PerformInteraction(p,c,token,'pack'),false);eq(c.valid,true)
 clock=clock+1;c:Use(p);token=p.ixCartMenu.token
 util.TraceLine=function() return {Hit=true,Entity=NULL,Fraction=.1} end
 eq(P:PerformInteraction(p,c,token,'pack'),false);eq(c.valid,true)
`);
run('Attached-crate menu detaches exactly its selected entity and rejects parent or busy-state changes',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture();local crates={}
 for n=1,5 do local v=ents.Create('ix_cargo_crate');v:Spawn();assert(c:AttachCrate(v));crates[n]=v end
 util.TraceLine=function() return {Hit=true,Entity=crates[1],Fraction=.2} end
 crates[1]:Use(p);local token=p.ixCartMenu.token;eq(p.ixCartMenu.options[1],'detach');eq(crates[1]:GetParent(),c)
 assert(P:PerformInteraction(p,crates[1],token,'detach'));eq(crates[1]:GetParent(),NULL);eq(crates[5]:GetParent(),c)
 clock=clock+1;util.TraceLine=function() return {Hit=true,Entity=crates[2],Fraction=.2} end
 crates[2]:Use(p);token=p.ixCartMenu.token;crates[2]:GetInventory().busy=true
 eq(P:PerformInteraction(p,crates[2],token,'detach'),false);eq(crates[2]:GetParent(),c)
 crates[2]:GetInventory().busy=false;clock=clock+1;crates[2]:Use(p);token=p.ixCartMenu.token;crates[2]:SetParent(NULL)
 eq(P:PerformInteraction(p,crates[2],token,'detach'),false)
`);
run('An attached crate is selectable before the chassis but never through a wall',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:Spawn();local crate=ents.Create('ix_cargo_crate');crate:Spawn();assert(c:AttachCrate(crate))
 local p=playerFixture();util.IntersectRayWithOBB=function() return Vector(),Vector(),.3 end
 util.TraceLine=function() return {Hit=true,Entity=c,Fraction=.6} end;eq(P:InteractionTarget(p),crate)
 util.TraceLine=function() return {Hit=true,Entity=NULL,Fraction=.2} end;eq(P:InteractionTarget(p),nil)
`);
run('The native item-menu factory opens at screen centre and rejects repeat clicks and stale characters',`
 local P=ix.PushCart;local c=ents.Create('ix_pushcart');c:Spawn();local p=playerFixture()
 function LocalPlayer() return p end;function ScrW() return 1280 end;function ScrH() return 720 end
 gui={IsGameUIVisible=function() return false end,IsConsoleVisible=function() return false end};vgui={CursorVisible=function() return false end}
 ix.SimpleMenu=function()
  local m={valid=true,options={}}
  function m:AddOption(label,fn) local row={label=label,click=fn,SetImage=function() end,SetEnabled=function() end};self.options[#self.options+1]=row;return row end
  function m:Remove() self.valid=false end;function m:Open(x,y) self.x=x;self.y=y end;return m
 end
 util.TraceLine=function() return {Hit=true,Entity=c,Fraction=.2} end
 local ints;net.ReadEntity=function() return c end;net.ReadUInt=function() local v=table.remove(ints,1);return v end
 net.ReadString=function() return 'open' end;net.SendToServer=function() sent=(sent or 0)+1 end
 ints={71,1};net.handlers.ixPushCartMenu();eq(P.menu.x,640);eq(P.menu.y,360)
 local option=P.menu.options[1];option.click();option.click();eq(sent,1)
 ints={72,1};net.handlers.ixPushCartMenu();option=P.menu.options[1];p.character={};option.click();eq(sent,1)
`,source(base+'sh_patient.lua')+source(base+'cl_interaction.lua'));
run('Crate menus keep storage and carrying but never fold; retired cart storage rejects direct and transfer paths',`
 local P=ix.PushCart;local p=playerFixture();local crate=ents.Create('ix_cargo_crate');crate:Spawn()
 util.TraceLine=function() return {Hit=true,Entity=crate,Fraction=.2} end
 local options=P:InteractionOptions(p,crate);assert(table.HasValue(options,'open'));assert(table.HasValue(options,'pickup'))
 eq(table.HasValue(options,'pack'),false);eq(P:Pack(p,crate,'cargo_crate'),false);eq(P:Pack(p,crate,'pushcart'),false)
 assert(P:OpenInventory(p,crate));eq(p.ixOpenStorage,crate:GetInventory());ix.storage.RemoveReceiver(p,crate:GetInventory())
 local cart=ents.Create('ix_pushcart');cart:Spawn();util.TraceLine=function() return {Hit=true,Entity=cart,Fraction=.2} end
 eq(P:OpenInventory(p,cart),false);eq(PLUGIN:CanTransferItem(item(),cart:GetInventory(),1,1,crate:GetInventory()),false)
 eq(PLUGIN:CanMoveItem(item(),cart:GetInventory()),false)
`);
run('Removing a middle crate leaves every other slot in place, survives save/load, and reuses only the hole',`
 local P=ix.PushCart;local cart=ents.Create('ix_pushcart');cart:Spawn();local p=playerFixture();local crates,positions={},{}
 for n=1,8 do local c=ents.Create('ix_cargo_crate');c:Spawn();assert(cart:AttachCrate(c));crates[n]=c;positions[n]=c:GetLocalPos() end
 local selected=crates[2];local content=item();selected:GetInventory():AddItem(content);local selectedInv=selected:GetInventory()
 assert(cart:UnloadCrate(p,selected));eq(selected:GetParent(),NULL);eq(selected:GetCartSlot(),0);eq(content.inventory_id,selectedInv.id)
 for n,c in ipairs(crates) do if n~=2 then eq(c:GetParent(),cart);eq(c:GetCartSlot(),n);vectorNear(c:GetLocalPos(),positions[n]) end end
 local record=P:Snapshot(cart);eq(record.crates[2].cartSlot,3);eq(record.crates[7].cartSlot,8)
 P.cleaning=true;for _,c in ipairs(crates) do if c~=selected then c:Remove() end end;cart:Remove();P.cleaning=nil
 local restored=P:RestoreRecord(record);eq(restored:GetCrateCount(),7)
 for _,c in ipairs(restored.crates) do vectorNear(c:GetLocalPos(),positions[c:GetCartSlot()]) end
 local replacement=ents.Create('ix_cargo_crate');replacement:Spawn();assert(restored:AttachCrate(replacement))
 eq(replacement:GetCartSlot(),2);vectorNear(replacement:GetLocalPos(),positions[2])
 eq(selected:GetInventory(),selectedInv);eq(content.deleted,nil)
`);
run('A real ray selects each visible crate in rotated stacks regardless of child order or oversized stock OBBs',`
 local P=ix.PushCart;local cart=ents.Create('ix_pushcart');cart:SetPos(Vector(120,250,15.96365));cart:Spawn();local crates={}
 for n=1,8 do
  local c=ents.Create('ix_cargo_crate');c:Spawn();assert(cart:AttachCrate(c));crates[n]=c
  c.GetPos=function(s) return cart:LocalToWorld(s.pos) end;c.GetAngles=function() return cart:GetAngles() end
  c.OBBMins=function() return Vector(-32,-32,-32) end;c.OBBMaxs=function() return Vector(32,32,32) end
 end
 function cart:GetChildren() local a={};for n=8,1,-1 do a[#a+1]=crates[n] end;return a end
 util.TraceLine=function() return {Hit=false,Fraction=1,Entity=NULL} end
 util.IntersectRayWithOBB=function(start,delta,origin,angles,mins,maxs)
  local d=start-origin;local axes={angles:Forward(),-angles:Right(),angles:Up()}
  local lo,hi=0,1
  for i,k in ipairs({'x','y','z'}) do
   local o,v=d:Dot(axes[i]),delta:Dot(axes[i])
   if math.abs(v)<.000001 then if o<mins[k] or o>maxs[k] then return end
   else
    local a,b=(mins[k]-o)/v,(maxs[k]-o)/v;if a>b then a,b=b,a end
    lo,hi=math.max(lo,a),math.min(hi,b);if lo>hi then return end
   end
  end
  return start+delta*lo,Vector(),lo
 end
 local p=playerFixture()
 for _,yaw in ipairs({0,37,90,165}) do
  cart:SetAngles(Angle(0,yaw,0))
  for n,c in ipairs(crates) do
   local normal=cart:GetAngles():Right()*(c:GetLocalPos().y<0 and 1 or -1)
   p.pos=c:GetPos()+Vector(0,0,11)+normal*70;p.GetAimVector=function() return -normal end
   eq(P:InteractionTarget(p),c,'ray chose wrong crate '..n..' at yaw '..yaw)
  end
 end
 util.TraceLine=function() return {Hit=true,Fraction=.1,Entity=NULL} end;eq(P:InteractionTarget(p),nil)
`);
run('Old compartment cargo migrates as the same inventory and unresolved IDs, with retry when space is blocked',`
 local P=ix.PushCart;local cart=ents.Create('ix_pushcart');cart:Spawn();local inv=cart:GetInventory();local uid=cart.cargoUID
 local i=item(6,6);assert(inv:AddItem(i));local lost=item();lost.inventory_type=inv.type
 cart.unplacedItems={lost.id};inv.unplacedItems=cart.unplacedItems
 util.TraceHull=function() return {Hit=true,StartSolid=true} end
 eq(P:MigrateCartInventory(cart),false);eq(inv.owner,cart);eq(cart:GetInventory(),inv);eq(i.deleted,nil)
 util.TraceHull=function() return {Hit=false} end
 assert(P:MigrateCartInventory(cart));eq(P:MigrateCartInventory(cart),false)
 local crate=inv.owner;assert(crate.isCargoCrate);eq(crate:GetInventory(),inv);eq(inv.width,6);eq(inv.height,6)
 eq(i.inventory_id,inv.id);eq(crate.unplacedItems[1],lost.id);eq(crate.ixAutoLoadBlockedUID,uid)
 eq(cart.cargoUID,uid);eq(P.entities[uid],cart);eq(#cart:GetInventory():GetItemsID(),0)
 eq(cart.unplacedItems,nil);PLUGIN:SaveData()
 local occurrences=0;for _,r in ipairs(PLUGIN.saved.records) do for _,id in ipairs(r.items) do if id==i.id then occurrences=occurrences+1 end end end
 eq(occurrences,1)
`);
run('Pending legacy cargo finishes SQL hydration before migration; busy storage is not moved',`
 local P=ix.PushCart;local cart=P:RestoreRecord({uid='old-cart',inventoryType='old-cargo',items={42},width=6,height=6,
  geometryVersion=2,pos=Vector(),class='ix_pushcart'})
 eq(P:MigrateCartInventory(cart),false)
 local i=item();i.id=42;ix.Item.instances[42]=i;i.inventory_type='old-cargo';ix.Item.loader.each(i);ix.Item.loader.done()
 local inv=cart:GetInventory();inv.busy=true;eq(P:MigrateCartInventory(cart),false);inv.busy=false
 assert(P:MigrateCartInventory(cart));eq(inv.owner.isCargoCrate,true);eq(i.inventory_id,inv.id)
`);
run('Legacy world crate converts once into a container and keeps the old item if entity creation fails',`
 local P=ix.PushCart;local i=item();local old=ents.Create('ix_cargo_crate');old:Spawn();i.entity=old
 ix.Item.entities[i.id]=old;old:SetCollisionBounds(Vector(-20,-20,-20),Vector(20,20,20))
 old:SetPos(Vector(100,200,40));local before=ents.Create
 ents.Create=function() return NULL end;eq(P:ConvertCrateItem(i,old),false);eq(i.deleted,nil);eq(old.valid,true);ents.Create=before
 local made;ents.Create=function(class) made=before(class);return made end
 assert(P:ConvertCrateItem(i,old));eq(i.deleted,true);eq(old.valid,false);eq(old.ixIsSafe,true);eq(ix.Item.entities[i.id],nil)
 eq(made.isCargoCrate,true);eq(made:GetInventory().width,4);near(made:GetPos().z,20)
 eq(P:ConvertCrateItem(i,old),false);eq(i:GetEntity(),nil)
`);
const files=[];function walk(dir){for(const f of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){const p=dir+f.name;if(f.isDirectory())walk(p+'/');else if(p.endsWith('.lua'))files.push(p);}}walk(base);
// Execute the real Helix loader, starting with no PushCart namespace. Earlier
// fixtures loaded sh_plugin before entities, the reverse of a fresh game boot.
const loaderText=read('helix/gamemode/core/libs/sh_plugin.lua');
const utilText=read('helix/gamemode/core/sh_util.lua');
const loader=normalize(loaderText.slice(loaderText.indexOf('function ix.plugin.Load('),loaderText.indexOf('function ix.plugin.GetHook(')))+
 normalize(loaderText.slice(loaderText.indexOf('function ix.plugin.LoadEntities('),loaderText.indexOf('function ix.plugin.Initialize(')));
const includes=normalize(utilText.slice(utilText.indexOf('function ix.util.Include('),utilText.indexOf('function ix.util.Lib(')));
const bootFiles=files.map(p=>`bootFiles[${JSON.stringify(p)}]=[==[${normalize(read(p))}]==]`).join('\n');
const boot=`
ix.PushCart=nil;ix.plugin.list={};HOOKS_CACHE={};PLUGIN=nil
local bootFiles={}
${bootFiles}
local currentFile=''
local loadedFiles={};local sentFiles={}
function include(name)
 local full=bootFiles[name] and name or currentFile:match('^(.*[/])')..name
 assert(bootFiles[full], 'Missing fixture file: '..full)
 local prior=currentFile;currentFile=full;loadedFiles[#loadedFiles+1]=full
 local fn,err=load(bootFiles[full], '@'..full);assert(fn,err);fn();currentFile=prior
end
function AddCSLuaFile(name) sentFiles[name]=true end
file={Exists=function(name) return bootFiles[name]~=nil end}
function file.Find(pattern)
 local prefix=pattern:match('^(.*[/])');local onlyLua=pattern:sub(-4)=='.lua'
 local names,dirs,seen={},{},{}
 for full in pairs(bootFiles) do
  if full:sub(1,#prefix)==prefix then
   local tail=full:sub(#prefix+1);local dir=tail:match('^([^/]+)/')
   if dir then if not seen[dir] then dirs[#dirs+1]=dir;seen[dir]=true end
   elseif not onlyLua or tail:sub(-4)=='.lua' then names[#names+1]=tail end
  end
 end
 table.sort(names);table.sort(dirs);return names,dirs
end
function string.StripExtension(s) return s:gsub('%.[^.]+$','') end
ix.util.StripRealmPrefix=function(s) return (s:gsub('^[sc][hl]_','')) end
ix.Locale={LoadFromDir=function() end};ix.faction={LoadFromDir=function() end};ix.class={LoadFromDir=function() end}
ix.plugin.LoadFromDir=function() end;ix.data={Set=function() end,Get=function() return {} end}
ix.Item.stored={}
function ix.Item:LoadFromDir(dir)
 for _,name in ipairs(file.Find(dir..'/*.lua')) do
  ITEM={functions={}};include(dir..'/'..name);self.stored[string.StripExtension(name)]=ITEM;ITEM=nil
 end
end
scripted_ents={Register=function(t,name) if t.Base then setmetatable(t,{__index=function(_,key) local base=classes[t.Base];return base and base[key] end}) end;classes[name]=t end};weapons={Register=function() end}
function Matrix() return {} end;function Material() return {} end
${includes}
${loader}
ix.plugin.Load('pushcart', '${base.slice(0,-1)}')
assert(loadedFiles[1]:find('/libs/'), 'Shared bootstrap must precede items and entity registration')
assert(ix.PushCart.Kin.Step and ix.PushCart.Kin.HANDLE_X)
assert(classes.ix_pushcart.Initialize and classes.ix_pushcart.InitCompositePhysics)
assert(classes.ix_pushcart.Model=='models/props_silo/pushcart.mdl')
`;
run('Actual Helix server cold boot registers and deploys the cart through its item action',`
 local p=playerFixture();local inv=ix.meta.Inventory:New();inv:SetSize(6,6);inv.type='main';inv.owner=p
 local i=item();i.player=p;assert(inv:AddItem(i))
 util.TraceLine=function() return {Hit=true,HitPos=Vector(70,0,0),HitNormal=Vector(0,0,1)} end
 ix.Item.stored.pushcart.functions.Deploy.OnRun(i)
 eq(i.deleted,true)
 local c=next(ix.PushCart.carts);assert(IsValid(c));eq(c:GetModel(),'models/props_silo/pushcart.mdl')
 assert(c:GetInventory());eq(c:GetBodyTop(),ix.PushCart.Kin.BODY_TOP_EMPTY)
 local crates={};for n=1,8 do local v=ents.Create('ix_cargo_crate');v:Spawn();assert(c:AttachCrate(v));crates[n]=v end
 c:LayoutCrates();eq(c:GetCrateCount(),8);near(crates[1]:GetLocalPos().z,c.BedZ)
 -- Reload must preserve the tables captured by the entity, not strand Kin.
 local savedP,savedK=ix.PushCart,ix.PushCart.Kin
 ix.plugin.Load('pushcart', '${base.slice(0,-1)}')
 eq(ix.PushCart,savedP);eq(ix.PushCart.Kin,savedK)
 local fresh=ents.Create('ix_pushcart');fresh:Spawn();eq(fresh:GetModel(),ix.PushCart.MODEL)
 assert(fresh:GetInventory())
 for _,id in ipairs({'medical_gurney','medical_wheelchair'}) do
  local folded=item();folded.player=p;assert(inv:AddItem(folded))
  ix.Item.stored[id].functions.Deploy.OnRun(folded);eq(folded.deleted,true)
  local found
  for entity in pairs(ix.PushCart.carts) do if entity:GetClass()=='ix_'..id then found=entity end end
  assert(found and found.PatientOnly and found.StartPush and found.GetDrawPose==nil)
  assert(found:GetInventory());eq(ix.PushCart:CartItem(found),id)
 end
`, '', boot);
run('Actual Helix client cold boot registers the complete cart renderer before plugin hooks',`
 assert(classes.ix_pushcart.Draw and classes.ix_pushcart.Think and classes.ix_pushcart.PadRenderBounds)
 local c=ents.Create('ix_pushcart');c.mins=Vector(-38,-23,-15.96365);c.maxs=Vector(39.72,23,36.24)
 c.SetRenderBounds=function(self,a,b) self.bounds={a,b} end
 c:Spawn();eq(ix.PushCart.carts[c],true);assert(c.bounds)
 function LocalPlayer() return NULL end
 c.cargoRevision=c:GetCargoRev();c:Think();eq(c.compositePhysics,true)
 eq(c:GetPhysicsObject().motion,false)
`, '', 'SERVER=false;CLIENT=true\n'+boot);
for(const className of ['ix_medical_gurney','ix_medical_wheelchair']) {
 run(className+' spawns, excludes cargo, restores its class and folds to its own item',`
  local P=ix.PushCart;local definition=classes['${className}'];local user=playerFixture()
  function user:IsAdmin() return true end
  local c=definition:SpawnFunction(user,{Hit=true,HitPos=Vector(100,0,0),HitNormal=Vector(0,0,1)})
  assert(c and c.PatientOnly);eq(c:GetClass(),'${className}');eq(c:GetModel(),definition.Model)
  near(c:GetPos().z+P:GetKinematics(c).WHEEL_BOTTOM,2)
  local box=ents.Create('ix_cargo_crate');box:Spawn();eq(c:CanAttachCrate(box),false);eq(c:AttachCrate(box,true),false)
  local record=P:Snapshot(c);local pos=c:GetPos();local inv=c:GetInventory();P.cleaning=true;c:Remove();P.cleaning=nil
  local restored=P:RestoreRecord(record,inv);eq(restored:GetClass(),'${className}');near(restored:GetPos():Distance(pos),0)
  eq(restored:GetModel(),definition.Model);eq(restored:GetInventory(),inv)
  eq(P:Pack(user,restored,'pushcart'),false)
  user.pos=restored:GetPos();local original=ix.Item.Instance;local produced
  ix.Item.Instance=function(self,id) produced=id;return original(self,id) end
  assert(P:Pack(user,restored,P:CartItem(restored)));eq(produced,P.Transports['${className}'].item)
 `);
 run(className+' has independent deterministic motion, tilted model conversion and patient clearance',`
  local P=ix.PushCart;local c=ents.Create('${className}');c:Spawn();local K=P:GetKinematics(c)
  assert(K~=P.Kin);local old=P.Kin.BODY_HALF_Y
  local function floor(d)
   if d.endpos.z<d.start.z then return {Hit=true,StartSolid=false,HitPos={z=0},Fraction=.5} end
   return {Hit=false,StartSolid=false,Fraction=1}
  end
  local pose=assert(K.FindFree(floor,K.Rest(0,0,0,0),0,K.BODY_TOP_EMPTY))
  local state={pose=pose,hx=K.REACH,hy=0,rate=0,load=0,top=K.BODY_TOP_EMPTY}
  local input={p0x=K.REACH,p0y=0,p0z=0,p1x=K.REACH-2,p1y=0,p1z=0,eyeYaw=180,dt=1/66}
  local a,dx,dy=K.Step(floor,state,input);local b,bx,by=K.Step(floor,state,input)
  near(dx,-2);near(dx,bx);near(dy,by);near(a.pose.x,b.pose.x)
  c:SetCargoLoad(.8);local loaded=P:GetKinematics(c);assert(loaded.BODY_HALF_Y>K.BODY_HALF_Y);eq(P.Kin.BODY_HALF_Y,old)
  for _,angle in ipairs({Angle(),Angle(12,35,-8),Angle(-10,220,6)}) do
   local model=P:ModelAngles(c,angle);local original=P:ModelAngles(c,model,true)
   near(original:Forward():Distance(angle:Forward()),0,.001);near(original:Up():Distance(angle:Up()),0,.001)
  end
  local user=playerFixture();user.ixPushCart=c;c:SetPusher(user)
  c:SetAngles(P:ModelAngles(c,Angle(0,180,0)))
  near(math.AngleDifference(P:BodyYaw(user),0),0,.001)
  local noFloor=function() return {Hit=false,StartSolid=false} end
  eq(K.FindFree(noFloor,pose,0,K.BODY_TOP_EMPTY),nil)
 `);
}
for(const f of files)parse(normalize(read(f)),{luaVersion:'5.3'});
parse(normalize(read('ixhl2rp/plugins/!healthsystem/sh_movement.lua')),{luaVersion:'5.3'});
console.log('PASS syntax: '+(files.length+1)+' Lua files');console.log('Restored carts: '+count+' behavior suites passed');

