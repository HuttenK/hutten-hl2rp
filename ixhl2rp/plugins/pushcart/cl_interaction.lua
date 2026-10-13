local P = ix.PushCart
net.Receive("ixPushCartMenu", function()
	local entity, token, count = net.ReadEntity(), net.ReadUInt(16), net.ReadUInt(3)
	local options = {}
	for i = 1, count do options[i] = net.ReadString() end
	local client = LocalPlayer()
	if !P:CanInteract(client, entity) or gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
	if IsValid(P.menu) then P.menu:Remove() elseif vgui.CursorVisible() then return end
	local menu = ix.SimpleMenu()
	P.menu = menu
	local character, parent, chosen = client:GetCharacter(), entity:GetParent(), false
	local function occupant() return P:GetPatient(entity.isCartPatient and P:PatientCart(entity) or entity) end
	local patient = occupant()
	local expires = CurTime() + 15
	local function valid()
		return IsValid(menu) and !chosen and client == LocalPlayer() and client:GetCharacter() == character
			and CurTime() <= expires and P:CanInteract(client, entity) and entity:GetParent() == parent and occupant() == patient
	end
	for _, action in ipairs(options) do
		local info = P.actions[action]
		if !info then continue end
		local label = action == "open" and entity.isCargoCrate and "Открыть ящик" or info.label
		menu:AddOption(label, function()
			local allowed = valid()
			chosen = true; menu:Remove()
			if !allowed then return end
			if action == "examinePatient" then
				local patient = P:GetPatient(entity.isCartPatient and P:PatientCart(entity) or entity)
				if IsValid(patient) and ix.Medicine then ix.Medicine.OpenExamination(patient) end
				return
			elseif action == "robPatient" or action == "finishPatient" then
				local display = entity.isCartPatient and entity or entity:GetNW2Entity("ixCartPatientDisplay")
				if IsValid(display) then
					net.Start("crit.use") net.WriteEntity(display) net.WriteBool(action=="robPatient") net.SendToServer()
				end
				return
			end
			net.Start("ixPushCartAction") net.WriteEntity(entity) net.WriteUInt(token,16) net.WriteString(action) net.SendToServer()
		end):SetImage(info.icon)
	end
	if #options == 0 then menu:AddOption("Груз занят"):SetEnabled(false) end
	menu:AddOption("Отмена", function() chosen = true; menu:Remove() end):SetImage("icon16/cancel.png")
	menu:Open(ScrW()/2, ScrH()/2)
	menu.Think = function(this)
		if !valid() or gui.IsGameUIVisible() or gui.IsConsoleVisible() then this:Remove() end
	end
end)
