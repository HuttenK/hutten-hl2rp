
local PLUGIN = PLUGIN

PLUGIN.name = "Datafile"
PLUGIN.author = "James"
PLUGIN.description = "Adds citizen datafiles."

ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_hooks.lua")

-- Включить подробный лог /datafile в серверную консоль (true/false).
PLUGIN.Debug = false

-- Безопасный лог: печатает только при PLUGIN.Debug, нигде не падает.
function ix.util.DatafileDebug(fmt, ...)
	if !ix.plugin or !ix.plugin.list then return end
	local p = ix.plugin.list["datafile"]
	if !p or !p.Debug then return end
	local ok, msg = pcall(string.format, fmt, ...)
	MsgN("[DATAFILE] " .. (ok and msg or tostring(fmt)))
end

do
	local COMMAND = {}
	COMMAND.description = "View the datafile of someone."
	COMMAND.arguments = {
		ix.type.string,
		bit.bor(ix.type.string, ix.type.optional)
	}
	COMMAND.argumentNames = {"CitizenID", "RegID (optional)"}

	-- Нормализация: убираем дефисы/пробелы для сравнения CID
	local function normCID(cid)
		return tostring(cid or ""):gsub("[%- ]", ""):lower()
	end

	-- query: строка поиска. Ищем сначала по CID, потом по имени.
	-- Возвращает: found(bool), opened(bool) — opened=true если HandleDatafile реально отправил досье.
	local function findAndOpen(client, query, queryNorm)
		-- 1. Память — по CID
		for id, v in pairs(PLUGIN.stored) do
			if isstring(v[2]) and v[2] != "" and v[2] != "000-00"
				and normCID(v[2]) == queryNorm then
				ix.util.DatafileDebug("findAndOpen: совпадение по CID id=%s cid=%s", id, tostring(v[2]))
				local opened = PLUGIN:HandleDatafile(client, id)
				return true, opened
			end
		end
		-- 2. Память — по имени
		local queryLow = query:lower()
		for id, v in pairs(PLUGIN.stored) do
			if isstring(v[1]) and v[1]:lower() == queryLow then
				ix.util.DatafileDebug("findAndOpen: совпадение по имени id=%s name=%s", id, tostring(v[1]))
				local opened = PLUGIN:HandleDatafile(client, id)
				return true, opened
			end
		end
		return false, false
	end

	function COMMAND:OnRun(client, citizenid, regid)
		local query     = citizenid .. (isstring(regid) and (" " .. regid) or "")
		local queryNorm = normCID(query)

		ix.util.DatafileDebug("/datafile запущена игроком %s | query=%q norm=%q | stored=%d записей",
			IsValid(client) and client:Name() or "?", query, queryNorm, table.Count(PLUGIN.stored))

		-- Быстрый путь: ищем в памяти
		local found, opened = findAndOpen(client, query, queryNorm)
		if found then
			-- Нашли запись, но HandleDatafile отказал (нет прав / ограничено) — сообщаем, не молчим.
			if !opened and IsValid(client) then
				client:Notify("Досье найдено, но доступ к нему запрещён (нет прав или файл ограничен): " .. query)
			end
			return
		end

		-- Медленный путь: запрашиваем ix_items напрямую (оффлайн-карточки)
		local q = mysql:Select("ix_items")
		q:Select("data")
		q:Callback(function(rows)
			if !IsValid(client) then return end
			if !istable(rows) then
				client:Notify("Досье не найдено: " .. query)
				return
			end
			local queryLow = query:lower()
			for _, row in ipairs(rows) do
				local raw = row.data
				if !raw or !raw:find("datafileID", 1, true) then continue end
				local d = util.JSONToTable(raw)
				if !d then continue end
				local dID = tonumber(d.datafileID)
				if !dID or dID == 0 then continue end
				local itemCID  = tostring(d.cid  or "")
				local itemName = tostring(d.name or "")
				-- совпадение по CID (не заглушка) или по имени
				local cidMatch  = itemCID != "" and itemCID != "000-00"
					and normCID(itemCID) == queryNorm
				local nameMatch = itemName:lower() == queryLow
				if !cidMatch and !nameMatch then continue end
				-- бэкфилл памяти
				if !PLUGIN.stored[dID] then PLUGIN.stored[dID] = {} end
				local entry = PLUGIN.stored[dID]
				entry[1] = itemName ~= "" and itemName or (entry[1] or "")
				entry[2] = itemCID  ~= "" and itemCID  or (entry[2] or "")
				entry[3] = tostring(d.number or entry[3] or "")
				ix.util.DatafileDebug("slow-path: найдено в ix_items dID=%s cid=%s", tostring(dID), itemCID)
				local opened = PLUGIN:HandleDatafile(client, dID)
				if !opened and IsValid(client) then
					client:Notify("Досье найдено, но доступ запрещён (нет прав или файл ограничен): " .. query)
				end
				return
			end
			ix.util.DatafileDebug("slow-path: совпадений в ix_items нет для %q", query)
			client:Notify("Досье не найдено: " .. query)
		end)
		q:Execute()
	end



	ix.command.Add("Datafile", COMMAND)

	COMMAND = {}
	COMMAND.arguments = {ix.type.player}
	COMMAND.superAdminOnly = true

	function COMMAND:OnRun(client, target)
		PLUGIN:ClearDatafile(target)
	end

	ix.command.Add("ClearDatafile", COMMAND)

	COMMAND = {}
	COMMAND.description = "Manage the datafile of someone."
	COMMAND.arguments = {ix.type.player}

	function COMMAND:OnRun(client, target)
		local permission = PLUGIN:ReturnPermission(client)

		if (permission == DATAFILE_PERMISSION_ELEVATED) then
			PLUGIN:ReturnDatafile(target, nil, true, function(result)
				netstream.Start(client, "CreateManagementPanel", target, result)
			end)
		else
			return "@datafileNotAuthorizedManage"
		end
	end

	ix.command.Add("ManageDatafile", COMMAND)

	COMMAND = {}
	COMMAND.description = "Make someone their datafile (un)restricted."
	COMMAND.arguments = {
		ix.type.player,
		bit.bor(ix.type.string, ix.type.optional)
	}

	function COMMAND:OnRun(client, target, reason)
		if (!reason or reason == "") then
			reason = nil
		end

		if (PLUGIN:ReturnPermission(client) >= DATAFILE_PERMISSION_FULL) then
			if (reason) then
				PLUGIN:SetRestricted(true, reason, target, client)

				return target:Name() .. "'s file has been restricted."
			else
				PLUGIN:SetRestricted(false, "", target, client)

				return target:Name() .. "'s file has been unrestricted."
			end
		else
			return "You do not have access to this datafile!"
		end
	end

	ix.command.Add("RestrictDatafile", COMMAND)

	/*
	COMMAND = {}
	COMMAND.description = "Rewards SC to a group of units. * = all units, PT-# = reward a PT."
	COMMAND.arguments = {
		ix.type.number,
		ix.type.string,
		ix.type.string
	}

	function COMMAND:OnCheckAccess(client)
		return client:Team() == FACTION_OVERWATCH
	end

	function COMMAND:OnRun(client, amount, reason, targets)
		amount = math.ceil(amount)

		if (amount <= 0 or reason == "") then
			return "@invalidArg", 1
		end

		if (targets == "*") then
			for _, v in ipairs(player.GetAll()) do
				if (v:Team() == FACTION_MPF) then
					PLUGIN:AddEntry("civil", reason, amount, v, client)
				end
			end

			client:Notify("All active units have been rewarded with " .. amount .. " SC.")
		else
			local patrolTeam = targets:lower():match("pt%-(%d+)")

			if (patrolTeam) then
				local pluginTable = ix.plugin.list["patrolmenu"]

				if (pluginTable) then
					local team = pluginTable.teams[tonumber(patrolTeam)]

					if (team) then
						for k, _ in pairs(team) do
							if (IsValid(k) and k:Team() == FACTION_MPF) then
								PLUGIN:AddEntry("civil", reason, amount, k, client)
							end
						end

						client:Notify("PT-" .. patrolTeam .. " has been rewarded with " .. amount .. " SC.")
					end
				else
					ErrorNoHalt("[Helix] Patrol Menu plugin is missing!\n")
				end
			end
		end
	end

	ix.command.Add("MassReward", COMMAND)
	*/
