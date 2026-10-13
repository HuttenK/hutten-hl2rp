local P,F=PLUGIN,ix.Facility
function P:JobTarget(j)
 if j.targetKind=="device" then local d=self.store.devices[j.target];return d and d.entity
 elseif j.targetKind=="cctv" then local c=ix.plugin.list.cctv;local d=c and c.devices[j.target];return d and d.entity
 elseif j.targetKind=="fusebox" then return Entity(j.target) end
end
function P:JobAllowed(p,j) return F.Access(p,j.level or 0,j.department) end
function P:NewJob(kind,target,title,level,department)
 for _,j in pairs(self.store.jobs) do if j.status~="closed" and j.targetKind==kind and j.target==target then return j end end
 if table.Count(self.store.jobs)>=100 then
  local oldest;for _,j in pairs(self.store.jobs) do if j.status=="closed" and (not oldest or j.id<oldest) then oldest=j.id end end
  if not oldest then return end;self.store.jobs[oldest]=nil
 end
 local j={id=self:NewID(),title=title,targetKind=kind,target=target,level=level or 0,department=department or "",status="open",created=os.time()}
 self.store.jobs[j.id]=j;self.dirty=true;return j
end
function P:JobRows(p)
 local rows={};local cid=p:GetCharacter():GetID()
 for _,j in SortedPairs(self.store.jobs) do if j.status~="closed" and self:JobAllowed(p,j) then
  local ent=self:JobTarget(j);local pos=IsValid(ent) and ent:GetPos()
  rows[#rows+1]={id=j.id,title=j.title,status=j.status,ownerName=j.ownerName,mine=j.owner==cid,
   position=pos and {x=pos.x,y=pos.y,z=pos.z},available=IsValid(ent),targetKind=j.targetKind}
 end end
 return rows
end
function P:JobAction(p,data)
 if not F.Active(p) then return false,"Персонаж недоступен." end
 local j=self.store.jobs[data.id];local cid=p:GetCharacter():GetID()
 if not j or j.status=="closed" or not self:JobAllowed(p,j) then return false,"Заявка недоступна." end
 if data.command=="claim" then
  if j.owner and j.owner~=cid then return false,"Заявка уже принята." end
  j.owner=cid;j.ownerName=p:Name();j.status="assigned";self.dirty=true
  return true,"Заявка принята. Устройства: подойдите и нажмите E. Камеры: подойдите и используйте /MaintenanceWork."
 elseif data.command=="release" then
  if j.owner~=cid and not p:IsAdmin() then return false,"Это чужая заявка." end
  j.owner=nil;j.ownerName=nil;j.status="open";self.dirty=true;return true,"Назначение освобождено."
 elseif data.command=="work" then return self:BeginWork(p,j) end
 return false,"Неизвестное действие."
end
local function item(p,id)
 if not p:GetCharacter() or not p.inventories then return end
 local found,instance=p:HasItem(id);return found and instance or nil
end
local function screwdriver(p) return item(p,"tool_screw") end
function P:BeginWork(p,j)
 if not F.Active(p) or not j or j.status~="assigned" or not self:JobAllowed(p,j) then return false,"Заявка недоступна." end
 if j.owner~=p:GetCharacter():GetID() then return false,"Сначала примите заявку." end
 local e=self:JobTarget(j);if not F.Near(p,e,110) then return false,"Подойдите к указанному оборудованию." end
 if self.work[p] then return false,"Работа уже выполняется." end
 if j.targetKind=="fusebox" then
  local b=ix.plugin.list.blackout
  if b and e:GetClass()=="ix_blackout_fusebox" then
   local ok=b:TryRepair(p,e)
   if ok and self.work[p] then self.work[p].job=j.id end
   return ok==true,ok and "Восстановите пять контактов в окне ремонта." or "Ремонт не начат. Проверьте инструменты, навык и открытую дверцу."
  end
 end
 local d=j.targetKind=="device" and self.store.devices[j.target]
 local cleaning=d and d.kind=="workpoint"
 if not cleaning and (not screwdriver(p) or not item(p,"facility_spares")) then return false,"Нужны отвёртка и комплект запчастей." end
 for _,w in pairs(self.work) do if w.entity==e then return false,"Оборудование уже обслуживают." end end
 local w={job=j.id,entity=e,character=p:GetCharacter():GetID(),cleaning=cleaning}
 self.work[p]=w
 if cleaning then
  w.untilTime=CurTime()+15;p:SetAction("Обслуживание участка…",15)
  return true,"Работа начата. Оставайтесь рядом и смотрите на оборудование."
 end
 self:StartRepair(p,w)
 return true,"Восстановите пять контактов в окне ремонта. Оставайтесь рядом с оборудованием."
