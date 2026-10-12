local P,F = PLUGIN,ix.furnish
P.records=P.records or {}; P.sessions={}
for _,name in ipairs({"begin","cancel","place","move","grab","pickup","stop"}) do util.AddNetworkString("furnish."..name) end
local function active(p)
 return IsValid(p) and p:IsPlayer() and p:Alive() and p:GetCharacter() and not p:IsRestricted() and not p:InVehicle()
end
local function finite(n) return isnumber(n) and n==n and math.abs(n)<1000000 end
local function vector(v) return isvector(v) and finite(v.x) and finite(v.y) and finite(v.z) end
local function near(p,e)
 if not active(p) or not IsValid(e) or p:GetShootPos():DistToSqr(e:NearestPoint(p:GetShootPos()))>F.reach^2 then return false end
 local tr=util.TraceLine({start=p:GetShootPos(),endpos=e:WorldSpaceCenter(),filter={p,e},mask=MASK_SOLID})
 return not tr.Hit
end
local function owns(p,e)
 return active(p) and IsValid(e) and e.furnishingID and P.records[e.furnishingID]
  and (p:IsAdmin() or e:GetNetVar("furnOwner")==p:GetCharacter():GetID())
end
local function zone(p,pos)
 if p:IsAdmin() or not ix.config.Get("furnitureAreaOnly",false) then return "",nil end
 local id,info,key=F.FindApartment(pos)
 if not id then return end
 local owner=tonumber(info.properties and info.properties.furnishingOwner) or 0
 if owner~=0 and owner~=p:GetCharacter():GetID() then return end
 if hook.Run("CanFurnishAt",p,pos,info)==false then return end
 return key,F.ApartmentAreas(key)
end
function P:EndFurnish(p)
 self.sessions[p]=nil
 if IsValid(p) then net.Start("furnish.stop");net.Send(p) end
end
function P:BeginFurnish(p,item,e)
 if not active(p) then return false end
 if item and (item.factionLock and not item.factionLock[p:Team()] or not F.Supported(item) or item:GetOwner()~=p or IsValid(item:GetEntity())) then return false end
 if e and not (owns(p,e) and near(p,e)) then return false end
 if self.loading then return false end
 local home=zone(p,IsValid(e) and e:GetPos() or p:GetPos())
 if home==nil then p:Notify("Войдите в разрешённую зону обустройства.");return false end
 self.sessions[p]={item=item and item.id,character=p:GetCharacter():GetID(),expires=CurTime()+180}
 net.Start("furnish.begin")
 net.WriteUInt(item and FURNISH_MODE_PLACE or FURNISH_MODE_EDIT,2)
 net.WriteString(item and item.preview_model or "")
 net.WriteUInt(item and item.id or 0,32);net.WriteString(home)
 net.WriteBool(p:IsAdmin() or not ix.config.Get("furnitureAreaOnly",false));net.WriteEntity(e or NULL)
 net.Send(p);return true
end
function F.BeginPlace(p,item) return P:BeginFurnish(p,item) end
function F.BeginEdit(p) return P:BeginFurnish(p) end
function P:ValidSession(p)
 local s=self.sessions[p]
 return active(p) and s and s.character==p:GetCharacter():GetID() and s.expires>CurTime() and s
end
function P:CheckFurniture(p,model,pos,ang,existing)
 if not util.IsValidModel(model) or not vector(pos) or not isangle(ang) or not finite(ang.y) or not finite(ang.p) or not finite(ang.r)
  or math.abs(ang.p)>.01 or math.abs(ang.r)>.01 or not util.IsInWorld(pos) or p:GetShootPos():DistToSqr(pos)>F.reach^2 then return false end
 local home,areas=zone(p,pos);if home==nil or hook.Run("CanFurnishAt",p,pos)==false then return false end
 local trace=util.TraceLine({start=p:GetShootPos(),endpos=pos+Vector(0,0,4),filter={p,existing},mask=MASK_SOLID})
 if trace.Hit and trace.HitPos:DistToSqr(pos)>100 then return false end
 local probe=ents.Create("prop_physics");if not IsValid(probe) then return false end
 probe:SetModel(model);local low,high=probe:GetModelBounds();probe:Remove()
 if not vector(low) or not vector(high) then return false end
 local _,ok=F.Evaluate(low,high,pos,Angle(0,ang.y,0),areas,{p,existing})
 return ok,home
end
function P:QueueFurnitureSave()
 if self.loading or self.cleaningMap or ix.shuttingDown then return end
 timer.Create("ixFurnishingSave",.2,1,function() self:SaveData() end)