end

-- luacheck: globals DATAFILE_PERMISSION_NONE DATAFILE_PERMISSION_MINOR DATAFILE_PERMISSION_MEDIUM DATAFILE_PERMISSION_FULL DATAFILE_PERMISSION_ELEVATED
DATAFILE_PERMISSION_NONE = 0
DATAFILE_PERMISSION_MINOR = 1
DATAFILE_PERMISSION_MEDIUM = 2
DATAFILE_PERMISSION_FULL = 3
DATAFILE_PERMISSION_ELEVATED = 4

-- All the categories possible. Yes, the names are quite annoying.
PLUGIN.Categories = {
	["med"] = true,     -- Medical note.
	["union"] = true,   -- Union (CWU, WI, UP) type note.
	["civil"] = true,    -- Civil Protection/CTA type note.
	["reg"] = true
}

-- Permissions for the numerous factions.
PLUGIN.Permissions = PLUGIN.Permissions or {}

-- All the civil statuses. Just for verification purposes.
PLUGIN.CivilStatus = {
	["Anti-Citizen"] = -50,
	["Citizen"] = 0,
	["Black"] = 5,
	["Brown"] = 15,
	["Orange"] = 18,
	["Red"] = 20,
	["Green"] = 30,
	["Blue"] = 45,
	["White"] = 65,
	["Gold"] = 80,
	["Platinum"] = 100
}

