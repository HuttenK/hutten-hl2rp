local PLUGIN = PLUGIN

-- множество «ключевых» дверей: { [tostring(MapCreationID)] = true }
PLUGIN.keyDoors = PLUGIN.keyDoors or {}

-- Немедленно и ИЗОЛИРОВАННО сохранить данные предмета в БД.
-- ITEM:SetData ставит сохранение в пакетную очередь (ix.Item:Async_SaveData),
-- которая выполняется внутри coroutine и ПРЕРЫВАЕТСЯ на первом же предмете, чьё
-- SaveData бросает ошибку (sv_mysql RawQuery делает error() при сбое SQL/колбэка);
-- ошибка глотается coroutine.resume, остаток пакета (в произвольном порядке pairs)
-- не сохраняется, items_to_savedata не очищается. Из-за этого часть привязок
-- ключей (data.doors) не доходила до sv.db и терялась после рестарта, хотя
-- сторона двери (keyDoors, отдельная txt-запись) сохранялась всегда.
-- Прямой вызов пишет ТОЛЬКО этот предмет и не зависит от чужих предметов.
function PLUGIN:PersistItemNow(item)
	if SERVER and item and item.SaveData then
		item:SaveData()
	end
end

-- Применить «ключевой» режим к двери: снять владельца/фракцию/класс, очистить
-- доступ и запереть (вместе с партнёром). Не сохраняет данные — это делает
-- вызывающий. Используется и при привязке, и при переприменении после рестарта.
function PLUGIN:ApplyKeyDoor(door)
	if !(IsValid(door) and door.IsDoor and door:IsDoor()) then return end

	door:SetNetVar("ownable", nil)
	door:SetNetVar("faction", nil)
	door:SetNetVar("class", nil)
	door.ixAccess = {}
	door:SetDTEntity(0, nil)

	door:Fire("lock")
	local partner = door.GetDoorPartner and door:GetDoorPartner()
	if IsValid(partner) then partner:Fire("lock") end
end

-- Сделать дверь «ключевой»: больше не покупается/не имеет владельца/фракции,
-- доступ только по физическому ключу. По умолчанию запирается.
function PLUGIN:MakeKeyDoor(door)
	local id = tostring(door:MapCreationID())
	self.keyDoors[id] = true

	self:ApplyKeyDoor(door)

	self:SaveData()
end

-- Переприменить «ключевой» статус ко всем сохранённым дверям. Вызывается после
-- полной загрузки данных сервера, поэтому переопределяет восстановление плагина
-- дверей (которое возвращает дверям обычный режим).
function PLUGIN:ReapplyKeyDoors()
	for id in pairs(self.keyDoors) do
		local door = ents.GetMapCreatedEntity(tonumber(id))
		self:ApplyKeyDoor(door)
	end
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
	-- Нормализуем ключи в строки: util.JSONToTable при загрузке из файла превращает
	-- числовые строковые ключи ("3044") обратно в числа (3044), из-за чего IsKeyDoor
	-- (поиск по tostring) переставал находить дверь после рестарта («keyDoors: нет»).
	local raw = self:GetData() or {}
	self.keyDoors = {}
	for id, v in pairs(raw) do
		if v then self.keyDoors[tostring(id)] = true end
	end
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
	PLUGIN:PersistItemNow(item) -- гарантированная запись (обход сбойной пакетной очереди)
	client:Notify("Предмет переименован: "..(text != "" and text or "(имя сброшено)"))
end)

-- PostLoadData вызывается ПОСЛЕ LoadData всех плагинов (в т.ч. нашего LoadData,
-- заполняющего self.keyDoors, и плагина дверей, восстанавливающего их обычное
-- состояние). Здесь мы гарантированно имеем актуальный self.keyDoors и
-- переопределяем восстановление дверей. Это заменяет ненадёжный таймер в
-- InitPostEntity, который срабатывал раньше асинхронной загрузки данных (MySQL)
-- и оставлял двери непривязанными после рестарта.
function PLUGIN:PostLoadData()
	self:ReapplyKeyDoors()
end
