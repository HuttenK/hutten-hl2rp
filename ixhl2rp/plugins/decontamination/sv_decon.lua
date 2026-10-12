local P,D=PLUGIN,ix.Decon
P.actions={};P.occupants={};P.remains=setmetatable({}, {__mode="k"})
function P:OtherActivity(p)
 local facility=ix.plugin.list.facility_utilities
 return IsValid(p) and (p.ixMedicalSession~=nil or (facility and facility.work and facility.work[p]~=nil))
end
function P:FacilityRecord(e)
 local facility=ix.plugin.list.facility_utilities
 local record=facility and IsValid(e) and facility.store.devices[e.facilityID]
 if record and record.entity==e and D.kinds[record.kind] then return facility,record end
end
function P:Ready(p,e)
 local facility,d=self:FacilityRecord(e)
 if not d or not ix.Facility.Near(p,e,110) or self:OtherActivity(p) or not ix.Facility.Access(p,d.level or 0,d.department)
  or p:GetNetVar("forcedSequence") or p:GetNW2Bool("ixPoseStudioPlaying",false) then return false end
 return facility:DevicePowered(d),d
end
function P:InGas(p)
 local controller=ix.plugin.list.scp610_control
 if controller and controller.settings.zoneGas==false then return false end
 for _,area in pairs(ix.area and ix.area.stored or {}) do
  if area.type=="infection" and D.ZoneDistance(p:WorldSpaceCenter(),area)==0 then return true end
 end
 return false
end
function P:PlayerRemains(e)
 return e.ixPlayerCorpse or e.ixPersistentCorpse or e.ixPlayer or e.ixCorpse or e.ixInventoryID or e.inventoryID or e.inventory
  or e.characterID or e.ixCharID or (IsValid(e:GetOwner()) and e:GetOwner():IsPlayer())
end
function P:IsRemains(e)
 return IsValid(e) and e:GetClass()=="prop_ragdoll" and self.remains[e]==true and not self:PlayerRemains(e)
end
function P:MarkRemains(source,corpse)
 if not IsValid(source) or not source:IsNPC() or not IsValid(corpse) or corpse:GetClass()~="prop_ragdoll" or self:PlayerRemains(corpse) then return end
 local c=ix.plugin.list.scp610_control
 if not (source.ixInfectionZone or c and c:Is610(source)) then return end
 self.remains[corpse]=true
 corpse:SetNW2Bool("ixDeconRemains",true)
end
function P:SCP610CorpseCreated(source,corpse) self:MarkRemains(source,corpse) end
function P:CreateEntityRagdoll(source,corpse) self:MarkRemains(source,corpse) end
function P:OnPlayerCorpseCreated(_,corpse)
 self.remains[corpse]=nil;corpse.ixPlayerCorpse=true;corpse:SetNW2Bool("ixDeconRemains",false)
end
function P:NearbyRemains(e)
 local found,distance
 for _,corpse in ipairs(ents.FindInSphere(e:WorldSpaceCenter(),100)) do
  if self:IsRemains(corpse) then
   local n=corpse:WorldSpaceCenter():DistToSqr(e:WorldSpaceCenter())
   if (not distance or n<distance) and not util.TraceLine({start=e:WorldSpaceCenter(),endpos=corpse:WorldSpaceCenter(),filter={e,corpse},mask=MASK_VISIBLE}).Hit then found=corpse;distance=n end
  end
 end
 return found
end
function P:Cancel(p,quiet)
 local a=self.actions[p];self.actions[p]=nil
 if not a then return end
 if self.occupants[a.entity]==p then self.occupants[a.entity]=nil end
 if IsValid(a.entity) then
  a.entity:SetNW2Entity("ixDeconUser",NULL);a.entity:SetNW2String("ixDeconStatus","ГОТОВО — E")
  a.entity:StopSound("ambient/water/water_spray1.wav")
 end
 hook.Run("DeconActionEnded",p,a.kind)
 if IsValid(p) and not quiet and not self:OtherActivity(p) then p:SetAction() end
end
function P:Use(p,e)
 local f,d=self:FacilityRecord(e);if not d or not ix.Facility.Near(p,e,110) then return end
 if p:IsAdmin() and p:KeyDown(IN_WALK) or d.fault then f:UseDevice(p,e);return end
 if CurTime()<(p.ixDeconUseAt or 0) then return end;p.ixDeconUseAt=CurTime()+.5
 local ready=self:Ready(p,e)
 if not ready then p:Notify("Нет питания, допуска или действие сейчас недоступно.");return end
 if d.kind=="decon_sensor" then
  self:Scan(d);p:Notify(e:GetNW2String("ixDeconStatus","Сканирование..."));return
 end
 if self.actions[p] then self:Cancel(p);p:Notify("Цикл остановлен.");return end
 if IsValid(self.occupants[e]) then p:Notify("Устройство занято.");return end
 local kind=d.kind=="decon_shower" and "shower" or "disposal"
 if kind=="shower" and self:InGas(p) then p:Notify("Сначала покиньте зону токсичного газа: душ не защищает от повторного воздействия.");return end
 local corpse
 if kind=="disposal" then
  corpse=self:NearbyRemains(e)
  if not corpse then p:Notify("Положите рядом останки уничтоженного SCP-610 или заражённого NPC (до 100 ед.).");return end
 end
 p:SetAction(kind=="shower" and "Деконтаминация — оставайтесь рядом..." or "Термическая утилизация останков...",8)
 self.actions[p]={kind=kind,entity=e,character=p:GetCharacter(),corpse=corpse,finish=CurTime()+8,pos=p:GetPos(),devicePos=e:GetPos()}
 self.occupants[e]=p;e:SetNW2Entity("ixDeconUser",p)
 e:SetNW2String("ixDeconStatus",kind=="shower" and "ИДЁТ ПРОМЫВКА — 8 с" or "УТИЛИЗАЦИЯ — 8 с")
 e:EmitSound(kind=="shower" and "ambient/water/water_spray1.wav" or "ambient/machines/steam_release_2.wav",60,100,.5)
 ix.chat.Send(p,"me",kind=="shower" and "включает душ деконтаминации и начинает промывку." or "помещает заражённые останки в цикл термической утилизации.")
 hook.Run("DeconActionStarted",p,kind,e,8)
