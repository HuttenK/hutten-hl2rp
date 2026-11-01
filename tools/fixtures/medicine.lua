hooks={}; hook.Add=function(event,name,fn) hooks[event]=hooks[event] or {}; hooks[event][name]=fn end
weapons={registered={}}; function weapons.Register(w,id) weapons.registered[id]=w end
ACT_VM_RECOIL1=1; ACT_VM_RECOIL2=2; ACT_VM_RECOIL3=3; ACT_VM_MISSRIGHT=4; ACT_VM_MISSRIGHT2=5; ACT_VM_MISSCENTER2=6
IN_ATTACK=1; IN_ATTACK2=2; IN_RELOAD=4; IN_SPEED=8
MASK_SOLID=1
timers={}; timer.Simple=function(_,fn) timers[#timers+1]=fn end
function flush() local pending=timers; timers={} for _,fn in ipairs(pending) do fn() end end
file={Exists=function() return true end}
net.WriteString=function() end; net.WriteFloat=function() end
net.Start=function() end; net.WriteUInt=function() end; net.Send=function() end
local point={DistToSqr=function() return 0 end}
util.TraceLine=function() return {Hit=false} end
function newHealth()
 local h={hediffs={},body={parts={}},nextID=0}
 for i=1,8 do h.body.parts[i]={id=i,hitgroup=i-1,canFracture=i>=5,movement=i>=7} end
 function h:GetHediffs() return ipairs(self.hediffs) end
 function h:GetParts(hit) return self.body.parts[hit+1] end
 function h:GetPartHealth() return self.partHP or 100 end
 function h:GetMaxHealth() return 100 end
 function h:GetCharacter() return self.character end
 function h:GetPlayer() return self.character.player end
 function h:GetBleedRate() return self.bleed or 0 end
 function h:OnUpdateDiffs() self.updated=true end
 function h:TendHediff(d,time) d.tended_time=time; d.tended_start=os.time() end
 function h:RemoveHediffByID(id) for i,d in ipairs(self.hediffs) do if d.id==id then table.remove(self.hediffs,i) return end end end
 function h:AddHediff(uid,hit,data)
  for _,d in ipairs(self.hediffs) do if uid=='fracture' and d.uniqueID==uid and d.part==hit+1 then return end end
  local d=table.Copy(data or {}); self.nextID=self.nextID+1
  d.id=self.nextID; d.uniqueID=uid; d.part=hit+1; d.severity=d.severity or 0
  d.isFracture=uid=='fracture'; d.isInjury=uid=='fracture' or uid=='cut' or uid=='bruise'
  d.tended_time=d.tended_time or -1; d.bleedRate=uid=='cut' and .06 or 0
  function d:GetSeverity() return self.severity end
  function d:SetSeverity(n) self.severity=n end
  function d:Send() end
  self.hediffs[#self.hediffs+1]=d
  return d
 end
 return h
end
function newMedic()
 local p={valid=true,items={},notices={},weapons={}}
 local c={player=p,hp=newHealth()}; c.hp.character=c; p.character=c
 function c:GetID() return 1 end
 function c:GetSkillModified() return 0 end
 function c:Health() return self.hp end
 function c:DoAction() self.actions=(self.actions or 0)+1 end
 function p:Alive() return not self.dead end
 function p:IsPlayer() return true end
 function p:GetCharacter() return self.character end
 function p:GetItems() return self.items end
 function p:GetNetVar() end
 function p:GetShootPos() return point end
 function p:NearestPoint() return point end
 function p:InCriticalState() return self.critical end
 function p:IsRestricted() return self.restricted end
 function p:KeyDown() return self.cancel end
 function p:Notify(s) self.notices[#self.notices+1]=s end
 function p:SetAction() end
 function p:IsWepRaised() return false end
 function p:EmitSound() end
 function p:GetActiveWeapon() return self.active end
 function p:GetWeapon(id) return self.weapons[id] end
 function p:SelectWeapon(id) self.active=self.weapons[id]; if self.active and self.active.Deploy then self.active:Deploy() end end
 function p:Give(id)
  if self.failGive then return end
  local w=setmetatable({valid=true,class=id},{__index=weapons.registered[id]})
  function w:GetClass() return self.class end
  function w:GetOwner() return p end
  function w:Remove() self.valid=false end
  function w:SendWeaponAnim(act) self.activity=act end
  self.weapons[id]=w
  return w
 end
 function p:GetViewModel()
  return {valid=true,SelectWeightedSequence=function() return self.badSequence and -1 or 1 end,
   SequenceDuration=function() return 1 end,SetSkin=function() end,SetPlaybackRate=function() end}
 end
 return p
end
function medicalItem(p,id,uses)
 local item={player=p,uniqueID=id,id=1,uses=uses or (ix.Medicine.Catalog[id] and ix.Medicine.Catalog[id].capacity) or 2,stats={time=8}}
 function item:GetUses() return self.uses end
 function item:SetData(k,v) if k=='uses' or k=='volume' then self.uses=v end end
 function item:GetName() return self.uniqueID end
 function item:Remove() self.removed=true; for k,v in pairs(p.items) do if v==self then p.items[k]=nil end end end
 p.items[#p.items+1]=item
 return item
end
allPlayers={}; player={GetAll=function() return allPlayers end}
