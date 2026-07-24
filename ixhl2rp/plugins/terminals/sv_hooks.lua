local PLUGIN = PLUGIN

util.AddNetworkString("ixTerminalResponse")
util.AddNetworkString("ixTerminalRetrieveInfo")
util.AddNetworkString("ixTerminalRequest")

-- Лояльность на терминале раньше искалась сравнением старого строкового статуса
-- (его выставляют через КПК: Citizen/Red/Blue/… из datafile PLUGIN.CivilStatus)
-- с НАЗВАНИЯМИ новых уровней ix.Loyalty — они никогда не совпадали, поэтому всем
-- показывался один уровень «Обычные граждане (3)».
-- Явная таблица: старый статус -> индекс уровня ix.Loyalty (1-9). Совпадение по цвету
-- там, где у нового уровня он есть (красный/синий/зелёный/белый), иначе по рангу.
-- ПРАВЬТЕ ЗДЕСЬ, если нужен другой уровень для конкретного статуса.
local STATUS_TO_LOYALTY = {
	["Anti-Citizen"] = 1, -- Анти-социальный (уровень G)
	["Citizen"]      = 3, -- Обычные граждане (уровень 0)
	["Black"]        = 3, -- нет отдельного уровня -> обычные граждане
	["Brown"]        = 3, -- нет отдельного уровня -> обычные граждане
	["Orange"]       = 3, -- нет отдельного уровня -> обычные граждане
	["Red"]          = 4, -- Сторонник 1-го уровня (красный)
	["Green"]        = 7, -- Лоялист 2-го уровня (зелёный)
	["Blue"]         = 6, -- Лоялист 1-го уровня (синий)
	["White"]        = 8, -- Почетный лоялист (белый)
	["Gold"]         = 9, -- Высший лоялист
	["Platinum"]     = 9, -- Высший лоялист (фиолетовый)
}

local function UpdateCardAppearance(character)
	local charID = character:GetID()
	local model  = character:GetModel() or ""
	local skin   = character:GetData("skin", 0)

	for _, item in pairs(ix.Item.instances) do
		if item.GetData and tonumber(item:GetData("datafileID")) == charID then
			item:SetData("charModel", model)
			item:SetData("charSkin",  skin)
		end
	end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	timer.Simple(0.5, function()
		if IsValid(client) and client:GetCharacter() == character then
			UpdateCardAppearance(character)
		end
	end)
end

function PLUGIN:CharacterVarChanged(character, key, oldVar, value)
	if key == "model" then
		UpdateCardAppearance(character)
	end
end

