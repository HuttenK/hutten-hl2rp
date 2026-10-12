local P,F=PLUGIN,ix.Facility
util.AddNetworkString("ixFacilityEngineeringInput")
function P:EngineeringKind(w)
 if w.sabotage then return end -- retain the existing five increasingly fast sabotage contacts
 local mode=ix.config.Get("facilityRepairGame","auto")
 if mode=="contacts" then return end
 if F.engineeringNames[mode] then return mode end
 if w.fusebox then return "probe" end
 local job=self.store.jobs[w.job];local d=job and job.targetKind=="device" and self.store.devices[job.target]
 return d and d.kind=="generator" and "pressure" or job and job.targetKind=="cctv" and "bolts" or "probe"
end
function P:NewEngineeringStage(p,w)
 local r=w.repair
 r.game=F.EngineeringStage(r.kind,r.stage,p:GetCharacter():GetSkillModified("electric"))
 if not r.game then self:CancelWork(p,"Не удалось подготовить ремонт. Попробуйте снова.",true);return false end
 r.started=CurTime();r.expires=math.min(CurTime()+120,r.deadline);r.hold=nil;r.holdBolt=nil
 r.torqueTime=math.max(.8,1.8-r.stage*.16)
 if r.kind=="bolts" then
  local e=w.entity;local tr=p:GetEyeTrace();local normal=(p:GetShootPos()-e:WorldSpaceCenter()):GetNormalized()
  local point=e:NearestPoint(p:GetShootPos())
  if tr.Entity==e then point=tr.HitPos;normal=tr.HitNormal end
  local pos=e:WorldToLocal(point+normal*.8);local ang=e:WorldToLocalAngles(normal:Angle())
  local low,high=e:GetModelBounds();local extent=high-low
  r.anchor={pos={pos.x,pos.y,pos.z},ang={ang.p,ang.y,ang.r},radius=math.Clamp(math.min(extent.x,extent.y,extent.z)*.3,2,7)}
 end
 return true
end
function P:StartEngineering(p,w,kind)
 self.repairSerial=(self.repairSerial or 0)%4294967294+1
 w.repair={token=self.repairSerial,round=1,stage=1,kind=kind,engineering=true,deadline=CurTime()+600}
 if self:NewEngineeringStage(p,w) then self:SendRepair(p,w,"start","Этап 1 / 5. Следуйте инструкции на экране.") end
end
function P:EngineeringPublic(r)
 local state=ix.repair.PublicState(r.game)
 state.anchor=r.anchor;state.torqueTime=r.torqueTime
 return state
end
function P:EngineeringBoltVisible(p,w,index)
 local r=w.repair;local points=F.EngineeringBolts(w.entity,{count=r.game.count,anchor=r.anchor})
 local point=points[index];if not point then return false end
 local start=p:GetShootPos();local aim=p:GetAimVector();local best,dot
 for i,v in ipairs(points) do
  local d=(v-start):GetNormalized():Dot(aim)
  if not dot or d>dot then best,dot=i,d end
 end
 if best~=index or dot<.995 or start:DistToSqr(point)>150^2 then return false end
 local filter={p,w.entity};local parent=w.entity:GetParent();if IsValid(parent) then filter[#filter+1]=parent end
 return not util.TraceLine({start=start,endpos=point,filter=filter,mask=MASK_SOLID}).Hit
end
function P:EngineeringInput(p,token,round,kind,a,b)
 local w=self.work[p];local r=w and w.repair
 if not r or not r.engineering or token~=r.token then return end
 if kind=="cancel" then self:CancelWork(p,"Ремонт отменён. Предметы сохранены.",true);return end
 if round~=r.round then return end
 if not self:WorkValid(p,w) or CurTime()>=r.expires then self:CancelWork(p,"Ремонт прерван. Инструменты и запчасти сохранены.",true);return end
 local now=CurTime();if now<(r.nextInput or 0) then return end;r.nextInput=now+.10
 local move={kind=kind,a=a,b=b,segment=a,valve=a,delta=b}
 if r.kind=="bolts" then
  local point=F.EngineeringBolts(w.entity,{count=r.game.count,anchor=r.anchor})[a]
  if not point then return end
  if not self:EngineeringBoltVisible(p,w,a) then
   if r.hold then r.hold=nil;r.holdBolt=nil;r.round=r.round+1;self:SendRepair(p,w,"move","Смотрите на выбранный болт во время затяжки.") end
   return
  end
  if kind=="hold" then
   if r.hold or r.game.tight[a] then return end
   r.hold=now;r.holdBolt=a;return
  elseif kind=="release" and r.hold and r.holdBolt==a then
   move={kind="tighten",bolt=a,torque=math.Clamp((now-r.hold)/r.torqueTime,0,1.5)}
   r.hold=nil;r.holdBolt=nil
  else return end
 elseif r.kind=="pressure" and kind~="run" then return
 elseif r.kind=="probe" and kind~="probe" and kind~="answer" then return end
 local result=ix.repair.PlayMove(r.game,move)
 if not result.ok then return end
 r.round=r.round+1
 if result.finished then
  if result.win then r.stage=r.stage+1 end
  if r.stage>F.repair.contacts then return self:CompleteWork(p,w) end
  if not self:NewEngineeringStage(p,w) then return end
  self:SendRepair(p,w,result.win and "hit" or "miss",result.win and "Этап пройден. Следующая задача сложнее." or "Попробуйте текущий этап снова. Запчасти сохранены.")
 else self:SendRepair(p,w,"move",result.verdict) end
end
net.Receive("ixFacilityEngineeringInput",function(length,p)
 if length>400 then return end
 P:EngineeringInput(p,net.ReadUInt(32),net.ReadUInt(16),net.ReadString(),net.ReadInt(16),net.ReadInt(16))
end)
