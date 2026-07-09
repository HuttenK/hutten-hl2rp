-- Ключ зажигания. Привязывается к транспорту LVS (data.vehID).
-- Только владелец ключа может отпереть/запереть машину и завести двигатель.
ITEM.name = "Ключ от транспорта"
ITEM.description = "Ключ зажигания с брелоком. Отпирает, запирает и позволяет завести привязанный транспорт."
ITEM.model = Model("models/items/keys_003.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Ключи"
ITEM.noBusiness = true

-- ВАЖНО: в этой сборке SetData работает только для заранее объявленных полей.
ITEM:AddData("vehID", { Transmit = ix.transmit.owner })
ITEM:AddData("vehName", { Transmit = ix.transmit.owner })
ITEM:AddData("label", { Transmit = ix.transmit.owner })

-- Переименование через общий netstream плагина keysystem.
ITEM.canRename = true
ITEM.renameField = "label"

function ITEM:GetPrintName()
	local label = self:GetData("label", "")
	if (label != "") then return "Ключ: " .. label end

	local veh = self:GetData("vehName", "")
	if (veh != "") then return "Ключ: " .. veh end

	return self.name
end

function ITEM:GetName()
	return self:GetPrintName()
end

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local row = tooltip:AddRowAfter("description", "vehiclekey")
		local id = self:GetData("vehID", "")

		if (id == "") then
			row:SetText("Не привязан к транспорту.")
		else
			row:SetText("Привязан к: " .. self:GetData("vehName", "транспорт"))
		end

		row:SizeToContents()
	end
end

-- Привязанная к ключу машина в пределах досягаемости.
local function getBoundVehicle(item)
	local ply = item.player
	if (not IsValid(ply)) then return end

	local id = item:GetData("vehID", "")
	if (id == "") then return end

	local vehicle = ix.vehiclekeys.Find(id)

	if (not IsValid(vehicle)) then
		ply:Notify("Привязанный транспорт не найден.")
		return
	end

	if (ply:GetPos():Distance(vehicle:WorldSpaceCenter()) > ix.vehiclekeys.range) then
		ply:Notify("Слишком далеко от транспорта.")
		return
	end

	return vehicle
end

-- Привязать ключ к ближайшей машине.
ITEM.functions.Pair = {
	name = "Привязать к транспорту",
	icon = "icon16/car_add.png",
	OnCanRun = function(item)
		-- Только из инвентаря и только если ключ ещё не привязан.
		return not IsValid(item.entity) and item:GetData("vehID", "") == ""
	end,
	OnRun = function(item)
		local ply = item.player
		if (not IsValid(ply)) then return false end

		local vehicle = ix.vehiclekeys.FindNearest(ply, 250)

		if (not IsValid(vehicle)) then
			ply:Notify("Рядом нет транспорта для привязки.")
			return false
		end

		local id = ix.vehiclekeys.GetID(vehicle)

		item:SetData("vehID", id)
		item:SetData("vehName", vehicle.PrintName or vehicle:GetClass())

		if (vehicle.Lock) then vehicle:Lock() end

		ply:Notify("Ключ привязан к транспорту. Машина заперта.")
		ply:EmitSound("physics/metal/weapon_impact_soft2.wav", 75, 80)

		return false
	end,
}

ITEM.functions.Unlock = {
	name = "Отпереть",
	icon = "icon16/lock_open.png",
	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetData("vehID", "") != ""
	end,
	OnRun = function(item)
		local vehicle = getBoundVehicle(item)

		if (IsValid(vehicle)) then
			if (vehicle.UnLock) then vehicle:UnLock() end
			item.player:Notify("Транспорт отперт.")
		end

		return false
	end,
}

ITEM.functions.Lock = {
	name = "Запереть",
	icon = "icon16/lock.png",
	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetData("vehID", "") != ""
	end,
	OnRun = function(item)
		local vehicle = getBoundVehicle(item)

		if (IsValid(vehicle)) then
			if (vehicle.Lock) then vehicle:Lock() end
			item.player:Notify("Транспорт заперт.")
		end

		return false
	end,
}

ITEM.functions.Unpair = {
	name = "Стереть привязку",
	icon = "icon16/car_delete.png",
	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetData("vehID", "") != ""
	end,
	OnRun = function(item)
		item:SetData("vehID", "")
		item:SetData("vehName", "")

		if (IsValid(item.player)) then
			item.player:Notify("Привязка ключа стёрта.")
		end

		return false
	end,
}

-- Переименование ключа (использует общий netstream ixItemRename из плагина keysystem).
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
		local ply = item.player or (CLIENT and LocalPlayer())
		return not IsValid(item.entity) and IsValid(ply) and ply:IsAdmin()
	end,
}
