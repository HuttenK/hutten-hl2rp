local PLUGIN = PLUGIN

PLUGIN.name = "Система ключей"
PLUGIN.author = "Claude"
PLUGIN.description = "Физический ключ-предмет, привязываемый к двери(ям). Доступ к ключевым дверям — только по ключу."

ix.util.Include("sv_plugin.lua")

-- Первый ключ-предмет в инвентаре игрока (server-side вызывается из OnRun)
local function getPlayerKey(client)
	local inv = client:GetInventory(client.default_inventory or "main")
	return inv and inv:FindItem("key")
end

ix.command.Add("KeyGive", {
	description = "Выдать себе чистый ключ.",
	adminOnly = true,
	OnRun = function(self, client)
		local instance = ix.Item:Instance("key")
		if instance then
			client:AddItem(instance)
			return "Ключ выдан (проверьте инвентарь)."
		end
		return "Не удалось создать ключ."
	end
})

ix.command.Add("KeyBind", {
	description = "Привязать дверь (на которую смотрите) к ключу в вашем инвентаре.",
	adminOnly = true,
	privilege = "Manage Doors",
	OnRun = function(self, client)
		local door = client:GetEyeTrace().Entity
		if !(IsValid(door) and door.IsDoor and door:IsDoor()) then return "@dNotValid" end

		local key = getPlayerKey(client)
		if !key then return "Нужен ключ в инвентаре (см. /KeyGive)." end

		local id = door:MapCreationID()
		if id == -1 then return "Эта дверь не сохраняется (создана не картой)." end

		local doors = key:GetData("doors", {})
		doors[tostring(id)] = true
		key:SetData("doors", doors)

		PLUGIN:MakeKeyDoor(door)
		return "Дверь привязана к ключу. Теперь она открывается только этим ключом."
	end
})

ix.command.Add("KeyUnbind", {
	description = "Отвязать дверь (на которую смотрите) от ключа в вашем инвентаре.",
	adminOnly = true,
	privilege = "Manage Doors",
	OnRun = function(self, client)
		local door = client:GetEyeTrace().Entity
		if !(IsValid(door) and door.IsDoor and door:IsDoor()) then return "@dNotValid" end

		local key = getPlayerKey(client)
		if !key then return "Нужен ключ в инвентаре." end

		local doors = key:GetData("doors", {})
		doors[tostring(door:MapCreationID())] = nil
		key:SetData("doors", doors)
		return "Дверь отвязана от ключа."
	end
})

ix.command.Add("KeyClear", {
	description = "Стереть все двери у ключа в вашем инвентаре.",
	adminOnly = true,
	OnRun = function(self, client)
		local key = getPlayerKey(client)
		if !key then return "Нужен ключ в инвентаре." end
		key:SetData("doors", {})
		return "Ключ очищен."
	end
})

ix.command.Add("DoorUnkey", {
	description = "Вернуть дверь (на которую смотрите) в обычный режим (не ключевая).",
	adminOnly = true,
	privilege = "Manage Doors",
	OnRun = function(self, client)
		local door = client:GetEyeTrace().Entity
		if !(IsValid(door) and door.IsDoor and door:IsDoor()) then return "@dNotValid" end
		PLUGIN:UnmakeKeyDoor(door)
		return "Дверь снова обычная (можно покупать/запирать как раньше)."
	end
})
