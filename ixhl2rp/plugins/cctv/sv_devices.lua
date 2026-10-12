local P,C=PLUGIN,ix.CCTV
function P:Ensure()
 self.devices=self.devices or {};self.nextID=self.nextID or 1;self.watchers=self.watchers or {}
end
function P:HasSpace(kind)
 self:Ensure();local def=C.kinds[kind];if not def then return false end
 local count=0;for _,d in pairs(self.devices) do if d.kind==kind and not d.bodycam then count=count+1 end end
 return count<def.limit and self.nextID<=1000000
end
function P:Snapshot(d)
 local pos,ang=C.Transform(d)
 return {id=d.id,kind=d.kind,name=d.name,on=d.on,terminal=d.terminal or 0,camera=d.camera or 0,fov=d.fov or 75,
  pos=pos and {x=pos.x,y=pos.y,z=pos.z},ang=ang and {p=ang.p,y=ang.y,r=ang.r},entityIndex=IsValid(d.entity) and d.entity:EntIndex() or 0,
  surface=d.surface==true,config=d.config,model=d.model,binding=d.binding,bodycam=d.bodycam==true,cameraRig=d.cameraRig}
end
function P:SaveData()
 if not self.loaded or self.restoring then return end
 local rows={}
 for _,d in pairs(self.devices) do
  if d.surface and IsValid(d.entity) then
   local pos=d.entity:GetPos();d.binding={mapid=d.entity:MapCreationID(),pos={x=pos.x,y=pos.y,z=pos.z}}
  end
  if not d.bodycam and (IsValid(d.entity) or (d.surface and self.surfaceRestoring)) then
   local row=self:Snapshot(d);row.entityIndex=nil
   -- Dynamic wearable IDs must never bind a restored monitor to an unrelated
   -- device after a map/restart. Re-select the wearer from the terminal.
   if self.devices[row.camera] and self.devices[row.camera].bodycam then row.camera=0 end
   rows[#rows+1]=row
  end
 end
 ix.data.Set("foundation_cctv_v1",{nextID=self.nextID,devices=rows})
end
function P:RegisterDevice(ent,kind)
 self:Ensure()
 if not self:HasSpace(kind) then ent:Remove();return end
 local d=ent.cctvRestore or {id=self.nextID,kind=kind,name=C.kinds[kind].name.." "..self.nextID,on=true,fov=75,camera=0,terminal=0}
 if self.devices[d.id] then ent:Remove();return end
 self.nextID=math.max(self.nextID,d.id+1);d.entity=ent;d.kind=kind
 if kind=="camera" then d.model=ent:GetModel();d.cameraRig=C.cameraRig.version end
 ent:SetNW2Int("ixCCTVID",d.id);ent.cctvRestore=nil;self.devices[d.id]=d
 if not self.restoring then self:SaveData();self:SendDevice(d) end
end
function P:LoadData()
 self:Ensure();self.restoring=true;self.surfaceRestoring=true;self.watchers={};self:LoadSurfacePresets()
 for _,d in pairs(self.devices) do if d.surface then ix.PropScreens.Unbind(d.entity,"ixCCTVSurfaceID",d.id) end end
 for _,def in pairs(C.kinds) do for _,ent in ipairs(ents.FindByClass(def.class)) do ent:Remove() end end
 self.devices={};self.nextID=1
 local saved=ix.data.Get("foundation_cctv_v1",{})
 for _,row in ipairs(istable(saved) and istable(saved.devices) and saved.devices or {}) do
  if istable(row) and row.surface==true then
   self:RestoreSurface(row)
  elseif istable(row) and not row.bodycam and C.ID(row.id) and C.kinds[row.kind] and C.Vector(row.pos) and C.Angle(row.ang)
   and not self.devices[row.id] and self:HasSpace(row.kind) then
   local d={id=row.id,kind=row.kind,name=C.Name(row.name) or C.kinds[row.kind].name,on=row.on~=false,
    terminal=C.ID(row.terminal) and row.terminal or 0,camera=C.ID(row.camera) and row.camera or 0,
    fov=C.Number(row.fov,30,110) and row.fov or 75}
   local ent=ents.Create(C.kinds[d.kind].class)
   if d.kind=="camera" then
    -- A saved explicit custom model keeps its transform. Legacy default
    -- cameras migrate to the new body while preserving the viewed scene.
    local custom=isstring(row.model) and row.model~=C.cameraRig.legacyModel and row.model~=C.cameraRig.model
    if custom and util.IsValidModel(row.model) then d.model=row.model end
   end
   if IsValid(ent) then
    local pos,ang=C.Vector(row.pos),C.Angle(row.ang)
    if d.kind=="camera" then pos,ang=C.RestoreCameraTransform(row) end
    ent.cctvRestore=d;ent:SetPos(pos);ent:SetAngles(ang);ent:Spawn();ent:Activate()
   end
  end
 end
 if istable(saved) and C.ID(saved.nextID) then self.nextID=math.max(self.nextID,saved.nextID) end
 for _,d in pairs(self.devices) do
  if not self.devices[d.camera] or self.devices[d.camera].kind~="camera" then d.camera=0 end
  if not self.devices[d.terminal] or self.devices[d.terminal].kind~="terminal" then d.terminal=0 end
 end
 self.loaded=true;self.restoring=false;self.stopping=false;self:Sync()
end
function P:RemoveDevice(ent)
 if self.restoring or self.stopping or ix.shuttingDown then return end
 self:Ensure();local id=ent:GetNW2Int("ixCCTVID",0);local d=self.devices[id]
 if not d or d.entity~=ent then return end
 self:DeleteRecord(id)
end
function P:DeleteRecord(id)
 local d=self.devices[id];if not d then return end
 if d.surface then ix.PropScreens.Unbind(d.entity,"ixCCTVSurfaceID",id) end
 self.devices[id]=nil;self:SendRemoved(id)
 for _,other in pairs(self.devices) do
  local changed=false
  if other.camera==id then other.camera=0;changed=true end
  if other.terminal==id then other.terminal=0;changed=true end
  if changed then self:SendDevice(other) end
 end
 self:SaveData()
end
function P:PreCleanupMap() self:SaveData();self.restoring=true;self.watchers={} end
function P:PostCleanupMap()
 -- Helix normally calls LoadData itself. Only restore here if it has not.
 timer.Simple(0,function() if ix.plugin.list.cctv==P and P.restoring then P:LoadData() end end)
end
function P:ShutDown() self:SaveData();self.stopping=true end
function P:OnUnload()
 self:SaveData();self.stopping=true;self.watchers={}
 for _,d in pairs(self.devices or {}) do
  if IsValid(d.entity) and not d.bodycam then
   if d.surface then ix.PropScreens.Unbind(d.entity,"ixCCTVSurfaceID",d.id) else d.entity:Remove() end
  end
 end
end
function P:PhysgunPickup(p,ent) if C.kinds[ent.CCTVKind] and not p:IsAdmin() then return false end end
function P:CanTool(p,tr) if IsValid(tr.Entity) and C.kinds[tr.Entity.CCTVKind] and not p:IsAdmin() then return false end end
function P:CanProperty(p,_,ent) if IsValid(ent) and C.kinds[ent.CCTVKind] and not p:IsAdmin() then return false end end
function P:CanPlayerSpawnSENT(p,class)
 for kind,def in pairs(C.kinds) do if def.class==class and (not p:IsAdmin() or not self:HasSpace(kind)) then return false end end
end
function P:PhysgunDrop(_,ent)
 if not IsValid(ent) then return end
 local changed=false
 for _,surface in pairs(self.devices or {}) do
  if surface.surface and surface.entity==ent then changed=true;self:SendDevice(surface) end
 end
 if changed then self:SaveData() end
 if not C.kinds[ent.CCTVKind] then return end
 local physics=ent:GetPhysicsObject();if IsValid(physics) then physics:EnableMotion(false) end
 local d=self.devices[ent:GetNW2Int("ixCCTVID",0)];if d then self:SendDevice(d);self:SaveData() end
end
function P:CanOperate(p,id)
 self:Ensure();local d=self.devices[id]
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or not p:GetCharacter() then return false end
 if not d or d.kind~="terminal" or not IsValid(d.entity) or not C.Powered(d) then return false end
 return C.TerminalReach(p,d) and hook.Run("CanUseCCTVTerminal",p,d.entity)~=false
end
function P:UseDevice(p,ent)
 self:Ensure();local id=ent:GetNW2Int("ixCCTVID",0);local d=self.devices[id];if not d then return end
 if d.kind=="terminal" then
  if self:CanOperate(p,id) then self:Sync(p);self:SendOpen(p,"terminal",id) else p:Notify("Пульт недоступен или обесточен.") end
 elseif p:IsAdmin() then self:OpenAdmin(p,nil,id) end
end
function P:Action(p,action,v)
 self:Ensure()
 if not IsValid(p) or not p:IsPlayer() or not istable(v) then return false,"Неверные данные." end
 if action=="switch" then
  if not self:CanOperate(p,v.terminal) then return false,"Подойдите к работающему пульту." end
  local camera=self.devices[v.camera]
  if not camera or camera.kind~="camera" then return false,"Камера не найдена." end
  local changed=false
  for _,d in pairs(self.devices) do
   if d.kind=="monitor" and d.terminal==v.terminal and (v.monitor==0 or d.id==v.monitor) then
    d.camera=camera.id;self:SendDevice(d);changed=true
   end
  end
  if not changed then return false,"Нет подключённых мониторов." end
  self:SaveData();return true,"Камера переключена."
 end
 if not p:IsAdmin() then return false,"Только для администрации." end
 if action=="placeSurface" then return self:PlaceSurface(p,v) end
 if action=="surfacePreset" then return self:SaveSurfacePreset(v) end
 if action=="place" then
  if v.kind=="terminal" then return self:PlaceSurface(p,v) end
  if not self:HasSpace(v.kind) then return false,"Достигнут лимит устройств." end
  local pos,ang=C.Placement(p,p:GetEyeTrace(),v.kind);if not pos then return false,"Выберите поверхность не дальше 256 ед." end
  local ent=ents.Create(C.kinds[v.kind].class);if not IsValid(ent) then return false,"Не удалось создать устройство." end
  ent:SetPos(pos);ent:SetAngles(ang);ent:Spawn();ent:Activate()
  undo.Create("CCTV");undo.AddEntity(ent);undo.SetPlayer(p);undo.Finish();p:AddCleanup("props",ent)
  return true,"Устройство размещено. Нажмите E для настройки."
 end
 local d=self.devices[v.id];if not d or not IsValid(d.entity) then return false,"Устройство не найдено." end
 if d.bodycam then return false,"Камерой управляет владелец через меню шлема." end
 if action=="remove" then
  if d.surface then self:DeleteRecord(d.id) else d.entity:Remove() end
  return true,"Устройство удалено."
 end
 if action~="configure" then return false,"Неизвестная команда." end
 local name=C.Name(v.name);if not name or not isbool(v.on) then return false,"Проверьте название и питание." end
 if d.surface and v.config~=nil then
  local config=C.SurfaceConfig(v.config);if not config then return false,"Проверьте размеры и положение экрана." end
  d.config=config
 elseif d.kind=="monitor" then
  if v.terminal~=0 and (not self.devices[v.terminal] or self.devices[v.terminal].kind~="terminal") then return false,"Пульт не найден." end
  if v.camera~=0 and (not self.devices[v.camera] or self.devices[v.camera].kind~="camera") then return false,"Камера не найдена." end
  d.terminal=v.terminal;d.camera=v.camera
 elseif d.kind=="camera" then
  local ang=C.Angle(v.ang);if not ang or not C.Number(v.fov,30,110) then return false,"Неверные углы или поле зрения." end
  d.entity:SetAngles(ang);d.fov=v.fov
 end
 d.name=name;d.on=v.on;self:SendDevice(d);self:SaveData();return true,"Настройки сохранены."
end
