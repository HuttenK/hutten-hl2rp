-- Engine boundary only; tests load the actual HealthStat, Hediff classes and
-- treatment/session code. No invented player API is used by the production path.
function table.Copy(t, seen)
 if type(t)~='table' then return t end
 seen=seen or {}; if seen[t] then return seen[t] end
 local r={}; seen[t]=r
 for k,v in pairs(t) do r[k]=table.Copy(v,seen) end
 return setmetatable(r,getmetatable(t))
end
function table.Merge(t,src) for k,v in pairs(src) do t[k]=v end return t end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
function Material(s) return s end
function ErrorNoHalt(s) error(s) end
function math.Remap(x,a,b,c,d) return c+(x-a)/(b-a)*(d-c) end
function math.Rand(a,b) return (a+b)/2 end
function Sound(s) return s end
HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3;HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
DMG_SLASH=4;DMG_BURN=8;DMG_POISON=16;DMG_SLOWBURN=32;DMG_POI=12;MASK_SHOT=1
vector_origin=Vector();NULL={valid=false};ix.char={loaded={},HookVar=function() end}
getmetatable(vector_origin).DistToSqr=function(a,b) return (a-b):LengthSqr() end
ix.Item={stored={},instances={}}
ix.util={Lib=function(name,value) ix[name]=value; return value end,Include=function() end}
net.ChooseOptimalBits=function() return 8 end
net.WriteBool=function() end
util.JSONToTable=function() return {} end
concommand={Add=function() end}
ix.log.AddType=function() end
function EffectData() return {SetOrigin=function() end,SetEntity=function() end} end
util.Effect=function() end
function hook.Run(event,...)
 for _,fn in pairs(hooks[event] or {}) do local r=fn(...); if r~=nil then return r end end
end
function newPatient()
 local p=newMedic()
 local c=p.character;c.data={};c.id=(nextPatientID or 0)+1;nextPatientID=c.id
 function c:GetID() return self.id end
 function c:GetPlayer() return self.player end
 function c:GetData(k,d) local v=self.data[k]; if v==nil then return d end return v end
 function c:SetData(k,v) self.data[k]=v end
 function c:HasSpecialLevel() return false end
 ix.char.loaded[c.id]=c
 c.hp=ix.meta.HealthStat:New(c,'health');c.hp.client=p
 p.vars={};p.pos=Vector();p.char_outfit={armor={}}
 function p:GetPos() return self.pos end
 function p:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:SetNetVar(k,v) self.vars[k]=v end
 function p:GetLocalVar(k,d) return self:GetNetVar(k,d) end
 function p:SetLocalVar(k,v) self.vars[k]=v end
 function p:ChatPrint(message) self.chat=self.chat or {};self.chat[#self.chat+1]=message end
 function p:SetHealth(value) self.engineHealth=value end
 function p:InVehicle() return self.vehicle end
 function p:ExitVehicle() self.vehicle=false end
 function p:GetClass() return 'player' end
 function p:IsNPC() return false end
 function p:HasGodMode() return self.god or false end
 function p:SetCriticalState(v) self.critical=v; self.vars.crit=v end
 function p:SetRagdolled(v)
  self.ragdolled=v
  if v then self.ixRagdoll=self.ixRagdoll or {valid=true,ixGrace=clock+5}
  else self.ixRagdoll=nil end
 end
 function p:SteamID() return tostring(c.id) end
 function p:Kill() error('SCP medical damage must never execute a patient') end
 return p
end
function scpNPC(name)
 local n={valid=true,class=name,IsCPTBase_NPC=true}
 function n:GetClass() return self.class end
 function n:IsPlayer() return false end
 function n:IsNPC() return true end
 function n:GetPos() return Vector() end
 function n:OBBCenter() return Vector(0,0,45) end
 function n:GetPossessor() return self.possessor or NULL end
 function n:GetPossessorAimPos() return Vector(100,0,30) end
 return n
end
function scpDamage(n,amount,inflictor)
 local d={amount=amount or 40,attacker=n,inflictor=inflictor or n,force=Vector(1,2,3)}
 function d:GetDamage() return self.amount end
 function d:SetDamage(v) self.amount=v end
 function d:GetAttacker() return self.attacker end
 function d:GetInflictor() return self.inflictor end
 function d:GetDamagePosition() return Vector() end
 function d:SetDamageForce(v) self.force=v end
 return d
end
function findCondition(h,id)
 for _,d in h:GetHediffs() do if d.uniqueID==id then return d end end
end
function wound(h,hit,info)
 local id=({slash='cut',club='blunt',acid='acid',burn='scp_burn'})[info.class]
 assert(id,info.class);h:AddHediff(id,hit,{severity=info.amount})
end
function attack(p,class,amount,hit,apply)
 local npc=scpNPC(class);npc.IsPossessed=true
 util.TraceLine=function() return {Entity=p,HitGroup=hit or 2} end
 local damage=scpDamage(npc,amount)
 assert(ix.SCPMedicine.Damage(p,damage,apply or wound));eq(damage.amount,0)
 return damage
end
ix.SCPCompat={Controlled=function(p) return p.controller end}
ix.Amputation={byHitgroup={[4]='larm',[5]='rarm',[6]='lleg',[7]='rleg'}}
function ix.Amputation.GetLimb() end
function ix.Amputation.Amputate(p,key)
 if p.character.data.amputation then return false end
 p.character.data.amputation=key; return true
end
