local P,F=PLUGIN,ix.Facility
util.AddNetworkString("ixFacilityRepairState")
util.AddNetworkString("ixFacilityRepairInput")
function P:SendRepair(p,w,result,message)
 if not IsValid(p) or not w or not w.repair then return end
 local r=w.repair;local j=self.store.jobs[w.job]
 local data={token=r.token,round=r.round,stage=r.stage,started=r.started,target=r.target,period=r.period,width=r.width,
  expires=r.expires,entity=IsValid(w.entity) and w.entity:EntIndex() or 0,title=w.title or (j and j.title) or "Ремонт оборудования",
  sabotage=w.sabotage==true,noParts=w.fusebox==true,result=result,message=message}
 if r.engineering then data.engineering=true;data.kind=r.kind;data.state=self:EngineeringPublic(r) end
 local raw=util.TableToJSON(data);if not raw or #raw>4096 then return end
 net.Start("ixFacilityRepairState");net.WriteString(raw);net.Send(p)
end
function P:StartRepair(p,w)
 local kind=self.EngineeringKind and self:EngineeringKind(w)
 if kind then return self:StartEngineering(p,w,kind) end
 self.repairSerial=(self.repairSerial or 0)%4294967294+1
 local stage=F.RepairStage(1)
 w.repair={token=self.repairSerial,round=1,stage=1,started=CurTime()+.7,target=math.random(35,80)/100,
  period=stage.period,width=stage.width,expires=CurTime()+F.repair.timeout}
 self:SendRepair(p,w,"start",w.sabotage and "Разомкните пять контактов. Каждый этап быстрее и сложнее." or "Замкните пять контактов. Каждый этап быстрее и сложнее.")
end
function P:FuseboxWorkValid(p,w)
 local b=ix.plugin.list.blackout;local box=w.entity
 if w.job then
  local j=self.store.jobs[w.job]
  if not j or j.status~="assigned" or j.owner~=w.character or not self:JobAllowed(p,j) then return false end
 end
 return b and F.Near(p,box,150) and p:GetCharacter():GetID()==w.character
  and box:GetClass()=="ix_blackout_fusebox" and box.ixRepairing==p
  and box:GetDoorOpen() and box:DoorPitch()<=-139 and box:GetBroken()==not w.sabotage
  and b:HasScrewdriver(p) and p:GetCharacter():GetSkillModified("electric")>=(w.sabotage and b.breakSkill or b.repairSkill)
end
function P:BeginFuseboxWork(p,box,sabotage)
 local b=ix.plugin.list.blackout
 if not b or not F.Near(p,box,150) or box:GetClass()~="ix_blackout_fusebox" then return false,"Подойдите к электрощиту." end
 if self.work[p] or box.ixRepairing then return false,"Работа уже выполняется." end
 if box:InteractionTarget(p)~="panel" then return false,"Откройте дверцу и наведите на панель внутри щитка." end
 local w={fusebox=true,sabotage=sabotage==true,entity=box,character=p:GetCharacter():GetID(),
  title=sabotage and "Саботаж электрощита" or "Ремонт электрощита"}
 box.ixRepairing=p
 if not self:FuseboxWorkValid(p,w) then box.ixRepairing=nil;return false,"Необходимы отвёртка, навык и открытый электрощит." end
 self.work[p]=w;box:StartSparks(F.repair.timeout)
 self:StartRepair(p,w)
 return true
end
function P:ReleaseFusebox(p,w)
 if w.fusebox and IsValid(w.entity) and w.entity.ixRepairing==p then
  w.entity.ixRepairing=nil;w.entity:StopSparks()
 end
end
function P:CompleteFuseboxWork(p,w)
 -- CompleteWork has already revalidated the session and all five contacts.
 self:ReleaseFusebox(p,w)
 local b=ix.plugin.list.blackout
 if w.sabotage then b:ApplyBreak(p,w.entity,b.breakXP) else b:ApplyRepair(p,w.entity) end
 if not w.sabotage then for _,j in pairs(self.store.jobs) do
  if j.targetKind=="fusebox" and j.target==w.entity:EntIndex() and j.status~="closed" then
   j.status="closed";j.closed=os.time();self.dirty=true
  end
 end end
 self:Audit(p,w.title,w.entity:EntIndex())
 self:SendRepair(p,w,"complete",w.sabotage and "Пять контактов разомкнуты. Электрощит выведен из строя." or "Все контакты восстановлены. Электрощит починен.")
 return true
end
function P:CancelWork(p,message,release)
 local w=self.work[p];if not w then return end
 self.work[p]=nil
 self:ReleaseFusebox(p,w)
 if w.fusebox then message="Работа с электрощитом отменена. Инструмент сохранён." end
 local j=self.store.jobs[w.job]
 if release and j and j.status=="assigned" and j.owner==w.character then
  j.owner=nil;j.ownerName=nil;j.status="open";self.dirty=true
 end
 if w.repair then self:SendRepair(p,w,"cancel",message or "Ремонт отменён. Запчасти сохранены.") end
 if IsValid(p) then
  if not w.repair then p:SetAction() end
  if message then p:Notify(message) end
 end
end
function P:RepairInput(p,token,round,attempt)
 local w=self.work[p];local r=w and w.repair
 if not r or r.engineering or token~=r.token then return end
 if not attempt then self:CancelWork(p,"Ремонт отменён. Запчасти сохранены.",true);return end
 if round~=r.round then return end
 if not self:WorkValid(p,w) then self:CancelWork(p,"Ремонт прерван: оборудование, инструменты или допуск недоступны.",true);return end
 local now=CurTime()
 if now>=r.expires then self:CancelWork(p,"Время ремонта истекло. Можно начать снова; запчасти сохранены.",true);return end
 if now<(r.nextInput or 0) then return end
 r.nextInput=now+.25
 -- The client submits a press, never a cursor position or a completion result.
 -- Bound latency compensation to keep normal internet delay from punishing timing.
 local latency=math.Clamp((p.Ping and p:Ping() or 0)/2000,0,.18)
 local at=now-latency
 local hit=at>=r.started and math.abs(F.RepairPosition(at,r.started,r.period)-r.target)<=r.width*.5+.015
 if hit then r.stage=r.stage+1 end
 r.round=r.round+1
 if r.stage>F.repair.contacts then return self:CompleteWork(p,w) end
 r.started=now+.7
 if hit then
  r.target=math.random(35,80)/100
  local stage=F.RepairStage(r.stage);r.period=stage.period;r.width=stage.width
 end
 self:SendRepair(p,w,hit and "hit" or "miss",hit and (w.sabotage and "Контакт разомкнут. Следующий контакт." or "Контакт восстановлен. Следующий контакт.") or "Мимо зоны. Этот контакт можно попробовать снова.")
end
net.Receive("ixFacilityRepairInput",function(length,p)
 if length>64 then return end
 P:RepairInput(p,net.ReadUInt(32),net.ReadUInt(16),net.ReadBool())
end)
