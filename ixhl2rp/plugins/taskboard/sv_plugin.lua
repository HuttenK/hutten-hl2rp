local PLUGIN = PLUGIN

PLUGIN.tasks  = PLUGIN.tasks or {}
PLUGIN.nextID = PLUGIN.nextID or 1

-- ==== Доступ / проверки ====
local function CanModerate(client)
	if (!IsValid(client)) then return false end
	return client:IsAdmin() or client:IsSuperAdmin()
end
PLUGIN.CanModerate = CanModerate

-- Рядом ли игрок с любым терминалом доски.
function PLUGIN:NearTerminal(client)
	if (!IsValid(client)) then return false end

	for _, e in ipairs(ents.FindInSphere(client:GetPos(), self.useRadius)) do
		if (IsValid(e) and e:GetClass() == "ix_taskboard") then
			return true
		end
	end

	return false
end

-- Копия списка БЕЗ деталей — её видят все. Детали приходят только принявшему.
function PLUGIN:SanitizedTasks()
	local out = {}

	for i, t in ipairs(self.tasks) do
		out[i] = {
			id         = t.id,
			title      = t.title,
			summary    = t.summary,
			reward     = t.reward,
			posterID   = t.posterID,
			posterName = t.posterName,
			time       = t.time,
			status     = t.status,
			takenName  = t.takenName,
		}
	end

	return out
end

function PLUGIN:SyncTasks(target)
	netstream.Start(target or player.GetAll(), "taskboard.sync", self:SanitizedTasks())
end

function PLUGIN:GetTask(id)
	id = tonumber(id)
	if (!id) then return end

	for _, t in ipairs(self.tasks) do
		if (t.id == id) then return t end
	end
end

-- Сколько открытых заданий висит у данного персонажа.
function PLUGIN:CountOpenForChar(charID)
	local n = 0

	for _, t in ipairs(self.tasks) do
		if (t.posterID == charID) then
			n = n + 1
		end
	end

	return n
end

function PLUGIN:AddTask(client, info)
	if (!istable(info)) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	local lim = self.limits

	local entry = {
		id         = self.nextID,
		title      = string.sub(tostring(info.title   or "Без названия"), 1, lim.title),
		summary    = string.sub(tostring(info.summary or ""), 1, lim.summary),
		details    = string.sub(tostring(info.details or ""), 1, lim.details),
		reward     = string.sub(tostring(info.reward  or ""), 1, lim.reward),
		posterID   = character:GetID(),
		posterName = character:GetName(),
		time       = os.time(),
		status     = "open",
	}

	self.nextID = self.nextID + 1
	table.insert(self.tasks, 1, entry) -- новые сверху

	while (#self.tasks > 100) do
		table.remove(self.tasks, #self.tasks)
	end

	self:SaveData()
	self:SyncTasks()
end

function PLUGIN:RemoveTask(id)
	id = tonumber(id)
	if (!id) then return end

	for i, t in ipairs(self.tasks) do
		if (t.id == id) then
			table.remove(self.tasks, i)
			break
		end
	end

	self:SaveData()
	self:SyncTasks()
end

-- Найти игрока-постера по ID персонажа (если он онлайн).
local function FindPlayerByCharID(charID)
	for _, ply in ipairs(player.GetAll()) do
		local char = ply:GetCharacter()
		if (char and char:GetID() == charID) then
			return ply
		end
	end
end

-- ==== Сохранение: задания + позиции терминалов ====
function PLUGIN:SaveData()
	local terminals = {}

	for _, e in ipairs(ents.FindByClass("ix_taskboard")) do
		terminals[#terminals + 1] = { e:GetPos(), e:GetAngles() }
	end

	self:SetData({
		tasks     = self.tasks,
		nextID    = self.nextID,
		terminals = terminals,
	})
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if (!istable(data)) then return end

	self.tasks  = istable(data.tasks) and data.tasks or {}
	self.nextID = tonumber(data.nextID) or 1

	for _, t in ipairs(data.terminals or {}) do
		local e = ents.Create("ix_taskboard")

		if (IsValid(e)) then
			e:SetPos(t[1])
			e:SetAngles(t[2])
			e:Spawn()

			local phys = e:GetPhysicsObject()
			if (IsValid(phys)) then phys:EnableMotion(false) end
		end
	end
end

function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if (!IsValid(client)) then return end

		self:SyncTasks(client)

		-- Вернуть детали по заданиям, которые этот персонаж уже взял (кэш на клиенте теряется при релоге).
		local character = client:GetCharacter()
		if (!character) then return end

		local charID = character:GetID()

		for _, t in ipairs(self.tasks) do
			if (t.takenID == charID and t.details) then
				netstream.Start(client, "taskboard.details", t.id, t.details)
			end
		end
	end)
end

-- ==== Приём от клиента ====
netstream.Hook("taskboard.post", function(client, info)
	if (!PLUGIN:NearTerminal(client)) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	if (PLUGIN:CountOpenForChar(character:GetID()) >= PLUGIN.maxOpenPerChar) then
		client:Notify("У вас уже слишком много открытых объявлений.")
		return
	end

	if (!istable(info) or !info.title or string.Trim(tostring(info.title)) == "") then
		return
	end

	PLUGIN:AddTask(client, info)
	client:Notify("Объявление размещено.")
end)

netstream.Hook("taskboard.accept", function(client, id)
	if (!PLUGIN:NearTerminal(client)) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	local task = PLUGIN:GetTask(id)
	if (!task) then return end

	if (task.posterID == character:GetID()) then
		client:Notify("Нельзя взять собственное объявление.")
		return
	end

	if (task.status != "open") then
		client:Notify("Это объявление уже кто-то взял.")
		return
	end

	task.status     = "taken"
	task.takenID    = character:GetID()
	task.takenName  = character:GetName()

	PLUGIN:SaveData()
	PLUGIN:SyncTasks()

	-- Детали — только принявшему.
	netstream.Start(client, "taskboard.details", task.id, task.details)
	client:Notify("Вы взяли объявление. Найдите заказчика лично для деталей и оплаты.")

	-- Уведомляем заказчика, если он онлайн.
	local poster = FindPlayerByCharID(task.posterID)
	if (IsValid(poster)) then
		poster:Notify(character:GetName() .. " взял(а) ваше объявление: " .. task.title)
	end
end)

-- Удалить объявление: только заказчик или админ.
netstream.Hook("taskboard.close", function(client, id)
	local character = client:GetCharacter()
	if (!character) then return end

	local task = PLUGIN:GetTask(id)
	if (!task) then return end

	if (task.posterID != character:GetID() and !CanModerate(client)) then
		return
	end

	PLUGIN:RemoveTask(task.id)
	client:Notify("Объявление закрыто.")
end)

-- Исполнитель отказывается от взятого объявления — оно снова открыто для других.
netstream.Hook("taskboard.abandon", function(client, id)
	local character = client:GetCharacter()
	if (!character) then return end

	local task = PLUGIN:GetTask(id)
	if (!task) then return end

	if (task.takenID != character:GetID()) then return end

	local poster = FindPlayerByCharID(task.posterID)
	local who = task.takenName or character:GetName()

	task.status    = "open"
	task.takenID   = nil
	task.takenName = nil

	PLUGIN:SaveData()
	PLUGIN:SyncTasks()

	netstream.Start(client, "taskboard.cleardetails", task.id)
	client:Notify("Вы отказались от объявления.")

	if (IsValid(poster)) then
		poster:Notify(who .. " отказал(ся/ась) от вашего объявления: " .. task.title)
	end
end)
