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

function Schema:PlayerFootstep(client, position, foot, soundName, volume)
	return true
end

function Schema:CanDrawAmmoHUD(weapon)
	return false
end

function Schema:IsRecognizedChatType(chatType)
	if (chatType == "mec" or chatType == "mel" or chatType == "med") then
		return true
	end
end

netstream.Hook("ixEmitQueuedSounds", function(sounds, delay, spacing, volume, pitch)
	ix.util.EmitQueuedSounds(LocalPlayer(), sounds, delay, spacing, volume, pitch)
end)

netstream.Hook("ixPlayLocalSound", function(path, position, level, pitch, volume)
	sound.Play(path, position, level, pitch, volume)
end)


function Schema:HUDShouldDraw(name)
 if name == "CHudAmmo" or name == "CHudSecondaryAmmo" then return false end
end
