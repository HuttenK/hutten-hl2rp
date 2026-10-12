local P,F=PLUGIN,ix.Facility
P.store={nextID=1,circuits={},devices={},doors={},jobs={}}
P.calls={};P.broadcasts={};P.work={};P.approvals={}
P.previews={}
function P:NewID() local id=self.store.nextID;self.store.nextID=id+1;return id end
function P:DeviceRecord(kind,pos,ang)
 if not F.kinds[kind] or table.Count(self.store.devices)>=96 then return end
 return {id=self:NewID(),kind=kind,name=F.kinds[kind].name,circuit=0,enabled=true,fault=false,level=0,department="",capacity=kind=="battery" and 30 or 60,
  fuel=0,charge=6000,running=false,links={},radius=300,width=32,pos=pos,ang=ang,generatorGeometry=kind=="generator" and F.generatorGeometryVersion or nil}
end
function P:RegisterDevice(ent,kind)
 local current=self.store.devices[ent.facilityID]
 if current and current.entity==ent and current.kind==kind then return current end
 -- Register trusted direct entity spawns too. Owned/reloaded entities already have a record.
 if kind=="panel" then return end -- overlays need an explicitly validated parent binding
 local d=self:DeviceRecord(kind,ent:GetPos(),ent:GetAngles());if not d then return end
 d.entity=ent;ent.facilityID=d.id;self.store.devices[d.id]=d;self.dirty=true;self:SyncDevice(d);return d
end
function P:Audit(p,action,target)
 local n=ix.plugin.list.foundation_network
 if n and n.store and n.Audit then n:Audit(p,"Инфраструктура",target,"Выполнено",action) end
