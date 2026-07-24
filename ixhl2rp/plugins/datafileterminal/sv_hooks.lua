local PLUGIN = PLUGIN

util.AddNetworkString("ixDfBrowserOpen")
util.AddNetworkString("ixDfPdaQuery") -- КПК: открыть досье по введённому CID (как /datafile)
util.AddNetworkString("ixDfPdaClose") -- закрыли меню КПК -> опустить устройство
util.AddNetworkString("ixPdaToggle")  -- клавиша G: включить/выключить КПК

PLUGIN.useRadius = 130
PLUGIN.pdaClass  = "pdaremake1" -- класс SWEP'а КПК (lua/weapons/pdaremake1.lua)

-- Ссылка на плагин досье (старый datafile с PLUGIN.stored / HandleDatafile)
local function df()
	return ix.plugin.list["datafile"]
end

-- Игрок рядом с терминалом досье?
function PLUGIN:IsNearTerminal(client)
	if !IsValid(client) then return false end
	for _, ent in ipairs(ents.FindInSphere(client:GetPos(), self.useRadius)) do
		if IsValid(ent) and ent:GetClass() == "ix_datafile_terminal" then
			return true
		end
	end
	return false
end

-- Есть ли у игрока ПРЕДМЕТ КПК в инвентаре (доступ только при наличии предмета).
function PLUGIN:HasPDAItem(client)
	return IsValid(client) and client.HasItem and client:HasItem("pda") or false
end

-- Держит ли игрок ПОДНЯТЫЙ КПК (сетевой флаг PDAEquipped из SWEP) И имеет предмет.
function PLUGIN:IsHoldingRaisedPDA(client)
	if !self:HasPDAItem(client) then return false end
	local wep = IsValid(client) and client:GetActiveWeapon()
	if !IsValid(wep) or wep:GetClass() != self.pdaClass then return false end
	return (wep.GetPDAEquipped and wep:GetPDAEquipped()) or false
end

-- Включить КПК: достаём оружие-вьюмодель и поднимаем (нужен предмет в инвентаре).
function PLUGIN:PdaOn(client)
	if !self:HasPDAItem(client) then
		client:Notify("Нужен КПК в инвентаре.")
		return
	end

	local wep = client:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == self.pdaClass then return end -- уже включён

	client.ixPdaPrev = IsValid(wep) and wep:GetClass() or nil

	if !client:HasWeapon(self.pdaClass) then client:Give(self.pdaClass) end
	client:SelectWeapon(self.pdaClass)

	-- Поднимаем как можно раньше (короткая задержка только чтобы Deploy успел
	-- отработать и не сбросил флаг). Меньше задержка = отзывчивее открытие.
	timer.Simple(0.05, function()
		if !IsValid(client) then return end
		local w = client:GetWeapon(self.pdaClass)
		if IsValid(w) and w.CustomEquip then w:CustomEquip(true) end
	end)
end

-- Выключить КПК: опускаем, возвращаем прежнее оружие и убираем оружие-КПК
-- (доступ к устройству снова только через предмет).
function PLUGIN:PdaOff(client)
	local w = client:GetWeapon(self.pdaClass)
	-- Прячем мгновенно (звук + сброс флага), без дёрганой holster-анимации.
	if IsValid(w) then
		w:EmitSound("Stalker2.PDAUnequip")
		if w.SetPDAEquipped then w:SetPDAEquipped(false) end
	end

	timer.Simple(0.1, function()
		if !IsValid(client) then return end
		local prev = client.ixPdaPrev
		if prev and prev != "" and client:HasWeapon(prev) then
			client:SelectWeapon(prev)
		end
		timer.Simple(0.1, function()
			if IsValid(client) and client:HasWeapon(self.pdaClass) then
				client:StripWeapon(self.pdaClass)
			end
		end)
	end)
end

