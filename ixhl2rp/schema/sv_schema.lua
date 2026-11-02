function Schema:SearchPlayer(client, target)
	if !target:GetCharacter() then
		return false
	end

	local name = hook.Run("GetDisplayedName", target) or target:Name()
	local inventory = target:GetInventory("main")

	ix.storage.Open(client, inventory, {
		entity = target,
		name = name,
		OnPlayerOpen = function(client)
			for k, v in pairs(target:GetInventories()) do
				if v.type == "main" then continue end

				v:AddReceiver(client)
			end
		end,
		OnPlayerClose = function(client)
			for k, v in pairs(target:GetInventories()) do
				if v.type == "main" then continue end

				v:RemoveReceiver(client)
			end
		end,
		OnSync = function(client)
			for k, v in pairs(target:GetInventories()) do
				if v.type == "main" then continue end

				v:Sync(client)
			end
		end,
	})

	return true
end
