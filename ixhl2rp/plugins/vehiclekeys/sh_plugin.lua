local PLUGIN = PLUGIN

PLUGIN.name = "Ключи от транспорта"
PLUGIN.author = "Claude"
PLUGIN.description = "Физический ключ-предмет, привязываемый к транспорту LVS. Только по ключу можно отпереть/запереть машину и завести двигатель."

ix.util.Include("sv_plugin.lua")

-- Выдать себе чистый (непривязанный) ключ.
ix.command.Add("VehicleKeyGive", {
	description = "Выдать себе чистый ключ от транспорта.",
	adminOnly = true,
	OnRun = function(self, client)
		local instance = ix.Item:Instance("vehicle_key")

		if (instance) then
			client:AddItem(instance)

			return "Ключ выдан (проверьте инвентарь). Наведитесь на транспорт и используйте «Привязать к транспорту»."
		end

		return "Не удалось создать ключ."
	end
})
