ITEM.name="Переносной генератор"
ITEM.description="Выбросите из инвентаря — генератор сразу готов к использованию. E: заправить, запустить или подключить кабель для резерва при blackout."
ITEM.model="models/props_se/junk/mobile_generator.mdl"
ITEM.category="Инфраструктура"
ITEM.width=3
ITEM.height=3
ITEM.weight=18
ITEM.stackable=false
ITEM:AddData("fuel",{Transmit=ix.transmit.owner})
ITEM:AddData("fault",{Transmit=ix.transmit.owner})
ITEM:AddData("capacity",{Transmit=ix.transmit.owner})
-- The standard inventory Drop action produces working equipment automatically.
ITEM.functions=ITEM.functions or {}
ITEM.functions.place=nil
function ITEM:OnDrop(client)
 self.facilityDropOwner=IsValid(client) and client:GetCharacter() and client:GetCharacter():GetID() or nil
 self.facilityDropPlayer=client
end
function ITEM:OnEntityCreated(entity)
 if not SERVER then return end
 local plugin=ix.plugin.list.facility_utilities
 if plugin then plugin:QueueDroppedSource(self,entity) end
end
