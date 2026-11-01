-- Engine boundaries only. Cart, drag, medicine and recovery behavior run from
-- production files; all geometry is expressed in Source's local axes.
MASK_PLAYERSOLID=2;MOVETYPE_NONE=0;SOLID_NONE=0;SIMPLE_USE=3
IN_SPEED=8;IN_JUMP=16;IN_DUCK=32;IN_USE=64
bit={bor=function(...) local r=0;for _,v in ipairs({...}) do r=r|v end;return r end,band=function(a,b) return a&b end,bnot=function(a) return ~a end}
ENT={};function AddCSLuaFile() end;function include() end
ix.util={Include=function() end};ix.storage={InUse=function(inv) return inv.busy end}
ix.Medicine={}
ix.PushCart={Kin={BODY_TOP_EMPTY=52.25,WHEEL_BOTTOM=-15.96365}}
function ix.PushCart:PendingTransfers(inv) return inv.pending end
function ix.PushCart:CloseInventory() end
function ix.PushCart:QueueSave() end
function ix.PushCart:Removed() self.removed=(self.removed or 0)+1 end
function table.HasValue(t,v) for _,n in ipairs(t) do if n==v then return true end end return false end
function table.RemoveByValue(t,v) for i,n in ipairs(t) do if n==v then table.remove(t,i) return end end end
net.WriteString=function() end
net.Start=function() end;net.WriteUInt=function() end;net.WriteEntity=function() end;net.Send=function() end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
function isfunction(f) return type(f)=='function' end
local V=getmetatable(Vector());V.__eq=function(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
local A=getmetatable(Angle());A.__eq=function(a,b) return a.p==b.p and a.y==b.y and a.r==b.r end
-- The fixture uses yaw-only cart movement, while production uses the engine's
-- full pitch/roll LocalToWorld transform.
function LocalToWorld(v,a,p,ang) return p+ang:Forward()*v.x-ang:Right()*v.y+ang:Up()*v.z,Angle(a.p+ang.p,a.y+ang.y,a.r+ang.r) end
function WorldToLocal(v,a,p,ang) local d=v-p;return Vector(d:Dot(ang:Forward()),-d:Dot(ang:Right()),d:Dot(ang:Up())),Angle(a.p-ang.p,a.y-ang.y,a.r-ang.r) end
function enrich(e)
 e.model='sd.mdl';e.skin=2;e.groups={[0]=1};e.materials={'metal'};e.submaterials={[0]='camo'};e.color=Color(1,2,3);e.material='custom';e.scale=1
 function e:SetPos(v) self.pos=v end
 function e:SetAngles(a) self.ang=a end
 function e:GetParent() return self.parent or NULL end
 function e:SetParent(p) self.parent=p end
 function e:SetLocalPos(v) self.localPos=v end
 function e:SetLocalAngles(a) self.localAngles=a end
 function e:GetLocalPos() return self.localPos or self.pos end
 function e:GetLocalAngles() return self.localAngles or self.ang end
 function e:GetChildren() return self.children or {} end
 function e:LocalToWorld(v) return LocalToWorld(v,Angle(),self:GetPos(),self:GetAngles()) end
 function e:WorldToLocal(v) return WorldToLocal(v,Angle(),self:GetPos(),self:GetAngles()) end
 function e:NearestPoint(p) return self:GetPos() end
 function e:SetModel(v) self.model=v end
 function e:GetModel() return self.model end
 function e:GetModelScale() return self.scale end
 function e:SetModelScale(v) self.scale=v end
 function e:GetSkin() return self.skin end
 function e:SetSkin(v) self.skin=v end
 function e:GetBodyGroups() return {{id=0}} end
 function e:GetBodygroup(id) return self.groups[id] end
 function e:SetBodygroup(id,v) self.groups[id]=v end
 function e:GetMaterials() return self.materials end
 function e:GetSubMaterial(id) return self.submaterials[id] end
 function e:SetSubMaterial(id,v) self.submaterials[id]=v end
 function e:GetMaterial() return self.material end
 function e:SetMaterial(v) self.material=v end
 function e:GetColor() return self.color end
 function e:SetColor(v) self.color=v end
 function e:GetNoDraw() return self.hidden or false end
 function e:SetNoDraw(v) self.hidden=v end
 function e:IsSolid() return not self.notSolid end
 function e:SetNotSolid(v) self.notSolid=v end
 function e:Spawn() end
 function e:LookupSequence(name) if missingSequence then return -1 end return 3 end
 function e:GetSequenceInfo() return {bbmin=Vector(-40,-12,0),bbmax=Vector(40,12,20)} end
 function e:ResetSequence(v) self.sequence=v;self.cacheInvalid=true end
 function e:SetCycle(v) self.cycle=v end
 function e:SetPlaybackRate(v) self.rate=v end
 function e:SetNW2String(k,v) self.nw[k]=v end
 function e:GetNW2String(k,d) return self.nw[k] or d end
 e.SetupBones = nil -- No client-only method on the server fixture.
 e.InvalidateBoneCache = nil -- Client-only too.
 function e:LookupBone(name) if missingBone then return end return tonumber(name) or 0 end
 function e:GetBoneName(i) return tostring(i) end
 function e:GetBoneMatrix(i) if self.isCartPatient then assert(self.sequence~=nil, "Server pose was not selected");if self.cacheInvalid then self.boneBuilds=(self.boneBuilds or 0)+1;self.cacheInvalid=false end end;local m=Matrix();m:SetTranslation(self.pos+Vector(i*5,0,12));return m end
 function e:SetCollisionBounds(a,b) self.mins,self.maxs=a,b end
 local remove=e.Remove
 function e:Remove() remove(self); if self.isCartPatient then ix.PushCart:PatientDisplayRemoved(self) end end
 return e
end
carrier=enrich(dragPlayer());carrier.pos=Vector(0,-65,0)
patient=enrich(dragPlayer());body=enrich(dragBody(patient));body.inventory={unique='patient inventory'};patient.vars.crit=true
function patient:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
local function physics(position,motion,collisions)
 local p={valid=true,pos=position,angle=Angle(),motion=motion,collisions=collisions}
 function p:GetPos() return self.pos end
 function p:SetPos(v) self.pos=v;self.moves=(self.moves or 0)+1 end
 function p:GetAngles() return self.angle end
 function p:SetAngles(v) self.angle=v end
 function p:IsMotionEnabled() return self.motion end
 function p:EnableMotion(v) self.motion=v end
 function p:IsCollisionEnabled() return self.collisions end
 function p:EnableCollisions(v) self.collisions=v end
 function p:SetVelocity(v) self.velocity=v end
 function p:WorldToLocal(v) return v-self.pos end
 function p:Wake() end
 function p:SetMass(v) self.mass=v end
 return p
end
body.parts={physics(Vector(0,-45,20),true,true),physics(Vector(5,-45,20),false,false)}
function body:GetPhysicsObjectNum(i) return self.parts[i+1] end
function body:GetPhysicsObjectCount() return #self.parts end
function body:TranslatePhysBoneToBone(i) return i end
cart=enrich(dragEntity('ix_pushcart'));cart.ixIsPushCart=true;cart.pos=Vector(0,0,15.96365);cart.crates={}
cart.BedMinX=-31;cart.BedMaxX=36.5;cart.BedZ=1.84;cart.BedHalfY=22
cart.inventory={GetItems=function(self) return self.items or {} end};cart.ph=physics(cart.pos,true,true)
function cart:GetInventory() return self.inventory end
function cart:GetPusher() return self.pusher or NULL end
function cart:SetPusher(p) self.pusher=p end
function cart:GetVelocity() return self.velocity or Vector() end
function cart:GetUp() return self.ang:Up() end
function cart:GetPhysicsObject() return self.ph end
function cart:GetCrateCount() return #self.crates end
function cart:SetCrateCount(n) self.count=n end
function cart:SetCargoLoad(v) self.load=v end
function cart:GetCargoLoad() return self.load end
function cart:SetBodyTop(v) self.top=v end
function cart:GetBodyTop() return self.top end
function cart:SetPushCmd() end
function cart:SetCollisionGroup() end
displays={}
ents={Create=function(class)
 local e=enrich(dragEntity(class));e.isCartPatient=true;lastDisplay=e;displays[#displays+1]=e;return e
end,FindByClass=function(class)
 local found={};for _,e in ipairs(displays) do if IsValid(e) and e.class==class then found[#found+1]=e end end;return found
end}
errors={};function ErrorNoHalt(message) errors[#errors+1]=message end
allPlayers={carrier,patient}
util.IntersectRayWithOBB=function() if rayFraction then return Vector(),Vector(),rayFraction end end
util.TraceLine=function(data)
 if data.filter~=carrier then return {Hit=wall or false,StartSolid=false,Entity=NULL} end
 return trace
end
util.TraceHull=function(data)
 if blockExit then return {Hit=true,StartSolid=true,HitNormal=Vector(0,0,1)} end
 if data.endpos.z<data.start.z then
  return {Hit=not noFloor,HitPos=Vector(data.endpos.x,data.endpos.y,0),HitNormal=Vector(0,0,1)}
 end
 return {Hit=false}
end
trace={Entity=body,HitPos=body.parts[1].pos,PhysicsBone=0,Hit=true,Fraction=.5}
function prepareCart()
 setmetatable(cart,{__index=ENT});ix.PushCart:Register(cart)
 assert(ix.BodyDrag.Start(carrier,body));trace={Entity=cart,Hit=true,Fraction=.8,HitPos=cart.pos}
end
