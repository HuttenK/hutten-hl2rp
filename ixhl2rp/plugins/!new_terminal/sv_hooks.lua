local PLUGIN = PLUGIN

util.AddNetworkString("civil.terminal.login")
util.AddNetworkString("civil.terminal.show")

net.Receive("civil.terminal.login", function(_, client)
	local character = client:GetCharacter()
	local terminal = net.ReadEntity()

	if !character or !IsValid(terminal) then return end
	if client:GetEyeTraceNoCursor().Entity != terminal then return end

	-- Терминал внутри активной зоны затемнения обесточен. Проверка нужна именно
	-- здесь: вход в терминал идёт своим net-сообщением, минуя PlayerUse.
	local blackout = ix.plugin.list["blackout"]

	if blackout and blackout:IsEntityBlackedOut(terminal) then
		client:NotifyLocalized("blackout.noPower")
		return
	end

	-- Доступ к терминалу только с экипированной CID-картой
	if !client:GetIDCard() then
		client:Notify("Требуется CID-карта для авторизации в терминале.")
		return
	end

	if character.noDatafile then
		ix.Datafile:Create(character, {}, function(datafile)
			ix.Datafile:Setup(client, character)

			PLUGIN:OpenTerminal(client, datafile)
		end)

		return
	end

	PLUGIN:OpenTerminal(client, character.datafile)
end)

netstream.Hook("civil.terminal.request", function(client, page)
	local character = client:GetCharacter()
	local id = character:GetID()

	if character.noDatafile then return end
	
	print("civil.terminal.request", page)

	if page <= 1 then return end
	
	if page == 3 then
		PLUGIN:TerminalShowCredits(client, id)
	elseif page == 6 then
		PLUGIN:TerminalShowMessages(client, id)
	end
end)

netstream.Hook("civil.terminal.transactions", function(client, targetPage)
	local character = client:GetCharacter()
	local id = character:GetID()

	if character.noDatafile then return end

	PLUGIN:TerminalFetchCredits(client, id, targetPage)
end)

netstream.Hook("civil.terminal.messages", function(client, targetPage)
	local character = client:GetCharacter()
	local id = character:GetID()

	if character.noDatafile then return end

	PLUGIN:TerminalFetchMessages(client, id, targetPage)
end)

-- Сохранение/загрузка размещённых терминалов между рестартами карты
function PLUGIN:SaveData()
	local data = {}
	for _, v in ipairs(ents.FindByClass("ix_civil_terminal")) do
		data[#data + 1] = { v:GetPos(), v:GetAngles() }
	end
	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if !istable(data) then return end

	for _, v in ipairs(data) do
		local ent = ents.Create("ix_civil_terminal")
		if !IsValid(ent) then continue end
		ent:SetPos(v[1])
		ent:SetAngles(v[2])
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end
end