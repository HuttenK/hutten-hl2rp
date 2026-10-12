local P,F=PLUGIN,ix.Facility

-- Use the same hands/physics carry path as ordinary items and cargo crates.
function P:SourceMoveReason(p,d)
 if not d or self.store.devices[d.id]~=d or (d.kind~="generator" and d.kind~="battery") or not IsValid(d.entity) then return "Оборудование недоступно." end
 if not self:GeneratorOperator(p,d) then return "Перенос: владелец или допуск L3." end
 if not F.Near(p,d.entity,110) then return "Подойдите к оборудованию." end
 if IsValid(d.entity:GetParent()) then return "Оборудование закреплено." end
 if IsValid(d.entity.ixHeldOwner) then return "Сначала поставьте оборудование на землю." end
 if d.running then return "Сначала остановите двигатель." end
 if #(d.links or {})>0 or (d.kind=="battery" and self:BatteryConnected(d)) then return "Сначала отсоедините все кабели." end
end

function P:CanPlayerHoldObject(p,e)
 local d=self.store.devices[e.facilityID]
 if not d or d.entity~=e or (d.kind~="generator" and d.kind~="battery") then return end
 return self:SourceMoveReason(p,d)==nil
end

function P:CarrySource(p,d)
 local reason=self:SourceMoveReason(p,d);if reason then return false,reason end
 local e=d.entity;local hands=p:GetWeapon("ix_hands");local physics=e:GetPhysicsObject()
 if not IsValid(hands) or not IsValid(physics) or hands:IsHoldingObject() then return false,"Освободите руки для переноски." end
 p:SelectWeapon("ix_hands")
 if p:GetActiveWeapon()~=hands then return false,"Сначала уберите оружие и выберите руки." end
 -- Old placed sources were frozen and used the model's arbitrary physics mass.
 local moving=physics:IsMoveable();local mass=physics:GetMass()
 physics:SetMass(d.kind=="battery" and 8 or 18);physics:EnableMotion(true)
 if not hands:CanHoldObject(e) then
  physics:SetMass(mass);physics:EnableMotion(moving);return false,"Сейчас нельзя взять оборудование в руки."
 end
 hands:PickupObject(e)
 if hands.heldEntity~=e then physics:SetMass(mass);physics:EnableMotion(moving);return false,"Не удалось взять оборудование." end
 p:SetLocalVar("bIsHoldingObject",true);p:SetLocalVar("holdingObject",e)
 d.dropped=true;physics:Wake();self.dirty=true;self:SaveData()
 return true,"R — поставить на землю."
end

function P:ReleaseSource(p,d)
 if not F.Active(p) or not IsValid(d.entity) then return false end
 local hands=p:GetWeapon("ix_hands")
 if not IsValid(hands) or hands.heldEntity~=d.entity or d.entity.ixHeldOwner~=p then return false,"Вы не держите это оборудование." end
 hands:DropObject();self:SyncDevice(d);self.dirty=true;self:SaveData();return true,"Оборудование поставлено на землю."
end

function P:PortableKind(item)
 if not item then return end
 if item.uniqueID=="facility_generator" then return "generator" end
 if item.uniqueID=="facility_battery" then return "battery" end
end

function P:PortableState(d,item,owner)
 d.portable=true;d.owner=owner;d.running=false;d.links={};d.circuit=0
 local fuel=tonumber(item:GetData("fuel",0))
 d.fuel=F.Number(fuel,0,600) and fuel or 0
 d.fault=item:GetData("fault",false)==true
 local capacity=tonumber(item:GetData("capacity",d.kind=="battery" and 30 or 60))
 d.capacity=F.Number(capacity,1,500) and capacity or (d.kind=="battery" and 30 or 60)
 if d.kind=="battery" then
  local charge=tonumber(item:GetData("charge",6000))
  d.charge=F.Number(charge,0,6000) and charge or 0
 end
end

function P:ConvertDroppedSource(item,original)
 local kind=self:PortableKind(item)
 if not kind or not self.loaded or self.restoring or self.stopping or ix.shuttingDown then return false end
 if not IsValid(original) or item:GetEntity()~=original or original:GetItem()~=item or item.inventory_id or item.facilityConverting
  or ix.Item.instances[item.id]~=item then return false end
 if ix.Inventory and ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers["item_"..item.id] then return false end
 local pos,ang=F.Vector(original:GetPos()),F.Angle(original:GetAngles())
 if not pos or not ang then return false end
 local d=self:DeviceRecord(kind,pos,ang)
 if not d then return false,"Достигнут предел оборудования. Предмет можно забрать и выбросить позже." end
 item.facilityConverting=true
 self:PortableState(d,item,item.facilityDropOwner or original.ixCharID)
 d.dropped=true
 self.store.devices[d.id]=d
 local ent=self:SpawnDevice(d)
 if not IsValid(ent) then
  self.store.devices[d.id]=nil;item.facilityConverting=nil
  return false,"Не удалось создать оборудование. Предмет сохранён."
 end
 local physics=ent:GetPhysicsObject()
 if IsValid(physics) then physics:SetVelocity(original:GetVelocity()) end
 -- The real source now exists. Only then consume the world item, bypassing its
 -- ordinary OnRemove path so the same item cannot survive in two forms.
 original.ixIsSafe=true
 item:Remove(true)
 ix.Item.entities[item.id]=nil
 original:Remove();item:SetEntity(nil)
 item.facilityConverting=nil;item.facilityDropOwner=nil
 self.dirty=true;self:SaveData()
 return true,d
end

function P:QueueDroppedSource(item,original,attempt)
 if not self:PortableKind(item) or not IsValid(original) or original.ixFacilityDropQueued then return end
 original.ixFacilityDropQueued=true
 -- Native item dropping also queues a zero-delay surface-alignment pass. Let
 -- that pass and SetEntity/Sync finish before copying the actual world transform.
 timer.Simple(.1,function()
  if not IsValid(original) then return end
  original.ixFacilityDropQueued=nil
  local current=ix.plugin.list.facility_utilities
  if not current or current.stopping or ix.shuttingDown or item:GetEntity()~=original or item.inventory_id then return end
  if current~=self then current:QueueDroppedSource(item,original);return end
  if not self.loaded or self.restoring then
   if (attempt or 0)<50 then self:QueueDroppedSource(item,original,(attempt or 0)+1) end
   return
  end
  local ok,message=self:ConvertDroppedSource(item,original)
  local owner=item.facilityDropPlayer
  item.facilityDropPlayer=nil
  if not ok and message and IsValid(owner) then owner:Notify(message) end
 end)
end

function P:ConvertExistingSourceItems()
 for _,ent in ipairs(ents.FindByClass("ix_item")) do
  local item=ent:GetItem()
  if self:PortableKind(item) then self:QueueDroppedSource(item,ent) end
 end
end