end
function P:CloseFurnitureStorage(record)
 local inv=record.storage;if not inv then return end
 local pending={}
 for id,transfer in pairs(ix.Inventory.pendingTransfers or {}) do
  if istable(transfer) and (transfer.from_id==inv.id or transfer.to_id==inv.id) then pending[#pending+1]=id end
 end
 for _,id in ipairs(pending) do ix.Inventory:CancelTransfer(id) end
 for _,p in pairs(inv:GetReceivers()) do
  if IsValid(p) and p.ixOpenStorage==inv then
   net.Start("ixStorageExpired");net.WriteUInt(inv.id,32);net.Send(p);ix.storage.RemoveReceiver(p,inv)
  end
 end
 ix.storage.RemoveContext(inv)
end
function P:RestoreFurnitureContents(record)
 local inv=record.storage
 if not inv or record.loadingContents then return end
 local ids=record.unplacedContents or record.contents or {}
 if #ids==0 then return end
 record.loadingContents=true;record.unplacedContents=table.Copy(ids)
 local unresolved={};for _,id in ipairs(ids) do unresolved[id]=true end
 local missing={}
 local function place(item)
  -- LoadInstanceByID mutates native instances: reuse live items without loading them again.
  -- A legacy generic container is migrated only while its saved record has no stable type.
  if item.inventory_id==inv.id then unresolved[item.id]=nil;return end
  if item.inventory_id or (item.inventory_type~=inv.type and not (not record.storageType and item.inventory_type=="container")) then
   unresolved[item.id]=nil;return
  end
  if inv:AddItem(item,item.x,item.y,nil,true) or inv:AddItem(item,nil,nil,nil,true) then
   item:Save();unresolved[item.id]=nil
  end
 end
 local function complete()
  record.loadingContents=nil;record.unplacedContents={}
  for _,id in ipairs(ids) do if unresolved[id] then record.unplacedContents[#record.unplacedContents+1]=id end end
  -- Keep the legacy migration marker until unresolved rows have actually been read.
  if #record.unplacedContents==0 then record.storageType=inv.type end
  self:QueueFurnitureSave()
 end
 for _,id in ipairs(ids) do
  local item=ix.Item.instances[id]
  if item then place(item) else missing[#missing+1]=id end
 end
 if #missing>0 then ix.Item:LoadInstanceByID(missing,place,complete) else complete() end
end
function P:SpawnFurniture(record,item)
 if IsValid(record.entity) then return record.entity end
 if not util.IsValidModel(record.model) then return end
 local definition=ix.container and ix.container.stored[string.lower(record.model)]
 local e=ents.Create(definition and "ix_container" or "prop_physics")
 if not IsValid(e) then return end
 e.furnishingID=record.id;e:SetModel(record.model);e:SetPos(record.pos);e:SetAngles(record.ang);e:Spawn()
 if not IsValid(e) then return end
 e:SetNetVar("furnOwner",record.owner);e:SetNetVar("furnApt",record.home or "");e:SetNetVar("owner",record.owner)
 local phys=e:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
 if definition then
  if record.storage then record.storage.owner=e;e:SetInventory(record.storage) else e:CreateInventory(definition);record.unplacedContents=nil end
  record.storage=e:GetInventory();record.storage.type="furnishing_"..record.id;record.storage.furnishingRecord=record
  e:SetMoney(record.money or 0)
  if record.displayName then e:SetDisplayName(record.displayName) end
  if record.password then e.password=record.password;e:SetLocked(true);e.Sessions={};e.PasswordAttempts={} end
  self:RestoreFurnitureContents(record)
 end
 record.entity=e;item:SetEntity(e);return e
end
function P:PlaceFurniture(p,id,pos,ang)
 local s=self:ValidSession(p);local item=ix.Item.instances[id]
 if not s or s.item~=id or not F.Supported(item) or (item.factionLock and not item.factionLock[p:Team()]) or item:GetOwner()~=p or IsValid(item:GetEntity()) then return false end
 if ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers['item_'..id] then return false end
 local count=0;for _,r in pairs(self.records) do if r.owner==s.character then count=count+1 end end
 if not p:IsAdmin() and count>=ix.config.Get("furnitureLimit",40) then p:Notify("Достигнут предел мебели.");return false end
 local ok,home=self:CheckFurniture(p,item.preview_model,pos,ang)
 if not ok then p:Notify("Нужно свободное место на полу в пределах досягаемости.");return false end
 local inventory=ix.Inventory:Get(item.inventory_id);if not inventory then return false end
 local record={id=id,uniqueID=item.uniqueID,model=item.preview_model,pos=pos,ang=Angle(0,ang.y,0),home=home,owner=s.character}
 record.storageType="furnishing_"..id
 if not self:SpawnFurniture(record,item) then p:Notify("Модель недоступна.");return false end
 if not inventory:TakeItemTable(item) then item:SetEntity(nil);record.entity.ixIsSafe=true;record.entity:Remove();return false end
 inventory:Sync()
 -- Retain the original instance and data; it cannot also load into a character inventory.
 item.inventory_type="furnishing";item.character_id=0;item.player_id=0;item:Save()
 self.records[id]=record;self:EndFurnish(p);self:SaveData()
 hook.Run("FurniturePlaced",p,record.entity,item);return true
end
function P:MoveFurniture(p,e,pos,ang)
 local s=self:ValidSession(p)
 if not s or s.item or not owns(p,e) or not near(p,e) then return false end
 local ok,home=self:CheckFurniture(p,e:GetModel(),pos,ang,e)
 if not ok then p:Notify("Мебель не помещается в выбранном месте.");return false end
 e:SetPos(pos);e:SetAngles(Angle(0,ang.y,0));local phys=e:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
 local r=self.records[e.furnishingID];r.pos=pos;r.ang=e:GetAngles();r.home=home;e:SetNetVar("furnApt",home)
 self:SaveData();return true
end
function P:PackFurniture(p,e)
 if not owns(p,e) or not near(p,e) then return false end
 local record=self.records[e.furnishingID];if record.busy then return false end
 local item=ix.Item.instances[record.id];local inv=p:GetInventory("main")
 if not item or item.inventory_id or not inv or record.loadingContents or #(record.unplacedContents or {})>0 then return false end
 local storage=e.GetInventory and e:GetInventory()
 for _,transfer in pairs(ix.Inventory.pendingTransfers or {}) do
  if istable(transfer) and storage and (transfer.from_id==storage.id or transfer.to_id==storage.id) then return false end
 end
 if storage and storage.receivers and next(storage.receivers) then p:Notify("Сначала закройте хранилище.");return false end
 if hook.Run("CanTransferItem",item,inv,nil,nil,nil)==false then return false end
 if (storage and #storage:GetItemsID()>0) or (e.GetMoney and e:GetMoney()>0) or #e:GetChildren()>0 then
  p:Notify("Опустошите хранилище и снимите прикреплённое оборудование.");return false
 end
 record.busy=true
 local ok=inv:AddItem(item)
 if not ok then record.busy=nil;p:Notify("В инвентаре недостаточно места.");return false end
 item:SetEntity(nil);item.character_id=p:GetCharacter():GetID();item:Save();inv:Sync()
 self.records[record.id]=nil;if storage then ix.Inventory.stored[storage.id]=nil end;e.ixIsSafe=true;e:Remove();self:EndFurnish(p);self:SaveData();return true
end
function P:SaveData()
 if self.loading then return end
 local rows={}
 for _,r in pairs(self.records) do
  local e=r.entity
  if IsValid(e) then
   r.pos=e:GetPos();r.ang=e:GetAngles()
   if e.GetInventory then r.money=e:GetMoney();r.password=e.password;r.displayName=e:GetDisplayName() end
  end
  local inv=r.storage
  if inv and not r.loadingContents then
   r.contents=inv:GetItemsID();local seen={};for _,id in ipairs(r.contents) do seen[id]=true end
   for _,id in ipairs(r.unplacedContents or {}) do if not seen[id] then r.contents[#r.contents+1]=id;seen[id]=true end end
   for _,item in ipairs(inv:GetItems()) do item:Save() end
  end
  local copy={}
  for k,v in pairs(r) do if k~="entity" and k~="storage" and k~="busy" and k~="loadingContents" and k~="loadingItem" then copy[k]=v end end
  rows[#rows+1]=copy
 end
 self:SetData(rows)
end
function P:LoadData()
 if self.loading then return end
 self.records=self.records or {};self.loading=true
 local pending=1;local seen={}
 for _,r in ipairs(self:GetData({})) do
  if isnumber(r.id) and not self.records[r.id] and not seen[r.id] and isstring(r.model) and vector(r.pos) and isangle(r.ang) then
   seen[r.id]=true;pending=pending+1;self.records[r.id]=r
   local function restore(item)
    if item.inventory_id or item.inventory_type~="furnishing" then self.records[r.id]=nil;return end
    if F.Supported(item) then self:SpawnFurniture(r,item) end
   end
   local function complete() pending=pending-1;if pending==0 then self.loading=false end end
   local item=ix.Item.instances[r.id]
   if item then restore(item);complete() else ix.Item:LoadInstanceByID(r.id,restore,complete) end
  end
 end
 pending=pending-1;if pending==0 then self.loading=false end
end
function P:EntityRemoved(e)
 local id=e.furnishingID
 if not id or not self.records[id] or ix.shuttingDown or self.cleaningMap then return end
 local record=self.records[id];self:CloseFurnitureStorage(record)
 local inv=record.storage
 if inv and (record.loadingContents or #(record.unplacedContents or {})>0 or #inv:GetItemsID()>0 or e:GetMoney()>0) then
  -- An entity removal must not strand its inventory, including an in-flight SQL restore.
  record.money=e:GetMoney();record.password=e.password;record.displayName=e:GetDisplayName()
  record.pos=e:GetPos();record.ang=e:GetAngles()
  record.entity=nil
  timer.Simple(0,function()
   local item=ix.Item.instances[id]
   if self.records[id]==record and item then self:SpawnFurniture(record,item);self:SaveData() end
  end)
  self:SaveData();return
 end
 self.records[id]=nil
 if inv then ix.Inventory.stored[inv.id]=nil end
 local item=ix.Item.instances[id];if item and not item.inventory_id then item:SetEntity(nil);item:Remove(true) end
 self:SaveData()
end
function P:PreCleanupMap()
 self:SaveData();self.cleaningMap=true
 for _,r in pairs(self.records) do self:CloseFurnitureStorage(r);if IsValid(r.entity) then r.entity.ixIsSafe=true end end
end
function P:InventoryItemAdded(old,inventory,item)
 if inventory.furnishingRecord or (old and old.furnishingRecord) then item:Save();self:QueueFurnitureSave() end
end
function P:InventoryItemRemoved(inventory,item)
 if inventory.furnishingRecord then self:QueueFurnitureSave() end
end
function P:CanTransferItem(item,target,x,y,source)
 for _,inv in pairs({target,source}) do
  local r=inv.furnishingRecord
  if r and (r.loadingContents or self.cleaningMap or not IsValid(r.entity)) then return false,"storageInUse" end
 end
end
function P:CanMoveItem(item,inventory)
 local r=inventory.furnishingRecord
 if r and (r.loadingContents or self.cleaningMap or not IsValid(r.entity)) then return false,"storageInUse" end
 if r then self:QueueFurnitureSave() end
end
concommand.Add("ix_furnishing_recover",function(p,_,args)
 if not IsValid(p) or not p:IsAdmin() then return end
 local e=p:GetEyeTrace().Entity;local r=P.records[tonumber(args and args[1])] or (IsValid(e) and P.records[e.furnishingID])
 if not r or r.loadingItem then return end
 if IsValid(r.entity) then P:RestoreFurnitureContents(r);return end
 local function restore(item)
  if item.inventory_id or item.inventory_type~="furnishing" or not F.Supported(item) then return end
  P:SpawnFurniture(r,item);P:QueueFurnitureSave()
 end
 local item=ix.Item.instances[r.id]
 if item then restore(item) else
  r.loadingItem=true;ix.Item:LoadInstanceByID(r.id,restore,function() r.loadingItem=nil end)
 end
end)
function P:PostCleanupMap()
 self.cleaningMap=nil
 for _,r in pairs(self.records) do local item=ix.Item.instances[r.id];if item then self:SpawnFurniture(r,item) end end
end
function P:Think()
 if (self.nextSessionCheck or 0)>CurTime() then return end;self.nextSessionCheck=CurTime()+1
 for p in pairs(self.sessions) do if not self:ValidSession(p) then self:EndFurnish(p) end end
end
function P:PlayerDeath(p) self:EndFurnish(p) end
function P:PlayerDisconnected(p) self.sessions[p]=nil end
function P:PlayerLoadedCharacter(p) self:EndFurnish(p) end
function P:PhysgunPickup(p,e) if e.furnishingID and not p:IsAdmin() then return false end end
local function receive(name,maxbits,fn)
 net.Receive("furnish."..name,function(length,p)
  if length>maxbits or not active(p) or (p.ixFurnishRequest or 0)>CurTime() then return end
  p.ixFurnishRequest=CurTime()+.15;fn(p)
 end)
end
receive("cancel",8,function(p) P:EndFurnish(p) end)
receive("place",256,function(p) P:PlaceFurniture(p,net.ReadUInt(32),net.ReadVector(),net.ReadAngle()) end)
receive("move",256,function(p) P:MoveFurniture(p,net.ReadEntity(),net.ReadVector(),net.ReadAngle()) end)
receive("grab",32,function(p) P:BeginFurnish(p,nil,net.ReadEntity()) end)
receive("pickup",32,function(p) P:PackFurniture(p,net.ReadEntity()) end)
