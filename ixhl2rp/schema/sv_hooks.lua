-- ─────────────────────────────────────────────────────────────────────────────
-- Sound Tape — серверные netstream хуки
-- ─────────────────────────────────────────────────────────────────────────────

netstream.Hook("ixSoundTapeSave", function(client, data)
	if not data then return end

	if not (client:IsAdmin() or client:IsSuperAdmin()) then
		client:Notify("ОШИБКА: Нет прав администратора!")
		return
	end

	local id    = data.id and tonumber(data.id)
	local sound = tostring(data.sound or ""):Trim()
	local label = tostring(data.label or ""):Trim()

	if #sound > 256 then
		client:Notify("ОШИБКА: Путь к звуку слишком длинный (макс. 256 символов).")
		return
	end

	-- Поиск экземпляра предмета
	local item = id and ix.Item.instances[id]

	if not item then
		local char = client:GetCharacter()
		local inv  = char and char:GetInventory()
		if inv then
			if id then
				local ok, found = inv:HasItemByID(id)
				if ok then item = found end
			end
			if not item then
				for _, v in ipairs(inv:GetItems()) do
					if v.uniqueID == "soundtape" then item = v break end
				end
			end
		end
	end

	if not item then
		client:Notify("ОШИБКА: Кассета не найдена (ID=" .. tostring(id) .. ")")
		return
	end

	-- Сохраняем данные
	item:SetData("sound", sound)
	item:SetData("label", label != "" and label or nil)
	client:Notify("Кассета обновлена.")

	-- Выкладываем в мир, если задан звук
	if sound != "" then
		-- Ищем инвентарь кассеты
		local inv = item.inventory_id and ix.Inventory:Get(item.inventory_id)
		if not inv then
			local char = client:GetCharacter()
			inv = char and char:GetInventory()
		end

		if not inv then
			client:Notify("ОШИБКА: Инвентарь кассеты не найден.")
			return
		end

		-- Убираем из инвентаря
		local ok, err = inv:TakeItemTable(item)
		if not ok then
			client:Notify("ОШИБКА при изъятии из инвентаря: " .. tostring(err or "unknown"))
			return
		end

		inv:Sync()

		-- Вычисляем позицию перед игроком
		local dropPos = client:GetShootPos() + client:GetAimVector() * 40
		local tr = util.TraceLine({
			start  = client:GetShootPos(),
			endpos = dropPos,
			filter = client
		})
		if tr.Hit then dropPos = tr.HitPos + tr.HitNormal * 5 end

		-- Спауним сущность в мире
		local entity = ix.Item:Spawn(dropPos, Angle(0, 0, 0), item)
		if IsValid(entity) then
			entity.ixSteamID = client:SteamID()
			entity.ixCharID  = client:GetCharacter():GetID()
			entity:SetNetVar("owner", entity.ixCharID)
		end
	end
end)

local soundtapePlaying  = {} -- [EntIndex] = true/false
local soundtapeToggleCD = {} -- [EntIndex] = CurTime() последнего переключения

