
function Schema:PopulateCharacterInfo(client, character, tooltip)
	if (client:IsRestricted()) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("tiedUp"))
		panel:SizeToContents()
	elseif (client:GetNetVar("tying")) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("beingTied"))
		panel:SizeToContents()
	elseif (client:GetNetVar("untying")) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("beingUntied"))
		panel:SizeToContents()
	end
end

do
	local chatTypes = {
		["ic"] = true,
		["w"] = true,
		["y"] = true,
		["radio"] = true,
		["request"] = true,
		["dispatch"] = true,
		["dispatch_radio"] = true
	}

	function Schema:ShouldPlayTypingBeep(client, chatType)
		return client:IsCombine() and chatTypes[chatType] and client:GetMoveType() != MOVETYPE_NOCLIP
	end
end

function Schema:ChatTextChanged(text)
	if (LocalPlayer():IsCombine()) then -- and (text:sub(1, 1):find("%w") or text:find("/%a+%s"))) then
		local chatType = ix.chat.Parse(LocalPlayer(), text, true)

		if (self:ShouldPlayTypingBeep(LocalPlayer(), chatType)) then
			netstream.Start("PlayerChatTextChanged", chatType)
		end
	end
end

function Schema:FinishChat()
	netstream.Start("PlayerFinishChat")
end

function Schema:GetPlayerEntityMenu(client, options)
	local callingPlayer = LocalPlayer()

	if (!callingPlayer:IsRestricted() and client:IsRestricted() and !client:GetNetVar("untying")) then
		options["Untie"] = true
		options["Search"] = true
	elseif (!callingPlayer:IsRestricted() and !client:IsRestricted() and !client:GetNetVar("tying") and
		callingPlayer:HasItem("ziptie")) then
			options["Ziptie"] = true
	end
end