end
function P:SaveData()
 if not self.loaded or self.restoring then return end
 local saved={nextID=self.store.nextID,circuits={},devices={},doors={},jobs={}}
 for kind,rows in pairs(self.store) do if istable(rows) then for _,v in pairs(rows) do
  local row={};for k,x in pairs(v) do if k~="entity" and k~="powered" and k~="source" and k~="pending" and k~="lockApplied" and k~="nextRing" and k~="chargeSource" then row[k]=x end end
  if kind=="devices" and IsValid(v.entity) then
   row.pos=v.entity:GetPos();row.ang=v.entity:GetAngles()
   if IsValid(v.entity:GetParent()) then
    local parent=v.entity:GetParent();row.binding={mapid=parent:MapCreationID(),model=parent:GetModel(),pos=parent:GetPos()}
    row.localPos=v.entity:GetLocalPos();row.localAng=v.entity:GetLocalAngles()
   end
  end
  saved[kind][#saved[kind]+1]=row
 end end end
 ix.data.Set("foundation_utilities_v1",saved);self.dirty=false
end
function P:SpawnDevice(d,parent)
 local ent=ents.Create("ix_facility_"..d.kind);if not IsValid(ent) then return end
 ent.facilityID=d.id;d.entity=ent
 ent:SetPos(F.Vector(d.pos) or Vector());ent:SetAngles(F.Angle(d.ang) or Angle())
 if IsValid(parent) then ent:SetParent(parent);ent:SetLocalPos(F.Vector(d.localPos));ent:SetLocalAngles(F.Angle(d.localAng));ix.PropScreens.Bind(parent,"ixFacilityPanelID",d.id) end
 ent:Spawn();if not IsValid(ent) then return end
 ent:Activate()
 if d.kind=="generator" or d.kind=="battery" then
  local physics=ent:GetPhysicsObject()
  if IsValid(physics) then physics:EnableMotion(true);physics:Wake() end
 end
 self:SyncDevice(d);return ent
end
function P:SyncDevice(d)
 local e=d.entity;if not IsValid(e) then return end
 if d.kind=="generator" or d.kind=="battery" then
  local pos,ang=e:GetPos(),e:GetAngles()
  if pos:DistToSqr(F.Vector(d.pos) or pos)>.01 or ang~=d.ang then
   d.pos=pos;d.ang=ang;self.dirty=true
  end
 end
 e:SetNW2Int("ixFacilityID",d.id);e:SetNW2String("ixFacilityName",d.name)
 e:SetNW2Bool("ixFacilityFault",d.fault==true);e:SetNW2Bool("ixFacilityPowered",self:DevicePowered(d))
 e:SetNW2Float("ixFacilityWidth",d.width or 32)
 if d.kind=="generator" then e:SetNW2Float("ixFacilityFuel",math.Clamp(d.fuel or 0,0,600));e:SetNW2Bool("ixFacilityRunning",d.running==true)
 elseif d.kind=="battery" then e:SetNW2Float("ixFacilityCharge",math.Clamp(d.charge or 0,0,6000)) end
 if d.kind~="intercom" and d.kind~="receiver" and d.kind~="announcement" then e:SetNW2String("ixFacilityState",d.kind=="generator" and ((d.running and "РАБОТАЕТ" or "ОСТАНОВЛЕН").." / "..F.Time(d.fuel).." ТОПЛИВА")
  or d.kind=="battery" and (d.chargeSource or "РЕЗЕРВ") or "") end
end
function P:LoadData()
 self:ClearGeneratorPower();self.linkEntities={}
 for p in pairs(self.cableModes) do if IsValid(p) then self:SetCableMode(p) end end
 if self.CancelWork then for p in pairs(self.work) do self:CancelWork(p,"Ремонт остановлен при перезагрузке.",true) end end
 self.restoring=true;self.calls={};self.broadcasts={};self.work={};self.approvals={};self.previews={};self.powerTopologyChanged=true
 for _,d in pairs(self.store.devices) do if IsValid(d.entity) then d.entity:Remove() end end
 local saved=ix.data.Get("foundation_utilities_v1",{})
 self.store={nextID=1,circuits={},devices={},doors={},jobs={}}
 for _,kind in ipairs({"circuits","devices","doors","jobs"}) do
  for _,row in ipairs(istable(saved[kind]) and saved[kind] or {}) do
   if istable(row) and F.ID(row.id) and F.Text(row.name or row.title or "",80) then
    if kind~="devices" or (F.kinds[row.kind] and F.Vector(row.pos) and F.Angle(row.ang)) then
     row.entity=nil;row.powered=nil;row.pending=nil;row.lockApplied=nil;row.nextRing=nil;self.store[kind][row.id]=row;self.store.nextID=math.max(self.store.nextID,row.id+1)
     if kind=="jobs" and row.targetKind=="fusebox" then row.status="closed" end
     if kind=="jobs" and row.status=="assigned" then row.status="open";row.owner=nil;row.ownerName=nil end
     if kind=="devices" and (row.kind=="generator" or row.kind=="battery") then
      F.MigrateGeneratorGeometry(row);row.running=false;row.circuit=0;row.links=istable(row.links) and row.links or {}
     end
     if kind=="devices" and not row.binding then self:SpawnDevice(row) end
    end
   end
  end
 end
 if F.ID(saved.nextID) then self.store.nextID=math.max(self.store.nextID,saved.nextID) end
 self.loaded=true;self.restoring=false;self.bindUntil=CurTime()+30;self.dirty=true
 self:RecomputePower(0)
 if self.ConvertExistingSourceItems then self:ConvertExistingSourceItems() end
end
function P:RestoreBindings()
 for _,d in pairs(self.store.devices) do if d.binding and not IsValid(d.entity) then
  local b=d.binding;local parent=b.mapid and b.mapid>=0 and ents.GetMapCreatedEntity(b.mapid)
  if not IsValid(parent) and F.Vector(b.pos) then
   for _,e in ipairs(ents.FindByClass("prop_physics")) do
    if e:GetModel()==b.model and e:GetPos():DistToSqr(F.Vector(b.pos))<16 then parent=e;break end
   end
  end
  if IsValid(parent) and parent:GetModel()==b.model and F.Vector(d.localPos) and F.Angle(d.localAng) then self:SpawnDevice(d,parent)
  elseif CurTime()>(self.bindUntil or 0) then self.store.devices[d.id]=nil;self.dirty=true end
 end end
 for _,d in pairs(self.store.doors) do
  if not IsValid(d.entity) then local e=ents.GetMapCreatedEntity(d.mapid);if F.Door(e) then d.entity=e end end
 end
end
function P:DeviceRemoved(ent)
 local parent=ent:GetParent()
 ix.PropScreens.Unbind(parent,"ixFacilityPanelID",ent.facilityID)
 if self.restoring or self.stopping or ix.shuttingDown then return end
 local id=ent.facilityID;local d=self.store.devices[id]
 if d and d.entity==ent then self:DropSourceCables(d);self.store.devices[id]=nil;self.dirty=true;self:RecomputePower(0);self:SaveData() end
end
function P:PhysgunDrop(_,e)
 if e.facilityID then self.dirty=true end
 for _,d in pairs(self.store.devices) do if IsValid(d.entity) and d.entity:GetParent()==e then self.dirty=true end end
end
function P:PreCleanupMap() self:SaveData();self.restoring=true end
function P:PostCleanupMap() self:LoadData() end
function P:ShutDown() self:SaveData();self.stopping=true end
function P:OnUnload()
 self:ClearGeneratorPower()
 for p in pairs(self.cableModes) do if IsValid(p) then self:SetCableMode(p) end end
 for p in pairs(self.work) do self:CancelWork(p,"Работа остановлена.",true) end
 self:SaveData();self.stopping=true
 for _,d in pairs(self.store.doors) do if d.wasLocked~=nil and IsValid(d.entity) then d.entity:Fire(d.wasLocked and "Lock" or "Unlock") end end
 for _,d in pairs(self.store.devices) do if IsValid(d.entity) then d.entity:Remove() end end
 self.calls={};self.broadcasts={};self.work={};self.previews={};self.approvals={}
 for _,p in ipairs(player.GetAll()) do p:SetNW2Bool("ixFacilityMic",false);p:SetNW2String("ixFacilityVoiceHint","");p:SetNW2String("ixFacilityStopHint","") end
 self:RefreshBlackouts()
end
function P:ReleaseWorker(p,c)
 if self.cableModes[p] then self:SetCableMode(p) end
 self:CancelWork(p,nil,true)
 self.broadcasts[p]=nil;self.work[p]=nil;self.previews[p]=nil
 for _,j in pairs(self.store.jobs) do if c and j.owner==c:GetID() and j.status=="assigned" then j.owner=nil;j.ownerName=nil;j.status="open";self.dirty=true end end
end
function P:PlayerDisconnected(p) self:ReleaseWorker(p,p:GetCharacter()) end
function P:PlayerLoadedCharacter(p,_,previous) self:ReleaseWorker(p,previous) end
function P:UseDevice(p,e)
 local d=self.store.devices[e.facilityID];if not d or not F.Near(p,e) then return end
 if p:IsAdmin() and p:KeyDown(IN_WALK) then self:SendUI(p,"admin",d.id);return end
 if d.fault then self:SendDeviceUI(p,d);return end
 if F.IsScreen(e) then local n=ix.plugin.list.foundation_network;if n and self:DevicePowered(d) then n:Open(p,e) end
 elseif d.kind=="intercom" then local ok,msg=self:CallIntercom(p,d);p:Notify(msg)
 elseif d.kind=="receiver" then local ok,msg=self:UseReceiver(p,d);p:Notify(msg)
 elseif d.kind=="announcement" then local ok,msg=self:UseAnnouncement(p,d);p:Notify(msg)
 else self:SendDeviceUI(p,d) end
end
function P:AimPanel(p,limit)
 local best,bestHit,depth=nil,nil,math.min(limit or 128,256)
 for _,d in pairs(self.store.devices) do if d.kind=="panel" and IsValid(d.entity) and IsValid(d.entity:GetParent()) then
  local pos,a,scale=F.PanelGeometry(d.entity);local ray=p:GetAimVector();local dot=ray:Dot(a:Up())
  if dot<-.001 then
   local distance=(pos-p:GetShootPos()):Dot(a:Up())/dot
   if distance>0 and distance<depth then
    local delta=p:GetShootPos()+ray*distance-pos;local x,y=delta:Dot(a:Forward())/scale,delta:Dot(a:Right())/scale
    if x>=0 and y>=0 and x<=1920 and y<=1120 then
     local hit=p:GetShootPos()+ray*distance
     local tr=util.TraceLine({start=p:GetShootPos(),endpos=hit,filter=p,mask=MASK_SOLID})
     if not tr.Hit or tr.HitPos:DistToSqr(hit)<16 then best,bestHit,depth=d,hit,distance end
    end
   end
  end
 end end
 return best,bestHit
end
function P:PlayerUse(p,ent)
 if not F.Active(p) or not IsValid(ent) then return end
 local target=ix.PropScreens.Aim(p,128)
 if target and target.kind=="panel" and target.row.entity:GetParent()==ent then self:UseDevice(p,target.row.entity);return false end
end
