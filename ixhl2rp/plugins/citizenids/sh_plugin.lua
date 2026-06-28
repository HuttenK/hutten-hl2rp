PLUGIN.name = "New Citizen IDs"
PLUGIN.description = ""
PLUGIN.author = "Schwarz Kruppzo"

ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")

-- Админ-команда: впечатать (привязать) экипированную CID-карту цели к её персонажу.
-- Снимает: имя, модель, скин, генетику (физописание), а также связь datafileID.
ix.command.Add("CardImprint", {
	description = "Впечатать CID-карту цели в её персонажа (имя, модель, генетика, связь).",
	adminOnly = true,
	arguments = {
		ix.type.player
	},
	OnRun = function(self, client, target)
		local character = target:GetCharacter()
		if !character then
			return "У цели нет активного персонажа."
		end

		local card = target:GetIDCard()
		if !card then
			return target:Name() .. ": нет экипированной CID-карты в слоте 'cid'."
		end

		if !Schema.ImprintCard then
			return "Ошибка: Schema:ImprintCard не загружена."
		end

		Schema:ImprintCard(card, character)

		return string.format("Карта впечатана в персонажа %s (CID #%s).",
			target:Name(), tostring(card:GetData("cid", "000-00")))
	end
})