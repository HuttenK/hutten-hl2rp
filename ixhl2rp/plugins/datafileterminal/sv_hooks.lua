local PLUGIN = PLUGIN

util.AddNetworkString("ixDfBrowserOpen")

PLUGIN.useRadius = 130
PLUGIN.pdaClass  = "pdaremake1" -- класс SWEP'а КПК (lua/weapons/pdaremake1.lua)

-- Ссылка на плагин досье (старый datafile с PLUGIN.stored / HandleDatafile)
local function df()
	return ix.plugin.list["datafile"]
end

-- Игрок рядом с терминалом досье?
function PLUGIN:IsNearTerminal(client)
	if !IsValid(client) then return false end
	for _, ent in ipairs(ents.FindInSphere(client:GetPos(), self.useRadius)) do
		if IsValid(ent) and ent:GetClass() == "ix_datafile_terminal" then
			return true
		end
	end
	return false
end

-- Stationary archives remain independent of FIELDLINK.
function PLUGIN:HasDatafileAccess(client) return self:IsNearTerminal(client) end

-- Собрать список доступных игроку досье.
-- Возвращает: nil  -> нет доступа вообще (нет карты/прав)
--             {}   -> доступ есть, но подходящих записей нет
--             list -> список таблиц {id, name, cid, status, points}
function PLUGIN:BuildList(client)
	local d = df()
	if !d or !istable(d.stored) then return {} end

	local char = client:GetCharacter()
	if !char then return nil end

	local perm = char:ReturnDatafilePermission() or 0
	if perm <= 0 then return nil end

	local list = {}
	for id, v in pairs(d.stored) do
		if !istable(v) then continue end

		local name = isstring(v[1]) and v[1] or ""
		local cid  = isstring(v[2]) and v[2] or ""

		-- пропускаем полностью пустые записи
		if name == "" and (cid == "" or cid == "000-00") then continue end

		-- права на конкретное досье (уровень его защиты)
		local targetPerm = (d.ReturnPermissionByID and d:ReturnPermissionByID(id)) or 0
		if perm < targetPerm then continue end

		local generic = istable(v[4]) and v[4] or {}

		list[#list + 1] = {
			id     = id,
			name   = name,
			cid    = cid,
			status = generic.status or "Citizen",
			points = generic.points or 0,
		}
	end

	table.sort(list, function(a, b)
		return (a.name or "") < (b.name or "")
	end)

	return list
end

