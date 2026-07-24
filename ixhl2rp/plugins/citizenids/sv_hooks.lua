function Schema:CharacterVarChanged(character, key, oldVar, value)
	if key == "name" and oldVar != value then
		local query = mysql:Select("ix_items")
		query:Select("item_id")
		query:WhereLike("data", "\"owner\":"..character:GetID())
		query:Callback(function(result)
			if istable(result) and #result > 0 then
				for k, v in ipairs(result) do
					v.item_id = tonumber(v.item_id)

					ix.Item.instances[v.item_id]:SetData("name", value)
					
					hook.Run("OnIDCardUpdated", ix.Item.instances[v.item_id])
				end
			end
		end)
		query:Execute()
	end
end

netstream.Hook("ixCitizenIDEdit", function(client, itemID, newData)
	if !client:IsSuperAdmin() and !client:IsAdmin() then return end

	local item = ix.Item.instances[itemID]
	
	if !item then return end
	
	newData["type"] = tonumber(newData["type"]) or 0
	newData["type"] = math.Clamp(math.Round(newData["type"]), 0, 3)

	local access = {}
	for i, v in ipairs(newData["access"] or {}) do
		access[v] = true
	end

	-- Защита от дубликатов УЛ: кнопка «сгенерировать» в редакторе ставит math.random,
	-- который при 50+ игроках регулярно совпадает. Не даём выдать номер, уже занятый
	-- другой картой. Проверяем среди ЗАГРУЖЕННЫХ карт (онлайн-игроки, мир, загруженные
	-- хранилища) — этого достаточно для типичного случая двух активных игроков.
	local newCID = tostring(newData["cid"] or "0000")

	if newCID != "" and newCID != "0000" and newCID != "000-00" then
		for _, other in pairs(ix.Item.instances) do
			if other == item then continue end
			if !istable(other) or !other.GetData then continue end
			if other.equip_inv != "cid" then continue end

			if tostring(other:GetData("cid", "")) == newCID then
				client:Notify("Номер УЛ " .. newCID .. " уже выдан другой карте. Выберите другой.")
				return
			end
		end
	end

	item:SetData("name", newData["name"] or "nobody")
	item:SetData("cid", newCID)
	item:SetData("number", newData["number"] or "")
	item:SetData("access", access)
	item:SetData("type", newData["type"])

	hook.Run("OnIDCardUpdated", item)
end)

do
	local CHAR = ix.meta.character

	function CHAR:CreateIDCard(type)
		if type then
			local client = self:GetPlayer()

			local instance = ix.Item:Instance(type)
			instance:SetupCharacter(self)

			client:AddItem(instance, "cid")

			-- Авто-регистрация при первом спавне: уникальный CID + впечатывание
			-- персонажа в карту (раньше это делалось вручную через /CardImprint).
			Schema:ImprintCard(instance, self)
		end
	end
end

-- =====================================================================
-- Привязка ("впечатывание") персонажа в CID-карту.
-- Снимок на карту: datafileID(связь), name, charModel, charSkin, charGeneticRaw.
-- Очки лояльности/статус НЕ пишем на карту — они берутся из досье по datafileID.
-- Текст физописания строит клиент-владелец (L() работает только на клиенте).
-- =====================================================================
util.AddNetworkString("ixCardImprintDescReq")
util.AddNetworkString("ixCardImprintDescResp")

-- Отзывает ВСЕ прочие CID-карты, привязанные к досье datafileID, кроме keepItemID.
-- Отозванная карта: отвязана от досье (datafileID = 0), помечена revoked и лишена
-- доступа — она больше не открывает досье и не даёт допуск. datafileID и revoked
-- пишутся сквозь в БД (item:SetData), поэтому эффект переживает перезагрузку.
--
-- Замечание: перебираем только ЗАГРУЖЕННЫЕ карты (ix.Item.instances) — то есть те,
-- что в инвентарях онлайн-игроков, в мире и в загруженных хранилищах. Старая карта
-- владельца почти всегда среди них. Карта, лежащая офлайн в невыгруженном контейнере,
-- отзовётся только когда прогрузится (тогда её datafileID ещё указывает на досье и
-- она сработает — см. TODO о сквозном апдейте БД, если понадобится строгий вариант).
function Schema:RevokeOtherCards(datafileID, keepItemID)
	datafileID = tonumber(datafileID)
	if !datafileID or datafileID <= 0 then return end

	for _, other in pairs(ix.Item.instances) do
		if !istable(other) or !other.GetData then continue end
		if other:GetID() == keepItemID then continue end
		if other.equip_inv != "cid" then continue end
		if tonumber(other:GetData("datafileID", 0)) != datafileID then continue end

		other:SetData("datafileID", 0)
		other:SetData("access", {})
		other:SetData("revoked", true)
	end
end

function Schema:ImprintCard(item, character)
	if !item or !item.SetData or !character then return false end

	-- Уникальный CID — выдаём, только если его ещё нет (не затираем выданный
	-- терминалом/админом). Детерминирован от ID персонажа => уникален и стабилен.
	local curCID = tostring(item:GetData("cid", "") or "")
	if curCID == "" or curCID == "000-00" or curCID == "0000" then
		-- Канонический уникальный номер: QPR-перестановка от ID персонажа (та же
		-- биекция, что и citizen_id в !new_datafile), поэтому РАЗНЫЕ персонажи всегда
		-- получают РАЗНЫЕ номера. Fallback на charID%100000, если библиотека досье
		-- почему-то недоступна. (math.random здесь НЕ используем — он давал дубликаты.)
		local n = (ix.Datafile and ix.Datafile.GenerateCitizenID)
			and ix.Datafile:GenerateCitizenID(character:GetID())
			or Schema:ZeroNumber(character:GetID() % 100000, 5)
		item:SetData("cid", string.format("%s-%s", n:sub(1, 3), n:sub(4, 5)))
	end

	-- Связь карта <-> персонаж
	item:SetData("datafileID", character:GetID())

	-- Эта карта становится единственной рабочей: все ранее впечатанные в это же
	-- досье — отзываем.
	item:SetData("revoked", nil)
	Schema:RevokeOtherCards(character:GetID(), item:GetID())

	-- Идентичность (снимок)
	item:SetData("name",      character:GetName())
	item:SetData("charModel", character:GetModel() or "")
	item:SetData("charSkin",  character:GetData("skin", 0))

	-- Сырая генетика (4 числа: shape, height, age, eyeColor) — текст соберёт клиент
	local g = character.Genetic and character:Genetic()
	if g and g.ToSaveable then
		item:SetData("charGeneticRaw", g:ToSaveable())
	end

	-- Просим клиента-владельца собрать текст физописания и вернуть его
	local ply = character:GetPlayer()
	if IsValid(ply) then
		net.Start("ixCardImprintDescReq")
			net.WriteUInt(item:GetID(), 32)
		net.Send(ply)
	end

	-- Синхронизируем досье/stored (имя, доступ, очки — по datafileID)
	hook.Run("OnIDCardUpdated", item)

	return true
end

-- Клиент-владелец вернул собранный текст физописания -> кладём на карту
net.Receive("ixCardImprintDescResp", function(len, ply)
	local itemID = net.ReadUInt(32)
	local desc   = net.ReadString()

	local item = ix.Item.instances[itemID]
	if !item or !item.GetData then return end

	-- Защита: отвечающий должен быть владельцем персонажа этой карты
	local char = ply:GetCharacter()
	if !char then return end
	if tonumber(item:GetData("datafileID")) != char:GetID() then return end

	item:SetData("charGenetic", string.sub(tostring(desc or ""), 1, 255))
end)