ITEM.name = "item.resin"
ITEM.description = "item.resin.desc"
ITEM.category = "item.category.raw"
ITEM.rarity = 1
ITEM.model = "models/items/crafting_metal/resin_puck_stack.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.max_stack = 25
ITEM.stackable = true
ITEM.cost = 20

-- Распаковка пачки: одна цельная пачка -> 5 отдельных единиц Смолы Альянса
-- (combine_resine). Пачка расходуется целиком. Лишнее, если инвентарь полон,
-- падает на землю (как в tomato.lua/farming).
ITEM.functions.unpack = {
	name = "Распаковать",
	OnRun = function(item)
		local client = item.player

		item:Remove()

		for i = 1, 5 do
			local new_item = ix.Item:Instance("combine_resine")

			if !client:AddItem(new_item) then
				ix.Item:Spawn(client, nil, new_item)
			end
		end

		return true
	end,
	OnCanRun = function(item)
		return !IsValid(item:GetEntity())
	end
}