-- Вызывается из ENT:Use
function PLUGIN:CardSnapshot(card) return Schema:GetCredentialSnapshot(card) end
function PLUGIN:OpenBrowser(client,terminal)
 if not self:IsNearTerminal(client) or not client:GetCharacter() then return end
 local cards={}
 for _,item in pairs(client:GetItems()) do
  local info=self:CardSnapshot(item)
  if info then cards[#cards+1]=info end
 end
 local target=client:GetEyeTraceNoCursor().Entity
 if IsValid(target) and target:IsPlayer() and target~=client and target:GetPos():DistToSqr(client:GetPos())<=130^2 then
  local info=self:CardSnapshot(target:GetIDCard()); if info then cards[#cards+1]=info end
 end
 local list=self:BuildList(client) or {}
 netstream.Start(client,"ixDfBrowserOpen",{cards=cards,records=list,clearance=client:GetCharacter():ReturnDatafilePermission() or 0})
end
netstream.Hook("ixDfTerminalRefresh",function(client)
 if (client.ixNextCredentialCheck or 0)>CurTime() then return end
 client.ixNextCredentialCheck=CurTime()+1
 PLUGIN:OpenBrowser(client)
end)

-- Внешность владельца (модель/скин/физописание). Асинхронно: для оффлайн-персонажей
-- модель берётся напрямую из ix_characters, поэтому Кляйнер больше не подставляется.
-- cb(model, skin, genetic) вызывается всегда.
local function ResolveCredential(id, generic, cb)
 -- Prefer a loaded, non-revoked card; archived snapshot covers removed cards.
 local best
 for _,item in pairs(ix.Item.instances) do
  if item.isKeycard and tonumber(item:GetData("datafileID",0))==id and not item:GetData("revoked",false) then
   if not best or item:GetID()>best:GetID() then best=item end
  end
 end
 if best then cb(PLUGIN:CardSnapshot(best)); return end
 if istable(generic.credential) then cb(table.Copy(generic.credential)); return end
 -- Legacy archives: recover the actual saved card even when its owner is offline.
 local classes={}
 for name,item in pairs(ix.Item.stored) do if item.isKeycard then classes[#classes+1]=name end end
 if #classes==0 then cb(nil); return end
 local query=mysql:Select("ix_items")
 query:Select("item_id"); query:Select("unique_id"); query:Select("data")
 query:WhereIn("unique_id",classes)
 query:Callback(function(rows)
  local snapshot, newest=nil,-1
  for _,row in ipairs(rows or {}) do
   local data=util.JSONToTable(row.data or "{}") or {}
   if tonumber(data.datafileID)==id and not data.revoked and (tonumber(row.item_id) or 0)>newest then
    local definition=ix.Item.stored[row.unique_id]
    if definition and definition.isKeycard then
     snapshot=PLUGIN:CardSnapshot({isKeycard=true,clearanceLevel=definition.clearanceLevel,departmentLabel=definition.departmentLabel,
      GetData=function(_,key,default) if data[key]~=nil then return data[key] end return default end})
     newest=tonumber(row.item_id) or 0
    end
   end
  end
  cb(snapshot)
 end)
 query:Execute()
end

-- Клиент выбрал досье в меню -> собираем полные данные и открываем окно ixDfView
netstream.Hook("ixDfBrowserSelect", function(client, datafileID)
	datafileID = tonumber(datafileID)
	if !datafileID then return end
	if !PLUGIN:HasDatafileAccess(client) then return end


	local d = df()
	if !d or !istable(d.stored) then return end

	local char = client:GetCharacter()
	if !char then return end

	local perm = char:ReturnDatafilePermission() or 0
	if perm <= 0 then
		client:Notify("Нет доступа: экипируйте действующую ключ-карту SCP.")
		return
	end

	local v = d.stored[datafileID]
	if !istable(v) then
		client:Notify("Досье не найдено.")
		return
	end

	local targetPerm = (d.ReturnPermissionByID and d:ReturnPermissionByID(datafileID)) or 0
	if perm < targetPerm then
		client:Notify("Недостаточно прав для просмотра этого досье.")
		return
	end

	local generic = istable(v[4]) and v[4] or {}
	local records = istable(v[5]) and v[5] or {}

	-- Записи; для MINOR (1) скрываем гражданские записи
	local outRecords = {}
	for _, rec in ipairs(records) do
		if !istable(rec) then continue end
		if perm == 1 and rec.category == "civil" then continue end
		outRecords[#outRecords + 1] = {
			category    = rec.category,
			text        = rec.text,
			unix_time   = rec.unix_time or rec.date,
			points      = rec.points or 0,
			poster_name = rec.poster_name,
		}
	end

	ResolveCredential(datafileID, generic, function(credential)
		if !IsValid(client) or !PLUGIN:IsNearTerminal(client) or !client:GetCharacter() or client:GetCharacter():ReturnDatafilePermission()<math.max(1,targetPerm) then return end

		netstream.Start(client, "ixDfView", {
			id         = datafileID,
			name       = v[1] or "",
			cid        = v[2] or "",
			regid      = v[3] or "",
			status     = generic.status or "Citizen",
			points     = generic.points or 0,
			bol        = generic.bol and true or false,
			bolReason  = generic.bol_reason or "",
			restricted = generic.restricted and true or false,
			lastSeen   = generic.last_seen or 0,
			aparts     = generic.aparts or "N/A",
			credential = credential,
			
			
			ownerCharID = datafileID,
			records    = outRecords,
		})
	end)
end)

-- Сохранение/загрузка размещённых терминалов между рестартами карты
function PLUGIN:SaveData()
	local data = {}
	for _, v in ipairs(ents.FindByClass("ix_datafile_terminal")) do
		data[#data + 1] = { v:GetPos(), v:GetAngles() }
	end
	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if !istable(data) then return end

	for _, v in ipairs(data) do
		local ent = ents.Create("ix_datafile_terminal")
		if !IsValid(ent) then continue end
		ent:SetPos(v[1])
		ent:SetAngles(v[2])
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end
end
