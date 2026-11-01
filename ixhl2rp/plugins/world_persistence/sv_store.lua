local P = PLUGIN
P.records = P.records or {}
P.nextID = P.nextID or 1

function P:Eligible(ent)
 return IsValid(ent) and self.classes[ent:GetClass()] == true
  and ent:MapCreationID() < 0 and not ent:GetNetVar("Persistent", false)
end

function P:Capture(ent, id)
 local row = {id=id, class=ent:GetClass(), pos=ent:GetPos(), ang=ent:GetAngles(),
  model=ent:GetModel(), skin=ent:GetSkin(), color=ent:GetColor(), material=ent:GetMaterial(),
  collision=ent:GetCollisionGroup(), bodygroups={}, submaterials={}, screenHostID=ent.ixPropScreenHostID}
 for _, group in ipairs(ent:GetBodyGroups() or {}) do row.bodygroups[tostring(group.id)] = ent:GetBodygroup(group.id) end
 for index in ipairs(ent:GetMaterials() or {}) do
  local value = ent:GetSubMaterial(index-1)
  if value and value ~= "" then row.submaterials[tostring(index-1)] = value end
 end
 local physics = ent:GetPhysicsObject()
 if IsValid(physics) then row.movable = physics:IsMoveable() end
 if row.class == "ix_garbage" and ent.nextRespawn then
  row.respawnAt = os.time() + math.max(0, ent.nextRespawn-CurTime())
 end
 return row
end

function P:Track(ent)
 if not self.loaded or self.cleaning or self.stopping or not self:Eligible(ent) then return end
 local id = ent.ixWorldPersistenceID
 if id and self.records[id] and self.records[id].entity == ent then return end
 id = self.nextID; self.nextID = id+1
 ent.ixWorldPersistenceID = id
 self.records[id] = {entity=ent, data=self:Capture(ent,id)}
 self:QueueSave()
end

function P:QueueSave()
 if not self.loaded or self.cleaning or self.stopping or ix.shuttingDown then return end
 timer.Create("ixWorldEntitiesSave", .25, 1, function()
  if ix.plugin.list.world_persistence == P then P:SaveData() end
 end)
end

