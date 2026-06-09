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
