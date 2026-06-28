local PLUGIN = PLUGIN
PLUGIN.stored = PLUGIN.stored or {}

-- Обновляет stored из item-инстансов и бэкфиллит NULL-cid в БД
local function BackfillCIDFromItems(stored)
	for _, item in pairs(ix.Item.instances) do
		if !item.GetData then continue end
		local dID = tonumber(item:GetData("datafileID"))
		if !dID or dID == 0 then continue end
		local cid = item:GetData("cid", "")
		if cid == "" then continue end
		if !stored[dID] then stored[dID] = {} end
		local entry = stored[dID]
		entry[1] = item:GetData("name",   entry[1] or "")
		entry[2] = cid
		entry[3] = item:GetData("number", entry[3] or "")
		entry[6] = item:GetData("access", entry[6] or {})
		-- Бэкфилл в БД (только один раз за сессию)
		if entry._cidFixed then continue end
		entry._cidFixed = true
		local q = mysql:Update("ix_datafiles")
		q:Update("character_name", entry[1])
		q:Update("cid",            cid)
		q:Update("regid",          entry[3] or "")
		q:Where("datafile_id",     dID)
		q:Execute()
	end
end

function PLUGIN:LoadData()
	local query = mysql:Create("ix_datafiles")
		query:Create("datafile_id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("character_name", "TEXT DEFAULT NULL")
		query:Create("cid", "TEXT DEFAULT NULL")
		query:Create("regid", "TEXT DEFAULT NULL")
		query:Create("genericdata", "TEXT DEFAULT NULL")
		query:Create("datafile", "TEXT DEFAULT NULL")
		query:Create("access", "TEXT DEFAULT NULL")
		query:PrimaryKey("datafile_id")
	query:Execute()

	self.stored = {}
	self.datafiles_save = {}

	query = mysql:Select("ix_datafiles")
		query:Select("datafile_id")
		query:Select("character_name")
		query:Select("cid")
		query:Select("regid")
		query:Select("genericdata")
		query:Select("datafile")
		query:Select("access")
		query:Callback(function(result)
			if istable(result) and #result > 0 then
				for k, v in pairs(result) do
					local id = tonumber(v.datafile_id)

					self.stored[id] = {
						[1] = v.character_name,
						[2] = v.cid,
						[3] = v.regid,
						[4] = util.JSONToTable(v.genericdata),
						[5] = util.JSONToTable(v.datafile),
						[6] = util.JSONToTable(v.access)
					}
				end
			end
			-- Бэкфилл из инстансов (для уже загруженных карточек)
			BackfillCIDFromItems(self.stored)
			-- Основной бэкфилл: читаем CID напрямую из ix_items (покрывает оффлайн-игроков)
			timer.Simple(1, function()
				local q = mysql:Select("ix_items")
				q:Select("data")
				q:Callback(function(rows)
					if !istable(rows) then return end
					for _, row in ipairs(rows) do
						local raw = row.data
						if !raw or !raw:find("datafileID", 1, true) then continue end
						local d = util.JSONToTable(raw)
						if !d then continue end
						local dID = tonumber(d.datafileID)
						local cid  = d.cid
						if !dID or dID == 0 or !isstring(cid) or cid == "" then continue end
						if !PLUGIN.stored[dID] then PLUGIN.stored[dID] = {} end
						local entry = PLUGIN.stored[dID]
						if !entry[2] or entry[2] == "" then
							entry[1] = d.name   or entry[1] or ""
							entry[2] = cid
							entry[3] = d.number or entry[3] or ""
							-- Заодно исправляем в ix_datafiles
							if !entry._cidFixed then
								entry._cidFixed = true
								local upd = mysql:Update("ix_datafiles")
								upd:Update("character_name", entry[1])
								upd:Update("cid",            cid)
								upd:Update("regid",          entry[3])
								upd:Where("datafile_id",     dID)
								upd:Execute()
							end
						end
					end
				end)
				q:Execute()
			end)
		end)
	query:Execute()
end

function PLUGIN:OnWipeTables()
	local query = mysql:Drop("ix_datafiles")
	query:Execute()
end

function PLUGIN:SaveData()

	local saved = {}
	for k, id in ipairs(self.datafiles_save) do
		if saved[id] then continue end
		
		saved[id] = true

		local v = self.stored[id]
		local query = mysql:Update("ix_datafiles")
			query:Where("datafile_id", id)
			query:Update("character_name", v[1])
			query:Update("cid", v[2])
			query:Update("regid", v[3])
			query:Update("genericdata", v[4] and util.TableToJSON(v[4]) or "[]")
			query:Update("datafile", v[5] and util.TableToJSON(v[5]) or "[]")
			query:Update("access", v[6] and util.TableToJSON(v[6]) or "[]")
		query:Execute()
	end

	self.datafiles_save = {}
end

function PLUGIN:CreateDatafile(name, cid, regid, access, callback)
	local GenericData = {
		bol = false,
		bol_reason = "",
		points = 0,
		restricted = false,
		restricted_reason = "",
		status = "Citizen",
		last_seen = os.time()
	}

	local CivilianData = {
		{
			category = "union",
			text = "TRANSFERRED TO DISTRICT WORKFORCE.",
			unix_time = os.time(),
			points = 0,
			poster_name = "Overwatch",
			poster_color = Color(50, 100, 150),
			poster_steam = 0
		}
	}

	name = name or ""
	cid = cid or ""
	regid = regid or ""
	access = access or {}

	local query = mysql:Insert("ix_datafiles")
		query:Insert("character_name", name)
		query:Insert("cid", cid)
		query:Insert("regid", regid)
		query:Insert("genericdata", util.TableToJSON(GenericData))
		query:Insert("datafile", util.TableToJSON(CivilianData))
		query:Insert("access", util.TableToJSON(access))
		query:Callback(function(result, status, lastID)
			if callback then
				callback(lastID)
			end

			local id = tonumber(lastID)

			self.stored[id] = {
				[1] = name,
				[2] = cid,
				[3] = regid,
				[4] = GenericData,
				[5] = CivilianData,
				[6] = access,
			}

			table.insert(self.datafiles_save, id)
		end)
	query:Execute()
end

function PLUGIN:OnIDCardInstanced(item)
	if item:GetData("datafileID", 0) == 0 then
		local name = item:GetData("name", "")
		local cid = item:GetData("cid", "")
		local regid = item:GetData("number", "")
		local access = item:GetData("access", {})

		self:CreateDatafile(name, cid, regid, access, function(id)
			print("Datafile created for ", item, id)
			item:SetData("datafileID", id)
		end)
	else
		-- Синхронизируем stored с item-данными (cid мог быть NULL в старых записях БД)
		local id = tonumber(item:GetData("datafileID", 0))
		if id and id > 0 then
			if !self.stored[id] then self.stored[id] = {} end
			self.stored[id][1] = item:GetData("name", "")
			self.stored[id][2] = item:GetData("cid", "")
			self.stored[id][3] = item:GetData("number", "")
			self.stored[id][6] = item:GetData("access", {})
		end
		print("Datafile loaded for ", item)
	end
end

function PLUGIN:OnIDCardUpdated(item)
	if item:GetData("datafileID", 0) != 0 then
		local id = tonumber(item:GetData("datafileID", 0))

		if self.stored[id] then
			local name = item:GetData("name", "")
			local cid = item:GetData("cid", "")
			local regid = item:GetData("number", "")
			local access = item:GetData("access", {})

			self.stored[id][1] = name
			self.stored[id][2] = cid
			self.stored[id][3] = regid
			self.stored[id][6] = access
		end

		table.insert(self.datafiles_save, id)
	end
end

function PLUGIN:HandleDatafile(player, target)
	if istable(target) then
		-- Поиск в памяти (stored)
		for id, v in pairs(self.stored) do
			if target[1] and v[2] == target[1] then
				target = id
				break
			end
		end

		-- Fallback: сканируем все item-инстансы (карточки в хранилищах, на полу и т.д.)
		if istable(target) then
			for _, item in pairs(ix.Item.instances) do
				if !item.GetData then continue end
				if item:GetData("cid", "") == target[1] then
					local dID = tonumber(item:GetData("datafileID"))
					if dID and dID > 0 then
						-- Заодно бэкфиллим память
						if !self.stored[dID] then self.stored[dID] = {} end
						self.stored[dID][2] = target[1]
						self.stored[dID][1] = item:GetData("name", "")
						self.stored[dID][3] = item:GetData("number", "")
						target = dID
						break
					end
				end
			end
		end
	end

	local playerValue = player:GetCharacter():ReturnDatafilePermission()
	local targetValue
	player.lastDatafile = nil

	-- Если playerValue=0 (нет флага в данных карты) — проверяем шаблон предмета напрямую
	if playerValue == 0 then
		local card = player:GetIDCard()
		if card then
			local tmpl = ix.Item.stored[card.uniqueID]
			if tmpl and istable(tmpl.access) then
				local ta = tmpl.access
				if     ta["DATAFILE_ELEVATED"] then playerValue = 4
				elseif ta["DATAFILE_FULL"]     then playerValue = 3
				elseif ta["DATAFILE_MEDIUM"]   then playerValue = 2
				elseif ta["DATAFILE_MINOR"]    then playerValue = 1
				end
			end
		else
			ix.util.DatafileDebug("HandleDatafile: у игрока %s НЕТ экипированной CID-карты (GetIDCard=nil) -> playerValue=0",
				IsValid(player) and player:Name() or "?")
		end
	end

	ix.util.DatafileDebug("HandleDatafile: target=%s (%s) playerValue=%s",
		tostring(target), type(target), tostring(playerValue))

	if isstring(target) or isnumber(target) then
		targetValue = self:ReturnPermissionByID(target)
		ix.util.DatafileDebug("HandleDatafile: targetValue(уровень защиты)=%s", tostring(targetValue))

		if playerValue >= targetValue then
			if playerValue == 0 then
				ix.util.DatafileDebug("ОТКАЗ: playerValue=0 (нет прав на просмотр досье)")
				if IsValid(player) then player:Notify("У вас нет доступа к датафайлам (карта без флага доступа).") end
				return false
			end

			local dID, datafile, genericdata = self:ReturnDatafileByID(target)
			-- Защита от NULL в БД
			genericdata = istable(genericdata) and genericdata or {}
			datafile    = istable(datafile)    and datafile    or {}

			local bTargetIsRestricted, restrictedText = self:IsRestricted(genericdata)
			local data = {}
			local db = self.stored[tonumber(dID)]
			if db then
				data = {db[1], db[2], db[3], dID}
			end

			if playerValue == 1 then
				if bTargetIsRestricted then
					ix.util.DatafileDebug("ОТКАЗ: досье ограничено, а у игрока MINOR(1)")
					if IsValid(player) then player:Notify("Это досье ограничено — доступ только для старших званий.") end
					return false
				end

				local restrictedDatafile = table.Copy(datafile)
				for k, v in pairs(restrictedDatafile) do
					if v.category == "civil" then
						table.remove(restrictedDatafile, k)
					end
				end

				ix.util.DatafileDebug("ОТПРАВКА: CreateRestrictedDatafile dID=%s", tostring(dID))
				netstream.Start(player, "CreateRestrictedDatafile", target, genericdata, restrictedDatafile, data)
			else
				ix.util.DatafileDebug("ОТПРАВКА: CreateFullDatafile dID=%s записей=%d", tostring(dID), table.Count(datafile))
				netstream.Start(player, "CreateFullDatafile", target, genericdata, datafile, data)
				net.Start("PopulateDatafilePoints")
					net.WriteInt(genericdata.points or 0, 16)
				net.Send(player)
			end

			player.lastDatafile = tonumber(dID)
			return true
		elseif playerValue < targetValue then
			ix.util.DatafileDebug("ОТКАЗ: playerValue(%s) < targetValue(%s)", tostring(playerValue), tostring(targetValue))
			if IsValid(player) then player:Notify("Недостаточно прав: уровень защиты этого досье выше вашего доступа.") end
			return false
		end
	else
		if !IsValid(target) then return false end
		local targetCharacter = target:GetCharacter()
		if !targetCharacter then return false end

		targetValue = targetCharacter:ReturnDatafilePermission()

		if playerValue >= targetValue then
			if playerValue == 0 then
				--Clockwork.player:Notify(player, "You are not authorized to access this datafile.")

				return false
			end

			local dID, datafile, genericdata = targetCharacter:ReturnDatafile()
			local bTargetIsRestricted, restrictedText = self:IsRestricted(genericdata)
			local data = {}
			local db = self.stored[tonumber(dID)]
			if db then
				data = {db[1], db[2], db[3], dID}
			end

			if playerValue == 1 then
				if bTargetIsRestricted then
					--Clockwork.player:Notify(player, "This datafile has been restricted; access denied. REASON: " .. restrictedText)

					return false
				end

				local restrictedDatafile = table.Copy(datafile)
				for k, v in pairs(restrictedDatafile) do
					if v.category == "civil" then
						table.remove(restrictedDatafile, k)
					end
				end

				netstream.Start(player, "CreateRestrictedDatafile", target, genericdata, restrictedDatafile, data)
			else
				netstream.Start(player, "CreateFullDatafile", target, genericdata, datafile, data)
				net.Start("PopulateDatafilePoints")
					net.WriteInt(genericdata.points or 0, 16)
				net.Send(player)
			end

			player.lastDatafile = tonumber(dID)
			return true
		elseif playerValue < targetValue then
			--Clockwork.player:Notify(player, "You are not authorized to access this datafile.")

			return false
		end
	end
end

function PLUGIN:CharacterLoaded(character)
	timer.Simple(1, function()
		local player = character:GetPlayer()
		local cid = player:GetIDCard()

		if cid then
			player.ixDatafile = cid:GetData("datafileID")
		end
	end)
end

function PLUGIN:RefreshDatafile(client, datafileID)
	datafileID = tonumber(datafileID) or 0

	local rf = RecipientFilter()
	rf:AddAllPlayers()

	local data = {}
	local db = self.stored[datafileID]
	if db then
		data = {db[1], db[2], db[3], datafileID}
	end

	for _, v in ipairs(rf:GetPlayers()) do
		if v.lastDatafile != datafileID or !v:GetCharacter() then
			rf:RemovePlayer(v)
		else
			continue
		end
	end

	netstream.Start(rf:GetPlayers(), "RefreshDatafile", db[4], db[5], data)
end

netstream.Hook("UpdateLastSeen", function(client, datafileID)
	local char = client:GetCharacter()

	if (char:ReturnDatafilePermission() < 1) then return end
	if PLUGIN:IsRestricted((PLUGIN.stored[tonumber(datafileID)] or {})[4]) then return end
	if !PLUGIN:HasDatafileAccess(char, datafileID) then return end

	PLUGIN:UpdateLastSeen(datafileID)
	PLUGIN:RefreshDatafile(client, datafileID)
end)

netstream.Hook("UpdateCivilStatus", function(client, datafileID, civilStatus)
	local char = client:GetCharacter()

	if (char:ReturnDatafilePermission() < 2) then return end
	if PLUGIN:IsRestricted((PLUGIN.stored[tonumber(datafileID)] or {})[4]) then return end
	if !PLUGIN:HasDatafileAccess(char, datafileID) then return end

	PLUGIN:SetCivilStatus(datafileID, civilStatus, client, char)
	PLUGIN:RefreshDatafile(client, datafileID)
end) --{target, tier})

