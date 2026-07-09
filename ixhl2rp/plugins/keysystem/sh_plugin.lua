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
		PLUGIN:PersistItemNow(key) -- немедленная запись, иначе привязка терялась после рестарта

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
		PLUGIN:PersistItemNow(key)
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
		PLUGIN:PersistItemNow(key)
		return "Ключ очищен."
	end
})

ix.command.Add("KeyDebug", {
	description = "Диагностика ключа: показать привязки ключа и ID двери, на которую смотрите.",
	adminOnly = true,
	OnRun = function(self, client)
		local lines = {}

		local key = getPlayerKey(client)
		if key then
			local doors = key:GetData("doors", {})
			local ids = {}
			for id in pairs(doors) do ids[#ids + 1] = id end
			lines[#lines + 1] = "Ключ найден. Привязок: " .. table.Count(doors)
				.. (#ids > 0 and (" [" .. table.concat(ids, ", ") .. "]") or " (пусто)")
		else
			lines[#lines + 1] = "Ключ в инвентаре НЕ найден."
		end

		local door = client:GetEyeTrace().Entity
		if IsValid(door) and door.IsDoor and door:IsDoor() then
			local id = door:MapCreationID()
			local partner = door.GetDoorPartner and door:GetDoorPartner()
			local pid = IsValid(partner) and partner:MapCreationID() or "нет"
			local bound = key and (key:GetData("doors", {})[tostring(id)]
				or (IsValid(partner) and key:GetData("doors", {})[tostring(pid)])) and "ДА" or "нет"
			lines[#lines + 1] = ("Дверь: MapID=%s, партнёр MapID=%s, привязана к ключу: %s")
				:format(tostring(id), tostring(pid), bound)
			lines[#lines + 1] = "Ключевая (keyDoors): " .. (PLUGIN:IsKeyDoor(door) and "ДА" or "нет")
		else
			lines[#lines + 1] = "Вы не смотрите на дверь."
		end

		lines[#lines + 1] = "Всего ключевых дверей загружено: " .. table.Count(PLUGIN.keyDoors)

		for _, l in ipairs(lines) do client:ChatPrint(l) end
		return "Диагностика выведена в чат."
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
