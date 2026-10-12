local P,F=PLUGIN,ix.Facility
util.AddNetworkString("ixFacilityRequest");util.AddNetworkString("ixFacilityUI")
local function sorted(rows) local result={};for _,r in SortedPairs(rows) do result[#result+1]=r end;return result end
function P:Snapshot(p,page)
 local data={page=page,admin=p:IsAdmin(),jobs=self:JobRows(p),circuits={},devices={},doors={},calls={},cameras={}}
 if page=="jobs" and not p:IsAdmin() then
  for _,d in pairs(self.store.devices) do if d.kind=="generator" and F.Near(p,d.entity,160) then data.devices[#data.devices+1]={id=d.id,kind=d.kind,name=d.name,entity=d.entity:EntIndex()} end end
  return data
 end
 for _,c in ipairs(sorted(self.store.circuits)) do data.circuits[#data.circuits+1]={id=c.id,name=c.name,zone=c.zone,load=c.load,priority=c.priority,
  powered=c.powered,source=c.source,isolated=c.isolated,mainsOff=c.mainsOff,lockdown=c.lockdown} end
 for _,d in ipairs(sorted(self.store.devices)) do
  data.devices[#data.devices+1]={id=d.id,kind=d.kind,name=d.name,circuit=d.circuit,enabled=d.enabled,fault=d.fault,powered=self:DevicePowered(d),
   fuel=d.fuel,charge=d.charge,running=d.running,capacity=d.capacity,radius=d.radius,width=d.width,level=d.level,department=d.department,
   localPos=d.localPos,localAng=d.localAng,entity=IsValid(d.entity) and d.entity:EntIndex() or 0}
 end
 for _,d in ipairs(sorted(self.store.doors)) do if p:IsAdmin() or F.Access(p,d.level,d.department) then
  data.doors[#data.doors+1]={id=d.id,name=d.name,circuit=d.circuit,level=d.level,department=d.department,dual=d.dual,camera=d.camera,
   status=self:DoorStatus(d),allowed=self:DoorAllowed(p,d),pending=self.approvals[d.id] and self.approvals[d.id].untilTime>CurTime()}
 end end
 for id,c in pairs(self.calls) do local d=self.store.devices[id]
  if d then data.calls[#data.calls+1]={id=id,name=d.name,caller=IsValid(c.player) and c.player:Name() or "—",operator=IsValid(c.operator) and c.operator:Name(),mine=c.operator==p} end
 end
 data.transmitting=self.broadcasts[p] and self.broadcasts[p].circuit
 local preview=self.previews[p]
 if preview and self:CameraPreviewAllowed(p,preview.camera) then data.previewCamera=preview.camera;data.previewSeconds=math.max(0,preview.untilTime-CurTime()) end
 if p:IsAdmin() then
  local b=ix.plugin.list.blackout;data.zones={};for name in SortedPairs(b and b.zones or {}) do data.zones[#data.zones+1]=name end
  local c=ix.plugin.list.cctv;for _,d in pairs(c and c.devices or {}) do if d.kind=="camera" then data.cameras[#data.cameras+1]={id=d.id,name=d.name} end end
 end
 return data
end
function P:SendUI(p,page,id,message,focusKind)
 if not F.Active(p) or (page=="admin" and not p:IsAdmin()) then return end
 if page=="jobs" and self.work[p] and self.work[p].repair then return end -- keep the calibration popup in front
 local data=self:Snapshot(p,page);data.focus=id;data.focusKind=focusKind;data.message=message
 local raw=util.TableToJSON(data);local packed=raw and util.Compress(raw)
 if not packed or #packed>60000 then return end
 net.Start("ixFacilityUI");net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.Send(p)
end
function P:Place(p,kind,trace)
 if not F.Active(p) or not p:IsAdmin() then return false,"Только для администрации." end
 if not F.kinds[kind] or table.Count(self.store.devices)>=96 then return false,"Достигнут предел устройств." end
 local tr=trace or p:GetEyeTrace()
 if not tr.Hit or tr.HitSky or tr.HitPos:DistToSqr(p:GetShootPos())>256^2 then return false,"Посмотрите на поверхность рядом." end
 local pos=tr.HitPos+tr.HitNormal*8
 if kind=="generator" then
  -- Spawnmenu generators use the same measured floor as inventory placement.
  if tr.HitNormal.z<.96 then return false,"Установите генератор на ровный пол." end
  pos=tr.HitPos+Vector(0,0,2-F.generatorFloor)
 end
 local d=self:DeviceRecord(kind,pos,Angle(0,p:EyeAngles().y+180,0))
 local parent
 if kind=="panel" then
  local C=ix.CCTV;local cfg;if C then cfg,parent=C.SurfacePlacement(p,tr) end
  if not cfg or not IsValid(parent) then return false,"Посмотрите на prop (не стену карты)." end
  local presets=ix.data.Get("facility_panel_presets_v1",{},false,true);local preset=presets[parent:GetModel()]
  if not ix.PropScreens.Occupied(parent) and istable(preset) and F.Vector(preset.pos) and F.Angle(preset.ang) and F.Number(preset.width,8,100) then
   d.localPos=preset.pos;d.localAng=preset.ang;d.width=preset.width
  else d.localPos=Vector(cfg.x,cfg.y,cfg.z);d.localAng=Angle(cfg.p,cfg.yaw,cfg.r) end
  d.binding={mapid=parent:MapCreationID(),model=parent:GetModel(),pos=parent:GetPos()}
 end
 self.store.devices[d.id]=d
 if not self:SpawnDevice(d,parent) then self.store.devices[d.id]=nil;return false,"Не удалось создать устройство." end
 self.dirty=true;self:SaveData();self:Audit(p,"place",d.id);return true,"Устройство создано: #"..d.id,d.id
end
function P:BindDoor(p,e)
 if not F.Active(p) or not p:IsAdmin() then return false,"Только для администрации." end
 if not F.Door(e) or not F.Near(p,e,256) or e:MapCreationID()<0 then return false,"Выберите поддерживаемую дверь карты рядом." end
 for _,door in pairs(self.store.doors) do if door.mapid==e:MapCreationID() then return true,"Дверь уже зарегистрирована.",door.id end end
 if table.Count(self.store.doors)>=128 then return false,"Лимит — 128 дверей." end
 local id=self:NewID();self.store.doors[id]={id=id,name="Дверь "..id,mapid=e:MapCreationID(),entity=e,level=2,department="",circuit=0,camera=0,dual=false}
 self.dirty=true;self:SaveData();self:Audit(p,"bindDoor",id);return true,"Дверь добавлена.",id
end
function P:ConfigureEntity(p,e)
 if not F.Active(p) or not p:IsAdmin() or not F.Near(p,e,256) then return end
 local target=ix.PropScreens.Aim(p,256)
 if target and target.kind=="panel" and target.row.entity:GetParent()==e then self:SendUI(p,"admin",target.row.id);return end
 local panels={}
 for _,panel in pairs(self.store.devices) do
  if panel.kind=="panel" and IsValid(panel.entity) and panel.entity:GetParent()==e then panels[#panels+1]=panel end
 end
 if #panels>0 then self:SendUI(p,"admin",#panels==1 and panels[1].id or nil);return end
 if F.Door(e) then
  local ok,msg,id=self:BindDoor(p,e);self:SendUI(p,"admin",ok and id or nil,msg,"door");return
 end
 local d=self.store.devices[e.facilityID]
 if d and d.entity==e then self:SendUI(p,"admin",d.id) end
end
function P:AdminAction(p,a)
 if not p:IsAdmin() or not F.Active(p) then return false,"Только для администрации." end
 local cmd=a.command;local d=self.store.devices[a.id]
 if cmd=="place" then return self:Place(p,a.kind)
 elseif cmd=="circuit" then
  local name=F.Text(a.name,64);local b=ix.plugin.list.blackout
  if not name or not b or not b.zones[a.zone] or table.Count(self.store.circuits)>=32 then return false,"Нужны название и существующая blackout-зона (максимум 32 цепи)." end
  for _,c in pairs(self.store.circuits) do if c.zone==a.zone then return false,"Зона уже подключена к цепи." end end
  local id=self:NewID();self.store.circuits[id]={id=id,name=name,zone=a.zone,priority=3,load=20,isolated=false,mainsOff=false}
 elseif cmd=="circuitConfig" then
  local c=self.store.circuits[a.id]
  if not c or not F.Text(a.name,64) or not F.Number(a.load,1,500) or not F.Number(a.priority,1,5) or a.priority%1~=0 then return false,"Проверьте поля цепи." end
  c.name=a.name;c.load=a.load;c.priority=a.priority;c.mainsOff=a.mainsOff==true
 elseif cmd=="deviceConfig" then
  if not d or not F.Text(a.name,64) or (a.circuit~=0 and not self.store.circuits[a.circuit]) or not F.Number(a.radius,100,600)
   or not F.Number(a.capacity,1,500) or not F.Number(a.level,0,4) or a.level%1~=0 or not table.HasValue(F.departments,a.department) then return false,"Проверьте поля устройства." end
  if d.kind=="panel" then
   local pos,ang=F.Vector(a.localPos),F.Angle(a.localAng)
   if not pos or pos:Length()>4096 or not ang or not F.Number(a.width,8,100) then return false,"Некорректное размещение экрана." end
   d.localPos=pos;d.localAng=ang;d.width=a.width
   if IsValid(d.entity) then d.entity:SetLocalPos(pos);d.entity:SetLocalAngles(ang) end
  end
  d.name=a.name;d.circuit=(d.kind=="generator" or d.kind=="battery") and 0 or a.circuit;d.radius=a.radius;d.capacity=a.capacity;d.level=a.level;d.department=a.department
 elseif cmd=="preset" and d and d.kind=="panel" and d.binding then
  local presets=ix.data.Get("facility_panel_presets_v1",{},false,true)
  if table.Count(presets)>=64 and not presets[d.binding.model] then return false,"Лимит пресетов — 64." end
  presets[d.binding.model]={pos=d.localPos,ang=d.localAng,width=d.width};ix.data.Set("facility_panel_presets_v1",presets,false,true)
 elseif cmd=="fault" and d then d.fault=not d.fault
  if not d.fault then for _,j in pairs(self.store.jobs) do if j.targetKind=="device" and j.target==d.id then j.status="closed" end end end
 elseif cmd=="cctvFault" then
  local c=ix.plugin.list.cctv;local camera=c and c.devices[a.id]
  if not camera or camera.kind~="camera" then return false,"Камера не найдена." end
  local j=self:NewJob("cctv",camera.id,"Ремонт камеры: "..camera.name,1)
  if not j then return false,"Очередь заявок заполнена." end
  if j.previousOn==nil then j.previousOn=camera.on end
  camera.on=false;c:SendDevice(camera);c:SaveData()
 elseif cmd=="bindDoor" then
  return self:BindDoor(p,p:GetEyeTrace().Entity)
 elseif cmd=="doorConfig" then
  local door=self.store.doors[a.id];local c=ix.plugin.list.cctv
  if not door or not F.Text(a.name,64) or not F.Number(a.level,1,4) or a.level%1~=0 or not table.HasValue(F.departments,a.department)
   or (a.circuit~=0 and not self.store.circuits[a.circuit]) or (a.camera~=0 and not (c and c.devices[a.camera] and c.devices[a.camera].kind=="camera")) then return false,"Проверьте параметры двери." end
  door.name=a.name;door.level=a.level;door.department=a.department;door.circuit=a.circuit;door.camera=a.camera;door.dual=a.dual==true
 elseif cmd=="remove" then
  if a.kind=="device" and d then self:DropSourceCables(d);self.store.devices[d.id]=nil;if IsValid(d.entity) then d.entity:Remove() end
  elseif a.kind=="door" then
   local door=self.store.doors[a.id]
   self.store.doors[a.id]=nil
   if door and door.wasLocked~=nil and IsValid(door.entity) then door.entity:Fire(door.wasLocked and "Lock" or "Unlock") end
   self.store.doors[a.id]=nil;self.approvals[a.id]=nil
  elseif a.kind=="circuit" then
   for _,x in pairs(self.store.devices) do if x.circuit==a.id then return false,"Сначала отсоедините устройства." end end
   for _,x in pairs(self.store.doors) do if x.circuit==a.id then return false,"Сначала отсоедините двери." end end
   self.store.circuits[a.id]=nil;self.powerTopologyChanged=true
  else return false,"Объект не найден." end
 else return false,"Неизвестная команда." end
 self:DiscoverJobs();self:RecomputePower(0);self.dirty=true;self:SaveData();self:Audit(p,cmd,a.id or a.name or "")
 return true,"Изменения сохранены."
end
function P:TerminalAction(p,s,a)
 local n=ix.plugin.list.foundation_network
 if not istable(a) or not s or s.public or not n or not n:Session(p,s.token) then return false,"Требуется активный сеанс терминала." end
 if a.section=="jobs" then return self:JobAction(p,a) end
 if not self:OperatorValid(p,s) then return false,"Нужны L2 и активный сеанс." end
 if a.section=="comms" then return self:CommsAction(p,s,a)
 elseif a.section=="doors" then
  if a.command=="lockSector" then return self:LockSector(p,s,a) end
  return self:DoorAction(p,s,a)
 elseif a.section=="power" then return self:PowerAction(p,a)
 elseif a.section=="jobs" then return self:JobAction(p,a) end
 return false,"Неизвестный раздел."
end
net.Receive("ixFacilityRequest",function(length,p)
 if length>65536 or not F.Active(p) or (p.ixFacilityNetAt or 0)>CurTime() then return end
 p.ixFacilityNetAt=CurTime()+.2
 local raw=net.ReadString();if #raw>8000 then return end
 local a=util.JSONToTable(raw);if not istable(a) then return end
 local ok,msg,id=false,"Запрос отклонён."
 if a.scope=="admin" and p:IsAdmin() then
  if a.command=="refresh" then ok,msg=true,nil else ok,msg,id=P:AdminAction(p,a) end
  P:SendUI(p,"admin",id,msg)
 elseif a.scope=="connection" then
  ok,msg=P:ConnectionAction(p,a);if msg then p:Notify(msg) end
 elseif a.scope=="device" then
  ok,msg=P:DeviceAction(p,a)
  if ok and (a.command=="pack" or a.command=="connect") then
   local packed=util.Compress(util.TableToJSON({page="device",close=true,message=msg}))
   net.Start("ixFacilityUI");net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.Send(p)
  else P:SendDeviceUI(p,P.store.devices[a.id],msg,ok and a.command=="repair") end
 elseif a.scope=="jobs" then
  if a.command=="refresh" then ok,msg=true,nil
  elseif a.command=="refuel" then ok,msg=P:Refuel(p,a.id)
  else ok,msg=P:JobAction(p,a) end
  P:SendUI(p,"jobs",nil,msg)
 end
end)
local nextTick,nextSave,nextDiscover=0,0,0
function P:Think()
 if not self.loaded or self.restoring or self.stopping or CurTime()<nextTick then return end
 local dt=nextTick==0 and 0 or math.min(1,CurTime()-(nextTick-.25));nextTick=CurTime()+.25
 self:RestoreBindings();self:RestoreLockdowns();self:PruneComms();self:TickJobs();self:RecomputePower(dt)
 for p,m in pairs(self.cableModes) do if not F.Active(p) or m.expires<CurTime() or m.character~=p:GetCharacter():GetID() then
  if IsValid(p) then self:SetCableMode(p) else self.cableModes[p]=nil end
 end end
 if CurTime()>nextDiscover then nextDiscover=CurTime()+5;self:DiscoverJobs() end
 if self.dirty and CurTime()>nextSave then nextSave=CurTime()+10;self:SaveData() end
end
