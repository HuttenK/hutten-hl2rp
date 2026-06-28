ITEM.name        = "Транквилизаторный инъектор"
ITEM.description  = "Одноразовый автоинъектор с нейротоксином Зен-флоры. Применяется вплотную: прижмите к цели и удерживайте несколько секунд — жертва падает и около 2 минут не может двигаться, оставаясь в сознании. Тихая альтернатива дротомёту для ближнего боя."
ITEM.model        = "models/healthvial.mdl"
ITEM.width        = 1
ITEM.height       = 1
ITEM.category     = "Снаряжение"
ITEM.bDropOnDeath = true
ITEM.noBusiness   = true
ITEM.contraband   = true

-- Контактное применение — по образцу зип-стяжки (schema/items/ziptie.lua):
-- трасса на 96 ед., затем DoStaredAction (нужно смотреть на цель и быть рядом).
ITEM.functions.Use = {
	name = "Применить",
	OnRun = function(itemTable)
		local client = itemTable.player

		local data = {}
			data.start  = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client

		local target = util.TraceLine(data).Entity
		local clientTarget = (IsValid(target) and IsValid(target.ixPlayer) and target.ixPlayer) or target

		if (IsValid(clientTarget) and clientTarget:IsPlayer() and clientTarget:GetCharacter()
		and clientTarget:Alive() and !IsValid(clientTarget.ixRagdoll)) then
			itemTable.bBeingUsed = true

			client:SetAction("Введение инъекции...", 4)
			clientTarget:SetAction("Кто-то прижимает что-то к вашей шее...", 4)

			-- Предупреждаем жертву, что её колют — у неё есть пара секунд среагировать.
			clientTarget:Notify("Вас прижали и пытаются вколоть шприц! Вырывайтесь, пока не поздно!")

			client:DoStaredAction(target, function()
				local plugin = ix.plugin.list["transvil"]

				if (plugin and plugin.ApplyTranquilizer) then
					plugin:ApplyTranquilizer(clientTarget, client)
				end

				itemTable:Remove()
			end, 4, function()
				client:SetAction()

				if (IsValid(clientTarget)) then
					clientTarget:SetAction()
				end

				itemTable.bBeingUsed = false
			end)
		else
			client:NotifyLocalized("plyNotValid")
		end

		return false
	end,

	-- Нельзя применять, пока предмет лежит в мире как entity, или пока уже используется.
	OnCanRun = function(itemTable)
		return !IsValid(itemTable.entity) or itemTable.bBeingUsed
	end
}

-- Нельзя перекладывать/передавать во время применения.
function ITEM:CanTransfer(inventory, newInventory)
	return !self.bBeingUsed
end
