local PLUGIN = PLUGIN

function PLUGIN:CreateMenuButtons(tabs)
	tabs["СОЗДАНИЕ ВЕЩЕЙ"] = function(container)
		local x = container:Add("ui.craft")
		x:Setup()
	end
end

ix.Craft:LoadFromDir(PLUGIN.folder.."/recipes", "recipe")
ix.Craft:LoadFromDir(PLUGIN.folder.."/stations", "station")

function PLUGIN:LoadData()
	timer.Simple(1, function()
    	self:LoadStations()
    end)
end

function PLUGIN:SaveData()
	self:SaveStations()
end

function PLUGIN:LoadStations()
	local data = self:GetData()

	-- Записи, которые НЕ удалось воссоздать (класс станции не зарегистрирован).
	-- Их нельзя просто забыть: SaveStations строит список из ents.FindByClass,
	-- поэтому невоссозданные станции иначе исчезли бы из сохранения навсегда.
	self.unloadedStations = {}

	if !istable(data) then
		return
	end

	local missing = {}

	for _, v in ipairs(data) do
		local uniqueID = tostring(v[1] or "")
		local class = "ix_station_"..uniqueID

		-- ВАЖНО: для незарегистрированного класса ents.Create возвращает NULL,
		-- а НЕ nil — старая проверка `if entity then` его пропускала, и первый же
		-- entity:SetPos обрывал ВЕСЬ цикл ошибкой. Из-за одной потерянной станции
		-- переставали появляться и все следующие по списку. Классы регистрируются
		-- динамически из plugins/*/stations/<uniqueID>.lua, так что после
		-- перезаливки гейммода отсутствующий/переименованный файл — обычное дело.
		if !scripted_ents.Get(class) then
			missing[uniqueID] = (missing[uniqueID] or 0) + 1
			self.unloadedStations[#self.unloadedStations + 1] = v

			continue
		end

		local entity = ents.Create(class)

		if !IsValid(entity) then
			missing[uniqueID] = (missing[uniqueID] or 0) + 1
			self.unloadedStations[#self.unloadedStations + 1] = v

			continue
		end

		entity:SetPos(v[2])
		entity:SetAngles(v[3])
		entity:Spawn()
		entity:LoadItems(v[4] or {})

		local physObject = entity:GetPhysicsObject()

		if IsValid(physObject) then
			physObject:EnableMotion(false)
		end
	end

	for uniqueID, count in pairs(missing) do
		ErrorNoHalt(Format(
			"[ixcraft] Класс 'ix_station_%s' не зарегистрирован — не заспавнено станций: %d. "..
			"Проверьте файл plugins/*/stations/%s.lua. Позиции сохранены и восстановятся сами.\n",
			uniqueID, count, uniqueID
		))
	end
end

function PLUGIN:SaveStations()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_station_*")) do
		local items = {}

		if v.inventory then
			for z, x in pairs(v.inventory:GetItems() or {}) do
				x:Save()
			end

			items = v.inventory:GetItemsID()
		end

		data[#data + 1] = {
			v.uniqueID,
			v:GetPos(),
			v:GetAngles(),
			items
		}
	end

	-- Возвращаем в сохранение станции, которые не удалось воссоздать при загрузке
	-- (см. LoadStations). Они не существуют в мире, значит FindByClass их не найдёт,
	-- и без этого они были бы стёрты первым же автосохранением — даже при том, что
	-- защита ниже не сработает, ведь список НЕ пустой. Когда файл станции вернётся
	-- на место, они снова заспавнятся на своих местах.
	for _, v in ipairs(self.unloadedStations or {}) do
		data[#data + 1] = v
	end

	-- ЗАЩИТА ОТ СТИРАНИЯ: если сейчас в мире НЕТ ни одной станции (ix_station_*),
	-- но в сохранении они ЕСТЬ — значит LoadStations ещё не отработал или сущности
	-- ix_station_<type> не успели зарегистрироваться (частый случай после перезалива
	-- файлов гейммода). НЕ перезаписываем сохранённые позиции пустым списком, иначе
	-- все верстаки теряются навсегда и их приходится расставлять заново.
	-- Пустое сохранение допускаем, только если сохранённых станций тоже не было.
	if (#data == 0) then
		local existing = self:GetData()

		if (istable(existing) and #existing > 0) then
			return
		end
	end

	self:SetData(data)
end