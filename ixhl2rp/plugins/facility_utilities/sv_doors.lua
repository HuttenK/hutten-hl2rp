local P,F=PLUGIN,ix.Facility
function P:DoorStatus(d)
 local e=d.entity;if not F.Door(e) then return "НЕДОСТУПНА" end
 local state=e:GetSaveTable() or {};local position=state.m_eDoorState or state.m_toggle_state
 local open=state.m_eDoorState~=nil and position==2 or state.m_eDoorState==nil and position==0
 local moving=state.m_eDoorState~=nil and (position==1 or position==3) or state.m_eDoorState==nil and (position==2 or position==3)
 return (moving and "ДВИЖЕНИЕ" or open and "ОТКРЫТА" or "ЗАКРЫТА")..(state.m_bLocked and " / ЗАПЕРТА" or " / НЕ ЗАПЕРТА")
end
function P:DoorAllowed(p,d)
 local c=d and self.store.circuits[d.circuit]
 if not d or not F.Door(d.entity) or d.fault then return false end
 local access=ix.plugin.list.map_keycards
 -- LockSector must still authorize an operator who is releasing an existing lockdown.
 if access and not access:GroupAllowed(p,access:FindGroup(d.entity),d.entity,true) then return false end
 local powered
 powered=self:DirectGrid(d.entity)
 if F.EntityBackup(d.entity) and not self:EntityIsolated(d.entity) then powered=true end
 local b=ix.plugin.list.blackout
 local override=b and b.ElectronicsOverride and b:ElectronicsOverride(d.entity:GetPos())
 if override~=nil then powered=not override end
 return powered and F.Access(p,d.level,d.department)
end
function P:DoorAction(p,session,data)
 local commands={open="Open",close="Close",lock="Lock",unlock="Unlock"}
 local action=data.command;local d=self.store.doors[data.id]
 if action=="camera" and self:DoorAllowed(p,d) and d.camera and d.camera~=0 then
  local c=ix.plugin.list.cctv
  if not c or not c.devices[d.camera] or c.devices[d.camera].kind~="camera" then return false,"Камера недоступна." end
  self.previews[p]={door=d.id,camera=d.camera,session=session,untilTime=CurTime()+30}
  return true,"Камера у двери / просмотр на 30 секунд."
 end
 if not commands[action] or not self:DoorAllowed(p,d) then return false,"Дверь недоступна: проверьте питание и допуск." end
 local circuit=self.store.circuits[d.circuit]
 if circuit and circuit.lockdown and (action=="open" or action=="unlock") then return false,"Сначала снимите блокировку сектора." end
 local partner=d.entity.GetDoorPartner and d.entity:GetDoorPartner()
 local dual=d.dual
 if IsValid(partner) then
  local linked;for _,other in pairs(self.store.doors) do if other.entity==partner then linked=other end end
  if not linked or not self:DoorAllowed(p,linked) then return false,"Зарегистрируйте вторую створку с подходящим допуском." end
  local c=self.store.circuits[linked.circuit]
  if c and c.lockdown and (action=="open" or action=="unlock") then return false,"Вторая створка находится в заблокированном секторе." end
  dual=dual or linked.dual
  -- Explicitly operate each registered leaf; no implicit lower-clearance bypass.
 end
 if action=="open" and (d.entity:GetSaveTable() or {}).m_bLocked then return false,"Сначала снимите блокировку." end
 if dual and (action=="unlock" or action=="open") then
  local q=self.approvals[d.id];local cid=p:GetCharacter():GetID()
  if not q or q.action~=action or q.untilTime<CurTime() then
   self.approvals[d.id]={action=action,player=p,character=cid,session=session,untilTime=CurTime()+30}
   return true,"Ожидание второго сотрудника (30 секунд)."
  end
  if q.character==cid then return false,"Подтверждение должен выполнить другой сотрудник." end
  local n=ix.plugin.list.foundation_network
  if not IsValid(q.player) or not n or not n:Session(q.player,q.session.token) or not self:DoorAllowed(q.player,d) then self.approvals[d.id]=nil;return false,"Первое подтверждение утратило силу." end
  self.approvals[d.id]=nil
 end
 d.entity:Fire(commands[action],"",0,p,p)
 if IsValid(partner) then partner:Fire(commands[action],"",0,p,p) end
 self:Audit(p,"Дверь: "..action,d.name);return true,"Команда передана: "..d.name
end
function P:CameraPreviewAllowed(p,id)
 local v=self.previews[p]
 return v and v.camera==id and v.untilTime>CurTime() and self:OperatorValid(p,v.session) and self:DoorAllowed(p,self.store.doors[v.door]) or false
end
function P:LockSector(p,session,data)
 if not F.Access(p,3) then return false,"Для блокировки сектора требуется L3." end
 local circuit=self.store.circuits[data.id];if not circuit then return false,"Сектор не найден." end
 local list={}
 for _,d in pairs(self.store.doors) do if d.circuit==data.id then
  if not self:DoorAllowed(p,d) then return false,"Одна из дверей недоступна. Блокировка не начата." end
  list[#list+1]=d
 end end
 if #list==0 then return false,"Нет связанных дверей." end
 if circuit.lockdown then
  circuit.lockdown=false
  for _,d in ipairs(list) do d.entity:Fire(d.wasLocked and "Lock" or "Unlock","",0,p,p);d.wasLocked=nil;d.lockApplied=nil end
  self.dirty=true;self:Audit(p,"Снятие блокировки сектора",data.id);return true,"Блокировка снята; прежнее состояние замков восстановлено."
 end
 circuit.lockdown=true
 for _,d in ipairs(list) do d.wasLocked=(d.entity:GetSaveTable() or {}).m_bLocked==true;d.lockApplied=true;d.entity:Fire("Close","",0,p,p);d.entity:Fire("Lock","",0,p,p) end
 self.dirty=true;self:Audit(p,"Блокировка сектора",data.id);return true,"Двери сектора закрываются и запираются. Проверьте состояние."
end
function P:AcceptInput(ent,input)
 if self.stopping then return end
 local command=string.lower(input)
 if command~="open" and command~="openawayfrom" and command~="unlock" and command~="toggle" then return end
 for _,d in pairs(self.store.doors) do
  local c=self.store.circuits[d.circuit]
  if d.entity==ent and c and c.lockdown then return true end
 end
end
function P:RestoreLockdowns()
 for _,d in pairs(self.store.doors) do
  local c=self.store.circuits[d.circuit]
  if c and c.lockdown and F.Door(d.entity) and not d.lockApplied then
   d.entity:Fire("Close");d.entity:Fire("Lock");d.lockApplied=true
  end
 end
end
