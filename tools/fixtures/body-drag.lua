-- Entity/physics boundaries. Arm and movement calculations run unmodified.
SERVER=true;CLIENT=false;ix.BodyDrag={};ix.config.Get=function(_,d) return d end
MOVETYPE_WALK=2;MASK_SOLID=1;IN_RELOAD=4;IN_ATTACK=1;IN_ATTACK2=2;NULL={valid=false}
angle_zero=Angle();vector_origin=Vector()
frame=1;function FrameNumber() return frame end
local V=getmetatable(Vector())
function V:LengthSqr() return self:Dot(self) end
function V:Length2DSqr() return self.x*self.x+self.y*self.y end
function V:Distance(v) return (self-v):Length() end
function V:DistToSqr(v) return (self-v):LengthSqr() end
function V:Normalize() local n=self:GetNormalized();self.x,self.y,self.z=n.x,n.y,n.z end
function math.ApproachAngle(a,b,s) return a+math.Clamp(math.AngleDifference(b,a),-s,s) end
local rawMatrix=Matrix
function Matrix(rows)
 local m=rawMatrix();if rows then for r=1,4 do for c=1,4 do m:SetField(r,c,rows[r][c]) end end end;return m
end
local M=getmetatable(Matrix())
function M:GetAngles() return Angle() end
function LocalToWorld(v,a,p,ang) return p+ang:Forward()*v.x-ang:Right()*v.y+ang:Up()*v.z,a end
function WorldToLocal(v,a,p,ang) local d=v-p;return Vector(d:Dot(ang:Forward()),-d:Dot(ang:Right()),d:Dot(ang:Up())),a end
hooks={};function hook.Add(e,n,f) hooks[e]=hooks[e] or {};hooks[e][n]=f end
function hook.Remove(e,n) if hooks[e] then hooks[e][n]=nil end end
function fire(e,...) for _,f in pairs(hooks[e] or {}) do local result=f(...);if result~=nil then return result end end end
hook.Run=fire
engine={TickInterval=function() return 1/66 end}
local nextID=0
function dragEntity(class)
 nextID=nextID+1
 local e={valid=true,id=nextID,class=class,nw={},pos=Vector(),ang=Angle(),removeCallbacks={}}
 function e:EntIndex() return self.id end
 function e:GetClass() return self.class end
 function e:IsPlayer() return self.class=='player' end
 function e:GetPos() return self.pos end
 function e:GetAngles() return self.ang end
 function e:GetNW2Entity(k) return self.nw[k] end
 function e:SetNW2Entity(k,v) self.nw[k]=v end
 function e:GetNW2Int(k,d) return self.nw[k] or d end
 function e:SetNW2Int(k,v) self.nw[k]=v end
 function e:GetNW2Vector(k) return self.nw[k] or Vector() end
 function e:SetNW2Vector(k,v) self.nw[k]=v end
 function e:GetCustomCollisionCheck() return self.custom==true end
 function e:SetCustomCollisionCheck(v) self.custom=v end
 function e:CollisionRulesChanged() self.collisionChanged=true end
 function e:CallOnRemove(k,f) self.removeCallbacks[k]=f end
 function e:RemoveCallOnRemove(k) self.removeCallbacks[k]=nil end
 function e:Remove() self.valid=false;for _,f in pairs(self.removeCallbacks) do f() end end
 function e:SetupBones() end
 return e
end
function dragPlayer()
 local p=dragEntity('player');p.vars={};p.weapons={};p.velocity=Vector();p.character={SetData=function(self,k,v) self[k]=v end}
 function p:GetCharacter() return self.character end
 function p:Alive() return not self.dead end
 function p:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end;return d end
 function p:GetLocalVar(k,d) return self:GetNetVar(k,d) end
 function p:SetNetVar(k,v) self.vars[k]=v end
 p.SetLocalVar=p.SetNetVar
 function p:IsRestricted() return self.restricted end
 function p:InVehicle() return self.vehicle end
 function p:GetMoveType() return self.move or MOVETYPE_WALK end
 function p:GetWeapons() return self.weapons end
 function p:GetActiveWeapon() return self.weapons[1] end
 function p:GetVelocity() return self.velocity end
 function p:GetModelScale() return 1 end
 function p:EyeAngles() return self.ang end
 function p:Crouching() return false end
 function p:GetViewOffset() return Vector(0,0,64) end
 p.GetViewOffsetDucked=p.GetViewOffset
 function p:GetShootPos() return self.pos+Vector(0,0,64) end
 function p:GetAimVector() return self.ang:Forward() end
 function p:ToggleWepRaised() self.raised=(self.raised or 0)+1 end
 function p:GetWalkSpeed() return 200 end
 function p:Notify(s) self.notice=s end
 return p
end
function dragBody(p)
 local b=dragEntity('prop_ragdoll');b.ixPlayer=p;p.ixRagdoll=b
 local ph={valid=true,pos=Vector(20,10,40),calls=0}
 function ph:GetPos() return self.pos end
 function ph:GetAngles() return Angle() end
 function ph:WorldToLocal(v) return v-self.pos end
 function ph:LocalToWorld(v) return v+self.pos end
 function ph:Wake() end
 function ph:ComputeShadowControl(params) self.calls=self.calls+1;self.last=params end
 function b:GetPhysicsObjectNum(i) if i==0 then return ph end end
 function b:GetPhysicsObjectCount() return 1 end
 function b:TranslatePhysBoneToBone() return 0 end
 function b:GetBoneMatrix() local m=Matrix();m:SetTranslation(ph.pos);return m end
 b.ph=ph;return b
end
function dragWeapon(owner,scripted)
 local w=dragEntity('weapon');w.owner=owner;w.clip=5;w.nextFire=0;w.nextAlt=0
 function w:GetOwner() return self.owner end
 function w:IsScripted() return scripted~=false end
 function w:Reload() self.reloads=(self.reloads or 0)+1;return 'reloaded' end
 function w:CanReload() return true end
 function w:GetReloading() return self.reloading end
 function w:GetNextPrimaryFire() return self.nextFire end
 function w:SetNextPrimaryFire(v) self.nextFire=v end
 function w:GetNextSecondaryFire() return self.nextAlt end
 function w:SetNextSecondaryFire(v) self.nextAlt=v end
 function w:Clip1() return self.clip end
 function w:Clip2() return -1 end
 owner.weapons[#owner.weapons+1]=w;return w
end
carrier=dragPlayer();patient=dragPlayer();body=dragBody(patient);allPlayers={carrier,patient}
trace={Entity=body,HitPos=body.ph.pos,PhysicsBone=0,Hit=true}
util.TraceLine=function(data) if data.filter==carrier then return trace end;return obstruction or {Hit=false} end
util.TraceHull=function(data) return collision or {Hit=false,HitPos=data.endpos} end
net.ReadBool=function() return release end;net.ReadEntity=function() return requested or body end