-- Клавиша G (с клиента): переключить КПК.
net.Receive("ixPdaToggle", function(len, client)
	if !IsValid(client) or !client:Alive() then return end
	if (client.ixNextPdaToggle or 0) > CurTime() then return end
	client.ixNextPdaToggle = CurTime() + 0.3

	local wep = client:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == PLUGIN.pdaClass then
		PLUGIN:PdaOff(client)
	else
		PLUGIN:PdaOn(client)
	end
end)

-- Доступ к базе досье: рядом с терминалом ЛИБО поднят КПК.
function PLUGIN:HasDatafileAccess(client)
	return self:IsNearTerminal(client) or self:IsHoldingRaisedPDA(client)
end

-- КПК: игрок ввёл CID -> открываем РЕДАКТИРУЕМОЕ досье ровно как команда /datafile.
net.Receive("ixDfPdaQuery", function(len, client)
	local cid = string.Trim(net.ReadString() or "")

	if !PLUGIN:IsHoldingRaisedPDA(client) then return end
	if (client.ixNextDfPda or 0) > CurTime() then return end
	client.ixNextDfPda = CurTime() + 0.4
	if cid == "" then return end

	-- Переиспользуем логику команды /datafile (поиск по CID/имени + slow-path в БД).
	local cmd = ix.command.list and ix.command.list["datafile"]
	if cmd and cmd.OnRun then
		cmd:OnRun(client, cid)
	else
		-- запасной путь: прямой вызов с CID-таблицей
		local dfp = ix.plugin.list["datafile"]
		if dfp and dfp.HandleDatafile then
			dfp:HandleDatafile(client, {cid})
		end
	end
end)

-- Меню КПК закрыли на клиенте -> полностью убираем устройство (опускаем, возвращаем
-- прежнее оружие, снимаем оружие-КПК).
net.Receive("ixDfPdaClose", function(len, client)
	if IsValid(client) then PLUGIN:PdaOff(client) end
end)

-- Собрать список доступных игроку досье.
-- Возвращает: nil  -> нет доступа вообще (нет карты/прав)
--             {}   -> доступ есть, но подходящих записей нет
--             list -> список таблиц {id, name, cid, status, points}
function PLUGIN:BuildList(client)
	local d = df()
	if !d or !istable(d.stored) then return {} end

	local char = client:GetCharacter()
	if !char then return nil end

	local perm = char:ReturnDatafilePermission() or 0
	if perm <= 0 then return nil end

	local list = {}
	for id, v in pairs(d.stored) do
		if !istable(v) then continue end

		local name = isstring(v[1]) and v[1] or ""
		local cid  = isstring(v[2]) and v[2] or ""

		-- пропускаем полностью пустые записи
		if name == "" and (cid == "" or cid == "000-00") then continue end

		-- права на конкретное досье (уровень его защиты)
		local targetPerm = (d.ReturnPermissionByID and d:ReturnPermissionByID(id)) or 0
		if perm < targetPerm then continue end

		local generic = istable(v[4]) and v[4] or {}

		list[#list + 1] = {
			id     = id,
			name   = name,
			cid    = cid,
			status = generic.status or "Citizen",
			points = generic.points or 0,
		}
	end

	table.sort(list, function(a, b)
		return (a.name or "") < (b.name or "")
	end)

	return list
end

-- ------------------------------------------------------------------
-- Фильтр по фракции владельца досье.
-- В базовом терминале показываем ТОЛЬКО граждан и роли ССД (CWU + медики).
-- Метрополиция (группа COMBINE), OTA/EOW (группа OTA) и администрация
-- (без группы) в список не выводятся. datafileID == character:GetID().
-- ------------------------------------------------------------------
local function IsFactionAllowed(factionIndex)
	-- Неизвестная фракция (осиротевшая/легаси запись без строки в ix_characters)
	-- — показываем: почти всегда это старые гражданские досье, не Комбайн.
	if !factionIndex then return true end
	if factionIndex == FACTION_CITIZEN then return true end
	return Schema:GetFactionGroup(factionIndex) == FACTION_GROUP_CWU
end