function P:SaveData(onlyChanged,prepared)
 if not self.loaded or self.restoring or self.cleaning or self.storageFault then return end
 local rows = {}
 for id, record in pairs(self.records) do
  if IsValid(record.entity) then
   if self:Eligible(record.entity) then
    if not prepared then record.data = self:Capture(record.entity,id) end
    rows[#rows+1] = record.data
   end
  elseif record.pending then
   -- An unavailable entity class must not erase its saved placement.
   rows[#rows+1] = record.data
  end
 end
 table.sort(rows, function(a,b) return a.id<b.id end)
 local snapshot={version=1,nextID=self.nextID,entities=rows}
 if ix.recordStore then
  local records={metadata={version=1,nextID=self.nextID}}
  for _,row in ipairs(rows) do records["entity:"..row.id]=row end
  local ok,err=ix.recordStore.Save("world_persistence/"..game.GetMap(),records)
  if not ok then error("World entity records not saved: "..tostring(err)) end
  return
 end
 local encoded=util.TableToJSON(snapshot)
 if onlyChanged==true and encoded and encoded==self.lastSnapshot then return end
 self:SetData(snapshot)
 self.lastSnapshot=encoded
end

function P:Restore(record)
 if IsValid(record.entity) then return end
 local row, ent = record.data, nil
 record.pending = true
 local ok, err = xpcall(function()
  ent = ents.Create(row.class)
  if not IsValid(ent) then error("unavailable entity class: " .. row.class) end
  ent.ixWorldPersistenceID = row.id
  if ix.PropScreens and ix.PropScreens.ValidHostID(row.screenHostID) then ent.ixPropScreenHostID=row.screenHostID end
  ent:SetPos(row.pos); ent:SetAngles(row.ang); ent:Spawn(); ent:Activate()
  if not IsValid(ent) then error("entity removed during spawn: " .. row.class) end
  if isstring(row.model) and row.model ~= "" and ent:GetModel() ~= row.model then
   ent:SetModel(row.model)
   if IsValid(ent:GetPhysicsObject()) then ent:PhysicsInit(SOLID_VPHYSICS) end
  end
  ent:SetSkin(tonumber(row.skin) or 0)
  if istable(row.color) then ent:SetColor(row.color) end
  if isstring(row.material) then ent:SetMaterial(row.material) end
  if isnumber(row.collision) then ent:SetCollisionGroup(row.collision) end
  for index,value in pairs(row.bodygroups or {}) do
   if tonumber(index) and isnumber(value) then ent:SetBodygroup(tonumber(index),value) end
  end
  for index,value in pairs(row.submaterials or {}) do
   if tonumber(index) and isstring(value) then ent:SetSubMaterial(tonumber(index),value) end
  end
  local physics = ent:GetPhysicsObject()
  if IsValid(physics) then physics:EnableMotion(row.movable == true) end
  if row.class == "ix_garbage" and isnumber(row.respawnAt) and row.respawnAt > os.time() then
   ent.nextRespawn = CurTime()+row.respawnAt-os.time()
  end
 end, debug.traceback)
 if ok then record.entity, record.pending = ent, nil
 else
  if IsValid(ent) then ent:Remove() end
  ErrorNoHalt("[World persistence] Placement " .. row.id .. " retained for retry: " .. tostring(err) .. "\n")
 end
end

function P:LoadData()
 if self.restoring then return end
 self.restoring = true
 if not self.loaded then
  self.storageFault=true
  local saved
  if ix.recordStore then
   local records,err=ix.recordStore.Load("world_persistence/"..game.GetMap())
   if err then self.storageFault=true;self.restoring=nil;error("World entity records unreadable: "..tostring(err)) end
   if records then
    saved=records.metadata
    if not istable(saved) or saved.version~=1 or not isnumber(saved.nextID) or saved.nextID<1
     or saved.nextID%1~=0 or saved.nextID>=2147483647 then self.restoring=nil;error("Invalid world record metadata") end
    saved.entities={}
    for key,row in pairs(records) do if key~="metadata" then
     if not istable(row) or not isnumber(row.id) or key~="entity:"..row.id or row.id>=saved.nextID then
      self.restoring=nil;error("Invalid world record identity")
     end
     saved.entities[#saved.entities+1]=row
    end end
   end
  end
  saved=saved or self:GetData({})
  if not istable(saved) or (saved.version ~= nil and (saved.version ~= 1 or not istable(saved.entities))) then
   self.storageFault = true; self.restoring = nil
   error("World entity save is unreadable; refusing to overwrite it")
  end
  local restored,nextID,count={},1,0
  for key,row in pairs(saved.entities or {}) do
   if not istable(row) or not isnumber(row.id) or row.id < 1 or row.id ~= math.floor(row.id)
    or row.id>=2147483647 or not self.classes[row.class] or not isvector(row.pos) or not isangle(row.ang) or restored[row.id]
    or not isnumber(key) or key<1 or key%1~=0 or (row.bodygroups~=nil and not istable(row.bodygroups))
    or (row.submaterials~=nil and not istable(row.submaterials)) then
    self.storageFault = true; self.restoring = nil
    error("Invalid or duplicate world entity record; refusing to overwrite the save")
   end
   count=count+1;restored[row.id] = {data=row, pending=true}
   nextID = math.max(nextID,row.id+1)
  end
  if count~=#(saved.entities or {}) then self.restoring=nil;error("Sparse world entity save; refusing to discard records") end
  if isnumber(saved.nextID) and saved.nextID==math.floor(saved.nextID) and saved.nextID<2147483647 then
   nextID = math.max(nextID,saved.nextID)
  end
  self.records,self.nextID,self.storageFault=restored,nextID,nil
  self.loaded = true
 end
 for _,record in pairs(self.records) do self:Restore(record) end
 self.restoring, self.cleaning, self.stopping = nil, nil, nil
end

function P:PostLoadData()
 if not self.loaded or self.storageFault then return end
 -- Also adopt entities that existed before this plugin loaded. Previously
 -- marked Helix persistent entities retain that single existing owner.
 for class in pairs(self.classes) do
  for _,ent in ipairs(ents.FindByClass(class)) do self:Track(ent) end
 end
 self:QueueSave();self:InstallMaintenance()
end

function P:OnEntityCreated(ent)
 if not IsValid(ent) or not self.classes[ent:GetClass()] then return end
 timer.Simple(0,function()
  if ix.plugin.list.world_persistence == P and not P.restoring then P:Track(ent) end
 end)
end

function P:EntityRemoved(ent)
 if self.restoring or self.cleaning or self.stopping or ix.shuttingDown then return end
 local id = ent.ixWorldPersistenceID
 if id and self.records[id] and self.records[id].entity == ent then
  self.records[id] = nil; self:QueueSave()
 end
end

function P:PhysgunDrop(_,ent) if self:Eligible(ent) then self:Track(ent); self:QueueSave() end end
function P:PreCleanupMap() self:SaveData(); self.cleaning = true end
function P:PostCleanupMap()
 timer.Simple(0,function() if ix.plugin.list.world_persistence == P and P.cleaning then P:LoadData(); P:PostLoadData() end end)
end
function P:ShutDown() self:SaveData(); self.stopping = true end
function P:OnUnload()
 self:SaveData();self.stopping=true;timer.Remove("ixWorldEntitiesAutosave");timer.Remove("ixWorldEntitiesSave")
 if ix.runtime then ix.runtime.Cancel("world.entities.save") end
end
-- Capture a bounded portion per frame; an explicit edit or shutdown still
-- captures and commits immediately. Removed records cannot re-enter the save.
function P:AutosaveStep()
 if not self.loaded or self.restoring or self.cleaning or self.stopping then self.saveQueue=nil;return end
 if not self.saveQueue then
  self.saveQueue={};for id in pairs(self.records) do self.saveQueue[#self.saveQueue+1]=id end
  self.saveCursor=1
 end
 local count=0
 while self.saveCursor<=#self.saveQueue and count<8 do
  local id=self.saveQueue[self.saveCursor];local record=self.records[id]
  if record and self:Eligible(record.entity) then record.data=self:Capture(record.entity,id) end
  self.saveCursor=self.saveCursor+1;count=count+1
 end
 if self.saveCursor<=#self.saveQueue then return false end
 self.saveQueue=nil;self:SaveData(true,true)
end
function P:InstallMaintenance()
 if ix.runtime and ix.runtime.active then
  ix.runtime.Schedule("world.entities.save",30,function() return P:AutosaveStep() end)
  self.runtimeScheduled=true
 end
end
timer.Create("ixWorldEntitiesAutosave",30,0,function()
 if ix.plugin.list.world_persistence == P and not P.stopping then
  if ix.runtime and ix.runtime.active then if not P.runtimeScheduled or not ix.runtime.jobs["world.entities.save"] then P:InstallMaintenance() end
  else P.runtimeScheduled=nil;P:SaveData(true) end
 end
end)
