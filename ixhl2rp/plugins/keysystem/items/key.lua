-- Физический ключ. Хранит список ID дверей (MapCreationID как строки) в data.doors.
-- Запирает/отпирает ближайшую привязанную дверь действием предмета.
ITEM.name = "Ключ"
ITEM.description = "Физический ключ. Отпирает и запирает привязанные к нему двери."
ITEM.model = Model("models/items/keys_003.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Ключи"
ITEM.noBusiness = true

-- ВАЖНО: в этой сборке SetData работает только для объявленных полей.
ITEM:AddData("doors", { Transmit = ix.transmit.owner })
ITEM:AddData("label", { Transmit = ix.transmit.owner })

ITEM.canRename = true
ITEM.renameField = "label"

-- КЛЮЧЕВОЙ ФИКС ПЕРСИСТЕНТНОСТИ.
-- Двери хранятся ключами вида tostring(MapCreationID) → строки ("3044"). Но при
-- загрузке предмета из БД util.JSONToTable превращает числовые строковые ключи
-- обратно в ЧИСЛА (3044). Из-за этого после рестарта doors["3044"] (строковый
-- поиск во всём коде — findDoor, KeyUnbind) не находил число 3044, и ключ «не видел»
-- свою дверь (при этом /KeyDebug показывал совпадающий MapID). Нормализуем ключи
-- обратно в строки сразу после загрузки/создания — дальше tostring-поиск снова
-- совпадает. OnInstanced вызывается и при загрузке из БД, и при создании предмета.
function ITEM:OnInstanced()
	local doors = self.data and self.data.doors
	if istable(doors) then
		local fixed = {}
		for id, v in pairs(doors) do
			if v then fixed[tostring(id)] = true end
		end
		self.data.doors = fixed
	end
end

function ITEM:GetName()
	local label = self:GetData("label", "")
	return (label != "") and ("Ключ: " .. label) or self.name
end

-- Тултип/инвентарь показывают имя через GetPrintName, поэтому переопределяем именно его
function ITEM:GetPrintName()
	local label = self:GetData("label", "")
	if label != "" then return "Ключ: " .. label end
	return self.name
end

if CLIENT then
	function ITEM:PopulateTooltip(tooltip)
		local n = table.Count(self:GetData("doors", {}))
		local row = tooltip:AddRowAfter("description", "keydoors")
		row:SetText("Привязано дверей: " .. n)
		row:SizeToContents()
	end
end

-- Подходит ли дверь под ключ. Сопоставляем и по MapCreationID самой двери, и по её
-- партнёру: двустворчатые двери — это две отдельные сущности с РАЗНЫМИ ID, а привязка
-- (/KeyBind) сохраняет только ту створку, на которую смотрел админ. Без проверки
-- партнёра ключ «не видит» дверь, если подойти со стороны второй створки.
local function doorMatches(item, ent)
	if !(IsValid(ent) and ent.IsDoor and ent:IsDoor()) then return false end

	local doors = item:GetData("doors", {})

	-- Проверяем оба типа ключа (строку и число) на случай, если таблица не прошла
	-- нормализацию в OnInstanced — см. комментарий к ITEM:OnInstanced.
	local id = ent:MapCreationID()
	if doors[tostring(id)] or doors[id] then return true end

	local partner = ent.GetDoorPartner and ent:GetDoorPartner()
	if IsValid(partner) then
		local pid = partner:MapCreationID()
		if doors[tostring(pid)] or doors[pid] then return true end
	end

	return false
end

-- Дверь, к которой относится действие ключа. Сначала — та, на которую игрок СМОТРИТ
-- (как при привязке через /KeyBind: там дверь берётся из GetEyeTrace). Это устраняет
-- главную причину «Рядом нет двери»: раньше поиск шёл только по сфере вокруг GetPos()
-- игрока, а начало отсчёта у вращающейся двери — в петле, и центр двери мог не попасть
-- в радиус. Если игрок не смотрит на подходящую дверь — берём ближайшую привязанную.
local function findDoor(item)
	local ply = item.player
	if !IsValid(ply) then return end

	local tr = ply:GetEyeTrace()
	if IsValid(tr.Entity) and tr.HitPos:DistToSqr(ply:GetShootPos()) <= (150 * 150)
	and doorMatches(item, tr.Entity) then
		return tr.Entity
	end

	local best, bestDist
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 150)) do
		if doorMatches(item, ent) then
			local d = ply:GetPos():DistToSqr(ent:GetPos())
			if !bestDist or d < bestDist then
				best, bestDist = ent, d
			end
		end
	end

	return best
end

local function setLock(item, bLock)
	local ply = item.player
	if !IsValid(ply) then return end

	local door = findDoor(item)
	if !IsValid(door) then
		ply:Notify("Рядом нет двери от этого ключа. Подойдите ближе и смотрите на дверь.")
		return
	end

	local cmd = bLock and "lock" or "unlock"
	door:Fire(cmd)

	local partner = door.GetDoorPartner and door:GetDoorPartner()
	if IsValid(partner) then partner:Fire(cmd) end

	ply:Notify(bLock and "Дверь заперта." or "Дверь отперта.")
end

ITEM.functions.Unlock = {
	name = "Отпереть",
	icon = "icon16/lock_open.png",
	OnRun = function(item)
		setLock(item, false)
		return false
	end,
}

ITEM.functions.Lock = {
	name = "Запереть",
	icon = "icon16/lock.png",
	OnRun = function(item)
		setLock(item, true)
		return false
	end,
}

ITEM.functions.Rename = {
	name = "Переименовать",
	icon = "icon16/textfield_rename.png",
	OnClick = function(item)
		Derma_StringRequest("Переименование ключа", "Введите название ключа:", item:GetData("label", ""),
			function(text)
				netstream.Start("ixItemRename", item.id, text)
			end)
		return false
	end,
	OnRun = function(item) return false end,
	OnCanRun = function(item)
		-- Переименование ключей — только администрация (пункт скрыт у остальных).
		local ply = item.player or (CLIENT and LocalPlayer())
		return !IsValid(item.entity) and IsValid(ply) and ply:IsAdmin()
	end,
}
