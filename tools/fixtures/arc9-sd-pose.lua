CLIENT=true;SERVER=false;frame=1
function FrameNumber() return frame end
local V={};V.__index=V
V.__index=function(t,k) return rawget(t,({[1]='x',[2]='y',[3]='z'})[k] or k) or V[k] end
function Vector(x,y,z) if type(x)=='table' then return Vector(x.x,x.y,x.z) end return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
V.__mul=function(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function V:Angle() return Angle(0,0,0) end
local A={};A.__index=A
function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},A) end
function A:Set(b) self.p=b.p;self.y=b.y;self.r=b.r end
function A:Forward() return Vector(1,0,0) end
function A:Right() return Vector(0,-1,0) end
function A:Up() return Vector(0,0,1) end
function A:RotateAroundAxis(axis,degrees) self.r=self.r+degrees end
A.__add=function(a,b) return Angle(a.p+b.p,a.y+b.y,a.r+b.r) end
function LocalToWorld(p,a,base,bang) return p+base,Angle(a.p+bang.p,a.y+bang.y,a.r+bang.r) end
function WorldToLocal(p,a,base,bang) return p-base,Angle(a.p-bang.p,a.y-bang.y,a.r-bang.r) end
vector_origin=Vector();angle_zero=Angle()
function math.NormalizeAngle(n) return (n+180)%360-180 end
math.AngleDifference=function(a,b) return math.NormalizeAngle(a-b) end
ix.anim={GetWeaponHoldType=function(p,w) return p:IsWepRaised() and w:GetHoldType() or w.HoldTypeHolstered or 'passive' end};ix.config.Get=function() return false end
ACT_MP_STAND_IDLE=1;ACT_MP_WALK=2;ACT_MP_RUN=3;ACT_MP_CROUCH_IDLE=4;ACT_MP_CROUCHWALK=5
ACT_HL2MP_IDLE=100;ACT_HL2MP_IDLE_PASSIVE=200;ACT_HL2MP_GESTURE_RELOAD_REVOLVER=300
hooks={};hook.Add=function(event,name,fn) hooks[event]=hooks[event] or {};hooks[event][name]=fn end
function hook.Run(event,...) for _,fn in pairs(hooks[event] or {}) do local r=fn(...);if r~=nil then return r end end end
concommand={Add=function() end}
local function matrix(pos,ang) return {GetTranslation=function() return pos end,GetAngles=function() return ang end} end
p={valid=true,model='models/sd/citizens/citizen_male_05_hair3.mdl',vars={},raised=true,scale=1,cycle=.5,chest=Vector(100,200,64),yaw=45,ground=true}
function p:IsPlayer() return true end;function p:GetCharacter() return true end
function p:Alive() return not self.dead end;function p:IsDormant() return false end
function p:GetModel() return self.model end;function p:GetNetVar(k) return self.vars[k] end
function p:GetSequenceCount() return 10 end;function p:IsWepRaised() return self.raised end
function p:SelectWeightedSequence() return self.native and 0 or -1 end
function p:LookupBone(n) if n~=self.missingBone then return n=="ValveBiped.Bip01_Spine4" and 0 or 1 end end
function p:InVehicle() return self.vehicle end;function p:OnGround() return self.ground end
function p:GetRenderAngles() return Angle(0,self.yaw,0) end;function p:EyeAngles() return Angle(20,self.yaw+10,0) end
function p:GetModelScale() return self.scale end;function p:GetCycle() return self.cycle end
function p:GetVelocity() return Vector() end;function p:SetupBones() end;function p:InvalidateBoneCache() end
function p:GetBoneMatrix() return matrix(self.chest,Angle(33,44,55)) end
function p:GetActiveWeapon() return w end
donors={};removed=0;util.IsValidModel=function() return not missingModel end
function ClientsideModel(path)
 if missingModel then return nil end
 local d={valid=true,poses={}};donors[#donors+1]=d
 function d:SetNoDraw() end;function d:DrawShadow() end;function d:SetPlaybackRate() end
 function d:GetSequenceCount() return 500 end
 function d:SelectWeightedSequence(act) return missingActivity and -1 or act end
 function d:LookupBone(n) if not missingDonorBone then return n=="ValveBiped.Bip01_Spine4" and 0 or 1 end end
 function d:SetPos(pos) self.pos=pos end;function d:SetAngles(ang) self.ang=ang end
 function d:SetModelScale(scale) self.scale=scale end;function d:GetSequence() return self.seq end
 function d:ResetSequence(seq) self.seq=seq end;function d:SetCycle(cycle) self.cycle=cycle end
 function d:SetPoseParameter(name,value) self.poses[name]=value end;function d:InvalidateBoneCache() end
 function d:SetupBones() self.samples=(self.samples or 0)+1 end
 function d:GetBoneMatrix(bone) return matrix(Vector(bone*8*self.scale,0,60*self.scale),Angle(-10,self.ang.y,90)) end
 function d:Remove() self.valid=false;removed=removed+1 end
 return d
end
w={valid=true,ARC9=true,MirrorVMWM=true,TPIKParentToSpine4=true,ActivityTranslate={[1]=400,[2]=401,[3]=402,[4]=403,[5]=404},
 hold='rpg',AttPosCache={},WorldModelOffset={Scale=1},sequence=17,cycle=.65}
function w:GetOwner() return p end;function w:GetHoldType() return self.hold end
function w:SetHoldType(v) self.hold=v end;function w:SetShouldHoldType() self.hold='rpg' end
function w:GetCustomize() return false end;function w:GetFinalAttTable() return {} end
function w:RunHook(name,data) if name=='Hook_GetAttachmentPos' then self.attachmentHooks=(self.attachmentHooks or 0)+1 end end
function w:ShouldTPIK() return not self.disabled and PLUGIN:ARC9_Hook_BlockTPIK(self)~=true end
function w:GetAttachmentPos(slot,wm,idle,nomodeloffset,custompos,customang,duplicate)
 self.lastCall={slot=slot,wm=wm,idle=idle,custompos=custompos,customang=customang,duplicate=duplicate}
 return custompos,customang,'original third return'
end
SWEP=w
player.GetAll=function() return {p} end