netstream.Hook("AddDatafileEntry", function(client, datafileID, category, text, points)
	local char = client:GetCharacter()

	if ((char:ReturnDatafilePermission() <= 1 && category == "civil") || char:ReturnDatafilePermission() == 0) then return end
	if PLUGIN:IsRestricted((PLUGIN.stored[tonumber(datafileID)] or {})[4]) then return end
	if !PLUGIN:HasDatafileAccess(char, datafileID) then return end

	PLUGIN:AddEntry(client, datafileID, category, text, points, false)
end) --{target, category, text, points});

netstream.Hook("SetBOL", function(client, datafileID)
	local char = client:GetCharacter()

	if (char:ReturnDatafilePermission() < 1) then return end
	if PLUGIN:IsRestricted((PLUGIN.stored[tonumber(datafileID)] or {})[4]) then return end
	if !PLUGIN:HasDatafileAccess(char, datafileID) then return end

	PLUGIN:SetBOL(client, datafileID, nil)
	PLUGIN:RefreshDatafile(client, datafileID)
end) --{self.Player});

netstream.Hook("RemoveDatafileEntry", function(client, datafileID, key, date, category, text)
	local char = client:GetCharacter()

	if (char:ReturnDatafilePermission() < 4) then return end

	--if (char:ReturnDatafilePermission() < 4) then return end
end) --{target, key, date, category, text})

netstream.Hook("RefreshDatafile", function(client, datafileID)
	PLUGIN:HandleDatafile(client, datafileID)
end) --target)

netstream.Hook("SetRegistryEntry", function(client, datafileID, text)
	local char = client:GetCharacter()

	if (char:ReturnDatafilePermission() < 1) then return end
	if PLUGIN:IsRestricted((PLUGIN.stored[tonumber(datafileID)] or {})[4]) then return end
	if !PLUGIN:HasDatafileAccess(char, datafileID) then return end

	PLUGIN:SetRegistry(client, datafileID, text);
	PLUGIN:RefreshDatafile(client, datafileID)
end);

