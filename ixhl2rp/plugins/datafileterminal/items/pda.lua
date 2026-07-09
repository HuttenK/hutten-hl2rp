ITEM.name = "КПК"
ITEM.description = "Карманный персональный компьютер. Доступ к базе досье. Включить/выключить — клавиша G."
ITEM.model = "models/nirrti/tablet/tablet_sfm.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Устройства"

-- Включить/выключить КПК прямо из инвентаря (альтернатива клавише G).
ITEM.functions = ITEM.functions or {}
ITEM.functions.Toggle = {
	name = "Включить/Выключить",
	icon = "icon16/television.png",
	OnRun = function(item)
		local client = item.player

		if IsValid(client) then
			local plugin = ix.plugin.list["datafileterminal"]

			if plugin then
				local wep = client:GetActiveWeapon()

				if IsValid(wep) and wep:GetClass() == plugin.pdaClass then
					plugin:PdaOff(client)
				else
					plugin:PdaOn(client)
				end
			end
		end

		return false -- не удаляем предмет
	end
}
