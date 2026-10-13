local PLUGIN = PLUGIN
local PLAYER = FindMetaTable("Player")

function PLAYER:InCriticalState()
	return self:GetNetVar("crit")
end

do
	local function DrawSkull(x, y, size, alpha)
        draw.NoTexture()
        surface.SetDrawColor(235, 232, 225, alpha)
        surface.DrawRect(x + size*.18, y + size*.12, size*.64, size*.48)
        surface.DrawRect(x + size*.3, y + size*.56, size*.4, size*.3)
        surface.SetDrawColor(12, 12, 15, alpha)
        surface.DrawRect(x + size*.27, y + size*.3, size*.16, size*.16)
        surface.DrawRect(x + size*.57, y + size*.3, size*.16, size*.16)
        surface.DrawRect(x + size*.46, y + size*.5, size*.08, size*.12)
        for i=1,3 do surface.DrawRect(x + size*(.3+i*.1), y + size*.7, 1, size*.16) end
    end
	local size = 32
	local mid  = size / 2
	local abs = math.abs
	local use = string.upper(input.LookupBinding("+use") or "E")

	local focus_stick = 0
	local focus_range = 25
	local focus_ent = nil
	local focused_ent = nil

	surface.CreateFont("ixCrit", {
		font = "Roboto Lt",
		size = 18,
		weight = 500,
		antialias = true,
		extended = true
	})
	surface.CreateFont("ixCritBlur", {
		font = "Roboto Lt",
		size = 18,
		weight = 500,
		blursize = 2,
		antialias = true,
		extended = true
	})

	local critCount = 0
	local critPlayers = {}

	net.Receive("crit.use", function()
		local isSlay = net.ReadBool()

		if isSlay then
			Derma_Query("Ограбив этого персонажа, Вы отправите его на точку появления в рамках правила NLR, получив инвентарь погибшего. Этот процесс займет 10 секунд. Вы точно уверены в этом?", "Ограбить персонажа", "Ограбить", function() 
				net.Start("crit.apply")
					net.WriteBool(true)
				net.SendToServer()

				end, "Отмена", function() 

				net.Start("crit.apply")
				net.SendToServer()
			end)
		else
			Derma_Query("Добив этого персонажа, вы отправите его на точку появления. Вещи останутся в теле по правилам сервера. Процесс займёт 30 секунд и прервётся, если персонажа спасут. Продолжить?", "Добить персонажа", "Добить", function()
				net.Start("crit.apply")
					net.WriteBool(true)
				net.SendToServer()

				end, "Отмена", function() 

				net.Start("crit.apply")
				net.SendToServer()
			end)
		end
	end)

	timer.Create("ixCritUpdate", 1, 0, function()
		for _, client in ipairs(player.GetAll()) do
			critPlayers[client] = client:GetNetVar("crit", nil)
		end

		critCount = table.Count(critPlayers)
	end)

	local function IsOffScreen(scrpos)
		return not scrpos.visible or scrpos.x < 0 or scrpos.y < 0 or scrpos.x > ScrW() or scrpos.y > ScrH()
	end

	local function UseCriticalButton()
		local target = focused_ent
		local menu = ix.SimpleMenu()

		menu:AddOption("ОГРАБИТЬ", function()
			net.Start("crit.use")
				net.WriteEntity(target)
				net.WriteBool(true)
			net.SendToServer()
		end)

		menu:AddOption("ДОБИТЬ", function()
			net.Start("crit.use")
				net.WriteEntity(target)
				net.WriteBool(false)
			net.SendToServer()
		end)

		menu:Open()
		menu:Center()

		focused_ent = nil
		return true
	end

	function PLUGIN:PlayerBindPress(client, bind, pressed)
		-- Non-solid cart occupants have their own server-authorized E menu.
		if bind:find("+use") and ix.PushCart and ix.PushCart.TracePatient and ix.PushCart:TracePatient(client) then return end
		-- Let the drag menu handle living ragdolls before the legacy critical
		-- prompt, regardless of plugin hook order. Shooting stays available.
		if ix.BodyDrag then
			local handled = ix.BodyDrag.HandleBind(client, bind, pressed)
			if handled then return true end
			if ix.BodyDrag.Body(client) then return end
		end
		if IsValid(focused_ent) and focus_stick >= CurTime() then
			if bind:find("attack") and pressed then
				return true
			elseif bind:find("+use") and pressed then
				return UseCriticalButton()
			end
		end
	end

	function PLUGIN:HUDPaint()
		self:DrawBleeding()
		
		if critCount == 0 then
			return
		end



		local plypos = LocalPlayer():GetPos()
		local midscreen_x = ScrW() / 2
		local midscreen_y = ScrH() / 2
		local pos, scrpos, d
		local focus_ent = nil
		local focus_d, focus_scrpos_x, focus_scrpos_y = 0, midscreen_x, midscreen_y

		for but, _ in pairs(critPlayers) do
			if IsValid(but) and but:IsPlayer() then
				local doll = but:GetNetVar("doll") and Entity(but:GetNetVar("doll"))
				if IsValid(doll) then
					but = doll
				end
				but = (ix.PushCart and ix.PushCart.PatientDisplay and ix.PushCart:PatientDisplay(but)) or but

				local boneID = but:LookupBone("ValveBiped.Bip01_Head1")

				pos = but:GetPos()

				if boneID then
					pos = but:GetBonePosition(boneID)
				end

				scrpos = pos:ToScreen()

				if !IsOffScreen(scrpos) then
					d = pos - plypos
					d = d:Dot(d) / (100 ^ 2)

					if d < 1 then
						surface.SetDrawColor(255, 255, 255, 255 * (1 - d))
						DrawSkull(scrpos.x - mid, scrpos.y - mid, size, 255 * (1 - d))

						if d > focus_d and !but.isCartPatient then
							local x = abs(scrpos.x - midscreen_x)
							local y = abs(scrpos.y - midscreen_y)
							if (x < focus_range and y < focus_range and
								 x < focus_scrpos_x and y < focus_scrpos_y) then

								if focus_stick < CurTime() or but == focused_ent then
									focus_ent = but
								end
							end
						end
					end
				end
			else
				critPlayers[but] = nil
				critCount = table.Count(critPlayers)
			end

			if IsValid(focus_ent) then
				focused_ent = focus_ent
				focus_stick = CurTime() + 0.1

				local text = string.format("НАЖМИТЕ [%s] ЧТОБЫ ОГРАБИТЬ ИЛИ ДОБИТЬ", use)
				local x = scrpos.x
				local y = scrpos.y + 16
				surface.SetFont("ixCrit")

				local tX, tY = surface.GetTextSize(text)
				x = x - tX/2
				
				surface.SetFont("ixCritBlur")
				surface.SetTextColor(0, 0, 0, 255)
				surface.SetTextPos(x, y)
				surface.DrawText(text)

				surface.SetFont("ixCrit")
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos(x, y)
				surface.DrawText(text)
			end
		end
	end
end
