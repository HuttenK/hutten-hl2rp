local PLUGIN = PLUGIN

-- множество «ключевых» дверей: { [tostring(MapCreationID)] = true }
PLUGIN.keyDoors = PLUGIN.keyDoors or {}

-- Сделать дверь «ключевой»: больше не покупается/не имеет владельца/фракции,
-- доступ только по физическому ключу. По умолчанию запирается.
function PLUGIN:MakeKeyDoor(door)
	local id = tostring(door:MapCreationID())
	self.keyDoors[id] = true

	door:SetNetVar("ownable", nil)
	door:SetNetVar("faction", nil)
	door:SetNetVar("class", nil)
	door.ixAccess = {}
	door:SetDTEntity(0, nil)

	door:Fire("lock")
	local partner = door.GetDoorPartner and door:GetDoorPartner()
	if IsValid(partner) then partner:Fire("lock") end

	self:SaveData()
end

-- Вернуть дверь в обычный режим
function PLUGIN:UnmakeKeyDoor(door)
	self.keyDoors[tostring(door:MapCreationID())] = nil
	door:SetNetVar("ownable", true)
	self:SaveData()
end

function PLUGIN:IsKeyDoor(door)
	return self.keyDoors[tostring(door:MapCreationID())] == true
end

function PLUGIN:SaveData()
	self:SetData(self.keyDoors)
end

function PLUGIN:LoadData()
	self.keyDoors = self:GetData() or {}
end

-- Универсальное переименование предметов (ключи, оружие и т.п.).
-- Безопасно: меняет только заранее заданное поле (item.renameField), только у предмета-владельца.
netstream.Hook("ixItemRename", function(client, itemID, text)
	if !IsValid(client) then return end

	itemID = tonumber(itemID)
	if !itemID then return end

	local item = ix.Item.instances[itemID]
	if !item then
		client:Notify("Переименование: предмет не найден (id "..tostring(itemID)..").")
		return
	end

	if !item.canRename then
		client:Notify("Этот предмет нельзя переименовать.")
		return
	end

	-- Переименование (оружие, ключи и т.п.) — только для администрации.
	if !client:IsAdmin() then
		client:Notify("Переименовывать предметы может только администрация.")
		return
	end

	-- Устойчивая проверка владельца (работает и для обычных, и для класс-предметов)
	if !client:HasItemByID(itemID) then
		client:Notify("Переименовать можно только предмет из своего инвентаря.")
		return
	end

	local field = item.renameField or "customName"
	-- utf8.sub режет по символам (string.sub режет по байтам и ломает кириллицу)
	text = utf8.sub(tostring(text or ""), 1, 32) or ""

	item:SetData(field, text)
	client:Notify("Предмет переименован: "..(text != "" and text or "(имя сброшено)"))
end)

-- После загрузки карты — переприменяем «ключевой» статус (unownable + заперто)
function PLUGIN:InitPostEntity()
	timer.Simple(1, function()
		for id in pairs(self.keyDoors) do
			local door = ents.GetMapCreatedEntity(tonumber(id))
			if IsValid(door) and door:IsDoor() then
				door:SetNetVar("ownable", nil)
				door:Fire("lock")
			end
		end
	end)
end
