local ItemMedical = class("ItemMedical"):implements("Item")

function ItemMedical:Init()
 self.category = "item.category.medical"
 self.stats = {uses=1, time=10}
 self.functions.use = {
  name="use.medicine",
  OnRun=function(item, items, data)
   return ix.Medicine.Begin(item, item.player, istable(data) and data.limb or 0)
  end,
  OnCanRun=function(item) return not IsValid(item:GetEntity()) and not item.inUse and item:GetUses() > 0 end
 }
 self.functions.inject = {
  name="use.medicineOn",
  OnRun=function(item, items, data)
   local target = istable(data) and data.target or nil
   if not IsValid(target) then target=ix.Medicine.ResolveTarget(item.player) end
   return ix.Medicine.Begin(item, target, istable(data) and data.limb or 0)
  end,
  OnCanRun=function(item)
   return not IsValid(item:GetEntity()) and not item.inUse and item:GetUses() > 0
  end
 }
 self:AddData("uses", {Transmit=ix.transmit.owner})
 self:AddData("volume", {Transmit=ix.transmit.owner})
 self.combine = self.combine or {}
 self.combine.comb = {
  name="combine.medicine",
  OnCanRun=function(item, target)
   return item ~= target and not item.inUse and not target.inUse and item.uniqueID == target.uniqueID and
    item:GetCapacity() > 1 and target:GetUses() < item:GetCapacity() and item:GetUses() > 0
  end,
  OnRun=function(item, target)
   if item.inUse or target.inUse then return false end
   local count=math.min(item:GetUses(), item:GetCapacity()-target:GetUses())
   if count <= 0 then return false end
   target:SetResource(target:GetUses()+count)
   if count >= item:GetUses() then item:Remove(true) else item:SetResource(item:GetUses()-count) end
   return false
  end
 }
end
function ItemMedical:GetCapacity() return ix.Medicine.ResourceCapacity(self) or self.stats.uses or 1 end
function ItemMedical:GetUses()
 if self.uniqueID=="eft_surgery" and self:GetData("volume")~=nil then
  return math.Clamp(math.floor((tonumber(self:GetData("volume")) or 0)/100),0,5)
 end
 local capacity=ix.Medicine.ResourceCapacity(self)
 if capacity then
  local value=self:GetData("volume")
  if value==nil then
   value=capacity*math.Clamp((tonumber(self:GetData("uses", self.stats.uses)) or 0)/(self.stats.uses or 1),0,1)
  end
  return math.Clamp(tonumber(value) or 0,0,capacity)
 end
 return math.Clamp(tonumber(self:GetData("uses", self.stats.uses or 1)) or 0,0,self:GetCapacity())
end
function ItemMedical:SetResource(value)
 if self.uniqueID=="eft_surgery" then self:SetData("volume",nil) end
 self:SetData(ix.Medicine.ResourceCapacity(self) and "volume" or "uses",value)
end
function ItemMedical:GetResourceText()
 return string.format(ix.Medicine.ResourceCapacity(self) and "Запас: %.1f / %d ед." or "Дозы: %.0f / %d",self:GetUses(),self:GetCapacity())
end
function ItemMedical:OnInstanced(isCreated)
 if isCreated then self:SetResource(self:GetCapacity()) end
end
function ItemMedical:CanTransfer()
 if self.inUse and IsValid(self.inUse) then return false end
end
if CLIENT then
 function ItemMedical:PopulateTooltip(tooltip)
  local row=tooltip:AddRowAfter("name")
  row:SetText(self:GetResourceText())
  row:SizeToContents()
 end
end
return ItemMedical
