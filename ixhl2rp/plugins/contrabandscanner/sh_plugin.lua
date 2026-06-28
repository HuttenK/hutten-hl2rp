local PLUGIN = PLUGIN

PLUGIN.name = "Сканер контрабанды"
PLUGIN.author = "Claude"
PLUGIN.description = "Арка-сканер настраиваемого размера: подаёт тревогу, если у проходящего есть запрещённые предметы."

-- Параметры по умолчанию для новых сканеров (юниты Source).
PLUGIN.defaults = {
	width  = 80,  -- ширина проёма (ось «лево-право» относительно лица установщика)
	height = 86,  -- высота арки (снизу вверх)
	depth  = 28,  -- толщина зоны срабатывания (вдоль прохода)

	alarmTime    = 4,    -- секунд держится тревога (красный + сирена) после прохода
	cooldown     = 5,    -- секунд между повторными тревогами на одного и того же игрока
	alertRadius  = 600,  -- в этом радиусе игроки получают уведомление о контрабанде
	checkInterval = 0.2, -- как часто (сек) сканер опрашивает зону
}

-- Предметы считаются запрещёнными, если у них стоит ITEM.contraband или ITEM.isIllegal,
-- ЛИБО их uniqueID есть в этом списке (на случай предметов без флага).
PLUGIN.extraIllegal = {
	-- ["weapon_pistol"] = true,
}

-- Общий помощник: запрещён ли предмет. Доступен и серверу, и сущности.
ix.contraband = ix.contraband or {}
ix.contraband.plugin = PLUGIN

function ix.contraband.IsItemIllegal(item)
	if (!item) then return false end

	return item.contraband == true
		or item.isIllegal == true
		or PLUGIN.extraIllegal[item.uniqueID] == true
end

if (SERVER) then
	ix.util.Include("sv_plugin.lua")
end

-- Двухточечная установка (как создание зоны): первый вызов — отметить одну
-- сторону прохода, второй — противоположную. Смотрите в пол/точку и вводите команду.
ix.command.Add("ScannerPoint", {
	description = "Отметить точку сканера: 1-й раз — одна сторона, 2-й раз — противоположная.",
	adminOnly = true,
	OnRun = function(self, client)
		if (!SERVER) then return end

		local pos = client:GetEyeTrace().HitPos
		local pending = PLUGIN.pendingPoint[client]

		-- первая точка
		if (!pending) then
			PLUGIN.pendingPoint[client] = pos
			return "Точка 1 отмечена. Встаньте у второй стороны прохода и снова введите /ScannerPoint."
		end

		-- вторая точка — строим сканер
		PLUGIN.pendingPoint[client] = nil

		local ok, msg = PLUGIN:CreateScannerFromPoints(client, pending, pos)
		return msg
	end
})

-- Сбросить незавершённую установку (отменить отмеченную первую точку).
ix.command.Add("ScannerCancel", {
	description = "Отменить незавершённую установку сканера (сбросить точку 1).",
	adminOnly = true,
	OnRun = function(self, client)
		if (!SERVER) then return end

		if (PLUGIN.pendingPoint[client]) then
			PLUGIN.pendingPoint[client] = nil
			return "Установка отменена."
		end

		return "Нет незавершённой установки."
	end
})

-- Изменить размеры ближайшего к прицелу сканера.
ix.command.Add("ScannerSize", {
	description = "Задать размер ближайшего сканера: ширина высота [толщина] (юниты).",
	adminOnly = true,
	arguments = {
		ix.type.number,
		ix.type.number,
		bit.bor(ix.type.number, ix.type.optional)
	},
	OnRun = function(self, client, width, height, depth)
		if (!SERVER) then return end

		local scanner = PLUGIN:FindAimedScanner(client)

		if (!IsValid(scanner)) then
			return "Рядом с прицелом нет сканера."
		end

		scanner:SetScanWidth(math.Clamp(width, 8, 1024))
		scanner:SetScanHeight(math.Clamp(height, 8, 1024))

		if (depth) then
			scanner:SetScanDepth(math.Clamp(depth, 4, 512))
		end

		PLUGIN:SaveData()

		return string.format("Размер сканера: %dШ x %dВ x %dТ.",
			scanner:GetScanWidth(), scanner:GetScanHeight(), scanner:GetScanDepth())
	end
})

-- Убрать ближайший к прицелу сканер.
ix.command.Add("ScannerRemove", {
	description = "Удалить ближайший к прицелу сканер контрабанды.",
	adminOnly = true,
	OnRun = function(self, client)
		if (!SERVER) then return end

		local scanner = PLUGIN:FindAimedScanner(client)

		if (!IsValid(scanner)) then
			return "Рядом с прицелом нет сканера."
		end

		scanner:Remove()
		PLUGIN:SaveData()

		return "Сканер удалён."
	end
})