PLUGIN.Default = {
	GenericData = {
		bol = false,
		bol_reason = "",
		restricted = false,
		restricted_reason = "",
		status = "Citizen",
		last_seen = os.time(),
		aparts = "N/A"
	},
	CivilianData = {
		category = "union", -- med, union, civil
		text = "TRANSFERRED TO DISTRICT WORKFORCE.",
		date = os.time(),
		points = 0,
		poster_name = "Overwatch",
		poster_steam = 0
	},
	CombineData = {
		category = "union", -- med, union, civil
		text = "INSTATED AS CIVIL PROTECTOR.",
		date = os.time(),
		points = 0,
		poster_name = "Overwatch",
		poster_steam = 0
	},
}

-- Переопределяем ReturnDatafilePermission в shared-файле чтобы гарантированно загружалось.
-- Если в данных карточки нет флага доступа — берём из шаблона предмета (ix.Item.stored).
-- Это покрывает старые карточки, выданные до прописания флагов в ITEM.access.
if SERVER then
	local CHAR = ix.meta.character

	function CHAR:ReturnDatafilePermission()
		local cid = self:GetPlayer():GetIDCard()
		if !cid then return 0 end

		local accesses = cid:GetData("access", {})
		local hasFlag = accesses["DATAFILE_ELEVATED"] or accesses["DATAFILE_FULL"]
			or accesses["DATAFILE_MEDIUM"] or accesses["DATAFILE_MINOR"]

		if !hasFlag then
			local template = ix.Item.stored[cid.uniqueID]
			if template and istable(template.access) then
				accesses = template.access
			end
		end

		if accesses["DATAFILE_ELEVATED"] then return 4
		elseif accesses["DATAFILE_FULL"] then return 3
		elseif accesses["DATAFILE_MEDIUM"] then return 2
		elseif accesses["DATAFILE_MINOR"] then return 1
		end

		return 0
	end
end