end
function P:ValidAction(p,a)
 if not IsValid(p) or p:GetCharacter()~=a.character or not self:Ready(p,a.entity)
  or p:GetPos():DistToSqr(a.pos)>24^2 or a.entity:GetPos():DistToSqr(a.devicePos)>4 then return false end
 if a.kind=="shower" then return not self:InGas(p) end
 return self:IsRemains(a.corpse) and a.corpse:WorldSpaceCenter():DistToSqr(a.entity:WorldSpaceCenter())<=100^2
  and not util.TraceLine({start=a.entity:WorldSpaceCenter(),endpos=a.corpse:WorldSpaceCenter(),filter={a.entity,a.corpse},mask=MASK_VISIBLE}).Hit
end
function P:Finish(p,a)
 if not self:ValidAction(p,a) then return false end
 if a.kind=="shower" then
  p.ixToxic=0;p.ixToxicMsg=nil;p:SetNWFloat("ixToxicLevel",0);p:SetNWBool("ixToxicChoke",false)
  p:Notify("Промывка завершена. Токсическое воздействие снято; защита от нового заражения не предоставляется.")
 else
  local c=ix.plugin.list.scp610_control
  if c and c.pending then c.pending[a.corpse]=nil end
  self.remains[a.corpse]=nil;a.corpse:Remove()
  p:Notify("Заражённые останки обезврежены и утилизированы.")
 end
 return true
end
function P:Scan(d)
 local e=d.entity;local f=ix.plugin.list.facility_utilities
 if not IsValid(e) then return end
 if not f:DevicePowered(d) then e:SetNW2Bool("ixDeconAlarm",false);e:SetNW2String("ixDeconStatus","НЕТ ПИТАНИЯ / ДАННЫХ");return end
 local radius=math.Clamp(tonumber(d.radius) or 300,100,600)
 local counts={npcs=0,flora=0,remains=0,zones=0,toxic=0};local c=ix.plugin.list.scp610_control
 for _,other in ipairs(ents.FindInSphere(e:WorldSpaceCenter(),radius)) do
  if self:IsRemains(other) then counts.remains=counts.remains+1
  elseif other.ixInfectionFlora then counts.flora=counts.flora+1
  elseif other:IsNPC() and other:Health()>0 and not other.Dead and (other.ixInfectionZone or c and c:Is610(other)) then counts.npcs=counts.npcs+1
  elseif other:IsPlayer() and other:Alive() and (other.ixToxic or 0)>0 then counts.toxic=counts.toxic+1 end
 end
 for _,area in pairs(ix.area and ix.area.stored or {}) do
  if area.type=="infection" and D.ZoneDistance(e:WorldSpaceCenter(),area)<=radius^2 then counts.zones=counts.zones+1 end
 end
 local alarm=counts.npcs+counts.flora+counts.remains+counts.zones+counts.toxic>0
 e:SetNW2Bool("ixDeconAlarm",alarm)
 e:SetNW2String("ixDeconStatus",alarm and ("ЗОНЫ "..counts.zones.." / SCP "..counts.npcs.." / ФЛОРА "..counts.flora.." / ОСТАНКИ "..counts.remains.." / ТОКСИНЫ "..counts.toxic) or "УГРОЗ НЕ ОБНАРУЖЕНО · "..radius.." ед.")
 if alarm and not e.ixDeconWasAlarm then e:EmitSound("buttons/blip2.wav",55,90,.4) end
 e.ixDeconWasAlarm=alarm
 return counts
end
function P:Think()
 if CurTime()<(self.nextTick or 0) then return end;self.nextTick=CurTime()+.2
 for p,a in pairs(self.actions) do
  if not self:ValidAction(p,a) then self:Cancel(p);if IsValid(p) then p:Notify("Цикл прерван: отойдите от угрозы и проверьте питание.") end
  elseif CurTime()>=a.finish then self:Finish(p,a);self:Cancel(p) end
 end
 if CurTime()<(self.nextScan or 0) then return end;self.nextScan=CurTime()+2
 local f=ix.plugin.list.facility_utilities
 for _,d in pairs(f and f.store.devices or {}) do if d.kind=="decon_sensor" then self:Scan(d) end end
end
function P:PlayerActionChanged(p) self:Cancel(p,true) end
function P:EntityTakeDamage(p,dmg) if dmg:GetDamage()>0 and self.actions[p] then self:Cancel(p) end end
function P:PlayerDeath(p) self:Cancel(p) end
function P:PlayerDisconnected(p) self:Cancel(p,true) end
function P:PlayerLoadedCharacter(p) self:Cancel(p) end
function P:OnUnload() for p in pairs(self.actions) do self:Cancel(p) end end
