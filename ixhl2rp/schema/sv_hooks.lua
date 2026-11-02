function Schema:OnPlayerOptionSelected(target, client, option)
	if option == "Untie" then
		if (!client:IsRestricted() and target:IsPlayer() and target:IsRestricted() and !target:GetNetVar("untying")) then
			target:SetAction("@beingUntied", 5)
			target:SetNetVar("untying", true)

			client:SetAction("@unTying", 5)

			client:DoStaredAction(target, function()
				target:SetRestricted(false)
				target:SetNetVar("untying")
			end, 5, function()
				if (IsValid(target)) then
					target:SetNetVar("untying")
					target:SetAction()
				end

				if (IsValid(client)) then
					client:SetAction()
				end
			end)
		end
	elseif option == "Search" then
		ix.command.Run(client, "CharSearch")
	elseif option == "Ziptie" then
		local inv = client:GetInventory("main")
		local has, item = inv:HasItem("ziptie")

		if has then
			ix.Item:PerformInventoryAction(client, item, inv.id, "Use", nil, 1)
		end
	end
end

function Schema:PlayerLoadout(client)
	client:SetNetVar("restricted")
end

function Schema:CharacterVarChanged(character, key, oldValue, value)
	local client = character:GetPlayer()
	if (key == "name") then
		local factionTable = ix.faction.Get(client:Team())

		if (factionTable.OnNameChanged) then
			factionTable:OnNameChanged(client, oldValue, value)
		end
	end
end

function Schema:PlayerFootstep(client, position, foot, soundName, volume)
	local factionTable = ix.faction.Get(client:Team())

	if (factionTable.runSounds and client:IsRunning()) then
		client:EmitSound(factionTable.runSounds[foot])
		return true
	end

	client:EmitSound(soundName)
	return true
end

function Schema:PlayerSpawn(client)
	client:SetCanZoom(false)
end

function Schema:GetPlayerPunchDamage()
	return 0
end

function Schema:CanPlayerJoinClass(client, class, info)
	if (client:IsRestricted()) then
		client:NotifyLocalized("cantChangeClassRestrained")

		return false
	end
end

function Schema:PlayerSpawnObject(client)
	if (client:IsRestricted()) then
		return false
	end
end

function Schema:PlayerSpray(client)
	return true
end


function Schema:PlayerSwitchFlashlight(client, enabled)
 return not enabled
end