function Schema:CharacterLoaded(character)
	if (character:IsCombine()) then
		vgui.Create("ixCombineDisplay")

		timer.Create("ixRandomDisplayLines", 12, 0, function()
			if (IsValid(client) and client:IsCombine()) then
				local text = self.randomDisplayLines[math.random(1, #self.randomDisplayLines)]

				if (istable(text)) then
					text = text[2](text[1]) or ""
				end

				if (text and self.LastRandomDisplayLine != text) then
					self:AddCombineDisplayMessage(text)

					self.LastRandomDisplayLine = text
				end
			else
				self.LastRandomDisplayLine = nil

				timer.Remove("ixRandomDisplayLines")
			end
		end)
	elseif (IsValid(ix.gui.combine)) then
		ix.gui.combine:Remove()

		timer.Remove("ixRandomDisplayLines")
	end
end

function Schema:PlayerFootstep(client, position, foot, soundName, volume)
	return true
end

local colorModify = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = -0.015,
	["$pp_colour_contrast"] = 1.2,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

local combineOverlay = ix.util.GetMaterial("effects/combine_mockup5")

function Schema:RenderScreenspaceEffects()
	//DrawColorModify(colorModify)

	if (LocalPlayer():IsCombine()) then
		render.UpdateScreenEffectTexture()

		combineOverlay:SetFloat("$alpha", 1)
		combineOverlay:SetInt("$ignorez", 1)

		render.SetMaterial(combineOverlay)
		render.DrawScreenQuad()
	end
end

function Schema:ShouldShowPlayerOnScoreboard(client)
	local clientFaction = LocalPlayer():Team()
	local playerFaction = client:Team()

	if (playerFaction == clientFaction) then
		return
	end
end

function Schema:CanDrawAmmoHUD(weapon)
	return false
end

-- Скрываем стандартный GMod-отображение боезапаса (иконка + счётчик справа снизу)
local hiddenHudElements = {
	["CHudAmmo"]          = true,
	["CHudSecondaryAmmo"] = true,
}

function Schema:HUDShouldDraw(name)
	if hiddenHudElements[name] then
		return false
	end
end

-- ============================================================
-- Руки игрока по фракции (viewmodel c_arms)
-- Используем hook.Add напрямую — Schema: не форвардит этот хук.
-- factionHands заполняется в InitPostEntity когда FACTION_* готовы.
-- ============================================================
local factionHands = {}

hook.Add("InitPostEntity", "ix_faction_hands_init", function()
	-- МПФ (ГО) — руки солдата Альянса (светлый скин)
	if FACTION_MPF then
		factionHands[FACTION_MPF] = {
			model = "models/weapons/c_arms_combine_soldier.mdl",
			skin  = 0,
			body  = "00000000",
		}
	end

	-- ОТА — руки солдата Альянса (тёмный скин)
	if FACTION_OTA then
		factionHands[FACTION_OTA] = {
			model = "models/weapons/c_arms_combine_soldier.mdl",
			skin  = 1,
			body  = "00000000",
		}
	end

	-- ОТА Элита (EOW) — те же тёмные руки
	if FACTION_EOW then
		factionHands[FACTION_EOW] = {
			model = "models/weapons/c_arms_combine_soldier.mdl",
			skin  = 1,
			body  = "00000000",
		}
	end
end)

-- Прямой хук GMod — Schema: не вызывается для PlayerSetHandsModel
hook.Add("PlayerSetHandsModel", "ix_faction_hands", function(client, hands)
	local data = factionHands[client:Team()]
	if not data then return end  -- пропускаем: GMod назначит дефолтные руки

	hands:SetModel(data.model)
	hands:SetSkin(data.skin)
	hands:SetBodyGroups(data.body)
end)

function Schema:IsPlayerRecognized(target)

end

function Schema:IsRecognizedChatType(chatType)
	if (chatType == "mec" or chatType == "mel" or chatType == "med") then
		return true
	end
end

netstream.Hook("CombineDisplayMessage", function(text, color, arguments)
	if (IsValid(ix.gui.combine)) then
		ix.gui.combine:AddLine(text, color, nil, unpack(arguments))
	end
end)

netstream.Hook("PlaySound", function(sound)
	surface.PlaySound(sound)
end)

netstream.Hook("ixEmitQueuedSounds", function(sounds, delay, spacing, volume, pitch)
	ix.util.EmitQueuedSounds(LocalPlayer(), sounds, delay, spacing, volume, pitch)
end)

netstream.Hook("ixPlayLocalSound", function(path, position, level, pitch, volume)
	sound.Play(path, position, level, pitch, volume)
end)

function Schema:PopulateHelpMenu(tabs)
	tabs["voices"] = function(container)
		local classes = {}

		for k, v in pairs(Schema.voices.classes) do
			if (v.condition(LocalPlayer())) then
				classes[#classes + 1] = k
			end
		end

		if (#classes < 1) then
			local info = container:Add("DLabel")
			info:SetFont("ixSmallFont")
			info:SetText(L("voices.noAccess"))
			info:SetContentAlignment(5)
			info:SetTextColor(color_white)
			info:SetExpensiveShadow(1, color_black)
			info:Dock(TOP)
			info:DockMargin(0, 0, 0, 8)
			info:SizeToContents()
			info:SetTall(info:GetTall() + 16)

			info.Paint = function(_, width, height)
				surface.SetDrawColor(ColorAlpha(derma.GetColor("Error", info), 160))
				surface.DrawRect(0, 0, width, height)
			end

			return
		end

		table.sort(classes, function(a, b)
			return a < b
		end)

		for _, class in ipairs(classes) do
			local category = container:Add("Panel")
			category:Dock(TOP)
			category:DockMargin(0, 0, 0, 8)
			category:DockPadding(8, 8, 8, 8)
			category.Paint = function(_, width, height)
				surface.SetDrawColor(Color(0, 0, 0, 66))
				surface.DrawRect(0, 0, width, height)
			end

			local categoryLabel = category:Add("DLabel")
			categoryLabel:SetFont("ixMediumLightFont")
			categoryLabel:SetText(class:upper())
			categoryLabel:Dock(FILL)
			categoryLabel:SetTextColor(color_white)
			categoryLabel:SetExpensiveShadow(1, color_black)
			categoryLabel:SizeToContents()
			category:SizeToChildren(true, true)

			for command, info in SortedPairs(self.voices.stored[class]) do
				local title = container:Add("DLabel")
				title:SetFont("ixMediumLightFont")
				title:SetText(command:upper())
				title:Dock(TOP)
				title:SetTextColor(ix.config.Get("color"))
				title:SetExpensiveShadow(1, color_black)
				title:SizeToContents()

				local description = container:Add("DLabel")
				description:SetFont("ixSmallFont")
				description:SetText(info.text)
				description:Dock(TOP)
				description:SetTextColor(color_white)
				description:SetExpensiveShadow(1, color_black)
				description:SetWrap(true)
				description:SetAutoStretchVertical(true)
				description:SizeToContents()
				description:DockMargin(0, 0, 0, 8)
			end
		end
	end
end

function Schema:RenderScreenspaceEffects()
	if (LocalPlayer():IsCombine()) then
		render.UpdateScreenEffectTexture()

		combineOverlay:SetFloat("$refractamount", 0.3)
		combineOverlay:SetFloat("$alpha", 0.5)
		combineOverlay:SetInt("$ignorez", 1)

		render.SetMaterial(combineOverlay)
		render.DrawScreenQuad()
	end
	
	if true then return end

	if (ix.option.Get("ColorModify", true)) then
		local colorModify = {}
		colorModify["$pp_colour_colour"] = 0.77 + ix.option.Get("ColorSaturation", 0)

		if (system.IsWindows()) then
			colorModify["$pp_colour_brightness"] = -0.02
			colorModify["$pp_colour_contrast"] = 1.2
		else
			colorModify["$pp_colour_brightness"] = 0
			colorModify["$pp_colour_contrast"] = 1
		end
		DrawColorModify(colorModify)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sound Tape item — клиентские хуки
-- ─────────────────────────────────────────────────────────────────────────────

netstream.Hook("ixSoundTapeEdit", function(data)
	if IsValid(ix.gui.soundTapeEdit) then
		ix.gui.soundTapeEdit:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetTitle("Sound Tape — Edit")
	frame:SetSize(420, 160)
	frame:Center()
	frame:MakePopup()
	ix.gui.soundTapeEdit = frame

	local labelSound = frame:Add("DLabel")
	labelSound:SetPos(10, 30)
	labelSound:SetText("Sound path (relative to sound/):")
	labelSound:SizeToContents()

	local entrySound = frame:Add("DTextEntry")
	entrySound:SetPos(10, 48)
	entrySound:SetSize(400, 22)
	entrySound:SetText(data.sound or "")
	entrySound:SetPlaceholderText("e.g. ambient/alarms/klaxon1.wav")

	local labelName = frame:Add("DLabel")
	labelName:SetPos(10, 76)
	labelName:SetText("Tape label (optional, visible to others):")
	labelName:SizeToContents()

	local entryLabel = frame:Add("DTextEntry")
	entryLabel:SetPos(10, 94)
	entryLabel:SetSize(400, 22)
	entryLabel:SetText(data.label or "")
	entryLabel:SetPlaceholderText("e.g. PA Announcement #4")

	local btnSave = frame:Add("DButton")
	btnSave:SetPos(10, 124)
	btnSave:SetSize(195, 24)
	btnSave:SetText("Save")
	btnSave.DoClick = function()
		netstream.Start("ixSoundTapeSave", {
			id    = data.id,
			sound = entrySound:GetText(),
			label = entryLabel:GetText(),
		})
		frame:Remove()
	end

	local btnTest = frame:Add("DButton")
	btnTest:SetPos(215, 124)
	btnTest:SetSize(195, 24)
	btnTest:SetText("Test sound")
	btnTest.DoClick = function()
		local snd = entrySound:GetText():Trim()
		if snd != "" then
			surface.PlaySound(snd)
		end
	end
end)

