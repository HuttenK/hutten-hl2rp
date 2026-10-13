ITEM.name = "item.bloodbag"
ITEM.description = "item.bloodbag.desc"
ITEM.model = "models/illusion/eftcontainers/carmedkit.mdl"
ITEM.useSound = "items/medshot4.wav"
ITEM.cost = 200
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
		bloodLoss:AdjustSeverity(-0.12)

		blood = 120
	end

	return {dmg = blood}
end