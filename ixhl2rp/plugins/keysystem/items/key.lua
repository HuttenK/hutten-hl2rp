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

-- Ближайшая привязанная к ключу дверь в радиусе
local function findNearestDoor(item)
	local ply = item.player
	if !IsValid(ply) then return end

	local doors = item:GetData("doors", {})
	local best, bestDist

	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 130)) do
		if ent.IsDoor and ent:IsDoor() and doors[tostring(ent:MapCreationID())] then
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

	local door = findNearestDoor(item)
	if !IsValid(door) then
		ply:Notify("Рядом нет двери от этого ключа.")
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
