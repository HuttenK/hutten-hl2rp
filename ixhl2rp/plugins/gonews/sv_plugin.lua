local PLUGIN = PLUGIN

PLUGIN.news    = PLUGIN.news or {}
PLUGIN.nextID  = PLUGIN.nextID or 1
PLUGIN.editorRadius = 140

util.AddNetworkString("gonews.openeditor")

-- Управлять новостями может кто угодно (терминал открыт для всех игроков).
local function CanManage(client)
	return IsValid(client) and client:IsPlayer()
end
PLUGIN.CanManage = CanManage

-- Рядом ли игрок с терминалом-редактором
function PLUGIN:NearEditor(client)
	if !IsValid(client) then return false end
	for _, e in ipairs(ents.FindInSphere(client:GetPos(), self.editorRadius)) do
		if IsValid(e) and e:GetClass() == "ix_gonews_editor" then
			return true
		end
	end
	return false
end

-- Рассылка списка новостей (target = игрок/таблица, иначе всем)
function PLUGIN:SyncNews(target)
	netstream.Start(target or player.GetAll(), "gonews.sync", self.news)
end

function PLUGIN:AddNews(client, info)
	if !istable(info) then return end

	local imageType = (info.imageType == "material") and "material" or "url"

	local entry = {
		id        = self.nextID,
		title     = string.sub(tostring(info.title  or "Без заголовка"), 1, 140),
		source    = string.sub(tostring(info.source or "Гражданская Оборона"), 1, 80),
		text      = string.sub(tostring(info.text   or ""), 1, 8000),
		image     = string.sub(tostring(info.image  or ""), 1, 500),
		imageType = imageType,
		time      = os.time(),
		author    = IsValid(client) and client:Name() or "SYSTEM",
	}

	self.nextID = self.nextID + 1
	table.insert(self.news, 1, entry) -- новые сверху

	-- ограничим хранилище разумным числом
	while #self.news > 100 do
		table.remove(self.news, #self.news)
	end

	self:SaveData()
	self:SyncNews()
end

function PLUGIN:RemoveNews(id)
	id = tonumber(id)
	if !id then return end

	for i, v in ipairs(self.news) do
		if v.id == id then
			table.remove(self.news, i)
			break
		end
	end

	self:SaveData()
	self:SyncNews()
end

-- ==== Сохранение: новости + позиции размещённых терминалов ====
function PLUGIN:SaveData()
	local terminals = {}

	for _, e in ipairs(ents.FindByClass("ix_gonews_terminal")) do
		terminals[#terminals + 1] = { e:GetPos(), e:GetAngles(), "reader" }
	end
	for _, e in ipairs(ents.FindByClass("ix_gonews_editor")) do
		terminals[#terminals + 1] = { e:GetPos(), e:GetAngles(), "editor" }
	end

	self:SetData({
		news      = self.news,
		nextID    = self.nextID,
		terminals = terminals,
	})
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if !istable(data) then return end

	self.news   = istable(data.news) and data.news or {}
	self.nextID = tonumber(data.nextID) or 1

	for _, t in ipairs(data.terminals or {}) do
		local class = (t[3] == "editor") and "ix_gonews_editor" or "ix_gonews_terminal"
		local e = ents.Create(class)
		if IsValid(e) then
			e:SetPos(t[1])
			e:SetAngles(t[2])
			e:Spawn()

			local phys = e:GetPhysicsObject()
			if IsValid(phys) then phys:EnableMotion(false) end
		end
	end
end

-- Синхронизируем при заходе персонажа
function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if IsValid(client) then
			PLUGIN:SyncNews(client)
		end
	end)
end

-- ==== Приём от редактора ====
netstream.Hook("gonews.post", function(client, info)
	if !CanManage(client) then return end
	if !PLUGIN:NearEditor(client) then return end
	PLUGIN:AddNews(client, info)
end)

netstream.Hook("gonews.remove", function(client, id)
	if !CanManage(client) then return end
	if !PLUGIN:NearEditor(client) then return end
	PLUGIN:RemoveNews(id)
end)
