local PLUGIN = PLUGIN

-- Общие серверные утилиты (доступны из предмета vehicle_key через ix.vehiclekeys.*)
ix.vehiclekeys = ix.vehiclekeys or {}

-- Дистанция, на которой ключ действует на машину (отпереть/запереть).
ix.vehiclekeys.range = 600

-- Любой транспорт LVS помечен полем .LVS = true (см. lvs_base/shared.lua).
function ix.vehiclekeys.IsVehicle(ent)
	return IsValid(ent) and ent.LVS == true
end

-- Трейс/пои может попасть в дочернюю сущность (сиденье, оружие) — поднимаемся к базовой машине.
function ix.vehiclekeys.Resolve(ent)
	while (IsValid(ent)) do
		if (ent.LVS == true) then return ent end
		ent = ent:GetParent()
	end

	return NULL
end

-- Уникальный ID машины. Создаётся при первой привязке ключа и живёт, пока существует сущность.
function ix.vehiclekeys.GetID(vehicle)
	if (not IsValid(vehicle)) then return end

	if (not vehicle.ixKeyID) then
		vehicle.ixKeyID = string.format("veh_%d_%d", os.time(), math.random(100000, 999999))
		vehicle:SetNWString("ixKeyID", vehicle.ixKeyID)
	end

	return vehicle.ixKeyID
end

-- Найти машину по её ключевому ID.
function ix.vehiclekeys.Find(id)
	if (not id or id == "") then return NULL end

	for _, e in ipairs(ents.GetAll()) do
		if (e.LVS == true and e.ixKeyID == id) then return e end
	end

	return NULL
end

-- Ближайшая машина LVS к игроку (для привязки ключа из меню инвентаря).
function ix.vehiclekeys.FindNearest(client, range)
	if (not IsValid(client)) then return NULL end

	local best, bestDist = NULL, nil

	for _, e in ipairs(ents.FindInSphere(client:GetPos(), range or 250)) do
		if (e.LVS ~= true) then continue end

		local d = client:GetPos():DistToSqr(e:WorldSpaceCenter())

		if (not bestDist or d < bestDist) then
			best, bestDist = e, d
		end
	end

	return best
end

-- Есть ли у игрока в инвентаре ключ с нужным ID.
-- В этой сборке client:GetItems() перебирает всё, что игрок несёт.
function ix.vehiclekeys.PlayerHasKey(client, id)
	if (not IsValid(client) or not id or id == "") then return false end

	for _, item in ipairs(client:GetItems() or {}) do
		if (item.uniqueID == "vehicle_key" and item:GetData("vehID", "") == id) then
			return true
		end
	end

	return false
end

--[[
	Гейты LVS. Срабатывают только на привязанных к ключу машинах (у которых есть .ixKeyID).
	Непривязанный транспорт ведёт себя как обычно (заводится и водится всеми).
--]]

-- «Завести двигатель» — только с ключом.
hook.Add("LVS.IsEngineStartAllowed", "ixVehicleKeys", function(vehicle)
	local id = vehicle.ixKeyID

	if (not id) then return end

	local driver = vehicle:GetDriver()

	if (IsValid(driver) and ix.vehiclekeys.PlayerHasKey(driver, id)) then return end

	if (IsValid(driver)) then
		driver:Notify("Нужен ключ, чтобы завести этот транспорт.")
	end

	return false
end)

-- Сесть за руль — только с ключом (пассажиром сесть можно).
hook.Add("LVS.CanPlayerDrive", "ixVehicleKeys", function(ply, vehicle)
	local id = vehicle.ixKeyID

	if (not id) then return end

	if (ix.vehiclekeys.PlayerHasKey(ply, id)) then return end

	return false
end)

-- Уведомление, когда за руль не пускает (вызывается самим LVS при CanPlayerDrive == false).
hook.Add("LVS.OnPlayerCannotDrive", "ixVehicleKeys", function(ply, vehicle)
	if (IsValid(vehicle) and vehicle.ixKeyID and IsValid(ply)) then
		ply:Notify("Нужен ключ, чтобы сесть за руль этого транспорта.")
	end
end)
