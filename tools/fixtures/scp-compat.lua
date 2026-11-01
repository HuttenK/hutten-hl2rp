CPTBase={};NULL={valid=false};MOVETYPE_WALK=2;MOVETYPE_OBSERVER=10;MOVETYPE_NOCLIP=8
OBS_MODE_CHASE=5;FL_NOTARGET=128;FSOLID_NOT_SOLID=4;MASK_SHOT=1;D_HT=1;D_FR=2;D_LI=3;D_NU=4
IN_USE=32;IN_ZOOM=524288;IN_JUMP=2;IN_ATTACK=1;IN_ATTACK2=2048;IN_RELOAD=8192
IN_FORWARD=8;IN_BACK=16;IN_MOVELEFT=512;IN_MOVERIGHT=1024;IN_SPEED=131072;IN_DUCK=4;IN_WALK=262144
HUD_PRINTCONSOLE=2
bit={band=function(a,b) return a & b end}
local delayed={};timer.created={}
function timer.Simple(t,fn) delayed[#delayed+1]={t=clock+t,fn=fn} end
function timer.Create(name,t,count,fn) timer.created[name]=fn end
function advance(t)
 clock=clock+t
 local old=delayed;delayed={}
 for _,entry in ipairs(old) do if entry.t<=clock then entry.fn() else delayed[#delayed+1]=entry end end
end
hooks={};function hook.Add(event,id,fn) hooks[event]=hooks[event] or {};hooks[event][id]=fn end
function hook.Run(event,...)
 if veto==event then return false end
 for _,fn in pairs(hooks[event] or {}) do local value=fn(...);if value~=nil then return value end end
end
file={Exists=function() return animationExists~=false end};sent={}
function AddCSLuaFile(name) sent[#sent+1]=name end
ix.util={Include=function() end};ix.SCPCompat={};ix.faction={indices={[1]={npcRelations={npc_combine_s=D_LI}}}}
allEntities={};ents.GetAll=function() return allEntities end
concommand={Add=function() end};errors={};function ErrorNoHalt(e) errors[#errors+1]=e end
function LocalPlayer() return p end
function RealTime() return clock end;function FrameTime() return .016 end
function AngleRand() return Angle() end
function CPT_ParticleEffect(_,pos) particlePos=pos end
function util.TraceLine(data) lastTrace=data;return {HitPos=data.endpos,HitNormal=Vector(),Entity=traceEntity or NULL} end
function util.TraceHull(data) return {HitPos=data.endpos,HitNormal=Vector()} end
net.ReadVector=function() return net.aim end;net.ReadEntity=function() return net.entity end
net.Start=function(name) net.name=name end;net.WriteVector=function(pos) net.sentPosition=pos end
net.WriteEntity=function(ent) net.sentEntity=ent end;net.SendToServer=function() net.sends=(net.sends or 0)+1 end
local PLAYER=FindMetaTable('Player')
function PLAYER:CPT_CreateRagdolledPlayer() self.legacyKnockdown=true end
function newPlayer()
 local q=setmetatable({valid=true,alive=true,character={GetFaction=function() return 1 end},pos=Vector(1,2,3),angles=Angle(10,20,0),
 move=2,vars={},locals={},nw={},weapons={},hp=73,armor=21,model='citizen.mdl',keys={},god=false,noDraw=false,notSolid=false}, {__index=PLAYER})
 function q:IsPlayer() return true end;function q:IsNPC() return false end
 function q:Alive() return self.alive end;function q:GetCharacter() return self.character end
 function q:InVehicle() return self.vehicle end;function q:IsFrozen() return self.frozen end
 function q:IsRestricted() return self.restricted end
 function q:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function q:GetLocalVar(k,d) if self.locals[k]~=nil then return self.locals[k] end return d end
 function q:GetNW2Entity(k) return self.nw[k] or NULL end
 function q:GetNW2Float(k,d) return self.nw[k] or d end
 function q:SetNW2Entity(k,v) self.nw[k]=v end
 q.SetNW2Float=q.SetNW2Entity;q.SetNW2Bool=q.SetNW2Entity;q.SetNW2String=q.SetNW2Entity
 function q:GetPos() return self.pos end;function q:SetPos(v) self.pos=v end
 function q:EyeAngles() return self.angles end;function q:SetEyeAngles(v) self.angles=v end
 function q:GetMoveType() return self.move end;function q:SetMoveType(v) self.move=v end
 function q:GetNoDraw() return self.noDraw end;function q:SetNoDraw(v) self.noDraw=v end
 function q:GetSolidFlags() return (self.solidFlags or 0) | (self.notSolid and FSOLID_NOT_SOLID or 0) end
 function q:SetNotSolid(v) self.notSolid=v end
 function q:HasGodMode() return self.god end;function q:GodEnable() self.god=true end;function q:GodDisable() self.god=false end
 function q:IsFlagSet() return self.noTarget end;function q:AddFlags() self.noTarget=true end;function q:RemoveFlags() self.noTarget=false end
 function q:GetActiveWeapon() return self.active or NULL end;function q:SetActiveWeapon(v) self.active=v end
 function q:SelectWeapon(class) for _,w in ipairs(self.weapons) do if w:GetClass()==class then self.active=w;self.deployed=true end end end
 function q:DrawShadow(v) self.shadow=v end;function q:DrawViewModel(v) self.vm=v end;function q:DrawWorldModel(v) self.wm=v end
 function q:Spectate(v) self.observer=v end;function q:SpectateEntity(v) self.observerTarget=v end
 function q:UnSpectate() self.observer=nil;self.observerTarget=nil end
 function q:GetAimVector() return self.angles:Forward() end;function q:SetLocalVelocity(v) self.velocity=v end
 function q:ChatPrint(v) self.message=v end;function q:KeyDown(k) return self.keys[k]==true end
 function q:StripWeapons() error('must preserve weapon entities') end
 function q:KillSilent() error('must not kill the controller') end;function q:Spawn() error('must not respawn the controller') end
 function q:EmitSound() end;function q:SetDSP(v) self.dsp=v end
 function q:LookupAttachment() return 0 end;function q:GetAttachment() return self.eyes end;function q:EyePos() return self.pos+Vector(0,0,64) end
 function q:SetRagdolled(b,t,grace) self.knockdown={b,t,grace} end
 local w={valid=true,clip=23,itemID=680,attachments={scope=true},GetOwner=function() return q end,GetClass=function() return 'arc9_eft_ak74' end,
  Holster=function(self) self.holstered=true;return true end}
 q.weapons={w};q.active=w
 return q
end
function newNPC(class)
 local n={valid=true,IsCPTBase_NPC=true,class=class or 'npc_cpt_scp_939_a',hp=200,pos=Vector(100,200,300),MemoryTable={},nw={}}
 function n:IsPlayer() return false end;function n:IsNPC() return true end
 function n:GetClass() return self.class end;function n:GetPossessor() return self.controller or NULL end
 function n:SetPossessor(v) self.controller=v end;function n:Health() return self.hp end
 function n:GetPos() return self.pos end;function n:OBBCenter() return Vector(0,0,25) end
 function n:OBBMaxs() return Vector(15,15,50) end;function n:BoundingRadius() return 40 end
 function n:GetUp() return Vector(0,0,1) end;function n:GetForward() return Vector(1,0,0) end
 function n:SetEnemy(v) self.enemy=v end;function n:GetEnemy() return self.enemy end
 function n:StopMoving() end;function n:ClearSchedule() end
 function n:SetPossessorAimPos(v) self.aim=v end;function n:GetPossessorAimPos() return self.aim end
 function n:SetNW2Entity(k,v) self.nw[k]=v end;function n:GetNW2Entity(k) return self.nw[k] or NULL end
 function n:Possess_OnPossessed() self.entered=(self.entered or 0)+1 end
 function n:Possess_OnStopPossessing() self.exited=(self.exited or 0)+1 end
 function n:ControlNPC() error('old kill/spawn controller must not run') end
 function n:ControlMovement() self.moves=(self.moves or 0)+1 end
 function n:GetRelationship(target) return self.MemoryTable[D_LI][target] and D_LI or D_HT end
 function n:Possess_AimTarget() return self.enemy end
 function n:Possess_EyeTrace() error('nil legacy camera aim') end
 function n:EmitSound() end;function n:SelectFromTable(t) return t[1] end
 n.tbl_Sounds={Crunch={'crunch'},Strike={'strike'}}
 return n
end
p=newPlayer();npc=newNPC();allPlayers={p};allEntities={npc};oldWeapon=p.active
