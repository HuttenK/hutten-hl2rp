-- Униформа ополчения: полностью заменяет модель персонажа, но лицо остаётся
-- открытым — поэтому модель подбирается ПОД ЛИЦО конкретного персонажа, а не
-- просто по полу.
--
-- Наборы conscript-моделей совпадают один-в-один с гражданскими моделями фракции
-- (schema/factions/sh_citizen.lua): male_01..male_10 и female_01..female_15.
-- Значит номер лица можно взять прямо из базовой модели персонажа:
--   models/autonomous/africa/male_01_hair1.mdl -> .../conscript/male_01.mdl
--   models/autonomous/africa/female_07.mdl     -> .../conscript/female_07.mdl
-- Причёска (_hairN) в conscript-моделях не отражена, поэтому суффикс отбрасываем.
--
-- ВАЖНО: в этой сборке Outfit:AddItem игнорирует модель из OnGetReplacement и
-- применяет только displayID (Appearance). Поэтому для ПОЛНОЙ замены модели
-- ставим playermodel вручную в OnEquipped/OnUnequipped — как база МПФ и химзащита.
local CONSCRIPT_PATH = "models/autonomous/africa/conscript/%s_%02d.mdl"
local CONSCRIPT_MAX = {
	male = 10,
	female = 15,
}

local function GetConscriptModel(char)
	-- Берём модель ПЕРСОНАЖА, а не client:GetModel(): последняя могла быть уже
	-- подменена другой одеждой, и тогда номер лица считался бы не с той модели.
	local base = string.lower(char:GetModel() or "")
	local kind, num

	local fileName = string.match(base, "([^/\\]+)%.mdl$")
	if fileName then
		kind, num = string.match(fileName, "^(%a+)_(%d+)")
	end

	-- Фолбэк: персонаж на нестандартной модели (админская, другая фракция, кастом) —
	-- ставим первое лицо нужного пола, иначе SetModel получит несуществующий путь
	-- и игрок станет ошибочной моделью.
	if not CONSCRIPT_MAX[kind or ""] then
		kind = (char:GetGender() == GENDER_FEMALE) and "female" or "male"
		num = 1
	end

	return string.format(CONSCRIPT_PATH, kind, math.Clamp(tonumber(num) or 1, 1, CONSCRIPT_MAX[kind]))
end

ITEM.name = "Униформа ополчения"
ITEM.description = "Разномастная форма ополченца: плотная полевая куртка и штаны без знаков различия, подогнанные по фигуре владельца. Лицо остаётся открытым — ополчение не прячется за визорами."
ITEM.model = Model("models/autonomous/africa/items/prop_millitary_jacket.mdl")
ITEM.rarity = 1
ITEM.width = 2
ITEM.height = 2
ITEM.equip_inv = 'torso'
ITEM.equip_slot = nil

function ITEM:OnGetReplacement(client, char)
	return GetConscriptModel(char)
end

function ITEM:OnEquipped(client)
	ix.meta.ItemCloth.OnEquipped(self, client)

	local item = self

	-- Ставим модель на следующий кадр, чтобы перебить применение базового аутфита.
	timer.Simple(0, function()
		if not IsValid(client) or not item:IsEquipped() then return end

		local char = client:GetCharacter()
		if not char then return end

		local model = item:OnGetReplacement(client, char)
		if not model or model == "" then return end

		if client.char_outfit then
			client.char_outfit.isModelChangedByOutfit = true
			-- Держим модель ополченца «текущей» для системы одежды, иначе
			-- Outfit:Update откатит игрока на гражданскую модель при следующем
			-- обновлении (напр. при надевании шлема или брони на ноги).
			client.char_outfit.model = model
		end

		client:SetModel(model)
	end)
end

function ITEM:OnUnequipped(client)
	ix.meta.ItemCloth.OnUnequipped(self, client)

	local char = client:GetCharacter()
	if not char then return end

	-- Базовую модель берём ИЗ ПЕРСОНАЖА: char_outfit.model сейчас указывает на
	-- модель ополченца (выставлена в OnEquipped).
	local baseModel = char:GetModel()
	if baseModel and baseModel != "" then
		if client.char_outfit then
			client.char_outfit.isModelChangedByOutfit = true
			client.char_outfit.model = baseModel
		end

		client:SetModel(baseModel)
	end

	-- Модель сменилась обратно на гражданскую (SetModel сбросил бодигруппы к её
	-- дефолтам) — пересчитываем всё ещё надетую одежду под неё.
	if client.char_outfit then
		client.char_outfit:Update()
	end
end
