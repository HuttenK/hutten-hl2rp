ITEM.name="Силовой кабель"
ITEM.description="Один кабель — одно резервное подключение до 15 м. При blackout соедините генератор или аккумулятор с устройством либо щитком. При свете кабели не нужны. При снятии кабель возвращается."
ITEM.model="models/props_lab/tpplug.mdl"
ITEM.category="Инфраструктура"
ITEM.width=1
ITEM.height=1
ITEM.weight=0.5
ITEM.stackable=false
ITEM.functions=ITEM.functions or {}
ITEM.functions.connect={name="Проложить кабель",icon="icon16/connect.png",
 OnRun=function(item) local p=ix.plugin.list.facility_utilities;if p then p:BeginCable(item.player) end;return false end,
 OnCanRun=function(item) return IsValid(item.player) and not IsValid(item.entity) and not item.player:IsRestricted() end}
ITEM.functions.disconnect={name="Снять подключённый кабель",icon="icon16/disconnect.png",
 OnRun=function(item) local p=ix.plugin.list.facility_utilities;if p then p:BeginCable(item.player,true) end;return false end,
 OnCanRun=ITEM.functions.connect.OnCanRun}
