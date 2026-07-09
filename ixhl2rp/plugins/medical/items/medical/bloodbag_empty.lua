ITEM.name = "item.bloodbagempty"
ITEM.description = "item.bloodbagempty.desc"
ITEM.model = Model("models/mosi/fallout4/props/aid/bloodbagempty.mdl")
ITEM.useSound = "items/medshot4.wav"
ITEM.cost = 50
ITEM.rarity = 1
ITEM.stats.uses = 1          -- один забор крови
ITEM.stats.time = 8
ITEM.junk = "bloodbag"       -- после забора превращается в полный пакет крови

-- Забор крови. База medical вызывает OnConsume для «пострадавшего» (на себе — сам
-- игрок, при использовании на цель — цель) и передаёт его персонажа в character.
--
-- В этой сборке НЕТ числового пула крови: GetBlood/SetBlood жили в отключённом
-- _old/!damagesystem. Кровопотеря моделируется хедиффом "bleeding"
-- (Hediff_BloodLoss) с severity 0..1, где 1.0 = смерть. Полный переливаемый пакет
-- (bloodbag.lua) уменьшает этот хедифф; здесь наоборот — забор 25% от полного
-- объёма = +0.25 к severity кровопотери у пострадавшего.
function ITEM:OnConsume(player, injector, mul, character)
	local health = character:Health()

	if health then
		local bloodLoss

		for k, v in health:GetHediffs() do
			if v.part != 1 then continue end
			if v.uniqueID == "bleeding" then
				bloodLoss = v
				break
			end
		end

		if bloodLoss then
			bloodLoss:AdjustSeverity(0.25)
		else
			-- Создаём хедифф кровопотери на торсе (hitGroup 0 → part 1, как в бою).
			health:AddHediff("bleeding", 0, {severity = 0.25})
			health.bloodloss = true
		end
	end

	-- Пустой пакет расходуется (stats.uses = 1) и через ITEM.junk заменяется на
	-- полный "bloodbag" в инвентаре того, кто делал забор.
	-- Возвращаем пустую таблицу: расчёт опыта медицины требует таблицу, не nil.
	return {}
end