end
function P:WorkValid(p,w)
 if w.fusebox then return self:FuseboxWorkValid(p,w) end
 local j=self.store.jobs[w.job]
 if not F.Near(p,w.entity,110) or p:GetCharacter():GetID()~=w.character or not j or j.owner~=w.character
  or j.status~="assigned" or not self:JobAllowed(p,j) or self:JobTarget(j)~=w.entity then return false end
 if j.targetKind=="device" and not self.store.devices[j.target].fault then return false end
 if j.targetKind=="cctv" then
  local c=ix.plugin.list.cctv;local d=c and c.devices[j.target]
  if not d or d.on~=false then return false end
 end
 if w.cleaning then
  local tr=p:GetEyeTrace();local parent=w.entity:GetParent()
  return tr.Entity==w.entity or (IsValid(parent) and tr.Entity==parent)
 end
 -- A popup owns the cursor during calibration; proximity and LOS still apply.
 return screwdriver(p)~=nil and item(p,"facility_spares")~=nil
end
function P:CompleteWork(p,w)
 if self.work[p]~=w or not self:WorkValid(p,w) then return false end
 if w.repair then if w.repair.stage<=F.repair.contacts then return false end
 elseif not w.cleaning or CurTime()<w.untilTime then return false end
 local j=self.store.jobs[w.job]
 -- Reserve completion before consuming/mutating: replayed presses cannot spend twice.
 self.work[p]=nil
 if w.fusebox then return self:CompleteFuseboxWork(p,w) end
 if not w.cleaning then item(p,"facility_spares"):Remove(true) end
 if j.targetKind=="device" then local d=self.store.devices[j.target];d.fault=false;self:SyncDevice(d)
 elseif j.targetKind=="cctv" then
  local c=ix.plugin.list.cctv;local d=c.devices[j.target];d.on=j.previousOn~=false;c:SendDevice(d);c:SaveData()
 end
 j.status="closed";j.closed=os.time();self.dirty=true;self:Audit(p,"Завершение работ",j.title)
 if w.repair then self:SendRepair(p,w,"complete","Все контакты восстановлены. Ремонт завершён.") else p:SetAction() end
 p:Notify("Заявка выполнена: "..j.title)
 return true
end
function P:TickJobs()
 for p,w in pairs(self.work) do
  if not self:WorkValid(p,w) then self:CancelWork(p,"Работа прервана. Запчасти сохранены.",w.repair~=nil)
  elseif w.repair and CurTime()>=w.repair.expires then self:CancelWork(p,"Время ремонта истекло. Запчасти сохранены.",true)
  elseif w.repair and w.repair.engineering and w.repair.hold and not self:EngineeringBoltVisible(p,w,w.repair.holdBolt) then
   w.repair.hold=nil;w.repair.holdBolt=nil;w.repair.round=w.repair.round+1;self:SendRepair(p,w,"move","Смотрите на выбранный болт во время затяжки.")
  elseif w.cleaning and CurTime()>=w.untilTime then self:CompleteWork(p,w) end
 end
 -- Fusebox repairs remain owned by the original skill/tool system.
 for _,j in pairs(self.store.jobs) do if j.status~="closed" then
  local e=self:JobTarget(j)
  if (j.targetKind=="device" and not self.store.devices[j.target]) or (j.targetKind=="cctv" and not IsValid(e) and CurTime()>(self.bindUntil or 0)) then j.status="closed";self.dirty=true end
  if j.targetKind=="fusebox" and (not IsValid(e) or e:GetClass()~="ix_blackout_fusebox" or not e:GetBroken()) then j.status="closed";self.dirty=true end
 end end
end
function P:DiscoverJobs()
 local b=ix.plugin.list.blackout
 for _,e in ipairs(b and b.fuseboxes or {}) do if IsValid(e) and e:GetBroken() then self:NewJob("fusebox",e:EntIndex(),"Ремонт электрощита #"..e:EntIndex(),1) end end
 for _,d in pairs(self.store.devices) do if d.fault then self:NewJob("device",d.id,(d.kind=="workpoint" and "Обслуживание: " or "Ремонт: ")..d.name,d.kind=="workpoint" and (d.level or 0) or 1,d.department) end end
end
function P:Refuel(p,id)
 local d=self.store.devices[id]
 if not d or d.kind~="generator" or not F.Near(p,d.entity,110) or d.running then return false,"Подойдите к остановленному генератору." end
 if d.fuel>=600 then return false,"Бак заполнен." end
 local fuel=item(p,"facility_fuel");if not fuel then return false,"Нужна канистра топлива." end
 local added=math.min(300,600-d.fuel)
 fuel:Remove(true);d.fuel=d.fuel+added;self.dirty=true;self:SyncDevice(d)
 return true,"Генератор заправлен: +"..F.Time(added)..". В баке: "..F.Time(d.fuel).."."
end
