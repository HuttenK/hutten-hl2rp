-- Костюм химзащиты: полностью заменяет модель персонажа на защитную (отдельные
-- модели для мужского и женского пола). Даёт сопротивление радиации/токсинам
-- (rad_resist), учитывается системой радиации (GetRadResistance суммирует
-- rad_resist предметов из char_outfit.armor).
--
-- ВАЖНО: в этой сборке Outfit:AddItem игнорирует модель из genderReplacement и
-- применяет только displayID (Appearance). Поэтому для ПОЛНОЙ замены модели
-- меняем playermodel вручную в OnEquipped/OnUnequipped — как это делает база МПФ.
ITEM.name = "Костюм химзащиты"
ITEM.description = "Герметичный защитный костюм. Полностью укрывает тело от заражённой среды и токсичной флоры. Максимальная защита — вместе с противогазом и фильтром."
ITEM.model = Model("models/props_c17/SuitCase001a.mdl") -- модель предмета в инвентаре/в мире
ITEM.width = 2
ITEM.height = 2
ITEM.rarity = 2
ITEM.equip_inv = 'torso'
ITEM.equip_slot = nil

-- Модели, надеваемые на персонажа (полная замена playermodel) по полу.
ITEM.genderReplacement = {
	[GENDER_MALE]   = "models/cellar/characters/hazmat/hazard_male.mdl",
	[GENDER_FEMALE] = "models/cellar/characters/hazmat/hazard_female.mdl",
}

-- Сопротивление радиации/токсинам (0..99). Полная защита — вместе с противогазом
-- (+10) и качественным фильтром (+89), потолок 99.
ITEM.rad_resist = 80

-- Герметичный костюм заменяет модель целиком — бронежилет поверх него не носится.
ITEM.blocksVest = true

function ITEM:OnEquipped(client)
	ix.meta.ItemClothArmor.OnEquipped(self, client) -- база: учёт в char_outfit.armor (rad_resist) и т.п.

	local item = self

	-- ставим модель на следующий кадр, чтобы перебить применение базового аутфита
	timer.Simple(0, function()
		if (!IsValid(client) or !item:IsEquipped()) then return end

		local char = client:GetCharacter()
		if (!char) then return end

		local model = item.genderReplacement[char:GetGender()] or item.genderReplacement[GENDER_MALE]

		if (model and model != "") then
			if (client.char_outfit) then
				client.char_outfit.isModelChangedByOutfit = true
			end

			client:SetModel(model)

			-- бодигруппы костюма (индекс-значение): 1->1, 2->1. Ставим ПОСЛЕ SetModel,
			-- т.к. смена модели сбрасывает бодигруппы.
			client:SetBodygroup(1, 1)
			client:SetBodygroup(2, 1)
		end
	end)
end

function ITEM:OnUnequipped(client)
	ix.meta.ItemClothArmor.OnUnequipped(self, client)

	local char = client:GetCharacter()
	if (!char) then return end

	-- возвращаем базовую модель (из аутфита или модель персонажа)
	local baseModel = (client.char_outfit and client.char_outfit.model) or char:GetModel()

	if (baseModel and baseModel != "") then
		if (client.char_outfit) then
			client.char_outfit.isModelChangedByOutfit = true
		end

		client:SetModel(baseModel)
	end
end
