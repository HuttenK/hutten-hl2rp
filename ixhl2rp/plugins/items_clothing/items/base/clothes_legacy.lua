local Clothing = class("ItemClothLegacy")
implements("ItemEquipable", "ItemClothLegacy")
Clothing = ix.meta.ItemClothLegacy
Clothing.category = "item.category.clothing"
function Clothing:IsEquipped() return self.inventory_type=="main" and self:GetData("equip")==true end
function Clothing:Init()
 ix.meta.ItemEquipable.Init(self)
 self:AddData("equip", {Transmit=ix.transmit.owner, Write=function(_,v) net.WriteBool(v) end, Read=function() return net.ReadBool() end})
 self.functions.equip={OnRun=function(item) item:Equip(item.player,true);item:SetData("equip",true);return false end,
  OnCanRun=function(item) return not item:GetEntity() and IsValid(item.player) and not item:IsEquipped() end}
 self.functions.unequip={OnRun=function(item) item:Equip(item.player,false);item:SetData("equip",false);return false end,
  OnCanRun=function(item) return not item:GetEntity() and IsValid(item.player) and item:IsEquipped() end}
end
function Clothing:OnEquipped(client) client.char_outfit:AddItem(self,false,{});client.char_outfit:Update() end
function Clothing:OnUnequipped(client) client.char_outfit:RemoveItem(self);client.char_outfit:Update() end
return Clothing
