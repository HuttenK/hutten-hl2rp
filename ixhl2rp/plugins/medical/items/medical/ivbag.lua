ITEM.name = "item.ivbag"
ITEM.description = "item.ivbag.desc"
ITEM.model = "models/cultist/items/medkit/w_medkit.mdl"
ITEM.useSound = "items/medshot4.wav"
ITEM.cost = 150
ITEM.rarity = 1
ITEM.stats.uses = 5
ITEM.stats.time = 10
function ITEM:OnConsume(player, injector, mul, character)
	local health = character:Health()
	local bloodLoss

	for k, v in health:GetHediffs() do
		if v.part != 1 then continue end
		if v.uniqueID == "bleeding" then 
			bloodLoss = v
			break
		end
	end

	local blood = 0

	if bloodLoss then
		bloodLoss:AdjustSeverity(-0.08)

		blood = 80
	end

	return {dmg = blood}
end