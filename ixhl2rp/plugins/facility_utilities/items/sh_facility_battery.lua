ITEM.name="Переносной аккумулятор"
ITEM.description="Выбросите из инвентаря — аккумулятор сразу готов к использованию. При blackout подключите кабель к устройству или щитку. При свете заряжается от местной сети без кабеля; в темноте — по кабелю от генератора. Заряд сохраняется при переноске."
ITEM.model="models/items/car_battery01.mdl"
ITEM.category="Инфраструктура"
ITEM.width=2
ITEM.height=2
ITEM.weight=8
ITEM.stackable=false
for _,key in ipairs({"charge","fault","circuit","capacity"}) do ITEM:AddData(key,{Transmit=ix.transmit.owner}) end
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