net.Receive("ixTerminalRetrieveInfo", function(len, ply)
	if !ply:Alive() then return end

	local terminal
	for k, v in pairs(ents.FindInSphere(ply:GetPos(), 80)) do
		if v:GetClass() == "ix_loyalist_terminal" then
			terminal = v
			break
		end
	end

	if !IsValid(terminal) then
		return
	end

	local item = ply:GetIDCard()

	if item then
		local dID, datafile, genericdata = Schema:GetDatafile(item:GetData("cid") or "", item:GetData("number") or "")

		if genericdata and datafile then
			local notes, civics, meds = 0, 0, 0

			for k, v in pairs(datafile) do
				if v.category == "union" then
					notes = notes + 1
				elseif v.category == "civil" then
					civics = civics + 1
				elseif v.category == "med" then
					meds = meds + 1
				end
			end

			-- Уровень лояльности: старый строковый статус из датафайла (его задают
			-- через КПК) маппится в индекс нового ix.Loyalty. Неизвестный/пустой
			-- статус -> «Обычные граждане» (3).
			local civilStatus = STATUS_TO_LOYALTY[genericdata.status] or 3

			-- Модель владельца карточки (не того, кто стоит у терминала).
			-- Ищем среди всех онлайн-игроков по character:GetID().
			local ownerModel = ""
			local ownerSkin  = 0
			local datafileID = tonumber(item:GetData("datafileID"))

			local geneticDesc = ""

			if datafileID then
				local ownerPly = nil
				for _, ply in ipairs(player.GetAll()) do
					local plyChar = ply:GetCharacter()
					if plyChar and plyChar:GetID() == datafileID then
						ownerPly = ply
						break
					end
				end

				if IsValid(ownerPly) then
					-- Берём ОРИГИНАЛЬНУЮ модель персонажа, а не текущую: форма/аутфит/
					-- форма МП через client:SetModel подменяют модель ИГРОКА и
					-- char_outfit.model (пока костюм надет), но character:GetModel()
					-- остаётся исходной моделью персонажа — её и берём.
					local ownerChar = ownerPly:GetCharacter()
					ownerModel = (ownerChar and ownerChar:GetModel())
						or ownerPly:GetModel() or ""
					-- Скин формы тоже подменяется -> берём скин персонажа
					ownerSkin  = (ownerChar and ownerChar:GetData("skin", 0)) or 0
					item:SetData("charModel", ownerModel)
					item:SetData("charSkin",  ownerSkin)

					-- Описание строится на клиенте (L() на сервере требует client-контекст)
				else
					-- Владелец оффлайн: кэш с карточки
					ownerModel  = item:GetData("charModel")   or ""
					ownerSkin   = item:GetData("charSkin")    or 0
					geneticDesc = item:GetData("charGenetic") or ""
				end
			end

			net.Start("ixTerminalResponse")
				net.WriteString(item:GetData("name") or "N/A")
				net.WriteString(genericdata.aparts or "N/A")
				net.WriteString(genericdata.status or "N/A")
				net.WriteInt(genericdata.points or 0, 16)
				net.WriteUInt(math.Clamp(civilStatus, 1, 255), 8)
				net.WriteString(ownerModel)
				net.WriteUInt(math.Clamp(ownerSkin, 0, 255), 8)
				net.WriteString(geneticDesc)
			net.Send(ply)
		end
	end
end)

net.Receive("ixTerminalRequest", function(len, player)
	if !player:Alive() then return end

	local terminal
	for k, v in pairs(ents.FindInSphere(player:GetPos(), 80)) do
		if v:GetClass() == "ix_loyalist_terminal" then
			terminal = v
			break
		end
	end

	if !IsValid(terminal) then
		return
	end

	if CurTime() < (player.nextTerminalRequest or 0) then return; end

	local b = player:GetIDCard()
	Schema:AddCombineDisplayMessage(Format("NOTICE: %s (#%s) is requesting officer at information terminal.", player:Name(), b:GetData("cid", 0)), Color(255, 180, 0));

	local waypoint = {
		pos = terminal:GetPos() + terminal:GetUp() * 20 + terminal:GetForward() * 10,
		text = L("terminalWaypointCall", player, b:GetData("name", "UNKNOWN"), b:GetData("cid", 0)),
		color = Color(255, 180, 0),
		addedBy = player,
		time = CurTime() + 300
	}

	ix.plugin.list["waypoints"]:AddWaypoint(waypoint)

	player.nextTerminalRequest = CurTime() + 299
end)

function PLUGIN:LoadData()
	self:LoadLoyalistTerminals()
end

function PLUGIN:SaveData()
	self:SaveLoyalistTerminals()
end

function PLUGIN:LoadLoyalistTerminals()
	local data = self:GetData()

	if data then
		for _, v in ipairs(data) do
			local entity = ents.Create("ix_loyalist_terminal")
			entity:SetPos(v[1])
			entity:SetAngles(v[2])
			entity:Spawn()

			local physObject = entity:GetPhysicsObject()

			if IsValid(physObject) then
				physObject:EnableMotion(false)
			end
		end
	end
end

function PLUGIN:SaveLoyalistTerminals()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_loyalist_terminal")) do
		data[#data + 1] = {
			v:GetPos(),
			v:GetAngles()
		}
	end

	self:SetData(data)
end
