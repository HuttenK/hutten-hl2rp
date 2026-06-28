-- Клиентский блок меню обвесов ArcCW: не даём ему ОТКРЫТЬСЯ вообще (раньше
-- меню успевало появиться и закрывалось только после ответа сервера — за эту
-- долю секунды можно было успеть поставить обвес). Закрываем в том же кадре.
local GUNSMITH_RANGE = 200

local function CanCustomizeCL()
	local ply = LocalPlayer()
	if (!IsValid(ply)) then return false end
	if (ply:IsAdmin()) then return true end

	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), GUNSMITH_RANGE)) do
		if (IsValid(ent) and ent:GetClass() == "ix_gunsmith") then
			return true
		end
	end

	return false
end

hook.Add("Think", "arccw_item_atts_blockmenu", function()
	if (!ArcCW or !ArcCW.STATE_CUSTOMIZE) then return end

	local ply = LocalPlayer()
	if (!IsValid(ply)) then return end

	local wep = ply:GetActiveWeapon()
	if (!IsValid(wep) or !wep.ArcCW) then return end

	if (wep.GetState and wep:GetState() == ArcCW.STATE_CUSTOMIZE and !CanCustomizeCL()) then
		if (wep.ExitCustomize) then
			wep:ExitCustomize()
		elseif (wep.SetState and ArcCW.STATE_NORMAL) then
			wep:SetState(ArcCW.STATE_NORMAL)
		end
	end
end)

-- Receive signal from server to refresh weapon visuals after attachments applied.
net.Receive("arccw_item_atts_apply", function()
	local weapon = net.ReadEntity()
	if not IsValid(weapon) or not weapon.ArcCW then return end

	-- Rebuild clientside model and visuals.
	timer.Simple(0.05, function()
		if not IsValid(weapon) then return end

		if weapon.SetupModel then
			weapon:SetupModel(false)
			weapon:SetupModel(true)
		end
	end)
end)
