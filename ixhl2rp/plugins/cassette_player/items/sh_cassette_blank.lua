-- Пустая кассета: игрок сам задаёт название и звуковой трек.
ITEM.name        = "Пустая кассета"
ITEM.description = "Компактный флеш-накопитель малого объема, произведенный еще в начале 21-го века. Раньше использовался для сохранения забавных картинок, а теперь с помощью него передают музыку. Легальную и запрещенную."
ITEM.model       = "models/props_junk/wideognomes.mdl"
ITEM.category    = "item.category.misc"
ITEM.width       = 1
ITEM.height      = 1
ITEM.rarity      = 1
ITEM.isCassette  = true

-- Данные хранятся на инстансе и синхронизируются только с владельцем.
ITEM:AddData("customName", {
	Transmit = ix.transmit.owner,
})
ITEM:AddData("track", {
	Transmit = ix.transmit.owner,
})

-- После записи показываем пользовательское название и трек в тултипе инвентаря.
function ITEM:GetPrintName()
	local customName = self:GetData("customName", "")
	if customName != "" then return customName end
	local success, result = pcall(L, tostring(self.name or "unknown"))
	return success and result or self.name
end

-- «Записать» — открывает на клиенте диалог для ввода названия и трека.
ITEM.functions.Record = {
	name = "Записать",
	OnCanRun = function(itemTable)
		-- Доступно только если кассета в инвентаре и ещё не записана.
		if IsValid(itemTable.entity) then return false end
		return itemTable:GetData("track", "") == ""
	end,
	OnRun = function(itemTable)
		if SERVER then
			net.Start("cassette.record")
				net.WriteInt(itemTable.id, 32)
			net.Send(itemTable.player)
		end
		return false
	end,
}