hook.Add("EntityRemoved", "ixSoundTapeCleanup", function(entity)
	if IsValid(entity) and entity:GetClass() == "ix_item" then
		local idx = entity:EntIndex()
		soundtapePlaying[idx]  = nil
		soundtapeToggleCD[idx] = nil
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────

function Schema:CanPlayerAccessDoor(client, door, access)
	if (access == DOOR_GUEST) and client.ixDatafile and client.ixDatafile != 0 then
		local dID, datafile, genericdata = ix.plugin.list["datafile"]:ReturnDatafileByID(client.ixDatafile)
		local doorName = door:GetNetVar("name")

		if genericdata.aparts and doorName and genericdata.aparts == doorName then
			return true
		end
	end
end

function Schema:LoadData()
	self:LoadRationDispensers()
	self:LoadVendingMachines()
	self:LoadCombineMonitors()
	self:LoadSinkTriggers()
	self:LoadCombineFields()
end

function Schema:SaveData()
	self:SaveRationDispensers()
	self:SaveVendingMachines()
	self:SaveCombineMonitors()
	self:SaveSinkTriggers()
	self:SaveCombineFields()
end

function Schema:PlayerSwitchFlashlight(client, enabled)
	if (client:IsCombine()) then
		return true
	end
end

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

function Schema:PlayerUse(client, entity)
	if (entity:IsDoor() and IsValid(entity.ixLock) and client:KeyDown(IN_SPEED)) then
		entity.ixLock:Toggle(client)
		return false
	end

	-- Soundtape: перехватываем E до запуска PerformInteraction,
	-- чтобы не получать «неизвестную ошибку» от Helix.
	-- PlayerUse стреляет каждый тик пока зажата E — кулдаун защищает от спама.
	if IsValid(entity) and entity:GetClass() == "ix_item" then
		local item = entity:GetItem()
		if item and item.uniqueID == "soundtape" then
			local sound = item:GetData("sound", "")
			if sound != "" then
				local idx  = entity:EntIndex()
				local last = soundtapeToggleCD[idx] or 0

				if (CurTime() - last) >= 1 then
					soundtapeToggleCD[idx] = CurTime()

					if soundtapePlaying[idx] then
						entity:StopSound(sound)
						soundtapePlaying[idx] = nil
						client:Notify("Кассета остановлена.")
					else
						entity:EmitSound(sound, 75, 100, 1)
						soundtapePlaying[idx] = true
						client:Notify("Кассета воспроизводится.")
					end
				end
				return false
			end
		end
	end
end

function Schema:PlayerUseDoor(client, door)
	if (client:IsCombine() or client:IsCityAdmin()) then
		if (!door:HasSpawnFlags(256) and !door:HasSpawnFlags(1024)) then
			door:Fire("open")
		end
	end
end

function Schema:PlayerLoadout(client)
	client:SetNetVar("restricted")
end

function Schema:PostPlayerLoadout(client)
	if (client:IsCombine()) then
		local factionTable = ix.faction.Get(client:Team())

		if (factionTable.OnNameChanged) then
			factionTable:OnNameChanged(client, "", client:GetCharacter():GetName())
		end
	end
end

function Schema:PlayerLoadedCharacter(client, character, oldCharacter)
	local faction = character:GetFaction()

	if (faction == FACTION_CITIZEN) then
		self:AddCombineDisplayMessage("@cCitizenLoaded", Color(255, 100, 255, 255))
	elseif (client:IsCombine()) then
		client:AddCombineDisplayMessage("@cCombineLoaded")
	end
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
	client:SetCanZoom(client:IsCombine())
end

function Schema:PlayerDeath(client, inflicter, attacker)
	if (client:IsCombine()) then
		local location = client:GetArea() or "unknown location"

		self:AddCombineDisplayMessage("@cLostBiosignal")
		self:AddCombineDisplayMessage("@cLostBiosignalLocation", Color(255, 0, 0, 255), location)

		local sounds = {"npc/overwatch/radiovoice/on1.wav", "npc/overwatch/radiovoice/lostbiosignalforunit.wav"}
		local chance = math.random(1, 7)

		if (chance == 2) then
			sounds[#sounds + 1] = "npc/overwatch/radiovoice/remainingunitscontain.wav"
		elseif (chance == 3) then
			sounds[#sounds + 1] = "npc/overwatch/radiovoice/reinforcementteamscode3.wav"
		end

		sounds[#sounds + 1] = "npc/overwatch/radiovoice/off4.wav"

		for k, v in ipairs(player.GetAll()) do
			if (v:IsCombine()) then
				ix.util.EmitQueuedSounds(v, sounds, 2, nil, v == client and 100 or 80)
			end
		end
	end
end

function Schema:PlayerHurt(client, attacker, health, damage)
	if (health <= 0) then
		return
	end

	if (client:IsCombine() and (client.ixTraumaCooldown or 0) < CurTime()) then
		local text = "External"

		if (damage > 50) then
			text = "Severe"
		end

		client:AddCombineDisplayMessage("@cTrauma", Color(255, 0, 0, 255), text)

		if (health < 25) then
			client:AddCombineDisplayMessage("@cDroppingVitals", Color(255, 0, 0, 255))
		end

		client.ixTraumaCooldown = CurTime() + 15
	end
end

function Schema:PlayerStaminaLost(client)
	client:AddCombineDisplayMessage("@cStaminaLost", Color(255, 255, 0, 255))
end

function Schema:PlayerStaminaGained(client)
	client:AddCombineDisplayMessage("@cStaminaGained", Color(0, 255, 0, 255))
end

function Schema:GetPlayerPainSound(client)
	if (client:IsCombine()) then
		return "NPC_MetroPolice.Pain"
	end
end

function Schema:GetPlayerDeathSound(client)
	if (client:IsCombine()) then
		local sound = "NPC_MetroPolice.Die"

		for k, v in ipairs(player.GetAll()) do
			if (v:IsCombine()) then
				v:EmitSound(sound)
			end
		end

		return sound
	end
end

function Schema:GetPlayerPunchDamage()
	return 0
end

local voiceChatTypes = {
    ["ic"] = true,
    ["w"] = true,
    ["y"] = true,
    ["radio"] = true,
    ["dispatch"] = true
}
function Schema:PlayerMessageSend(speaker, chatType, text, anonymous, receivers, rawText)
	if IsValid(speaker) then
		if voiceChatTypes[chatType] then
			local class = self.voices.GetClass(speaker, chatType)

			for k, v in ipairs(class) do
				local info = self.voices.Get(v, rawText)

				if (info) then
					local volume = 80

					if (chatType == "w") then
						volume = 60
					elseif (chatType == "y") then
						volume = 150
					elseif (chatType == "dispatch") then
						info.global = true
					end
					
					if (info.sound) then
						if (info.global) then
							netstream.Start(nil, "PlaySound", info.sound)
						else
							local character = speaker:GetCharacter()
							local faction = ix.faction.indices[character:GetFaction()]
							local beeps = faction.typingBeeps or {}
							local snd = istable(info.sound) and info.sound[character:GetGender() or 1] or info.sound

							speaker.bTypingBeep = nil
							ix.util.EmitQueuedSounds(speaker, {snd, beeps[2]}, nil, nil, volume)
						end
					end

					if (speaker:IsCombine() and chatType != "dispatch") then
						return string.format("<:: %s ::>", info.text)
					else
						return info.text
					end
				end
			end

			if (chatType == "ic" or chatType == "w" or chatType == "y") then
				if (speaker:IsCombine()) then
					return string.format("<:: %s ::>", text)
				end
			end
		end
	end
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

-- Функция проверки, нужно ли воспроизводить звук рации при наборе текста
function Schema:ShouldPlayTypingBeep(client, chatType)
	-- Проверяем, валиден ли игрок, жив ли он и есть ли у него загруженный персонаж
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then
		return false
	end

	-- Список чатов, в которых рация должна издавать звуки
	local allowedTypes = {
		["ic"] = true,
		["w"] = true,
		["y"] = true,
		["radio"] = true,
		["dispatch"] = true
	}

	-- Если тип чата не входит в список (например, OOC, LOOC или PM) — не пищим
	if (!chatType or !allowedTypes[chatType]) then
		return false
	end

	return true
end

netstream.Hook("PlayerChatTextChanged", function(client, key)
	if (Schema:ShouldPlayTypingBeep(client, key) and !client.bTypingBeep) then
		local faction = ix.faction.indices[client:GetCharacter():GetFaction()]
		local beeps = faction.typingBeeps

		if istable(beeps) then
			client:EmitSound(beeps[1])
		end

		client.bTypingBeep = true
	end
end)

netstream.Hook("PlayerFinishChat", function(client)
	if (Schema:ShouldPlayTypingBeep(client, "ic") and client.bTypingBeep) then
		local faction = ix.faction.indices[client:GetCharacter():GetFaction()]
		local beeps = faction.typingBeeps

		if istable(beeps) then
			client:EmitSound(beeps[2])
		end

		client.bTypingBeep = nil
	end
end)

-- ============================================================
-- Руки игрока по фракции (viewmodel c_arms)
-- PlayerSetHandsModel в Helix не существует, поэтому переопределяем
-- модель сущности рук серверно в PostPlayerLoadout (после SetupHands).
-- Модель сетевая — клиент увидит её в первом лице.
-- ============================================================
local function GetFactionHands(team)
	-- МПФ / ОТА / ОТА-Элита — стандартные руки Альянса c_arms_combine.
	if FACTION_MPF and team == FACTION_MPF then
		return { model = "models/weapons/c_arms_combine.mdl", skin = 0, body = "00000000" }
	elseif (FACTION_OTA and team == FACTION_OTA) or (FACTION_EOW and team == FACTION_EOW) then
		return { model = "models/weapons/c_arms_combine.mdl", skin = 1, body = "00000000" }
	end
end

local function ApplyFactionHands(client)
	if not IsValid(client) then return end

	local data = GetFactionHands(client:Team())
	if not data then return end

	local hands = client:GetHands()
	if not IsValid(hands) then return end

	hands:SetModel(data.model)
	hands:SetSkin(data.skin)
	hands:SetBodyGroups(data.body)
end

hook.Add("PostPlayerLoadout", "ixFactionHands", function(client)
	ApplyFactionHands(client)
end)

-- /charsetmodel и прочие пересборки рук — обновляем и здесь.
hook.Add("PlayerModelChanged", "ixFactionHands", function(client)
	timer.Simple(0, function() ApplyFactionHands(client) end)
end)