-- Приводит значение колонки faction (uniqueID-строка, иногда число) к индексу фракции.
local function FactionIndexFromRaw(raw)
	if raw == nil then return nil end
	if isnumber(raw) then return ix.faction.indices[raw] and raw or nil end
	local n = tonumber(raw)
	if n and ix.faction.indices[n] then return n end
	local f = ix.faction.teams[tostring(raw)]
	return f and f.index or nil
end

-- Резолвим фракции: онлайн — сразу с персонажа, оффлайн — одним запросом к ix_characters.
-- cb(filteredList) вызывается всегда.
function PLUGIN:FilterByFaction(list, cb)
	local factionByID = {}
	for _, p in ipairs(player.GetAll()) do
		local c = p:GetCharacter()
		if c then factionByID[c:GetID()] = c:GetFaction() end
	end

	local offline = {}
	for _, e in ipairs(list) do
		if factionByID[e.id] == nil then offline[#offline + 1] = e.id end
	end

	local function finish()
		local out = {}
		for _, e in ipairs(list) do
			if IsFactionAllowed(factionByID[e.id]) then out[#out + 1] = e end
		end
		cb(out)
	end

	if #offline == 0 then finish() return end

	local q = mysql:Select("ix_characters")
		q:Select("id")
		q:Select("faction")
		q:WhereIn("id", offline)
		q:Callback(function(rows)
			if istable(rows) then
				for _, row in ipairs(rows) do
					factionByID[tonumber(row.id)] = FactionIndexFromRaw(row.faction)
				end
			end
			finish()
		end)
	q:Execute()
end

-- Вызывается из ENT:Use
function PLUGIN:OpenBrowser(client, terminal)
	local list = self:BuildList(client)

	if list == nil then
		client:Notify("Нет доступа: требуется CID-карта с правом на досье.")
		return
	end

	self:FilterByFaction(list, function(filtered)
		if !IsValid(client) then return end

		if #filtered == 0 then
			client:Notify("База данных досье пуста.")
			return
		end

		netstream.Start(client, "ixDfBrowserOpen", filtered)
	end)
end

-- Внешность владельца (модель/скин/физописание). Асинхронно: для оффлайн-персонажей
-- модель берётся напрямую из ix_characters, поэтому Кляйнер больше не подставляется.
-- cb(model, skin, genetic) вызывается всегда.
local function ResolveAppearance(id, cb)
	-- Снимок с впечатанной карты (модель/скин/готовый текст физописания).
	-- Физописание берём ТОЛЬКО отсюда: генетика других игроков не сетится
	-- наблюдателю, поэтому клиент не может построить её сам (в отличие от
	-- лоялист-терминала, который читает СВОЮ карту). Источник — впечатывание,
	-- которое теперь выполняется автоматически при первом спавне персонажа.
	local cModel, cSkin, cGenetic = "", 0, ""
	for _, item in pairs(ix.Item.instances) do
		if item.GetData and tonumber(item:GetData("datafileID")) == id then
			cModel   = item:GetData("charModel", "") or ""
			cSkin    = item:GetData("charSkin", 0) or 0
			cGenetic = item:GetData("charGenetic", "") or ""
			break
		end
	end

	-- 1. Онлайн-владелец — живая ОРИГИНАЛЬНАЯ модель (форма не учитывается),
	--    физописание — с карты (cGenetic).
	for _, p in ipairs(player.GetAll()) do
		local c = p:GetCharacter()
		if c and c:GetID() == id then
			-- Всегда берём БАЗОВУЮ модель персонажа, а не текущую. Форма/костюм/форма МП
			-- подменяют модель ИГРОКА (client:SetModel) и char_outfit.model, но
			-- character:GetModel() остаётся исходной моделью из карт-генерации. Так в
			-- терминале показывается изначальная модель без бодигрупп и костюмов.
			local model = c:GetModel() or cModel or ""
			local skin  = c:GetData("skin", 0) or cSkin or 0
			cb(model, skin, cGenetic)
			return
		end
	end

	-- 3. Оффлайн — модель/скин персонажа напрямую из БД (id == datafileID)
	local q = mysql:Select("ix_characters")
		q:Select("model")
		q:Select("data")
		q:Where("id", id)
		q:Limit(1)
		q:Callback(function(rows)
			local model, skin = cModel, cSkin
			if istable(rows) and istable(rows[1]) then
				local row = rows[1]
				if isstring(row.model) and row.model != "" then
					model = row.model
				end
				local d = row.data and util.JSONToTable(row.data)
				if istable(d) and d.skin != nil then
					skin = tonumber(d.skin) or skin
				end
			end
			cb(model, skin, cGenetic)
		end)
	q:Execute()
end

-- Клиент выбрал досье в меню -> собираем полные данные и открываем окно ixDfView
netstream.Hook("ixDfBrowserSelect", function(client, datafileID)
	datafileID = tonumber(datafileID)
	if !datafileID then return end
	if !PLUGIN:HasDatafileAccess(client) then return end

	-- С поднятого КПК открываем РЕДАКТИРУЕМОЕ досье (/datafile -> cwFullDatafile),
	-- где можно добавлять/править записи. Терминал по-прежнему показывает read-only.
	if PLUGIN:IsHoldingRaisedPDA(client) then
		local dfp = ix.plugin.list["datafile"]
		if dfp and dfp.HandleDatafile then
			dfp:HandleDatafile(client, datafileID)
		end
		return
	end

	local d = df()
	if !d or !istable(d.stored) then return end

	local char = client:GetCharacter()
	if !char then return end

	local perm = char:ReturnDatafilePermission() or 0
	if perm <= 0 then
		client:Notify("Нет доступа: требуется CID-карта с правом на досье.")
		return
	end

	local v = d.stored[datafileID]
	if !istable(v) then
		client:Notify("Досье не найдено.")
		return
	end

	local targetPerm = (d.ReturnPermissionByID and d:ReturnPermissionByID(datafileID)) or 0
	if perm < targetPerm then
		client:Notify("Недостаточно прав для просмотра этого досье.")
		return
	end

	local generic = istable(v[4]) and v[4] or {}
	local records = istable(v[5]) and v[5] or {}

	-- Записи; для MINOR (1) скрываем гражданские записи
	local outRecords = {}
	for _, rec in ipairs(records) do
		if !istable(rec) then continue end
		if perm == 1 and rec.category == "civil" then continue end
		outRecords[#outRecords + 1] = {
			category    = rec.category,
			text        = rec.text,
			unix_time   = rec.unix_time or rec.date,
			points      = rec.points or 0,
			poster_name = rec.poster_name,
		}
	end

	ResolveAppearance(datafileID, function(model, skin, genetic)
		if !IsValid(client) then return end

		netstream.Start(client, "ixDfView", {
			id         = datafileID,
			name       = v[1] or "",
			cid        = v[2] or "",
			regid      = v[3] or "",
			status     = generic.status or "Citizen",
			points     = generic.points or 0,
			bol        = generic.bol and true or false,
			bolReason  = generic.bol_reason or "",
			restricted = generic.restricted and true or false,
			lastSeen   = generic.last_seen or 0,
			aparts     = generic.aparts or "N/A",
			model      = model,
			skin       = skin,
			genetic    = genetic,
			ownerCharID = datafileID,
			records    = outRecords,
		})
	end)
end)

-- Сохранение/загрузка размещённых терминалов между рестартами карты
function PLUGIN:SaveData()
	local data = {}
	for _, v in ipairs(ents.FindByClass("ix_datafile_terminal")) do
		data[#data + 1] = { v:GetPos(), v:GetAngles() }
	end
	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if !istable(data) then return end

	for _, v in ipairs(data) do
		local ent = ents.Create("ix_datafile_terminal")
		if !IsValid(ent) then continue end
		ent:SetPos(v[1])
		ent:SetAngles(v[2])
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end
end
